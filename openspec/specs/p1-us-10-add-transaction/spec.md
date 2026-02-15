## Purpose
Capture monthly movements with the same control fields used in the spreadsheet model.

## Requirements
### Requirement: Full transaction capture fields
Add transaction SHALL support amount, type, category, note, date/day, payer account, and split toggle.

#### Scenario: Create transaction with required fields
- **WHEN** user saves a valid transaction
- **THEN** movement is stored with all selected financial metadata

### Requirement: Paid/received state control
Transaction flow SHALL support marking a movement as paid/received at creation or update time.

#### Scenario: Save as pending
- **WHEN** user keeps paid state disabled
- **THEN** movement is stored as pending and contributes to still-to-pay calculations

### Requirement: Category selector integration
Transaction form SHALL open and apply selection from category selector.

#### Scenario: Category chosen
- **WHEN** user selects a category
- **THEN** selected category is applied to transaction form
