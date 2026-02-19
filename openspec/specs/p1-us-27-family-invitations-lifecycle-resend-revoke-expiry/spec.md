## Purpose
Manage family invitations with resend, revoke, and expiration controls.

## Requirements
### Requirement: Invitation lifecycle state model
Invitation lifecycle state model SHALL be implemented for stable delivery.

#### Scenario: Invitation created and pending
- **WHEN** the user executes the flow
- **THEN** the app stores and renders consistent data

### Requirement: Resend and revoke actions
Resend and revoke actions SHALL include clear validation and feedback.

#### Scenario: Admin revokes invitation
- **WHEN** an error or edge case occurs
- **THEN** the user receives actionable feedback without losing progress

### Requirement: Expiration and retry flow
Expiration and retry flow SHALL be reflected across dependent screens and calculations.

#### Scenario: Invitation expired
- **WHEN** related modules are opened after updates
- **THEN** values remain synchronized for the active family and month
