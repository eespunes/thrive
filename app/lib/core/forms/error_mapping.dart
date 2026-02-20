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
            'La operacion esta tardando demasiado. Comprueba tu conexion e intentalo de nuevo.',
        recoverable: true,
      );
    }

    if (error is SocketException) {
      return const FailureDetail(
        code: 'network_unavailable',
        developerMessage: 'Device has no network connectivity',
        userMessage:
            'No tienes conexion a internet. Cuando vuelvas a estar online, reintenta la accion.',
        recoverable: true,
      );
    }

    if (error is BackendException) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return const FailureDetail(
          code: 'auth_invalid_credentials',
          developerMessage: 'Backend rejected credentials',
          userMessage: 'El email o la contrasena no son correctos.',
          recoverable: true,
        );
      }

      if (error.statusCode >= 500) {
        return const FailureDetail(
          code: 'backend_unavailable',
          developerMessage: 'Backend service is unavailable',
          userMessage:
              'Nuestros servicios no estan disponibles en este momento. Prueba de nuevo en unos minutos.',
          recoverable: true,
        );
      }

      return FailureDetail(
        code: 'backend_request_failed',
        developerMessage:
            'Request failed with status ${error.statusCode}: ${error.message}',
        userMessage: 'No pudimos completar la operacion solicitada.',
        recoverable: true,
      );
    }

    return FailureDetail(
      code: 'unexpected_error',
      developerMessage: 'Unexpected error in operation $operation: $error',
      userMessage:
          'Se produjo un error inesperado. Intenta nuevamente dentro de unos minutos.',
      recoverable: true,
    );
  }
}
