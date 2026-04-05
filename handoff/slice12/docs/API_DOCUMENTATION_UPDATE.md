# ORDAVIA Slice 12 — API Documentation Update

## Clinical Test Result Contract

`GET /api/v1/clinical_tests/:id`

### Response shape

```json
{
  "clinical_test": {
    "id": 123,
    "case_id": 456,
    "mandate_id": 789,
    "workflow_state": "scored",
    "billing_state": "paid",
    "result_state": "machine_scored",
    "aps_score": null,
    "ops_score": null,
    "ips_score": null,
    "composite_score": null,
    "diagnosis_band": null,
    "diagnosis_flags": ["retest_required"],
    "scoring_version": "1.0",
    "diagnosis_version": "1.0",
    "machine_diagnosis": {
      "band": null,
      "flags": ["retest_required"],
      "rule_paths_applied": ["R17"]
    }
  }
}
```

## `diagnosis_band: null` semantics

`diagnosis_band: null` is a valid business-state response.

It means **"retest required"** under Rule Path **R17**.
It does **not** mean the field is missing, uncomputed, or omitted by serialization.

Clients must therefore:

- treat explicit `null` as a meaningful state,
- inspect `diagnosis_flags` and `machine_diagnosis.rule_paths_applied`,
- avoid defaulting null to `green`, `unknown`, or empty-string placeholders.

## Standardized workflow error response

### 422 invalid transition

```json
{
  "success": false,
  "error_code": "invalid_transition",
  "message": "Cannot transition from draft to completed"
}
```

### 403 forbidden reviewer access

```json
{
  "success": false,
  "error_code": "forbidden",
  "message": "Reviewer access denied"
}
```
