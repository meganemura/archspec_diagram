require_relative "test_helper"

class ArchitectureTest < Minitest::Test
  include DiagramHelpers

  def test_components_keep_declaration_order_and_selector_lines
    architecture = load_architecture(<<~RUBY)
      component :models, in: "app/models/**/*.rb", except: "app/models/legacy/**/*.rb"
      component :records, descendants_of: "ApplicationRecord"
      component :commands, namespace: "Commands", constants: "::Legacy"
    RUBY

    assert_equal %i[models records commands], architecture.components.keys
    assert_equal ["in: app/models/**/*.rb", "except: app/models/legacy/**/*.rb"], architecture.components[:models].selectors
    assert_equal ["descendants of: ApplicationRecord"], architecture.components[:records].selectors
    assert_equal ["namespace: Commands", "constants: Legacy"], architecture.components[:commands].selectors
  end

  def test_title_is_the_config_directory_name
    with_config("component :a, in: 'a.rb'") do |path|
      assert_equal File.basename(File.dirname(path)), Architecture.load(path).title
    end
  end

  def test_a_directory_resolves_to_its_archspec_rb
    with_config("component :a, in: 'a.rb'") do |path|
      assert_equal %i[a], Architecture.load(File.dirname(path)).components.keys
    end
  end

  def test_top_level_declarations_have_no_origin
    architecture = load_architecture(<<~RUBY)
      component :a, in: "a.rb"
      a.cannot_use :a
    RUBY

    assert_nil architecture.components[:a].origin
    assert_nil architecture.clauses.first.origin
  end

  def test_presets_own_the_components_and_rules_they_introduce
    architecture = load_architecture(<<~RUBY)
      component :wrapper, in: "w.rb"
      architecture :layered, layers: { ui: "ui/**/*.rb", core: "core/**/*.rb" }
      preset :ruby_conventions
    RUBY

    assert_nil architecture.components[:wrapper].origin
    assert_equal "architecture :layered, layers: {…}", architecture.components[:ui].origin.label
    labels = architecture.clauses.map { _1.origin.label }
    assert_equal ["architecture :layered, layers: {…}"] * 2, labels.first(2)
    assert_equal ["preset :ruby_conventions"] * 4, labels.last(4)
  end

  def test_two_identical_preset_calls_stay_distinct_origins
    architecture = load_architecture(<<~RUBY)
      preset :ruby_conventions
      preset :ruby_conventions
    RUBY

    assert_equal [1, 1, 1, 1, 2, 2, 2, 2], architecture.clauses.map { _1.origin.seq }
  end

  def test_a_rule_merged_into_an_earlier_one_keeps_the_first_origin
    architecture = load_architecture(<<~RUBY)
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      architecture :modular_monolith, components: { c: "c.rb" }, public: { c: "c/public/*.rb" }
      c.public_api "c/api/*.rb"
    RUBY

    clause = architecture.clauses.find { _1.summary.to_s.start_with?("public API") }
    assert_equal "public API: c/public/*.rb, c/api/*.rb", clause.summary
    assert_equal :architecture, clause.origin.verb
  end

  def test_origin_labels_collapse_collections_and_quote_scalars
    origin = Architecture::Origin.new(seq: 1, verb: :architecture, preset: :vanilla_rails,
                                      options: { share_helpers: true, concerns: "app/**/concerns/*.rb", empty: { a: 1 }, list: [1] })

    assert_equal 'architecture :vanilla_rails, share_helpers: true, concerns: "app/**/concerns/*.rb", empty: {…}, list: […]',
                 origin.label
  end

  def test_a_name_used_by_a_rule_but_never_declared_becomes_an_undeclared_component
    architecture = load_architecture(<<~RUBY)
      component :a, in: "a.rb"
      rule ArchSpec::Rules::ForbidDependenciesRule.new(:a, [:ghost])
    RUBY

    assert_equal %i[a ghost], architecture.components.keys
    assert_equal [true, false], architecture.components.values.map(&:declared)
    assert_empty architecture.components[:ghost].selectors
  end

  def test_each_user_failure_is_a_one_line_error
    cases = {
      "component :a, in: 'a.rb'\nmodles.cannot_use :a" => /\Acould not load .*Archspec\.rb: undefined local variable or method .modles./,
      "component :a, in: (" => /\Acould not load .*Archspec\.rb: /,
      "component :a, in: 'a.rb'\na.cannot_use :nope" => /\Acould not load .*Archspec\.rb: a\.cannot_use references unknown component: nope\z/,
      "# nothing here\n" => /\A.*Archspec\.rb declares no components or rules\z/
    }

    cases.each do |source, pattern|
      error = assert_raises(ArchspecDiagram::Error, source) { load_architecture(source) }
      assert_match pattern, error.message
      refute_includes error.message, "\n"
    end
  end

  def test_missing_file_and_directory_without_config
    error = assert_raises(ArchspecDiagram::Error) { Architecture.load("/nonexistent/Archspec.rb") }
    assert_equal "could not load /nonexistent/Archspec.rb: no such file", error.message

    Dir.mktmpdir do |dir|
      error = assert_raises(ArchspecDiagram::Error) { Architecture.load(dir) }
      assert_equal "could not load #{dir}: no Archspec.rb in that directory", error.message
    end
  end

  def test_unreadable_file
    with_config("component :a, in: 'a.rb'") do |path|
      File.chmod(0o000, path)
      skip "permissions are not enforced for this user" if File.readable?(path)

      error = assert_raises(ArchspecDiagram::Error) { Architecture.load(path) }
      assert_equal "could not load #{path}: Permission denied", error.message
    end
  end

  def test_focus_keeps_the_component_its_neighbours_and_project_wide_clauses
    architecture = load_architecture(<<~RUBY)
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      component :c, in: "c.rb"
      component :d, in: "d.rb"
      a.can_only_use :b, :c
      c.cannot_use :d
      d.cannot_use :a
      no_cycles
    RUBY

    focused = architecture.focus(:a)

    assert_equal %i[a b c d], focused.components.keys
    assert_equal [[:a, "uses only: b, c", %i[b c]], [:c, nil, [:d]], [:d, nil, [:a]], [nil, "no cycles among all components", []]],
                 focused.clauses.map { [_1.subject, _1.summary, _1.links.map(&:to)] }
  end

  def test_focus_drops_links_that_leave_the_neighbourhood
    architecture = load_architecture(<<~RUBY)
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      component :c, in: "c.rb"
      a.cannot_use :b
      b.cannot_use :c
    RUBY

    focused = architecture.focus(:a)

    assert_equal %i[a b], focused.components.keys
    assert_equal [:a], focused.clauses.map(&:subject)
  end

  def test_focus_on_an_unknown_component_names_the_known_ones
    architecture = load_architecture("component :billing, in: 'b.rb'\ncomponent :catalog, in: 'c.rb'")

    error = assert_raises(ArchspecDiagram::Error) { architecture.focus(:biling) }

    assert_equal "unknown component :biling (known: billing, catalog)", error.message
  end
end
