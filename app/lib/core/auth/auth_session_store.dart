import 'package:thrive_app/core/auth/auth_session.dart';
import 'package:thrive_app/core/result/app_result.dart';

abstract interface class AuthSessionStore {
  Future<AppResult<AuthSession?>> read();
  Future<AppResult<void>> write(AuthSession session);
  Future<AppResult<void>> clear();
}

class InMemoryAuthSessionStore implements AuthSessionStore {
  AuthSession? _session;

  @override
  Future<AppResult<void>> clear() async {
    _session = null;
    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<AuthSession?>> read() async {
    return AppSuccess<AuthSession?>(_session);
  }

  @override
  Future<AppResult<void>> write(AuthSession session) async {
    _session = session;
    return const AppSuccess<void>(null);
  }
}
