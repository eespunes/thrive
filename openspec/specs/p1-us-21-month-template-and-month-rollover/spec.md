## Purpose
Create new month from template and carry over selected recurring structures.

## Requirements
### Requirement: Month initialization flow
Month initialization flow SHALL be implemented for stable delivery.

#### Scenario: Initialize new month
- **WHEN** the user executes the flow
- **THEN** the app stores and renders consistent data

### Requirement: Rollover rules for recurring blocks
Rollover rules for recurring blocks SHALL include clear validation and feedback.

#### Scenario: Copy recurring data to new month
- **WHEN** an error or edge case occurs
- **THEN** the user receives actionable feedback without losing progress

### Requirement: Rollover audit and status
Rollover audit and status SHALL be reflected across dependent screens and calculations.

#### Scenario: Review generated month summary
- **WHEN** related modules are opened after updates
- **THEN** values remain synchronized for the active family and month
