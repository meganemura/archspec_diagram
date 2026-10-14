require_relative "test_helper"

class DocumentTest < Minitest::Test
  include DiagramHelpers

  HOSTILE = <<~RUBY
    component :"</title>", in: "a.rb"
    component :"```", in: "b.rb"
    self.public_send(:"</title>").cannot_use :"```", because: "```\\n</script><b>"
  RUBY

  def test_mermaid_is_the_bare_diagram_with_a_trailing_newline
    output = render_source("component :a, in: 'a.rb'")

    assert_equal %(flowchart TB\n  c0["<b>a</b><br/><small>in: a.rb</small>"]\n), output
  end

  def test_markdown_wraps_the_diagram_and_adds_a_legend_of_the_kinds_present
    output = render_source("component :a, in: 'a.rb'\na.cannot_use :a", format: :markdown)
    lines = output.lines.map(&:chomp)

    assert_match(/\A## archspec_diagram\S* architecture\z/, lines.first)
    assert_equal "```mermaid", lines[2]
    assert_equal "flowchart TB", lines[3]
    assert_equal ["```", "", "| Arrow | Meaning |", "| --- | --- |",
                  "| dashed red arrow ending in a cross | the source must not use the target |"], lines.last(5)
  end

  def test_markdown_omits_the_legend_when_there_are_no_arrows
    output = render_source("component :a, in: 'a.rb'", format: :markdown)

    refute_includes output, "| Arrow |"
  end

  def test_markdown_fence_outgrows_backticks_in_the_diagram
    flowchart = Struct.new(:to_s, :legend).new("a ``` b ````` c", [])
    output = Document.new(flowchart, Options.new(format: :markdown), title: "t").to_s

    assert_equal "## t architecture\n\n``````mermaid\na ``` b ````` c\n``````\n", output
  end

  def test_html_is_a_standalone_page_with_the_escaped_diagram_and_the_pinned_script
    output = render_source("component :a, in: 'a.rb'\na.cannot_use :a", format: :html)

    assert_match(/\A<!doctype html>\n/, output)
    assert_includes output, %(<pre class="mermaid">\nflowchart TB\n  c0[&quot;&lt;b&gt;a&lt;/b&gt;)
    assert_includes output, 'import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.esm.min.mjs";'
    assert_includes output, "<li><strong>dashed red arrow ending in a cross</strong>: the source must not use the target</li>"
  end

  def test_hostile_names_and_reasons_cannot_break_out_in_any_format
    mermaid = render_source(HOSTILE, detail: :reasons)
    markdown = render_source(HOSTILE, detail: :reasons, format: :markdown)
    html = render_source(HOSTILE, detail: :reasons, format: :html)

    refute_includes mermaid, "`"
    refute_includes mermaid, "<script"
    assert_equal 2, markdown.lines.grep(/\A`{3}/).size
    assert_equal 1, html.scan("</title>").size
    assert_equal 1, html.scan("<script").size
    assert_equal 1, html.scan("</script>").size
    assert_includes html, "cannot use: #96;#96;#96; #lt;/script#gt;#lt;b#gt;"
  end
end
