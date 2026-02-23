import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';
import 'package:thrive_app/core/sync/offline_sync_queue.dart';

void main() {
  test('enqueue stores offline mutation and returns queue depth', () {
    final queue = OfflineSyncQueue(
      gateway: _FixedGateway(
        result: const AppSuccess<SyncPushResponse>(
          SyncPushResponse(
            appliedMutationIds: <String>[],
            conflicts: <SyncConflict>[],
          ),
        ),
      ),
      logger: InMemoryAppLogger(),
    );

    final result = queue.enqueue(_mutation(mutationId: 'm-1'));

    expect(result, isA<AppSuccess<int>>());
    expect((result as AppSuccess<int>).value, 1);
    expect(queue.pendingMutations.length, 1);
    expect(queue.state, SyncQueueState.queued);
  });

  test('sync keeps queue when device is offline', () async {
    final queue = OfflineSyncQueue(
      gateway: _FixedGateway(
        result: const AppSuccess<SyncPushResponse>(
          SyncPushResponse(
            appliedMutationIds: <String>[],
            conflicts: <SyncConflict>[],
          ),
        ),
      ),
      logger: InMemoryAppLogger(),
    );
    queue.enqueue(_mutation(mutationId: 'm-1'));

    final result = await queue.sync(isOnline: false);

    expect(result, isA<AppFailure<SyncCycleResult>>());
    final detail = (result as AppFailure<SyncCycleResult>).detail;
    expect(detail.code, 'sync_offline_queue_retained');
    expect(queue.pendingMutations.length, 1);
  });

  test('sync applies queued mutations when online without conflicts', () async {
    final queue = OfflineSyncQueue(
      gateway: _FixedGateway(
        result: const AppSuccess<SyncPushResponse>(
          SyncPushResponse(
            appliedMutationIds: <String>['m-1', 'm-2'],
            conflicts: <SyncConflict>[],
          ),
        ),
      ),
      logger: InMemoryAppLogger(),
    );
    queue.enqueue(_mutation(mutationId: 'm-1'));
    queue.enqueue(_mutation(mutationId: 'm-2'));

    final result = await queue.sync(isOnline: true);

    expect(result, isA<AppSuccess<SyncCycleResult>>());
    final cycle = (result as AppSuccess<SyncCycleResult>).value;
    expect(cycle.appliedCount, 2);
    expect(cycle.pendingCount, 0);
    expect(queue.state, SyncQueueState.idle);
  });

  test(
    'sync keeps local mutation when conflict strategy is keepLocal',
    () async {
      final queue = OfflineSyncQueue(
        gateway: _FixedGateway(
          result: const AppSuccess<SyncPushResponse>(
            SyncPushResponse(
              appliedMutationIds: <String>[],
              conflicts: <SyncConflict>[
                SyncConflict(
                  mutationId: 'm-conflict',
                  entityId: 'tx-1',
                  localVersion: 3,
                  remoteVersion: 5,
                ),
              ],
            ),
          ),
        ),
        logger: InMemoryAppLogger(),
      );
      queue.enqueue(_mutation(mutationId: 'm-conflict'));

      final result = await queue.sync(
        isOnline: true,
        conflictStrategy: SyncConflictStrategy.keepLocal,
      );

      expect(result, isA<AppFailure<SyncCycleResult>>());
      final detail = (result as AppFailure<SyncCycleResult>).detail;
      expect(detail.code, 'sync_conflict_requires_resolution');
      expect(queue.pendingMutations.length, 1);
      expect(queue.state, SyncQueueState.queued);
    },
  );

  test(
    'sync drops conflicting mutation when strategy accepts remote',
    () async {
      final queue = OfflineSyncQueue(
        gateway: _FixedGateway(
          result: const AppSuccess<SyncPushResponse>(
            SyncPushResponse(
              appliedMutationIds: <String>[],
              conflicts: <SyncConflict>[
                SyncConflict(
                  mutationId: 'm-conflict',
                  entityId: 'tx-1',
                  localVersion: 3,
                  remoteVersion: 5,
                ),
              ],
            ),
          ),
        ),
        logger: InMemoryAppLogger(),
      );
      queue.enqueue(_mutation(mutationId: 'm-conflict'));

      final result = await queue.sync(
        isOnline: true,
        conflictStrategy: SyncConflictStrategy.acceptRemote,
      );

      expect(result, isA<AppSuccess<SyncCycleResult>>());
      expect(queue.pendingMutations, isEmpty);
      expect(queue.state, SyncQueueState.idle);
    },
  );
}

OfflineMutation _mutation({required String mutationId}) {
  return OfflineMutation(
    mutationId: mutationId,
    workspaceId: 'workspace-1',
    entityType: 'transaction',
    entityId: 'tx-1',
    mutationType: OfflineMutationType.upsert,
    baseVersion: 1,
    payload: const <String, Object?>{'amountMinor': 2000},
    createdAt: DateTime.utc(2030, 1, 1),
  );
}

class _FixedGateway implements OfflineSyncGateway {
  const _FixedGateway({required this.result});

  final AppResult<SyncPushResponse> result;

  @override
  Future<AppResult<SyncPushResponse>> push(
    List<OfflineMutation> mutations,
  ) async {
    return result;
  }
}
