## Purpose
Track household savings goals with progress, target date, and deposit actions.

## Requirements
### Requirement: Total savings overview
The goals screen SHALL display aggregate savings total.

#### Scenario: Goals screen opened
- **WHEN** user opens goals
- **THEN** total saved amount is displayed at top

### Requirement: Goal cards with progress and target
Each goal SHALL show saved amount versus target, progress percentage, and target date.

#### Scenario: Goal card rendering
- **WHEN** goals are loaded
- **THEN** each goal displays progress information and deadline text

### Requirement: Deposit action per goal
Users SHALL be able to add deposits directly from each goal card.

#### Scenario: Deposit button tapped
- **WHEN** user taps deposit on a goal card
- **THEN** deposit flow opens and updates goal progress after confirmation
