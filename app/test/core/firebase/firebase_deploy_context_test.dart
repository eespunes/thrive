import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/firebase/firebase_deploy_context.dart';
import 'package:thrive_app/core/firebase/firebase_environment.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('returns deterministic targets for each environment', () {
    final devTargets = FirebaseDeployContext.targetsFor(ThriveEnvironment.dev);
    final stgTargets = FirebaseDeployContext.targetsFor(ThriveEnvironment.stg);
    final prodTargets = FirebaseDeployContext.targetsFor(
      ThriveEnvironment.prod,
    );

    expect(devTargets.firestore, 'firebase-dev-firestore');
    expect(stgTargets.functions, 'firebase-stg-functions');
    expect(prodTargets.firestore, 'firebase-prod-firestore');
  });

  test('validates correct service account and deploy targets', () {
    final result = FirebaseDeployContext.validate(
      environment: ThriveEnvironment.dev,
      serviceAccountEmail:
          'github-actions-dev@thrive-dev.iam.gserviceaccount.com',
      deployTargets: const FirebaseDeployTargets(
        firestore: 'firebase-dev-firestore',
        functions: 'firebase-dev-functions',
      ),
    );

    expect(result, isA<AppSuccess<void>>());
  });

  test('fails when service account does not match selected environment', () {
    final result = FirebaseDeployContext.validate(
      environment: ThriveEnvironment.stg,
      serviceAccountEmail:
          'github-actions-prod@thrive-prod.iam.gserviceaccount.com',
      deployTargets: const FirebaseDeployTargets(
        firestore: 'firebase-stg-firestore',
        functions: 'firebase-stg-functions',
      ),
    );

    expect(result, isA<AppFailure<void>>());
    final detail = (result as AppFailure<void>).detail;
    expect(detail.code, 'firebase_service_account_mismatch');
  });

  test('fails when deploy targets do not match selected environment', () {
    final result = FirebaseDeployContext.validate(
      environment: ThriveEnvironment.prod,
      serviceAccountEmail:
          'github-actions-prod@thrive-prod.iam.gserviceaccount.com',
      deployTargets: const FirebaseDeployTargets(
        firestore: 'firebase-stg-firestore',
        functions: 'firebase-stg-functions',
      ),
    );

    expect(result, isA<AppFailure<void>>());
    final detail = (result as AppFailure<void>).detail;
    expect(detail.code, 'firebase_deploy_target_mismatch');
  });
}
