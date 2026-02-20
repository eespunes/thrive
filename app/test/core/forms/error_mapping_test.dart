import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/forms/error_mapping.dart';

void main() {
  test('maps timeout to network_timeout', () {
    final detail = ThriveErrorMapper.map(
      TimeoutException('timeout'),
      operation: 'test',
    );

    expect(detail.code, 'network_timeout');
    expect(detail.recoverable, isTrue);
  });

  test('maps socket error to network_unavailable', () {
    final detail = ThriveErrorMapper.map(
      const SocketException('offline'),
      operation: 'test',
    );

    expect(detail.code, 'network_unavailable');
  });

  test('maps backend 401 to auth_invalid_credentials', () {
    final detail = ThriveErrorMapper.map(
      const BackendException(statusCode: 401, message: 'invalid'),
      operation: 'test',
    );

    expect(detail.code, 'auth_invalid_credentials');
  });

  test('maps backend 403 to auth_insufficient_permissions', () {
    final detail = ThriveErrorMapper.map(
      const BackendException(statusCode: 403, message: 'forbidden'),
      operation: 'test',
    );

    expect(detail.code, 'auth_insufficient_permissions');
  });

  test('maps backend 503 to backend_unavailable', () {
    final detail = ThriveErrorMapper.map(
      const BackendException(statusCode: 503, message: 'down'),
      operation: 'test',
    );

    expect(detail.code, 'backend_unavailable');
  });

  test('maps other backend 4xx errors to backend_request_failed', () {
    final detail = ThriveErrorMapper.map(
      const BackendException(statusCode: 404, message: 'not found'),
      operation: 'test',
    );

    expect(detail.code, 'backend_request_failed');
  });

  test('maps unexpected exception to unexpected_error', () {
    final detail = ThriveErrorMapper.map(
      Exception('unexpected'),
      operation: 'test',
    );

    expect(detail.code, 'unexpected_error');
  });
}
