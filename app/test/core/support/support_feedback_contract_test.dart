import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';
import 'package:thrive_app/core/support/support_feedback_contract.dart';

void main() {
  test('captures in-app support request with valid payload', () {
    final contract = SupportFeedbackContract(logger: InMemoryAppLogger());

    final result = contract.captureSupportRequest(_ticket());

    expect(result, isA<AppSuccess<void>>());
  });

  test('attaches diagnostics with pii/secret redaction', () {
    final contract = SupportFeedbackContract(logger: InMemoryAppLogger());

    final result = contract.attachDiagnosticContext(
      ticket: _ticket(),
      context: const DiagnosticContext(
        appVersion: '1.0.1+2',
        platform: 'android',
        deviceLocale: 'en_US',
        timezoneOffset: '+01:00',
        logs: <String>[
          'user mail user@example.com failed login',
          'token=abc123',
          'Authorization: Bearer abc.def.ghi',
          'Cookie: route=abc; sessionid=secret; other=1',
          '/api/login?password=hello123&token=qwerty',
          'password: super-secret-pass',
        ],
      ),
    );

    expect(result, isA<AppSuccess<DiagnosticAttachment>>());
    final attachment = (result as AppSuccess<DiagnosticAttachment>).value;
    expect(attachment.redactedLogs.first, contains('[redacted-email]'));
    expect(attachment.redactedLogs.last, contains('[redacted-secret]'));
    expect(
      attachment.redactedLogs[2],
      contains('Authorization: [redacted-secret]'),
    );
    expect(
      attachment.redactedLogs[3],
      contains(
        'Cookie: route=[redacted-cookie]; sessionid=[redacted-cookie]; other=[redacted-cookie]',
      ),
    );
    expect(
      attachment.redactedLogs[4],
      contains('?password=[redacted-secret]&token=[redacted-secret]'),
    );
    expect(attachment.redactedLogs[2], isNot(contains('abc.def.ghi')));
    expect(attachment.redactedLogs[3], isNot(contains('secret')));
  });

  test('assigns ownership team based on ticket category', () {
    final contract = SupportFeedbackContract(logger: InMemoryAppLogger());

    final result = contract.assignOwnership(
      SupportTicket(
        ticketId: 't-2',
        userId: 'u-1',
        workspaceId: 'w-1',
        category: 'billing',
        message: 'Need invoice correction for last month.',
        priority: SupportPriority.medium,
        createdAt: DateTime.utc(2030, 1, 1),
      ),
    );

    expect(result, isA<AppSuccess<SupportAssignment>>());
    final assignment = (result as AppSuccess<SupportAssignment>).value;
    expect(assignment.team, 'finance-support');
  });

  test('sla evaluation flags breach when response is late', () {
    final contract = SupportFeedbackContract(logger: InMemoryAppLogger());

    final result = contract.evaluateSla(
      ticket: _ticket(createdAt: DateTime.utc(2030, 1, 1, 0)),
      assignment: const SupportAssignment(
        team: 'mobile-platform',
        slaHours: 12,
      ),
      now: DateTime.utc(2030, 1, 2, 0),
    );

    expect(result, isA<AppSuccess<SupportSlaStatus>>());
    final status = (result as AppSuccess<SupportSlaStatus>).value;
    expect(status.isBreached, isTrue);
  });

  test('sla evaluation stays on track and emits info signal', () {
    final logger = InMemoryAppLogger();
    final contract = SupportFeedbackContract(logger: logger);

    final result = contract.evaluateSla(
      ticket: _ticket(createdAt: DateTime.utc(2030, 1, 1, 0)),
      assignment: const SupportAssignment(
        team: 'mobile-platform',
        slaHours: 12,
      ),
      now: DateTime.utc(2030, 1, 1, 6),
    );

    expect(result, isA<AppSuccess<SupportSlaStatus>>());
    final status = (result as AppSuccess<SupportSlaStatus>).value;
    expect(status.isBreached, isFalse);
    expect(
      logger.events.map((event) => event.code),
      contains('support_sla_on_track'),
    );
  });

  test('invalid support request fails deterministically', () {
    final contract = SupportFeedbackContract(logger: InMemoryAppLogger());

    final result = contract.captureSupportRequest(
      SupportTicket(
        ticketId: '',
        userId: 'u-1',
        workspaceId: 'w-1',
        category: 'bug',
        message: 'short',
        priority: SupportPriority.low,
        createdAt: DateTime.utc(2030, 1, 1),
      ),
    );

    expect(result, isA<AppFailure<void>>());
    expect((result as AppFailure<void>).detail.code, 'support_ticket_invalid');
  });
}

SupportTicket _ticket({DateTime? createdAt}) {
  return SupportTicket(
    ticketId: 't-1',
    userId: 'u-1',
    workspaceId: 'w-1',
    category: 'bug',
    message: 'The transaction list freezes when opening details.',
    priority: SupportPriority.high,
    createdAt: createdAt ?? DateTime.utc(2030, 1, 1),
  );
}
