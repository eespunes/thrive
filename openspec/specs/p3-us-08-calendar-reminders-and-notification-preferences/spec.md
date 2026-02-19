## Purpose
Deliver calendar reminders with per-member preference controls.

## Requirements
### Requirement: Reminder schedule and channels
Reminder schedule and channels SHALL be supported with family-scoped data consistency.

#### Scenario: Reminder time reached
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Per-member reminder preferences
Per-member reminder preferences SHALL include transparent status and fallback behavior.

#### Scenario: User disables category reminders
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Delivery and snooze behavior
Delivery and snooze behavior SHALL be measurable with quality indicators and timestamps.

#### Scenario: User snoozes reminder
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
