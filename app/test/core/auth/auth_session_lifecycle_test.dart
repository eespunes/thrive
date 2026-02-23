import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/auth/auth_session.dart';
import 'package:thrive_app/core/auth/auth_session_lifecycle.dart';
import 'package:thrive_app/core/auth/auth_session_store.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test(
    'createSession persists session and logs auth_session_created',
    () async {
      final logger = InMemoryAppLogger();
      final store = InMemoryAuthSessionStore();
      final lifecycle = AuthSessionLifecycle(
        store: store,
        refresher: _FixedRefresher(
          result: AppSuccess<AuthSession>(_session(accessToken: 'token-new')),
        ),
        logger: logger,
      );

      final result = await lifecycle.createSession(
        _session(accessToken: 'token-a'),
      );

      expect(result, isA<AppSuccess<void>>());
      final readBack = await store.read();
      expect(readBack, isA<AppSuccess<AuthSession?>>());
      final session = (readBack as AppSuccess<AuthSession?>).value;
      expect(session?.accessToken, 'token-a');
      expect(
        logger.events.map((event) => event.code),
        contains('auth_session_created'),
      );
    },
  );

  test(
    'validAccessToken returns cached token when refresh is not needed',
    () async {
      final logger = InMemoryAppLogger();
      final store = InMemoryAuthSessionStore();
      await store.write(
        _session(
          accessToken: 'cached-token',
          expiresAt: DateTime.utc(2030, 1, 1),
        ),
      );

      final lifecycle = AuthSessionLifecycle(
        store: store,
        refresher: _FixedRefresher(
          result: AppSuccess<AuthSession>(_session(accessToken: 'token-new')),
        ),
        logger: logger,
        clock: () => DateTime.utc(2029, 1, 1),
      );

      final result = await lifecycle.validAccessToken();

      expect(result, isA<AppSuccess<String>>());
      final token = (result as AppSuccess<String>).value;
      expect(token, 'cached-token');
    },
  );

  test(
    'validAccessToken refreshes and persists when token is near expiry',
    () async {
      final logger = InMemoryAppLogger();
      final store = InMemoryAuthSessionStore();
      await store.write(
        _session(
          accessToken: 'stale-token',
          expiresAt: DateTime.utc(2029, 1, 1, 0, 1),
        ),
      );

      final refreshed = _session(
        sessionId: 'session-1',
        accessToken: 'fresh-token',
        expiresAt: DateTime.utc(2029, 1, 1, 1, 0),
      );

      final lifecycle = AuthSessionLifecycle(
        store: store,
        refresher: _FixedRefresher(result: AppSuccess<AuthSession>(refreshed)),
        logger: logger,
        clock: () => DateTime.utc(2029, 1, 1, 0, 0),
      );

      final result = await lifecycle.validAccessToken();

      expect(result, isA<AppSuccess<String>>());
      final token = (result as AppSuccess<String>).value;
      expect(token, 'fresh-token');
      final persisted = await store.read();
      final persistedSession = (persisted as AppSuccess<AuthSession?>).value;
      expect(persistedSession?.accessToken, 'fresh-token');
      expect(
        logger.events.map((event) => event.code),
        contains('auth_token_refreshed'),
      );
    },
  );

  test('validAccessToken clears store when refresh token is revoked', () async {
    final logger = InMemoryAppLogger();
    final store = InMemoryAuthSessionStore();
    await store.write(
      _session(
        accessToken: 'stale-token',
        expiresAt: DateTime.utc(2029, 1, 1, 0, 1),
      ),
    );

    final lifecycle = AuthSessionLifecycle(
      store: store,
      refresher: _FixedRefresher(
        result: AppFailure<AuthSession>(
          FailureDetail(
            code: 'auth_refresh_token_revoked',
            developerMessage: 'Refresh token revoked upstream.',
            userMessage: 'Session revoked.',
            recoverable: true,
          ),
        ),
      ),
      logger: logger,
      clock: () => DateTime.utc(2029, 1, 1, 0, 0),
    );

    final result = await lifecycle.validAccessToken();

    expect(result, isA<AppFailure<String>>());
    final detail = (result as AppFailure<String>).detail;
    expect(detail.code, 'auth_session_revoked');
    final readBack = await store.read();
    expect((readBack as AppSuccess<AuthSession?>).value, isNull);
  });

  test(
    'validAccessToken returns auth_session_missing when no session exists',
    () async {
      final logger = InMemoryAppLogger();
      final store = InMemoryAuthSessionStore();
      final lifecycle = AuthSessionLifecycle(
        store: store,
        refresher: _FixedRefresher(
          result: AppSuccess<AuthSession>(_session(accessToken: 'unused')),
        ),
        logger: logger,
      );

      final result = await lifecycle.validAccessToken();

      expect(result, isA<AppFailure<String>>());
      final detail = (result as AppFailure<String>).detail;
      expect(detail.code, 'auth_session_missing');
    },
  );

  test('validAccessToken propagates non-revocation refresh failures', () async {
    final logger = InMemoryAppLogger();
    final store = InMemoryAuthSessionStore();
    await store.write(
      _session(
        accessToken: 'stale-token',
        expiresAt: DateTime.utc(2029, 1, 1, 0, 1),
      ),
    );

    final lifecycle = AuthSessionLifecycle(
      store: store,
      refresher: _FixedRefresher(
        result: AppFailure<AuthSession>(
          FailureDetail(
            code: 'auth_refresh_network_error',
            developerMessage: 'Refresh endpoint timed out.',
            userMessage: 'Please try again in a moment.',
            recoverable: true,
          ),
        ),
      ),
      logger: logger,
      clock: () => DateTime.utc(2029, 1, 1, 0, 0),
    );

    final result = await lifecycle.validAccessToken();

    expect(result, isA<AppFailure<String>>());
    final detail = (result as AppFailure<String>).detail;
    expect(detail.code, 'auth_refresh_network_error');
  });

  test(
    'validAccessToken performs one refresh when called concurrently',
    () async {
      final logger = InMemoryAppLogger();
      final store = InMemoryAuthSessionStore();
      await store.write(
        _session(
          accessToken: 'stale-token',
          expiresAt: DateTime.utc(2029, 1, 1, 0, 1),
        ),
      );

      final refresher = _CountingRefresher(
        result: AppSuccess<AuthSession>(
          _session(
            accessToken: 'fresh-token',
            expiresAt: DateTime.utc(2029, 1, 1, 1, 0),
          ),
        ),
      );
      final lifecycle = AuthSessionLifecycle(
        store: store,
        refresher: refresher,
        logger: logger,
        clock: () => DateTime.utc(2029, 1, 1, 0, 0),
      );

      final results = await Future.wait<AppResult<String>>(
        <Future<AppResult<String>>>[
          lifecycle.validAccessToken(),
          lifecycle.validAccessToken(),
        ],
      );

      expect(refresher.callCount, 1);
      expect(results[0], isA<AppSuccess<String>>());
      expect(results[1], isA<AppSuccess<String>>());
    },
  );

  test(
    'validAccessToken does not reuse in-flight refresh for a different session',
    () async {
      final logger = InMemoryAppLogger();
      final store = InMemoryAuthSessionStore();
      await store.write(
        _session(
          sessionId: 'session-old',
          userId: 'user-old',
          accessToken: 'old-stale-token',
          expiresAt: DateTime.utc(2029, 1, 1, 0, 1),
        ),
      );

      final refresher = _SessionAwareDelayedRefresher();
      final lifecycle = AuthSessionLifecycle(
        store: store,
        refresher: refresher,
        logger: logger,
        clock: () => DateTime.utc(2029, 1, 1, 0, 0),
      );

      final firstCall = lifecycle.validAccessToken();
      await refresher.waitUntilCalled('session-old');

      await lifecycle.createSession(
        _session(
          sessionId: 'session-new',
          userId: 'user-new',
          accessToken: 'new-stale-token',
          expiresAt: DateTime.utc(2029, 1, 1, 0, 1),
        ),
      );

      final secondCall = lifecycle.validAccessToken();
      await refresher.waitUntilCalled('session-new');

      refresher.complete(
        sessionId: 'session-new',
        result: AppSuccess<AuthSession>(
          _session(
            sessionId: 'session-new',
            userId: 'user-new',
            accessToken: 'new-fresh-token',
            expiresAt: DateTime.utc(2029, 1, 1, 1, 0),
          ),
        ),
      );

      final secondResult = await secondCall;
      expect(secondResult, isA<AppSuccess<String>>());
      expect((secondResult as AppSuccess<String>).value, 'new-fresh-token');

      refresher.complete(
        sessionId: 'session-old',
        result: AppSuccess<AuthSession>(
          _session(
            sessionId: 'session-old',
            userId: 'user-old',
            accessToken: 'old-fresh-token',
            expiresAt: DateTime.utc(2029, 1, 1, 1, 0),
          ),
        ),
      );

      final firstResult = await firstCall;
      expect(firstResult, isA<AppFailure<String>>());
      expect(
        (firstResult as AppFailure<String>).detail.code,
        'auth_session_changed_during_refresh',
      );

      final readBack = await store.read();
      final persistedSession = (readBack as AppSuccess<AuthSession?>).value;
      expect(persistedSession?.sessionId, 'session-new');
      expect(persistedSession?.accessToken, 'new-fresh-token');
      expect(refresher.callCountBySession('session-old'), 1);
      expect(refresher.callCountBySession('session-new'), 1);
    },
  );

  test(
    'signOut clears local session even when remote revocation fails',
    () async {
      final logger = InMemoryAppLogger();
      final store = InMemoryAuthSessionStore();
      await store.write(_session(accessToken: 'token-a'));

      final lifecycle = AuthSessionLifecycle(
        store: store,
        refresher: _FixedRefresher(
          result: AppSuccess<AuthSession>(_session(accessToken: 'unused')),
        ),
        revocationGateway: _FixedRevoker(
          result: AppFailure<void>(
            FailureDetail(
              code: 'auth_revoke_failed',
              developerMessage: 'Remote revoke endpoint unavailable.',
              userMessage: 'Could not sign out from all devices right now.',
              recoverable: true,
            ),
          ),
        ),
        logger: logger,
      );

      final result = await lifecycle.signOut(revokeRemote: true);

      expect(result, isA<AppFailure<void>>());
      final readBack = await store.read();
      expect((readBack as AppSuccess<AuthSession?>).value, isNull);
      expect(
        logger.events.map((event) => event.code),
        contains('auth_session_signed_out'),
      );
    },
  );

  test(
    'signOut with default revokeRemote=false clears local session',
    () async {
      final logger = InMemoryAppLogger();
      final store = InMemoryAuthSessionStore();
      await store.write(_session(accessToken: 'token-a'));

      final revoker = _CountingRevoker(result: const AppSuccess<void>(null));
      final lifecycle = AuthSessionLifecycle(
        store: store,
        refresher: _FixedRefresher(
          result: AppSuccess<AuthSession>(_session(accessToken: 'unused')),
        ),
        revocationGateway: revoker,
        logger: logger,
      );

      final result = await lifecycle.signOut();

      expect(result, isA<AppSuccess<void>>());
      expect(revoker.callCount, 0);
      final readBack = await store.read();
      expect((readBack as AppSuccess<AuthSession?>).value, isNull);
    },
  );

  test('signOut succeeds when no session exists', () async {
    final logger = InMemoryAppLogger();
    final store = InMemoryAuthSessionStore();
    final revoker = _CountingRevoker(result: const AppSuccess<void>(null));

    final lifecycle = AuthSessionLifecycle(
      store: store,
      refresher: _FixedRefresher(
        result: AppSuccess<AuthSession>(_session(accessToken: 'unused')),
      ),
      revocationGateway: revoker,
      logger: logger,
    );

    final result = await lifecycle.signOut(revokeRemote: true);

    expect(result, isA<AppSuccess<void>>());
    expect(revoker.callCount, 0);
  });

  test(
    'handleRemoteRevocation clears matching session and returns failure',
    () async {
      final logger = InMemoryAppLogger();
      final store = InMemoryAuthSessionStore();
      await store.write(
        _session(sessionId: 'session-remote', accessToken: 'token-a'),
      );

      final lifecycle = AuthSessionLifecycle(
        store: store,
        refresher: _FixedRefresher(
          result: AppSuccess<AuthSession>(_session(accessToken: 'unused')),
        ),
        logger: logger,
      );

      final result = await lifecycle.handleRemoteRevocation(
        sessionId: 'session-remote',
      );

      expect(result, isA<AppFailure<void>>());
      final detail = (result as AppFailure<void>).detail;
      expect(detail.code, 'auth_session_revoked');
      final readBack = await store.read();
      expect((readBack as AppSuccess<AuthSession?>).value, isNull);
    },
  );

  test('handleRemoteRevocation ignores non-matching session id', () async {
    final logger = InMemoryAppLogger();
    final store = InMemoryAuthSessionStore();
    await store.write(
      _session(sessionId: 'session-local', accessToken: 'token-a'),
    );

    final lifecycle = AuthSessionLifecycle(
      store: store,
      refresher: _FixedRefresher(
        result: AppSuccess<AuthSession>(_session(accessToken: 'unused')),
      ),
      logger: logger,
    );

    final result = await lifecycle.handleRemoteRevocation(
      sessionId: 'session-remote',
    );

    expect(result, isA<AppSuccess<void>>());
    final readBack = await store.read();
    final session = (readBack as AppSuccess<AuthSession?>).value;
    expect(session, isNotNull);
    expect(session?.sessionId, 'session-local');
  });
}

AuthSession _session({
  String sessionId = 'session-1',
  String userId = 'user-1',
  String accessToken = 'token-current',
  String refreshToken = 'refresh-current',
  DateTime? expiresAt,
}) {
  return AuthSession(
    sessionId: sessionId,
    userId: userId,
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: expiresAt ?? DateTime.utc(2030, 1, 1),
  );
}

class _FixedRefresher implements AuthTokenRefresher {
  const _FixedRefresher({required this.result});

  final AppResult<AuthSession> result;

  @override
  Future<AppResult<AuthSession>> refresh({required AuthSession session}) async {
    return result;
  }
}

class _FixedRevoker implements AuthSessionRevocationGateway {
  const _FixedRevoker({required this.result});

  final AppResult<void> result;

  @override
  Future<AppResult<void>> revoke({required AuthSession session}) async {
    return result;
  }
}

class _CountingRefresher implements AuthTokenRefresher {
  _CountingRefresher({required this.result});

  final AppResult<AuthSession> result;
  int callCount = 0;

  @override
  Future<AppResult<AuthSession>> refresh({required AuthSession session}) async {
    callCount += 1;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    return result;
  }
}

class _CountingRevoker implements AuthSessionRevocationGateway {
  _CountingRevoker({required this.result});

  final AppResult<void> result;
  int callCount = 0;

  @override
  Future<AppResult<void>> revoke({required AuthSession session}) async {
    callCount += 1;
    return result;
  }
}

class _SessionAwareDelayedRefresher implements AuthTokenRefresher {
  final Map<String, int> _callCount = <String, int>{};
  final Map<String, Completer<AppResult<AuthSession>>> _pending =
      <String, Completer<AppResult<AuthSession>>>{};

  int callCountBySession(String sessionId) => _callCount[sessionId] ?? 0;

  Future<void> waitUntilCalled(String sessionId) async {
    while (!_pending.containsKey(sessionId)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  void complete({
    required String sessionId,
    required AppResult<AuthSession> result,
  }) {
    final completer = _pending[sessionId];
    if (completer == null || completer.isCompleted) {
      throw StateError('No pending refresh for session: $sessionId');
    }
    completer.complete(result);
  }

  @override
  Future<AppResult<AuthSession>> refresh({required AuthSession session}) {
    _callCount[session.sessionId] = (_callCount[session.sessionId] ?? 0) + 1;
    final completer = Completer<AppResult<AuthSession>>();
    _pending[session.sessionId] = completer;
    return completer.future;
  }
}
