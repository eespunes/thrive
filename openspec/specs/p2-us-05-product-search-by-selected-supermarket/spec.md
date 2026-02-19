## Purpose
Search products constrained to selected supermarket catalogs.

## Requirements
### Requirement: Supermarket-scoped product search
Supermarket-scoped product search SHALL be supported with family-scoped data consistency.

#### Scenario: Search product in assigned store
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Autocomplete ranking and relevance
Autocomplete ranking and relevance SHALL include transparent status and fallback behavior.

#### Scenario: Multiple similar products returned
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Store-specific availability state
Store-specific availability state SHALL be measurable with quality indicators and timestamps.

#### Scenario: Item unavailable in selected store
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
