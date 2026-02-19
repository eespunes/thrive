## Purpose
Import initial spreadsheet data to bootstrap month, categories, and balances.

## Requirements
### Requirement: Excel upload and parsing
Excel upload and parsing SHALL be implemented for stable delivery.

#### Scenario: User uploads spreadsheet
- **WHEN** the user executes the flow
- **THEN** the app stores and renders consistent data

### Requirement: Field mapping and preview
Field mapping and preview SHALL include clear validation and feedback.

#### Scenario: User confirms mapped columns
- **WHEN** an error or edge case occurs
- **THEN** the user receives actionable feedback without losing progress

### Requirement: Import validation report
Import validation report SHALL be reflected across dependent screens and calculations.

#### Scenario: Import contains invalid rows
- **WHEN** related modules are opened after updates
- **THEN** values remain synchronized for the active family and month
