import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/firebase/firebase_environment.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('defaults to dev when THRIVE_ENV is empty', () {
    final result = FirebaseEnvironmentLoader.load(rawValue: '');

    expect(result, isA<AppSuccess<ThriveEnvironment>>());
    final value = (result as AppSuccess<ThriveEnvironment>).value;
    expect(value, ThriveEnvironment.dev);
  });

  test('parses dev aliases', () {
    const aliases = <String>['dev', 'development'];
    for (final alias in aliases) {
      final result = FirebaseEnvironmentLoader.load(rawValue: alias);

      expect(result, isA<AppSuccess<ThriveEnvironment>>());
      final value = (result as AppSuccess<ThriveEnvironment>).value;
      expect(value, ThriveEnvironment.dev);
    }
  });

  test('parses stg aliases', () {
    const aliases = <String>['stg', 'stage', 'staging'];
    for (final alias in aliases) {
      final result = FirebaseEnvironmentLoader.load(rawValue: alias);

      expect(result, isA<AppSuccess<ThriveEnvironment>>());
      final value = (result as AppSuccess<ThriveEnvironment>).value;
      expect(value, ThriveEnvironment.stg);
    }
  });

  test('parses prod aliases', () {
    const aliases = <String>['prod', 'production'];
    for (final alias in aliases) {
      final result = FirebaseEnvironmentLoader.load(rawValue: alias);

      expect(result, isA<AppSuccess<ThriveEnvironment>>());
      final value = (result as AppSuccess<ThriveEnvironment>).value;
      expect(value, ThriveEnvironment.prod);
    }
  });

  test('returns failure when THRIVE_ENV is invalid', () {
    final result = FirebaseEnvironmentLoader.load(rawValue: 'qa');

    expect(result, isA<AppFailure<ThriveEnvironment>>());
    final detail = (result as AppFailure<ThriveEnvironment>).detail;
    expect(detail.code, 'firebase_environment_invalid');
  });

  test('returns deterministic project config by environment', () {
    final cases = <({ThriveEnvironment environment, String projectId})>[
      (environment: ThriveEnvironment.dev, projectId: 'thrive-dev'),
      (environment: ThriveEnvironment.stg, projectId: 'thrive-stg'),
      (environment: ThriveEnvironment.prod, projectId: 'thrive-prod'),
    ];

    for (final item in cases) {
      final result = FirebaseProjectConfigRegistry.configFor(item.environment);

      expect(result, isA<AppSuccess<FirebaseProjectConfig>>());
      final config = (result as AppSuccess<FirebaseProjectConfig>).value;
      expect(config.environment, item.environment);
      expect(config.projectId, item.projectId);
      expect(config.serviceAccountEmail, contains(item.projectId));
    }
  });

  test('returns config for every declared ThriveEnvironment value', () {
    for (final environment in ThriveEnvironment.values) {
      final result = FirebaseProjectConfigRegistry.configFor(environment);
      expect(result, isA<AppSuccess<FirebaseProjectConfig>>());
    }
  });
}
