## Purpose
Define Firebase project separation and environment configuration management.

## Requirements
### Requirement: Environment isolation and config loading
Environment isolation and config loading SHALL be implemented for stable delivery.

#### Scenario: App boots in each env
- **WHEN** the feature is configured and used
- **THEN** behavior follows the defined contract and is observable

### Requirement: Service account and deploy targeting
Service account and deploy targeting SHALL be implemented with clear success and failure handling.

#### Scenario: CI deploy runs
- **WHEN** normal and error paths are exercised
- **THEN** the system returns deterministic outcomes and user-safe feedback

### Requirement: Environment drift detection
Environment drift detection SHALL be documented with ownership and operational criteria.

#### Scenario: Config mismatch identified
- **WHEN** operations teams review runtime behavior
- **THEN** they can diagnose issues and recover without data loss
