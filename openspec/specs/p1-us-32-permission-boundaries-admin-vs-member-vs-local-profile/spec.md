## Purpose
Enforce role boundaries for admin, adult member, and local profile actions.

## Requirements
### Requirement: Role-based action permissions
Role-based action permissions SHALL be implemented for stable delivery.

#### Scenario: Member attempts restricted action
- **WHEN** the user executes the flow
- **THEN** the app stores and renders consistent data

### Requirement: UI gating by role
UI gating by role SHALL include clear validation and feedback.

#### Scenario: Local profile opens protected section
- **WHEN** an error or edge case occurs
- **THEN** the user receives actionable feedback without losing progress

### Requirement: Permission error handling
Permission error handling SHALL be reflected across dependent screens and calculations.

#### Scenario: Unauthorized backend write attempted
- **WHEN** related modules are opened after updates
- **THEN** values remain synchronized for the active family and month
