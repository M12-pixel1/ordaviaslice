# ORDAVIA Slice 12 — Controller/API Integration

This package extends the Slice 11 baseline with controller-layer error rescue mapping,
serializer contracts, request specs, API documentation updates, and explicit result-state
transition formalization.

## Scope delivered

- Controller rescue mapping for workflow endpoint domain exceptions
- Standardized JSON error contract with `422` + `error_code`
- Serializer contract with explicit `diagnosis_band: null` support for R17 (`retest required`)
- Request specs for valid transitions, invalid transitions, R17 serialization, and unauthorized reviewer access
- Result-state transition map formalized in `ClinicalTest`
- Technical audit and API documentation update

## Integration notes

This scaffold assumes the host application already provides:

- `ApplicationController`
- `current_user`
- `Case`, `Mandate`, and `User` models
- tenant scoping hooks for clinical test lookup
- existing authentication stack

The controller uses a narrow `clinical_tests_scope` hook so Slice 01–10 tenancy controls can be wired without
rewriting endpoint logic.
