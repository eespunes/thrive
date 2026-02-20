import 'package:thrive_app/core/firebase/firebase_environment.dart';
import 'package:thrive_app/core/result/app_result.dart';

final class FirebaseDeployTargets {
  const FirebaseDeployTargets({
    required this.firestore,
    required this.functions,
  });

  final String firestore;
  final String functions;
}

abstract final class FirebaseDeployContext {
  static FirebaseDeployTargets targetsFor(ThriveEnvironment environment) {
    return _targetsByEnvironment[environment]!;
  }

  static AppResult<void> validate({
    required ThriveEnvironment environment,
    required String serviceAccountEmail,
    required FirebaseDeployTargets deployTargets,
  }) {
    final configResult = FirebaseProjectConfigRegistry.configFor(environment);
    if (configResult is AppFailure<FirebaseProjectConfig>) {
      return AppFailure<void>(configResult.detail);
    }

    final expectedServiceAccount =
        (configResult as AppSuccess<FirebaseProjectConfig>)
            .value
            .serviceAccountEmail
            .toLowerCase();
    final normalizedServiceAccount = serviceAccountEmail.trim().toLowerCase();
    if (normalizedServiceAccount != expectedServiceAccount) {
      return AppFailure<void>(
        FailureDetail(
          code: 'firebase_service_account_mismatch',
          developerMessage:
              'Service account "$serviceAccountEmail" does not match expected "$expectedServiceAccount" for ${environment.name}.',
          userMessage:
              'The app is not configured correctly. Please contact support.',
          recoverable: false,
        ),
      );
    }

    final expectedTargets = targetsFor(environment);
    final firestoreMatches =
        deployTargets.firestore == expectedTargets.firestore;
    final functionsMatches =
        deployTargets.functions == expectedTargets.functions;
    if (!firestoreMatches || !functionsMatches) {
      return AppFailure<void>(
        FailureDetail(
          code: 'firebase_deploy_target_mismatch',
          developerMessage:
              'Deploy targets mismatch for ${environment.name}. Expected firestore=${expectedTargets.firestore}, functions=${expectedTargets.functions}, got firestore=${deployTargets.firestore}, functions=${deployTargets.functions}.',
          userMessage:
              'The app is not configured correctly. Please contact support.',
          recoverable: false,
        ),
      );
    }

    return const AppSuccess<void>(null);
  }

  static const Map<ThriveEnvironment, FirebaseDeployTargets>
  _targetsByEnvironment = <ThriveEnvironment, FirebaseDeployTargets>{
    ThriveEnvironment.dev: FirebaseDeployTargets(
      firestore: 'firebase-dev-firestore',
      functions: 'firebase-dev-functions',
    ),
    ThriveEnvironment.stg: FirebaseDeployTargets(
      firestore: 'firebase-stg-firestore',
      functions: 'firebase-stg-functions',
    ),
    ThriveEnvironment.prod: FirebaseDeployTargets(
      firestore: 'firebase-prod-firestore',
      functions: 'firebase-prod-functions',
    ),
  };
}
