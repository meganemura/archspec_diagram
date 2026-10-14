require_relative "test_helper"
require "stringio"

class CLITest < Minitest::Test
  include DiagramHelpers

  CLI = ArchspecDiagram::CLI

  def run_cli(*argv)
    out = StringIO.new
    err = StringIO.new
    status = CLI.start(argv, out:, err:)
    [status, out.string, err.string]
  end

  def test_renders_a_path_to_stdout
    with_config("component :a, in: 'a.rb'") do |path|
      status, out, err = run_cli(path)

      assert_equal [0, ""], [status, err]
      assert_equal %(flowchart TB\n  c0["<b>a</b><br/><small>in: a.rb</small>"]\n), out
    end
  end

  def test_a_directory_works_and_options_reach_render
    with_config("component :a, in: 'a.rb'\ncomponent :b, in: 'b.rb'\na.cannot_use :b") do |path|
      _, out, = run_cli("-d", "LR", "--detail", "names", "--focus", "a", File.dirname(path))

      assert_equal <<~MERMAID, out
        flowchart LR
          c0["<b>a</b>"]
          c1["<b>b</b>"]
          c0 -.-x|"cannot use"| c1
          linkStyle 0 stroke:#e03131,stroke-width:1.5px,stroke-dasharray:5 4
      MERMAID
    end
  end

  def test_output_file_is_written_and_no_temp_file_remains
    with_config("component :a, in: 'a.rb'") do |path|
      target = File.join(File.dirname(path), "arch.md")

      status, out, = run_cli("-f", "markdown", "-o", target, path)

      assert_equal [0, ""], [status, out]
      assert_match(/\A## .* architecture\n/, File.read(target))
      assert_equal %w[Archspec.rb arch.md], Dir.children(File.dirname(path)).sort
    end
  end

  def test_a_failed_run_leaves_the_previous_output_intact
    with_config("component :a, in: 'a.rb'\nnope") do |path|
      target = File.join(File.dirname(path), "arch.mmd")
      File.write(target, "old diagram\n")

      status, = run_cli("-o", target, path)

      assert_equal 1, status
      assert_equal "old diagram\n", File.read(target)
      assert_equal %w[Archspec.rb arch.mmd], Dir.children(File.dirname(path)).sort
    end
  end

  def test_config_failures_are_one_line_and_exit_1
    {
      "component :a, in: 'a.rb'\nmodles.cannot_use :a" => /\Aarchspec_diagram: could not load \S*Archspec\.rb: undefined local variable or method .modles./,
      "component :a, in: (" => /\Aarchspec_diagram: could not load \S*Archspec\.rb: /,
      "# empty" => /\Aarchspec_diagram: \S*Archspec\.rb declares no components or rules\n\z/
    }.each do |source, pattern|
      with_config(source) do |path|
        status, out, err = run_cli(path)

        assert_equal [1, ""], [status, out], source
        assert_match pattern, err
        assert_equal 1, err.lines.size, err
      end
    end
  end

  def test_directory_without_a_config_and_a_missing_file
    Dir.mktmpdir do |dir|
      assert_equal [1, "archspec_diagram: could not load #{dir}: no Archspec.rb in that directory\n"], run_cli(dir).then { [_1, _3] }
    end
    assert_equal [1, "archspec_diagram: could not load nope.rb: no such file\n"], run_cli("nope.rb").then { [_1, _3] }
  end

  def test_unreadable_config
    with_config("component :a, in: 'a.rb'") do |path|
      File.chmod(0o000, path)
      skip "permissions are not enforced for this user" if File.readable?(path)

      status, _, err = run_cli(path)

      assert_equal [1, "archspec_diagram: could not load #{path}: Permission denied\n"], [status, err]
    end
  end

  def test_unknown_focus_exits_1_naming_the_known_components
    with_config("component :billing, in: 'b.rb'\ncomponent :catalog, in: 'c.rb'") do |path|
      status, _, err = run_cli("--focus", "biling", path)

      assert_equal [1, "archspec_diagram: unknown component :biling (known: billing, catalog)\n"], [status, err]
    end
  end

  def test_usage_errors_exit_2_with_one_line
    with_config("component :a, in: 'a.rb'") do |path|
      {
        ["-f", "svg", path] => "archspec_diagram: unknown format: svg (expected mermaid, markdown or html)\n",
        ["-d", "up", path] => "archspec_diagram: unknown direction: up (expected TB, BT, LR or RL)\n",
        ["--detail", "all", path] => "archspec_diagram: unknown detail: all (expected names, rules or reasons)\n",
        ["--bogus", path] => "archspec_diagram: invalid option: --bogus\n",
        ["-f"] => "archspec_diagram: missing argument: -f\n",
        [path, path] => "archspec_diagram: expected one PATH\n"
      }.each do |argv, message|
        status, out, err = run_cli(*argv)

        assert_equal [2, "", message], [status, out, err], argv.inspect
      end
    end
  end

  def test_version_and_help
    assert_equal [0, "#{ArchspecDiagram::VERSION}\n", ""], run_cli("--version")
    status, out, = run_cli("--help")

    assert_equal 0, status
    assert_match(/\Ausage: archspec_diagram \[options\] \[PATH\]\n/, out)
  end

  def test_the_executable_prints_one_line_and_no_backtrace
    exe = File.expand_path("../exe/archspec_diagram", __dir__)
    with_config("oops!(") do |path|
      output = IO.popen([RbConfig.ruby, exe, path], err: [:child, :out], &:read)

      assert_equal 1, output.lines.size
      assert_match(/\Aarchspec_diagram: could not load /, output)
      refute $?.success?
      assert_equal 1, $?.exitstatus
    end
  end
end
