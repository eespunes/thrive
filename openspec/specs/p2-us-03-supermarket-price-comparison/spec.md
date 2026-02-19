## Purpose
Compare basket prices across supermarkets to reduce spending.

## Requirements
### Requirement: Basket total comparison
Basket total comparison SHALL be supported with family-scoped data consistency.

#### Scenario: Compare selected supermarkets
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Coverage and missing-product handling
Coverage and missing-product handling SHALL include transparent status and fallback behavior.

#### Scenario: Product missing in one store
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Price freshness and confidence indicators
Price freshness and confidence indicators SHALL be measurable with quality indicators and timestamps.

#### Scenario: User reviews comparison quality
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
