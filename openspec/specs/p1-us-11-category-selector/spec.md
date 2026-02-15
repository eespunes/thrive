## Purpose
Enable fast and searchable category selection during transaction creation.

## Requirements
### Requirement: Searchable category list
The category selector SHALL provide search input and list of most-used plus all categories.

#### Scenario: Filter categories by query
- **WHEN** user types a search term
- **THEN** the list is filtered to matching categories

### Requirement: Category confirmation state
The selector SHALL show current selection and return it to the transaction form.

#### Scenario: Select and confirm category
- **WHEN** user taps a category
- **THEN** selection is marked and applied to the transaction flow
