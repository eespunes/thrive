import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

enum AuditAction { create, update, delete, transferOwnership, settlement }

enum AuditSource { mobileApp, cloudFunction, adminConsole, systemJob }

class AuditActor {
  const AuditActor({required this.actorId, required this.actorType});

  final String actorId;
  final String actorType;
}

class AuditEvent {
  const AuditEvent({
    required this.eventId,
    required this.workspaceId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.source,
    required this.actor,
    required this.before,
    required this.after,
    required this.occurredAt,
  });

  final String eventId;
  final String workspaceId;
  final String entityType;
  final String entityId;
  final AuditAction action;
  final AuditSource source;
  final AuditActor actor;
  final Map<String, Object?> before;
  final Map<String, Object?> after;
  final DateTime occurredAt;
}

class AuditRetentionPolicy {
  const AuditRetentionPolicy({
    required this.retentionDays,
    required this.maxQueryWindowDays,
  });

  final int retentionDays;
  final int maxQueryWindowDays;
}

abstract interface class AuditLogStore {
  Future<AppResult<void>> append(AuditEvent event);

  Future<AppResult<List<AuditEvent>>> query({
    required String workspaceId,
    required DateTime from,
    required DateTime to,
    required int limit,
  });
}

class AuditLogContract {
  AuditLogContract({
    required AuditLogStore store,
    required AuditRetentionPolicy retentionPolicy,
    required AppLogger logger,
  }) : _store = store,
       _retentionPolicy = retentionPolicy,
       _logger = logger;

  final AuditLogStore _store;
  final AuditRetentionPolicy _retentionPolicy;
  final AppLogger _logger;

  Future<AppResult<void>> record(AuditEvent event) async {
    final validation = _validateEvent(event);
    if (validation is AppFailure<void>) {
      return validation;
    }

    final appendResult = await _store.append(event);
    if (appendResult is AppFailure<void>) {
      _logger.warning(
        code: 'audit_append_failed',
        message: appendResult.detail.developerMessage,
        metadata: <String, Object?>{
          'eventId': event.eventId,
          'workspaceId': event.workspaceId,
          'action': event.action.name,
          'source': event.source.name,
        },
      );
      return appendResult;
    }

    _logger.info(
      code: 'audit_event_recorded',
      message: 'Immutable audit event recorded',
      metadata: <String, Object?>{
        'eventId': event.eventId,
        'workspaceId': event.workspaceId,
        'entityType': event.entityType,
        'entityId': event.entityId,
        'action': event.action.name,
        'source': event.source.name,
        'actorType': event.actor.actorType,
      },
    );
    return const AppSuccess<void>(null);
  }

  Future<AppResult<List<AuditEvent>>> query({
    required String workspaceId,
    required DateTime from,
    required DateTime to,
    required int limit,
    required DateTime now,
  }) async {
    if (workspaceId.trim().isEmpty) {
      return _queryFailure(
        code: 'audit_workspace_invalid',
        developerMessage: 'workspaceId cannot be empty for audit query.',
        userMessage: 'Could not load audit history right now.',
      );
    }

    if (!to.isAfter(from)) {
      return _queryFailure(
        code: 'audit_query_range_invalid',
        developerMessage: 'Audit query requires to > from.',
        userMessage: 'Could not load audit history right now.',
      );
    }

    if (limit <= 0) {
      return _queryFailure(
        code: 'audit_query_limit_invalid',
        developerMessage: 'Audit query limit must be greater than zero.',
        userMessage: 'Could not load audit history right now.',
      );
    }

    final windowDays = to.difference(from).inDays;
    if (windowDays > _retentionPolicy.maxQueryWindowDays) {
      return _queryFailure(
        code: 'audit_query_window_exceeded',
        developerMessage:
            'Requested $windowDays days but max is ${_retentionPolicy.maxQueryWindowDays}.',
        userMessage: 'Requested period is too large. Narrow your date range.',
      );
    }

    final result = await _store.query(
      workspaceId: workspaceId,
      from: from,
      to: to,
      limit: limit,
    );

    if (result is AppFailure<List<AuditEvent>>) {
      _logger.warning(
        code: 'audit_query_failed',
        message: result.detail.developerMessage,
        metadata: <String, Object?>{
          'workspaceId': workspaceId,
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
        },
      );
      return result;
    }

    final retentionCutoff = now.subtract(
      Duration(days: _retentionPolicy.retentionDays),
    );
    final events = (result as AppSuccess<List<AuditEvent>>).value
        .where((event) => !event.occurredAt.isBefore(retentionCutoff))
        .toList(growable: false);

    _logger.info(
      code: 'audit_query_completed',
      message: 'Audit query completed with retention filtering',
      metadata: <String, Object?>{
        'workspaceId': workspaceId,
        'returnedCount': events.length,
        'retentionDays': _retentionPolicy.retentionDays,
      },
    );

    return AppSuccess<List<AuditEvent>>(events);
  }

  AppResult<void> _validateEvent(AuditEvent event) {
    if (event.eventId.trim().isEmpty ||
        event.workspaceId.trim().isEmpty ||
        event.entityType.trim().isEmpty ||
        event.entityId.trim().isEmpty) {
      return _eventFailure(
        code: 'audit_event_invalid',
        developerMessage: 'Audit event identity fields cannot be empty.',
        userMessage: 'Could not save change history for this action.',
      );
    }

    if (event.actor.actorId.trim().isEmpty ||
        event.actor.actorType.trim().isEmpty) {
      return _eventFailure(
        code: 'audit_actor_missing',
        developerMessage: 'Audit actor attribution is required.',
        userMessage: 'Could not save change history for this action.',
      );
    }

    if (event.before.isEmpty && event.after.isEmpty) {
      return _eventFailure(
        code: 'audit_change_payload_empty',
        developerMessage: 'Audit event must contain before/after payload data.',
        userMessage: 'Could not save change history for this action.',
      );
    }

    return const AppSuccess<void>(null);
  }

  AppFailure<void> _eventFailure({
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

  AppFailure<List<AuditEvent>> _queryFailure({
    required String code,
    required String developerMessage,
    required String userMessage,
  }) {
    _logger.warning(code: code, message: developerMessage);
    return AppFailure<List<AuditEvent>>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: userMessage,
        recoverable: true,
      ),
    );
  }
}
