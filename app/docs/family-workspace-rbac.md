# Family Workspace and RBAC Model

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `FamilyWorkspaceRbac` | Mobile Platform + Family Domain | Enforce membership state transitions, protected action authorization, and ownership transfer rules. |
| `FamilyMembership` | Mobile Platform + Family Domain | Represent deterministic workspace membership state, role, and lifecycle timestamps. |

## Membership State Model

- Membership lifecycle states are `invited`, `active`, `suspended`, and `removed`.
- Workspace join flow transitions `invited` to `active` and emits `family_member_joined`.
- Removed memberships are terminal for activation (`family_member_removed`).

## Role Matrix and Protected Actions

- Role matrix:
- `owner`: full workspace control including ownership transfer.
- `admin`: workspace administration without ownership transfer.
- `member`: transactional contribution and workspace access.
- `localProfile`: read-only workspace visibility.
- Authorization must deny inactive memberships with deterministic code `family_membership_inactive`.
- Forbidden actions return `family_action_forbidden` with user-safe feedback.
- Allowed actions emit `family_action_authorized`.

## Role Transition and Auditability

- Ownership transfer requires an active owner actor and an active eligible target member.
- Successful ownership transfer emits `family_ownership_transferred` with previous/new owner identifiers.
- Denied transfer attempts emit deterministic denial codes:
- `family_actor_missing`
- `family_owner_required`
- `family_target_missing`
- `family_target_not_eligible`
- `family_workspace_mismatch`
- `family_self_transfer_invalid`

## Operational Signals

- Info-level success signals:
- `family_member_joined`
- `family_action_authorized`
- `family_ownership_transferred`
- Warning/error operational codes:
- `family_member_removed`
- `family_membership_inactive`
- `family_action_forbidden`
- `family_actor_missing`
- `family_owner_required`
- `family_target_missing`
- `family_target_not_eligible`
- `family_workspace_mismatch`
- `family_self_transfer_invalid`
