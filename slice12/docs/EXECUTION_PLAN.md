# ORDAVIA Slice 12 — Execution Plan

## Objective

Integrate Slice 11 domain behavior into API/controller boundaries without reopening the already-approved scoring and diagnosis contract.

## Workstreams

1. **Controller rescue mapping**
   - Add a reusable rescue concern for `ClinicalTest::InvalidTransitionError`
   - Standardize JSON error body for clinical test workflow endpoints

2. **Serializer contract**
   - Provide explicit result serialization
   - Preserve `diagnosis_band: null` for R17 as a contract, not as an omission

3. **Request-spec coverage**
   - Validate 200 paths for legal transitions
   - Validate deterministic `422 invalid_transition`
   - Validate `diagnosis_band: null` visibility
   - Validate `403` on unauthorized review submission

4. **Result-state formalization**
   - Replace implicit transition conventions with explicit `RESULT_STATE_TRANSITIONS`
   - Expose allowed transitions for future docs/UI compatibility

5. **API documentation update**
   - Document `diagnosis_band: null` as `retest required`
   - Publish sample success and error payloads
