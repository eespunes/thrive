# Realtime Subscriptions, Pagination, and Caching

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `RealtimeSubscriptionController` | Mobile Platform + Data Platform | Attach/detach realtime listeners with deterministic lifecycle events. |
| `CursorPaginator` | Mobile Platform | Produce stable page windows from ordered datasets using cursors. |
| `RealtimePageCache` | Mobile Platform | Cache page windows with TTL expiry and explicit invalidation semantics. |

## Realtime Subscription Lifecycle

- Screen entry attaches a subscription by query key.
- Duplicate attach for the same key returns `realtime_subscription_duplicate`.
- Screen exit must detach listeners to avoid duplicate events and memory leaks.
- Invalid query key fails with `realtime_query_key_invalid`.

## Cursor Pagination and Ordering

- Pagination requires `limit > 0`.
- `afterCursor` must exist in ordered dataset or returns `pagination_cursor_invalid`.
- Cursor values must be unique; duplicates return `pagination_cursor_not_unique`.
- Successful pages return `items` + `nextCursor` deterministically.

## Cache TTL and Invalidation

- Cached pages expire strictly by TTL window.
- Reads after expiry return `realtime_cache_expired` and purge stale entry.
- Explicit invalidation removes entries by query key.
- Missing entries return `realtime_cache_miss`.

## Operational Signals

- `realtime_subscription_started`
- `realtime_subscription_event`
- `realtime_subscription_stopped`
- `realtime_subscription_error`
- `realtime_cache_updated`
- `realtime_cache_hit`
- `realtime_cache_invalidated`
- `realtime_cache_miss`
- `realtime_cache_expired`
- `realtime_query_key_invalid`

## Recovery Guidance

- On cache miss/expiry, request fresh data and keep user feedback non-technical.
- Ensure listener detachment on screen dispose/navigation transitions.
- Keep pagination deterministic to simplify debugging and analytics.
