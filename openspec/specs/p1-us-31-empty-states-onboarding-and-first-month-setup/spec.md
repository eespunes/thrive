## Purpose
Guide users with clear empty states and first-month setup actions.

## Requirements
### Requirement: Contextual empty states
Contextual empty states SHALL be implemented for stable delivery.

#### Scenario: Open empty module
- **WHEN** the user executes the flow
- **THEN** the app stores and renders consistent data

### Requirement: Actionable onboarding prompts
Actionable onboarding prompts SHALL include clear validation and feedback.

#### Scenario: User follows first setup prompt
- **WHEN** an error or edge case occurs
- **THEN** the user receives actionable feedback without losing progress

### Requirement: Completion progress across setup
Completion progress across setup SHALL be reflected across dependent screens and calculations.

#### Scenario: User partially completes setup
- **WHEN** related modules are opened after updates
- **THEN** values remain synchronized for the active family and month
