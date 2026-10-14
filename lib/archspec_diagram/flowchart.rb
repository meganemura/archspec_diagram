module ArchspecDiagram
  # Mermaid flowchart syntax for an Architecture: ids, escaping, groups,
  # arrows, styles. Owns no wording about rules; every visible sentence
  # comes from the Architecture it is given.
  class Flowchart
    # The only list of Link kinds: arrow syntax, edge label, linkStyle, and
    # legend sentence per kind. Rows are looked up with fetch, so a decoder
    # emitting a kind missing here fails the kitchen-sink render test.
    LINKS = {
      allow:           { arrow: "-->", label: nil, style: "stroke:#2f9e44,stroke-width:2px",
                         legend: "allowlist: the source may use only components it points to" },
      consumer:        { arrow: "==>", label: "only consumer", style: "stroke:#1971c2,stroke-width:2px",
                         legend: "audience: only the sources pointing here may use the target" },
      forbid:          { arrow: "-.-x", label: "cannot use", style: "stroke:#e03131,stroke-width:1.5px,stroke-dasharray:5 4",
                         legend: "the source must not use the target" },
      forbid_constant: { arrow: "-.-x", label: "cannot reference", style: "stroke:#e03131,stroke-width:1.5px,stroke-dasharray:5 4",
                         legend: "the source must not reference the constant" }
    }.freeze

    CLASS_DEFS = {
      empty: "stroke-dasharray:4 3,opacity:0.6",
      undeclared: "stroke-dasharray:2 2,fill:none",
      constant: "fill:none,stroke:#e03131,color:#e03131",
      note: "fill:none,stroke-dasharray:2 2"
    }.freeze

    def self.legend = LINKS.transform_values { _1[:legend] }

    def initialize(architecture, options)
      @architecture = architecture
      @options = options
    end

    # Deterministic for a given Architecture and Options: order follows
    # declaration order, so re-rendering an unchanged config is a no-op diff.
    def to_s
      raise NotImplementedError
      # TODO, emitting lines in this order:
      #   "flowchart #{direction}"
      #   groups = components and project-wide clauses bucketed by origin,
      #     in first-seen order; nil origin renders at top level.
      #     subgraph g_<seq>["<origin.label>"] … end
      #   inside each bucket: one node per component, then one note node
      #     n_<seq | top> holding that bucket's project-wide clause summaries
      #     (top-level note titled "project rules"; preset note "project-wide").
      #   constant nodes k_<id>{{"Name"}}:::constant, once per distinct constant.
      #   edges = merged_links, emitted in order, index i recorded per kind.
      #   one "linkStyle i,j,… <style>" line per kind present.
      #   classDef line per CLASS_DEFS entry actually used.
    end

    private

    # <b>name</b>, then at :rules detail <small>selector lines</small> and
    # each clause summary of this subject, then at :reasons detail
    # "<i>because …</i>" under its line. A clause whose summary is nil puts
    # its reason on its edges instead. Class :empty when any clause is empty,
    # :undeclared when the component is not declared.
    def node(component, clauses) = raise(NotImplementedError)

    # Links grouped by [from, to]. A pair carrying allow and consumer
    # collapses to one allow-styled edge labelled "only consumer"; any other
    # combination keeps one edge per kind, since allow+forbid on one pair is
    # a contradiction worth seeing.
    def merged_links = raise(NotImplementedError)

    # Injective: c_ then each [A-Za-z0-9] kept, "_" -> "__", any other
    # character -> "_<hex codepoint>_". After "_" the next char is "_" or a
    # hex digit, so decoding is unambiguous and `a-` vs `a_2d` stay apart.
    # Prefixes c_/k_/n_/g_ keep node kinds disjoint and dodge `end`.
    def id(prefix, name) = raise(NotImplementedError)

    # Text inside ["…"] and edge labels: & < > " # ` become #amp; #lt; #gt;
    # #quot; #35; #96;, and line breaks become a space. Backticks matter
    # because a leading one turns the label into a Mermaid markdown string.
    # Our own <b>/<br/>/<small> tags are appended after escaping.
    def text(string) = raise(NotImplementedError)
  end
end
