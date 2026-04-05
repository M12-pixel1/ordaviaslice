# frozen_string_literal: true

class ClinicalTestResultSerializer
  def initialize(clinical_test)
    @clinical_test = clinical_test
  end

  def as_json(*)
    {
      clinical_test: {
        id: clinical_test.id,
        case_id: clinical_test.case_id,
        mandate_id: clinical_test.mandate_id,
        parent_test_id: clinical_test.parent_test_id,
        reviewer_id: clinical_test.reviewer_id,
        tier: clinical_test.tier,
        workflow_state: clinical_test.workflow_state,
        billing_state: clinical_test.billing_state,
        result_state: clinical_test.result_state,
        aps_score: decimal_or_nil(clinical_test.aps_score),
        ops_score: decimal_or_nil(clinical_test.ops_score),
        ips_score: decimal_or_nil(clinical_test.ips_score),
        composite_score: decimal_or_nil(clinical_test.composite_score),
        # IMPORTANT: diagnosis_band must serialize explicit nil for R17.
        # null means "retest required" and must never be omitted as if data were missing.
        diagnosis_band: clinical_test.diagnosis_band,
        diagnosis_flags: Array(clinical_test.diagnosis_flags),
        scoring_version: clinical_test.scoring_version,
        diagnosis_version: clinical_test.diagnosis_version,
        machine_diagnosis: clinical_test.machine_diagnosis,
        expert_diagnosis: clinical_test.expert_diagnosis,
        adjustment_reason: clinical_test.adjustment_reason,
        report_generated_at: iso8601_or_nil(clinical_test.report_generated_at),
        consented_at: iso8601_or_nil(clinical_test.consented_at),
        created_at: iso8601_or_nil(clinical_test.created_at),
        updated_at: iso8601_or_nil(clinical_test.updated_at)
      }
    }
  end

  private

  attr_reader :clinical_test

  def decimal_or_nil(value)
    value.nil? ? nil : value.to_f
  end

  def iso8601_or_nil(value)
    value&.iso8601
  end
end
