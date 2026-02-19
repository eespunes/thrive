## Purpose
Allow community price submissions with moderation and abuse controls.

## Requirements
### Requirement: Community price contribution flow
Community price contribution flow SHALL be supported with family-scoped data consistency.

#### Scenario: User submits a price
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Moderation and trust scoring
Moderation and trust scoring SHALL include transparent status and fallback behavior.

#### Scenario: Suspicious contribution detected
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Rollback and correction process
Rollback and correction process SHALL be measurable with quality indicators and timestamps.

#### Scenario: Incorrect price reported
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
