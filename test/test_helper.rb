require "minitest/autorun"
require "tmpdir"
require_relative "../lib/archspec_diagram"

module DiagramHelpers
  Architecture = ArchspecDiagram.const_get(:Architecture)
  Clauses = ArchspecDiagram.const_get(:Clauses)
  Flowchart = ArchspecDiagram.const_get(:Flowchart)
  Options = ArchspecDiagram.const_get(:Options)

  FIXTURES = File.expand_path("fixtures", __dir__)

  def with_config(source, name: "Archspec.rb")
    Dir.mktmpdir("archspec_diagram") do |dir|
      path = File.join(dir, name)
      File.write(path, source)
      yield path
    end
  end

  def load_architecture(source)
    with_config(source) { |path| Architecture.load(path) }
  end

  def clause_for(architecture, subject, nth = 0)
    architecture.clauses.select { _1.subject == subject }.fetch(nth)
  end
end
