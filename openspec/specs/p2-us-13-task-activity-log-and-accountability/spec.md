## Purpose
Provide task activity timeline for transparency and accountability.

## Requirements
### Requirement: Task activity events
Task activity events SHALL be supported with family-scoped data consistency.

#### Scenario: Task state changes
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Actor attribution
Actor attribution SHALL include transparent status and fallback behavior.

#### Scenario: Member edits task
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Audit timeline visibility
Audit timeline visibility SHALL be measurable with quality indicators and timestamps.

#### Scenario: User reviews task history
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
