## Purpose
Show expected versus real balance using planned and paid movement states.

## Requirements
### Requirement: Expected balance formula
Expected balance formula SHALL be implemented for stable delivery.

#### Scenario: Open balance summary
- **WHEN** the user executes the flow
- **THEN** the app stores and renders consistent data

### Requirement: Real balance formula
Real balance formula SHALL include clear validation and feedback.

#### Scenario: Mark movement as paid
- **WHEN** an error or edge case occurs
- **THEN** the user receives actionable feedback without losing progress

### Requirement: Variance breakdown
Variance breakdown SHALL be reflected across dependent screens and calculations.

#### Scenario: Inspect expected-real delta
- **WHEN** related modules are opened after updates
- **THEN** values remain synchronized for the active family and month
