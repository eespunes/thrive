import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thrive_app/core/result/app_result.dart';
import 'package:thrive_app/core/state/app_core_providers.dart';
import 'package:thrive_app/modules/health/domain/health_repository.dart';

final healthRepositoryProvider = Provider.autoDispose<HealthRepository>(
  (ref) => throw StateError(
    'healthRepositoryProvider must be overridden by the owning feature module.',
  ),
  name: 'healthRepositoryProvider',
);

final healthStatusProvider =
    FutureProvider.autoDispose<AppResult<HealthStatus>>((ref) async {
      final repository = ref.watch(healthRepositoryProvider);
      final logger = ref.watch(appLoggerProvider);
      final result = await repository.fetchStatus();

      result.when(
        success: (status) {
          logger.info(
            code: 'health_loaded',
            message: 'Health status loaded',
            metadata: <String, Object?>{'healthy': status.healthy},
          );
        },
        failure: (failure) {
          logger.error(
            code: failure.code,
            message: failure.developerMessage,
            metadata: <String, Object?>{'recoverable': failure.recoverable},
          );
        },
      );

      return result;
    }, name: 'healthStatusProvider');

void refreshHealthStatus(WidgetRef ref) {
  ref.invalidate(healthStatusProvider);
  ref
      .read(appLoggerProvider)
      .info(
        code: 'provider_refresh_requested',
        message: 'Provider invalidated by explicit refresh action',
        metadata: <String, Object?>{'provider': healthStatusProvider.name},
      );
}

void invalidateHealthStateOnWorkspaceSwitch(
  Ref ref, {
  required String? previousWorkspaceId,
  required String? nextWorkspaceId,
}) {
  if (previousWorkspaceId == nextWorkspaceId) {
    return;
  }

  ref.invalidate(healthStatusProvider);
  ref
      .read(appLoggerProvider)
      .info(
        code: 'workspace_switch_invalidation',
        message: 'Invalidated health providers after workspace switch',
        metadata: <String, Object?>{
          'provider': healthStatusProvider.name,
          'previousWorkspaceId': previousWorkspaceId,
          'nextWorkspaceId': nextWorkspaceId,
        },
      );
}
