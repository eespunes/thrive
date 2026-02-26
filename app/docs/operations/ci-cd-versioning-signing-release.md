# CI/CD, Versioning, Signing, and Release

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `CiCdReleaseContract` | Mobile Platform + Release Engineering | Validate automated workflow gates, signing/promotion payloads, and staged rollout rollback signals. |

## Automated Build and Test Workflow

- Workflow validation requires commit SHA, tests pass, analysis pass, and artifact generation.
- Any failed quality gate returns deterministic `cicd_quality_gate_failed`.

## Signing and Artifact Promotion

- Promotion requires valid artifact ID, signing key version, track, and checksum.
- Allowed tracks are explicit (`internal`, `alpha`, `beta`, `production`).

## Staged Rollout and Rollback

- Rollout snapshots evaluate issue flags and percentage progression.
- Production issues trigger `cicd_rollback_required` decisions.
- Healthy progression emits `cicd_rollout_healthy`.

## Operational Signals

- `cicd_workflow_validated`
- `cicd_quality_gate_failed`
- `cicd_artifact_promoted`
- `cicd_rollback_required`
- `cicd_rollout_healthy`
- `cicd_version_validated`

## Recovery Guidance

- Block release promotion when required quality gates fail.
- Keep signing/promotion validation deterministic to avoid accidental bad promotions.
- Use rollout incident telemetry to trigger rollback without manual ambiguity.
