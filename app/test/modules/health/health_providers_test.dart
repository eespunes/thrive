import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';
import 'package:thrive_app/core/state/app_core_providers.dart';
import 'package:thrive_app/modules/health/application/health_providers.dart';
import 'package:thrive_app/modules/health/domain/health_repository.dart';

void main() {
  test('providers follow naming and lifecycle conventions', () {
    expect(healthRepositoryProvider.name, 'healthRepositoryProvider');
    expect(healthStatusProvider.name, 'healthStatusProvider');
    expect(
      healthStatusProvider,
      isA<AutoDisposeFutureProvider<AppResult<HealthStatus>>>(),
    );
  });

  test('healthStatusProvider returns deterministic AppSuccess', () async {
    final logger = InMemoryAppLogger();
    final container = ProviderContainer(
      overrides: <Override>[
        appLoggerProvider.overrideWithValue(logger),
        healthRepositoryProvider.overrideWithValue(_SuccessRepository()),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(healthStatusProvider.future);

    expect(result, isA<AppSuccess<HealthStatus>>());
    expect(logger.events.map((event) => event.code), contains('health_loaded'));
  });

  test('healthStatusProvider returns deterministic AppFailure', () async {
    final logger = InMemoryAppLogger();
    final container = ProviderContainer(
      overrides: <Override>[
        appLoggerProvider.overrideWithValue(logger),
        healthRepositoryProvider.overrideWithValue(_FailureRepository()),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(healthStatusProvider.future);

    expect(result, isA<AppFailure<HealthStatus>>());
    expect(
      logger.events.map((event) => event.code),
      contains('health_unavailable'),
    );
  });

  test('workspace switch invalidates async provider state', () async {
    final logger = InMemoryAppLogger();
    final repository = _CountingRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        appLoggerProvider.overrideWithValue(logger),
        healthRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(healthStatusProvider.future);
    expect(repository.fetchCount, 1);

    container.read(
      _workspaceSwitchHarnessProvider((
        previousWorkspaceId: 'family-a',
        nextWorkspaceId: 'family-b',
      )),
    );

    await container.read(healthStatusProvider.future);
    expect(repository.fetchCount, 2);
    expect(
      logger.events.map((event) => event.code),
      contains('workspace_switch_invalidation'),
    );
  });
}

final _workspaceSwitchHarnessProvider =
    Provider.family<
      void,
      ({String? previousWorkspaceId, String? nextWorkspaceId})
    >((ref, input) {
      invalidateHealthStateOnWorkspaceSwitch(
        ref,
        previousWorkspaceId: input.previousWorkspaceId,
        nextWorkspaceId: input.nextWorkspaceId,
      );
    });

class _SuccessRepository implements HealthRepository {
  @override
  Future<AppResult<HealthStatus>> fetchStatus() async {
    return const AppSuccess<HealthStatus>(
      HealthStatus(
        healthy: true,
        details: 'Feature module contract is configured and operational.',
      ),
    );
  }
}

class _FailureRepository implements HealthRepository {
  @override
  Future<AppResult<HealthStatus>> fetchStatus() async {
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
}

class _CountingRepository implements HealthRepository {
  int fetchCount = 0;

  @override
  Future<AppResult<HealthStatus>> fetchStatus() async {
    fetchCount += 1;
    return const AppSuccess<HealthStatus>(
      HealthStatus(
        healthy: true,
        details: 'Feature module contract is configured and operational.',
      ),
    );
  }
}
