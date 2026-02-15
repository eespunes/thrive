## Purpose
Centralize family planning in a shared calendar accessible to all household members.

## Requirements
### Requirement: Shared calendar workspace
The app SHALL provide a shared family calendar within each workspace.

#### Scenario: Open family calendar
- **WHEN** a family member opens the calendar screen
- **THEN** the app shows events created by all members of that workspace

### Requirement: Family event lifecycle management
Members SHALL be able to create, edit, and delete family events.

#### Scenario: Create a family event
- **WHEN** a member creates an event with title, date, and time
- **THEN** the event is persisted and visible to all family members

### Requirement: Custom event categories
Users SHALL be able to create and manage custom event categories in addition to default ones.

#### Scenario: Create custom category
- **WHEN** a user creates a new category in calendar settings
- **THEN** the category is available when creating and filtering events

### Requirement: Member assignment per event
Calendar events SHALL support assigning one or more family members.

#### Scenario: Assign members to event
- **WHEN** a user assigns family members during event creation or edit
- **THEN** assignees are stored and visible in event details

### Requirement: Color coding for events and categories
Calendar events and categories SHALL support color selection for visual differentiation.

#### Scenario: Apply event or category color
- **WHEN** a user selects a color for an event or category
- **THEN** calendar views render that event with the selected color consistently

### Requirement: Real-time family synchronization
Calendar changes SHALL synchronize across all family members in the same workspace.

#### Scenario: Event updated by another member
- **WHEN** one family member creates or edits an event
- **THEN** other members see the updated event state without manual refresh
