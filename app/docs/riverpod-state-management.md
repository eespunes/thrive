# Riverpod State Management Patterns

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `appLoggerProvider` | Mobile Core | Inject shared observability dependency in provider graph. |
| `ThriveProviderObserver` | Mobile Platform + SRE | Emit provider lifecycle signals for diagnostics. |
| Feature providers (`*Provider`) | Feature Team | Define repository wiring, async state, and invalidation rules. |

## Naming and Lifecycle Conventions

- Provider names must use `*Provider` suffix and explicit `name`.
- Feature-level providers default to `autoDispose` to avoid stale state retention.
- Repository providers are overridden at feature entrypoint (`ProviderScope`) to keep module boundaries explicit.

## Async State and Error Propagation

- Async reads should use `FutureProvider` or `AsyncNotifier` and return deterministic domain results (`AppResult<T>`).
- Domain failures must remain user-safe (`AppFailure.detail.userMessage`).
- Unexpected runtime errors from providers are surfaced through `AsyncError` and logged via `ThriveProviderObserver` (`provider_failed`).

## Invalidation and Refresh Strategy

- User-triggered refresh: invalidate feature async providers (`ref.invalidate(...)`) and re-read.
- Workspace switch: invalidate workspace-bound providers when workspace identity changes.
- Health module reference implementation:
  - `refreshHealthStatus(ref)` for explicit refresh actions.
  - `invalidateHealthStateOnWorkspaceSwitch(...)` for workspace transitions.

## Operational Signals

- `provider_added`
- `provider_updated`
- `provider_disposed`
- `provider_failed`
- `provider_refresh_requested`
- `workspace_switch_invalidation`
