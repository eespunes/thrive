## Purpose
Centralize family administration, wallet/bank connections, preferences, and support actions.

## Requirements
### Requirement: Family settings controls
Settings SHALL provide access to members management and base currency configuration.

#### Scenario: Family section visible
- **WHEN** user opens settings
- **THEN** family management and currency configuration actions are available

### Requirement: Wallet and bank connections section
Settings SHALL display active account connections and allow adding a new account.

#### Scenario: Connections management
- **WHEN** user opens banking section
- **THEN** active providers are listed and add account action is available

### Requirement: Preferences and support actions
Settings SHALL include toggles for notifications and dark mode plus support and logout actions.

#### Scenario: Toggle preference
- **WHEN** user changes a preference toggle
- **THEN** the updated preference is persisted and reflected in app behavior
