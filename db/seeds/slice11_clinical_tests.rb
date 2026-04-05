# frozen_string_literal: true

# Usage:
#   load Rails.root.join("db/seeds/slice11_clinical_tests.rb")

cases = Case.includes(:mandates).order(:id).limit(3).to_a
raise "Slice 11 seeds require at least 3 existing Case records with Mandates" if cases.size < 3
raise "Slice 11 seeds require every selected Case to already have a Mandate" if cases.any? { |case_record| case_record.mandates.blank? }

reviewer = User.order(:id).first

seed_definitions = [
  { label: "tier0-draft", tier: :tier0, workflow_state: "draft", billing_state: "paid", result_state: "pending", answers_json: {} },
  { label: "tier0-submitted", tier: :tier0, workflow_state: "submitted", billing_state: "paid", result_state: "pending", answers_json: { "A1" => 4, "B1" => 4, "C1" => 4 } },
  { label: "tier0-completed", tier: :tier0, workflow_state: "completed", billing_state: "paid", result_state: "machine_scored", aps_score: 80.0, ops_score: 80.0, ips_score: 80.0, composite_score: 80.0, diagnosis_band: "green", report_generated_at: Time.current, answers_json: { "A1" => 4, "B1" => 4, "C1" => 4 } },

  { label: "tier1-draft", tier: :tier1, workflow_state: "draft", billing_state: "pending", result_state: "pending", answers_json: {} },
  { label: "tier1-scored", tier: :tier1, workflow_state: "scored", billing_state: "paid", result_state: "machine_scored", aps_score: 72.0, ops_score: 68.0, ips_score: 64.0, composite_score: 68.8, diagnosis_band: "yellow", answers_json: { "A1" => 4, "B1" => 4, "C1" => 4 } },
  { label: "tier1-reviewed", tier: :tier1, workflow_state: "reviewed", billing_state: "paid", result_state: "reviewed", aps_score: 72.0, ops_score: 68.0, ips_score: 64.0, composite_score: 68.8, diagnosis_band: "yellow", reviewer: reviewer, expert_diagnosis: { "adjusted_values" => { "composite_score" => 70.0 }, "adjustment_reason" => "Expert calibration." }, adjustment_reason: "Expert calibration.", answers_json: { "A1" => 4, "B1" => 4, "C1" => 4 } },

  { label: "tier2-baseline", tier: :tier2, workflow_state: "scored", billing_state: "active", result_state: "machine_scored", aps_score: 60.0, ops_score: 62.0, ips_score: 58.0, composite_score: 60.9, diagnosis_band: "yellow", answers_json: { "A1" => 3, "B1" => 3, "C1" => 3 } },
  { label: "tier2-followup", tier: :tier2, workflow_state: "submitted", billing_state: "active", result_state: "pending", answers_json: { "A1" => 5, "B1" => 4, "C1" => 4 } },
  { label: "tier2-completed", tier: :tier2, workflow_state: "completed", billing_state: "active", result_state: "published", aps_score: 84.0, ops_score: 79.0, ips_score: 81.0, composite_score: 81.0, diagnosis_band: "green", reviewer: reviewer, expert_diagnosis: { "adjusted_values" => { "composite_score" => 82.0 }, "adjustment_reason" => "Sprint close-out review." }, adjustment_reason: "Sprint close-out review.", report_generated_at: Time.current, answers_json: { "A1" => 5, "B1" => 4, "C1" => 4 } }
]

tier2_baseline = nil

ClinicalTest.transaction do
  seed_definitions.each_with_index do |definition, index|
    case_record = cases[index % cases.size]
    mandate = case_record.mandates.first

    attributes = definition.except(:label, :reviewer).merge(
      case: case_record,
      mandate: mandate,
      contact_email: "#{definition[:label]}@example.test",
      client_org: "Seeded Client #{index + 1}",
      agent_type: "operations_agent",
      biz_function: "support_automation",
      scoring_version: "1.0",
      diagnosis_version: "1.0",
      consent_version: "1.0",
      consented_at: Time.current
    )

    attributes[:reviewer] = definition[:reviewer] if definition.key?(:reviewer) && definition[:reviewer].present?

    record = ClinicalTest.create!(attributes)

    tier2_baseline ||= record if definition[:label] == "tier2-baseline"

    if definition[:label] == "tier2-followup" && tier2_baseline.present?
      record.update!(parent_test: tier2_baseline, case: tier2_baseline.case, mandate: tier2_baseline.mandate)
    end
  end
end
