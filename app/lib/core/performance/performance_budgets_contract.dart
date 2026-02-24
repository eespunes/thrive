import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

class PerformanceFlowBudget {
  const PerformanceFlowBudget({
    required this.flowName,
    required this.maxLatencyMs,
    required this.maxPayloadKb,
    required this.minThroughputRps,
  });

  final String flowName;
  final int maxLatencyMs;
  final int maxPayloadKb;
  final int minThroughputRps;
}

class PerformanceObservation {
  const PerformanceObservation({
    required this.flowName,
    required this.latencyMs,
    required this.payloadKb,
    required this.throughputRps,
    required this.measuredAt,
  });

  final String flowName;
  final int latencyMs;
  final int payloadKb;
  final int throughputRps;
  final DateTime measuredAt;
}

class PerformanceBudgetResult {
  const PerformanceBudgetResult({
    required this.withinBudget,
    required this.regressions,
  });

  final bool withinBudget;
  final List<String> regressions;
}

class LoadProtectionConfig {
  const LoadProtectionConfig({
    required this.maxConcurrentRequests,
    required this.maxQueueDepth,
    required this.enableShedding,
  });

  final int maxConcurrentRequests;
  final int maxQueueDepth;
  final bool enableShedding;
}

class LoadSnapshot {
  const LoadSnapshot({
    required this.concurrentRequests,
    required this.queueDepth,
    required this.errorRatePercent,
  });

  final int concurrentRequests;
  final int queueDepth;
  final double errorRatePercent;
}

class LoadProtectionDecision {
  const LoadProtectionDecision({
    required this.accepted,
    required this.reasonCode,
    required this.userMessage,
    required this.shouldShed,
  });

  final bool accepted;
  final String reasonCode;
  final String userMessage;
  final bool shouldShed;
}

class ProfilingWorkflowPlan {
  const ProfilingWorkflowPlan({
    required this.target,
    required this.owner,
    required this.steps,
  });

  final String target;
  final String owner;
  final List<String> steps;
}

class PerformanceBudgetsContract {
  PerformanceBudgetsContract({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  AppResult<PerformanceBudgetResult> evaluateBudget({
    required PerformanceFlowBudget budget,
    required PerformanceObservation observation,
  }) {
    if (budget.flowName.trim().isEmpty ||
        observation.flowName.trim().isEmpty ||
        budget.flowName != observation.flowName ||
        budget.maxLatencyMs <= 0 ||
        budget.maxPayloadKb <= 0 ||
        budget.minThroughputRps <= 0) {
      return _budgetFailure(
        code: 'performance_budget_invalid',
        developerMessage:
            'Budget/observation payload is invalid or mismatched.',
        userMessage: 'Could not evaluate performance budget right now.',
      );
    }

    final regressions = <String>[];
    if (observation.latencyMs > budget.maxLatencyMs) {
      regressions.add('latency_ms_exceeded');
    }
    if (observation.payloadKb > budget.maxPayloadKb) {
      regressions.add('payload_kb_exceeded');
    }
    if (observation.throughputRps < budget.minThroughputRps) {
      regressions.add('throughput_rps_below_min');
    }

    final result = PerformanceBudgetResult(
      withinBudget: regressions.isEmpty,
      regressions: regressions,
    );

    if (result.withinBudget) {
      _logger.info(
        code: 'performance_budget_passed',
        message: 'Performance budget passed for critical flow',
        metadata: <String, Object?>{
          'flow': budget.flowName,
          'latencyMs': observation.latencyMs,
          'payloadKb': observation.payloadKb,
          'throughputRps': observation.throughputRps,
        },
      );
    } else {
      _logger.warning(
        code: 'performance_budget_regression_detected',
        message: 'Performance budget regression detected',
        metadata: <String, Object?>{
          'flow': budget.flowName,
          'regressions': regressions,
        },
      );
    }

    return AppSuccess<PerformanceBudgetResult>(result);
  }

  AppResult<LoadProtectionDecision> evaluateLoadProtection({
    required LoadProtectionConfig config,
    required LoadSnapshot snapshot,
  }) {
    if (config.maxConcurrentRequests <= 0 || config.maxQueueDepth <= 0) {
      return _loadFailure(
        code: 'load_protection_config_invalid',
        developerMessage: 'Load protection config values must be > 0.',
        userMessage: 'Could not evaluate service load right now.',
      );
    }

    final overload =
        snapshot.concurrentRequests > config.maxConcurrentRequests ||
        snapshot.queueDepth > config.maxQueueDepth;

    if (!overload) {
      final decision = const LoadProtectionDecision(
        accepted: true,
        reasonCode: 'load_within_limits',
        userMessage: 'Request accepted.',
        shouldShed: false,
      );
      _logger.info(
        code: 'load_protection_allowed',
        message: 'Request accepted within load limits',
        metadata: <String, Object?>{
          'concurrentRequests': snapshot.concurrentRequests,
          'queueDepth': snapshot.queueDepth,
        },
      );
      return AppSuccess<LoadProtectionDecision>(decision);
    }

    if (!config.enableShedding) {
      return _loadFailure(
        code: 'load_protection_overloaded',
        developerMessage:
            'Overload detected but shedding is disabled. concurrent=${snapshot.concurrentRequests} queue=${snapshot.queueDepth}.',
        userMessage: 'Service is temporarily busy. Please try again shortly.',
      );
    }

    final decision = const LoadProtectionDecision(
      accepted: false,
      reasonCode: 'load_shedding_applied',
      userMessage: 'Service is busy. Please retry in a moment.',
      shouldShed: true,
    );
    _logger.warning(
      code: 'load_protection_shedding_applied',
      message: 'Load shedding applied due to traffic spike',
      metadata: <String, Object?>{
        'concurrentRequests': snapshot.concurrentRequests,
        'queueDepth': snapshot.queueDepth,
        'errorRatePercent': snapshot.errorRatePercent,
      },
    );
    return AppSuccess<LoadProtectionDecision>(decision);
  }

  AppResult<ProfilingWorkflowPlan> createProfilingWorkflow({
    required String target,
    required String owner,
  }) {
    if (target.trim().isEmpty || owner.trim().isEmpty) {
      return AppFailure<ProfilingWorkflowPlan>(
        FailureDetail(
          code: 'profiling_workflow_invalid',
          developerMessage: 'Profiling workflow target/owner cannot be empty.',
          userMessage: 'Could not prepare profiling workflow right now.',
          recoverable: true,
        ),
      );
    }

    final plan = ProfilingWorkflowPlan(
      target: target,
      owner: owner,
      steps: const <String>[
        'Collect trace and latency histogram',
        'Identify top regressions by p95 and payload',
        'Apply optimization and compare against budget',
      ],
    );

    _logger.info(
      code: 'profiling_workflow_created',
      message: 'Profiling workflow created for slow operation',
      metadata: <String, Object?>{'target': target, 'owner': owner},
    );
    return AppSuccess<ProfilingWorkflowPlan>(plan);
  }

  AppFailure<PerformanceBudgetResult> _budgetFailure({
    required String code,
    required String developerMessage,
    required String userMessage,
  }) {
    _logger.warning(code: code, message: developerMessage);
    return AppFailure<PerformanceBudgetResult>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: userMessage,
        recoverable: true,
      ),
    );
  }

  AppFailure<LoadProtectionDecision> _loadFailure({
    required String code,
    required String developerMessage,
    required String userMessage,
  }) {
    _logger.warning(code: code, message: developerMessage);
    return AppFailure<LoadProtectionDecision>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: userMessage,
        recoverable: true,
      ),
    );
  }
}
