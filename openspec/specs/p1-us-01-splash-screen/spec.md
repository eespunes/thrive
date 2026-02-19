## Purpose
Present a branded splash entry that initializes app session and routes users to the proper next screen.

## Visual Assets
- `app/assets/logos/thrive-unicolor.svg` (splash primary mark)

## Requirements
### Requirement: Branded splash presentation
The app SHALL show the Thrive brand splash screen at app startup.

#### Scenario: App launch shows splash
- **WHEN** the user opens the app
- **THEN** a branded splash screen is displayed before navigation continues

### Requirement: Startup routing
The splash flow SHALL route users to login or family dashboard based on session state.

#### Scenario: Session-aware routing
- **WHEN** startup checks complete
- **THEN** the app navigates to authentication for unauthenticated users or main app for authenticated users
