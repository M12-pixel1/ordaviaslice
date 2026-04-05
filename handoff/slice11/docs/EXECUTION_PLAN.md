# Execution Plan

## Objective

Deliver Sprint 1 of Slice 11 as a server-authoritative Clinical Test backbone embedded into the existing ORDAVIA case lifecycle.

## Delivery workstream

### 1. Schema and data backbone
- Add `clinical_tests` table with all requested workflow, scoring, diagnosis, review and lead-capture fields.
- Preserve foreign-key linkage to `cases`, `mandates`, `users`, and self-referential baseline/follow-up lineage.
- Add performance indexes on workflow, billing and tier query paths.

### 2. Domain model and lifecycle control
- Implement `ClinicalTest` as a first-class ActiveRecord model.
- Enforce allow-lists for `tier`, `workflow_state`, `billing_state`, and `result_state`.
- Implement deterministic transition methods:
  - `transition_workflow_to!`
  - `transition_billing_to!`
  - `transition_result_to!`
- Raise `ClinicalTest::InvalidTransitionError` with deterministic text for any impossible transition.

### 3. Server-authoritative scoring
- Read only `answers_json`.
- Ignore any client-populated score fields.
- Compute APS / OPS / IPS from section answers.
- Compute composite score with normalized weights when one or more sections are unavailable.
- Stamp `scoring_version = "1.0"` on every run.

### 4. Diagnosis and machine snapshot
- Apply primary diagnosis rules in strict priority order.
- Apply partial/insufficient rules additively.
- Persist:
  - `diagnosis_band`
  - `diagnosis_flags`
  - `machine_diagnosis`
  - `diagnosis_version = "1.0"`
- Move `result_state` to `machine_scored`.
- Auto-complete Tier 0 in workflow after scoring.

### 5. Delta foundation
- Implement `.compare` / `.call` interface.
- Enforce scoring version compatibility.
- Return delta payload structure without full Sprint 5 comparison logic.

### 6. Test envelope
- Cover:
  - state validation
  - transition guards
  - scoring overwrite behavior
  - composite re-weighting
  - diagnosis rule paths
  - version stamping
  - tier-specific workflow outcomes
  - delta mismatch behavior

## Delivery assumptions

- Slice 01–10 already exposes `Case`, `Mandate`, and `User`.
- Existing API rescue stack can serialize domain errors to the expected 422 shape.
- Stripe and notification wiring already exist and only need state-hook integration, not reimplementation.

## Definition of done for merge

- Migration runs cleanly.
- New model validates correctly.
- Scoring and diagnosis are callable from backend only.
- No client score field can survive a scoring pass.
- Specs for new files pass at ≥90% coverage.
