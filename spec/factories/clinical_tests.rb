# frozen_string_literal: true

FactoryBot.define do
  sequence :clinical_test_full_answers do |n|
    answers = {}
    ClinicalTest::SECTION_QUESTIONS.each_value do |question_ids|
      question_ids.each_with_index do |question_id, index|
        answers[question_id] = ((n + index) % 5) + 1
      end
    end
    answers
  end

  factory :clinical_test do
    association :case
    association :mandate

    tier { :tier0 }
    workflow_state { "draft" }
    billing_state { "pending" }
    result_state { "pending" }
    scoring_version { "1.0" }
    diagnosis_version { "1.0" }
    consent_version { "1.0" }
    consented_at { Time.current }
    answers_json { {} }
    diagnosis_flags { [] }

    trait :tier0 do
      tier { :tier0 }
      billing_state { "paid" }
    end

    trait :tier1 do
      tier { :tier1 }
    end

    trait :tier2 do
      tier { :tier2 }
      billing_state { "active" }
    end

    trait :draft do
      workflow_state { "draft" }
      result_state { "pending" }
    end

    trait :submitted do
      workflow_state { "submitted" }
      answers_json { generate(:clinical_test_full_answers) }
    end

    trait :scored do
      workflow_state { "scored" }
      result_state { "machine_scored" }
      aps_score { 82.5 }
      ops_score { 76.25 }
      ips_score { 80.0 }
      composite_score { 79.69 }
      diagnosis_band { "yellow" }
      diagnosis_flags { [] }
      answers_json { generate(:clinical_test_full_answers) }
      machine_diagnosis do
        {
          "scoring_version" => "1.0",
          "diagnosis_version" => "1.0",
          "computed_at" => Time.current.iso8601
        }
      end
    end

    trait :reviewed do
      scored
      tier { :tier1 }
      workflow_state { "reviewed" }
      result_state { "reviewed" }
      association :reviewer, factory: :user
      expert_diagnosis do
        {
          "original_machine_values" => { "composite_score" => 79.69 },
          "adjusted_values" => { "composite_score" => 81.25 },
          "adjustment_reason" => "Expert escalation based on reviewer notes."
        }
      end
      adjustment_reason { "Expert escalation based on reviewer notes." }
    end

    trait :completed do
      scored
      workflow_state { "completed" }
      report_generated_at { Time.current }
    end

    trait :with_parent do
      transient do
        parent_factory_traits { %i[tier2 scored] }
      end

      after(:build) do |clinical_test, evaluator|
        clinical_test.parent_test ||= build(:clinical_test, *evaluator.parent_factory_traits)
        clinical_test.parent_test.case = clinical_test.case
        clinical_test.parent_test.mandate = clinical_test.mandate
      end
    end

    trait :with_reviewer do
      association :reviewer, factory: :user
    end

    trait :with_partial_answers do
      answers_json do
        answers = {}
        (1..6).each { |index| answers["A#{index}"] = 4 }
        (1..6).each { |index| answers["B#{index}"] = 3 }
        (1..6).each { |index| answers["C#{index}"] = 5 }
        answers
      end
    end

    trait :with_insufficient_answers do
      answers_json do
        answers = {}
        (1..5).each { |index| answers["A#{index}"] = 4 }
        (1..5).each { |index| answers["B#{index}"] = 3 }
        (1..3).each { |index| answers["C#{index}"] = 5 }
        answers
      end
    end

    trait :with_full_answers do
      answers_json { generate(:clinical_test_full_answers) }
    end

    sequence(:contact_email) { |n| "clinical-test-#{n}@example.test" }
  end
end
