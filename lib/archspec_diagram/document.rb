require "cgi"

module ArchspecDiagram
  # Wraps a flowchart for its destination. mermaid: the bare diagram, for
  # pasting into GitHub, Notion, or mmdc. markdown: a fenced block plus a
  # legend table. html: a standalone page that renders in a browser.
  class Document
    MERMAID_JS = "https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.esm.min.mjs"

    def initialize(flowchart, options, title:)
      @flowchart = flowchart
      @options = options
      @title = title
    end

    def to_s
      raise NotImplementedError
      # TODO: case @options.format
      #   :mermaid  -> diagram + "\n"
      #   :markdown -> "## #{title} architecture", fence + "mermaid", diagram, fence,
      #                then a two-column legend table from Flowchart.legend
      #                (only kinds present, if Flowchart exposes them).
      #     fence = "`" * [3, longest backtick run in diagram + 1].max, so the
      #     fence holds even if escaping ever regresses.
      #   :html     -> <!doctype html> page; CGI.escapeHTML on the title and on
      #                the diagram inside <pre class="mermaid"> (mermaid reads
      #                textContent, so escaped tags come back as tags); legend
      #                as an HTML list; module script imports MERMAID_JS.
    end
  end
end
