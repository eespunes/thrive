## Purpose
Authenticate users quickly with social sign-in and optional email sign-in entry.

## Requirements
### Requirement: Google login entrypoint
The login screen SHALL provide a primary "Continue with Google" action.

#### Scenario: Google sign-in success
- **WHEN** the user taps the Google button and authentication succeeds
- **THEN** the user enters the post-login family entry flow

### Requirement: Secondary email sign-in option
The login screen SHALL expose a secondary email sign-in path.

#### Scenario: Email auth selection
- **WHEN** the user taps the email sign-in option
- **THEN** the app opens the email authentication flow
