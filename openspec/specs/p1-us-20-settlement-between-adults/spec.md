## Purpose
Calculate monthly settlement between adult members to show who owes whom.

## Requirements
### Requirement: Monthly settlement calculation
Monthly settlement calculation SHALL be implemented for stable delivery.

#### Scenario: Generate settlement at month end
- **WHEN** the user executes the flow
- **THEN** the app stores and renders consistent data

### Requirement: Per-member contribution tracking
Per-member contribution tracking SHALL include clear validation and feedback.

#### Scenario: Member contribution updated
- **WHEN** an error or edge case occurs
- **THEN** the user receives actionable feedback without losing progress

### Requirement: Settlement explanation details
Settlement explanation details SHALL be reflected across dependent screens and calculations.

#### Scenario: Open settlement breakdown
- **WHEN** related modules are opened after updates
- **THEN** values remain synchronized for the active family and month
