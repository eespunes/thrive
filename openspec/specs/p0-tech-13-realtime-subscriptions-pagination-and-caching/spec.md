## Purpose
Define realtime listeners, pagination windows, and cache invalidation rules.

## Requirements
### Requirement: Realtime subscription lifecycle
Realtime subscription lifecycle SHALL be implemented for stable delivery.

#### Scenario: User enters and leaves screen
- **WHEN** the feature is configured and used
- **THEN** behavior follows the defined contract and is observable

### Requirement: Cursor pagination and ordering
Cursor pagination and ordering SHALL be implemented with clear success and failure handling.

#### Scenario: Large dataset loaded
- **WHEN** normal and error paths are exercised
- **THEN** the system returns deterministic outcomes and user-safe feedback

### Requirement: Cache TTL and invalidation
Cache TTL and invalidation SHALL be documented with ownership and operational criteria.

#### Scenario: Underlying data changes
- **WHEN** operations teams review runtime behavior
- **THEN** they can diagnose issues and recover without data loss
