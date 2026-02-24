import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

enum SupportPriority { low, medium, high, critical }

class SupportTicket {
  const SupportTicket({
    required this.ticketId,
    required this.userId,
    required this.workspaceId,
    required this.category,
    required this.message,
    required this.priority,
    required this.createdAt,
  });

  final String ticketId;
  final String userId;
  final String workspaceId;
  final String category;
  final String message;
  final SupportPriority priority;
  final DateTime createdAt;
}

class DiagnosticContext {
  const DiagnosticContext({
    required this.appVersion,
    required this.platform,
    required this.deviceLocale,
    required this.timezoneOffset,
    required this.logs,
  });

  final String appVersion;
  final String platform;
  final String deviceLocale;
  final String timezoneOffset;
  final List<String> logs;
}

class SupportAssignment {
  const SupportAssignment({required this.team, required this.slaHours});

  final String team;
  final int slaHours;
}

class SupportSlaStatus {
  const SupportSlaStatus({required this.dueAt, required this.isBreached});

  final DateTime dueAt;
  final bool isBreached;
}

class DiagnosticAttachment {
  const DiagnosticAttachment({
    required this.ticketId,
    required this.redactedLogs,
  });

  final String ticketId;
  final List<String> redactedLogs;
}

class SupportFeedbackContract {
  SupportFeedbackContract({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  AppResult<void> captureSupportRequest(SupportTicket ticket) {
    if (ticket.ticketId.trim().isEmpty ||
        ticket.userId.trim().isEmpty ||
        ticket.workspaceId.trim().isEmpty ||
        ticket.category.trim().isEmpty ||
        ticket.message.trim().length < 10) {
      return _failure(
        code: 'support_ticket_invalid',
        developerMessage: 'Support ticket payload is invalid.',
        userMessage:
            'Could not submit support request. Please review your message.',
      );
    }

    _logger.info(
      code: 'support_ticket_captured',
      message: 'In-app support request captured',
      metadata: <String, Object?>{
        'ticketId': ticket.ticketId,
        'category': ticket.category,
        'priority': ticket.priority.name,
      },
    );
    return const AppSuccess<void>(null);
  }

  AppResult<DiagnosticAttachment> attachDiagnosticContext({
    required SupportTicket ticket,
    required DiagnosticContext context,
  }) {
    if (context.appVersion.trim().isEmpty ||
        context.platform.trim().isEmpty ||
        context.deviceLocale.trim().isEmpty ||
        context.timezoneOffset.trim().isEmpty) {
      return AppFailure<DiagnosticAttachment>(
        FailureDetail(
          code: 'support_diagnostics_invalid',
          developerMessage: 'Diagnostic context fields cannot be empty.',
          userMessage: 'Could not attach diagnostics right now.',
          recoverable: true,
        ),
      );
    }

    final redacted = context.logs.map(_redactLogLine).toList(growable: false);
    _logger.info(
      code: 'support_diagnostics_attached',
      message: 'Diagnostic context attached to support ticket',
      metadata: <String, Object?>{
        'ticketId': ticket.ticketId,
        'logCount': redacted.length,
      },
    );

    return AppSuccess<DiagnosticAttachment>(
      DiagnosticAttachment(ticketId: ticket.ticketId, redactedLogs: redacted),
    );
  }

  AppResult<SupportAssignment> assignOwnership(SupportTicket ticket) {
    if (ticket.category.trim().isEmpty) {
      return AppFailure<SupportAssignment>(
        FailureDetail(
          code: 'support_category_invalid',
          developerMessage: 'Support category is required for assignment.',
          userMessage: 'Could not assign support ticket right now.',
          recoverable: true,
        ),
      );
    }

    final normalized = ticket.category.toLowerCase();
    final assignment = switch (normalized) {
      'billing' => const SupportAssignment(
        team: 'finance-support',
        slaHours: 8,
      ),
      'bug' => const SupportAssignment(team: 'mobile-platform', slaHours: 12),
      'account' => const SupportAssignment(
        team: 'trust-and-safety',
        slaHours: 8,
      ),
      _ => const SupportAssignment(team: 'customer-support', slaHours: 24),
    };

    _logger.info(
      code: 'support_ticket_assigned',
      message: 'Support ticket assigned to owning team',
      metadata: <String, Object?>{
        'ticketId': ticket.ticketId,
        'team': assignment.team,
        'slaHours': assignment.slaHours,
      },
    );

    return AppSuccess<SupportAssignment>(assignment);
  }

  AppResult<SupportSlaStatus> evaluateSla({
    required SupportTicket ticket,
    required SupportAssignment assignment,
    required DateTime now,
    DateTime? firstResponseAt,
  }) {
    if (assignment.slaHours <= 0) {
      return AppFailure<SupportSlaStatus>(
        FailureDetail(
          code: 'support_sla_invalid',
          developerMessage: 'SLA hours must be greater than zero.',
          userMessage: 'Could not evaluate support status right now.',
          recoverable: true,
        ),
      );
    }

    final dueAt = ticket.createdAt.add(Duration(hours: assignment.slaHours));
    final referenceTime = firstResponseAt ?? now;
    final breached = referenceTime.isAfter(dueAt);

    if (breached) {
      _logger.warning(
        code: 'support_sla_breached',
        message: 'Support SLA was breached',
        metadata: <String, Object?>{
          'ticketId': ticket.ticketId,
          'team': assignment.team,
          'dueAt': dueAt.toIso8601String(),
        },
      );
    } else {
      _logger.info(
        code: 'support_sla_on_track',
        message: 'Support SLA remains on track',
        metadata: <String, Object?>{
          'ticketId': ticket.ticketId,
          'team': assignment.team,
          'dueAt': dueAt.toIso8601String(),
        },
      );
    }

    return AppSuccess<SupportSlaStatus>(
      SupportSlaStatus(dueAt: dueAt, isBreached: breached),
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

String _redactLogLine(String value) {
  var output = value;

  // Email addresses.
  output = output.replaceAllMapped(
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    (_) => '[redacted-email]',
  );

  // Authorization-style headers.
  output = output.replaceAllMapped(
    RegExp(
      r'\b(Authorization|Proxy-Authorization)\s*:\s*([^\r\n]*)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}: [redacted-secret]',
  );

  // Cookie / Set-Cookie values (redact all cookie values in the header).
  output = output.replaceAllMapped(
    RegExp(r'\b(Cookie|Set-Cookie)\s*:\s*([^\r\n]*)', caseSensitive: false),
    (match) {
      final headerName = match.group(1);
      final cookieString = match.group(2) ?? '';
      final parts = cookieString.split(';');
      final redactedParts = <String>[];

      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) {
          continue;
        }

        final eqIndex = trimmed.indexOf('=');
        if (eqIndex == -1) {
          redactedParts.add(trimmed);
          continue;
        }

        final name = trimmed.substring(0, eqIndex).trim();
        redactedParts.add('$name=[redacted-cookie]');
      }

      final redactedCookieString = redactedParts.join('; ');
      return '$headerName: $redactedCookieString';
    },
  );

  // Sensitive query-string parameters.
  output = output.replaceAllMapped(
    RegExp(
      r'([?&](?:password|passwd|pwd|token|access_token|id_token|sessionid|session_id|sid)=)[^&\s]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}[redacted-secret]',
  );

  // Generic key/value secret patterns.
  output = output.replaceAllMapped(
    RegExp(
      r'\b(token|secret|apikey|password|passwd|pwd|sessionid|session_id|sid)\s*([=:])\s*([^\s&]+)',
      caseSensitive: false,
    ),
    (match) {
      final currentValue = match.group(3) ?? '';
      if (currentValue.startsWith('[redacted-')) {
        return match.group(0)!;
      }
      return '${match.group(1)}${match.group(2)}[redacted-secret]';
    },
  );
  return output;
}
