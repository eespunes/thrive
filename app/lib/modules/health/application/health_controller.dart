import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';
import 'package:thrive_app/modules/health/domain/health_repository.dart';

class HealthController {
  HealthController({
    required HealthRepository repository,
    required AppLogger logger,
  }) : _repository = repository,
       _logger = logger;

  final HealthRepository _repository;
  final AppLogger _logger;

  Future<AppResult<HealthStatus>> loadStatus() async {
    final result = await _repository.fetchStatus();

    result.when(
      success: (status) {
        _logger.info(
          code: 'health_loaded',
          message: 'Health status loaded',
          metadata: <String, Object?>{'healthy': status.healthy},
        );
      },
      failure: (failure) {
        _logger.error(
          code: failure.code,
          message: failure.developerMessage,
          metadata: <String, Object?>{'recoverable': failure.recoverable},
        );
      },
    );

    return result;
  }
}
