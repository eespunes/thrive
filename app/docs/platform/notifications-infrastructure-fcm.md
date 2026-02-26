# Notifications Infrastructure and FCM Contract

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `NotificationInfrastructureContract` | Mobile Platform + Backend Platform | Enforce token lifecycle, preference mapping, and delivery retry contract. |
| `PushTokenGateway` | Mobile Platform + Backend Platform | Register and refresh device push tokens. |
| `NotificationDeliveryGateway` | Backend Platform | Send channel-based notification payloads and return deterministic results. |

## Push Token Registration and Refresh

- Token registration requires `userId`, `workspaceId`, `deviceId`, `platform`, and a valid token payload.
- Invalid token payloads fail with `push_token_invalid`.
- Successful registration emits `push_token_registered`.
- Token rotation/refresh emits `push_token_refreshed`.

## Channel and Preference Mapping

- Preference updates must include user/workspace identity and at least one channel preference.
- Missing identity fails with `notification_preference_identity_invalid`.
- Empty preference input fails with `notification_preferences_missing`.
- Mapping includes all channels with deterministic defaults for missing entries.

## Delivery Diagnostics and Retries

- Delivery attempts retry recoverable failures up to configured max attempts.
- Per-attempt failures emit `notification_delivery_attempt_failed`.
- Successful delivery emits `notification_delivery_succeeded`.
- Retry exhaustion emits `notification_delivery_failed`.

## Operational Signals

- `push_token_registered`
- `push_token_refreshed`
- `push_token_invalid`
- `notification_preferences_updated`
- `notification_delivery_attempt_failed`
- `notification_delivery_succeeded`
- `notification_delivery_failed`

## Recovery Guidance

- Show user-safe retry messaging for delivery failures.
- Keep failure codes stable for diagnostics and alerting.
- Never expose raw token values in user-visible text or logs.
