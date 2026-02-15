## Purpose
Provide monthly analytics aligned with the budget spreadsheet to understand category distribution and totals.

## Requirements
### Requirement: Period switcher
Reports SHALL support this month, previous month, and year views.

#### Scenario: Switch reporting period
- **WHEN** user changes period
- **THEN** all charts and totals refresh to selected scope

### Requirement: Spend distribution and total
Reports SHALL display total spent and category percentage distribution.

#### Scenario: Report chart render
- **WHEN** data is available
- **THEN** donut chart and total spent amount are shown

### Requirement: Category breakdown list
Reports SHALL list categories with amount and share percentage.

#### Scenario: Breakdown list loaded
- **WHEN** report view is rendered
- **THEN** each category line shows amount and percentage values
