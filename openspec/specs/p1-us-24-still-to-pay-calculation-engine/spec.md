## Purpose
Compute still-to-pay based on pending debts, subscriptions, and pending expenses.

## Requirements
### Requirement: Pending obligations aggregation
Pending obligations aggregation SHALL be implemented for stable delivery.

#### Scenario: Open still-to-pay card
- **WHEN** the user executes the flow
- **THEN** the app stores and renders consistent data

### Requirement: Paid state recalculation
Paid state recalculation SHALL include clear validation and feedback.

#### Scenario: Pending item marked paid
- **WHEN** an error or edge case occurs
- **THEN** the user receives actionable feedback without losing progress

### Requirement: Category-level pending drilldown
Category-level pending drilldown SHALL be reflected across dependent screens and calculations.

#### Scenario: View pending by category
- **WHEN** related modules are opened after updates
- **THEN** values remain synchronized for the active family and month
