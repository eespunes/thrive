# Analytics Event Taxonomy Contract

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `AnalyticsEventTaxonomyContract` | Product Analytics + Mobile Platform | Validate event naming, schema, privacy safety, and deprecation policy. |
| `AnalyticsGateway` | Data Platform | Deliver validated analytics events to the analytics backend. |

## Event Naming and Parameter Schema

- Event names must follow `snake_case` naming contract and stable length rules.
- Event definitions are versioned and registered explicitly.
- Missing definitions fail with `analytics_definition_not_found`.
- Missing required params fail with `analytics_param_required_missing`.

## Privacy-Safe Analytics Payloads

- String values are checked for potential PII patterns (email/phone-like values).
- Potential PII payloads fail with `analytics_payload_pii_detected`.
- Unknown parameters fail with `analytics_param_unknown`.

## Versioning and Deprecation

- Definitions are versioned integers (`> 0`) and duplicates are rejected.
- Deprecated definitions reject event validation with `analytics_definition_deprecated`.
- New schemas should be introduced via new version, not in-place mutation.

## Operational Signals

- `analytics_definition_registered`
- `analytics_event_emitted`
- `analytics_emit_failed`
- `analytics_event_name_invalid`
- `analytics_param_required_missing`
- `analytics_param_unknown`
- `analytics_payload_pii_detected`
- `analytics_definition_deprecated`

## Recovery Guidance

- Keep event schema changes backward-compatible with explicit versioning.
- Avoid raw user identifiers/PII in event payloads.
- Use deterministic failure codes to diagnose taxonomy drift.
