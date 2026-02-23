import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/functions/cloud_function_contracts.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('execute returns success and persists idempotency result', () async {
    final logger = InMemoryAppLogger();
    final gateway = _SequenceGateway(
      results: <AppResult<FunctionContractResponse>>[
        AppSuccess<FunctionContractResponse>(_response(requestId: 'req-1')),
      ],
    );
    final store = InMemoryFunctionIdempotencyStore();
    final executor = CloudFunctionContractExecutor(
      gateway: gateway,
      idempotencyStore: store,
      logger: logger,
    );

    final result = await executor.execute(request: _request());

    expect(result, isA<AppSuccess<FunctionContractResponse>>());
    expect(gateway.callCount, 1);
    final cached = await store.read(key: 'idem-1');
    expect(cached, isA<AppSuccess<FunctionContractResponse?>>());
    expect((cached as AppSuccess<FunctionContractResponse?>).value, isNotNull);
  });

  test('execute retries recoverable failure using backoff policy', () async {
    final logger = InMemoryAppLogger();
    final gateway = _SequenceGateway(
      results: <AppResult<FunctionContractResponse>>[
        AppFailure<FunctionContractResponse>(
          FailureDetail(
            code: 'transient_timeout',
            developerMessage: 'Gateway timed out.',
            userMessage: 'Temporary issue.',
            recoverable: true,
          ),
        ),
        AppSuccess<FunctionContractResponse>(_response(requestId: 'req-2')),
      ],
    );
    final delays = <Duration>[];
    final executor = CloudFunctionContractExecutor(
      gateway: gateway,
      idempotencyStore: InMemoryFunctionIdempotencyStore(),
      logger: logger,
      delay: (delay) async => delays.add(delay),
    );

    final result = await executor.execute(
      request: _request(idempotencyKey: 'idem-2'),
      retryPolicy: const RetryBackoffPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 100),
        multiplier: 2,
        maxDelay: Duration(seconds: 1),
      ),
    );

    expect(result, isA<AppSuccess<FunctionContractResponse>>());
    expect(gateway.callCount, 2);
    expect(delays, <Duration>[const Duration(milliseconds: 100)]);
    expect(
      logger.events.map((event) => event.code),
      contains('cloud_function_retry_scheduled'),
    );
  });

  test(
    'execute returns cached response for duplicate idempotency key',
    () async {
      final logger = InMemoryAppLogger();
      final gateway = _SequenceGateway(
        results: <AppResult<FunctionContractResponse>>[
          AppSuccess<FunctionContractResponse>(_response(requestId: 'req-3')),
        ],
      );
      final store = InMemoryFunctionIdempotencyStore();
      final executor = CloudFunctionContractExecutor(
        gateway: gateway,
        idempotencyStore: store,
        logger: logger,
      );

      final first = await executor.execute(
        request: _request(idempotencyKey: 'idem-3'),
      );
      final second = await executor.execute(
        request: _request(idempotencyKey: 'idem-3'),
      );

      expect(first, isA<AppSuccess<FunctionContractResponse>>());
      expect(second, isA<AppSuccess<FunctionContractResponse>>());
      expect(gateway.callCount, 1);
      expect(
        logger.events.map((event) => event.code),
        contains('cloud_function_idempotent_replay'),
      );
    },
  );

  test('execute does not retry non-recoverable failure', () async {
    final logger = InMemoryAppLogger();
    final gateway = _SequenceGateway(
      results: <AppResult<FunctionContractResponse>>[
        AppFailure<FunctionContractResponse>(
          FailureDetail(
            code: 'permission_denied',
            developerMessage: 'Caller role is not allowed.',
            userMessage: 'Action not allowed.',
            recoverable: false,
          ),
        ),
      ],
    );
    final executor = CloudFunctionContractExecutor(
      gateway: gateway,
      idempotencyStore: InMemoryFunctionIdempotencyStore(),
      logger: logger,
    );

    final result = await executor.execute(
      request: _request(idempotencyKey: 'idem-4'),
    );

    expect(result, isA<AppFailure<FunctionContractResponse>>());
    expect(gateway.callCount, 1);
    final detail = (result as AppFailure<FunctionContractResponse>).detail;
    expect(detail.code, 'permission_denied');
  });
}

FunctionContractRequest _request({String idempotencyKey = 'idem-1'}) {
  return FunctionContractRequest(
    functionName: 'createSettlement',
    payload: const <String, Object?>{'amountMinor': 2500},
    idempotencyKey: idempotencyKey,
    timeout: const Duration(seconds: 10),
  );
}

FunctionContractResponse _response({required String requestId}) {
  return FunctionContractResponse(
    statusCode: 200,
    data: const <String, Object?>{'ok': true},
    requestId: requestId,
  );
}

class _SequenceGateway implements CloudFunctionGateway {
  _SequenceGateway({required this.results});

  final List<AppResult<FunctionContractResponse>> results;
  int callCount = 0;

  @override
  Future<AppResult<FunctionContractResponse>> invoke(
    FunctionContractRequest request,
  ) async {
    final index = callCount;
    callCount += 1;

    if (index >= results.length) {
      return AppFailure<FunctionContractResponse>(
        FailureDetail(
          code: 'test_gateway_exhausted',
          developerMessage: 'No more queued results in test gateway.',
          userMessage: 'Unexpected test state.',
          recoverable: false,
        ),
      );
    }

    return results[index];
  }
}
