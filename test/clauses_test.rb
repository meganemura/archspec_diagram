require_relative "test_helper"

class ClausesTest < Minitest::Test
  include DiagramHelpers

  def summaries(source)
    load_architecture(source).clauses.map(&:summary)
  end

  def test_dependency_rules_become_links_pointing_from_the_depending_side
    architecture = load_architecture(<<~RUBY)
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      component :c, in: "c.rb"
      a.can_only_use :b
      b.cannot_use :c
      c.can_only_be_used_by :a
      a.cannot_reference_constants "Rails"
    RUBY

    assert_equal [
      [:a, "uses only: b", [[:a, :b, :allow]]],
      [:b, nil, [[:b, :c, :forbid]]],
      [:c, "used only by: a", [[:a, :c, :consumer]]],
      [:a, nil, [[:a, Architecture::Constant.new("Rails"), :forbid_constant]]]
    ], architecture.clauses.map { |c| [c.subject, c.summary, c.links.map { [_1.from, _1.to, _1.kind] }] }
  end

  def test_empty_allowlists_say_so
    assert_equal ["uses no other component", "used by no other component"], summaries(<<~RUBY)
      component :a, in: "a.rb"
      a.can_only_use
      a.can_only_be_used_by
    RUBY
  end

  def test_no_cycles_is_project_wide
    architecture = load_architecture(<<~RUBY)
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      no_cycles
      no_cycles among: %i[a b]
    RUBY

    assert_equal [[nil, "no cycles among all components"], [nil, "no cycles among: a, b"]],
                 architecture.clauses.map { [_1.subject, _1.summary] }
  end

  def test_method_rules_describe_receivers_arity_keywords_and_scope
    assert_equal [
      "cannot call render, params",
      "cannot call puts (bare calls only)",
      "cannot call find_by_sql on ActiveRecord::Base or its subclasses",
      "must implement #perform",
      "must implement .perform_later (arity 1, keywords: actor)",
      "must implement one of #perform, #call",
      "must implement one of .perform, .call",
      "cannot define save, destroy",
      "cannot do Thing.new(...).call"
    ], summaries(<<~RUBY)
      component :a, in: "a.rb"
      a.cannot_call :render, :params
      a.cannot_call :puts, receiver: :none
      a.cannot_call :find_by_sql, receiver: "ActiveRecord::Base"
      a.must_implement :perform
      a.must_implement :perform_later, scope: :class, arity: 1, keywords: :actor
      a.must_implement_one_of :perform, :call
      a.must_implement_one_of :perform, :call, scope: :class
      a.cannot_define :save, :destroy
      a.cannot_instantiate_and_invoke
    RUBY
  end

  def test_public_api_lists_only_the_parts_that_are_set
    assert_equal [
      "public API: a/public/*.rb",
      "public API: constants A::Api",
      "public API: a/p.rb; constants A::Api; namespace A::Public"
    ], summaries(<<~RUBY)
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      component :c, in: "c.rb"
      a.public_api "a/public/*.rb"
      b.public_api constants: "A::Api"
      c.public_api "a/p.rb", constants: "A::Api", namespace: "A::Public"
    RUBY
  end

  def test_naming_rules_cover_forbidden_requires_scope_except_and_project_wide
    architecture = load_architecture(<<~RUBY)
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      a.method_names.matching(/\\Awith_(?<base>.+)/).requires("without_%{base}")
      a.method_names(scope: :class).matching(/\\Aget_/).forbidden(except: %i[get_a get_b])
      a.method_names.matching(/\\Aon_(?<e>.+)/).requires("%{e}", on: b, scope: :class)
    RUBY

    assert_equal [
      'instance methods matching /\\Awith_(?<base>.+)/: require without_%{base}',
      'class methods matching /\\Aget_/: forbidden, except get_a, get_b',
      'instance methods matching /\\Aon_(?<e>.+)/: require %{e} on b (class side)'
    ], architecture.clauses.map(&:summary)
  end

  def test_other_component_rules
    assert_equal ["must be empty", "cannot reference its includers"], summaries(<<~RUBY)
      component :a, in: "a.rb"
      component :b, in: "b.rb"
      a.must_be_empty
      b.cannot_reference_includers
    RUBY
  end

  def test_empty_flag_and_reason
    clause = load_architecture(<<~RUBY).clauses.first
      component :a, in: "a.rb"
      a.must_be_empty(because: "behavior belongs on models")
    RUBY

    assert_equal [true, "behavior belongs on models"], [clause.empty, clause.reason]
  end

  def test_a_custom_rule_degrades_to_a_generic_clause
    custom = Class.new do
      def id = "custom.thing"
      def evaluate(_graph) = []
    end
    sourced = Class.new(custom) { def source = :a }

    clauses = [custom.new, sourced.new].map { Clauses.decode(_1, origin: nil) }

    assert_equal [[nil, "rule custom.thing"], [:a, "rule custom.thing"]], clauses.map { [_1.subject, _1.summary] }
  end

  def test_a_custom_rule_in_a_config_is_decoded_and_keeps_its_reason
    architecture = load_architecture(<<~RUBY)
      component :a, in: "a.rb"
      rule Class.new { def id = "x.y"; def evaluate(_) = [] }.new, because: "house rule"
    RUBY

    assert_equal [nil, "rule x.y", "house rule"], architecture.clauses.map { [_1.subject, _1.summary, _1.reason] }.last
  end
end
