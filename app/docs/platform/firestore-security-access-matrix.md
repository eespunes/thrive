# Firestore Security Rules and Access Matrix

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `FirestoreSecurityAccessMatrix` | Mobile Platform + Backend Platform + Security | Evaluate role/resource/operation requests with least-privilege defaults. |
| `FirestoreAccessRequest` | Mobile Platform | Provide deterministic access request context (`workspaceId`, role, resource, operation). |

## Resource-Level Access Model

- Authorization is evaluated per resource and operation (`read`, `write`, `delete`).
- Role map supports `owner`, `admin`, `member`, `localProfile`, and `unknown`.
- Unknown/undefined role paths must deny by default.

## Rule Validation Paths

- Allowed requests emit `firestore_access_allowed`.
- Denied requests emit `firestore_access_denied` with stable metadata.
- Invalid workspace scope fails fast with `firestore_workspace_invalid`.

## Least Privilege Defaults

- No wildcard allow behavior is permitted.
- New resources must be explicitly added to the role matrix before usage.
- Unknown roles/resources/operations must not inherit access implicitly.

## Operational Signals

- `firestore_access_allowed`
- `firestore_access_denied`
- `firestore_workspace_invalid`

## Recovery Guidance

- For deny responses, render safe "not allowed" UX and avoid technical Firestore details.
- Surface stable failure codes in telemetry to support incident triage.
- If policy changes are needed, update matrix + tests together in the same PR.
