# Technical Audit and Risk Register

## Executive readout

The brief is implementable, but there are several contract ambiguities that should be locked down before production merge. None of them block scaffolding. Two of them can break QA if left unresolved.

## Critical spec gaps

### 1. Scoring floor contradiction
- The formula is:
  - `(sum(answered values) / (count(answered) * 5)) * 100`
- If answers are constrained to `1..5`, the minimum reachable score is `20.0`.
- The brief's test matrix says `score = 0 (all 1s)`.
- That is mathematically impossible.

**Decision taken in this package:** the code follows the formula, not the contradictory test note.

### 2. Exact decimal boundary ambiguity
- The test matrix calls for exact boundaries like `39.99`, `59.99`, `79.99`.
- With discrete answer values and finite question counts, those exact decimals are not always naturally reachable from raw answer sets.
- They are reachable only if tests seed persisted section scores directly rather than deriving every case from `answers_json`.

**Decision taken in this package:** service specs use direct persisted scores where exact diagnosis threshold coverage is needed.

### 3. `diagnosis_band` domain mismatch
- Table definition implies `green / yellow / orange / red`.
- Rule R17 defines band `none`.
- That creates a domain mismatch.

**Decision taken in this package:** `diagnosis_band` is persisted as `nil` for R17, while `machine_diagnosis.rule_paths_applied` and flags preserve the "retest required" state.

### 4. Transition-to-422 contract lives outside this scope
- The brief requires `422, error_code: invalid_transition`.
- The delivery structure excludes controllers and serializers.
- Therefore the model can raise deterministic domain errors, but API shaping must happen in the existing app layer.

**Decision taken in this package:** deterministic exception text is implemented; controller rescue integration remains a required follow-up.

## Medium risks

### 5. Tier-specific nullability is partly underspecified
- `parent_test_id`, `reviewer_id`, and `expert_diagnosis` are said to be nullable only where operationally required.
- But the brief does not formally state when Tier 2 baseline tests must or must not have a `parent_test_id`.
- It also does not specify whether every Tier 2 follow-up is guaranteed to have expert review in Sprint 1.

**Mitigation:** this package validates reviewer/expert diagnosis only once a paid test is actually in `reviewed` or `completed` workflow states.

### 6. Seed dependency on prior slices
- Case and mandate creation rules are unknown here.
- Generating fresh `Case`/`Mandate` rows could break validations from Slices 01–10.

**Mitigation:** seed script reuses existing cases and mandates instead of fabricating unknown dependencies.

### 7. Result-state lifecycle is only partially specified
- Workflow transitions are defined in detail.
- Result-state transitions are implied but not formally mapped.
- Publishing and PDF generation semantics are therefore convention-based rather than contract-based.

**Mitigation:** package includes a conservative `result_state` transition map and treats `published` as the completion gate for reviewed paid tests.

## Low risks

### 8. Numeric storage precision
- `decimal(5,2)` is adequate for `0..100` scores.
- Weight normalization is kept in computation and rounded for persisted/report payloads.

### 9. Reviewer linkage
- `reviewer_id` uses `users`.
- If reviewer role scoping exists in prior slices, authorization still has to be enforced above the model layer.

### 10. N+1 requirement
- The brief mentions no N+1 queries on key paths.
- This Sprint 1 package is domain-model heavy and query-light, so the real N+1 exposure sits in list/report endpoints not included here.

## Merge recommendation

Proceed with merge after three alignment calls:
1. confirm that formula beats the contradictory `all 1s => 0` note,
2. confirm `diagnosis_band = nil` is acceptable for R17,
3. confirm controller rescue layer owns the 422 API contract.
