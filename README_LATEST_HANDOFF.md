# ORDAVIA Slices 11 + 12 — Latest Handoff Package

Date: 2026-04-05
Status: Approved slice packs available; host-repo integration not yet executed in real app context.

## What this package is

This is the latest version currently available in the execution environment.
It contains the approved Slice 11 and Slice 12 delivery packs exactly as available here,
consolidated into one uploadable handoff bundle.

## What this package is NOT

- Not a completed host-repo integration branch
- Not a verified green-CI merge
- Not a tested fabrikas deployment artifact
- Not a substitute for running the real ORDAVIA Rails app test suite

## Included directories

- `slice11/` — scoring/domain delivery pack
- `slice12/` — controller/API integration pack

## Key documents

### Slice 11
- `slice11/README.md`
- `slice11/docs/CLAUDE_CODEX_EXECUTION_PROMPT.md`
- `slice11/docs/EXECUTION_PLAN.md`
- `slice11/docs/TECHNICAL_AUDIT.md`

### Slice 12
- `slice12/README.md`
- `slice12/docs/API_DOCUMENTATION_UPDATE.md`
- `slice12/docs/EXECUTION_PLAN.md`
- `slice12/docs/TECHNICAL_AUDIT.md`

## Required host integration work after repo access is granted

1. Wire tenant-aware `clinical_tests_scope`
2. Wire host `current_user` / authentication plumbing
3. Merge routes into the actual API namespace used by ORDAVIA
4. Port serializer contract to the host serializer stack
5. Include and verify rescue mapping precedence for invalid transitions
6. Run real request specs against the host test database
7. Run full `bundle exec rspec` and confirm no regressions

## Non-negotiable contract points

- Scoring formula from Slice 11 remains authoritative
- `diagnosis_band = nil` must serialize to JSON `null`
- `InvalidTransitionError` must surface as `422 invalid_transition`
- `RESULT_STATE_TRANSITIONS` must not be altered

## Recommended next step

Upload this package to the ORDAVIA repo (or attach it to the working branch), then provide repo access.
Once the real Rails host code is accessible, integration can be performed against the actual app context.
