import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/auth/auth_session.dart';

void main() {
  test('isExpired returns false before expiry and true at expiry', () {
    final session = AuthSession(
      sessionId: 'session-1',
      userId: 'user-1',
      accessToken: 'token-1',
      refreshToken: 'refresh-1',
      expiresAt: DateTime.utc(2029, 1, 1, 0, 2, 0),
    );

    expect(session.isExpired(DateTime.utc(2029, 1, 1, 0, 1, 59)), isFalse);
    expect(session.isExpired(DateTime.utc(2029, 1, 1, 0, 2, 0)), isTrue);
  });

  test('shouldRefresh returns true when inside skew window', () {
    final session = AuthSession(
      sessionId: 'session-1',
      userId: 'user-1',
      accessToken: 'token-1',
      refreshToken: 'refresh-1',
      expiresAt: DateTime.utc(2029, 1, 1, 0, 3, 0),
    );

    expect(
      session.shouldRefresh(
        DateTime.utc(2029, 1, 1, 0, 1, 30),
        refreshSkew: const Duration(minutes: 2),
      ),
      isTrue,
    );
  });

  test('shouldRefresh returns false when outside skew window', () {
    final session = AuthSession(
      sessionId: 'session-1',
      userId: 'user-1',
      accessToken: 'token-1',
      refreshToken: 'refresh-1',
      expiresAt: DateTime.utc(2029, 1, 1, 0, 10, 0),
    );

    expect(
      session.shouldRefresh(
        DateTime.utc(2029, 1, 1, 0, 1, 0),
        refreshSkew: const Duration(minutes: 2),
      ),
      isFalse,
    );
  });

  test('shouldRefresh returns true when token is already expired', () {
    final session = AuthSession(
      sessionId: 'session-1',
      userId: 'user-1',
      accessToken: 'token-1',
      refreshToken: 'refresh-1',
      expiresAt: DateTime.utc(2029, 1, 1, 0, 2, 0),
    );

    expect(
      session.shouldRefresh(
        DateTime.utc(2029, 1, 1, 0, 2, 1),
        refreshSkew: const Duration(minutes: 2),
      ),
      isTrue,
    );
  });
}
