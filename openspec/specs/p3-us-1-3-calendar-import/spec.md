## Purpose
Allow families to import external calendars so existing schedules are available inside Thrive without manual re-entry.

## Requirements
### Requirement: External calendar connection setup
The app SHALL allow users to connect one or more external calendar sources.

#### Scenario: Connect external calendar account
- **WHEN** a user completes the external calendar connection flow
- **THEN** the account is linked and available for calendar import configuration

### Requirement: Selective calendar import
Users SHALL be able to choose which calendars to import from a connected source.

#### Scenario: Choose calendars to import
- **WHEN** a user selects specific calendars from the connected account
- **THEN** only selected calendars are imported into the family calendar view

### Requirement: Conflict-safe imported events
Imported events SHALL preserve source metadata and avoid duplicate event creation.

#### Scenario: Re-import same source data
- **WHEN** the app syncs already imported calendar data again
- **THEN** matching events are updated in place instead of duplicated

### Requirement: Import sync visibility
The app SHALL show import status, last successful sync time, and sync errors.

#### Scenario: Review import health
- **WHEN** a user opens calendar import settings
- **THEN** the app displays current sync state and any actionable errors
