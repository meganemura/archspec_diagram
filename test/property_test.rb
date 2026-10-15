require_relative "test_helper"

# hegeltest needs Ruby 3.4 or later, and this gem supports 3.2. The Gemfile
# installs it only where it can load, so on an older Ruby these tests skip.
begin
  require "hegel"
rescue LoadError
  nil
end

class PropertyTest < Minitest::Test
  include DiagramHelpers
  include Hegel::Syntax::Methods if defined?(Hegel)

  UNESCAPES = { "amp" => "&", "lt" => "<", "gt" => ">", "quot" => '"', "35" => "#", "96" => "`" }.freeze

  def setup
    skip "hegeltest needs Ruby 3.4 or later" unless defined?(Hegel)
  end

  # Keyed by the test name, so a local rerun of a failed test (the command
  # bulldogger prints) replays the stored counterexample first instead of
  # searching again. On CI the engine's ci profile leaves the database off and
  # derandomizes the run, so a rerun there reaches the same case anyway.
  def property(&)
    Hegel.test(database_key: name, &)
  end

  def test_label_text_carries_no_mermaid_syntax_and_unescapes_to_its_input
    escape = Flowchart.allocate.method(:text)
    property do |tc|
      input = tc.draw(text(max_size: 20))
      escaped = escape.call(input)

      refute_match(/[&<>"`\r\n\v\f\u0085  ]/, escaped)
      assert_equal input.gsub(/\R/, " "), escaped.gsub(/#(amp|lt|gt|quot|35|96);/) { UNESCAPES.fetch(Regexp.last_match(1)) }
    end
  end

  def test_every_component_is_one_node_and_every_edge_joins_two_nodes
    property do |tc|
      names = tc.draw(arrays(text(min_size: 1, max_size: 6), min_size: 1, max_size: 5)).uniq
      pairs = tc.draw(arrays(tuples(integers(min_value: 0, max_value: names.size - 1),
                                    integers(min_value: 0, max_value: names.size - 1)), max_size: 6))
      pairs = pairs.reject { |from, to| from == to }.uniq
      output = render_source(config_for(names, pairs))

      node_ids = output.scan(/^\s+(c\d+)\[/).flatten
      assert_equal names.size, node_ids.size
      assert_equal node_ids.uniq, node_ids

      edges = output.lines.grep(/-\.-x/)
      assert_equal pairs.size, edges.size
      edges.each do |line|
        from, to = line.chomp.match(/\A\s+(c\d+) .* (c\d+)\z/).captures
        assert_includes node_ids, from
        assert_includes node_ids, to
      end

      styled = output.scan(/^\s+linkStyle (\S+) /).flatten.flat_map { _1.split(",") }.map(&:to_i)
      assert_equal (0...edges.size).to_a, styled.sort
    end
  end

  private

  # Rules go through the proxy `component` returns, kept in a local, not
  # through the component's name: a name such as "then" calls Kernel#then
  # instead of reaching archspec's method_missing.
  def config_for(names, pairs)
    lines = names.each_with_index.map { |name, index| "c#{index} = component #{name.to_sym.inspect}, in: \"c#{index}/**/*.rb\"" }
    pairs.group_by(&:first).each do |from, group|
      targets = group.map { names.fetch(_2).to_sym.inspect }.join(", ")
      lines << "c#{from}.cannot_use #{targets}"
    end
    lines.join("\n")
  end
end
