import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

enum CanonicalFinanceEntityType {
  wallet,
  category,
  transaction,
  debt,
  savingsGoal,
}

class CanonicalEntityReference {
  const CanonicalEntityReference({required this.type, required this.id});

  final CanonicalFinanceEntityType type;
  final String id;

  @override
  bool operator ==(Object other) {
    return other is CanonicalEntityReference &&
        other.type == type &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);
}

class CanonicalFinanceEntity {
  const CanonicalFinanceEntity({
    required this.entityType,
    required this.id,
    required this.workspaceId,
    required this.schemaVersion,
    required this.references,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final CanonicalFinanceEntityType entityType;
  final String id;
  final String workspaceId;
  final int schemaVersion;
  final List<CanonicalEntityReference> references;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isSoftDeleted => deletedAt != null;

  CanonicalFinanceEntity copyWith({
    CanonicalFinanceEntityType? entityType,
    String? id,
    String? workspaceId,
    int? schemaVersion,
    List<CanonicalEntityReference>? references,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return CanonicalFinanceEntity(
      entityType: entityType ?? this.entityType,
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      references: references ?? this.references,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

class CanonicalFinanceModelContract {
  CanonicalFinanceModelContract({
    required AppLogger logger,
    required int currentSchemaVersion,
  }) : _logger = logger,
       _currentSchemaVersion = currentSchemaVersion;

  final AppLogger _logger;
  final int _currentSchemaVersion;

  AppResult<void> validateForSave(CanonicalFinanceEntity entity) {
    if (entity.id.trim().isEmpty || entity.workspaceId.trim().isEmpty) {
      return _failure(
        code: 'canonical_entity_invalid',
        developerMessage: 'Entity id/workspaceId cannot be empty.',
        userMessage: 'Could not save data. Please retry.',
      );
    }

    if (entity.schemaVersion != _currentSchemaVersion) {
      return _failure(
        code: 'canonical_schema_version_unsupported',
        developerMessage:
            'Entity schema version ${entity.schemaVersion} does not match current version $_currentSchemaVersion.',
        userMessage:
            'Your app data version is outdated. Please update and retry.',
      );
    }

    if (entity.isSoftDeleted) {
      return _failure(
        code: 'canonical_entity_deleted',
        developerMessage: 'Soft-deleted entity cannot be saved as active.',
        userMessage: 'This item was removed and cannot be updated anymore.',
      );
    }

    _logger.info(
      code: 'canonical_entity_saved_contract_validated',
      message: 'Canonical entity passed save contract validation',
      metadata: <String, Object?>{
        'entityType': entity.entityType.name,
        'entityId': entity.id,
        'workspaceId': entity.workspaceId,
        'schemaVersion': entity.schemaVersion,
      },
    );
    return const AppSuccess<void>(null);
  }

  AppResult<void> validateReferentialIntegrity({
    required CanonicalFinanceEntity entity,
    required Set<CanonicalEntityReference> availableReferences,
  }) {
    if (entity.isSoftDeleted) {
      return const AppSuccess<void>(null);
    }

    for (final reference in entity.references) {
      if (!availableReferences.contains(reference)) {
        return _failure(
          code: 'canonical_reference_missing',
          developerMessage:
              'Reference ${reference.type.name}:${reference.id} is missing for entity ${entity.id}.',
          userMessage:
              'Some linked data is no longer available. Please refresh and retry.',
          metadata: <String, Object?>{
            'entityId': entity.id,
            'workspaceId': entity.workspaceId,
            'missingReferenceType': reference.type.name,
            'missingReferenceId': reference.id,
          },
        );
      }
    }

    _logger.info(
      code: 'canonical_referential_integrity_passed',
      message: 'Canonical referential integrity validation passed',
      metadata: <String, Object?>{
        'entityType': entity.entityType.name,
        'entityId': entity.id,
        'workspaceId': entity.workspaceId,
        'referenceCount': entity.references.length,
      },
    );
    return const AppSuccess<void>(null);
  }

  AppResult<CanonicalFinanceEntity> markSoftDeleted({
    required CanonicalFinanceEntity entity,
    required DateTime deletedAt,
  }) {
    if (entity.isSoftDeleted) {
      return AppFailure<CanonicalFinanceEntity>(
        FailureDetail(
          code: 'canonical_already_deleted',
          developerMessage: 'Entity is already soft-deleted.',
          userMessage: 'This item is already removed.',
          recoverable: true,
        ),
      );
    }

    final deletedEntity = entity.copyWith(deletedAt: deletedAt);
    _logger.info(
      code: 'canonical_entity_soft_deleted',
      message: 'Canonical entity marked as soft-deleted',
      metadata: <String, Object?>{
        'entityType': entity.entityType.name,
        'entityId': entity.id,
        'workspaceId': entity.workspaceId,
      },
    );
    return AppSuccess<CanonicalFinanceEntity>(deletedEntity);
  }

  AppResult<CanonicalFinanceEntity> migrateEntitySchema({
    required CanonicalFinanceEntity entity,
    required int targetSchemaVersion,
    required DateTime migratedAt,
  }) {
    if (targetSchemaVersion < entity.schemaVersion) {
      return AppFailure<CanonicalFinanceEntity>(
        FailureDetail(
          code: 'canonical_schema_downgrade_not_supported',
          developerMessage:
              'Schema downgrade from ${entity.schemaVersion} to $targetSchemaVersion is not supported.',
          userMessage:
              'Could not migrate local data safely. Please contact support.',
          recoverable: false,
        ),
      );
    }

    if (targetSchemaVersion != _currentSchemaVersion) {
      return AppFailure<CanonicalFinanceEntity>(
        FailureDetail(
          code: 'canonical_schema_target_invalid',
          developerMessage:
              'Target schema $targetSchemaVersion does not match contract version $_currentSchemaVersion.',
          userMessage: 'Could not complete data migration. Please retry later.',
          recoverable: true,
        ),
      );
    }

    final migrated = entity.copyWith(
      schemaVersion: targetSchemaVersion,
      updatedAt: migratedAt,
    );
    _logger.info(
      code: 'canonical_schema_migrated',
      message: 'Canonical entity schema migrated',
      metadata: <String, Object?>{
        'entityType': entity.entityType.name,
        'entityId': entity.id,
        'workspaceId': entity.workspaceId,
        'fromVersion': entity.schemaVersion,
        'toVersion': targetSchemaVersion,
      },
    );
    return AppSuccess<CanonicalFinanceEntity>(migrated);
  }

  AppFailure<void> _failure({
    required String code,
    required String developerMessage,
    required String userMessage,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    _logger.warning(code: code, message: developerMessage, metadata: metadata);
    return AppFailure<void>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: userMessage,
        recoverable: true,
      ),
    );
  }
}
