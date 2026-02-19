## Purpose
Translate natural-language questions into explainable financial answers.

## Requirements
### Requirement: NL-to-query interpretation
NL-to-query interpretation SHALL be supported with family-scoped data consistency.

#### Scenario: User asks ambiguous question
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: Explainability of results
Explainability of results SHALL include transparent status and fallback behavior.

#### Scenario: User requests why answer
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Clarification prompts
Clarification prompts SHALL be measurable with quality indicators and timestamps.

#### Scenario: Intent confidence is low
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
