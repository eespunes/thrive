import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

class ConsentRecord {
  const ConsentRecord({
    required this.userId,
    required this.policyVersion,
    required this.granted,
    required this.grantedAt,
    required this.source,
  });

  final String userId;
  final String policyVersion;
  final bool granted;
  final DateTime grantedAt;
  final String source;
}

class RetentionItem {
  const RetentionItem({
    required this.itemId,
    required this.dataType,
    required this.createdAt,
    required this.retentionDays,
  });

  final String itemId;
  final String dataType;
  final DateTime createdAt;
  final int retentionDays;
}

class RetentionEvaluation {
  const RetentionEvaluation({
    required this.expiredItemIds,
    required this.retainedItemIds,
  });

  final List<String> expiredItemIds;
  final List<String> retainedItemIds;
}

class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.userId,
    required this.workspaceId,
    required this.requestedAt,
    required this.requestedBy,
  });

  final String userId;
  final String workspaceId;
  final DateTime requestedAt;
  final String requestedBy;
}

enum AccountDeletionState { scheduled, completed }

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.state,
    required this.scheduledAt,
    required this.purgedRecordCount,
  });

  final AccountDeletionState state;
  final DateTime scheduledAt;
  final int purgedRecordCount;
}

class PrivacyLifecycleContract {
  PrivacyLifecycleContract({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  AppResult<void> captureConsent(ConsentRecord record) {
    if (record.userId.trim().isEmpty ||
        record.policyVersion.trim().isEmpty ||
        record.source.trim().isEmpty) {
      return _failure(
        code: 'privacy_consent_invalid',
        developerMessage: 'Consent record fields cannot be empty.',
        userMessage: 'Could not save your privacy settings right now.',
      );
    }

    _logger.info(
      code: 'privacy_consent_recorded',
      message: 'Consent record captured and linked to policy version',
      metadata: <String, Object?>{
        'userId': record.userId,
        'policyVersion': record.policyVersion,
        'granted': record.granted,
        'source': record.source,
      },
    );
    return const AppSuccess<void>(null);
  }

  AppResult<RetentionEvaluation> enforceRetentionSchedule({
    required List<RetentionItem> items,
    required DateTime now,
  }) {
    if (items.isEmpty) {
      return AppFailure<RetentionEvaluation>(
        FailureDetail(
          code: 'privacy_retention_items_missing',
          developerMessage: 'Retention evaluation requires at least one item.',
          userMessage: 'Could not process retention schedule right now.',
          recoverable: true,
        ),
      );
    }

    final expired = <String>[];
    final retained = <String>[];

    for (final item in items) {
      if (item.itemId.trim().isEmpty ||
          item.dataType.trim().isEmpty ||
          item.retentionDays <= 0) {
        return AppFailure<RetentionEvaluation>(
          FailureDetail(
            code: 'privacy_retention_item_invalid',
            developerMessage: 'Retention item payload is invalid.',
            userMessage: 'Could not process retention schedule right now.',
            recoverable: true,
          ),
        );
      }

      final expiresAt = item.createdAt.add(Duration(days: item.retentionDays));
      if (!now.isBefore(expiresAt)) {
        expired.add(item.itemId);
      } else {
        retained.add(item.itemId);
      }
    }

    _logger.info(
      code: 'privacy_retention_evaluated',
      message: 'Retention schedule evaluated',
      metadata: <String, Object?>{
        'expiredCount': expired.length,
        'retainedCount': retained.length,
      },
    );

    return AppSuccess<RetentionEvaluation>(
      RetentionEvaluation(expiredItemIds: expired, retainedItemIds: retained),
    );
  }

  AppResult<AccountDeletionResult> processAccountDeletion({
    required AccountDeletionRequest request,
    required bool hasLegalHold,
    required bool hasPendingSettlement,
    required DateTime now,
  }) {
    if (request.userId.trim().isEmpty ||
        request.workspaceId.trim().isEmpty ||
        request.requestedBy.trim().isEmpty) {
      return AppFailure<AccountDeletionResult>(
        FailureDetail(
          code: 'privacy_deletion_request_invalid',
          developerMessage: 'Deletion request fields cannot be empty.',
          userMessage: 'Could not process account deletion right now.',
          recoverable: true,
        ),
      );
    }

    if (hasLegalHold) {
      return AppFailure<AccountDeletionResult>(
        FailureDetail(
          code: 'privacy_deletion_legal_hold',
          developerMessage: 'Account deletion blocked due to legal hold.',
          userMessage:
              'Account deletion cannot proceed due to compliance hold.',
          recoverable: true,
        ),
      );
    }

    if (hasPendingSettlement) {
      return AppFailure<AccountDeletionResult>(
        FailureDetail(
          code: 'privacy_deletion_pending_settlement',
          developerMessage: 'Account deletion blocked by pending settlement.',
          userMessage:
              'Account deletion requires pending operations to finish.',
          recoverable: true,
        ),
      );
    }

    _logger.warning(
      code: 'privacy_account_deletion_scheduled',
      message: 'Account deletion workflow scheduled',
      metadata: <String, Object?>{
        'userId': request.userId,
        'workspaceId': request.workspaceId,
        'requestedBy': request.requestedBy,
      },
    );

    return AppSuccess<AccountDeletionResult>(
      AccountDeletionResult(
        state: AccountDeletionState.scheduled,
        scheduledAt: now,
        purgedRecordCount: 0,
      ),
    );
  }

  AppResult<AccountDeletionResult> markDeletionCompleted({
    required AccountDeletionResult scheduled,
    required int purgedRecordCount,
    required DateTime completedAt,
  }) {
    if (scheduled.state != AccountDeletionState.scheduled ||
        purgedRecordCount < 0) {
      return AppFailure<AccountDeletionResult>(
        FailureDetail(
          code: 'privacy_deletion_completion_invalid',
          developerMessage: 'Deletion completion payload is invalid.',
          userMessage: 'Could not finalize account deletion right now.',
          recoverable: true,
        ),
      );
    }

    _logger.warning(
      code: 'privacy_account_deletion_completed',
      message: 'Account deletion workflow completed',
      metadata: <String, Object?>{
        'purgedRecordCount': purgedRecordCount,
        'completedAt': completedAt.toIso8601String(),
      },
    );

    return AppSuccess<AccountDeletionResult>(
      AccountDeletionResult(
        state: AccountDeletionState.completed,
        scheduledAt: scheduled.scheduledAt,
        purgedRecordCount: purgedRecordCount,
      ),
    );
  }

  AppFailure<void> _failure({
    required String code,
    required String developerMessage,
    required String userMessage,
  }) {
    _logger.warning(code: code, message: developerMessage);
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
