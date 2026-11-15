# rbs_inline: enabled

require "cgi"

module ArchspecDiagram
  class Document
    MERMAID_JS = "https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.esm.min.mjs" #: String

    #: (Flowchart flowchart, Options options, title: String) -> void
    def initialize(flowchart, options, title:)
      @flowchart = flowchart
      @options = options
      @title = title
    end

    #: () -> String
    def to_s
      case @options.format
      when :mermaid then "#{diagram}\n"
      when :markdown then markdown
      else html
      end
    end

    private

    #: () -> String
    def diagram = @flowchart.to_s

    #: () -> String
    def markdown
      fence = "`" * [3, longest_backtick_run + 1].max
      lines = ["## #{@title.gsub(/\R/, ' ')} architecture", "", "#{fence}mermaid", diagram, fence]
      unless legend.empty?
        lines.push("", "| Arrow | Meaning |", "| --- | --- |")
        lines.concat(legend.map { |look, meaning| "| #{look} | #{meaning} |" })
      end
      "#{lines.join("\n")}\n"
    end

    # Mermaid reads the element's textContent, so escaped tags come back as tags.
    #: () -> String
    def html
      items = legend.map { |look, meaning| "      <li><strong>#{CGI.escapeHTML(look)}</strong>: #{CGI.escapeHTML(meaning)}</li>" }
      <<~HTML
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>#{CGI.escapeHTML(@title)} architecture</title>
          <style>
            body { font-family: system-ui, sans-serif; margin: 2rem; }
            ul { line-height: 1.6; }
          </style>
        </head>
        <body>
          <h1>#{CGI.escapeHTML(@title)} architecture</h1>
          <pre class="mermaid">
        #{CGI.escapeHTML(diagram)}
          </pre>
        #{items.empty? ? '' : "  <ul>\n#{items.join("\n")}\n  </ul>\n"}  <script type="module">
            import mermaid from "#{MERMAID_JS}";
            mermaid.initialize({ startOnLoad: false });
            await mermaid.run();
          </script>
        </body>
        </html>
      HTML
    end

    #: () -> Array[[String, String]]
    def legend = @legend ||= @flowchart.legend

    #: () -> Integer
    def longest_backtick_run = diagram.scan(/`+/).map(&:length).max || 0
  end
end
