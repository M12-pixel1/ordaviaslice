# frozen_string_literal: true

require "rails_helper"

RSpec.describe ClinicalDiagnosisService do
  subject(:run_service) { described_class.call(clinical_test) }

  def answers_payload(aps_answered:, ops_answered:, ips_answered:, aps_value: 4, ops_value: 4, ips_value: 4)
    answers = {}
    ClinicalTest::SECTION_QUESTIONS[:aps].first(aps_answered).each { |question_id| answers[question_id] = aps_value }
    ClinicalTest::SECTION_QUESTIONS[:ops].first(ops_answered).each { |question_id| answers[question_id] = ops_value }
    ClinicalTest::SECTION_QUESTIONS[:ips].first(ips_answered).each { |question_id| answers[question_id] = ips_value }
    answers
  end

  def composite_for(aps, ops, ips)
    ClinicalScoringService.compute_composite(aps: aps, ops: ops, ips: ips).first
  end

  def build_test(aps:, ops:, ips:, aps_answered:, ops_answered:, ips_answered:, tier: :tier1, workflow_state: "scored", result_state: "pending")
    create(
      :clinical_test,
      tier,
      workflow_state: workflow_state,
      result_state: result_state,
      answers_json: answers_payload(
        aps_answered: aps_answered,
        ops_answered: ops_answered,
        ips_answered: ips_answered
      ),
      aps_score: aps,
      ops_score: ops,
      ips_score: ips,
      composite_score: composite_for(aps, ops, ips),
      scoring_version: "1.0",
      diagnosis_version: "0.9"
    )
  end

  describe "R1-R9 primary band rules" do
    it "applies R1 for green" do
      clinical_test = build_test(aps: 85.0, ops: 80.0, ips: 80.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_band).to eq("green")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R1")
    end

    it "applies R2 for yellow" do
      clinical_test = build_test(aps: 70.0, ops: 65.0, ips: 60.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_band).to eq("yellow")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R2")
    end

    it "applies R3 for orange and sets review_recommended" do
      clinical_test = build_test(aps: 50.0, ops: 50.0, ips: 50.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_band).to eq("orange")
      expect(clinical_test.diagnosis_flags).to include("review_recommended")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R3")
    end

    it "applies R4 for red and sets intervention_required" do
      clinical_test = build_test(aps: 20.0, ops: 30.0, ips: 40.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_band).to eq("red")
      expect(clinical_test.diagnosis_flags).to include("intervention_required")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R4")
    end

    it "applies R5 when APS is strong but OPS is critical" do
      clinical_test = build_test(aps: 85.0, ops: 30.0, ips: 70.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_band).to eq("yellow")
      expect(clinical_test.diagnosis_flags).to include("ops_critical")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R5")
    end

    it "applies R6 whenever APS is below 40" do
      clinical_test = build_test(aps: 35.0, ops: 90.0, ips: 90.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_band).to eq("red")
      expect(clinical_test.diagnosis_flags).to include("aps_intervention")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R6")
    end

    it "applies R7 when IPS is low but APS and OPS are both healthy" do
      clinical_test = build_test(aps: 70.0, ops: 70.0, ips: 30.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_band).to eq("orange")
      expect(clinical_test.diagnosis_flags).to include("ips_remediation")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R7")
    end

    it "applies R8 when any two sections are below 40" do
      clinical_test = build_test(aps: 35.0, ops: 35.0, ips: 80.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_band).to eq("red")
      expect(clinical_test.diagnosis_flags).to include("multi_system_failure")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R8")
    end

    it "applies R9 when all three sections are below 40" do
      clinical_test = build_test(aps: 35.0, ops: 30.0, ips: 20.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_band).to eq("red")
      expect(clinical_test.diagnosis_flags).to include("full_intervention")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R9")
    end
  end

  describe "R10-R17 additive and partial/insufficient rules" do
    it "applies R10 for partial APS answers" do
      clinical_test = build_test(aps: 80.0, ops: 70.0, ips: 70.0, aps_answered: 6, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_flags).to include("aps_partial")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R10")
    end

    it "applies R11 for insufficient APS answers" do
      clinical_test = build_test(aps: nil, ops: 70.0, ips: 70.0, aps_answered: 5, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_flags).to include("aps_insufficient")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R11")
    end

    it "applies R12 for partial OPS answers" do
      clinical_test = build_test(aps: 70.0, ops: 70.0, ips: 70.0, aps_answered: 15, ops_answered: 6, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_flags).to include("ops_partial")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R12")
    end

    it "applies R13 for insufficient OPS answers" do
      clinical_test = build_test(aps: 70.0, ops: nil, ips: 70.0, aps_answered: 15, ops_answered: 5, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_flags).to include("ops_insufficient")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R13")
    end

    it "applies R14 for partial IPS answers" do
      clinical_test = build_test(aps: 70.0, ops: 70.0, ips: 70.0, aps_answered: 15, ops_answered: 15, ips_answered: 4)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_flags).to include("ips_partial")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R14")
    end

    it "applies R15 for insufficient IPS answers" do
      clinical_test = build_test(aps: 70.0, ops: 70.0, ips: nil, aps_answered: 15, ops_answered: 15, ips_answered: 3)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_flags).to include("ips_insufficient")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R15")
    end

    it "applies R16 when one or two sections are nil and composite is re-weighted" do
      clinical_test = build_test(aps: nil, ops: nil, ips: 90.0, aps_answered: 5, ops_answered: 5, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_flags).to include("partial_assessment")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R16")
      expect(clinical_test.machine_diagnosis["composite"]["weights_used"]).to eq("ips" => 1.0)
    end

    it "applies R17 when all sections are nil" do
      clinical_test = build_test(aps: nil, ops: nil, ips: nil, aps_answered: 0, ops_answered: 0, ips_answered: 0)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_band).to be_nil
      expect(clinical_test.diagnosis_flags).to include("retest_required")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R17")
    end
  end

  describe "band boundaries and persistence" do
    it "treats 40.0 composite as orange when no higher-priority rule is present" do
      clinical_test = build_test(aps: 40.0, ops: 40.0, ips: 40.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_band).to eq("orange")
    end

    it "treats 60.0 composite as yellow" do
      clinical_test = build_test(aps: 60.0, ops: 60.0, ips: 60.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_band).to eq("yellow")
    end

    it "treats 80.0 composite as green when no section is below 60" do
      clinical_test = build_test(aps: 80.0, ops: 80.0, ips: 80.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_band).to eq("green")
    end

    it "persists diagnosis_version 1.0 and result_state machine_scored" do
      clinical_test = build_test(aps: 70.0, ops: 70.0, ips: 70.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_version).to eq("1.0")
      expect(clinical_test.result_state).to eq("machine_scored")
    end

    it "persists machine_diagnosis with section metadata and version stamps" do
      clinical_test = build_test(aps: 70.0, ops: 65.0, ips: 60.0, aps_answered: 15, ops_answered: 15, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.machine_diagnosis).to include(
        "scoring_version" => "1.0",
        "diagnosis_version" => "1.0",
        "band" => "yellow"
      )
      expect(clinical_test.machine_diagnosis["sections"]["aps"]).to include(
        "score" => 70.0,
        "answered" => 15,
        "total" => 15,
        "status" => "complete"
      )
    end
  end

  describe "tier-specific workflow outcomes" do
    it "auto-completes tier 0 after machine scoring" do
      clinical_test = build_test(
        aps: 80.0, ops: 80.0, ips: 80.0,
        aps_answered: 15, ops_answered: 15, ips_answered: 10,
        tier: :tier0
      )

      described_class.call(clinical_test)

      expect(clinical_test.reload.workflow_state).to eq("completed")
    end

    it "keeps tier 1 at scored pending expert review" do
      clinical_test = build_test(
        aps: 80.0, ops: 80.0, ips: 80.0,
        aps_answered: 15, ops_answered: 15, ips_answered: 10,
        tier: :tier1
      )

      described_class.call(clinical_test)

      expect(clinical_test.reload.workflow_state).to eq("scored")
    end

    it "keeps tier 2 at scored while preserving parent test linkage" do
      parent_test = create(:clinical_test, :tier2, :scored)
      clinical_test = build_test(
        aps: 75.0, ops: 75.0, ips: 75.0,
        aps_answered: 15, ops_answered: 15, ips_answered: 10,
        tier: :tier2
      )
      clinical_test.update!(parent_test: parent_test, case: parent_test.case, mandate: parent_test.mandate)

      described_class.call(clinical_test)

      expect(clinical_test.reload.workflow_state).to eq("scored")
      expect(clinical_test.parent_test_id).to eq(parent_test.id)
    end
  end

  describe "additive flag combinations" do
    it "combines a band rule with a partial flag and partial assessment" do
      clinical_test = build_test(aps: nil, ops: 65.0, ips: 65.0, aps_answered: 5, ops_answered: 6, ips_answered: 10)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_flags).to include("aps_insufficient", "ops_partial", "partial_assessment")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R2", "R11", "R12", "R16")
    end

    it "combines an orange band rule with remediation flags" do
      clinical_test = build_test(aps: 70.0, ops: 70.0, ips: 30.0, aps_answered: 15, ops_answered: 6, ips_answered: 4)

      described_class.call(clinical_test)

      expect(clinical_test.reload.diagnosis_flags).to include("ips_remediation", "ops_partial", "ips_partial")
      expect(clinical_test.machine_diagnosis["rule_paths_applied"]).to include("R7", "R12", "R14")
    end
  end
end
