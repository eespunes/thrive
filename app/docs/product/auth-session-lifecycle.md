# Auth Session Lifecycle and Token Refresh

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `AuthSessionLifecycle` | Mobile Platform + Auth Backend | Coordinate session creation, token refresh, sign-out, and remote revocation handling. |
| `AuthSessionStore` | Mobile Platform | Persist and clear session material safely on-device. |
| `AuthTokenRefresher` + `AuthSessionRevocationGateway` | Auth Backend + Mobile Platform | Refresh access tokens and revoke sessions deterministically. |

## Session Creation and Storage

- Sign-in success must create and persist an `AuthSession`.
- Session creation emits `auth_session_created`.
- Storage failures must return deterministic failure codes with user-safe messages.

## Token Refresh and Expiry

- Access token reads must evaluate expiry and refresh when needed.
- Successful refresh emits `auth_token_refreshed`.
- Missing session returns `auth_session_missing`.
- Revoked refresh credentials must clear local session and return `auth_session_revoked`.

## Sign-Out and Multi-Device Revocation

- Sign-out always clears local session state and emits `auth_session_signed_out`.
- Optional remote revocation may fail independently; local sign-out still completes.
- Remote revocation notifications should clear matching local sessions and emit `auth_session_revoked`.

## Operational Signals

- `auth_session_created`
- `auth_token_refreshed`
- `auth_session_signed_out`
- `auth_session_revoked`
- `auth_session_missing`
