import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/state/thrive_provider_observer.dart';

void main() {
  test('logs provider lifecycle add/update/dispose', () {
    final logger = InMemoryAppLogger();
    final container = ProviderContainer(
      observers: <ProviderObserver>[ThriveProviderObserver(logger: logger)],
    );

    final testProvider = StateProvider<int>(
      (ref) => 0,
      name: 'testStateProvider',
    );

    expect(container.read(testProvider), 0);
    container.read(testProvider.notifier).state = 1;
    container.dispose();

    final codes = logger.events.map((event) => event.code).toList();
    expect(codes, contains('provider_added'));
    expect(codes, contains('provider_updated'));
    expect(codes, contains('provider_disposed'));
  });

  test('logs provider failures', () {
    final logger = InMemoryAppLogger();
    final container = ProviderContainer(
      observers: <ProviderObserver>[ThriveProviderObserver(logger: logger)],
    );
    addTearDown(container.dispose);

    final failingProvider = Provider<int>(
      (ref) => throw StateError('boom'),
      name: 'failingProvider',
    );

    expect(() => container.read(failingProvider), throwsStateError);

    final failureEvent = logger.events.lastWhere(
      (event) => event.code == 'provider_failed',
    );
    expect(failureEvent.metadata['provider'], 'failingProvider');
  });
}
