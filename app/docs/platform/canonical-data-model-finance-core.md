# Canonical Data Model for Finance Core

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `CanonicalFinanceModelContract` | Mobile Platform + Finance Domain | Validate canonical entity integrity and schema compatibility before save/sync operations. |
| `CanonicalFinanceEntity` + `CanonicalEntityReference` | Mobile Platform + Finance Domain | Represent stable IDs, workspace scope, typed relationships, and soft-delete metadata. |

## Canonical Entity Rules

- Canonical entities must define a stable `id`, `workspaceId`, `entityType`, and `schemaVersion`.
- Entity save validation fails fast for empty IDs or unsupported schema versions.
- Soft-deleted entities are immutable for active save paths.

## Referential Integrity and Soft Deletion

- Every reference in `references` must resolve to an existing typed entity.
- Missing references return deterministic failure code `canonical_reference_missing`.
- Soft deletion uses `deletedAt` and preserves record history for audit/recovery.
- Duplicate delete attempts return `canonical_already_deleted`.

## Schema Versioning and Migration

- Canonical entities use explicit integer schema versions.
- Downgrade migrations are not allowed (`canonical_schema_downgrade_not_supported`).
- Target migration version must match runtime contract version (`canonical_schema_target_invalid`).
- Successful migrations emit `canonical_schema_migrated` with from/to version metadata.

## Operational Signals

- `canonical_entity_saved_contract_validated`
- `canonical_referential_integrity_passed`
- `canonical_entity_soft_deleted`
- `canonical_schema_migrated`
- `canonical_entity_invalid`
- `canonical_schema_version_unsupported`
- `canonical_reference_missing`
- `canonical_entity_deleted`

## Recovery Guidance

- Prompt user refresh/retry for recoverable integrity or schema mismatches.
- Never expose internal schema details in user-facing strings.
- Preserve deleted entities for safe recovery and diagnostics.
