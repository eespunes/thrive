## Purpose
Resolve duplicate imports and conflicting edits safely.

## Requirements
### Requirement: Conflict detection and merge rules
Conflict detection and merge rules SHALL be supported with family-scoped data consistency.

#### Scenario: Two users edit same event
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Deduplication by source identifiers
Deduplication by source identifiers SHALL include transparent status and fallback behavior.

#### Scenario: Reimport same source event
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Conflict status communication
Conflict status communication SHALL be measurable with quality indicators and timestamps.

#### Scenario: User opens conflicted event
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
