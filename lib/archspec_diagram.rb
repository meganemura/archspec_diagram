require "archspec"
require_relative "archspec_diagram/version"

# The whole public surface: ArchspecDiagram.render, ArchspecDiagram::Error,
# and ArchspecDiagram::CLI for the executable. Everything else is a private
# constant, so callers cannot couple to the model or the Mermaid writer.
module ArchspecDiagram
  Error = Class.new(ArchSpec::Error)

  # The one validated bag of rendering choices. The CLI and library callers
  # both construct it through render, so option rules live here only.
  class Options < Data.define(:format, :direction, :detail, :focus)
    FORMATS = %i[mermaid markdown html].freeze
    DIRECTIONS = %i[TB BT LR RL].freeze
    # names: components and arrows. rules: plus selectors and rule lines.
    # reasons: plus every because: text.
    DETAILS = %i[names rules reasons].freeze

    def initialize(format: :mermaid, direction: :TB, detail: :rules, focus: nil)
      super(
        format: choose("format", format, FORMATS),
        direction: choose("direction", direction, DIRECTIONS),
        detail: choose("detail", detail, DETAILS),
        focus: focus&.to_sym
      )
    end

    def detail_at_least?(level) = DETAILS.index(detail) >= DETAILS.index(level)

    private

    def choose(label, value, allowed)
      choice = allowed.find { _1.to_s.casecmp?(value.to_s) }
      return choice if choice

      expected = allowed.map(&:to_s)
      raise Error, "unknown #{label}: #{value} (expected #{expected[..-2].join(', ')} or #{expected.last})"
    end
  end

  # Reads the Archspec.rb at +path+ (or +path+/Archspec.rb for a directory)
  # and returns the diagram as a String. Raises Error with a one-line message
  # for every user-caused failure: bad options, unreadable or broken config,
  # unknown focus component.
  def self.render(path = "Archspec.rb", **options)
    raise NotImplementedError
    # TODO:
    #   opts = Options.new(**options)            # fail before evaluating user code
    #   architecture = Architecture.load(path)
    #   architecture = architecture.focus(opts.focus) if opts.focus
    #   Document.new(Flowchart.new(architecture, opts), opts, title: architecture.title).to_s
  end
end

require_relative "archspec_diagram/architecture"
require_relative "archspec_diagram/clauses"
require_relative "archspec_diagram/flowchart"
require_relative "archspec_diagram/document"
require_relative "archspec_diagram/cli"

module ArchspecDiagram
  private_constant :Options, :Architecture, :Clauses, :Flowchart, :Document
end
