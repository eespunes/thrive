## Purpose
Connect grocery planning with family budgets to make spending impact visible before purchases.

## Requirements
### Requirement: Shared shopping list management
The app SHALL allow family members to create, edit, complete, and remove shopping list items.

#### Scenario: Item lifecycle in shopping list
- **WHEN** a user adds or updates a shopping item
- **THEN** the list reflects changes for all family members in the workspace

### Requirement: Estimated cost per item
Shopping list items SHALL support an estimated cost value.

#### Scenario: Add estimated price to item
- **WHEN** a user sets an estimated amount for an item
- **THEN** the value is stored and included in list totals

### Requirement: Budget impact summary
The shopping list screen SHALL show estimated total and budget impact for the current period.

#### Scenario: View projected spend
- **WHEN** the user opens the shopping list
- **THEN** the app displays projected spend and remaining budget delta

### Requirement: Favorite and nearby supermarkets
The app SHALL allow families to register favorite supermarkets and suggest nearby supermarkets.

#### Scenario: Select supermarket for a list
- **WHEN** a user creates or edits a shopping list
- **THEN** the user can assign a preferred supermarket from favorites or nearby options

### Requirement: Product search scoped by supermarket
Shopping item entry SHALL support product search contextualized to the selected supermarket.

#### Scenario: Search product in selected supermarket
- **WHEN** a user types a product while a supermarket is assigned
- **THEN** the app returns product suggestions for that supermarket

### Requirement: Fallback product search without supermarket
The app SHALL provide generic product suggestions when no supermarket is selected.

#### Scenario: Search product without assigned supermarket
- **WHEN** a user types a product and no supermarket is linked
- **THEN** the app shows non-store-specific suggestions and prompts optional supermarket selection
