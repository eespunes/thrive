import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/release/ci_cd_release_contract.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('automated workflow passes when build/test/analysis are green', () {
    final contract = CiCdReleaseContract(logger: InMemoryAppLogger());

    final result = contract.validateAutomatedWorkflow(
      const BuildWorkflowSnapshot(
        commitSha: 'abc123456',
        testsPassed: true,
        analysisPassed: true,
        artifactsGenerated: true,
      ),
    );

    expect(result, isA<AppSuccess<void>>());
  });

  test('signing and promotion validation rejects invalid track', () {
    final contract = CiCdReleaseContract(logger: InMemoryAppLogger());

    final result = contract.validateSigningPromotion(
      const SigningPromotionRequest(
        artifactId: 'apk-1',
        track: 'preview',
        signingKeyVersion: 1,
        checksum: 'abcdef1234',
      ),
    );

    expect(result, isA<AppFailure<void>>());
    expect(
      (result as AppFailure<void>).detail.code,
      'cicd_signing_promotion_invalid',
    );
  });

  test('rollout requires rollback when issue reported', () {
    final contract = CiCdReleaseContract(logger: InMemoryAppLogger());

    final result = contract.evaluateRollout(
      const RolloutSnapshot(
        releaseId: 'rel-1',
        currentPercentage: 25,
        previousPercentage: 10,
        issueReported: true,
      ),
    );

    expect(result, isA<AppSuccess<RollbackDecision>>());
    final decision = (result as AppSuccess<RollbackDecision>).value;
    expect(decision.shouldRollback, isTrue);
    expect(decision.reason, 'production_issue_reported');
  });

  test('rollout requires rollback when rollout percentage regresses', () {
    final contract = CiCdReleaseContract(logger: InMemoryAppLogger());

    final result = contract.evaluateRollout(
      const RolloutSnapshot(
        releaseId: 'rel-2',
        currentPercentage: 20,
        previousPercentage: 30,
        issueReported: false,
      ),
    );

    expect(result, isA<AppSuccess<RollbackDecision>>());
    final decision = (result as AppSuccess<RollbackDecision>).value;
    expect(decision.shouldRollback, isTrue);
    expect(decision.reason, 'rollout_percentage_regressed');
  });

  test('semantic version validation accepts x.y.z+build format', () {
    final contract = CiCdReleaseContract(logger: InMemoryAppLogger());

    final result = contract.validateSemanticVersion('1.2.3+45');

    expect(result, isA<AppSuccess<void>>());
  });

  test('semantic version validation rejects invalid format', () {
    final contract = CiCdReleaseContract(logger: InMemoryAppLogger());

    final result = contract.validateSemanticVersion('1.2');

    expect(result, isA<AppFailure<void>>());
    expect((result as AppFailure<void>).detail.code, 'cicd_version_invalid');
  });
}
