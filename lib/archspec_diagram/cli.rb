require "optparse"

module ArchspecDiagram
  # usage: archspec_diagram [options] [PATH]
  # PATH is an Archspec.rb or a directory holding one (default ./Archspec.rb).
  # Exit 0 on success, 1 for a config or I/O problem, 2 for a usage error.
  # Every failure prints one line to stderr and never a backtrace.
  module CLI
    def self.start(argv, out: $stdout, err: $stderr)
      options = {}
      output = nil
      parser = OptionParser.new do |o|
        o.banner = "usage: archspec_diagram [options] [PATH]"
        o.on("-f", "--format FORMAT", "mermaid (default), markdown, html") { options[:format] = _1 }
        o.on("-d", "--direction DIR", "TB (default), BT, LR, RL") { options[:direction] = _1 }
        o.on("--detail LEVEL", "names, rules (default), reasons") { options[:detail] = _1 }
        o.on("--focus COMPONENT", "one component and its neighbours") { options[:focus] = _1 }
        o.on("-o", "--output FILE", "write here instead of stdout") { output = _1 }
        o.on("-v", "--version") { return out.puts(VERSION).then { 0 } }
        o.on("-h", "--help") { return out.puts(o).then { 0 } }
      end

      paths = parser.parse(argv)
      return usage_error(err, "expected one PATH") if paths.size > 1

      begin
        Options.new(**options)
      rescue Error => e
        return usage_error(err, e.message)
      end

      result = ArchspecDiagram.render(paths.first || "Archspec.rb", **options)
      output ? write_atomically(output, result) : out.write(result)
      0
    rescue OptionParser::ParseError => e
      usage_error(err, e.message)
    rescue Error, SystemCallError => e
      err.puts "archspec_diagram: #{e.message}"
      1
    end

    def self.usage_error(err, message)
      err.puts "archspec_diagram: #{message}"
      2
    end

    def self.write_atomically(path, content)
      temp = "#{path}.tmp-#{Process.pid}"
      File.write(temp, content)
      File.rename(temp, path)
    ensure
      File.delete(temp) if temp && File.exist?(temp)
    end
    private_class_method :usage_error, :write_atomically
  end
end
