## Purpose
Convert purchased list items into transactions with minimal friction.

## Requirements
### Requirement: List item to movement conversion
List item to movement conversion SHALL be supported with family-scoped data consistency.

#### Scenario: User marks purchase completed
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Category and payer mapping
Category and payer mapping SHALL include transparent status and fallback behavior.

#### Scenario: Converted item needs category
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Duplicate conversion prevention
Duplicate conversion prevention SHALL be measurable with quality indicators and timestamps.

#### Scenario: Already converted item reprocessed
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
