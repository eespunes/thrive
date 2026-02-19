## Purpose
Show freshness, confidence, and source metadata for all prices.

## Requirements
### Requirement: Price metadata schema
Price metadata schema SHALL be supported with family-scoped data consistency.

#### Scenario: Price result rendered
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Confidence computation rules
Confidence computation rules SHALL include transparent status and fallback behavior.

#### Scenario: Mixed-quality data in basket
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Source transparency UX
Source transparency UX SHALL be measurable with quality indicators and timestamps.

#### Scenario: User inspects price origin
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
