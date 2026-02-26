# Offline-First Sync and Conflict Resolution

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `OfflineSyncQueue` | Mobile Platform + Data Platform | Manage offline mutation queue, sync lifecycle, and conflict policy handling. |
| `OfflineSyncGateway` | Data Platform | Push queued mutations and return applied IDs plus conflict descriptors. |

## Offline Queue Behavior

- Offline writes are appended to queue and state moves to `queued`.
- Sync attempts while offline keep queue intact and return `sync_offline_queue_retained`.
- Empty queue sync returns deterministic idle result without backend call.

## Conflict Detection and Strategy

- Gateway responses can include `conflicts` with local/remote version metadata.
- `keepLocal` strategy preserves conflicted mutations in queue and returns `sync_conflict_requires_resolution`.
- `acceptRemote` strategy drops conflicted local mutations and logs resolution.

## User-Visible Sync State and Recovery

- Queue state transitions: `idle`, `queued`, `syncing`, `error`.
- Successful cycle emits `sync_cycle_completed` with counts.
- Gateway failures propagate deterministic code/message through queue result.

## Operational Signals

- `offline_mutation_enqueued`
- `sync_cycle_completed`
- `sync_offline_queue_retained`
- `sync_conflict_requires_resolution`
- `sync_conflict_resolved_accept_remote`

## Recovery Guidance

- Keep user changes queued when network is unavailable.
- Present clear retry messaging for recoverable sync errors.
- Expose conflict count and resolution path without losing local intent unexpectedly.
