## Purpose
Provide collaborative household task lists to coordinate recurring and ad-hoc chores.

## Requirements
### Requirement: Shared task list creation
The app SHALL allow users to create shared task lists and tasks within a family workspace.

#### Scenario: Create task in shared list
- **WHEN** a user creates a task
- **THEN** the task is visible to other members with title, due date, and status

### Requirement: Task assignment and ownership
Tasks SHALL support assignment to one or more family members.

#### Scenario: Assign task to member
- **WHEN** a user assigns a task
- **THEN** assignee information is stored and shown in the task row

### Requirement: Completion tracking
The app SHALL track task completion and completion timestamp.

#### Scenario: Mark task as done
- **WHEN** an assignee marks a task completed
- **THEN** status changes to completed and completion metadata is recorded
