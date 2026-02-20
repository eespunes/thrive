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

  test('maps backend 503 to backend_unavailable', () {
    final detail = ThriveErrorMapper.map(
      const BackendException(statusCode: 503, message: 'down'),
      operation: 'test',
    );

    expect(detail.code, 'backend_unavailable');
  });
}
