import 'dart:async';
import 'dart:io';

import 'package:thrive_app/core/result/app_result.dart';

class BackendException implements Exception {
  const BackendException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;
}

abstract final class ThriveErrorMapper {
  static FailureDetail map(Object error, {required String operation}) {
    if (error is TimeoutException) {
      return const FailureDetail(
        code: 'network_timeout',
        developerMessage: 'Request timed out',
        userMessage:
            'This action is taking too long. Check your connection and try again.',
        recoverable: true,
      );
    }

    if (error is SocketException) {
      return const FailureDetail(
        code: 'network_unavailable',
        developerMessage: 'Device has no network connectivity',
        userMessage:
            'You are offline. When you are back online, retry the action.',
        recoverable: true,
      );
    }

    if (error is BackendException) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return const FailureDetail(
          code: 'auth_invalid_credentials',
          developerMessage: 'Backend rejected credentials',
          userMessage: 'The email or password is incorrect.',
          recoverable: true,
        );
      }

      if (error.statusCode >= 500) {
        return const FailureDetail(
          code: 'backend_unavailable',
          developerMessage: 'Backend service is unavailable',
          userMessage:
              'Our services are currently unavailable. Please try again in a few minutes.',
          recoverable: true,
        );
      }

      return FailureDetail(
        code: 'backend_request_failed',
        developerMessage:
            'Request failed with status ${error.statusCode}: ${error.message}',
        userMessage: 'We could not complete the requested action.',
        recoverable: true,
      );
    }

    return FailureDetail(
      code: 'unexpected_error',
      developerMessage: 'Unexpected error in operation $operation: $error',
      userMessage:
          'An unexpected error occurred. Please try again in a few minutes.',
      recoverable: true,
    );
  }
}
