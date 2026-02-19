## Purpose
Generate recurring movements for subscriptions, incomes, and fixed obligations.

## Requirements
### Requirement: Recurring rule definition
Recurring rule definition SHALL be implemented for stable delivery.

#### Scenario: Create monthly recurring rule
- **WHEN** the user executes the flow
- **THEN** the app stores and renders consistent data

### Requirement: Automatic generation schedule
Automatic generation schedule SHALL include clear validation and feedback.

#### Scenario: Recurrence execution date reached
- **WHEN** an error or edge case occurs
- **THEN** the user receives actionable feedback without losing progress

### Requirement: Duplicate prevention for recurrence runs
Duplicate prevention for recurrence runs SHALL be reflected across dependent screens and calculations.

#### Scenario: Recurrence rerun attempted
- **WHEN** related modules are opened after updates
- **THEN** values remain synchronized for the active family and month
