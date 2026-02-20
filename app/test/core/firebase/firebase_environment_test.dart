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

  test('parses stg aliases', () {
    final result = FirebaseEnvironmentLoader.load(rawValue: 'staging');

    expect(result, isA<AppSuccess<ThriveEnvironment>>());
    final value = (result as AppSuccess<ThriveEnvironment>).value;
    expect(value, ThriveEnvironment.stg);
  });

  test('parses prod aliases', () {
    final result = FirebaseEnvironmentLoader.load(rawValue: 'production');

    expect(result, isA<AppSuccess<ThriveEnvironment>>());
    final value = (result as AppSuccess<ThriveEnvironment>).value;
    expect(value, ThriveEnvironment.prod);
  });

  test('returns failure when THRIVE_ENV is invalid', () {
    final result = FirebaseEnvironmentLoader.load(rawValue: 'qa');

    expect(result, isA<AppFailure<ThriveEnvironment>>());
    final detail = (result as AppFailure<ThriveEnvironment>).detail;
    expect(detail.code, 'firebase_environment_invalid');
  });

  test('returns deterministic project config by environment', () {
    final result = FirebaseProjectConfigRegistry.configFor(
      ThriveEnvironment.stg,
    );

    expect(result, isA<AppSuccess<FirebaseProjectConfig>>());
    final config = (result as AppSuccess<FirebaseProjectConfig>).value;
    expect(config.environment, ThriveEnvironment.stg);
    expect(config.projectId, 'thrive-stg');
    expect(
      config.serviceAccountEmail,
      'github-actions-stg@thrive-stg.iam.gserviceaccount.com',
    );
  });
}
