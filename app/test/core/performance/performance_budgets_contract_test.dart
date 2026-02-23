import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/performance/performance_budgets_contract.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('budget evaluation passes when observation is within targets', () {
    final logger = InMemoryAppLogger();
    final contract = PerformanceBudgetsContract(logger: logger);

    final result = contract.evaluateBudget(
      budget: const PerformanceFlowBudget(
        flowName: 'home_feed',
        maxLatencyMs: 350,
        maxPayloadKb: 120,
        minThroughputRps: 20,
      ),
      observation: PerformanceObservation(
        flowName: 'home_feed',
        latencyMs: 300,
        payloadKb: 100,
        throughputRps: 23,
        measuredAt: DateTime.utc(2030, 1, 1),
      ),
    );

    expect(result, isA<AppSuccess<PerformanceBudgetResult>>());
    final value = (result as AppSuccess<PerformanceBudgetResult>).value;
    expect(value.withinBudget, isTrue);
    expect(
      logger.events.map((event) => event.code),
      contains('performance_budget_passed'),
    );
  });

  test('budget evaluation flags deterministic regressions', () {
    final contract = PerformanceBudgetsContract(logger: InMemoryAppLogger());

    final result = contract.evaluateBudget(
      budget: const PerformanceFlowBudget(
        flowName: 'home_feed',
        maxLatencyMs: 300,
        maxPayloadKb: 100,
        minThroughputRps: 25,
      ),
      observation: PerformanceObservation(
        flowName: 'home_feed',
        latencyMs: 450,
        payloadKb: 150,
        throughputRps: 10,
        measuredAt: DateTime.utc(2030, 1, 1),
      ),
    );

    expect(result, isA<AppSuccess<PerformanceBudgetResult>>());
    final value = (result as AppSuccess<PerformanceBudgetResult>).value;
    expect(value.withinBudget, isFalse);
    expect(
      value.regressions,
      containsAll(<String>[
        'latency_ms_exceeded',
        'payload_kb_exceeded',
        'throughput_rps_below_min',
      ]),
    );
  });

  test('load protection applies shedding during spike', () {
    final contract = PerformanceBudgetsContract(logger: InMemoryAppLogger());

    final result = contract.evaluateLoadProtection(
      config: const LoadProtectionConfig(
        maxConcurrentRequests: 200,
        maxQueueDepth: 50,
        enableShedding: true,
      ),
      snapshot: const LoadSnapshot(
        concurrentRequests: 260,
        queueDepth: 80,
        errorRatePercent: 4.0,
      ),
    );

    expect(result, isA<AppSuccess<LoadProtectionDecision>>());
    final decision = (result as AppSuccess<LoadProtectionDecision>).value;
    expect(decision.accepted, isFalse);
    expect(decision.reasonCode, 'load_shedding_applied');
  });

  test(
    'load protection fails deterministically when overloaded and shedding disabled',
    () {
      final contract = PerformanceBudgetsContract(logger: InMemoryAppLogger());

      final result = contract.evaluateLoadProtection(
        config: const LoadProtectionConfig(
          maxConcurrentRequests: 200,
          maxQueueDepth: 50,
          enableShedding: false,
        ),
        snapshot: const LoadSnapshot(
          concurrentRequests: 260,
          queueDepth: 51,
          errorRatePercent: 2.3,
        ),
      );

      expect(result, isA<AppFailure<LoadProtectionDecision>>());
      expect(
        (result as AppFailure<LoadProtectionDecision>).detail.code,
        'load_protection_overloaded',
      );
    },
  );

  test('profiling workflow produces deterministic optimization steps', () {
    final contract = PerformanceBudgetsContract(logger: InMemoryAppLogger());

    final result = contract.createProfilingWorkflow(
      target: 'slow_query_transactions',
      owner: 'data-platform',
    );

    expect(result, isA<AppSuccess<ProfilingWorkflowPlan>>());
    final plan = (result as AppSuccess<ProfilingWorkflowPlan>).value;
    expect(plan.steps.length, 3);
  });
}
