## Purpose
Expose sync status, errors, and recovery actions for calendar integrations.

## Requirements
### Requirement: Sync health dashboard
Sync health dashboard SHALL be supported with family-scoped data consistency.

#### Scenario: User opens sync settings
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Error diagnostics and retry
Error diagnostics and retry SHALL include transparent status and fallback behavior.

#### Scenario: Sync failure occurs
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Recovery actions and guidance
Recovery actions and guidance SHALL be measurable with quality indicators and timestamps.

#### Scenario: User triggers manual resync
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
