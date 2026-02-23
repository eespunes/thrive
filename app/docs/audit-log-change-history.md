# Audit Log and Change History Contract

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `AuditLogContract` | Mobile Platform + Security + Compliance | Validate immutable audit schema and enforce query/retention policy. |
| `AuditLogStore` | Backend Platform | Persist immutable audit events and support deterministic queries. |

## Audit Event Schema

- Every audit event requires stable identifiers: `eventId`, `workspaceId`, `entityType`, and `entityId`.
- Events are immutable records with explicit `before` and/or `after` snapshots.
- Invalid identity payloads fail with `audit_event_invalid`.

## Actor and Source Attribution

- Every event requires actor attribution (`actorId`, `actorType`) and source.
- Missing actor attribution fails with `audit_actor_missing`.
- Empty change payloads fail with `audit_change_payload_empty`.

## Retention and Query Policy

- Queries enforce a max time window and deterministic limit controls.
- Oversized windows fail with `audit_query_window_exceeded`.
- Result sets are filtered by retention cutoff before returning.

## Operational Signals

- `audit_event_recorded`
- `audit_append_failed`
- `audit_query_completed`
- `audit_query_failed`
- `audit_query_window_exceeded`

## Recovery Guidance

- Keep audit errors user-safe while preserving developer diagnostics in telemetry.
- Use stable codes and metadata (`workspaceId`, `eventId`, `action`, `source`) for investigations.
- Do not mutate existing events; append only.
