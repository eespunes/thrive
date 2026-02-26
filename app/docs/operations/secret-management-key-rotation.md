# Secret Management and Key Rotation

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `SecretManagementContract` | Security + SRE + Backend Platform | Enforce least-privilege secret access, rotation windows, and leak response workflow. |

## Secret Distribution and Least Privilege

- Access requests must match secret scope (name + environment).
- Allowed roles are explicit per secret descriptor.
- Unauthorized roles fail with `secret_access_denied`.

## Automated Key Rotation

- Rotation evaluates configured window from last rotation timestamp.
- If not due, contract returns `secret_rotation_not_due` deterministic state.
- Due rotations require strictly increasing version numbers.

## Leak Response Process

- Leak incidents generate deterministic response actions:
- revoke exposed credential
- rotate + redeploy dependent services
- audit access logs and notify owner

## Operational Signals

- `secret_access_granted`
- `secret_access_denied`
- `secret_rotation_not_due`
- `secret_rotation_completed`
- `secret_rotation_version_invalid`
- `secret_leak_response_plan_created`

## Recovery Guidance

- Rotate compromised credentials immediately and validate dependent service health.
- Preserve incident metadata for postmortem and compliance reporting.
- Keep secret names/version references stable in audit logs, not secret values.
