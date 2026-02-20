import 'package:thrive_app/core/firebase/firebase_environment.dart';
import 'package:thrive_app/core/result/app_result.dart';

final class FirebaseRuntimeSnapshot {
  const FirebaseRuntimeSnapshot({
    required this.environment,
    required this.projectId,
    required this.appId,
    required this.storageBucket,
  });

  final ThriveEnvironment environment;
  final String projectId;
  final String appId;
  final String storageBucket;
}

abstract final class FirebaseEnvironmentDriftDetector {
  static AppResult<void> detect({
    required FirebaseProjectConfig expected,
    required FirebaseRuntimeSnapshot runtime,
  }) {
    final mismatches = <String>[];

    if (runtime.environment != expected.environment) {
      mismatches.add(
        'environment expected=${expected.environment.name} actual=${runtime.environment.name}',
      );
    }
    if (runtime.projectId != expected.projectId) {
      mismatches.add(
        'projectId expected=${expected.projectId} actual=${runtime.projectId}',
      );
    }
    if (runtime.appId != expected.appId) {
      mismatches.add(
        'appId expected=${expected.appId} actual=${runtime.appId}',
      );
    }
    if (runtime.storageBucket != expected.storageBucket) {
      mismatches.add(
        'storageBucket expected=${expected.storageBucket} actual=${runtime.storageBucket}',
      );
    }

    if (mismatches.isEmpty) {
      return const AppSuccess<void>(null);
    }

    return AppFailure<void>(
      FailureDetail(
        code: 'firebase_environment_drift',
        developerMessage:
            'Firebase config drift detected for ${expected.environment.name}: ${mismatches.join('; ')}.',
        userMessage:
            'A configuration mismatch was detected. Please try again in a few minutes.',
        recoverable: false,
      ),
    );
  }
}
