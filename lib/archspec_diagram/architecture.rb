module ArchspecDiagram
  class Architecture < Data.define(:title, :components, :clauses)
    Origin = Data.define(:seq, :verb, :preset, :options) do
      def label
        args = options.map { |key, value| "#{key}: #{brief(value)}" }
        ["#{verb} :#{preset}", *args].join(", ")
      end

      private

      def brief(value)
        case value
        when Hash then "{…}"
        when Array then "[…]"
        when String, Symbol then value.inspect
        else value.to_s
        end
      end
    end

    Component = Data.define(:name, :selectors, :origin, :declared)

    Constant = Data.define(:name)

    Link = Data.define(:from, :to, :kind)

    Clause = Data.define(:subject, :summary, :links, :reason, :origin, :empty) do
      def project_wide? = subject.nil?
      def drawn_as_links_only? = summary.nil?
    end

    def self.load(path)
      file = resolve(path)
      source = read(file, path)
      ledger = Ledger.new
      definition = ArchSpec::Definition.new
      definition.base_dir = File.dirname(file)
      definition.extend(ArchSpec::DSL::Context)
      definition.extend(ledger.tracking)
      evaluate(definition, source, file, path)

      clauses = definition.rules.map { Clauses.decode(_1, origin: ledger.rule_origin(_1)) }
      components = definition.component_specs.to_h do |name, spec|
        [name, Component.new(name:, selectors: selector_lines(spec), origin: ledger.component_origin(name), declared: true)]
      end
      add_undeclared(components, clauses)
      new(title: File.basename(File.dirname(file)), components:, clauses:)
    end

    def focus(name)
      name = name.to_sym
      unless components.key?(name)
        raise Error, "unknown component #{name.inspect} (known: #{components.keys.join(', ')})"
      end

      links = clauses.flat_map(&:links)
      keep = [name, *links.filter_map { _1.to if _1.from == name }, *links.filter_map { _1.from if _1.to == name }]
        .grep(Symbol).uniq
      kept_clauses = clauses.filter_map do |clause|
        next clause if clause.project_wide?
        next unless keep.include?(clause.subject)

        inside = clause.links.select { keep.include?(_1.from) && (_1.to.is_a?(Constant) || keep.include?(_1.to)) }
        next if inside.empty? && clause.drawn_as_links_only? && !clause.links.empty?

        clause.with(links: inside)
      end
      with(components: components.slice(*keep), clauses: kept_clauses)
    end

    def self.resolve(path)
      path = path.to_s
      file = File.directory?(path) ? File.join(path, "Archspec.rb") : path
      unless File.file?(file)
        raise Error, "could not load #{path}: #{File.directory?(path) ? 'no Archspec.rb in that directory' : 'no such file'}"
      end

      file
    end

    def self.read(file, path)
      File.read(file)
    rescue SystemCallError => e
      raise Error, "could not load #{path}: #{SystemCallError.new(e.errno).message}"
    end

    def self.evaluate(definition, source, file, path)
      definition.instance_eval(source, file)
      return unless definition.component_specs.empty? && definition.rules.empty?

      raise Error, "#{path} declares no components or rules"
    rescue Error
      raise
    rescue ScriptError, StandardError => e
      raise Error, "could not load #{path}: #{e.message.lines.map(&:strip).find { !_1.empty? } || e.class.name}"
    end

    def self.add_undeclared(components, clauses)
      clauses.each do |clause|
        names = [clause.subject, *clause.links.flat_map { [_1.from, _1.to] }].grep(Symbol)
        names.each do |name|
          components[name] ||= Component.new(name:, selectors: [], origin: clause.origin, declared: false)
        end
      end
    end

    def self.selector_lines(spec)
      [
        ["in", spec.file_patterns],
        ["except", spec.exclude_patterns],
        ["namespace", spec.namespaces],
        ["constants", spec.constants],
        ["descendants of", spec.ancestor_names]
      ].reject { |_, values| values.empty? }.map { |label, values| "#{label}: #{values.join(', ')}" }
    end

    private_class_method :resolve, :read, :evaluate, :add_undeclared, :selector_lines

    class Ledger
      def initialize
        @current = nil
        @seq = 0
        @rule_origins = {}.compare_by_identity
        @component_origins = {}
      end

      # Both entry points need wrapping: Context aliases preset to the
      # original architecture body, so overriding architecture alone misses
      # `preset :ruby_conventions`.
      def tracking
        ledger = self
        Module.new do
          define_method(:architecture) do |name, **options|
            ledger.within(:architecture, name, options) { super(name, **options) }
          end
          define_method(:preset) do |name, **options|
            ledger.within(:preset, name, options) { super(name, **options) }
          end
          define_method(:add_rule) do |rule|
            ledger.claim_rule(rule)
            super(rule)
          end
          define_method(:add_component) do |spec|
            ledger.claim_component(spec.name)
            super(spec)
          end
        end
      end

      def within(verb, name, options)
        outer = @current
        @current = Origin.new(seq: @seq += 1, verb:, preset: name.to_sym, options:)
        yield
      ensure
        @current = outer
      end

      def claim_rule(rule) = @rule_origins[rule] ||= @current
      def claim_component(name) = @component_origins.key?(name) || (@component_origins[name] = @current)
      def rule_origin(rule) = @rule_origins[rule]
      def component_origin(name) = @component_origins[name]
    end
    private_constant :Ledger
  end
end
