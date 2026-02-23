import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/realtime/realtime_pagination_cache.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('paginates ordered items and returns next cursor', () {
    final paginator = CursorPaginator<_Row>();
    final rows = <_Row>[
      const _Row(id: 'a'),
      const _Row(id: 'b'),
      const _Row(id: 'c'),
    ];

    final result = paginator.paginate(
      orderedItems: rows,
      limit: 2,
      cursorExtractor: (row) => row.id,
    );

    expect(result, isA<AppSuccess<CursorPage<_Row>>>());
    final page = (result as AppSuccess<CursorPage<_Row>>).value;
    expect(page.items.map((row) => row.id), <String>['a', 'b']);
    expect(page.nextCursor, 'b');
  });

  test('returns pagination failure when cursor is invalid', () {
    final paginator = CursorPaginator<_Row>();

    final result = paginator.paginate(
      orderedItems: const <_Row>[_Row(id: 'a')],
      limit: 10,
      cursorExtractor: (row) => row.id,
      afterCursor: 'missing',
    );

    expect(result, isA<AppFailure<CursorPage<_Row>>>());
    final detail = (result as AppFailure<CursorPage<_Row>>).detail;
    expect(detail.code, 'pagination_cursor_invalid');
  });

  test('returns pagination failure when cursor values are duplicated', () {
    final paginator = CursorPaginator<_Row>();

    final result = paginator.paginate(
      orderedItems: const <_Row>[
        _Row(id: 'a'),
        _Row(id: 'a'),
      ],
      limit: 10,
      cursorExtractor: (row) => row.id,
    );

    expect(result, isA<AppFailure<CursorPage<_Row>>>());
    final detail = (result as AppFailure<CursorPage<_Row>>).detail;
    expect(detail.code, 'pagination_cursor_not_unique');
  });

  test('cache stores and returns page before TTL expiration', () {
    final logger = InMemoryAppLogger();
    final cache = RealtimePageCache<_Row>(
      ttl: const Duration(minutes: 5),
      logger: logger,
    );
    final cachedAt = DateTime.utc(2030, 1, 1, 0, 0, 0);

    final putResult = cache.put(
      queryKey: 'workspace:home',
      page: const CursorPage<_Row>(
        items: <_Row>[_Row(id: 'a')],
        nextCursor: null,
      ),
      cachedAt: cachedAt,
    );

    expect(putResult, isA<AppSuccess<void>>());

    final readResult = cache.read(
      queryKey: 'workspace:home',
      now: cachedAt.add(const Duration(minutes: 1)),
    );

    expect(readResult, isA<AppSuccess<CursorPage<_Row>>>());
    final page = (readResult as AppSuccess<CursorPage<_Row>>).value;
    expect(page.items.single.id, 'a');
    expect(
      logger.events.map((event) => event.code),
      contains('realtime_cache_hit'),
    );
  });

  test('cache read fails when entry expires', () {
    final cache = RealtimePageCache<_Row>(
      ttl: const Duration(minutes: 5),
      logger: InMemoryAppLogger(),
    );
    final cachedAt = DateTime.utc(2030, 1, 1, 0, 0, 0);

    cache.put(
      queryKey: 'workspace:home',
      page: const CursorPage<_Row>(items: <_Row>[], nextCursor: null),
      cachedAt: cachedAt,
    );

    final readResult = cache.read(
      queryKey: 'workspace:home',
      now: cachedAt.add(const Duration(minutes: 6)),
    );

    expect(readResult, isA<AppFailure<CursorPage<_Row>>>());
    final detail = (readResult as AppFailure<CursorPage<_Row>>).detail;
    expect(detail.code, 'realtime_cache_expired');
  });

  test('cache invalidates entry by query key', () {
    final cache = RealtimePageCache<_Row>(
      ttl: const Duration(minutes: 5),
      logger: InMemoryAppLogger(),
    );
    final now = DateTime.utc(2030, 1, 1, 0, 0, 0);

    cache.put(
      queryKey: 'workspace:home',
      page: const CursorPage<_Row>(items: <_Row>[], nextCursor: null),
      cachedAt: now,
    );

    final invalidateResult = cache.invalidate('workspace:home');
    expect(invalidateResult, isA<AppSuccess<void>>());

    final readResult = cache.read(queryKey: 'workspace:home', now: now);
    expect(readResult, isA<AppFailure<CursorPage<_Row>>>());
    final detail = (readResult as AppFailure<CursorPage<_Row>>).detail;
    expect(detail.code, 'realtime_cache_miss');
  });

  test('cache fails with deterministic code for empty query key', () {
    final cache = RealtimePageCache<_Row>(
      ttl: const Duration(minutes: 5),
      logger: InMemoryAppLogger(),
    );

    final result = cache.put(
      queryKey: ' ',
      page: const CursorPage<_Row>(items: <_Row>[], nextCursor: null),
      cachedAt: DateTime.utc(2030, 1, 1),
    );

    expect(result, isA<AppFailure<void>>());
    final detail = (result as AppFailure<void>).detail;
    expect(detail.code, 'realtime_query_key_invalid');
  });

  test(
    'subscription lifecycle attaches, receives events, and detaches',
    () async {
      final logger = InMemoryAppLogger();
      final controller = StreamController<List<_Row>>();
      final subscription = RealtimeSubscriptionController<_Row>(logger: logger);
      final received = <List<_Row>>[];

      final attachResult = await subscription.attach(
        queryKey: 'workspace:home',
        stream: controller.stream,
        onData: received.add,
      );

      expect(attachResult, isA<AppSuccess<void>>());
      expect(subscription.activeSubscriptionCount, 1);

      controller.add(const <_Row>[_Row(id: 'a'), _Row(id: 'b')]);
      await Future<void>.delayed(Duration.zero);

      expect(received.single.map((row) => row.id), <String>['a', 'b']);

      final detachResult = await subscription.detach('workspace:home');
      expect(detachResult, isA<AppSuccess<void>>());
      expect(subscription.activeSubscriptionCount, 0);
      expect(
        logger.events.map((event) => event.code),
        containsAll(<String>[
          'realtime_subscription_started',
          'realtime_subscription_event',
          'realtime_subscription_stopped',
        ]),
      );

      await controller.close();
    },
  );

  test('subscription attach rejects duplicate query key', () async {
    final controller = StreamController<List<_Row>>();
    final subscription = RealtimeSubscriptionController<_Row>(
      logger: InMemoryAppLogger(),
    );

    final first = await subscription.attach(
      queryKey: 'workspace:home',
      stream: controller.stream,
      onData: (_) {},
    );
    final second = await subscription.attach(
      queryKey: 'workspace:home',
      stream: controller.stream,
      onData: (_) {},
    );

    expect(first, isA<AppSuccess<void>>());
    expect(second, isA<AppFailure<void>>());
    final detail = (second as AppFailure<void>).detail;
    expect(detail.code, 'realtime_subscription_duplicate');

    await subscription.detachAll();
    await controller.close();
  });

  test('subscription rejects empty query key', () async {
    final subscription = RealtimeSubscriptionController<_Row>(
      logger: InMemoryAppLogger(),
    );

    final result = await subscription.attach(
      queryKey: '',
      stream: const Stream<List<_Row>>.empty(),
      onData: (_) {},
    );

    expect(result, isA<AppFailure<void>>());
    final detail = (result as AppFailure<void>).detail;
    expect(detail.code, 'realtime_query_key_invalid');
  });
}

class _Row {
  const _Row({required this.id});

  final String id;
}
