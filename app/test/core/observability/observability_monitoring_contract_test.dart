import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/observability/log_event.dart';
import 'package:thrive_app/core/observability/observability_monitoring_contract.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('structured log emits with required fields', () {
    final logger = InMemoryAppLogger();
    final contract = ObservabilityMonitoringContract(
      crashReportingGateway: _CrashGatewayStub(),
      alertRoutingGateway: _AlertGatewayStub(),
      logger: logger,
    );

    final result = contract.emitStructuredLog(
      StructuredLogRecord(
        code: 'runtime_warning',
        message: 'Cache nearing capacity',
        level: LogLevel.warning,
        metadata: const <String, Object?>{'cachePercent': 89},
        owner: 'mobile-platform',
        occurredAt: DateTime.utc(2030, 1, 1),
      ),
    );

    expect(result, isA<AppSuccess<void>>());
    expect(logger.events.single.code, 'runtime_warning');
  });

  test('capture crash persists report and logs success', () async {
    final logger = InMemoryAppLogger();
    final contract = ObservabilityMonitoringContract(
      crashReportingGateway: _CrashGatewayStub(),
      alertRoutingGateway: _AlertGatewayStub(),
      logger: logger,
    );

    final result = await contract.captureCrash(
      CrashReport(
        errorType: 'StateError',
        releaseVersion: '0.1.0+14',
        environment: 'prod',
        fatal: true,
        occurredAt: DateTime.utc(2030, 1, 1),
      ),
    );

    expect(result, isA<AppSuccess<void>>());
    expect(
      logger.events.map((event) => event.code),
      contains('crash_report_captured'),
    );
  });

  test('routes alert when threshold is exceeded', () async {
    final gateway = _AlertGatewayStub();
    final logger = InMemoryAppLogger();
    final contract = ObservabilityMonitoringContract(
      crashReportingGateway: _CrashGatewayStub(),
      alertRoutingGateway: gateway,
      logger: logger,
    );

    final result = await contract.routeAlertIfThresholdExceeded(
      rule: const AlertRule(
        ruleCode: 'error_rate_high',
        threshold: 5,
        ownerTeam: 'sre',
        severity: LogLevel.error,
      ),
      observedCount: 7,
      now: DateTime.utc(2030, 1, 2),
    );

    expect(result, isA<AppSuccess<void>>());
    expect(gateway.incidents.length, 1);
    expect(logger.events.map((event) => event.code), contains('alert_routed'));
  });

  test('does not route alert when threshold is not reached', () async {
    final gateway = _AlertGatewayStub();
    final contract = ObservabilityMonitoringContract(
      crashReportingGateway: _CrashGatewayStub(),
      alertRoutingGateway: gateway,
      logger: InMemoryAppLogger(),
    );

    final result = await contract.routeAlertIfThresholdExceeded(
      rule: const AlertRule(
        ruleCode: 'error_rate_high',
        threshold: 5,
        ownerTeam: 'sre',
        severity: LogLevel.error,
      ),
      observedCount: 4,
      now: DateTime.utc(2030, 1, 2),
    );

    expect(result, isA<AppSuccess<void>>());
    expect(gateway.incidents, isEmpty);
  });

  test('release health emits warning when crash-free rate below threshold', () {
    final logger = InMemoryAppLogger();
    final contract = ObservabilityMonitoringContract(
      crashReportingGateway: _CrashGatewayStub(),
      alertRoutingGateway: _AlertGatewayStub(),
      logger: logger,
    );

    final result = contract.evaluateReleaseHealth(
      snapshot: const ReleaseHealthSnapshot(
        releaseVersion: '0.1.0+14',
        sessions: 100,
        crashes: 4,
      ),
      minimumCrashFreeRate: 0.98,
    );

    expect(result, isA<AppSuccess<double>>());
    expect((result as AppSuccess<double>).value, closeTo(0.96, 0.0001));
    expect(
      logger.events.map((event) => event.code),
      contains('release_health_below_threshold'),
    );
  });
}

class _CrashGatewayStub implements CrashReportingGateway {
  @override
  Future<AppResult<void>> record(CrashReport report) async =>
      const AppSuccess<void>(null);
}

class _AlertGatewayStub implements AlertRoutingGateway {
  final List<AlertIncident> incidents = <AlertIncident>[];

  @override
  Future<AppResult<void>> route(AlertIncident incident) async {
    incidents.add(incident);
    return const AppSuccess<void>(null);
  }
}
