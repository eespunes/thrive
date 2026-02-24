import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

class SecretDescriptor {
  const SecretDescriptor({
    required this.name,
    required this.environment,
    required this.version,
    required this.lastRotatedAt,
    required this.rotationWindowDays,
    required this.allowedRoles,
  });

  final String name;
  final String environment;
  final int version;
  final DateTime lastRotatedAt;
  final int rotationWindowDays;
  final Set<String> allowedRoles;
}

class SecretAccessRequest {
  const SecretAccessRequest({
    required this.secretName,
    required this.environment,
    required this.requesterRole,
    required this.requestedAt,
  });

  final String secretName;
  final String environment;
  final String requesterRole;
  final DateTime requestedAt;
}

class SecretRotationResult {
  const SecretRotationResult({required this.rotated, required this.newVersion});

  final bool rotated;
  final int newVersion;
}

class LeakIncident {
  const LeakIncident({
    required this.secretName,
    required this.environment,
    required this.detectedAt,
    required this.scope,
  });

  final String secretName;
  final String environment;
  final DateTime detectedAt;
  final String scope;
}

class LeakResponsePlan {
  const LeakResponsePlan({required this.actions});

  final List<String> actions;
}

class SecretManagementContract {
  SecretManagementContract({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  AppResult<void> authorizeAccess({
    required SecretDescriptor descriptor,
    required SecretAccessRequest request,
  }) {
    if (descriptor.name != request.secretName ||
        descriptor.environment != request.environment) {
      return _failure(
        code: 'secret_access_scope_mismatch',
        developerMessage: 'Secret name/environment mismatch in access request.',
        userMessage: 'Secret access is not allowed for this request.',
      );
    }

    if (!descriptor.allowedRoles.contains(request.requesterRole)) {
      return _failure(
        code: 'secret_access_denied',
        developerMessage:
            'Role ${request.requesterRole} is not allowed for secret ${descriptor.name}.',
        userMessage: 'You are not authorized to access this secret.',
      );
    }

    _logger.info(
      code: 'secret_access_granted',
      message: 'Secret access granted by least-privilege policy',
      metadata: <String, Object?>{
        'secretName': descriptor.name,
        'environment': descriptor.environment,
        'requesterRole': request.requesterRole,
      },
    );
    return const AppSuccess<void>(null);
  }

  AppResult<SecretRotationResult> rotateIfDue({
    required SecretDescriptor descriptor,
    required int nextVersion,
    required DateTime now,
  }) {
    if (descriptor.rotationWindowDays <= 0 ||
        descriptor.version <= 0 ||
        nextVersion <= 0) {
      return AppFailure<SecretRotationResult>(
        FailureDetail(
          code: 'secret_rotation_config_invalid',
          developerMessage:
              'Rotation configuration/version values are invalid.',
          userMessage: 'Could not process key rotation right now.',
          recoverable: true,
        ),
      );
    }

    final dueAt = descriptor.lastRotatedAt.add(
      Duration(days: descriptor.rotationWindowDays),
    );
    if (now.isBefore(dueAt)) {
      _logger.info(
        code: 'secret_rotation_not_due',
        message: 'Secret rotation window has not been reached',
        metadata: <String, Object?>{
          'secretName': descriptor.name,
          'dueAt': dueAt.toIso8601String(),
        },
      );
      return AppSuccess<SecretRotationResult>(
        SecretRotationResult(rotated: false, newVersion: descriptor.version),
      );
    }

    if (nextVersion <= descriptor.version) {
      return AppFailure<SecretRotationResult>(
        FailureDetail(
          code: 'secret_rotation_version_invalid',
          developerMessage:
              'Next version $nextVersion must be greater than current ${descriptor.version}.',
          userMessage: 'Could not process key rotation right now.',
          recoverable: true,
        ),
      );
    }

    _logger.warning(
      code: 'secret_rotation_completed',
      message: 'Secret key rotation executed',
      metadata: <String, Object?>{
        'secretName': descriptor.name,
        'environment': descriptor.environment,
        'previousVersion': descriptor.version,
        'newVersion': nextVersion,
      },
    );
    return AppSuccess<SecretRotationResult>(
      SecretRotationResult(rotated: true, newVersion: nextVersion),
    );
  }

  AppResult<LeakResponsePlan> buildLeakResponsePlan(LeakIncident incident) {
    if (incident.secretName.trim().isEmpty ||
        incident.environment.trim().isEmpty ||
        incident.scope.trim().isEmpty) {
      return AppFailure<LeakResponsePlan>(
        FailureDetail(
          code: 'secret_leak_incident_invalid',
          developerMessage: 'Leak incident fields cannot be empty.',
          userMessage: 'Could not build leak response plan right now.',
          recoverable: true,
        ),
      );
    }

    final plan = LeakResponsePlan(
      actions: <String>[
        'Revoke impacted credential immediately',
        'Rotate secret to new version and redeploy dependent services',
        'Audit access logs and notify incident owner',
      ],
    );

    _logger.warning(
      code: 'secret_leak_response_plan_created',
      message: 'Leak response process initialized',
      metadata: <String, Object?>{
        'secretName': incident.secretName,
        'environment': incident.environment,
        'scope': incident.scope,
      },
    );

    return AppSuccess<LeakResponsePlan>(plan);
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
