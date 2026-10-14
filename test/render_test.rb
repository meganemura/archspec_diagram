require_relative "test_helper"
require "open3"

class RenderTest < Minitest::Test
  include DiagramHelpers

  UPSTREAM = %w[archspec fizzy mastodon discourse rails_app].freeze
  GOLDEN = File.expand_path("golden", __dir__)

  def test_kitchen_sink_uses_every_link_kind_and_no_generic_fallback
    output = ArchspecDiagram.render(File.join(FIXTURES, "kitchen_sink"), detail: :reasons)

    Flowchart::LINKS.each_value do |row|
      assert_includes output, row[:label] || "-->", "no edge for #{row[:look]}"
    end
    assert_includes output, "-->", "no plain allowlist arrow"
    assert_includes output, "==>", "no consumer arrow"
    assert_includes output, "-.-x", "no forbid arrow"
    refute_match(/rule [a-z]+\.[a-z_]+/, output, "a rule fell back to the generic clause")
  end

  def test_kitchen_sink_covers_every_decoder
    architecture = Architecture.load(File.join(FIXTURES, "kitchen_sink"))
    summaries = architecture.clauses.map(&:summary).compact.join("\n")

    {
      "uses only:" => "AllowDependenciesRule", "uses no other" => "AllowDependenciesRule (empty)",
      "used only by:" => "AllowedConsumersRule", "no cycles among:" => "NoCyclesRule",
      "must be empty" => "MustBeEmptyRule", "cannot reference its includers" => "ConcernIndependenceRule",
      "public API:" => "PublicApiRule", "cannot call" => "CannotCallRule",
      "must implement #" => "MustImplementRule", "must implement one of" => "MustImplementOneOfRule",
      "cannot define" => "CannotDefineMethodRule", "Thing.new(...).call" => "CannotInstantiateAndInvokeRule",
      "forbidden" => "NamingRule forbidden", "require " => "NamingRule requires"
    }.each { |text, rule| assert_includes summaries, text, "kitchen sink has no #{rule}" }
    kinds = architecture.clauses.flat_map(&:links).map(&:kind).uniq.sort
    assert_equal Flowchart::LINKS.keys.sort, kinds
  end

  def test_names_that_collide_under_naive_sanitizing_stay_distinct_nodes
    output = render_source(<<~RUBY)
      component :"a-", in: "x.rb"
      component :a_2d, in: "y.rb"
      component :end, in: "z.rb"
      self.end.cannot_use :"a-", :a_2d
    RUBY

    assert_equal ['  c2 -.-x|"cannot use"| c0', '  c2 -.-x|"cannot use"| c1'], output.lines.map(&:chomp).grep(/-\.-x/)
    assert_equal 3, output.scan(/^  c\d\[/).uniq.size
  end

  def test_upstream_configs_match_golden_files
    UPSTREAM.each do |name|
      actual = ArchspecDiagram.render(File.join(FIXTURES, "upstream", name))
      golden = File.join(GOLDEN, "#{name}.mmd")
      File.write(golden, actual) if ENV["UPDATE_GOLDEN"]

      assert_equal File.read(golden, encoding: "UTF-8"), actual, "#{name} no longer matches test/golden/#{name}.mmd (UPDATE_GOLDEN=1 regenerates)"
    end
  end

  def test_kitchen_sink_matches_its_golden_file
    actual = ArchspecDiagram.render(File.join(FIXTURES, "kitchen_sink"), detail: :reasons)
    golden = File.join(GOLDEN, "kitchen_sink.mmd")
    File.write(golden, actual) if ENV["UPDATE_GOLDEN"]

    assert_equal File.read(golden, encoding: "UTF-8"), actual
  end

  def test_golden_files_parse_with_mermaid_cli
    mmdc = ENV["MMDC"]
    skip "set MMDC to the mmdc executable to check goldens parse" unless mmdc

    config = ENV["MMDC_PUPPETEER_CONFIG"]
    Dir.mktmpdir do |dir|
      Dir[File.join(GOLDEN, "*.mmd")].sort.each do |golden|
        args = [mmdc, *(["-p", config] if config), "-i", golden, "-o", File.join(dir, "#{File.basename(golden, '.mmd')}.svg")]
        _, stderr, status = Open3.capture3(*args)

        assert status.success?, "mmdc rejected #{File.basename(golden)}: #{stderr.lines.first(3).join}"
      end
    end
  end
end
