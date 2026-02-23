import 'package:thrive_app/core/auth/auth_session.dart';
import 'package:thrive_app/core/auth/auth_session_store.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

typedef Clock = DateTime Function();

abstract interface class AuthTokenRefresher {
  Future<AppResult<AuthSession>> refresh({required AuthSession session});
}

abstract interface class AuthSessionRevocationGateway {
  Future<AppResult<void>> revoke({required AuthSession session});
}

class NoopAuthSessionRevocationGateway implements AuthSessionRevocationGateway {
  const NoopAuthSessionRevocationGateway();

  @override
  Future<AppResult<void>> revoke({required AuthSession session}) async {
    return const AppSuccess<void>(null);
  }
}

class AuthSessionLifecycle {
  AuthSessionLifecycle({
    required AuthSessionStore store,
    required AuthTokenRefresher refresher,
    required AppLogger logger,
    AuthSessionRevocationGateway revocationGateway =
        const NoopAuthSessionRevocationGateway(),
    Clock clock = _utcNow,
  }) : _store = store,
       _refresher = refresher,
       _logger = logger,
       _revocationGateway = revocationGateway,
       _clock = clock;

  final AuthSessionStore _store;
  final AuthTokenRefresher _refresher;
  final AppLogger _logger;
  final AuthSessionRevocationGateway _revocationGateway;
  final Clock _clock;
  _SessionRefreshInFlight? _refreshInFlight;

  Future<AppResult<void>> createSession(AuthSession session) async {
    final result = await _store.write(session);
    result.when(
      success: (_) {
        _logger.info(
          code: 'auth_session_created',
          message: 'Authentication session persisted',
          metadata: <String, Object?>{
            'sessionId': session.sessionId,
            'userId': session.userId,
          },
        );
      },
      failure: (failure) {
        _logger.error(code: failure.code, message: failure.developerMessage);
      },
    );
    return result;
  }

  Future<AppResult<String>> validAccessToken() async {
    final sessionResult = await _store.read();
    if (sessionResult is AppFailure<AuthSession?>) {
      return AppFailure<String>(sessionResult.detail);
    }

    final session = (sessionResult as AppSuccess<AuthSession?>).value;
    if (session == null) {
      return AppFailure<String>(
        FailureDetail(
          code: 'auth_session_missing',
          developerMessage: 'No active session found in store.',
          userMessage: 'Your session has ended. Please sign in again.',
          recoverable: true,
        ),
      );
    }

    if (!session.shouldRefresh(_clock())) {
      return AppSuccess<String>(session.accessToken);
    }

    final currentRefresh = _refreshInFlight;
    if (currentRefresh != null &&
        currentRefresh.sessionId == session.sessionId) {
      return currentRefresh.future;
    }

    final refreshFuture = _refreshAndPersist(session);
    final refreshInFlight = _SessionRefreshInFlight(
      sessionId: session.sessionId,
      future: refreshFuture,
    );
    _refreshInFlight = refreshInFlight;
    try {
      return await refreshFuture;
    } finally {
      if (identical(_refreshInFlight, refreshInFlight)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<AppResult<String>> _refreshAndPersist(AuthSession session) async {
    final refreshResult = await _refresher.refresh(session: session);
    if (refreshResult is AppFailure<AuthSession>) {
      final detail = refreshResult.detail;
      if (detail.code == 'auth_refresh_token_revoked' ||
          detail.code == 'auth_refresh_unauthorized') {
        await _store.clear();
        _logger.warning(
          code: 'auth_session_revoked',
          message: 'Session revoked while refreshing token',
          metadata: <String, Object?>{
            'sessionId': session.sessionId,
            'reason': detail.code,
          },
        );
        return AppFailure<String>(
          FailureDetail(
            code: 'auth_session_revoked',
            developerMessage:
                'Refresh failed due to revoked or unauthorized token.',
            userMessage: 'Your session has ended. Please sign in again.',
            recoverable: true,
          ),
        );
      }

      _logger.warning(code: detail.code, message: detail.developerMessage);
      return AppFailure<String>(detail);
    }

    final refreshedSession = (refreshResult as AppSuccess<AuthSession>).value;
    final activeSessionResult = await _store.read();
    if (activeSessionResult is AppFailure<AuthSession?>) {
      return AppFailure<String>(activeSessionResult.detail);
    }

    final activeSession =
        (activeSessionResult as AppSuccess<AuthSession?>).value;
    if (activeSession == null || activeSession.sessionId != session.sessionId) {
      _logger.warning(
        code: 'auth_refresh_discarded_session_changed',
        message: 'Discarded refresh result because active session changed',
        metadata: <String, Object?>{
          'refreshedSessionId': session.sessionId,
          'activeSessionId': activeSession?.sessionId,
        },
      );
      return AppFailure<String>(
        FailureDetail(
          code: 'auth_session_changed_during_refresh',
          developerMessage:
              'Active session changed while token refresh was in-flight.',
          userMessage: 'Your session changed. Please retry the operation.',
          recoverable: true,
        ),
      );
    }

    final writeResult = await _store.write(refreshedSession);
    if (writeResult is AppFailure<void>) {
      return AppFailure<String>(writeResult.detail);
    }

    _logger.info(
      code: 'auth_token_refreshed',
      message: 'Access token refreshed and persisted',
      metadata: <String, Object?>{
        'sessionId': refreshedSession.sessionId,
        'userId': refreshedSession.userId,
      },
    );
    return AppSuccess<String>(refreshedSession.accessToken);
  }

  Future<AppResult<void>> signOut({bool revokeRemote = false}) async {
    AppFailure<void>? remoteFailure;
    if (revokeRemote) {
      final sessionResult = await _store.read();
      if (sessionResult is AppFailure<AuthSession?>) {
        return AppFailure<void>(sessionResult.detail);
      }
      final session = (sessionResult as AppSuccess<AuthSession?>).value;
      if (session != null) {
        final revokeResult = await _revocationGateway.revoke(session: session);
        if (revokeResult is AppFailure<void>) {
          remoteFailure = revokeResult;
          _logger.warning(
            code: revokeResult.detail.code,
            message: revokeResult.detail.developerMessage,
          );
        }
      }
    }

    final clearResult = await _store.clear();
    if (clearResult is AppFailure<void>) {
      return clearResult;
    }

    _logger.info(
      code: 'auth_session_signed_out',
      message: 'Session cleared from local storage',
    );

    if (remoteFailure != null) {
      return remoteFailure;
    }
    return const AppSuccess<void>(null);
  }

  Future<AppResult<void>> handleRemoteRevocation({
    required String sessionId,
  }) async {
    final sessionResult = await _store.read();
    if (sessionResult is AppFailure<AuthSession?>) {
      return AppFailure<void>(sessionResult.detail);
    }

    final session = (sessionResult as AppSuccess<AuthSession?>).value;
    if (session == null || session.sessionId != sessionId) {
      return const AppSuccess<void>(null);
    }

    final clearResult = await _store.clear();
    if (clearResult is AppFailure<void>) {
      return clearResult;
    }

    _logger.warning(
      code: 'auth_session_revoked',
      message: 'Active session revoked remotely',
      metadata: <String, Object?>{'sessionId': sessionId},
    );

    return AppFailure<void>(
      FailureDetail(
        code: 'auth_session_revoked',
        developerMessage:
            'Active session was revoked remotely and removed from local store.',
        userMessage: 'Your session has ended. Please sign in again.',
        recoverable: true,
      ),
    );
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

class _SessionRefreshInFlight {
  const _SessionRefreshInFlight({
    required this.sessionId,
    required this.future,
  });

  final String sessionId;
  final Future<AppResult<String>> future;
}
