# ORDAVIA Slice 11 — Sprint 1 Delivery Pack

This package implements the Sprint 1 delivery skeleton for the Clinical Test product inside the existing ORDAVIA Case → Mandate → Submission → Validation → Payout → Trust Update flow.

## Included scope

- `clinical_tests` migration
- `ClinicalTest` model with workflow, billing and result transition guards
- `ClinicalScoringService`
- `ClinicalDiagnosisService`
- `ClinicalDeltaService`
- Model and service specs
- FactoryBot factory with requested traits
- Seed script
- Execution plan
- Technical audit and risk register
- Claude/Codex-ready execution prompt

## Important integration notes

1. **Controller/webhook wiring is not included in the briefed delivery structure.**
   - The code here implements the domain model and service layer.
   - API `422 error_code: "invalid_transition"` serialization should be wired in the existing controller/rescue layer from Slices 01–10.

2. **Existing project conventions are assumed, not discoverable here.**
   - `Case`, `Mandate`, `User`, and their factories are expected to exist already.
   - If Slice 01–10 uses a shared error base class under `app/errors/`, the custom errors here should be re-based onto that class.

3. **The scoring formula is treated as source of truth.**
   - With answer values constrained to `1..5`, the minimum mathematically reachable section score is `20.0`, not `0.0`.
   - The audit document calls out this spec mismatch explicitly.

4. **Boundary test coverage is implemented pragmatically.**
   - Some exact decimal boundary values in the brief are not naturally reachable via discrete answer sets.
   - The specs therefore verify priority handling and persistence with direct persisted score values where that is the only deterministic route.

5. **Seed script is intentionally conservative.**
   - It expects at least 3 existing `Case` records, each with at least 1 `Mandate`.
   - It reuses existing records instead of inventing unknown Slice 01–10 dependencies.

## Recommended submit flow in the existing app

```ruby
ClinicalTest.transaction do
  clinical_test.update!(answers_json: permitted_answers_only)

  ClinicalScoringService.call(clinical_test)
  ClinicalDiagnosisService.call(clinical_test)
end
```

Any client-supplied score fields should be filtered out or ignored at the controller boundary and always overwritten by the scoring service.

## Suggested next integration steps

1. Wire the submit endpoint to call scoring then diagnosis in one transaction boundary.
2. Add rescue serialization for `ClinicalTest::InvalidTransitionError`.
3. Add Stripe event hooks for `billing_state` transitions.
4. Add report generation/publishing hooks for Tier 1/2 completion.
5. Add SimpleCov threshold enforcement for the new files.
