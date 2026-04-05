# frozen_string_literal: true

require "rails_helper"

RSpec.describe ClinicalDeltaService do
  describe ".compare" do
    it "raises VersionMismatchError when scoring versions differ" do
      baseline_test = create(:clinical_test, :scored, scoring_version: "1.0")
      followup_test = create(:clinical_test, :scored, scoring_version: "2.0")

      expect { described_class.compare(baseline_test, followup_test) }
        .to raise_error(
          ClinicalDeltaService::VersionMismatchError,
          "Cannot compare clinical tests with scoring_version 1.0 and 2.0"
        )
    end

    it "returns a comparable delta hash for the Sprint 1 smoke path" do
      baseline_test = create(:clinical_test, :scored, aps_score: 60.0, ops_score: 50.0, ips_score: 40.0, composite_score: 52.5)
      followup_test = create(:clinical_test, :scored, aps_score: 70.0, ops_score: 55.0, ips_score: 50.0, composite_score: 60.75)

      delta = described_class.compare(baseline_test, followup_test)

      expect(delta).to include(
        baseline_test_id: baseline_test.id,
        followup_test_id: followup_test.id,
        scoring_version: "1.0"
      )
      expect(delta[:sections][:aps]).to eq(baseline: 60.0, followup: 70.0, delta: 10.0)
      expect(delta[:sections][:composite]).to eq(baseline: 52.5, followup: 60.75, delta: 8.25)
    end
  end
end
