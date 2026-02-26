# Privacy, Consent, Retention, and Account Deletion

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `PrivacyLifecycleContract` | Privacy + Compliance + Mobile Platform | Enforce consent linkage, retention schedule evaluation, and account deletion workflow safeguards. |

## Consent Records and Policy Linkage

- Consent capture requires `userId`, `policyVersion`, and source attribution.
- Consent events are logged with deterministic metadata for auditability.

## Retention Schedule Enforcement

- Retention items include type, creation timestamp, and retention window.
- Evaluation returns deterministic sets of expired vs retained IDs.
- Invalid retention items fail with stable codes.

## Account Deletion Workflow

- Deletion requests validate identity and workspace scope.
- Legal hold and pending-settlement states block deletion.
- Successful scheduling and completion emit deterministic workflow signals.

## Operational Signals

- `privacy_consent_recorded`
- `privacy_retention_evaluated`
- `privacy_account_deletion_scheduled`
- `privacy_account_deletion_completed`
- `privacy_deletion_legal_hold`
- `privacy_deletion_pending_settlement`

## Recovery Guidance

- Keep user-facing deletion blockers clear and non-technical.
- Require legal/compliance review for legal-hold scenarios.
- Track purge counts and completion timestamps for audit trails.
