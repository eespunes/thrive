## Purpose
Handle unmatched products clearly and warn on partial basket totals.

## Requirements
### Requirement: Missing product state
Missing product state SHALL be supported with family-scoped data consistency.

#### Scenario: Product has no match
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Partial basket warning and impact
Partial basket warning and impact SHALL include transparent status and fallback behavior.

#### Scenario: Comparison has incomplete coverage
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: User decision support
User decision support SHALL be measurable with quality indicators and timestamps.

#### Scenario: User chooses store despite gaps
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
