## Purpose
Provide generic product search when store-specific data is unavailable.

## Requirements
### Requirement: Generic search fallback activation
Generic search fallback activation SHALL be supported with family-scoped data consistency.

#### Scenario: No store selected
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Fallback result labeling
Fallback result labeling SHALL include transparent status and fallback behavior.

#### Scenario: Generic suggestions displayed
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Prompt to improve precision
Prompt to improve precision SHALL be measurable with quality indicators and timestamps.

#### Scenario: User asked to select store
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
