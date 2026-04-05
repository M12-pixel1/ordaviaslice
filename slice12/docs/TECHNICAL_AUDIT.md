# ORDAVIA Slice 12 — Technical Audit

## Decision alignment carried forward

1. **Scoring formula remains authoritative**
   - Slice 12 does not reinterpret scoring semantics.
   - Any API payload exposing scores serializes the values computed by Slice 11 services.

2. **R17 null-band semantics preserved**
   - `diagnosis_band = nil` is intentionally serialized as JSON `null`.
   - Serializer comment and API docs both encode this as an explicit contract.

3. **Controller owns HTTP error mapping**
   - Domain layer continues to raise `ClinicalTest::InvalidTransitionError`.
   - Controller concern maps it to deterministic `422` JSON.

## Delivered controls

### 1. Standardized rescue mapping

- `ClinicalTestErrorRescuable` centralizes `InvalidTransitionError` → `422 invalid_transition`
- Prevents endpoint-by-endpoint drift in error formatting

### 2. Explicit serializer contract

- `ClinicalTestResultSerializer` emits `diagnosis_band` even when nil
- Numeric values normalize to JSON-compatible floats
- Time fields normalize to ISO8601

### 3. Request-level behavioral coverage

Covered scenarios:

- valid workflow transition returns `200`
- invalid transition returns `422 + invalid_transition`
- R17 retest serializes `diagnosis_band: null`
- unauthorized reviewer submission returns `403`

### 4. Result-state transition formalization

- `RESULT_STATE_TRANSITIONS` eliminates convention-only behavior for result progression
- `allowed_result_transitions` exposes the transition table for future API/UI use

## Known integration assumptions

1. **Authentication hook**
   - Controller assumes `current_user` exists in `ApplicationController`

2. **Tenant scoping hook**
   - `clinical_tests_scope` is intentionally narrow and must be overridden with existing multi-tenant scope

3. **Authorization depth**
   - This slice enforces controller-level reviewer access denial for endpoint behavior
   - Full reviewer role scoping policy remains a next-slice hardening item, per approved backlog

## Residual risks

1. **Routes may differ in host app**
   - If ORDAVIA uses versioned route concerns or namespace wrappers, the route file here must be adapted

2. **Existing serializer stack may differ**
   - If the host app standardizes on Blueprinter, AMS, or JSONAPI serializers, this serializer should be ported without changing contract semantics

3. **Rescue stack ordering**
   - If global exception handlers already exist, rescue precedence must be verified so `invalid_transition` remains deterministic

## Release recommendation

**APPROVE FOR INTEGRATION** provided the host repo wires:

- tenancy-aware `clinical_tests_scope`
- actual authentication/current user plumbing
- route merge into existing API namespace
- request spec execution inside real ORDAVIA app context
