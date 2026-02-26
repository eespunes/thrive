# Observability, Crash Reporting, and Monitoring Contract

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `ObservabilityMonitoringContract` | Mobile Platform + SRE | Enforce structured logs, crash capture, and threshold-based alert routing. |
| `CrashReportingGateway` | Mobile Platform + SRE | Persist crash diagnostics and release-health context. |
| `AlertRoutingGateway` | SRE | Route incidents to the owning on-call team. |

## Structured Logging Standard

- Structured logs require stable `code`, `message`, and `owner` fields.
- Invalid structured payloads fail with `structured_log_invalid`.
- Logs are emitted with deterministic metadata and stable operational codes.

## Crash Reporting and Release Health

- Crash reports require `errorType`, `releaseVersion`, and `environment`.
- Invalid reports fail with `crash_report_invalid`.
- Successful crash capture emits `crash_report_captured`.
- Release health computes crash-free rate and compares against threshold.

## Alert Routing and Incident Ownership

- Alert rules require `ruleCode`, positive `threshold`, and `ownerTeam`.
- Threshold breaches route incidents via `AlertRoutingGateway` and emit `alert_routed`.
- Non-breaches emit `alert_threshold_not_reached`.

## Operational Signals

- `structured_log_invalid`
- `crash_report_captured`
- `crash_report_capture_failed`
- `release_health_healthy`
- `release_health_below_threshold`
- `alert_threshold_not_reached`
- `alert_routed`
- `alert_routing_failed`

## Recovery Guidance

- Preserve stable codes for dashboarding and alert rules.
- Keep user-safe messaging detached from internal stack details.
- Route severe threshold events to on-call owners without manual triage delays.
