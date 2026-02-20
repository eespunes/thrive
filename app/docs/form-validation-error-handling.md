# Form Validation and Error Handling Patterns

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `ThriveFieldValidators` | Mobile Platform | Define reusable field-level validation rules. |
| `ThriveErrorMapper` | Mobile Platform + Backend | Map transport/backend errors to deterministic `FailureDetail`. |
| Retry and recovery UX | Product + Mobile Platform | Ensure users can retry failed operations safely. |

## Field Validation Contract

- Validate fields at submit time and block request execution when invalid.
- Field errors must be shown near the failing input.
- Validation failures must be observable through `form_validation_failed`.
- Example rules in `core/forms/field_validation.dart`:
  - required
  - email format
  - minimum length

## Server and Network Error Mapping

- Map errors to stable, user-safe `FailureDetail` values:
  - `network_timeout`
  - `network_unavailable`
  - `auth_invalid_credentials`
  - `backend_unavailable`
  - `backend_request_failed`
  - `unexpected_error`
- Never show raw backend/internal messages to users.

## Retry and Recovery UX

- Failed actions must expose a clear retry affordance.
- Retry can reuse already entered form values.
- Retry intent must be logged with `email_sign_in_retry_requested`.
- Keep original failure telemetry (`code`, `recoverable`) for incident analysis.

## Operational Signals

- `form_validation_failed`
- `email_sign_in_succeeded`
- `<failure.code>` (from mapped failure detail)
- `email_sign_in_retry_requested`
