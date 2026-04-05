# frozen_string_literal: true

class ClinicalTest < ApplicationRecord
  class InvalidTransitionError < StandardError
    attr_reader :current, :target

    def initialize(current:, target:)
      @current = current
      @target = target

      super("Cannot transition from #{current} to #{target}")
    end
  end

  TIERS = {
    tier0: 0,
    tier1: 1,
    tier2: 2
  }.freeze

  WORKFLOW_STATES = %w[
    draft
    in_progress
    submitted
    scored
    reviewed
    completed
  ].freeze

  BILLING_STATES = %w[
    pending
    payment_pending
    paid
    active
    past_due
    cancelled
  ].freeze

  RESULT_STATES = %w[
    pending
    machine_scored
    reviewed
    published
  ].freeze

  RESULT_STATE_TRANSITIONS = {
    "pending" => {
      "machine_scored" => :scoring_completed?
    },
    "machine_scored" => {
      "reviewed" => :expert_review_submitted?,
      "published" => :report_published?
    },
    "reviewed" => {
      "published" => :report_published?
    },
    "published" => {}
  }.freeze

  SECTION_QUESTIONS = {
    aps: (1..15).map { |index| "A#{index}" },
    ops: (1..15).map { |index| "B#{index}" },
    ips: (1..10).map { |index| "C#{index}" }
  }.freeze

  SECTION_THRESHOLDS = {
    aps: 6,
    ops: 6,
    ips: 4
  }.freeze

  enum :tier, TIERS, scopes: false, validate: true

  belongs_to :case
  belongs_to :mandate
  belongs_to :parent_test, class_name: "ClinicalTest", optional: true
  belongs_to :reviewer, class_name: "User", optional: true

  has_many :child_tests,
           class_name: "ClinicalTest",
           foreign_key: :parent_test_id,
           inverse_of: :parent_test,
           dependent: :nullify

  validates :workflow_state, inclusion: { in: WORKFLOW_STATES }
  validates :billing_state, inclusion: { in: BILLING_STATES }
  validates :result_state, inclusion: { in: RESULT_STATES }
  validates :consented_at, :scoring_version, :diagnosis_version, :consent_version, presence: true

  validate :review_artifacts_present_when_reviewed
  validate :parent_test_belongs_to_same_case_and_mandate, if: :parent_test_id?

  def free_tier?
    tier == "tier0"
  end

  def paid_report_tier?
    tier == "tier1"
  end

  def sprint_tier?
    tier == "tier2"
  end

  def expert_review_required?
    paid_report_tier? || sprint_tier?
  end

  def transition_workflow_to!(target)
    target = target.to_s

    unless valid_workflow_transition?(target)
      raise InvalidTransitionError.new(current: workflow_state, target: target)
    end

    update!(workflow_state: target)
  end

  def transition_billing_to!(target)
    target = target.to_s

    unless valid_billing_transition?(target)
      raise InvalidTransitionError.new(current: billing_state, target: target)
    end

    update!(billing_state: target)
  end

  def transition_result_to!(target)
    target = target.to_s

    unless valid_result_transition?(target)
      raise InvalidTransitionError.new(current: result_state, target: target)
    end

    update!(result_state: target)
  end

  def answers_started?
    normalized_answers.any?
  end

  def answers_present?
    normalized_answers.any?
  end

  def scoring_completed?
    aps_score.present? || ops_score.present? || ips_score.present? || composite_score.present?
  end

  def expert_review_submitted?
    expert_review_required? && reviewer.present? && expert_diagnosis.present?
  end

  def report_published?
    result_state == "published" || report_generated_at.present?
  end

  def normalized_answers
    answers_json.is_a?(Hash) ? answers_json.compact : {}
  end

  def allowed_result_transitions
    RESULT_STATE_TRANSITIONS.fetch(result_state, {}).keys
  end

  private

  def valid_workflow_transition?(target)
    return false unless WORKFLOW_STATES.include?(target)

    case [workflow_state, target]
    when ["draft", "in_progress"]
      answers_started?
    when ["in_progress", "submitted"]
      answers_present?
    when ["submitted", "scored"]
      scoring_completed?
    when ["scored", "reviewed"]
      expert_review_submitted?
    when ["scored", "completed"]
      free_tier?
    when ["reviewed", "completed"]
      report_published?
    else
      false
    end
  end

  def valid_billing_transition?(target)
    return false unless BILLING_STATES.include?(target)

    case [billing_state, target]
    when ["pending", "payment_pending"]
      !free_tier?
    when ["pending", "paid"]
      free_tier?
    when ["payment_pending", "paid"]
      true
    when ["paid", "active"]
      sprint_tier?
    when ["active", "past_due"], ["active", "cancelled"]
      sprint_tier?
    when ["past_due", "active"], ["past_due", "cancelled"]
      sprint_tier?
    else
      false
    end
  end

  def valid_result_transition?(target)
    return false unless RESULT_STATES.include?(target)

    transition_guard = RESULT_STATE_TRANSITIONS.fetch(result_state, {}).fetch(target, nil)
    return false if transition_guard.nil?

    public_send(transition_guard)
  end

  def review_artifacts_present_when_reviewed
    return unless %w[reviewed completed].include?(workflow_state)
    return unless expert_review_required?

    errors.add(:reviewer, "must be present once expert review is completed") if reviewer.blank?
    errors.add(:expert_diagnosis, "must be present once expert review is completed") if expert_diagnosis.blank?
  end

  def parent_test_belongs_to_same_case_and_mandate
    return if parent_test.case_id == case_id && parent_test.mandate_id == mandate_id

    errors.add(:parent_test_id, "must belong to the same case and mandate")
  end
end
