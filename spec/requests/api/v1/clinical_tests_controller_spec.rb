# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::ClinicalTestsController", type: :request do
  let(:case_record) { create(:case) }
  let(:mandate) { create(:mandate) }

  def parsed_body
    JSON.parse(response.body)
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
  end

  describe "PATCH /api/v1/clinical_tests/:id/transition_workflow" do
    let(:current_user) { nil }

    it "returns 200 for a valid workflow transition" do
      clinical_test = create(
        :clinical_test,
        :tier0,
        case: case_record,
        mandate: mandate,
        workflow_state: "scored",
        result_state: "machine_scored"
      )

      patch "/api/v1/clinical_tests/#{clinical_test.id}/transition_workflow", params: {
        clinical_test: { target_state: "completed" }
      }

      expect(response).to have_http_status(:ok)
      expect(parsed_body.dig("clinical_test", "workflow_state")).to eq("completed")
    end

    it "returns 422 with invalid_transition for an impossible transition" do
      clinical_test = create(:clinical_test, case: case_record, mandate: mandate, workflow_state: "draft")

      patch "/api/v1/clinical_tests/#{clinical_test.id}/transition_workflow", params: {
        clinical_test: { target_state: "completed" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(parsed_body["success"]).to eq(false)
      expect(parsed_body["error_code"]).to eq("invalid_transition")
      expect(parsed_body["message"]).to eq("Cannot transition from draft to completed")
    end
  end

  describe "GET /api/v1/clinical_tests/:id" do
    let(:current_user) { nil }

    it "serializes diagnosis_band as explicit null for the R17 retest scenario" do
      clinical_test = create(
        :clinical_test,
        case: case_record,
        mandate: mandate,
        workflow_state: "scored",
        result_state: "machine_scored",
        aps_score: nil,
        ops_score: nil,
        ips_score: nil,
        composite_score: nil,
        diagnosis_band: nil,
        diagnosis_flags: ["retest_required"],
        machine_diagnosis: {
          "band" => nil,
          "flags" => ["retest_required"],
          "rule_paths_applied" => ["R17"]
        }
      )

      get "/api/v1/clinical_tests/#{clinical_test.id}"

      expect(response).to have_http_status(:ok)
      expect(parsed_body.fetch("clinical_test")).to have_key("diagnosis_band")
      expect(parsed_body.dig("clinical_test", "diagnosis_band")).to be_nil
      expect(parsed_body.dig("clinical_test", "diagnosis_flags")).to include("retest_required")
    end
  end

  describe "POST /api/v1/clinical_tests/:id/review" do
    let(:reviewer) { create(:user) }
    let(:current_user) { create(:user) }

    it "returns 403 for unauthorized reviewer access" do
      clinical_test = create(
        :clinical_test,
        :tier1,
        :scored,
        case: case_record,
        mandate: mandate,
        reviewer: reviewer,
        workflow_state: "scored",
        result_state: "machine_scored"
      )

      post "/api/v1/clinical_tests/#{clinical_test.id}/review", params: {
        clinical_test: {
          adjustment_reason: "Override attempt",
          adjusted_values: { composite_score: 85.0 },
          original_machine_values: { composite_score: 79.69 }
        }
      }

      expect(response).to have_http_status(:forbidden)
      expect(parsed_body["success"]).to eq(false)
      expect(parsed_body["error_code"]).to eq("forbidden")
      expect(parsed_body["message"]).to eq("Reviewer access denied")
    end
  end
end
