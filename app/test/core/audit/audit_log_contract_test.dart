import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/audit/audit_log_contract.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('records valid immutable audit event', () async {
    final logger = InMemoryAppLogger();
    final store = _InMemoryAuditLogStore();
    final contract = AuditLogContract(
      store: store,
      retentionPolicy: const AuditRetentionPolicy(
        retentionDays: 365,
        maxQueryWindowDays: 90,
      ),
      logger: logger,
    );

    final result = await contract.record(_event());

    expect(result, isA<AppSuccess<void>>());
    expect(store.events.length, 1);
    expect(
      logger.events.map((event) => event.code),
      contains('audit_event_recorded'),
    );
  });

  test('fails record when actor attribution is missing', () async {
    final contract = AuditLogContract(
      store: _InMemoryAuditLogStore(),
      retentionPolicy: const AuditRetentionPolicy(
        retentionDays: 365,
        maxQueryWindowDays: 90,
      ),
      logger: InMemoryAppLogger(),
    );

    final result = await contract.record(
      AuditEvent(
        eventId: 'evt-1',
        workspaceId: 'w-1',
        entityType: 'transaction',
        entityId: 'tx-1',
        action: AuditAction.update,
        source: AuditSource.cloudFunction,
        actor: const AuditActor(actorId: ' ', actorType: 'function'),
        before: const <String, Object?>{'amountMinor': 1200},
        after: const <String, Object?>{'amountMinor': 1400},
        occurredAt: DateTime.utc(2030, 1, 1),
      ),
    );

    expect(result, isA<AppFailure<void>>());
    expect((result as AppFailure<void>).detail.code, 'audit_actor_missing');
  });

  test('query enforces max retention window', () async {
    final contract = AuditLogContract(
      store: _InMemoryAuditLogStore(),
      retentionPolicy: const AuditRetentionPolicy(
        retentionDays: 365,
        maxQueryWindowDays: 7,
      ),
      logger: InMemoryAppLogger(),
    );

    final result = await contract.query(
      workspaceId: 'w-1',
      from: DateTime.utc(2030, 1, 1),
      to: DateTime.utc(2030, 2, 1),
      limit: 20,
      now: DateTime.utc(2030, 2, 2),
    );

    expect(result, isA<AppFailure<List<AuditEvent>>>());
    expect(
      (result as AppFailure<List<AuditEvent>>).detail.code,
      'audit_query_window_exceeded',
    );
  });

  test('query filters out events older than retention policy', () async {
    final store = _InMemoryAuditLogStore();
    store.events.addAll(<AuditEvent>[
      _event(eventId: 'old', occurredAt: DateTime.utc(2028, 1, 1)),
      _event(eventId: 'recent', occurredAt: DateTime.utc(2030, 1, 20)),
    ]);

    final contract = AuditLogContract(
      store: store,
      retentionPolicy: const AuditRetentionPolicy(
        retentionDays: 30,
        maxQueryWindowDays: 90,
      ),
      logger: InMemoryAppLogger(),
    );

    final result = await contract.query(
      workspaceId: 'w-1',
      from: DateTime.utc(2029, 12, 1),
      to: DateTime.utc(2030, 2, 1),
      limit: 50,
      now: DateTime.utc(2030, 2, 1),
    );

    expect(result, isA<AppSuccess<List<AuditEvent>>>());
    final events = (result as AppSuccess<List<AuditEvent>>).value;
    expect(events.length, 1);
    expect(events.single.eventId, 'recent');
  });
}

AuditEvent _event({String eventId = 'evt-1', DateTime? occurredAt}) {
  return AuditEvent(
    eventId: eventId,
    workspaceId: 'w-1',
    entityType: 'transaction',
    entityId: 'tx-1',
    action: AuditAction.update,
    source: AuditSource.mobileApp,
    actor: const AuditActor(actorId: 'user-1', actorType: 'user'),
    before: const <String, Object?>{'amountMinor': 1200},
    after: const <String, Object?>{'amountMinor': 1400},
    occurredAt: occurredAt ?? DateTime.utc(2030, 1, 1),
  );
}

class _InMemoryAuditLogStore implements AuditLogStore {
  final List<AuditEvent> events = <AuditEvent>[];

  @override
  Future<AppResult<void>> append(AuditEvent event) async {
    events.add(event);
    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<List<AuditEvent>>> query({
    required String workspaceId,
    required DateTime from,
    required DateTime to,
    required int limit,
  }) async {
    final matches = events
        .where(
          (event) =>
              event.workspaceId == workspaceId &&
              !event.occurredAt.isBefore(from) &&
              !event.occurredAt.isAfter(to),
        )
        .take(limit)
        .toList(growable: false);
    return AppSuccess<List<AuditEvent>>(matches);
  }
}
