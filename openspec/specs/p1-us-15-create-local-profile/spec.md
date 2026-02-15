## Purpose
Create local profiles for children or other dependents without account authentication.

## Requirements
### Requirement: Local profile form
Create local profile screen SHALL support avatar, name, profile type, and optional description.

#### Scenario: Save local profile
- **WHEN** user completes required fields and saves
- **THEN** a local profile is created and appears in members management

### Requirement: Profile type selection
Form SHALL allow selecting profile type between child and other.

#### Scenario: Select profile type
- **WHEN** user chooses child or other option
- **THEN** selected type is stored as part of profile metadata
