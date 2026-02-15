## Purpose
Help families reduce grocery spending by comparing basket prices across supermarkets with transparent data quality.

## Requirements
### Requirement: Basket comparison across supermarkets
The app SHALL compare estimated total basket cost across selected supermarkets.

#### Scenario: Compare basket totals
- **WHEN** a user has a shopping list with comparable product matches in multiple supermarkets
- **THEN** the app shows total basket estimate per supermarket and highlights the cheapest option

### Requirement: Favorite and nearby supermarket scope
Comparison SHALL prioritize family favorite supermarkets and nearby stores.

#### Scenario: Comparison scope selection
- **WHEN** user opens comparison
- **THEN** the default comparison includes favorites and nearby supermarkets with option to adjust scope

### Requirement: MVP data source strategy
The initial implementation SHALL support manual/community price entries as a primary source.

#### Scenario: No official feed available
- **WHEN** official supermarket price feed is unavailable
- **THEN** product comparison uses latest user-contributed prices and marks source as community data

### Requirement: Price freshness and confidence
Each compared price SHALL include timestamp and confidence level metadata.

#### Scenario: Show data quality
- **WHEN** comparison results are rendered
- **THEN** each price line shows last-updated information and confidence indicator

### Requirement: Product normalization for fair comparison
Comparison engine SHALL normalize products by unit/quantity to avoid invalid price ranking.

#### Scenario: Different package sizes
- **WHEN** equivalent products have different package quantities
- **THEN** the app compares using normalized unit price and explains conversion

### Requirement: Fallback behavior for missing matches
The app SHALL handle missing product matches gracefully in supermarket comparisons.

#### Scenario: Product unavailable in a supermarket
- **WHEN** an item cannot be matched for a selected supermarket
- **THEN** the app flags the item as missing and recalculates basket total with clear partial-coverage warning

