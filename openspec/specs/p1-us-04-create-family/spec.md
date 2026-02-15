## Purpose
Create a new family workspace with base settings needed to start using the app.

## Requirements
### Requirement: Family creation form
The app SHALL collect family name and base currency during family creation.

#### Scenario: Create family with required fields
- **WHEN** the user submits valid family name and base currency
- **THEN** a new family workspace is created and user is assigned admin role

### Requirement: Post-creation routing
After successful family creation, the app SHALL route to the main dashboard.

#### Scenario: Family creation completed
- **WHEN** family setup is successful
- **THEN** the user enters the main app home screen
