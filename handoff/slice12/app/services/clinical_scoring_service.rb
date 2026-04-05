# frozen_string_literal: true

class ClinicalScoringService
  SCORING_VERSION = "1.0"
  SECTION_WEIGHTS = {
    aps: BigDecimal("0.40"),
    ops: BigDecimal("0.35"),
    ips: BigDecimal("0.25")
  }.freeze

  class << self
    def call(clinical_test)
      new(clinical_test).call
    end

    def compute_composite(section_scores)
      available = SECTION_WEIGHTS.select { |section, _weight| section_scores[section].present? }
      return [nil, {}] if available.empty?

      total_weight = available.values.sum
      normalized_weights = available.transform_values { |weight| weight / total_weight }

      composite = normalized_weights.sum do |section, normalized_weight|
        BigDecimal(section_scores.fetch(section).to_s) * normalized_weight
      end

      weights_used = normalized_weights.transform_values { |weight| weight.round(2).to_f }

      [round_score(composite), weights_used]
    end

    def round_score(value)
      return nil if value.nil?

      BigDecimal(value.to_s).round(2).to_f
    end
  end

  def initialize(clinical_test)
    @clinical_test = clinical_test
  end

  def call
    section_results = build_section_results
    section_scores = section_results.transform_values(&:fetch_score)
    composite_score, = self.class.compute_composite(section_scores)

    ClinicalTest.transaction do
      clinical_test.update!(
        aps_score: section_scores[:aps],
        ops_score: section_scores[:ops],
        ips_score: section_scores[:ips],
        composite_score: composite_score,
        scoring_version: SCORING_VERSION
      )

      clinical_test.transition_workflow_to!("scored") if clinical_test.workflow_state == "submitted"
    end

    clinical_test.reload
  end

  private

  attr_reader :clinical_test

  SectionResult = Struct.new(:score, :answered, :total, :status, keyword_init: true) do
    def fetch_score
      score
    end
  end

  def build_section_results
    ClinicalTest::SECTION_QUESTIONS.each_with_object({}) do |(section, questions), results|
      answered_values = questions.filter_map { |question_id| extract_answer_value(question_id) }
      threshold = ClinicalTest::SECTION_THRESHOLDS.fetch(section)

      results[section] = if answered_values.size < threshold
                           SectionResult.new(
                             score: nil,
                             answered: answered_values.size,
                             total: questions.size,
                             status: "insufficient"
                           )
                         else
                           score = (answered_values.sum / (answered_values.size * 5.0)) * 100.0
                           status = answered_values.size == questions.size ? "complete" : "partial"

                           SectionResult.new(
                             score: self.class.round_score(score),
                             answered: answered_values.size,
                             total: questions.size,
                             status: status
                           )
                         end
    end
  end

  def extract_answer_value(question_id)
    raw_value = clinical_test.normalized_answers[question_id]
    return if raw_value.nil?

    value = BigDecimal(raw_value.to_s)
    return unless value.between?(1, 5)

    value.to_f
  rescue ArgumentError
    nil
  end
end
