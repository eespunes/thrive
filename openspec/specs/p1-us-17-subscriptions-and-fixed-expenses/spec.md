## Purpose
Manage fixed expenses and subscriptions with monthly paid state and recurring schedule visibility.

## Requirements
### Requirement: Fixed-expense total summary
Subscriptions screen SHALL show the active month total for fixed expenses.

#### Scenario: Open fixed-expenses screen
- **WHEN** user opens subscriptions module
- **THEN** monthly fixed total is displayed at top

### Requirement: Recurring item details
Each recurring item SHALL include schedule day/date, amount, and active toggle.

#### Scenario: Recurring row displayed
- **WHEN** list is rendered
- **THEN** each row shows cadence text, amount, and toggle state

### Requirement: Paid-state per month
Recurring items SHALL support paid-state for the active month.

#### Scenario: Recurring item pending
- **WHEN** item is enabled but unpaid in current month
- **THEN** it is counted in pending totals until marked paid
