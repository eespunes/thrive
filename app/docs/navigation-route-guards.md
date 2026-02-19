# Navigation and Route Guards

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `AppRouteRegistry` | Mobile Platform | Centralize route map and deterministic route resolution. |
| `AppRouteGuardState` | Auth + Family Domain | Provide current auth/workspace state to guard evaluation. |
| Route observability codes | Mobile Platform + SRE | Maintain stable logging codes and dashboards. |

## Route Map

| Path | Guard policy | Behavior on success | Behavior on failure |
| --- | --- | --- | --- |
| `/` | Public | Render home shell. | N/A |
| `/login` | Public | Render authentication entrypoint. | N/A |
| `/family/workspace` | Requires authenticated user | Render workspace selection/create screen. | Redirect to `/login` if unauthenticated. |
| `/health` | Requires authenticated user and active family workspace | Render health module. | Redirect to `/login` when unauthenticated; redirect to `/family/workspace` when workspace is missing. |

## Deep Link Handling

- Route matching uses normalized URI `path` only.
- Query params are preserved in route settings arguments but ignored for route lookup.
- Example: `/health?source=push` resolves to `/health`.

## Fallback Behavior for Unknown Routes

- Unknown paths render a safe fallback screen with recovery action ("Go Home").
- The app does not crash on unknown route input.
- Logs are emitted with the originally requested path to support triage.

## Operational Criteria

- `route_navigation_resolved` logs every successful route resolution.
- `route_guard_blocked` logs guard denials with reason and resolved fallback path.
- `route_unknown_fallback` logs unknown path requests.
- Each log must include `requestedPath`, `resolvedPath`, and deterministic `outcome`.
