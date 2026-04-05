# frozen_string_literal: true

class CreateClinicalTests < ActiveRecord::Migration[7.1]
  def change
    create_table :clinical_tests do |t|
      t.references :case, null: false, foreign_key: true
      t.references :mandate, null: false, foreign_key: true
      t.references :parent_test, null: true, foreign_key: { to_table: :clinical_tests }
      t.references :reviewer, null: true, foreign_key: { to_table: :users }

      t.integer :tier, null: false, default: 0
      t.string :workflow_state, null: false, default: "draft"
      t.string :billing_state, null: false, default: "pending"
      t.string :result_state, null: false, default: "pending"

      t.jsonb :answers_json
      t.decimal :aps_score, precision: 5, scale: 2
      t.decimal :ops_score, precision: 5, scale: 2
      t.decimal :ips_score, precision: 5, scale: 2
      t.decimal :composite_score, precision: 5, scale: 2

      t.string :diagnosis_band
      t.jsonb :diagnosis_flags
      t.jsonb :machine_diagnosis
      t.jsonb :expert_diagnosis
      t.text :adjustment_reason

      t.string :scoring_version, null: false, default: "1.0"
      t.string :diagnosis_version, null: false, default: "1.0"
      t.string :consent_version, null: false, default: "1.0"
      t.datetime :consented_at, null: false
      t.datetime :report_generated_at

      t.string :contact_email
      t.string :agent_type
      t.string :biz_function
      t.string :client_org

      t.timestamps
    end

    add_index :clinical_tests, :workflow_state
    add_index :clinical_tests, :billing_state
    add_index :clinical_tests, :tier
  end
end
