# Testing Strategy and Quality Gates

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `TestingStrategyContract` | Mobile Platform + QA | Validate pyramid ownership, deterministic fixture quality, and release-blocking criteria. |

## Test Pyramid and Ownership

- Each test layer (`unit`, `widget`, `integration`, `e2e`) requires a clear owner.
- Pyramid distribution must follow `unit >= widget >= integration >= e2e`.

## Deterministic Fixtures and Test Data

- Fixtures require stable IDs, deterministic seeds, and non-empty records.
- Invalid fixture payloads fail deterministically for CI diagnosis.

## Release Blocking Criteria

- Release gates evaluate critical/high failures, flaky rate, and required checks.
- Blocking state is returned with deterministic reason list.
- Recommended guardrails include no critical failures and flaky rate <= 3%.

## Operational Signals

- `testing_ownership_validated`
- `testing_pyramid_validated`
- `testing_fixture_validated`
- `release_blocking_criteria_passed`
- `release_blocking_criteria_failed`

## Recovery Guidance

- Resolve ownership gaps before onboarding new test suites.
- Treat pyramid inversions and high flake rates as quality debt to remediate.
- Preserve stable failure reason codes for CI dashboards.
