## Purpose
Normalize package sizes and units for fair basket comparisons.

## Requirements
### Requirement: Unit normalization engine
Unit normalization engine SHALL be supported with family-scoped data consistency.

#### Scenario: Different package sizes detected
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Equivalent product matching
Equivalent product matching SHALL include transparent status and fallback behavior.

#### Scenario: Alternative product selected
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Normalization explanation
Normalization explanation SHALL be measurable with quality indicators and timestamps.

#### Scenario: User opens comparison details
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
