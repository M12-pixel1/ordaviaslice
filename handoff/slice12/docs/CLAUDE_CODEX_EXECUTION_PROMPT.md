# ORDAVIA Slice 12 — Claude/Codex Execution Prompt

Implement Slice 12 for ORDAVIA using the approved Slice 11 baseline.

## Non-negotiable constraints

- Do not modify the Slice 11 scoring formula.
- Preserve `diagnosis_band = nil` for R17 and serialize it explicitly as JSON `null`.
- Domain exceptions remain domain-level concerns; controller/API layer maps them to HTTP responses.

## Deliverables

1. Controller rescue mapping for clinical test workflow endpoints
2. Standardized JSON error payloads
3. Result serializer with explicit `diagnosis_band: nil` support
4. Request specs for:
   - valid workflow transition returns 200
   - invalid transition returns 422 + invalid_transition
   - R17 retest returns diagnosis_band: null
   - unauthorized reviewer access returns 403
5. Formalized result-state transition table in model layer
6. API docs update and technical audit

## Implementation direction

- Reuse existing `ApplicationController` and authentication stack
- Keep host-app tenancy scoping externalized behind a narrow `clinical_tests_scope` hook
- Keep result-state behavior deterministic through an explicit transition table
- Do not omit nil fields whose absence would change business semantics
