import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thrive_app/core/observability/app_logger.dart';

class ThriveProviderObserver extends ProviderObserver {
  ThriveProviderObserver({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    _logger.info(
      code: 'provider_added',
      message: 'Provider instantiated',
      metadata: _metadataFor(provider: provider, value: value),
    );
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    _logger.info(
      code: 'provider_disposed',
      message: 'Provider disposed',
      metadata: _metadataFor(provider: provider),
    );
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    _logger.info(
      code: 'provider_updated',
      message: 'Provider state updated',
      metadata: _metadataFor(provider: provider, value: newValue),
    );
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    _logger.error(
      code: 'provider_failed',
      message: 'Provider emitted an error',
      metadata: <String, Object?>{
        ..._metadataFor(provider: provider),
        'error': error.toString(),
      },
    );
  }

  Map<String, Object?> _metadataFor({
    required ProviderBase<Object?> provider,
    Object? value,
  }) {
    return <String, Object?>{
      'provider': provider.name ?? provider.runtimeType.toString(),
      'providerType': provider.runtimeType.toString(),
      if (value != null) 'valueType': value.runtimeType.toString(),
    };
  }
}
