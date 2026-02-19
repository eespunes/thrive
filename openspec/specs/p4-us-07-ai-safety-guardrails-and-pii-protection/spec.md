## Purpose
Protect users with safety rules, data minimization, and PII redaction.

## Requirements
### Requirement: Prompt and response safety filters
Prompt and response safety filters SHALL be supported with family-scoped data consistency.

#### Scenario: Unsafe content generated
- **WHEN** a family member executes the feature
- **THEN** updates are shared correctly according to permissions

### Requirement: PII detection and masking
PII detection and masking SHALL include transparent status and fallback behavior.

#### Scenario: Sensitive data requested
- **WHEN** data is incomplete or external dependencies fail
- **THEN** the app remains usable and communicates limitations

### Requirement: Policy enforcement observability
Policy enforcement observability SHALL be measurable with quality indicators and timestamps.

#### Scenario: Safety event reviewed
- **WHEN** results are displayed
- **THEN** users can see freshness, confidence, and source context
