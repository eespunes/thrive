import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

class AnalyticsEventDefinition {
  const AnalyticsEventDefinition({
    required this.name,
    required this.version,
    required this.requiredParams,
    required this.optionalParams,
    this.deprecated = false,
  });

  final String name;
  final int version;
  final Set<String> requiredParams;
  final Set<String> optionalParams;
  final bool deprecated;
}

class AnalyticsEvent {
  const AnalyticsEvent({
    required this.name,
    required this.version,
    required this.params,
    required this.emittedAt,
  });

  final String name;
  final int version;
  final Map<String, Object?> params;
  final DateTime emittedAt;
}

abstract interface class AnalyticsGateway {
  Future<AppResult<void>> send(AnalyticsEvent event);
}

class AnalyticsEventTaxonomyContract {
  AnalyticsEventTaxonomyContract({
    required AnalyticsGateway gateway,
    required AppLogger logger,
  }) : _gateway = gateway,
       _logger = logger;

  final AnalyticsGateway _gateway;
  final AppLogger _logger;
  final Map<String, Map<int, AnalyticsEventDefinition>> _registry =
      <String, Map<int, AnalyticsEventDefinition>>{};

  AppResult<void> registerDefinition(AnalyticsEventDefinition definition) {
    final namingValidation = _validateEventName(definition.name);
    if (namingValidation is AppFailure<void>) {
      return namingValidation;
    }

    if (definition.version <= 0) {
      return _failure(
        code: 'analytics_definition_version_invalid',
        developerMessage: 'Event definition version must be greater than zero.',
        userMessage: 'Could not update analytics configuration right now.',
      );
    }

    final versions = _registry.putIfAbsent(
      definition.name,
      () => <int, AnalyticsEventDefinition>{},
    );
    if (versions.containsKey(definition.version)) {
      return _failure(
        code: 'analytics_definition_duplicate',
        developerMessage:
            'Definition already exists for ${definition.name} v${definition.version}.',
        userMessage: 'Could not update analytics configuration right now.',
      );
    }

    versions[definition.version] = definition;
    _logger.info(
      code: 'analytics_definition_registered',
      message: 'Analytics event definition registered',
      metadata: <String, Object?>{
        'name': definition.name,
        'version': definition.version,
        'deprecated': definition.deprecated,
      },
    );
    return const AppSuccess<void>(null);
  }

  Future<AppResult<void>> emit(AnalyticsEvent event) async {
    final validation = validate(event);
    if (validation is AppFailure<void>) {
      return validation;
    }

    final sendResult = await _gateway.send(event);
    if (sendResult is AppFailure<void>) {
      _logger.warning(
        code: 'analytics_emit_failed',
        message: sendResult.detail.developerMessage,
        metadata: <String, Object?>{
          'name': event.name,
          'version': event.version,
          'failureCode': sendResult.detail.code,
        },
      );
      return sendResult;
    }

    _logger.info(
      code: 'analytics_event_emitted',
      message: 'Analytics event emitted successfully',
      metadata: <String, Object?>{'name': event.name, 'version': event.version},
    );
    return const AppSuccess<void>(null);
  }

  AppResult<void> validate(AnalyticsEvent event) {
    final namingValidation = _validateEventName(event.name);
    if (namingValidation is AppFailure<void>) {
      return namingValidation;
    }

    final definition = _registry[event.name]?[event.version];
    if (definition == null) {
      return _failure(
        code: 'analytics_definition_not_found',
        developerMessage:
            'No analytics definition found for ${event.name} v${event.version}.',
        userMessage: 'Could not record analytics for this action.',
      );
    }

    if (definition.deprecated) {
      return _failure(
        code: 'analytics_definition_deprecated',
        developerMessage:
            'Definition ${event.name} v${event.version} is deprecated.',
        userMessage: 'Could not record analytics for this action.',
      );
    }

    final allowedKeys = <String>{
      ...definition.requiredParams,
      ...definition.optionalParams,
    };

    for (final requiredKey in definition.requiredParams) {
      if (!event.params.containsKey(requiredKey)) {
        return _failure(
          code: 'analytics_param_required_missing',
          developerMessage:
              'Required parameter "$requiredKey" is missing for ${event.name}.',
          userMessage: 'Could not record analytics for this action.',
        );
      }
    }

    for (final key in event.params.keys) {
      if (!allowedKeys.contains(key)) {
        return _failure(
          code: 'analytics_param_unknown',
          developerMessage:
              'Parameter "$key" is not allowed for ${event.name} v${event.version}.',
          userMessage: 'Could not record analytics for this action.',
        );
      }

      final piiResult = _ensureValueIsPrivacySafe(event.params[key]);
      if (piiResult is AppFailure<void>) {
        return piiResult;
      }
    }

    return const AppSuccess<void>(null);
  }

  AppResult<void> _validateEventName(String name) {
    final normalized = name.trim();
    final eventNamePattern = RegExp(r'^[a-z][a-z0-9_]{2,63}$');
    if (!eventNamePattern.hasMatch(normalized)) {
      return _failure(
        code: 'analytics_event_name_invalid',
        developerMessage: 'Event name "$name" does not match naming contract.',
        userMessage: 'Could not record analytics for this action.',
      );
    }

    return const AppSuccess<void>(null);
  }

  AppResult<void> _ensureValueIsPrivacySafe(Object? value) {
    if (value is! String) {
      return const AppSuccess<void>(null);
    }

    final emailPattern = RegExp(
      r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
    );
    final phonePattern = RegExp(r'\+?\d[\d\s().-]{7,}\d');

    if (emailPattern.hasMatch(value) || phonePattern.hasMatch(value)) {
      return _failure(
        code: 'analytics_payload_pii_detected',
        developerMessage: 'Potential PII detected in analytics payload value.',
        userMessage: 'Could not record analytics for this action.',
      );
    }

    return const AppSuccess<void>(null);
  }

  AppFailure<void> _failure({
    required String code,
    required String developerMessage,
    required String userMessage,
  }) {
    _logger.warning(code: code, message: developerMessage);
    return AppFailure<void>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: userMessage,
        recoverable: true,
      ),
    );
  }
}
