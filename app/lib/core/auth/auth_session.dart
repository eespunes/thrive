class AuthSession {
  const AuthSession({
    required this.sessionId,
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String sessionId;
  final String userId;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool isExpired(DateTime now) {
    return !expiresAt.isAfter(now);
  }

  bool shouldRefresh(
    DateTime now, {
    Duration refreshSkew = const Duration(minutes: 2),
  }) {
    return expiresAt.isBefore(now.add(refreshSkew)) || isExpired(now);
  }
}
