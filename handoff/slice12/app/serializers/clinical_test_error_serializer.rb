# frozen_string_literal: true

class ClinicalTestErrorSerializer
  class << self
    def unprocessable_entity(error_code:, message:)
      {
        success: false,
        error_code: error_code,
        message: message
      }
    end

    def forbidden(error_code:, message:)
      {
        success: false,
        error_code: error_code,
        message: message
      }
    end
  end
end
