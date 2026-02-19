## Purpose
Notify members about upcoming obligations and savings milestones.

## Requirements
### Requirement: Reminder creation and schedule windows
Reminder creation and schedule windows SHALL be implemented for stable delivery.

#### Scenario: Reminder window reached
- **WHEN** the user executes the flow
- **THEN** the app stores and renders consistent data

### Requirement: Per-user reminder preferences
Per-user reminder preferences SHALL include clear validation and feedback.

#### Scenario: Member disables reminder type
- **WHEN** an error or edge case occurs
- **THEN** the user receives actionable feedback without losing progress

### Requirement: Reminder delivery status
Reminder delivery status SHALL be reflected across dependent screens and calculations.

#### Scenario: Notification not delivered
- **WHEN** related modules are opened after updates
- **THEN** values remain synchronized for the active family and month
