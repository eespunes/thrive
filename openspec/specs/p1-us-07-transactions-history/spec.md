## Purpose
Provide chronological transaction history with paid-state visibility for monthly reconciliation.

## Requirements
### Requirement: Date-grouped movement history
History screen SHALL display movements grouped by date labels.

#### Scenario: History list render
- **WHEN** user opens movements
- **THEN** transactions are grouped by day and show signed amount and payer

### Requirement: Paid and pending visibility
History entries SHALL expose whether a movement is paid/received or still pending.

#### Scenario: Pending movement in history
- **WHEN** a movement is not marked paid
- **THEN** the entry displays pending state distinctly from paid entries

### Requirement: Monthly net indicator
History screen SHALL show current month net context at top.

#### Scenario: Monthly card visible
- **WHEN** movements screen loads
- **THEN** a month-level net summary card is displayed
