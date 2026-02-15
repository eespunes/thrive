## Purpose
Allow users to join an existing family workspace using an invitation code.

## Requirements
### Requirement: Invitation code join flow
The app SHALL provide an input for invitation code and join action.

#### Scenario: Join family with valid code
- **WHEN** a user submits a valid invitation code
- **THEN** the user is added to that family and routed to dashboard

### Requirement: Invalid code feedback
The join flow SHALL provide clear feedback for invalid invitation codes.

#### Scenario: Invalid invitation code
- **WHEN** submitted code is invalid or expired
- **THEN** the user sees an error message and can retry
