import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/observability/log_event.dart';
import 'package:thrive_app/core/result/app_result.dart';

class StructuredLogRecord {
  const StructuredLogRecord({
    required this.code,
    required this.message,
    required this.level,
    required this.metadata,
    required this.owner,
    required this.occurredAt,
  });

  final String code;
  final String message;
  final LogLevel level;
  final Map<String, Object?> metadata;
  final String owner;
  final DateTime occurredAt;
}

class CrashReport {
  const CrashReport({
    required this.errorType,
    required this.releaseVersion,
    required this.environment,
    required this.fatal,
    required this.occurredAt,
    this.stackTraceHash,
  });

  final String errorType;
  final String releaseVersion;
  final String environment;
  final bool fatal;
  final DateTime occurredAt;
  final String? stackTraceHash;
}

class AlertRule {
  const AlertRule({
    required this.ruleCode,
    required this.threshold,
    required this.ownerTeam,
    required this.severity,
  });

  final String ruleCode;
  final int threshold;
  final String ownerTeam;
  final LogLevel severity;
}

class ReleaseHealthSnapshot {
  const ReleaseHealthSnapshot({
    required this.releaseVersion,
    required this.sessions,
    required this.crashes,
  });

  final String releaseVersion;
  final int sessions;
  final int crashes;

  double get crashFreeRate {
    if (sessions <= 0) {
      return 1;
    }
    final rate = 1 - (crashes / sessions);
    return rate.clamp(0, 1);
  }
}

class AlertIncident {
  const AlertIncident({
    required this.ruleCode,
    required this.ownerTeam,
    required this.severity,
    required this.observedCount,
    required this.triggeredAt,
    required this.metadata,
  });

  final String ruleCode;
  final String ownerTeam;
  final LogLevel severity;
  final int observedCount;
  final DateTime triggeredAt;
  final Map<String, Object?> metadata;
}

abstract interface class CrashReportingGateway {
  Future<AppResult<void>> record(CrashReport report);
}

abstract interface class AlertRoutingGateway {
  Future<AppResult<void>> route(AlertIncident incident);
}

class ObservabilityMonitoringContract {
  ObservabilityMonitoringContract({
    required CrashReportingGateway crashReportingGateway,
    required AlertRoutingGateway alertRoutingGateway,
    required AppLogger logger,
  }) : _crashReportingGateway = crashReportingGateway,
       _alertRoutingGateway = alertRoutingGateway,
       _logger = logger;

  final CrashReportingGateway _crashReportingGateway;
  final AlertRoutingGateway _alertRoutingGateway;
  final AppLogger _logger;

  AppResult<void> emitStructuredLog(StructuredLogRecord record) {
    if (record.code.trim().isEmpty ||
        record.message.trim().isEmpty ||
        record.owner.trim().isEmpty) {
      return AppFailure<void>(
        FailureDetail(
          code: 'structured_log_invalid',
          developerMessage: 'Structured log requires code/message/owner.',
          userMessage: 'Could not record telemetry right now.',
          recoverable: true,
        ),
      );
    }

    final metadata = <String, Object?>{
      ...record.metadata,
      'owner': record.owner,
      'occurredAt': record.occurredAt.toIso8601String(),
    };

    if (record.level == LogLevel.info) {
      _logger.info(
        code: record.code,
        message: record.message,
        metadata: metadata,
      );
    } else if (record.level == LogLevel.warning) {
      _logger.warning(
        code: record.code,
        message: record.message,
        metadata: metadata,
      );
    } else {
      _logger.error(
        code: record.code,
        message: record.message,
        metadata: metadata,
      );
    }

    return const AppSuccess<void>(null);
  }

  Future<AppResult<void>> captureCrash(CrashReport report) async {
    if (report.errorType.trim().isEmpty ||
        report.releaseVersion.trim().isEmpty ||
        report.environment.trim().isEmpty) {
      return AppFailure<void>(
        FailureDetail(
          code: 'crash_report_invalid',
          developerMessage:
              'Crash report requires errorType/releaseVersion/environment.',
          userMessage: 'Could not process crash diagnostics right now.',
          recoverable: true,
        ),
      );
    }

    final result = await _crashReportingGateway.record(report);
    if (result is AppFailure<void>) {
      _logger.warning(
        code: 'crash_report_capture_failed',
        message: result.detail.developerMessage,
        metadata: <String, Object?>{
          'releaseVersion': report.releaseVersion,
          'environment': report.environment,
          'fatal': report.fatal,
        },
      );
      return result;
    }

    _logger.info(
      code: 'crash_report_captured',
      message: 'Crash report captured successfully',
      metadata: <String, Object?>{
        'releaseVersion': report.releaseVersion,
        'environment': report.environment,
        'fatal': report.fatal,
      },
    );
    return const AppSuccess<void>(null);
  }

  Future<AppResult<void>> routeAlertIfThresholdExceeded({
    required AlertRule rule,
    required int observedCount,
    required DateTime now,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) async {
    if (rule.ruleCode.trim().isEmpty ||
        rule.ownerTeam.trim().isEmpty ||
        rule.threshold <= 0) {
      return AppFailure<void>(
        FailureDetail(
          code: 'alert_rule_invalid',
          developerMessage:
              'Alert rule requires non-empty code/ownerTeam and threshold > 0.',
          userMessage: 'Could not evaluate monitoring alert rules right now.',
          recoverable: true,
        ),
      );
    }

    if (observedCount < rule.threshold) {
      _logger.info(
        code: 'alert_threshold_not_reached',
        message: 'Alert threshold not reached',
        metadata: <String, Object?>{
          'ruleCode': rule.ruleCode,
          'observedCount': observedCount,
          'threshold': rule.threshold,
        },
      );
      return const AppSuccess<void>(null);
    }

    final incident = AlertIncident(
      ruleCode: rule.ruleCode,
      ownerTeam: rule.ownerTeam,
      severity: rule.severity,
      observedCount: observedCount,
      triggeredAt: now,
      metadata: metadata,
    );

    final routeResult = await _alertRoutingGateway.route(incident);
    if (routeResult is AppFailure<void>) {
      _logger.warning(
        code: 'alert_routing_failed',
        message: routeResult.detail.developerMessage,
        metadata: <String, Object?>{
          'ruleCode': rule.ruleCode,
          'ownerTeam': rule.ownerTeam,
        },
      );
      return routeResult;
    }

    _logger.warning(
      code: 'alert_routed',
      message: 'Monitoring alert routed to incident owner',
      metadata: <String, Object?>{
        'ruleCode': rule.ruleCode,
        'ownerTeam': rule.ownerTeam,
        'observedCount': observedCount,
      },
    );
    return const AppSuccess<void>(null);
  }

  AppResult<double> evaluateReleaseHealth({
    required ReleaseHealthSnapshot snapshot,
    required double minimumCrashFreeRate,
  }) {
    if (minimumCrashFreeRate <= 0 || minimumCrashFreeRate > 1) {
      return AppFailure<double>(
        FailureDetail(
          code: 'release_health_threshold_invalid',
          developerMessage:
              'minimumCrashFreeRate must be within (0, 1]. Received $minimumCrashFreeRate.',
          userMessage: 'Could not evaluate release health right now.',
          recoverable: true,
        ),
      );
    }

    final crashFreeRate = snapshot.crashFreeRate;
    if (crashFreeRate < minimumCrashFreeRate) {
      _logger.warning(
        code: 'release_health_below_threshold',
        message: 'Release crash-free rate is below threshold',
        metadata: <String, Object?>{
          'releaseVersion': snapshot.releaseVersion,
          'crashFreeRate': crashFreeRate,
          'threshold': minimumCrashFreeRate,
          'sessions': snapshot.sessions,
          'crashes': snapshot.crashes,
        },
      );
    } else {
      _logger.info(
        code: 'release_health_healthy',
        message: 'Release crash-free rate is healthy',
        metadata: <String, Object?>{
          'releaseVersion': snapshot.releaseVersion,
          'crashFreeRate': crashFreeRate,
          'threshold': minimumCrashFreeRate,
        },
      );
    }

    return AppSuccess<double>(crashFreeRate);
  }
}
