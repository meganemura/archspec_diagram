module ArchspecDiagram
  module Clauses
    Link = Architecture::Link
    Constant = Architecture::Constant

    DECODERS = {
      ArchSpec::Rules::AllowDependenciesRule => lambda do |rule|
        {
          subject: rule.source,
          summary: rule.targets.empty? ? "uses no other component" : "uses only: #{list(rule.targets)}",
          links: rule.targets.map { Link.new(from: rule.source, to: _1, kind: :allow) }
        }
      end,
      ArchSpec::Rules::ForbidDependenciesRule => lambda do |rule|
        { subject: rule.source, links: rule.targets.map { Link.new(from: rule.source, to: _1, kind: :forbid) } }
      end,
      ArchSpec::Rules::AllowedConsumersRule => lambda do |rule|
        {
          subject: rule.source,
          summary: rule.consumers.empty? ? "used by no other component" : "used only by: #{list(rule.consumers)}",
          links: rule.consumers.map { Link.new(from: _1, to: rule.source, kind: :consumer) }
        }
      end,
      ArchSpec::Rules::CannotReferenceConstantsRule => lambda do |rule|
        {
          subject: rule.source,
          links: rule.constants.map { Link.new(from: rule.source, to: Constant.new(_1), kind: :forbid_constant) }
        }
      end,
      ArchSpec::Rules::NoCyclesRule => lambda do |rule|
        { subject: nil, summary: rule.components.empty? ? "no cycles among all components" : "no cycles among: #{list(rule.components)}" }
      end,
      ArchSpec::Rules::MustBeEmptyRule => ->(rule) { { subject: rule.source, summary: "must be empty", empty: true } },
      ArchSpec::Rules::ConcernIndependenceRule => ->(rule) { { subject: rule.source, summary: "cannot reference its includers" } },
      ArchSpec::Rules::PublicApiRule => lambda do |rule|
        parts = [
          (list(rule.file_patterns) unless rule.file_patterns.empty?),
          ("constants #{list(rule.constants)}" unless rule.constants.empty?),
          ("namespace #{list(rule.namespaces)}" unless rule.namespaces.empty?)
        ].compact
        { subject: rule.source, summary: ["public API", parts.join("; ")].reject(&:empty?).join(": ") }
      end,
      ArchSpec::Rules::CannotCallRule => lambda do |rule|
        receiver =
          case rule.receiver
          when :any then ""
          when :none then " (bare calls only)"
          else " on #{rule.receiver} or its subclasses"
          end
        { subject: rule.source, summary: "cannot call #{list(rule.method_names)}#{receiver}" }
      end,
      ArchSpec::Rules::MustImplementRule => lambda do |rule|
        extras = []
        extras << "arity #{rule.arity}" if rule.arity
        extras << "keywords: #{list(rule.keywords)}" unless rule.keywords.empty?
        summary = "must implement #{sigil(rule.scope)}#{rule.method_name}"
        summary += " (#{extras.join(', ')})" unless extras.empty?
        { subject: rule.source, summary: }
      end,
      ArchSpec::Rules::MustImplementOneOfRule => lambda do |rule|
        names = rule.method_names.map { "#{sigil(rule.scope)}#{_1}" }
        { subject: rule.source, summary: "must implement one of #{list(names)}" }
      end,
      ArchSpec::Rules::CannotDefineMethodRule => ->(rule) { { subject: rule.source, summary: "cannot define #{list(rule.method_names)}" } },
      ArchSpec::Rules::CannotInstantiateAndInvokeRule => ->(rule) { { subject: rule.source, summary: "cannot do Thing.new(...).call" } },
      ArchSpec::Rules::NamingRule => lambda do |rule|
        constraint = rule.instance_variable_get(:@constraint)
        phrase =
          case constraint
          when ArchSpec::Rules::Naming::Forbidden then "forbidden"
          when ArchSpec::Rules::Naming::Requires
            on = constraint.instance_variable_get(:@on)
            side = constraint.instance_variable_get(:@target_scope) == :class ? " (class side)" : ""
            "require #{constraint.instance_variable_get(:@template)}#{" on #{on}" if on}#{side}"
          else constraint.respond_to?(:id) ? constraint.id : "naming rule"
          end
        except = rule.except.empty? ? "" : ", except #{list(rule.except)}"
        {
          subject: rule.source,
          summary: "#{rule.scope} methods matching #{rule.selector.regex.inspect}: #{phrase}#{except}"
        }
      end
    }.freeze

    def self.decode(rule, origin:)
      attrs = DECODERS.fetch(rule.class) { method(:custom) }.call(rule)
      reason = rule.respond_to?(:archspec_because) ? rule.archspec_because : nil
      Architecture::Clause.new(subject: nil, summary: nil, links: [], empty: false, **attrs, reason:, origin:)
    end

    def self.custom(rule)
      {
        subject: (rule.source.to_sym if rule.respond_to?(:source) && rule.source),
        summary: "rule #{rule.respond_to?(:id) ? rule.id : rule.class.name}"
      }
    end

    def self.list(names) = names.to_a.join(", ")
    def self.sigil(scope) = scope == :class ? "." : "#"
  end
end
