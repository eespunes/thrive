## Purpose
Manage favorite supermarkets and detect nearby stores for planning.

## Requirements
### Requirement: Favorites management
Favorites management SHALL be supported with family-scoped data consistency.

#### Scenario: Add favorite supermarket
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Nearby supermarket suggestions
Nearby supermarket suggestions SHALL include transparent status and fallback behavior.

#### Scenario: Location permission granted
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Store preference persistence
Store preference persistence SHALL be measurable with quality indicators and timestamps.

#### Scenario: Family updates preferred store
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
