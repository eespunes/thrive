import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

enum NotificationChannel {
  budgetAlerts,
  transactionUpdates,
  familyUpdates,
  systemAnnouncements,
}

class DevicePushToken {
  const DevicePushToken({
    required this.userId,
    required this.workspaceId,
    required this.deviceId,
    required this.token,
    required this.platform,
    required this.updatedAt,
  });

  final String userId;
  final String workspaceId;
  final String deviceId;
  final String token;
  final String platform;
  final DateTime updatedAt;
}

class NotificationPreferenceUpdate {
  const NotificationPreferenceUpdate({
    required this.userId,
    required this.workspaceId,
    required this.preferences,
  });

  final String userId;
  final String workspaceId;
  final Map<NotificationChannel, bool> preferences;
}

class NotificationDeliveryDiagnostics {
  const NotificationDeliveryDiagnostics({
    required this.attempts,
    required this.succeeded,
    this.lastFailureCode,
  });

  final int attempts;
  final bool succeeded;
  final String? lastFailureCode;
}

abstract interface class PushTokenGateway {
  Future<AppResult<void>> register(DevicePushToken token);

  Future<AppResult<void>> refresh(DevicePushToken token);
}

abstract interface class NotificationDeliveryGateway {
  Future<AppResult<void>> send({
    required String userId,
    required NotificationChannel channel,
    required Map<String, Object?> payload,
  });
}

class NotificationInfrastructureContract {
  NotificationInfrastructureContract({
    required PushTokenGateway pushTokenGateway,
    required NotificationDeliveryGateway deliveryGateway,
    required AppLogger logger,
    int maxDeliveryAttempts = 3,
  }) : _pushTokenGateway = pushTokenGateway,
       _deliveryGateway = deliveryGateway,
       _logger = logger,
       _maxDeliveryAttempts = maxDeliveryAttempts;

  final PushTokenGateway _pushTokenGateway;
  final NotificationDeliveryGateway _deliveryGateway;
  final AppLogger _logger;
  final int _maxDeliveryAttempts;

  Future<AppResult<void>> registerOrRefreshToken({
    required DevicePushToken token,
    required bool isRefresh,
  }) async {
    final validation = _validateToken(token);
    if (validation is AppFailure<void>) {
      return validation;
    }

    final result = isRefresh
        ? await _pushTokenGateway.refresh(token)
        : await _pushTokenGateway.register(token);

    if (result is AppFailure<void>) {
      _logger.warning(
        code: 'notification_token_sync_failed',
        message: result.detail.developerMessage,
        metadata: <String, Object?>{
          'userId': token.userId,
          'workspaceId': token.workspaceId,
          'deviceId': token.deviceId,
          'isRefresh': isRefresh,
          'failureCode': result.detail.code,
        },
      );
      return result;
    }

    _logger.info(
      code: isRefresh ? 'push_token_refreshed' : 'push_token_registered',
      message: isRefresh
          ? 'Device push token refreshed'
          : 'Device push token registered',
      metadata: <String, Object?>{
        'userId': token.userId,
        'workspaceId': token.workspaceId,
        'deviceId': token.deviceId,
        'platform': token.platform,
      },
    );
    return const AppSuccess<void>(null);
  }

  AppResult<Map<NotificationChannel, bool>> mapPreferences(
    NotificationPreferenceUpdate update,
  ) {
    if (update.userId.trim().isEmpty || update.workspaceId.trim().isEmpty) {
      return AppFailure<Map<NotificationChannel, bool>>(
        FailureDetail(
          code: 'notification_preference_identity_invalid',
          developerMessage: 'userId/workspaceId cannot be empty.',
          userMessage: 'Could not update notification settings right now.',
          recoverable: true,
        ),
      );
    }

    if (update.preferences.isEmpty) {
      return AppFailure<Map<NotificationChannel, bool>>(
        FailureDetail(
          code: 'notification_preferences_missing',
          developerMessage: 'At least one channel preference must be provided.',
          userMessage:
              'Choose at least one notification preference to continue.',
          recoverable: true,
        ),
      );
    }

    final mapped = <NotificationChannel, bool>{
      for (final channel in NotificationChannel.values)
        channel: update.preferences[channel] ?? false,
    };

    _logger.info(
      code: 'notification_preferences_updated',
      message: 'Notification preferences mapped and validated',
      metadata: <String, Object?>{
        'userId': update.userId,
        'workspaceId': update.workspaceId,
        'enabledChannels': mapped.entries.where((entry) => entry.value).length,
      },
    );

    return AppSuccess<Map<NotificationChannel, bool>>(mapped);
  }

  Future<AppResult<NotificationDeliveryDiagnostics>> sendWithRetry({
    required String userId,
    required NotificationChannel channel,
    required Map<String, Object?> payload,
  }) async {
    if (userId.trim().isEmpty) {
      return _deliveryFailure(
        code: 'notification_user_invalid',
        developerMessage: 'userId cannot be empty when sending notification.',
        userMessage: 'Could not send notification right now.',
      );
    }

    if (payload.isEmpty) {
      return _deliveryFailure(
        code: 'notification_payload_invalid',
        developerMessage: 'Notification payload cannot be empty.',
        userMessage: 'Could not send notification right now.',
      );
    }

    FailureDetail? lastFailure;

    for (var attempt = 1; attempt <= _maxDeliveryAttempts; attempt += 1) {
      final result = await _deliveryGateway.send(
        userId: userId,
        channel: channel,
        payload: payload,
      );

      if (result is AppSuccess<void>) {
        _logger.info(
          code: 'notification_delivery_succeeded',
          message: 'Notification delivered successfully',
          metadata: <String, Object?>{
            'userId': userId,
            'channel': channel.name,
            'attempt': attempt,
          },
        );
        return AppSuccess<NotificationDeliveryDiagnostics>(
          NotificationDeliveryDiagnostics(attempts: attempt, succeeded: true),
        );
      }

      lastFailure = (result as AppFailure<void>).detail;
      _logger.warning(
        code: 'notification_delivery_attempt_failed',
        message: lastFailure.developerMessage,
        metadata: <String, Object?>{
          'userId': userId,
          'channel': channel.name,
          'attempt': attempt,
          'failureCode': lastFailure.code,
        },
      );

      if (!lastFailure.recoverable) {
        break;
      }
    }

    _logger.warning(
      code: 'notification_delivery_failed',
      message: 'Notification delivery exhausted retry attempts.',
      metadata: <String, Object?>{
        'userId': userId,
        'channel': channel.name,
        'maxAttempts': _maxDeliveryAttempts,
        'lastFailureCode': lastFailure?.code,
      },
    );

    return _deliveryFailure(
      code: 'notification_delivery_failed',
      developerMessage:
          'Notification delivery failed after $_maxDeliveryAttempts attempts.',
      userMessage: 'Notification could not be sent. Please retry later.',
    );
  }

  AppResult<void> _validateToken(DevicePushToken token) {
    if (token.userId.trim().isEmpty ||
        token.workspaceId.trim().isEmpty ||
        token.deviceId.trim().isEmpty ||
        token.platform.trim().isEmpty ||
        token.token.trim().length < 10) {
      _logger.warning(
        code: 'push_token_invalid',
        message: 'Push token registration payload is invalid.',
      );
      return AppFailure<void>(
        FailureDetail(
          code: 'push_token_invalid',
          developerMessage:
              'Token payload must include userId/workspaceId/deviceId/platform and token length >= 10.',
          userMessage: 'Could not enable notifications on this device.',
          recoverable: true,
        ),
      );
    }

    return const AppSuccess<void>(null);
  }

  AppFailure<NotificationDeliveryDiagnostics> _deliveryFailure({
    required String code,
    required String developerMessage,
    required String userMessage,
  }) {
    return AppFailure<NotificationDeliveryDiagnostics>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: userMessage,
        recoverable: true,
      ),
    );
  }
}
