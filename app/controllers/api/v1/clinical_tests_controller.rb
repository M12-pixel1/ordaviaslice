# frozen_string_literal: true

module Api
  module V1
    class ClinicalTestsController < ApplicationController
      include ClinicalTestErrorRescuable

      before_action :set_clinical_test, only: %i[show transition_workflow transition_result review]
      before_action :authorize_reviewer_access!, only: :review

      # GET /api/v1/clinical_tests/:id
      def show
        render json: ClinicalTestResultSerializer.new(clinical_test).as_json, status: :ok
      end

      # PATCH /api/v1/clinical_tests/:id/transition_workflow
      def transition_workflow
        clinical_test.transition_workflow_to!(workflow_transition_params.fetch(:target_state))

        render json: ClinicalTestResultSerializer.new(clinical_test.reload).as_json, status: :ok
      end

      # PATCH /api/v1/clinical_tests/:id/transition_result
      def transition_result
        clinical_test.transition_result_to!(result_transition_params.fetch(:target_state))

        render json: ClinicalTestResultSerializer.new(clinical_test.reload).as_json, status: :ok
      end

      # POST /api/v1/clinical_tests/:id/review
      def review
        payload = review_params.to_h.deep_stringify_keys

        ClinicalTest.transaction do
          clinical_test.update!(
            reviewer: current_user,
            expert_diagnosis: payload,
            adjustment_reason: payload["adjustment_reason"]
          )

          clinical_test.transition_result_to!("reviewed") if clinical_test.result_state == "machine_scored"
          clinical_test.transition_workflow_to!("reviewed") if clinical_test.workflow_state == "scored"
        end

        render json: ClinicalTestResultSerializer.new(clinical_test.reload).as_json, status: :ok
      end

      private

      attr_reader :clinical_test

      def set_clinical_test
        @clinical_test = clinical_tests_scope.find(params[:id])
      end

      # Tenant-aware hook for Slice 01–10 scoping. Override with account/policy scope in host app.
      def clinical_tests_scope
        ClinicalTest.all
      end

      def authorize_reviewer_access!
        return if reviewer_authorized?

        render json: ClinicalTestErrorSerializer.forbidden(
          error_code: "forbidden",
          message: "Reviewer access denied"
        ), status: :forbidden
      end

      def reviewer_authorized?
        return false if current_user.blank?
        return true if current_user.respond_to?(:admin?) && current_user.admin?

        clinical_test.reviewer_id.present? && clinical_test.reviewer_id == current_user.id
      end

      def workflow_transition_params
        params.require(:clinical_test).permit(:target_state)
      end

      def result_transition_params
        params.require(:clinical_test).permit(:target_state)
      end

      def review_params
        params.require(:clinical_test).permit(
          :adjustment_reason,
          adjusted_values: {},
          original_machine_values: {}
        )
      end
    end
  end
end
