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
