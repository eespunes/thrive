## Purpose
Manage family wallets/accounts including default account selection for transaction attribution.

## Requirements
### Requirement: Wallet and account CRUD
Wallet and account CRUD SHALL be implemented for stable delivery.

#### Scenario: Create and edit account
- **WHEN** the user executes the flow
- **THEN** the app stores and renders consistent data

### Requirement: Default account assignment
Default account assignment SHALL include clear validation and feedback.

#### Scenario: Select default wallet
- **WHEN** an error or edge case occurs
- **THEN** the user receives actionable feedback without losing progress

### Requirement: Account deactivation and historical integrity
Account deactivation and historical integrity SHALL be reflected across dependent screens and calculations.

#### Scenario: Archive account with old movements
- **WHEN** related modules are opened after updates
- **THEN** values remain synchronized for the active family and month
