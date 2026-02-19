## Purpose
Run what-if scenarios to project budget outcomes before decisions.

## Requirements
### Requirement: Scenario input and assumptions
Scenario input and assumptions SHALL be supported with family-scoped data consistency.

#### Scenario: User creates simulation
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Projection model and confidence
Projection model and confidence SHALL include transparent status and fallback behavior.

#### Scenario: Sparse historical data
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Scenario comparison and save
Scenario comparison and save SHALL be measurable with quality indicators and timestamps.

#### Scenario: User compares two scenarios
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
