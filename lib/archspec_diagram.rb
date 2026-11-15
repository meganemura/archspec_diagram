# rbs_inline: enabled

require "archspec"
require_relative "archspec_diagram/version"

# The whole public surface: ArchspecDiagram.render, ArchspecDiagram::Error,
# and ArchspecDiagram::CLI for the executable. Everything else is a private
# constant, so callers cannot couple to the model or the Mermaid writer.
module ArchspecDiagram
  class Error < ArchSpec::Error; end

  Options = Data.define(
    :format, #: Symbol
    :direction, #: Symbol
    :detail, #: Symbol
    :focus #: Symbol?
  )

  class Options
    # @rbs!
    #   def self.new: (?format: String | Symbol, ?direction: String | Symbol, ?detail: String | Symbol, ?focus: String | Symbol | nil) -> instance
    #               | ...

    FORMATS = %i[mermaid markdown html].freeze #: Array[Symbol]
    DIRECTIONS = %i[TB BT LR RL].freeze #: Array[Symbol]
    DETAILS = %i[names rules reasons].freeze #: Array[Symbol]

    #: (?format: String | Symbol, ?direction: String | Symbol, ?detail: String | Symbol, ?focus: String | Symbol | nil) -> void
    def initialize(format: :mermaid, direction: :TB, detail: :rules, focus: nil)
      super(
        format: choose("format", format, FORMATS),
        direction: choose("direction", direction, DIRECTIONS),
        detail: choose("detail", detail, DETAILS),
        focus: focus&.to_sym
      )
    end

    #: (Symbol level) -> bool
    def detail_at_least?(level) = DETAILS.index(detail).to_i >= DETAILS.index(level).to_i

    private

    #: (String label, String | Symbol value, Array[Symbol] allowed) -> Symbol
    def choose(label, value, allowed)
      choice = allowed.find { _1.to_s.casecmp?(value.to_s) }
      return choice if choice

      expected = allowed.map(&:to_s)
      raise Error, "unknown #{label}: #{value} (expected #{expected.first(expected.size - 1).join(', ')} or #{expected.last})"
    end
  end

  # Reads the Archspec.rb at +path+ (or +path+/Archspec.rb for a directory)
  # and returns the diagram as a String. Raises Error with a one-line message
  # for every user-caused failure: bad options, unreadable or broken config,
  # unknown focus component.
  #: (?String path, **untyped options) -> String
  def self.render(path = "Archspec.rb", **options)
    opts = Options.new(**options)
    architecture = Architecture.load(path)
    architecture = architecture.focus(opts.focus) if opts.focus
    Document.new(Flowchart.new(architecture, opts), opts, title: architecture.title).to_s
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
