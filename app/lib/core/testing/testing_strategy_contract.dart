import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

enum TestLayer { unit, widget, integration, e2e }

class TestPyramidSnapshot {
  const TestPyramidSnapshot({
    required this.unitCount,
    required this.widgetCount,
    required this.integrationCount,
    required this.e2eCount,
  });

  final int unitCount;
  final int widgetCount;
  final int integrationCount;
  final int e2eCount;
}

class FixtureDefinition {
  const FixtureDefinition({
    required this.fixtureId,
    required this.seed,
    required this.records,
  });

  final String fixtureId;
  final String seed;
  final List<Map<String, Object?>> records;
}

class ReleaseGateInput {
  const ReleaseGateInput({
    required this.criticalFailures,
    required this.highFailures,
    required this.flakyRate,
    required this.requiredChecksPassed,
  });

  final int criticalFailures;
  final int highFailures;
  final double flakyRate;
  final bool requiredChecksPassed;
}

class ReleaseGateResult {
  const ReleaseGateResult({required this.isBlocked, required this.reasons});

  final bool isBlocked;
  final List<String> reasons;
}

class TestingStrategyContract {
  TestingStrategyContract({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  AppResult<void> validateOwnership(Map<TestLayer, String> ownership) {
    for (final layer in TestLayer.values) {
      final owner = ownership[layer];
      if (owner == null || owner.trim().isEmpty) {
        return _failure(
          code: 'testing_owner_missing',
          developerMessage: 'Missing owner for ${layer.name} test layer.',
          userMessage: 'Could not validate testing ownership right now.',
        );
      }
    }

    _logger.info(
      code: 'testing_ownership_validated',
      message: 'Testing ownership validated across all layers',
    );
    return const AppSuccess<void>(null);
  }

  AppResult<void> validatePyramid(TestPyramidSnapshot snapshot) {
    if (snapshot.unitCount <= 0 ||
        snapshot.widgetCount <= 0 ||
        snapshot.integrationCount <= 0 ||
        snapshot.e2eCount <= 0) {
      return _failure(
        code: 'testing_pyramid_counts_invalid',
        developerMessage: 'All test layer counts must be greater than zero.',
        userMessage: 'Could not validate testing strategy right now.',
      );
    }

    if (!(snapshot.unitCount >= snapshot.widgetCount &&
        snapshot.widgetCount >= snapshot.integrationCount &&
        snapshot.integrationCount >= snapshot.e2eCount)) {
      return _failure(
        code: 'testing_pyramid_invalid',
        developerMessage:
            'Expected unit >= widget >= integration >= e2e counts.',
        userMessage: 'Testing pyramid distribution needs adjustment.',
      );
    }

    _logger.info(
      code: 'testing_pyramid_validated',
      message: 'Testing pyramid distribution is valid',
      metadata: <String, Object?>{
        'unit': snapshot.unitCount,
        'widget': snapshot.widgetCount,
        'integration': snapshot.integrationCount,
        'e2e': snapshot.e2eCount,
      },
    );
    return const AppSuccess<void>(null);
  }

  AppResult<void> validateDeterministicFixture(FixtureDefinition fixture) {
    if (fixture.fixtureId.trim().isEmpty || fixture.seed.trim().isEmpty) {
      return _failure(
        code: 'testing_fixture_invalid',
        developerMessage: 'Fixture id and seed are required.',
        userMessage: 'Could not validate test fixtures right now.',
      );
    }

    if (fixture.records.isEmpty) {
      return _failure(
        code: 'testing_fixture_records_missing',
        developerMessage: 'Fixture records cannot be empty.',
        userMessage: 'Could not validate test fixtures right now.',
      );
    }

    _logger.info(
      code: 'testing_fixture_validated',
      message: 'Deterministic fixture validated',
      metadata: <String, Object?>{
        'fixtureId': fixture.fixtureId,
        'recordCount': fixture.records.length,
      },
    );
    return const AppSuccess<void>(null);
  }

  AppResult<ReleaseGateResult> evaluateReleaseBlockingCriteria(
    ReleaseGateInput input,
  ) {
    if (input.flakyRate < 0 || input.flakyRate > 1) {
      return AppFailure<ReleaseGateResult>(
        FailureDetail(
          code: 'testing_flaky_rate_invalid',
          developerMessage: 'flakyRate must be within [0, 1].',
          userMessage: 'Could not evaluate release quality gates right now.',
          recoverable: true,
        ),
      );
    }

    final reasons = <String>[];
    if (input.criticalFailures > 0) {
      reasons.add('critical_failures_present');
    }
    if (input.highFailures > 2) {
      reasons.add('high_failures_exceeded');
    }
    if (input.flakyRate > 0.03) {
      reasons.add('flaky_rate_exceeded');
    }
    if (!input.requiredChecksPassed) {
      reasons.add('required_checks_not_passed');
    }

    final blocked = reasons.isNotEmpty;
    if (blocked) {
      _logger.warning(
        code: 'release_blocking_criteria_failed',
        message: 'Release blocked by quality gates',
        metadata: <String, Object?>{'reasons': reasons},
      );
    } else {
      _logger.info(
        code: 'release_blocking_criteria_passed',
        message: 'Release quality gates passed',
      );
    }

    return AppSuccess<ReleaseGateResult>(
      ReleaseGateResult(isBlocked: blocked, reasons: reasons),
    );
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
