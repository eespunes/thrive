import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

class FunctionContractRequest {
  const FunctionContractRequest({
    required this.functionName,
    required this.payload,
    required this.idempotencyKey,
    required this.timeout,
  });

  final String functionName;
  final Map<String, Object?> payload;
  final String idempotencyKey;
  final Duration timeout;
}

class FunctionContractResponse {
  const FunctionContractResponse({
    required this.statusCode,
    required this.data,
    required this.requestId,
  });

  final int statusCode;
  final Map<String, Object?> data;
  final String requestId;
}

class RetryBackoffPolicy {
  const RetryBackoffPolicy({
    required this.maxAttempts,
    required this.initialDelay,
    required this.multiplier,
    required this.maxDelay,
  });

  final int maxAttempts;
  final Duration initialDelay;
  final double multiplier;
  final Duration maxDelay;

  Duration delayForAttempt(int attempt) {
    if (attempt <= 1) {
      return Duration.zero;
    }

    var delayMs = initialDelay.inMilliseconds.toDouble();
    for (var i = 2; i < attempt; i += 1) {
      delayMs = delayMs * multiplier;
    }

    final boundedMs = delayMs.clamp(0, maxDelay.inMilliseconds.toDouble());
    return Duration(milliseconds: boundedMs.toInt());
  }
}

abstract interface class CloudFunctionGateway {
  Future<AppResult<FunctionContractResponse>> invoke(
    FunctionContractRequest request,
  );
}

abstract interface class FunctionIdempotencyStore {
  Future<AppResult<FunctionContractResponse?>> read({required String key});

  Future<AppResult<void>> write({
    required String key,
    required FunctionContractResponse response,
  });
}

class InMemoryFunctionIdempotencyStore implements FunctionIdempotencyStore {
  final Map<String, FunctionContractResponse> _responses =
      <String, FunctionContractResponse>{};

  @override
  Future<AppResult<FunctionContractResponse?>> read({
    required String key,
  }) async {
    return AppSuccess<FunctionContractResponse?>(_responses[key]);
  }

  @override
  Future<AppResult<void>> write({
    required String key,
    required FunctionContractResponse response,
  }) async {
    _responses[key] = response;
    return const AppSuccess<void>(null);
  }
}

typedef DelayCallback = Future<void> Function(Duration delay);

class CloudFunctionContractExecutor {
  CloudFunctionContractExecutor({
    required CloudFunctionGateway gateway,
    required FunctionIdempotencyStore idempotencyStore,
    required AppLogger logger,
    DelayCallback delay = _noDelay,
  }) : _gateway = gateway,
       _idempotencyStore = idempotencyStore,
       _logger = logger,
       _delay = delay;

  final CloudFunctionGateway _gateway;
  final FunctionIdempotencyStore _idempotencyStore;
  final AppLogger _logger;
  final DelayCallback _delay;

  static const RetryBackoffPolicy defaultRetryPolicy = RetryBackoffPolicy(
    maxAttempts: 3,
    initialDelay: Duration(milliseconds: 250),
    multiplier: 2,
    maxDelay: Duration(seconds: 2),
  );

  Future<AppResult<FunctionContractResponse>> execute({
    required FunctionContractRequest request,
    RetryBackoffPolicy retryPolicy = defaultRetryPolicy,
  }) async {
    if (request.functionName.trim().isEmpty ||
        request.idempotencyKey.trim().isEmpty) {
      return AppFailure<FunctionContractResponse>(
        FailureDetail(
          code: 'cloud_function_request_invalid',
          developerMessage:
              'Function name and idempotency key are required fields.',
          userMessage: 'Could not process this action. Please retry.',
          recoverable: true,
        ),
      );
    }

    _logger.info(
      code: 'cloud_function_invocation_received',
      message: 'Cloud function invocation received by contract executor',
      metadata: <String, Object?>{
        'functionName': request.functionName,
        'idempotencyKey': request.idempotencyKey,
      },
    );

    final existingResult = await _idempotencyStore.read(
      key: request.idempotencyKey,
    );
    if (existingResult is AppFailure<FunctionContractResponse?>) {
      return AppFailure<FunctionContractResponse>(existingResult.detail);
    }

    final cached =
        (existingResult as AppSuccess<FunctionContractResponse?>).value;
    if (cached != null) {
      _logger.info(
        code: 'cloud_function_idempotent_replay',
        message: 'Returning cached response for idempotent request',
        metadata: <String, Object?>{
          'functionName': request.functionName,
          'idempotencyKey': request.idempotencyKey,
          'requestId': cached.requestId,
        },
      );
      return AppSuccess<FunctionContractResponse>(cached);
    }

    for (var attempt = 1; attempt <= retryPolicy.maxAttempts; attempt += 1) {
      final invokeResult = await _gateway.invoke(request);

      if (invokeResult is AppSuccess<FunctionContractResponse>) {
        final response = invokeResult.value;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return AppFailure<FunctionContractResponse>(
            FailureDetail(
              code: 'cloud_function_invalid_response',
              developerMessage:
                  'Function returned non-success status ${response.statusCode}.',
              userMessage: 'The service response was invalid. Please retry.',
              recoverable: true,
            ),
          );
        }

        final persistResult = await _idempotencyStore.write(
          key: request.idempotencyKey,
          response: response,
        );
        if (persistResult is AppFailure<void>) {
          return AppFailure<FunctionContractResponse>(persistResult.detail);
        }

        _logger.info(
          code: 'cloud_function_invocation_succeeded',
          message: 'Cloud function invocation succeeded',
          metadata: <String, Object?>{
            'functionName': request.functionName,
            'attempt': attempt,
            'requestId': response.requestId,
          },
        );
        return AppSuccess<FunctionContractResponse>(response);
      }

      final failure =
          (invokeResult as AppFailure<FunctionContractResponse>).detail;
      final shouldRetry =
          failure.recoverable && attempt < retryPolicy.maxAttempts;
      if (!shouldRetry) {
        _logger.warning(
          code: 'cloud_function_invocation_failed',
          message: failure.developerMessage,
          metadata: <String, Object?>{
            'functionName': request.functionName,
            'attempt': attempt,
            'code': failure.code,
          },
        );
        return AppFailure<FunctionContractResponse>(failure);
      }

      final delay = retryPolicy.delayForAttempt(attempt + 1);
      _logger.warning(
        code: 'cloud_function_retry_scheduled',
        message: 'Retrying cloud function after transient failure',
        metadata: <String, Object?>{
          'functionName': request.functionName,
          'attempt': attempt,
          'nextAttempt': attempt + 1,
          'delayMs': delay.inMilliseconds,
          'failureCode': failure.code,
        },
      );
      await _delay(delay);
    }

    return AppFailure<FunctionContractResponse>(
      FailureDetail(
        code: 'cloud_function_retry_exhausted',
        developerMessage: 'Retry loop exhausted unexpectedly.',
        userMessage: 'Could not complete this action. Please retry.',
        recoverable: true,
      ),
    );
  }
}

Future<void> _noDelay(Duration _) async {}
