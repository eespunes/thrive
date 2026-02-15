## Purpose
Manage family participants, invitations, and local-only profiles from a dedicated screen.

## Requirements
### Requirement: Members and local profiles list
Members management SHALL display registered family members and local profiles without accounts.

#### Scenario: Open members management
- **WHEN** user opens members screen
- **THEN** app shows both connected members and local profiles sections

### Requirement: Invite adults and create local profile actions
Members screen SHALL provide actions to invite adults by email and create local child/other profiles.

#### Scenario: Trigger invite action
- **WHEN** user taps invite by email
- **THEN** invite flow starts for adult member onboarding
