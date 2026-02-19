## Purpose
Allow safe transaction edit/delete with traceable history of changes.

## Requirements
### Requirement: Transaction edit with validation
Transaction edit with validation SHALL be implemented for stable delivery.

#### Scenario: Edit existing movement
- **WHEN** the user executes the flow
- **THEN** the app stores and renders consistent data

### Requirement: Soft delete and restore behavior
Soft delete and restore behavior SHALL include clear validation and feedback.

#### Scenario: Delete movement
- **WHEN** an error or edge case occurs
- **THEN** the user receives actionable feedback without losing progress

### Requirement: Change log visibility
Change log visibility SHALL be reflected across dependent screens and calculations.

#### Scenario: Review transaction history events
- **WHEN** related modules are opened after updates
- **THEN** values remain synchronized for the active family and month
