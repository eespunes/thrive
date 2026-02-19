## Purpose
Connect grocery planning with budget visibility before purchases.

## Requirements
### Requirement: Shared shopping list management
Shared shopping list management SHALL be supported with family-scoped data consistency.

#### Scenario: Family updates shopping list
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Estimated cost and budget delta
Estimated cost and budget delta SHALL include transparent status and fallback behavior.

#### Scenario: Open list budget summary
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: List-to-budget synchronization
List-to-budget synchronization SHALL be measurable with quality indicators and timestamps.

#### Scenario: Budget updates after list change
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
