require "minitest/autorun"
# bulldogger writes each failure, with the values in its frames, to
# tmp/bulldogger/ and prints the path and a rerun command. It needs Ruby 4.0,
# so the Gemfile installs it only there.
begin
  require "bulldogger/minitest"
rescue LoadError
  nil
end
require "tmpdir"
require_relative "../lib/archspec_diagram"

module DiagramHelpers
  Architecture = ArchspecDiagram.const_get(:Architecture)
  Clauses = ArchspecDiagram.const_get(:Clauses)
  Flowchart = ArchspecDiagram.const_get(:Flowchart)
  Options = ArchspecDiagram.const_get(:Options)
  Document = ArchspecDiagram.const_get(:Document)

  FIXTURES = File.expand_path("fixtures", __dir__)

  def with_config(source, name: "Archspec.rb")
    Dir.mktmpdir("archspec_diagram") do |dir|
      path = File.join(dir, name)
      File.write(path, source)
      yield path
    end
  end

  def render_source(source, **options)
    with_config(source) { |path| ArchspecDiagram.render(path, **options) }
  end

  def load_architecture(source)
    with_config(source) { |path| Architecture.load(path) }
  end

  def clause_for(architecture, subject, nth = 0)
    architecture.clauses.select { _1.subject == subject }.fetch(nth)
  end
end
