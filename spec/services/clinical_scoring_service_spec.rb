# frozen_string_literal: true

require "rails_helper"

RSpec.describe ClinicalScoringService do
  subject(:run_service) { described_class.call(clinical_test) }

  let(:clinical_test) { create(:clinical_test, :tier1, workflow_state: workflow_state, answers_json: answers_json) }
  let(:workflow_state) { "submitted" }
  let(:answers_json) { full_answers(5, 5, 5) }

  def full_answers(aps_value, ops_value, ips_value)
    answers = {}
    ClinicalTest::SECTION_QUESTIONS[:aps].each { |question_id| answers[question_id] = aps_value }
    ClinicalTest::SECTION_QUESTIONS[:ops].each { |question_id| answers[question_id] = ops_value }
    ClinicalTest::SECTION_QUESTIONS[:ips].each { |question_id| answers[question_id] = ips_value }
    answers
  end

  def partial_answers(aps_count:, aps_value:, ops_count:, ops_value:, ips_count:, ips_value:)
    answers = {}
    ClinicalTest::SECTION_QUESTIONS[:aps].first(aps_count).each { |question_id| answers[question_id] = aps_value }
    ClinicalTest::SECTION_QUESTIONS[:ops].first(ops_count).each { |question_id| answers[question_id] = ops_value }
    ClinicalTest::SECTION_QUESTIONS[:ips].first(ips_count).each { |question_id| answers[question_id] = ips_value }
    answers
  end

  it "computes 100.0 across all sections when all answers are 5" do
    run_service

    expect(clinical_test.reload.aps_score).to eq(100.0)
    expect(clinical_test.ops_score).to eq(100.0)
    expect(clinical_test.ips_score).to eq(100.0)
    expect(clinical_test.composite_score).to eq(100.0)
  end

  it "computes 20.0 when all answers are 1 according to the formula" do
    clinical_test.update!(answers_json: full_answers(1, 1, 1))

    run_service

    expect(clinical_test.reload.aps_score).to eq(20.0)
    expect(clinical_test.ops_score).to eq(20.0)
    expect(clinical_test.ips_score).to eq(20.0)
    expect(clinical_test.composite_score).to eq(20.0)
  end

  it "returns nil section scores and nil composite when every section is insufficient" do
    clinical_test.update!(
      answers_json: partial_answers(
        aps_count: 5, aps_value: 4,
        ops_count: 5, ops_value: 4,
        ips_count: 3, ips_value: 4
      )
    )

    run_service

    expect(clinical_test.reload.aps_score).to be_nil
    expect(clinical_test.ops_score).to be_nil
    expect(clinical_test.ips_score).to be_nil
    expect(clinical_test.composite_score).to be_nil
  end

  it "computes partial section scores once thresholds are met" do
    clinical_test.update!(
      answers_json: partial_answers(
        aps_count: 6, aps_value: 4,
        ops_count: 6, ops_value: 5,
        ips_count: 4, ips_value: 3
      )
    )

    run_service

    expect(clinical_test.reload.aps_score).to eq(80.0)
    expect(clinical_test.ops_score).to eq(100.0)
    expect(clinical_test.ips_score).to eq(60.0)
    expect(clinical_test.composite_score).to eq(84.0)
  end

  it "ignores client-provided score fields and overwrites them from answers_json" do
    clinical_test.update!(
      aps_score: 1.23,
      ops_score: 4.56,
      ips_score: 7.89,
      composite_score: 9.99,
      answers_json: full_answers(5, 4, 3)
    )

    run_service

    expect(clinical_test.reload.aps_score).to eq(100.0)
    expect(clinical_test.ops_score).to eq(80.0)
    expect(clinical_test.ips_score).to eq(60.0)
    expect(clinical_test.composite_score).to eq(83.0)
  end

  it "stamps scoring_version 1.0 on every computation" do
    clinical_test.update!(scoring_version: "0.9")

    run_service

    expect(clinical_test.reload.scoring_version).to eq("1.0")
  end

  it "transitions submitted tests to scored after computation" do
    expect { run_service }
      .to change { clinical_test.reload.workflow_state }
      .from("submitted")
      .to("scored")
  end

  it "does not force a workflow transition for draft records" do
    clinical_test.update!(workflow_state: "draft")

    run_service

    expect(clinical_test.reload.workflow_state).to eq("draft")
  end

  it "re-normalizes weights when ips is nil" do
    clinical_test.update!(
      answers_json: partial_answers(
        aps_count: 15, aps_value: 4,
        ops_count: 15, ops_value: 3,
        ips_count: 3, ips_value: 5
      )
    )

    run_service

    expect(clinical_test.reload.aps_score).to eq(80.0)
    expect(clinical_test.ops_score).to eq(60.0)
    expect(clinical_test.ips_score).to be_nil
    expect(clinical_test.composite_score).to eq(70.67)
  end

  it "re-normalizes weights when only one section is available" do
    clinical_test.update!(
      answers_json: partial_answers(
        aps_count: 15, aps_value: 4,
        ops_count: 5, ops_value: 4,
        ips_count: 3, ips_value: 4
      )
    )

    run_service

    expect(clinical_test.reload.aps_score).to eq(80.0)
    expect(clinical_test.ops_score).to be_nil
    expect(clinical_test.ips_score).to be_nil
    expect(clinical_test.composite_score).to eq(80.0)
  end

  it "supports a single answered section with the rest omitted" do
    clinical_test.update!(
      answers_json: partial_answers(
        aps_count: 0, aps_value: 0,
        ops_count: 15, ops_value: 2,
        ips_count: 0, ips_value: 0
      )
    )

    run_service

    expect(clinical_test.reload.aps_score).to be_nil
    expect(clinical_test.ops_score).to eq(40.0)
    expect(clinical_test.ips_score).to be_nil
    expect(clinical_test.composite_score).to eq(40.0)
  end

  it "ignores malformed answers outside the 1..5 range" do
    clinical_test.update!(
      answers_json: {
        "A1" => 4,
        "A2" => 6,
        "A3" => 0,
        "A4" => "oops",
        "B1" => 5,
        "C1" => nil
      }
    )

    run_service

    expect(clinical_test.reload.aps_score).to be_nil
    expect(clinical_test.ops_score).to be_nil
    expect(clinical_test.ips_score).to be_nil
    expect(clinical_test.composite_score).to be_nil
  end
end
