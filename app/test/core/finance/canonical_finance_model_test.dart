import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/finance/canonical_finance_model.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('validateForSave succeeds for canonical entity with current schema', () {
    final logger = InMemoryAppLogger();
    final contract = CanonicalFinanceModelContract(
      logger: logger,
      currentSchemaVersion: 3,
    );

    final result = contract.validateForSave(_entity(schemaVersion: 3));

    expect(result, isA<AppSuccess<void>>());
    expect(
      logger.events.map((event) => event.code),
      contains('canonical_entity_saved_contract_validated'),
    );
  });

  test('validateForSave fails for unsupported schema version', () {
    final logger = InMemoryAppLogger();
    final contract = CanonicalFinanceModelContract(
      logger: logger,
      currentSchemaVersion: 3,
    );

    final result = contract.validateForSave(_entity(schemaVersion: 2));

    expect(result, isA<AppFailure<void>>());
    final detail = (result as AppFailure<void>).detail;
    expect(detail.code, 'canonical_schema_version_unsupported');
  });

  test('validateReferentialIntegrity fails when any reference is missing', () {
    final logger = InMemoryAppLogger();
    final contract = CanonicalFinanceModelContract(
      logger: logger,
      currentSchemaVersion: 3,
    );

    final result = contract.validateReferentialIntegrity(
      entity: _entity(
        references: const <CanonicalEntityReference>[
          CanonicalEntityReference(
            type: CanonicalFinanceEntityType.wallet,
            id: 'wallet-1',
          ),
          CanonicalEntityReference(
            type: CanonicalFinanceEntityType.category,
            id: 'category-missing',
          ),
        ],
      ),
      availableReferences: <CanonicalEntityReference>{
        const CanonicalEntityReference(
          type: CanonicalFinanceEntityType.wallet,
          id: 'wallet-1',
        ),
      },
    );

    expect(result, isA<AppFailure<void>>());
    final detail = (result as AppFailure<void>).detail;
    expect(detail.code, 'canonical_reference_missing');
  });

  test('markSoftDeleted returns deleted entity and logs code', () {
    final logger = InMemoryAppLogger();
    final contract = CanonicalFinanceModelContract(
      logger: logger,
      currentSchemaVersion: 3,
    );
    final deletedAt = DateTime.utc(2030, 1, 1);

    final result = contract.markSoftDeleted(
      entity: _entity(),
      deletedAt: deletedAt,
    );

    expect(result, isA<AppSuccess<CanonicalFinanceEntity>>());
    final entity = (result as AppSuccess<CanonicalFinanceEntity>).value;
    expect(entity.deletedAt, deletedAt);
    expect(
      logger.events.map((event) => event.code),
      contains('canonical_entity_soft_deleted'),
    );
  });

  test('migrateEntitySchema upgrades schema to current version', () {
    final logger = InMemoryAppLogger();
    final contract = CanonicalFinanceModelContract(
      logger: logger,
      currentSchemaVersion: 4,
    );

    final result = contract.migrateEntitySchema(
      entity: _entity(schemaVersion: 3),
      targetSchemaVersion: 4,
      migratedAt: DateTime.utc(2030, 2, 1),
    );

    expect(result, isA<AppSuccess<CanonicalFinanceEntity>>());
    final migrated = (result as AppSuccess<CanonicalFinanceEntity>).value;
    expect(migrated.schemaVersion, 4);
    expect(
      logger.events.map((event) => event.code),
      contains('canonical_schema_migrated'),
    );
  });

  test('migrateEntitySchema rejects schema downgrade', () {
    final logger = InMemoryAppLogger();
    final contract = CanonicalFinanceModelContract(
      logger: logger,
      currentSchemaVersion: 4,
    );

    final result = contract.migrateEntitySchema(
      entity: _entity(schemaVersion: 4),
      targetSchemaVersion: 3,
      migratedAt: DateTime.utc(2030, 2, 1),
    );

    expect(result, isA<AppFailure<CanonicalFinanceEntity>>());
    final detail = (result as AppFailure<CanonicalFinanceEntity>).detail;
    expect(detail.code, 'canonical_schema_downgrade_not_supported');
  });
}

CanonicalFinanceEntity _entity({
  int schemaVersion = 3,
  List<CanonicalEntityReference> references = const <CanonicalEntityReference>[
    CanonicalEntityReference(
      type: CanonicalFinanceEntityType.wallet,
      id: 'wallet-1',
    ),
    CanonicalEntityReference(
      type: CanonicalFinanceEntityType.category,
      id: 'category-1',
    ),
  ],
}) {
  return CanonicalFinanceEntity(
    entityType: CanonicalFinanceEntityType.transaction,
    id: 'tx-1',
    workspaceId: 'workspace-1',
    schemaVersion: schemaVersion,
    references: references,
    createdAt: DateTime.utc(2029, 1, 1),
    updatedAt: DateTime.utc(2029, 1, 2),
  );
}
