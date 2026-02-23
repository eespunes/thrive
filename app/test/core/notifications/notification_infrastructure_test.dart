import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/notifications/notification_infrastructure.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('register token succeeds and emits registration signal', () async {
    final logger = InMemoryAppLogger();
    final contract = NotificationInfrastructureContract(
      pushTokenGateway: _PushTokenGatewayStub(),
      deliveryGateway: _DeliveryGatewayStub(),
      logger: logger,
    );

    final result = await contract.registerOrRefreshToken(
      token: _token(),
      isRefresh: false,
    );

    expect(result, isA<AppSuccess<void>>());
    expect(
      logger.events.map((event) => event.code),
      contains('push_token_registered'),
    );
  });

  test('refresh token fails on invalid payload', () async {
    final contract = NotificationInfrastructureContract(
      pushTokenGateway: _PushTokenGatewayStub(),
      deliveryGateway: _DeliveryGatewayStub(),
      logger: InMemoryAppLogger(),
    );

    final result = await contract.registerOrRefreshToken(
      token: DevicePushToken(
        userId: ' ',
        workspaceId: 'w-1',
        deviceId: 'd-1',
        token: 'short',
        platform: 'android',
        updatedAt: DateTime.utc(2030, 1, 1),
      ),
      isRefresh: true,
    );

    expect(result, isA<AppFailure<void>>());
    expect((result as AppFailure<void>).detail.code, 'push_token_invalid');
  });

  test('maps channel preferences and defaults missing channels to false', () {
    final contract = NotificationInfrastructureContract(
      pushTokenGateway: _PushTokenGatewayStub(),
      deliveryGateway: _DeliveryGatewayStub(),
      logger: InMemoryAppLogger(),
    );

    final result = contract.mapPreferences(
      const NotificationPreferenceUpdate(
        userId: 'u-1',
        workspaceId: 'w-1',
        preferences: <NotificationChannel, bool>{
          NotificationChannel.budgetAlerts: true,
        },
      ),
    );

    expect(result, isA<AppSuccess<Map<NotificationChannel, bool>>>());
    final mapped = (result as AppSuccess<Map<NotificationChannel, bool>>).value;
    expect(mapped[NotificationChannel.budgetAlerts], isTrue);
    expect(mapped[NotificationChannel.transactionUpdates], isFalse);
  });

  test('retries delivery on recoverable failure and succeeds', () async {
    final logger = InMemoryAppLogger();
    final contract = NotificationInfrastructureContract(
      pushTokenGateway: _PushTokenGatewayStub(),
      deliveryGateway: _DeliveryGatewaySequenceStub(
        results: <AppResult<void>>[
          AppFailure<void>(
            FailureDetail(
              code: 'notification_gateway_timeout',
              developerMessage: 'Timeout.',
              userMessage: 'Timeout',
              recoverable: true,
            ),
          ),
          const AppSuccess<void>(null),
        ],
      ),
      logger: logger,
    );

    final result = await contract.sendWithRetry(
      userId: 'u-1',
      channel: NotificationChannel.familyUpdates,
      payload: const <String, Object?>{'title': 'Update'},
    );

    expect(result, isA<AppSuccess<NotificationDeliveryDiagnostics>>());
    final diagnostics =
        (result as AppSuccess<NotificationDeliveryDiagnostics>).value;
    expect(diagnostics.attempts, 2);
    expect(
      logger.events.map((event) => event.code),
      contains('notification_delivery_attempt_failed'),
    );
    expect(
      logger.events.map((event) => event.code),
      contains('notification_delivery_succeeded'),
    );
  });

  test('fails delivery after retries are exhausted', () async {
    final contract = NotificationInfrastructureContract(
      pushTokenGateway: _PushTokenGatewayStub(),
      deliveryGateway: _DeliveryGatewaySequenceStub(
        results: <AppResult<void>>[
          AppFailure<void>(
            FailureDetail(
              code: 'notification_gateway_down',
              developerMessage: 'Gateway unavailable.',
              userMessage: 'Unavailable',
              recoverable: true,
            ),
          ),
          AppFailure<void>(
            FailureDetail(
              code: 'notification_gateway_down',
              developerMessage: 'Gateway unavailable.',
              userMessage: 'Unavailable',
              recoverable: true,
            ),
          ),
          AppFailure<void>(
            FailureDetail(
              code: 'notification_gateway_down',
              developerMessage: 'Gateway unavailable.',
              userMessage: 'Unavailable',
              recoverable: true,
            ),
          ),
        ],
      ),
      logger: InMemoryAppLogger(),
      maxDeliveryAttempts: 3,
    );

    final result = await contract.sendWithRetry(
      userId: 'u-1',
      channel: NotificationChannel.systemAnnouncements,
      payload: const <String, Object?>{'title': 'Maintenance'},
    );

    expect(result, isA<AppFailure<NotificationDeliveryDiagnostics>>());
    final detail =
        (result as AppFailure<NotificationDeliveryDiagnostics>).detail;
    expect(detail.code, 'notification_delivery_failed');
  });
}

DevicePushToken _token() {
  return DevicePushToken(
    userId: 'u-1',
    workspaceId: 'w-1',
    deviceId: 'device-1',
    token: 'fcm_token_1234567890',
    platform: 'android',
    updatedAt: DateTime.utc(2030, 1, 1),
  );
}

class _PushTokenGatewayStub implements PushTokenGateway {
  @override
  Future<AppResult<void>> refresh(DevicePushToken token) async =>
      const AppSuccess<void>(null);

  @override
  Future<AppResult<void>> register(DevicePushToken token) async =>
      const AppSuccess<void>(null);
}

class _DeliveryGatewayStub implements NotificationDeliveryGateway {
  @override
  Future<AppResult<void>> send({
    required String userId,
    required NotificationChannel channel,
    required Map<String, Object?> payload,
  }) async {
    return const AppSuccess<void>(null);
  }
}

class _DeliveryGatewaySequenceStub implements NotificationDeliveryGateway {
  _DeliveryGatewaySequenceStub({required this.results});

  final List<AppResult<void>> results;
  int _cursor = 0;

  @override
  Future<AppResult<void>> send({
    required String userId,
    required NotificationChannel channel,
    required Map<String, Object?> payload,
  }) async {
    if (_cursor >= results.length) {
      return AppFailure<void>(
        FailureDetail(
          code: 'test_gateway_exhausted',
          developerMessage: 'No more queued results in test delivery gateway.',
          userMessage: 'Unexpected test state.',
          recoverable: false,
        ),
      );
    }

    final result = results[_cursor];
    _cursor += 1;
    return result;
  }
}
