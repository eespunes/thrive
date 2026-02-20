import 'package:thrive_app/core/result/app_result.dart';
import 'package:thrive_app/modules/health/domain/health_repository.dart';

class HealthRepositoryImpl implements HealthRepository {
  HealthRepositoryImpl({this.shouldFail = false});

  final bool shouldFail;

  @override
  Future<AppResult<HealthStatus>> fetchStatus() async {
    if (shouldFail) {
      return const AppFailure<HealthStatus>(
        FailureDetail(
          code: 'health_unavailable',
          developerMessage: 'Health probe could not reach data source',
          userMessage:
              'We could not check the status right now. Please try again in a few minutes.',
          recoverable: true,
        ),
      );
    }

    return const AppSuccess<HealthStatus>(
      HealthStatus(
        healthy: true,
        details: 'Feature module contract is configured and operational.',
      ),
    );
  }
}
