# Cloud Functions Contracts and Idempotency

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `CloudFunctionContractExecutor` | Mobile Platform + Backend Platform | Validate function request/response contracts, retries, and idempotent flow. |
| `FunctionIdempotencyStore` | Mobile Platform + Backend Platform | Persist/replay deterministic responses by idempotency key. |
| `CloudFunctionGateway` | Backend Platform | Execute backend function calls and return standardized contract responses. |

## Function Input/Output Contract

- Requests require non-empty `functionName` and `idempotencyKey`.
- Responses must return success HTTP-like status (`2xx`) to be accepted.
- Invalid response status returns `cloud_function_invalid_response`.

## Idempotency and Duplicate Prevention

- Executor reads idempotency store before invoking backend.
- Existing stored response is returned as replay (`cloud_function_idempotent_replay`).
- Successful backend responses are persisted before returning to caller.

## Retry and Backoff Policy

- Retries are attempted only for recoverable failures.
- Delay is computed from bounded exponential backoff policy.
- Retry schedule emits `cloud_function_retry_scheduled` with attempt metadata.
- Non-recoverable failures stop retries immediately.

## Operational Signals

- `cloud_function_invocation_received`
- `cloud_function_invocation_succeeded`
- `cloud_function_retry_scheduled`
- `cloud_function_idempotent_replay`
- `cloud_function_invocation_failed`
- `cloud_function_request_invalid`
- `cloud_function_invalid_response`

## Recovery Guidance

- Keep user messaging action-oriented and non-technical on transient failure.
- Preserve stable failure codes for runbooks and automated alert routing.
- Always include idempotency keys for write-like operations to prevent duplicates.
