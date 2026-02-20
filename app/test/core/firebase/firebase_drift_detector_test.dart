import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/firebase/firebase_drift_detector.dart';
import 'package:thrive_app/core/firebase/firebase_environment.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test(
    'returns success when runtime config matches expected environment config',
    () {
      final expected =
          (FirebaseProjectConfigRegistry.configFor(ThriveEnvironment.dev)
                  as AppSuccess<FirebaseProjectConfig>)
              .value;

      final result = FirebaseEnvironmentDriftDetector.detect(
        expected: expected,
        runtime: FirebaseRuntimeSnapshot(
          environment: ThriveEnvironment.dev,
          projectId: expected.projectId,
          appId: expected.appId,
          storageBucket: expected.storageBucket,
        ),
      );

      expect(result, isA<AppSuccess<void>>());
    },
  );

  test('returns failure with deterministic code when drift is detected', () {
    final expected =
        (FirebaseProjectConfigRegistry.configFor(ThriveEnvironment.stg)
                as AppSuccess<FirebaseProjectConfig>)
            .value;

    final result = FirebaseEnvironmentDriftDetector.detect(
      expected: expected,
      runtime: const FirebaseRuntimeSnapshot(
        environment: ThriveEnvironment.prod,
        projectId: 'thrive-prod',
        appId: '1:999999999999:android:wrong-app',
        storageBucket: 'wrong-bucket.appspot.com',
      ),
    );

    expect(result, isA<AppFailure<void>>());
    final detail = (result as AppFailure<void>).detail;
    expect(detail.code, 'firebase_environment_drift');
    expect(detail.developerMessage, contains('environment'));
    expect(detail.developerMessage, contains('projectId'));
    expect(detail.developerMessage, contains('appId'));
    expect(detail.developerMessage, contains('storageBucket'));
  });
}
