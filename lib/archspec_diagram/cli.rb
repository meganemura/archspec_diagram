require "optparse"

module ArchspecDiagram
  # usage: archspec_diagram [options] [PATH]
  # PATH is an Archspec.rb or a directory holding one (default ./Archspec.rb).
  # Exit 0 on success, 1 for a config or I/O problem, 2 for a usage error.
  # Every failure prints one line to stderr and never a backtrace.
  module CLI
    def self.start(argv, out: $stdout, err: $stderr)
      raise NotImplementedError
      # TODO:
      #   options = {}
      #   parser = OptionParser.new do |o|
      #     o.banner = "usage: archspec_diagram [options] [PATH]"
      #     o.on("-f", "--format FORMAT", "mermaid (default), markdown, html") { options[:format] = _1 }
      #     o.on("-d", "--direction DIR", "TB (default), BT, LR, RL") { options[:direction] = _1 }
      #     o.on("--detail LEVEL", "names, rules (default), reasons") { options[:detail] = _1 }
      #     o.on("--focus COMPONENT", "one component and its neighbours") { options[:focus] = _1 }
      #     o.on("-o", "--output FILE", "write here instead of stdout") { output = _1 }
      #     o.on("-v", "--version") { out.puts VERSION; return 0 }
      #     o.on("-h", "--help") { out.puts o; return 0 }
      #   end
      #   paths = parser.parse(argv)                      # OptionParser::ParseError -> 2
      #   more than one path -> err "archspec_diagram: expected one PATH" ; 2
      #   result = ArchspecDiagram.render(paths.first || "Archspec.rb", **options)
      #     (values pass through as strings; Options is the only validator)
      #   output ? write_atomically(output, result) : out.write(result)
      #   rescue Error, SystemCallError => e: err.puts "archspec_diagram: #{e.message}"; 1
    end

    # Write to FILE.tmp-<pid> then rename, so a failed run leaves the old
    # diagram intact and a rerun simply replaces it.
    def self.write_atomically(path, content) = raise(NotImplementedError)
    private_class_method :write_atomically
  end
end
