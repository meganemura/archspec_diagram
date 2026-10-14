require_relative "test_helper"

class PublicApiTest < Minitest::Test
  include DiagramHelpers

  def test_internals_are_private_constants
    %i[Options Architecture Clauses Flowchart Document].each do |name|
      assert_raises(NameError, name.to_s) { eval("ArchspecDiagram::#{name}") }
    end
  end

  def test_errors_are_archspec_errors
    assert_operator ArchspecDiagram::Error, :<, ArchSpec::Error
  end

  def test_render_defaults_to_the_archspec_rb_in_the_working_directory
    with_config("component :a, in: 'a.rb'") do |path|
      Dir.chdir(File.dirname(path)) do
        assert_equal ArchspecDiagram.render(path), ArchspecDiagram.render
      end
    end
  end

  def test_render_rejects_bad_options_before_evaluating_the_config
    error = assert_raises(ArchspecDiagram::Error) { ArchspecDiagram.render("/nonexistent", format: :svg) }

    assert_equal "unknown format: svg (expected mermaid, markdown or html)", error.message
  end

  def test_render_focus_accepts_a_symbol_or_a_string
    with_config("component :a, in: 'a.rb'\ncomponent :b, in: 'b.rb'\na.cannot_use :b") do |path|
      assert_equal ArchspecDiagram.render(path, focus: :a), ArchspecDiagram.render(path, focus: "a")
    end
  end
end
