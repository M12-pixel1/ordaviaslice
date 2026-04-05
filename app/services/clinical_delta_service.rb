# frozen_string_literal: true

class ClinicalDeltaService
  class VersionMismatchError < StandardError; end

  class << self
    def call(baseline_test, followup_test)
      new(baseline_test, followup_test).call
    end

    def compare(baseline_test, followup_test)
      call(baseline_test, followup_test)
    end
  end

  def initialize(baseline_test, followup_test)
    @baseline_test = baseline_test
    @followup_test = followup_test
  end

  def call
    validate_versions!

    {
      baseline_test_id: baseline_test.id,
      followup_test_id: followup_test.id,
      scoring_version: baseline_test.scoring_version,
      sections: {
        aps: delta_payload(:aps_score),
        ops: delta_payload(:ops_score),
        ips: delta_payload(:ips_score),
        composite: delta_payload(:composite_score)
      },
      machine: {
        baseline: baseline_test.machine_diagnosis,
        followup: followup_test.machine_diagnosis
      },
      expert: {
        baseline: baseline_test.expert_diagnosis,
        followup: followup_test.expert_diagnosis
      }
    }
  end

  private

  attr_reader :baseline_test, :followup_test

  def validate_versions!
    return if baseline_test.scoring_version == followup_test.scoring_version

    raise VersionMismatchError,
          "Cannot compare clinical tests with scoring_version #{baseline_test.scoring_version} and #{followup_test.scoring_version}"
  end

  def delta_payload(attribute_name)
    baseline_value = baseline_test.public_send(attribute_name)
    followup_value = followup_test.public_send(attribute_name)

    {
      baseline: value_to_float(baseline_value),
      followup: value_to_float(followup_value),
      delta: compute_delta(baseline_value, followup_value)
    }
  end

  def compute_delta(baseline_value, followup_value)
    return nil if baseline_value.nil? || followup_value.nil?

    (BigDecimal(followup_value.to_s) - BigDecimal(baseline_value.to_s)).round(2).to_f
  end

  def value_to_float(value)
    value.nil? ? nil : BigDecimal(value.to_s).round(2).to_f
  end
end
