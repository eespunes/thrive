import 'dart:collection';

import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

enum OfflineMutationType { upsert, delete }

enum SyncQueueState { idle, queued, syncing, error }

enum SyncConflictStrategy { keepLocal, acceptRemote }

class OfflineMutation {
  const OfflineMutation({
    required this.mutationId,
    required this.workspaceId,
    required this.entityType,
    required this.entityId,
    required this.mutationType,
    required this.baseVersion,
    required this.payload,
    required this.createdAt,
  });

  final String mutationId;
  final String workspaceId;
  final String entityType;
  final String entityId;
  final OfflineMutationType mutationType;
  final int baseVersion;
  final Map<String, Object?> payload;
  final DateTime createdAt;
}

class SyncConflict {
  const SyncConflict({
    required this.mutationId,
    required this.entityId,
    required this.localVersion,
    required this.remoteVersion,
  });

  final String mutationId;
  final String entityId;
  final int localVersion;
  final int remoteVersion;
}

class SyncPushResponse {
  const SyncPushResponse({
    required this.appliedMutationIds,
    required this.conflicts,
  });

  final List<String> appliedMutationIds;
  final List<SyncConflict> conflicts;
}

class SyncCycleResult {
  const SyncCycleResult({
    required this.appliedCount,
    required this.pendingCount,
    required this.conflictCount,
    required this.state,
  });

  final int appliedCount;
  final int pendingCount;
  final int conflictCount;
  final SyncQueueState state;
}

abstract interface class OfflineSyncGateway {
  Future<AppResult<SyncPushResponse>> push(List<OfflineMutation> mutations);
}

class OfflineSyncQueue {
  OfflineSyncQueue({
    required OfflineSyncGateway gateway,
    required AppLogger logger,
  }) : _gateway = gateway,
       _logger = logger;

  final OfflineSyncGateway _gateway;
  final AppLogger _logger;
  final List<OfflineMutation> _queue = <OfflineMutation>[];
  SyncQueueState _state = SyncQueueState.idle;

  SyncQueueState get state => _state;

  List<OfflineMutation> get pendingMutations =>
      UnmodifiableListView<OfflineMutation>(_queue);

  AppResult<int> enqueue(OfflineMutation mutation) {
    _queue.add(mutation);
    _state = SyncQueueState.queued;
    _logger.info(
      code: 'offline_mutation_enqueued',
      message: 'Offline mutation added to queue',
      metadata: <String, Object?>{
        'mutationId': mutation.mutationId,
        'workspaceId': mutation.workspaceId,
        'entityType': mutation.entityType,
        'entityId': mutation.entityId,
        'pendingCount': _queue.length,
      },
    );
    return AppSuccess<int>(_queue.length);
  }

  Future<AppResult<SyncCycleResult>> sync({
    required bool isOnline,
    SyncConflictStrategy conflictStrategy = SyncConflictStrategy.keepLocal,
  }) async {
    if (!isOnline) {
      _state = SyncQueueState.queued;
      return _failure(
        code: 'sync_offline_queue_retained',
        developerMessage: 'Sync skipped because device is offline.',
        userMessage: 'Changes are queued and will sync when you are online.',
      );
    }

    if (_queue.isEmpty) {
      _state = SyncQueueState.idle;
      return AppSuccess<SyncCycleResult>(
        SyncCycleResult(
          appliedCount: 0,
          pendingCount: 0,
          conflictCount: 0,
          state: _state,
        ),
      );
    }

    _state = SyncQueueState.syncing;
    final pushResult = await _gateway.push(_queue);
    if (pushResult is AppFailure<SyncPushResponse>) {
      _state = SyncQueueState.error;
      return _failure(
        code: pushResult.detail.code,
        developerMessage: pushResult.detail.developerMessage,
        userMessage: pushResult.detail.userMessage,
      );
    }

    final response = (pushResult as AppSuccess<SyncPushResponse>).value;
    final conflictIds = response.conflicts
        .map((conflict) => conflict.mutationId)
        .toSet();

    _queue.removeWhere(
      (mutation) => response.appliedMutationIds.contains(mutation.mutationId),
    );

    if (response.conflicts.isNotEmpty &&
        conflictStrategy == SyncConflictStrategy.acceptRemote) {
      _queue.removeWhere(
        (mutation) => conflictIds.contains(mutation.mutationId),
      );
      _logger.warning(
        code: 'sync_conflict_resolved_accept_remote',
        message: 'Conflicts resolved by accepting remote state',
        metadata: <String, Object?>{'conflictCount': response.conflicts.length},
      );
    }

    if (response.conflicts.isNotEmpty &&
        conflictStrategy == SyncConflictStrategy.keepLocal) {
      _state = SyncQueueState.queued;
      return _failure(
        code: 'sync_conflict_requires_resolution',
        developerMessage:
            'Sync detected ${response.conflicts.length} conflicts and kept local mutations queued.',
        userMessage:
            'Some changes need review before they can sync. Please retry.',
      );
    }

    _state = _queue.isEmpty ? SyncQueueState.idle : SyncQueueState.queued;
    _logger.info(
      code: 'sync_cycle_completed',
      message: 'Offline sync cycle completed',
      metadata: <String, Object?>{
        'appliedCount': response.appliedMutationIds.length,
        'pendingCount': _queue.length,
        'conflictCount': response.conflicts.length,
        'state': _state.name,
      },
    );

    return AppSuccess<SyncCycleResult>(
      SyncCycleResult(
        appliedCount: response.appliedMutationIds.length,
        pendingCount: _queue.length,
        conflictCount: response.conflicts.length,
        state: _state,
      ),
    );
  }

  AppFailure<SyncCycleResult> _failure({
    required String code,
    required String developerMessage,
    required String userMessage,
  }) {
    _logger.warning(code: code, message: developerMessage);
    return AppFailure<SyncCycleResult>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: userMessage,
        recoverable: true,
      ),
    );
  }
}
