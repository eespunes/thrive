import 'dart:async';
import 'dart:io';

import 'package:thrive_app/core/forms/error_mapping.dart';
import 'package:thrive_app/core/result/app_result.dart';

class EmailSignInSuccess {
  const EmailSignInSuccess();
}

abstract interface class EmailSignInRepository {
  Future<AppResult<EmailSignInSuccess>> signIn({
    required String email,
    required String password,
  });
}

class DemoEmailSignInRepository implements EmailSignInRepository {
  const DemoEmailSignInRepository();

  @override
  Future<AppResult<EmailSignInSuccess>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _simulateBackendCall(email: email, password: password);
      return const AppSuccess<EmailSignInSuccess>(EmailSignInSuccess());
    } catch (error) {
      return AppFailure<EmailSignInSuccess>(
        ThriveErrorMapper.map(error, operation: 'email_sign_in'),
      );
    }
  }

  Future<void> _simulateBackendCall({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final normalizedEmail = email.toLowerCase();
    if (normalizedEmail.contains('timeout')) {
      throw TimeoutException('Simulated timeout in email sign-in');
    }
    if (normalizedEmail.contains('network')) {
      throw const SocketException('Simulated offline mode');
    }
    if (normalizedEmail.contains('server')) {
      throw const BackendException(
        statusCode: 503,
        message: 'Simulated backend outage',
      );
    }
    if (password != 'thrive123') {
      throw const BackendException(
        statusCode: 401,
        message: 'Invalid credentials',
      );
    }
  }
}
