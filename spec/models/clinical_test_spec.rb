# frozen_string_literal: true

require "rails_helper"

RSpec.describe ClinicalTest, type: :model do
  describe "validations" do
    it "rejects an invalid tier" do
      clinical_test = build(:clinical_test, tier: 99)

      expect(clinical_test).not_to be_valid
      expect(clinical_test.errors[:tier]).to be_present
    end

    it "requires consented_at" do
      clinical_test = build(:clinical_test, consented_at: nil)

      expect(clinical_test).not_to be_valid
      expect(clinical_test.errors[:consented_at]).to include("can't be blank")
    end

    it "requires workflow_state to be from the allow-list" do
      clinical_test = build(:clinical_test, workflow_state: "rogue_state")

      expect(clinical_test).not_to be_valid
      expect(clinical_test.errors[:workflow_state]).to be_present
    end

    it "requires reviewer and expert diagnosis once a paid review is completed" do
      clinical_test = build(:clinical_test, :tier1, workflow_state: "reviewed", reviewer: nil, expert_diagnosis: nil)

      expect(clinical_test).not_to be_valid
      expect(clinical_test.errors[:reviewer]).to be_present
      expect(clinical_test.errors[:expert_diagnosis]).to be_present
    end

    it "enforces parent lineage inside the same case and mandate" do
      parent_test = create(:clinical_test)
      other_case = create(:case)
      other_mandate = create(:mandate)

      clinical_test = build(:clinical_test, case: other_case, mandate: other_mandate, parent_test: parent_test)

      expect(clinical_test).not_to be_valid
      expect(clinical_test.errors[:parent_test_id]).to include("must belong to the same case and mandate")
    end
  end

  describe "workflow transitions" do
    subject(:clinical_test) { create(:clinical_test, :tier1, workflow_state: workflow_state, answers_json: answers_json) }

    let(:workflow_state) { "draft" }
    let(:answers_json) { {} }

    shared_examples "an invalid workflow transition" do |target|
      it "raises InvalidTransitionError with deterministic messaging" do
        expect { clinical_test.transition_workflow_to!(target) }
          .to raise_error(ClinicalTest::InvalidTransitionError, "Cannot transition from #{workflow_state} to #{target}")
      end
    end

    context "when moving from draft to in_progress" do
      let(:answers_json) { { "A1" => 4 } }

      it "allows the transition when answers have started" do
        expect { clinical_test.transition_workflow_to!("in_progress") }
          .to change(clinical_test, :workflow_state).from("draft").to("in_progress")
      end
    end

    context "when moving from in_progress to submitted" do
      let(:workflow_state) { "in_progress" }
      let(:answers_json) { { "A1" => 4, "B1" => 5 } }

      it "allows the transition when answers are present" do
        expect { clinical_test.transition_workflow_to!("submitted") }
          .to change(clinical_test, :workflow_state).from("in_progress").to("submitted")
      end
    end

    context "when moving from submitted to scored" do
      let(:workflow_state) { "submitted" }
      let(:answers_json) { { "A1" => 4, "B1" => 5 } }

      before do
        clinical_test.update!(aps_score: 80.0, composite_score: 80.0)
      end

      it "allows the transition once scoring exists" do
        expect { clinical_test.transition_workflow_to!("scored") }
          .to change(clinical_test, :workflow_state).from("submitted").to("scored")
      end
    end

    context "when moving from scored to reviewed" do
      let(:workflow_state) { "scored" }

      before do
        clinical_test.update!(
          reviewer: create(:user),
          expert_diagnosis: { summary: "Expert validated machine output." }
        )
      end

      it "allows the transition for paid tiers with expert artifacts" do
        expect { clinical_test.transition_workflow_to!("reviewed") }
          .to change(clinical_test, :workflow_state).from("scored").to("reviewed")
      end
    end

    context "when moving from scored to completed on tier 0" do
      subject(:clinical_test) { create(:clinical_test, :tier0, workflow_state: "scored") }

      it "auto-completes successfully" do
        expect { clinical_test.transition_workflow_to!("completed") }
          .to change(clinical_test, :workflow_state).from("scored").to("completed")
      end
    end

    context "when moving from reviewed to completed" do
      let(:workflow_state) { "reviewed" }

      before do
        clinical_test.update!(
          reviewer: create(:user),
          expert_diagnosis: { summary: "Expert validated machine output." },
          result_state: "published",
          report_generated_at: Time.current
        )
      end

      it "allows completion once the report is published" do
        expect { clinical_test.transition_workflow_to!("completed") }
          .to change(clinical_test, :workflow_state).from("reviewed").to("completed")
      end
    end

    context "when attempting an impossible transition" do
      let(:workflow_state) { "draft" }

      include_examples "an invalid workflow transition", "completed"
    end
  end

  describe "billing transitions" do
    it "moves tier 1 from pending to payment_pending" do
      clinical_test = create(:clinical_test, :tier1, billing_state: "pending")

      expect { clinical_test.transition_billing_to!("payment_pending") }
        .to change(clinical_test, :billing_state).from("pending").to("payment_pending")
    end

    it "moves tier 0 from pending to paid without checkout" do
      clinical_test = create(:clinical_test, :tier0, billing_state: "pending")

      expect { clinical_test.transition_billing_to!("paid") }
        .to change(clinical_test, :billing_state).from("pending").to("paid")
    end

    it "moves tier 2 from paid to active" do
      clinical_test = create(:clinical_test, :tier2, billing_state: "paid")

      expect { clinical_test.transition_billing_to!("active") }
        .to change(clinical_test, :billing_state).from("paid").to("active")
    end

    it "rejects invalid billing transitions deterministically" do
      clinical_test = create(:clinical_test, :tier0, billing_state: "pending")

      expect { clinical_test.transition_billing_to!("active") }
        .to raise_error(ClinicalTest::InvalidTransitionError, "Cannot transition from pending to active")
    end
  end

  describe "result transitions" do
    it "exposes an explicit transition map for pending" do
      expect(described_class::RESULT_STATE_TRANSITIONS.fetch("pending")).to eq(
        "machine_scored" => :scoring_completed?
      )
    end

    it "moves result_state from pending to machine_scored after scoring" do
      clinical_test = create(:clinical_test, :scored, result_state: "pending")

      expect { clinical_test.transition_result_to!("machine_scored") }
        .to change(clinical_test, :result_state).from("pending").to("machine_scored")
    end

    it "moves result_state from machine_scored to reviewed with expert artifacts" do
      clinical_test = create(
        :clinical_test,
        :tier1,
        :scored,
        result_state: "machine_scored",
        reviewer: create(:user),
        expert_diagnosis: { summary: "Expert validated machine output." }
      )

      expect { clinical_test.transition_result_to!("reviewed") }
        .to change(clinical_test, :result_state).from("machine_scored").to("reviewed")
    end

    it "rejects impossible result transitions" do
      clinical_test = create(:clinical_test, result_state: "pending")

      expect { clinical_test.transition_result_to!("published") }
        .to raise_error(ClinicalTest::InvalidTransitionError, "Cannot transition from pending to published")
    end

    it "surfaces allowed transitions from the explicit transition table" do
      clinical_test = create(:clinical_test, :scored, result_state: "machine_scored")

      expect(clinical_test.allowed_result_transitions).to match_array(%w[reviewed published])
    end
  end
end
