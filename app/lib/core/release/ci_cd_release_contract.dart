import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

class BuildWorkflowSnapshot {
  const BuildWorkflowSnapshot({
    required this.commitSha,
    required this.testsPassed,
    required this.analysisPassed,
    required this.artifactsGenerated,
  });

  final String commitSha;
  final bool testsPassed;
  final bool analysisPassed;
  final bool artifactsGenerated;
}

class SigningPromotionRequest {
  const SigningPromotionRequest({
    required this.artifactId,
    required this.track,
    required this.signingKeyVersion,
    required this.checksum,
  });

  final String artifactId;
  final String track;
  final int signingKeyVersion;
  final String checksum;
}

class RolloutSnapshot {
  const RolloutSnapshot({
    required this.releaseId,
    required this.currentPercentage,
    required this.previousPercentage,
    required this.issueReported,
  });

  final String releaseId;
  final int currentPercentage;
  final int previousPercentage;
  final bool issueReported;
}

class RollbackDecision {
  const RollbackDecision({required this.shouldRollback, required this.reason});

  final bool shouldRollback;
  final String reason;
}

class CiCdReleaseContract {
  CiCdReleaseContract({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  AppResult<void> validateAutomatedWorkflow(BuildWorkflowSnapshot snapshot) {
    if (snapshot.commitSha.trim().length < 7) {
      return _failure(
        code: 'cicd_commit_sha_invalid',
        developerMessage: 'Commit SHA must contain at least 7 chars.',
        userMessage: 'Could not validate release workflow right now.',
      );
    }

    if (!snapshot.testsPassed ||
        !snapshot.analysisPassed ||
        !snapshot.artifactsGenerated) {
      return _failure(
        code: 'cicd_quality_gate_failed',
        developerMessage: 'Required build/test/analyze gates did not pass.',
        userMessage: 'Release candidate is not ready yet.',
      );
    }

    _logger.info(
      code: 'cicd_workflow_validated',
      message: 'Automated build and test workflow validated',
      metadata: <String, Object?>{'commitSha': snapshot.commitSha},
    );
    return const AppSuccess<void>(null);
  }

  AppResult<void> validateSigningPromotion(SigningPromotionRequest request) {
    const allowedTracks = <String>{'internal', 'alpha', 'beta', 'production'};

    if (request.artifactId.trim().isEmpty ||
        request.signingKeyVersion <= 0 ||
        request.checksum.trim().length < 8 ||
        !allowedTracks.contains(request.track)) {
      return _failure(
        code: 'cicd_signing_promotion_invalid',
        developerMessage:
            'Invalid signing/promotion payload for artifact ${request.artifactId}.',
        userMessage: 'Could not validate artifact promotion right now.',
      );
    }

    _logger.info(
      code: 'cicd_artifact_promoted',
      message: 'Artifact signing and promotion validated',
      metadata: <String, Object?>{
        'artifactId': request.artifactId,
        'track': request.track,
        'signingKeyVersion': request.signingKeyVersion,
      },
    );
    return const AppSuccess<void>(null);
  }

  AppResult<RollbackDecision> evaluateRollout(RolloutSnapshot snapshot) {
    if (snapshot.releaseId.trim().isEmpty ||
        snapshot.currentPercentage < 0 ||
        snapshot.currentPercentage > 100 ||
        snapshot.previousPercentage < 0 ||
        snapshot.previousPercentage > 100) {
      return AppFailure<RollbackDecision>(
        FailureDetail(
          code: 'cicd_rollout_snapshot_invalid',
          developerMessage: 'Rollout snapshot values are invalid.',
          userMessage: 'Could not evaluate rollout status right now.',
          recoverable: true,
        ),
      );
    }

    if (snapshot.issueReported) {
      _logger.warning(
        code: 'cicd_rollback_required',
        message: 'Production issue reported during rollout',
        metadata: <String, Object?>{
          'releaseId': snapshot.releaseId,
          'currentPercentage': snapshot.currentPercentage,
        },
      );
      return const AppSuccess<RollbackDecision>(
        RollbackDecision(
          shouldRollback: true,
          reason: 'production_issue_reported',
        ),
      );
    }

    if (snapshot.currentPercentage < snapshot.previousPercentage) {
      return const AppSuccess<RollbackDecision>(
        RollbackDecision(
          shouldRollback: true,
          reason: 'rollout_percentage_regressed',
        ),
      );
    }

    _logger.info(
      code: 'cicd_rollout_healthy',
      message: 'Rollout progressing without rollback signals',
      metadata: <String, Object?>{
        'releaseId': snapshot.releaseId,
        'currentPercentage': snapshot.currentPercentage,
      },
    );
    return const AppSuccess<RollbackDecision>(
      RollbackDecision(shouldRollback: false, reason: 'healthy'),
    );
  }

  AppResult<void> validateSemanticVersion(String version) {
    final pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)\+(\d+)$');
    final match = pattern.firstMatch(version.trim());
    if (match == null) {
      return _failure(
        code: 'cicd_version_invalid',
        developerMessage:
            'Version "$version" does not match x.y.z+build format.',
        userMessage: 'Could not validate app version format.',
      );
    }

    _logger.info(
      code: 'cicd_version_validated',
      message: 'Semantic version validated for release pipeline',
      metadata: <String, Object?>{'version': version},
    );
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
