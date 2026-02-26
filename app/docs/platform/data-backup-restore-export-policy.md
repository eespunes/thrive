# Data Backup, Restore, and Export Policy Contract

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `BackupRestoreExportPolicyContract` | Mobile Platform + Backend Platform + Compliance | Enforce backup cadence, restore validation, and export access controls. |
| `BackupGateway` | Backend Platform | Execute scheduled snapshots with integrity metadata. |
| `RestoreGateway` | Backend Platform + SRE | Execute restore drills and report deterministic outcomes. |
| `ExportGateway` | Backend Platform + Compliance | Generate authorized user exports with access/rate safeguards. |

## Automated Backup Cadence

- Backup cadence supports hourly/daily/weekly intervals.
- `runScheduledBackup` checks due state before execution.
- Not-due runs fail with `backup_not_due`.
- Successful backups emit `backup_job_completed`.

## Restore Runbook and Validation

- Restore drills validate request identity and snapshot integrity.
- Stale snapshots fail with `restore_snapshot_stale`.
- Missing checksum fails with `restore_snapshot_integrity_invalid`.
- Successful restore drill emits `restore_drill_passed`.

## Export Integrity and Access Controls

- Export requests require explicit authorization (`hasAccess`) and rate-limit guard.
- Unauthorized requests fail with `export_access_denied`.
- Rate-limited requests fail with `export_rate_limited`.
- Successful export emits `export_generated`.

## Operational Signals

- `backup_job_completed`
- `backup_job_failed`
- `backup_not_due`
- `backup_integrity_invalid`
- `restore_drill_passed`
- `restore_drill_failed`
- `restore_snapshot_stale`
- `export_generated`
- `export_generation_failed`
- `export_access_denied`
- `export_rate_limited`

## Recovery Guidance

- Keep snapshot integrity metadata (`checksum`, `recordCount`) available for drill diagnostics.
- Execute restore drills regularly with deterministic logs.
- Maintain strict export authorization and throttling to prevent data exposure.
