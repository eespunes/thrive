## Purpose
Provide a monthly control center that mirrors the Excel monthly overview with actionable financial status.

## Requirements
### Requirement: Monthly summary cards
Dashboard SHALL display core monthly metrics including balance and pending obligations.

#### Scenario: Dashboard monthly snapshot
- **WHEN** user opens home for the active month
- **THEN** the app shows summary values for balance and still-to-pay amounts

### Requirement: Budget category cards and recent activity
Dashboard SHALL show category cards and latest movements for quick review.

#### Scenario: Dashboard detail content
- **WHEN** monthly data is loaded
- **THEN** category cards and recent movement items are visible and updated

### Requirement: Navigation to block details
Dashboard SHALL provide direct entry to block-specific detail screens.

#### Scenario: Category card selected
- **WHEN** user taps a category card
- **THEN** app opens that category detail with limit and recent transactions
