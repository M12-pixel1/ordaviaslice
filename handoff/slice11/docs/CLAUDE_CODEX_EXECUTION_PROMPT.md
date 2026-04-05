You are implementing ORDAVIA Slice 11 Sprint 1 inside an existing Rails 7.1 codebase.

Mission:
Build the Clinical Test backend backbone as part of the existing Case -> Mandate -> Submission -> Validation -> Payout -> Trust Update architecture. Do not build a separate module. Do not add frontend work.

Hard rules:
- All scoring is server-authoritative.
- Ignore all client-provided score fields in incoming payloads.
- Read only `answers_json` for scoring.
- Preserve existing RBAC, multi-tenancy, Stripe Connect, and notifications from prior slices.
- Use ActiveRecord only. No direct SQL.
- Use service objects with a single public `.call` method.
- Raise specific error classes.
- Follow existing project conventions where they already exist.

Deliver these files:

ordavia-slice11-sprint1/
├── db/migrate/XXXXXX_create_clinical_tests.rb
├── app/models/clinical_test.rb
├── app/services/clinical_scoring_service.rb
├── app/services/clinical_diagnosis_service.rb
├── app/services/clinical_delta_service.rb
├── spec/models/clinical_test_spec.rb
├── spec/services/clinical_scoring_service_spec.rb
├── spec/services/clinical_diagnosis_service_spec.rb
├── spec/services/clinical_delta_service_spec.rb
├── spec/factories/clinical_tests.rb
└── db/seeds/slice11_clinical_tests.rb

Implementation contract:

1) Migration
Create `clinical_tests` with:
- foreign keys to `cases`, `mandates`, `users`
- self-reference `parent_test_id`
- `tier`, `workflow_state`, `billing_state`, `result_state`
- `answers_json`
- APS / OPS / IPS / composite score decimals
- diagnosis fields
- version fields
- consent fields
- report and lead capture fields
- indexes on `case_id`, `mandate_id`, `parent_test_id`, `workflow_state`, `billing_state`, `tier`

2) Model
Implement associations:
- belongs_to :case
- belongs_to :mandate
- belongs_to :parent_test, class_name: "ClinicalTest", optional: true
- belongs_to :reviewer, class_name: "User", optional: true
- has_many :child_tests, class_name: "ClinicalTest", foreign_key: :parent_test_id

Validate:
- tier inclusion 0..2
- workflow/billing/result state inclusion
- consent/version presence

Implement deterministic transition methods that raise:
`ClinicalTest::InvalidTransitionError, "Cannot transition from {current} to {target}"`

Workflow:
- draft -> in_progress when answers start
- in_progress -> submitted when answers exist
- submitted -> scored when scoring completed
- scored -> reviewed when paid-tier expert review exists
- scored -> completed when tier 0 auto-completes
- reviewed -> completed when report is published

Billing:
- pending -> payment_pending for tier 1/2
- pending -> paid for tier 0
- payment_pending -> paid on checkout completion
- paid -> active for tier 2
- active -> past_due / cancelled for tier 2
- past_due -> active / cancelled for tier 2

3) ClinicalScoringService
Implement `.call(clinical_test)`.

Rules:
- Section A = APS questions A1-A15
- Section B = OPS questions B1-B15
- Section C = IPS questions C1-C10
- Section score = `(sum(answered values) / (count(answered) * 5)) * 100`
- A/B threshold = 6 answered; C threshold = 4 answered
- Below threshold => section score nil
- Threshold met but not complete => compute score normally
- Composite weights:
  - APS 0.40
  - OPS 0.35
  - IPS 0.25
- If one or more sections are nil, renormalize using only available weights
- Stamp `scoring_version = "1.0"`
- Overwrite any pre-filled persisted/client score fields

4) ClinicalDiagnosisService
Implement `.call(clinical_test)`.

Persist:
- `diagnosis_band`
- `diagnosis_flags`
- `machine_diagnosis`
- `result_state = machine_scored`
- `diagnosis_version = "1.0"`

Primary rule priority:
R17 > R9 > R8 > R6 > R5 > R7 > R4 > R3 > R2 > R1

Band rules:
- R1: composite >= 80 and no section < 60 => green
- R2: composite 60..79.99 => yellow
- R3: composite 40..59.99 => orange + review_recommended
- R4: composite < 40 => red + intervention_required
- R5: APS >= 80 and OPS < 40 => yellow + ops_critical
- R6: APS < 40 => red + aps_intervention
- R7: IPS < 40 and APS/OPS >= 60 => orange + ips_remediation
- R8: any two sections < 40 => red + multi_system_failure
- R9: all three sections < 40 => red + full_intervention
- R17: all sections nil => no band / retest_required

Additive rules:
- R10 APS partial => aps_partial
- R11 APS insufficient => aps_insufficient
- R12 OPS partial => ops_partial
- R13 OPS insufficient => ops_insufficient
- R14 IPS partial => ips_partial
- R15 IPS insufficient => ips_insufficient
- R16 one or two sections nil => partial_assessment

Persist `machine_diagnosis` as:
- scoring_version
- diagnosis_version
- computed_at ISO8601
- section scores/answered/total/status
- composite score
- weights_used
- band
- rule_paths_applied
- flags

Tier handling:
- Tier 0 auto-completes workflow after machine scoring
- Tier 1 stops at scored
- Tier 2 stops at scored and may carry `parent_test_id`

5) ClinicalDeltaService
Implement `.call` and `.compare`.
- Compare baseline vs follow-up
- Raise `ClinicalDeltaService::VersionMismatchError` if scoring versions differ
- Return a delta hash
- Do not implement full Sprint 5 delta intelligence yet

6) Specs
Target at least 40 examples, ideally more.
Cover:
- all R1-R17 rule paths
- state transitions
- impossible transitions
- client score overwrite behavior
- missing answers
- partial answers
- reweighted composite
- version stamping
- tier-specific workflow outcomes
- delta mismatch
- machine_diagnosis persistence

Important decision notes:
- Follow the scoring formula as source of truth even though a separate note claims "all 1s => 0". Formula makes that impossible; all 1s produce 20.0.
- For R17, store `diagnosis_band` as nil rather than inventing a fifth persisted band.
- Keep implementation conservative and compatible with existing Slice 01–10 conventions.

Output code only. No essays. No frontend. No shortcuts.
