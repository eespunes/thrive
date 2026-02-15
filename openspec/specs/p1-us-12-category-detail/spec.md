## Purpose
Show per-category budget status and recent transactions to control category spending.

## Requirements
### Requirement: Category budget status card
Category detail SHALL display remaining amount, total limit, and progress percentage.

#### Scenario: Category detail opened
- **WHEN** user opens a budget category card
- **THEN** the screen shows current remaining budget and progress bar

### Requirement: Category recent transactions
Category detail SHALL list recent transactions assigned to that category.

#### Scenario: Category transaction list shown
- **WHEN** category detail is loaded
- **THEN** recent movements in that category are displayed with amount and payer

### Requirement: Edit limit action
Category detail SHALL provide action to edit budget limit.

#### Scenario: Edit limit tapped
- **WHEN** user taps edit limit
- **THEN** app navigates to limit edition screen
