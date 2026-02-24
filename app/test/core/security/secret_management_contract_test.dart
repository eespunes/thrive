import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';
import 'package:thrive_app/core/security/secret_management_contract.dart';

void main() {
  test('secret access is granted for allowed role and scope', () {
    final contract = SecretManagementContract(logger: InMemoryAppLogger());

    final result = contract.authorizeAccess(
      descriptor: _descriptor(),
      request: SecretAccessRequest(
        secretName: 'firebase_api_key',
        environment: 'prod',
        requesterRole: 'release-bot',
        requestedAt: DateTime.utc(2030, 1, 1),
      ),
    );

    expect(result, isA<AppSuccess<void>>());
  });

  test('secret access is denied for unauthorized role', () {
    final contract = SecretManagementContract(logger: InMemoryAppLogger());

    final result = contract.authorizeAccess(
      descriptor: _descriptor(),
      request: SecretAccessRequest(
        secretName: 'firebase_api_key',
        environment: 'prod',
        requesterRole: 'guest',
        requestedAt: DateTime.utc(2030, 1, 1),
      ),
    );

    expect(result, isA<AppFailure<void>>());
    expect((result as AppFailure<void>).detail.code, 'secret_access_denied');
  });

  test('rotation executes when window is reached', () {
    final contract = SecretManagementContract(logger: InMemoryAppLogger());

    final result = contract.rotateIfDue(
      descriptor: _descriptor(
        lastRotatedAt: DateTime.utc(2029, 12, 1),
        version: 3,
      ),
      nextVersion: 4,
      now: DateTime.utc(2030, 1, 10),
    );

    expect(result, isA<AppSuccess<SecretRotationResult>>());
    final rotation = (result as AppSuccess<SecretRotationResult>).value;
    expect(rotation.rotated, isTrue);
    expect(rotation.newVersion, 4);
  });

  test('rotation remains pending before window due date', () {
    final contract = SecretManagementContract(logger: InMemoryAppLogger());

    final result = contract.rotateIfDue(
      descriptor: _descriptor(
        lastRotatedAt: DateTime.utc(2030, 1, 1),
        version: 5,
      ),
      nextVersion: 6,
      now: DateTime.utc(2030, 1, 10),
    );

    expect(result, isA<AppSuccess<SecretRotationResult>>());
    final rotation = (result as AppSuccess<SecretRotationResult>).value;
    expect(rotation.rotated, isFalse);
    expect(rotation.newVersion, 5);
  });

  test('leak response plan provides deterministic actions', () {
    final contract = SecretManagementContract(logger: InMemoryAppLogger());

    final result = contract.buildLeakResponsePlan(
      LeakIncident(
        secretName: 'firebase_api_key',
        environment: 'prod',
        detectedAt: DateTime.utc(2030, 1, 1),
        scope: 'public log exposure',
      ),
    );

    expect(result, isA<AppSuccess<LeakResponsePlan>>());
    final plan = (result as AppSuccess<LeakResponsePlan>).value;
    expect(plan.actions.length, 3);
  });
}

SecretDescriptor _descriptor({DateTime? lastRotatedAt, int version = 1}) {
  return SecretDescriptor(
    name: 'firebase_api_key',
    environment: 'prod',
    version: version,
    lastRotatedAt: lastRotatedAt ?? DateTime.utc(2029, 10, 1),
    rotationWindowDays: 30,
    allowedRoles: const <String>{'release-bot', 'sre'},
  );
}
