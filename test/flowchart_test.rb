require_relative "test_helper"

class FlowchartTest < Minitest::Test
  include DiagramHelpers

  def flow(source, **options)
    Flowchart.new(load_architecture(source), Options.new(**options)).to_s
  end

  def test_a_small_config_renders_exactly
    source = <<~RUBY
      component :models, in: "app/models/**/*.rb"
      component :controllers, in: "app/controllers/**/*.rb"
      controllers.can_only_use :models, because: "thin controllers"
      models.cannot_use :controllers
      no_cycles
    RUBY

    assert_equal <<~MERMAID.chomp, flow(source, detail: :reasons, direction: :LR)
      flowchart LR
        c0["<b>models</b><br/><small>in: app/models/**/*.rb</small>"]
        c1["<b>controllers</b><br/><small>in: app/controllers/**/*.rb</small><br/>uses only: models<br/><i>because thin controllers</i>"]
        n_top["<b>project rules</b><br/>no cycles among all components"]:::note
        c1 --> c0
        c0 -.-x|"cannot use"| c1
        linkStyle 0 stroke:#2f9e44,stroke-width:2px
        linkStyle 1 stroke:#e03131,stroke-width:1.5px,stroke-dasharray:5 4
        classDef note fill:none,stroke-dasharray:2 2
    MERMAID
  end

  def test_detail_names_drops_selectors_rules_and_notes
    source = <<~RUBY
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      a.can_only_use :b
      no_cycles
    RUBY

    assert_equal <<~MERMAID.chomp, flow(source, detail: :names)
      flowchart TB
        c0["<b>a</b>"]
        c1["<b>b</b>"]
        c0 --> c1
        linkStyle 0 stroke:#2f9e44,stroke-width:2px
    MERMAID
  end

  def test_detail_rules_omits_reasons_and_reasons_puts_them_on_summaryless_edges
    source = <<~RUBY
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      a.cannot_use :b, because: "layering"
    RUBY

    assert_includes flow(source, detail: :rules), %(c0 -.-x|"cannot use"| c1)
    assert_includes flow(source, detail: :reasons), %(c0 -.-x|"cannot use: layering"| c1)
  end

  def test_names_that_collide_under_naive_sanitizing_get_distinct_ids
    output = flow(<<~RUBY)
      component :"a-", in: "x.rb"
      component :a_2d, in: "y.rb"
      component :a__2d, in: "z.rb"
      component :end, in: "w.rb"
    RUBY

    assert_equal ['c0["<b>a-</b>', 'c1["<b>a_2d</b>', 'c2["<b>a__2d</b>', 'c3["<b>end</b>'],
                 output.lines.grep(/\A  c\d/).map { _1.strip[/\A.*?<\/b>/] }
  end

  def test_markup_in_names_selectors_and_reasons_is_escaped
    output = flow(<<~RUBY, detail: :reasons)
      component :"</title>", in: "a.rb"
      component :b, in: "`b`/**.rb"
      self.public_send(:"</title>").cannot_use :b, because: "no \\"quotes\\" & <i>tags</i>\\nline two ``` # hash"
    RUBY

    refute_includes output, "</title>"
    refute_includes output, "`"
    assert_includes output, "<b>#lt;/title#gt;</b>"
    assert_includes output, "in: #96;b#96;/**.rb"
    assert_includes output, %(cannot use: no #quot;quotes#quot; #amp; #lt;i#gt;tags#lt;/i#gt; line two #96;#96;#96; #35; hash)
    refute_match(/\R\s*line two/, output)
  end

  def test_allow_and_consumer_on_one_pair_merge_into_one_allow_edge
    output = flow(<<~RUBY)
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      a.can_only_use :b
      b.can_only_be_used_by :a
    RUBY

    assert_equal ['  c0 -->|"only consumer"| c1', "  linkStyle 0 stroke:#2f9e44,stroke-width:2px"],
                 output.lines.map(&:chomp).grep(/c0 -|linkStyle/)
  end

  def test_allow_and_forbid_on_one_pair_stay_two_edges
    output = flow(<<~RUBY)
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      a.can_only_use :b
      a.cannot_use :b
    RUBY

    assert_equal ["  c0 --> c1", '  c0 -.-x|"cannot use"| c1'], output.lines.map(&:chomp).grep(/c0 -/)
  end

  def test_link_style_indices_point_at_the_edges_of_that_kind
    output = flow(<<~RUBY)
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      component :c, in: "c.rb"
      a.cannot_use :b
      b.can_only_use :c
      c.can_only_be_used_by :a
      a.cannot_reference_constants "X"
    RUBY

    edges = output.lines.map(&:chomp).select { _1.match?(/\A  c\d+ [-=]/) }
    styles = output.lines.map(&:chomp).grep(/linkStyle/).to_h { |l| l.match(/linkStyle ([\d,]+) (.*)/).captures.then { |i, s| [s, i.split(",").map(&:to_i)] } }

    assert_equal ["  c0 -.-x|\"cannot use\"| c1", "  c1 --> c2", "  c0 ==>|\"only consumer\"| c2", "  c0 -.-x|\"cannot reference\"| k0"],
                 edges
    assert_equal({ "stroke:#e03131,stroke-width:1.5px,stroke-dasharray:5 4" => [0, 3],
                   "stroke:#2f9e44,stroke-width:2px" => [1],
                   "stroke:#1971c2,stroke-width:2px" => [2] }, styles)
  end

  def test_constants_are_one_node_each_and_a_declared_class_is_defined_only_when_used
    output = flow(<<~RUBY)
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      a.cannot_reference_constants "X", "Y"
      b.cannot_reference_constants "X"
    RUBY

    assert_equal ['  k0{{"X"}}:::constant', '  k1{{"Y"}}:::constant'], output.lines.map(&:chomp).grep(/\A  k\d/)
    assert_equal ["  classDef constant fill:none,stroke:#e03131,color:#e03131"], output.lines.map(&:chomp).grep(/classDef/)
    assert_equal ['  c1 -.-x|"cannot reference"| k0'], output.lines.map(&:chomp).grep(/c1 -/)
  end

  def test_presets_become_subgraphs_with_a_project_wide_note
    output = flow(<<~RUBY)
      component :a, in: "a.rb"
      preset :ruby_conventions
      architecture :layered, layers: { ui: "ui.rb", core: "core.rb" }
    RUBY

    assert_equal [
      "flowchart TB",
      '  c0["<b>a</b><br/><small>in: a.rb</small>"]',
      '  subgraph g0["architecture :layered, layers: {…}"]',
      '    c1["<b>ui</b><br/><small>in: ui.rb</small><br/>uses only: core"]',
      '    c2["<b>core</b><br/><small>in: core.rb</small><br/>uses no other component"]',
      '    n_g0["<b>project-wide</b><br/>no cycles among: ui, core"]:::note',
      "  end",
      '  subgraph g1["preset :ruby_conventions"]',
      '    n_g1["<b>project-wide</b><br/>instance methods matching /\\A(get|set)_/: forbidden<br/>instance methods matching /\\Ais_/: forbidden<br/>class methods matching /\\A(get|set)_/: forbidden<br/>class methods matching /\\Ais_/: forbidden"]:::note',
      "  end",
      "  c1 --> c2",
      "  linkStyle 0 stroke:#2f9e44,stroke-width:2px",
      "  classDef note fill:none,stroke-dasharray:2 2"
    ], output.lines.map(&:chomp)
  end

  def test_undeclared_and_empty_components_get_their_classes
    output = flow(<<~RUBY)
      component :a, in: "a.rb"
      a.must_be_empty
      rule ArchSpec::Rules::ForbidDependenciesRule.new(:a, [:ghost])
    RUBY

    assert_includes output, '  c0["<b>a</b><br/><small>in: a.rb</small><br/>must be empty"]:::empty'
    assert_includes output, '  c1["<b>ghost</b>"]:::undeclared'
    assert_equal ["  classDef empty stroke-dasharray:4 3,opacity:0.6", "  classDef undeclared stroke-dasharray:2 2,fill:none"],
                 output.lines.map(&:chomp).grep(/classDef/)
  end

  def test_rendering_is_deterministic
    source = File.read(File.join(FIXTURES, "kitchen_sink", "Archspec.rb"))

    assert_equal flow(source), flow(source)
  end

  def test_an_unknown_link_kind_fails_loudly
    architecture = load_architecture('component :a, in: "a.rb"')
    bad = Architecture::Clause.new(subject: :a, summary: nil, reason: nil, origin: nil, empty: false,
                                   links: [Architecture::Link.new(from: :a, to: :a, kind: :mystery)])

    assert_raises(KeyError) { Flowchart.new(architecture.with(clauses: [bad]), Options.new).to_s }
  end

  def test_legend_lists_only_kinds_in_the_diagram
    architecture = load_architecture(<<~RUBY)
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      a.cannot_use :b
    RUBY

    assert_equal [["dashed red arrow ending in a cross", "the source must not use the target"]],
                 Flowchart.new(architecture, Options.new).legend
  end

  def test_every_link_kind_defines_each_field
    Flowchart::LINKS.each_value do |row|
      assert_equal %i[arrow label legend look style], row.keys.sort
    end
  end
end
