import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';
import 'package:thrive_app/core/testing/testing_strategy_contract.dart';

void main() {
  test('validates complete ownership across test layers', () {
    final contract = TestingStrategyContract(logger: InMemoryAppLogger());

    final result = contract.validateOwnership(const <TestLayer, String>{
      TestLayer.unit: 'mobile-core',
      TestLayer.widget: 'mobile-ui',
      TestLayer.integration: 'mobile-platform',
      TestLayer.e2e: 'qa',
    });

    expect(result, isA<AppSuccess<void>>());
  });

  test('rejects invalid test pyramid distribution', () {
    final contract = TestingStrategyContract(logger: InMemoryAppLogger());

    final result = contract.validatePyramid(
      const TestPyramidSnapshot(
        unitCount: 20,
        widgetCount: 30,
        integrationCount: 10,
        e2eCount: 5,
      ),
    );

    expect(result, isA<AppFailure<void>>());
    expect((result as AppFailure<void>).detail.code, 'testing_pyramid_invalid');
  });

  test('validates deterministic fixture payload', () {
    final contract = TestingStrategyContract(logger: InMemoryAppLogger());

    final result = contract.validateDeterministicFixture(
      const FixtureDefinition(
        fixtureId: 'wallet_fixture_v1',
        seed: 'seed-2026-01',
        records: <Map<String, Object?>>[
          <String, Object?>{'id': 'wallet-1', 'currency': 'EUR'},
        ],
      ),
    );

    expect(result, isA<AppSuccess<void>>());
  });

  test(
    'release blocking criteria returns blocked when critical failures exist',
    () {
      final contract = TestingStrategyContract(logger: InMemoryAppLogger());

      final result = contract.evaluateReleaseBlockingCriteria(
        const ReleaseGateInput(
          criticalFailures: 1,
          highFailures: 0,
          flakyRate: 0.0,
          requiredChecksPassed: true,
        ),
      );

      expect(result, isA<AppSuccess<ReleaseGateResult>>());
      final gate = (result as AppSuccess<ReleaseGateResult>).value;
      expect(gate.isBlocked, isTrue);
      expect(gate.reasons, contains('critical_failures_present'));
    },
  );

  test('release blocking criteria passes when quality gates are clean', () {
    final contract = TestingStrategyContract(logger: InMemoryAppLogger());

    final result = contract.evaluateReleaseBlockingCriteria(
      const ReleaseGateInput(
        criticalFailures: 0,
        highFailures: 1,
        flakyRate: 0.01,
        requiredChecksPassed: true,
      ),
    );

    expect(result, isA<AppSuccess<ReleaseGateResult>>());
    final gate = (result as AppSuccess<ReleaseGateResult>).value;
    expect(gate.isBlocked, isFalse);
    expect(gate.reasons, isEmpty);
  });
}
