## Purpose
Define Firestore security rules mapped to workspace roles and resources.

## Requirements
### Requirement: Resource-level read/write matrix
Resource-level read/write matrix SHALL be implemented for stable delivery.

#### Scenario: Client reads protected doc
- **WHEN** the feature is configured and used
- **THEN** behavior follows the defined contract and is observable

### Requirement: Rule tests for allowed and denied paths
Rule tests for allowed and denied paths SHALL be implemented with clear success and failure handling.

#### Scenario: Rule test suite runs
- **WHEN** normal and error paths are exercised
- **THEN** the system returns deterministic outcomes and user-safe feedback

### Requirement: Least privilege defaults
Least privilege defaults SHALL be documented with ownership and operational criteria.

#### Scenario: Unknown role requests access
- **WHEN** operations teams review runtime behavior
- **THEN** they can diagnose issues and recover without data loss
