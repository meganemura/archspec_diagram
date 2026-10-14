require_relative "test_helper"

class RuleCoverageTest < Minitest::Test
  def test_every_archspec_rule_class_has_a_decoder
    rule_classes = ArchSpec::Rules.constants.map { ArchSpec::Rules.const_get(_1) }
      .select { _1.is_a?(Class) && _1.method_defined?(:id) && _1.method_defined?(:evaluate) }
    decoded = ArchspecDiagram.const_get(:Clauses)::DECODERS.keys

    assert_empty rule_classes - decoded, "archspec rule classes without a decoder in clauses.rb"
  end
end
