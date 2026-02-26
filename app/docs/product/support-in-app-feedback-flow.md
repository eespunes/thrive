# Support and In-App Feedback Flow

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `SupportFeedbackContract` | Customer Support + Mobile Platform | Capture in-app support requests, attach sanitized diagnostics, and enforce SLA ownership workflow. |

## In-App Support Request Capture

- Ticket capture requires stable IDs, category, and meaningful message content.
- Invalid ticket payloads fail with deterministic `support_ticket_invalid`.

## Diagnostic Context Attachment

- Diagnostic context includes app/platform/locale/timezone and log snippets.
- Logs are redacted for PII/secrets before attachment.
- Successful attachment emits `support_diagnostics_attached`.

## Response Workflow and Ownership

- Category-based routing assigns team and SLA hours.
- SLA evaluation returns deterministic breach status and due timestamp.
- Breaches emit `support_sla_breached` for escalation workflows.

## Operational Signals

- `support_ticket_captured`
- `support_diagnostics_attached`
- `support_ticket_assigned`
- `support_sla_on_track`
- `support_sla_breached`
- `support_ticket_invalid`

## Recovery Guidance

- Route high-priority tickets to owning teams with explicit SLA clock start.
- Keep diagnostics sanitized to prevent accidental secret disclosure.
- Escalate breached SLAs via operational runbooks.
