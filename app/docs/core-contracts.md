# Shared Core Contracts

## Ownership

| Contract | Owner | Purpose |
| --- | --- | --- |
| `AppResult<T>` | Mobile Core | Deterministic success/failure response model for all layers. |
| `AppLogger` | Mobile Core + SRE | Unified operational logging contract with structured metadata. |
| `FeatureModule` + `ModuleRegistry` | Mobile Platform | Enforce module bootstrap contract and route registration. |
| `LayerRuleValidator` | Mobile Platform | Validate dependency direction and architecture boundaries. |

## Operational Criteria

- Every recoverable error must carry both `developerMessage` and `userMessage`.
- Feature modules must log configuration (`feature_module_configured`) and registration (`module_registered`).
- Layer validation must produce deterministic output order for CI diagnostics.
- Duplicated route registration must fail fast via `StateError`.

## Recovery Criteria

- User-facing failures should avoid internal technical details.
- Operational logs must include stable `code` values to support alerting and runbooks.
- Module bootstrap failures stop startup early to prevent partial app states.
