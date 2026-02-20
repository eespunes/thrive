import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';
import 'package:thrive_app/modules/health/application/health_controller.dart';
import 'package:thrive_app/modules/health/data/health_repository_impl.dart';
import 'package:thrive_app/modules/health/domain/health_repository.dart';

void main() {
  test('returns success and logs info on healthy path', () async {
    final logger = InMemoryAppLogger();
    final controller = HealthController(
      repository: HealthRepositoryImpl(),
      logger: logger,
    );

    final result = await controller.loadStatus();

    expect(result, isA<AppSuccess<HealthStatus>>());
    expect(logger.events.last.code, 'health_loaded');
  });

  test('returns failure with user-safe message and logs error', () async {
    final logger = InMemoryAppLogger();
    final controller = HealthController(
      repository: HealthRepositoryImpl(shouldFail: true),
      logger: logger,
    );

    final result = await controller.loadStatus();

    expect(result, isA<AppFailure<HealthStatus>>());
    final detail = (result as AppFailure<HealthStatus>).detail;
    expect(
      detail.userMessage,
      'We could not check the status right now. Please try again in a few minutes.',
    );
    expect(logger.events.last.level.name, 'error');
    expect(logger.events.last.code, 'health_unavailable');
  });
}
