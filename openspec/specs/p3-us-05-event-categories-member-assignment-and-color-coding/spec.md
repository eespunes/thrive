## Purpose
Support rich event metadata with categories, assignees, and colors.

## Requirements
### Requirement: Category and color governance
Category and color governance SHALL be supported with family-scoped data consistency.

#### Scenario: User creates category and color
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Member assignment rules
Member assignment rules SHALL include transparent status and fallback behavior.

#### Scenario: Assign multiple members
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Consistent rendering across views
Consistent rendering across views SHALL be measurable with quality indicators and timestamps.

#### Scenario: Calendar view switched
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
