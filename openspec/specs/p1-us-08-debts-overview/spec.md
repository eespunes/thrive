## Purpose
Track debt obligations with due-day, horizon date, paid state, and monthly amount impact.

## Requirements
### Requirement: Debt list with due metadata
Debts screen SHALL list debt items with due day/date, until date, and monthly amount.

#### Scenario: Debt row details
- **WHEN** debt rows are rendered
- **THEN** each row shows due metadata, outstanding context, and amount

### Requirement: Debt paid-state tracking
Each debt item SHALL support paid-state tracking for the active month.

#### Scenario: Debt not yet paid
- **WHEN** monthly debt payment is pending
- **THEN** item appears as pending and contributes to still-to-pay total

### Requirement: Debt progress context
Debt items SHALL show payoff progress and expected completion context.

#### Scenario: Debt progress display
- **WHEN** user views debt row
- **THEN** progress percentage and completion hint are shown
