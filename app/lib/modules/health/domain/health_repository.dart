import 'package:thrive_app/core/result/app_result.dart';

class HealthStatus {
  const HealthStatus({required this.healthy, required this.details});

  final bool healthy;
  final String details;
}

abstract interface class HealthRepository {
  Future<AppResult<HealthStatus>> fetchStatus();
}
