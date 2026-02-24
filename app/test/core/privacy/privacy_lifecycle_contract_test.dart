import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/privacy/privacy_lifecycle_contract.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('captures consent linked to policy version', () {
    final contract = PrivacyLifecycleContract(logger: InMemoryAppLogger());

    final result = contract.captureConsent(
      ConsentRecord(
        userId: 'user-1',
        policyVersion: 'policy-2026-01',
        granted: true,
        grantedAt: DateTime.utc(2030, 1, 1),
        source: 'settings_screen',
      ),
    );

    expect(result, isA<AppSuccess<void>>());
  });

  test(
    'retention schedule marks expired and retained items deterministically',
    () {
      final contract = PrivacyLifecycleContract(logger: InMemoryAppLogger());

      final result = contract.enforceRetentionSchedule(
        items: <RetentionItem>[
          RetentionItem(
            itemId: 'a',
            dataType: 'session_log',
            createdAt: DateTime.utc(2029, 1, 1),
            retentionDays: 30,
          ),
          RetentionItem(
            itemId: 'b',
            dataType: 'audit_log',
            createdAt: DateTime.utc(2030, 1, 15),
            retentionDays: 60,
          ),
        ],
        now: DateTime.utc(2030, 2, 1),
      );

      expect(result, isA<AppSuccess<RetentionEvaluation>>());
      final evaluation = (result as AppSuccess<RetentionEvaluation>).value;
      expect(evaluation.expiredItemIds, contains('a'));
      expect(evaluation.retainedItemIds, contains('b'));
    },
  );

  test('account deletion is blocked by legal hold', () {
    final contract = PrivacyLifecycleContract(logger: InMemoryAppLogger());

    final result = contract.processAccountDeletion(
      request: AccountDeletionRequest(
        userId: 'user-1',
        workspaceId: 'workspace-1',
        requestedAt: DateTime.utc(2030, 1, 1),
        requestedBy: 'user-1',
      ),
      hasLegalHold: true,
      hasPendingSettlement: false,
      now: DateTime.utc(2030, 1, 2),
    );

    expect(result, isA<AppFailure<AccountDeletionResult>>());
    expect(
      (result as AppFailure<AccountDeletionResult>).detail.code,
      'privacy_deletion_legal_hold',
    );
  });

  test('account deletion schedules and completes successfully', () {
    final contract = PrivacyLifecycleContract(logger: InMemoryAppLogger());

    final scheduled = contract.processAccountDeletion(
      request: AccountDeletionRequest(
        userId: 'user-1',
        workspaceId: 'workspace-1',
        requestedAt: DateTime.utc(2030, 1, 1),
        requestedBy: 'user-1',
      ),
      hasLegalHold: false,
      hasPendingSettlement: false,
      now: DateTime.utc(2030, 1, 2),
    );

    expect(scheduled, isA<AppSuccess<AccountDeletionResult>>());
    final completion = contract.markDeletionCompleted(
      scheduled: (scheduled as AppSuccess<AccountDeletionResult>).value,
      purgedRecordCount: 42,
      completedAt: DateTime.utc(2030, 1, 3),
    );

    expect(completion, isA<AppSuccess<AccountDeletionResult>>());
    final value = (completion as AppSuccess<AccountDeletionResult>).value;
    expect(value.state, AccountDeletionState.completed);
    expect(value.purgedRecordCount, 42);
    expect(value.scheduledAt, DateTime.utc(2030, 1, 2));
  });
}
