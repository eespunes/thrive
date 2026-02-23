import 'dart:async';
import 'dart:collection';

import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

class CursorPage<T> {
  const CursorPage({required this.items, required this.nextCursor});

  final List<T> items;
  final String? nextCursor;
}

typedef CursorExtractor<T> = String Function(T item);

class CursorPaginator<T> {
  AppResult<CursorPage<T>> paginate({
    required List<T> orderedItems,
    required int limit,
    required CursorExtractor<T> cursorExtractor,
    String? afterCursor,
  }) {
    if (limit <= 0) {
      return AppFailure<CursorPage<T>>(
        FailureDetail(
          code: 'pagination_limit_invalid',
          developerMessage: 'Pagination limit must be greater than zero.',
          userMessage: 'Could not load more items right now.',
          recoverable: true,
        ),
      );
    }

    final seenCursors = <String>{};
    for (final item in orderedItems) {
      final cursor = cursorExtractor(item);
      if (!seenCursors.add(cursor)) {
        return AppFailure<CursorPage<T>>(
          FailureDetail(
            code: 'pagination_cursor_not_unique',
            developerMessage:
                'Duplicate cursor "$cursor" found in ordered list.',
            userMessage: 'Could not load this list. Please refresh and retry.',
            recoverable: true,
          ),
        );
      }
    }

    var startIndex = 0;
    if (afterCursor != null) {
      final cursorIndex = orderedItems.indexWhere(
        (item) => cursorExtractor(item) == afterCursor,
      );
      if (cursorIndex < 0) {
        return AppFailure<CursorPage<T>>(
          FailureDetail(
            code: 'pagination_cursor_invalid',
            developerMessage:
                'Cursor $afterCursor was not found in ordered list.',
            userMessage:
                'Could not continue loading this list. Please refresh.',
            recoverable: true,
          ),
        );
      }
      startIndex = cursorIndex + 1;
    }

    if (startIndex >= orderedItems.length) {
      return AppSuccess<CursorPage<T>>(
        CursorPage<T>(items: <T>[], nextCursor: null),
      );
    }

    final endIndex = (startIndex + limit) < orderedItems.length
        ? (startIndex + limit)
        : orderedItems.length;
    final items = orderedItems.sublist(startIndex, endIndex);

    final hasMore = endIndex < orderedItems.length;
    final nextCursor = items.isEmpty || !hasMore
        ? null
        : cursorExtractor(items.last);

    return AppSuccess<CursorPage<T>>(
      CursorPage<T>(items: items, nextCursor: nextCursor),
    );
  }
}

class _CacheEntry<T> {
  const _CacheEntry({required this.page, required this.expiresAt});

  final CursorPage<T> page;
  final DateTime expiresAt;
}

class RealtimePageCache<T> {
  RealtimePageCache({required Duration ttl, required AppLogger logger})
    : assert(ttl > Duration.zero, 'ttl must be positive'),
      _ttl = ttl,
      _logger = logger;

  final Duration _ttl;
  final AppLogger _logger;
  final Map<String, _CacheEntry<T>> _entries = <String, _CacheEntry<T>>{};

  AppResult<void> put({
    required String queryKey,
    required CursorPage<T> page,
    required DateTime cachedAt,
  }) {
    final queryKeyResult = _validateQueryKey(queryKey);
    if (queryKeyResult is AppFailure<void>) {
      return queryKeyResult;
    }

    _entries[queryKey] = _CacheEntry<T>(
      page: page,
      expiresAt: cachedAt.add(_ttl),
    );
    _logger.info(
      code: 'realtime_cache_updated',
      message: 'Realtime page cache updated',
      metadata: <String, Object?>{
        'queryKey': queryKey,
        'itemCount': page.items.length,
        'nextCursor': page.nextCursor,
      },
    );
    return const AppSuccess<void>(null);
  }

  AppResult<CursorPage<T>> read({
    required String queryKey,
    required DateTime now,
  }) {
    final queryKeyResult = _validateQueryKey(queryKey);
    if (queryKeyResult is AppFailure<void>) {
      return AppFailure<CursorPage<T>>(queryKeyResult.detail);
    }

    final entry = _entries[queryKey];
    if (entry == null) {
      return _cacheFailure(
        code: 'realtime_cache_miss',
        developerMessage: 'No cache entry found for $queryKey.',
      );
    }

    if (now.isAfter(entry.expiresAt)) {
      _entries.remove(queryKey);
      return _cacheFailure(
        code: 'realtime_cache_expired',
        developerMessage: 'Cache entry expired for $queryKey.',
      );
    }

    _logger.info(
      code: 'realtime_cache_hit',
      message: 'Realtime page cache hit',
      metadata: <String, Object?>{'queryKey': queryKey},
    );
    return AppSuccess<CursorPage<T>>(entry.page);
  }

  AppResult<void> invalidate(String queryKey) {
    final queryKeyResult = _validateQueryKey(queryKey);
    if (queryKeyResult is AppFailure<void>) {
      return queryKeyResult;
    }

    _entries.remove(queryKey);
    _logger.info(
      code: 'realtime_cache_invalidated',
      message: 'Realtime page cache invalidated',
      metadata: <String, Object?>{'queryKey': queryKey},
    );
    return const AppSuccess<void>(null);
  }

  AppFailure<CursorPage<T>> _cacheFailure({
    required String code,
    required String developerMessage,
  }) {
    _logger.warning(code: code, message: developerMessage);
    return AppFailure<CursorPage<T>>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: 'Could not use cached data. Reloading latest content.',
        recoverable: true,
      ),
    );
  }

  AppResult<void> _validateQueryKey(String queryKey) {
    if (queryKey.trim().isEmpty) {
      _logger.warning(
        code: 'realtime_query_key_invalid',
        message: 'Realtime queryKey cannot be empty.',
      );
      return AppFailure<void>(
        FailureDetail(
          code: 'realtime_query_key_invalid',
          developerMessage: 'Realtime queryKey cannot be empty.',
          userMessage: 'Could not load this view right now.',
          recoverable: true,
        ),
      );
    }

    return const AppSuccess<void>(null);
  }
}

class RealtimeSubscriptionController<T> {
  RealtimeSubscriptionController({required AppLogger logger})
    : _logger = logger;

  final AppLogger _logger;
  final Map<String, StreamSubscription<List<T>>> _subscriptions =
      <String, StreamSubscription<List<T>>>{};

  int get activeSubscriptionCount => _subscriptions.length;

  Future<AppResult<void>> attach({
    required String queryKey,
    required Stream<List<T>> stream,
    required void Function(List<T> items) onData,
  }) async {
    final queryKeyResult = _validateQueryKey(queryKey);
    if (queryKeyResult is AppFailure<void>) {
      return queryKeyResult;
    }

    if (_subscriptions.containsKey(queryKey)) {
      return AppFailure<void>(
        FailureDetail(
          code: 'realtime_subscription_duplicate',
          developerMessage: 'Subscription already attached for $queryKey.',
          userMessage: 'Live updates are already enabled for this view.',
          recoverable: true,
        ),
      );
    }

    final subscription = stream.listen(
      (items) {
        _logger.info(
          code: 'realtime_subscription_event',
          message: 'Realtime subscription event received',
          metadata: <String, Object?>{
            'queryKey': queryKey,
            'itemCount': items.length,
          },
        );
        onData(items);
      },
      onError: (Object error, StackTrace stackTrace) {
        _logger.warning(
          code: 'realtime_subscription_error',
          message: 'Realtime subscription emitted an error: $error',
          metadata: <String, Object?>{'queryKey': queryKey},
        );
      },
    );

    _subscriptions[queryKey] = subscription;
    _logger.info(
      code: 'realtime_subscription_started',
      message: 'Realtime subscription started',
      metadata: <String, Object?>{'queryKey': queryKey},
    );

    return const AppSuccess<void>(null);
  }

  Future<AppResult<void>> detach(String queryKey) async {
    final queryKeyResult = _validateQueryKey(queryKey);
    if (queryKeyResult is AppFailure<void>) {
      return queryKeyResult;
    }

    final subscription = _subscriptions.remove(queryKey);
    if (subscription == null) {
      return const AppSuccess<void>(null);
    }

    await subscription.cancel();
    _logger.info(
      code: 'realtime_subscription_stopped',
      message: 'Realtime subscription stopped',
      metadata: <String, Object?>{'queryKey': queryKey},
    );
    return const AppSuccess<void>(null);
  }

  Future<void> detachAll() async {
    final keys = _subscriptions.keys.toList(growable: false);
    for (final key in keys) {
      await detach(key);
    }
  }

  List<String> activeKeys() =>
      UnmodifiableListView<String>(_subscriptions.keys.toList(growable: false));

  AppResult<void> _validateQueryKey(String queryKey) {
    if (queryKey.trim().isEmpty) {
      _logger.warning(
        code: 'realtime_query_key_invalid',
        message: 'Realtime queryKey cannot be empty.',
      );
      return AppFailure<void>(
        FailureDetail(
          code: 'realtime_query_key_invalid',
          developerMessage: 'Realtime queryKey cannot be empty.',
          userMessage: 'Could not load this view right now.',
          recoverable: true,
        ),
      );
    }

    return const AppSuccess<void>(null);
  }
}
