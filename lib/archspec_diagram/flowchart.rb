require "set"

module ArchspecDiagram
  class Flowchart
    LINKS = {
      allow:           { arrow: "-->", label: nil, style: "stroke:#2f9e44,stroke-width:2px",
                         look: "green arrow",
                         legend: "allowlist: the source may use only components it points to" },
      consumer:        { arrow: "==>", label: "only consumer", style: "stroke:#1971c2,stroke-width:2px",
                         look: "thick blue arrow",
                         legend: "audience: only the sources pointing here may use the target" },
      forbid:          { arrow: "-.-x", label: "cannot use", style: "stroke:#e03131,stroke-width:1.5px,stroke-dasharray:5 4",
                         look: "dashed red arrow ending in a cross",
                         legend: "the source must not use the target" },
      forbid_constant: { arrow: "-.-x", label: "cannot reference", style: "stroke:#e03131,stroke-width:1.5px,stroke-dasharray:5 4",
                         look: "dashed red arrow to a red hexagon",
                         legend: "the source must not reference the constant" }
    }.freeze

    CLASS_DEFS = {
      empty: "stroke-dasharray:4 3,opacity:0.6",
      undeclared: "stroke-dasharray:2 2,fill:none",
      constant: "fill:none,stroke:#e03131,color:#e03131",
      note: "fill:none,stroke-dasharray:2 2"
    }.freeze

    Edge = Data.define(:from, :to, :kind, :label)
    Constant = Architecture::Constant
    private_constant :Edge, :Constant

    def initialize(architecture, options)
      @architecture = architecture
      @options = options
      @component_ids = architecture.components.keys.each_with_index.to_h { |name, index| [name, "c#{index}"] }
      constants = architecture.clauses.flat_map(&:links).map(&:to).grep(Constant).uniq
      @constant_ids = constants.each_with_index.to_h { |constant, index| [constant, "k#{index}"] }
      @classes = Set.new
    end

    def to_s
      @to_s ||= begin
        edges = merged_edges
        lines = ["flowchart #{@options.direction}"]
        lines.concat(group_lines)
        @classes << :constant unless @constant_ids.empty?
        lines.concat(@constant_ids.map { |constant, id| "  #{id}{{\"#{text(constant.name)}\"}}:::constant" })
        lines.concat(edges.map { edge_line(_1) })
        lines.concat(link_style_lines(edges))
        lines.concat(class_def_lines)
        lines.join("\n")
      end
    end

    def legend
      present = @architecture.clauses.flat_map(&:links).map(&:kind).uniq
      LINKS.slice(*present).values.map { [_1[:look], _1[:legend]] }
    end

    private

    def group_lines
      buckets = Hash.new { |hash, origin| hash[origin] = { components: [], notes: [] } }
      @architecture.components.each_value { buckets[_1.origin][:components] << _1 }
      @architecture.clauses.select(&:project_wide?).each { buckets[_1.origin][:notes] << _1 }

      group_index = -1
      buckets.flat_map do |origin, bucket|
        group = "g#{group_index += 1}" if origin
        notes = @options.detail_at_least?(:rules) ? bucket[:notes].reject(&:drawn_as_links_only?) : []
        nodes = bucket[:components].map { |component| node(component) }
        nodes << note_node(group, origin ? "project-wide" : "project rules", notes) unless notes.empty?
        next [] if nodes.empty?
        next nodes.map { "  #{_1}" } unless origin

        ["  subgraph #{group}[\"#{text(origin.label)}\"]", *nodes.map { "    #{_1}" }, "  end"]
      end
    end

    def node(component)
      clauses = @architecture.clauses.select { _1.subject == component.name }
      parts = ["<b>#{text(component.name)}</b>"]
      if @options.detail_at_least?(:rules)
        parts.concat(component.selectors.map { "<small>#{text(_1)}</small>" })
        parts.concat(clauses.filter_map { clause_line(_1) })
      end
      klass = if !component.declared then :undeclared elsif clauses.any?(&:empty) then :empty end
      @classes << klass if klass
      "#{@component_ids.fetch(component.name)}[\"#{parts.join('<br/>')}\"]#{":::#{klass}" if klass}"
    end

    def note_node(group, title, clauses)
      @classes << :note
      parts = ["<b>#{title}</b>", *clauses.map { clause_line(_1) }]
      "n_#{group || 'top'}[\"#{parts.join('<br/>')}\"]:::note"
    end

    def clause_line(clause)
      return if clause.drawn_as_links_only?

      line = text(clause.summary)
      line += "<br/><i>because #{text(clause.reason)}</i>" if clause.reason && @options.detail_at_least?(:reasons)
      line
    end

    def merged_edges
      entries = @architecture.clauses.flat_map do |clause|
        reason = clause.reason if clause.drawn_as_links_only? && @options.detail_at_least?(:reasons)
        clause.links.map { |link| [link, reason] }
      end

      entries.group_by { |link, _| [link.from, link.to] }.flat_map do |(from, to), pair|
        fold_consumer_into_allow(pair.group_by { |link, _| link.kind }).map do |kind, (group, base)|
          reasons = group.filter_map(&:last).uniq.join("; ")
          label = [base, (reasons unless reasons.empty?)].compact.join(": ")
          Edge.new(from:, to:, kind:, label: label.empty? ? nil : label)
        end
      end
    end

    def fold_consumer_into_allow(by_kind)
      consumer = by_kind.key?(:allow) && by_kind.delete(:consumer)
      by_kind.to_h do |kind, group|
        group += consumer if consumer && kind == :allow
        base = consumer && kind == :allow ? LINKS.fetch(:consumer)[:label] : LINKS.fetch(kind)[:label]
        [kind, [group, base]]
      end
    end

    def edge_line(edge)
      arrow = LINKS.fetch(edge.kind)[:arrow]
      target = edge.to.is_a?(Constant) ? @constant_ids.fetch(edge.to) : @component_ids.fetch(edge.to)
      label = "|\"#{text(edge.label)}\"|" if edge.label
      "  #{@component_ids.fetch(edge.from)} #{arrow}#{label} #{target}"
    end

    def link_style_lines(edges)
      edges.each_with_index.group_by { |edge, _| LINKS.fetch(edge.kind)[:style] }.map do |style, group|
        "  linkStyle #{group.map(&:last).join(',')} #{style}"
      end
    end

    def class_def_lines = CLASS_DEFS.slice(*@classes).map { |name, style| "  classDef #{name} #{style}" }

    # Text inside ["…"] and edge labels: & < > " # ` become #amp; #lt; #gt;
    # #quot; #35; #96;, and line breaks become a space. Backticks matter
    # because a leading one turns the label into a Mermaid markdown string.
    def text(string)
      string.to_s.gsub(/\R/, " ").gsub(/[&<>"#]/) { "##{ESCAPES.fetch(_1)};" }
    end

    ESCAPES = { "&" => "amp", "<" => "lt", ">" => "gt", '"' => "quot", "#" => "35", "`" => "96" }.freeze
    private_constant :ESCAPES
  end
end
