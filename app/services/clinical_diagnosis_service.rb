# frozen_string_literal: true

class ClinicalDiagnosisService
  DIAGNOSIS_VERSION = "1.0"

  PRIMARY_RULES = [
    { code: "R17", predicate: :all_sections_null?, band: nil, flags: %w[retest_required] },
    { code: "R9", predicate: :all_three_sections_critical?, band: "red", flags: %w[full_intervention] },
    { code: "R8", predicate: :two_or_more_sections_critical?, band: "red", flags: %w[multi_system_failure] },
    { code: "R6", predicate: :aps_critical?, band: "red", flags: %w[aps_intervention] },
    { code: "R5", predicate: :ops_critical_despite_strong_aps?, band: "yellow", flags: %w[ops_critical] },
    { code: "R7", predicate: :ips_needs_remediation?, band: "orange", flags: %w[ips_remediation] },
    { code: "R4", predicate: :red_band?, band: "red", flags: %w[intervention_required] },
    { code: "R3", predicate: :orange_band?, band: "orange", flags: %w[review_recommended] },
    { code: "R2", predicate: :yellow_band?, band: "yellow", flags: [] },
    { code: "R1", predicate: :green_band?, band: "green", flags: [] }
  ].freeze

  class << self
    def call(clinical_test)
      new(clinical_test).call
    end
  end

  def initialize(clinical_test)
    @clinical_test = clinical_test
    @section_metadata = build_section_metadata
  end

  def call
    primary_rule = detect_primary_rule
    additive_rules = detect_additive_rules(primary_rule[:code])

    diagnosis_flags = (primary_rule[:flags] + additive_rules.flat_map { |rule| rule[:flags] }).uniq
    rule_paths_applied = [primary_rule[:code], *additive_rules.map { |rule| rule[:code] }].compact
    composite_score, weights_used = ClinicalScoringService.compute_composite(section_scores)

    ClinicalTest.transaction do
      clinical_test.update!(
        composite_score: composite_score,
        diagnosis_band: primary_rule[:band],
        diagnosis_flags: diagnosis_flags,
        diagnosis_version: DIAGNOSIS_VERSION,
        machine_diagnosis: machine_diagnosis_payload(
          composite_score: composite_score,
          weights_used: weights_used,
          band: primary_rule[:band],
          rule_paths_applied: rule_paths_applied,
          flags: diagnosis_flags
        )
      )

      clinical_test.transition_result_to!("machine_scored") if clinical_test.result_state == "pending"

      if clinical_test.workflow_state == "scored" && clinical_test.free_tier?
        clinical_test.transition_workflow_to!("completed")
      end
    end

    clinical_test.reload
  end

  private

  attr_reader :clinical_test, :section_metadata

  def build_section_metadata
    ClinicalTest::SECTION_QUESTIONS.each_with_object({}) do |(section, questions), result|
      answered = questions.count { |question_id| valid_answer?(clinical_test.normalized_answers[question_id]) }
      total = questions.size
      threshold = ClinicalTest::SECTION_THRESHOLDS.fetch(section)

      status =
        if answered < threshold
          "insufficient"
        elsif answered < total
          "partial"
        else
          "complete"
        end

      persisted_score = clinical_test.public_send("#{section}_score")
      score = persisted_score.nil? ? nil : persisted_score.to_f

      result[section] = {
        score: score,
        answered: answered,
        total: total,
        status: status
      }
    end
  end

  def detect_primary_rule
    PRIMARY_RULES.detect { |rule| public_send(rule[:predicate]) } || PRIMARY_RULES.last
  end

  def detect_additive_rules(primary_code)
    rules = []

    rules << additive_rule("R10", "aps_partial") if section_metadata.dig(:aps, :status) == "partial"
    rules << additive_rule("R11", "aps_insufficient") if section_metadata.dig(:aps, :status) == "insufficient"
    rules << additive_rule("R12", "ops_partial") if section_metadata.dig(:ops, :status) == "partial"
    rules << additive_rule("R13", "ops_insufficient") if section_metadata.dig(:ops, :status) == "insufficient"
    rules << additive_rule("R14", "ips_partial") if section_metadata.dig(:ips, :status) == "partial"
    rules << additive_rule("R15", "ips_insufficient") if section_metadata.dig(:ips, :status) == "insufficient"

    null_sections = section_scores.values.count(&:nil?)
    rules << additive_rule("R16", "partial_assessment") if null_sections.between?(1, 2) && primary_code != "R17"

    rules
  end

  def additive_rule(code, flag)
    { code: code, flags: [flag] }
  end

  def section_scores
    {
      aps: value_to_float(clinical_test.aps_score),
      ops: value_to_float(clinical_test.ops_score),
      ips: value_to_float(clinical_test.ips_score)
    }
  end

  def all_sections_null?
    section_scores.values.all?(&:nil?)
  end

  def all_three_sections_critical?
    section_scores.values.all? { |score| score.present? && score < 40.0 }
  end

  def two_or_more_sections_critical?
    section_scores.values.count { |score| score.present? && score < 40.0 } >= 2
  end

  def aps_critical?
    section_scores[:aps].present? && section_scores[:aps] < 40.0
  end

  def ops_critical_despite_strong_aps?
    section_scores[:aps].present? &&
      section_scores[:aps] >= 80.0 &&
      section_scores[:ops].present? &&
      section_scores[:ops] < 40.0
  end

  def ips_needs_remediation?
    section_scores[:ips].present? &&
      section_scores[:ips] < 40.0 &&
      section_scores[:aps].to_f >= 60.0 &&
      section_scores[:ops].to_f >= 60.0
  end

  def red_band?
    clinical_test.composite_score.present? && clinical_test.composite_score.to_f < 40.0
  end

  def orange_band?
    clinical_test.composite_score.present? &&
      clinical_test.composite_score.to_f >= 40.0 &&
      clinical_test.composite_score.to_f < 60.0
  end

  def yellow_band?
    clinical_test.composite_score.present? &&
      clinical_test.composite_score.to_f >= 60.0 &&
      clinical_test.composite_score.to_f < 80.0
  end

  def green_band?
    clinical_test.composite_score.present? &&
      clinical_test.composite_score.to_f >= 80.0 &&
      section_scores.values.compact.none? { |score| score < 60.0 }
  end

  def machine_diagnosis_payload(composite_score:, weights_used:, band:, rule_paths_applied:, flags:)
    {
      "scoring_version" => clinical_test.scoring_version,
      "diagnosis_version" => DIAGNOSIS_VERSION,
      "computed_at" => Time.current.iso8601,
      "sections" => section_metadata.transform_values do |metadata|
        {
          "score" => metadata[:score],
          "answered" => metadata[:answered],
          "total" => metadata[:total],
          "status" => metadata[:status]
        }
      end,
      "composite" => {
        "score" => composite_score,
        "weights_used" => weights_used
      },
      "band" => band,
      "rule_paths_applied" => rule_paths_applied,
      "flags" => flags
    }
  end

  def valid_answer?(raw_value)
    value = BigDecimal(raw_value.to_s)
    value.between?(1, 5)
  rescue ArgumentError
    false
  end

  def value_to_float(value)
    value.nil? ? nil : value.to_f
  end
end
