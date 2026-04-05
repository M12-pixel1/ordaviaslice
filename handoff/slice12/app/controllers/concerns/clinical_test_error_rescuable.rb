# frozen_string_literal: true

module ClinicalTestErrorRescuable
  extend ActiveSupport::Concern

  included do
    rescue_from ClinicalTest::InvalidTransitionError, with: :render_invalid_transition
  end

  private

  def render_invalid_transition(error)
    render json: ClinicalTestErrorSerializer.unprocessable_entity(
      error_code: "invalid_transition",
      message: error.message
    ), status: :unprocessable_entity
  end
end
