# rbs_inline: enabled

module ArchspecDiagram
  Architecture = Data.define(
    :title, #: String
    :components, #: Hash[Symbol, Architecture::Component]
    :clauses #: Array[Architecture::Clause]
  )

  class Architecture
    Origin = Data.define(
      :seq, #: Integer
      :verb, #: Symbol
      :preset, #: Symbol
      :options #: Hash[Symbol, untyped]
    )

    class Origin
      #: () -> String
      def label
        args = options.map { |key, value| "#{key}: #{brief(value)}" }
        ["#{verb} :#{preset}", *args].join(", ")
      end

      private

      #: (untyped value) -> String
      def brief(value)
        case value
        when Hash then "{…}"
        when Array then "[…]"
        when String, Symbol then value.inspect
        else value.to_s
        end
      end
    end

    Component = Data.define(
      :name, #: Symbol
      :selectors, #: Array[String]
      :origin, #: Origin?
      :declared #: bool
    )

    Constant = Data.define(
      :name #: String
    )

    Link = Data.define(
      :from, #: Symbol
      :to, #: Symbol | Constant
      :kind #: Symbol
    )

    Clause = Data.define(
      :subject, #: Symbol?
      :summary, #: String?
      :links, #: Array[Link]
      :reason, #: String?
      :origin, #: Origin?
      :empty #: bool
    )

    class Clause
      #: () -> bool
      def project_wide? = subject.nil?
      #: () -> bool
      def drawn_as_links_only? = summary.nil?
    end

    #: (String | Pathname path) -> Architecture
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
      new(title: File.basename(File.dirname(File.expand_path(file))), components:, clauses:)
    end

    #: (String | Symbol name) -> Architecture
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

    #: (String | Pathname path) -> String
    def self.resolve(path)
      path = path.to_s
      file = File.directory?(path) ? File.join(path, "Archspec.rb") : path
      unless File.file?(file)
        raise Error, "could not load #{path}: #{File.directory?(path) ? 'no Archspec.rb in that directory' : 'no such file'}"
      end

      file
    end

    #: (String file, String | Pathname path) -> String
    def self.read(file, path)
      File.read(file, encoding: "UTF-8")
    rescue SystemCallError => e
      raise Error, "could not load #{path}: #{SystemCallError.new(e.errno).message}"
    end

    #: (ArchSpec::Definition definition, String source, String file, String | Pathname path) -> void
    def self.evaluate(definition, source, file, path)
      definition.instance_eval(source, file)
      return unless definition.component_specs.empty? && definition.rules.empty?

      raise Error, "#{path} declares no components or rules"
    rescue Error
      raise
    rescue ScriptError, StandardError => e
      raise Error, "could not load #{path}: #{e.message.lines.map(&:strip).find { !_1.empty? } || e.class.name}"
    end

    #: (Hash[Symbol, Component] components, Array[Clause] clauses) -> void
    def self.add_undeclared(components, clauses)
      clauses.each do |clause|
        names = [clause.subject, *clause.links.flat_map { [_1.from, _1.to] }].grep(Symbol) #: Array[Symbol]
        names.each do |name|
          components[name] ||= Component.new(name:, selectors: [], origin: clause.origin, declared: false)
        end
      end
    end

    #: (ArchSpec::ComponentSpec spec) -> Array[String]
    def self.selector_lines(spec)
      lines = [
        ["in", spec.file_patterns],
        ["except", spec.exclude_patterns],
        ["namespace", spec.namespaces],
        ["constants", spec.constants],
        ["descendants of", spec.ancestor_names]
      ] #: Array[[String, Array[String]]]
      lines.reject { |_, values| values.empty? }.map { |label, values| "#{label}: #{values.join(', ')}" }
    end

    private_class_method :resolve, :read, :evaluate, :add_undeclared, :selector_lines

    class Ledger
      #: () -> void
      def initialize
        @current = nil #: Origin?
        @seq = 0
        origins = {} #: Hash[untyped, Origin?]
        @rule_origins = origins.compare_by_identity
        @component_origins = {} #: Hash[Symbol, Origin?]
      end

      # Both entry points need wrapping: Context aliases preset to the
      # original architecture body, so overriding architecture alone misses
      # `preset :ruby_conventions`.
      #: () -> Module
      def tracking
        ledger = self #: Ledger
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

      #: [T] (Symbol verb, String | Symbol name, Hash[Symbol, untyped] options) { () -> T } -> T
      def within(verb, name, options)
        outer = @current
        @current = Origin.new(seq: @seq += 1, verb:, preset: name.to_sym, options:)
        yield
      ensure
        @current = outer
      end

      #: (untyped rule) -> Origin?
      def claim_rule(rule) = @rule_origins[rule] ||= @current
      #: (Symbol name) -> (bool | Origin | nil)
      def claim_component(name) = @component_origins.key?(name) || (@component_origins[name] = @current)
      #: (untyped rule) -> Origin?
      def rule_origin(rule) = @rule_origins[rule]
      #: (Symbol name) -> Origin?
      def component_origin(name) = @component_origins[name]
    end
    private_constant :Ledger
  end
end
