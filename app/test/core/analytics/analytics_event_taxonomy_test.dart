import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/analytics/analytics_event_taxonomy.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('registers definition and emits valid event', () async {
    final logger = InMemoryAppLogger();
    final contract = AnalyticsEventTaxonomyContract(
      gateway: _AnalyticsGatewayStub(),
      logger: logger,
    );

    final registerResult = contract.registerDefinition(
      const AnalyticsEventDefinition(
        name: 'transaction_created',
        version: 1,
        requiredParams: <String>{'workspace_id', 'source'},
        optionalParams: <String>{'flow'},
      ),
    );
    expect(registerResult, isA<AppSuccess<void>>());

    final emitResult = await contract.emit(
      AnalyticsEvent(
        name: 'transaction_created',
        version: 1,
        params: const <String, Object?>{
          'workspace_id': 'w-1',
          'source': 'manual',
        },
        emittedAt: DateTime.utc(2030, 1, 1),
      ),
    );

    expect(emitResult, isA<AppSuccess<void>>());
    expect(
      logger.events.map((event) => event.code),
      contains('analytics_event_emitted'),
    );
  });

  test('fails when required parameter is missing', () {
    final contract = AnalyticsEventTaxonomyContract(
      gateway: _AnalyticsGatewayStub(),
      logger: InMemoryAppLogger(),
    );

    contract.registerDefinition(
      const AnalyticsEventDefinition(
        name: 'budget_goal_opened',
        version: 1,
        requiredParams: <String>{'workspace_id'},
        optionalParams: <String>{},
      ),
    );

    final result = contract.validate(
      AnalyticsEvent(
        name: 'budget_goal_opened',
        version: 1,
        params: const <String, Object?>{},
        emittedAt: DateTime.utc(2030, 1, 1),
      ),
    );

    expect(result, isA<AppFailure<void>>());
    expect(
      (result as AppFailure<void>).detail.code,
      'analytics_param_required_missing',
    );
  });

  test('fails when potential pii is detected', () {
    final contract = AnalyticsEventTaxonomyContract(
      gateway: _AnalyticsGatewayStub(),
      logger: InMemoryAppLogger(),
    );

    contract.registerDefinition(
      const AnalyticsEventDefinition(
        name: 'support_contacted',
        version: 1,
        requiredParams: <String>{'channel'},
        optionalParams: <String>{'note'},
      ),
    );

    final result = contract.validate(
      AnalyticsEvent(
        name: 'support_contacted',
        version: 1,
        params: const <String, Object?>{
          'channel': 'email',
          'note': 'Reach me at person@example.com',
        },
        emittedAt: DateTime.utc(2030, 1, 1),
      ),
    );

    expect(result, isA<AppFailure<void>>());
    expect(
      (result as AppFailure<void>).detail.code,
      'analytics_payload_pii_detected',
    );
  });

  test('fails when schema version is deprecated', () {
    final contract = AnalyticsEventTaxonomyContract(
      gateway: _AnalyticsGatewayStub(),
      logger: InMemoryAppLogger(),
    );

    contract.registerDefinition(
      const AnalyticsEventDefinition(
        name: 'wallet_opened',
        version: 1,
        requiredParams: <String>{'workspace_id'},
        optionalParams: <String>{},
        deprecated: true,
      ),
    );

    final result = contract.validate(
      AnalyticsEvent(
        name: 'wallet_opened',
        version: 1,
        params: const <String, Object?>{'workspace_id': 'w-1'},
        emittedAt: DateTime.utc(2030, 1, 1),
      ),
    );

    expect(result, isA<AppFailure<void>>());
    expect(
      (result as AppFailure<void>).detail.code,
      'analytics_definition_deprecated',
    );
  });
}

class _AnalyticsGatewayStub implements AnalyticsGateway {
  @override
  Future<AppResult<void>> send(AnalyticsEvent event) async =>
      const AppSuccess<void>(null);
}
