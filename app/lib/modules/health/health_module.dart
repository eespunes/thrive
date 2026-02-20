import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thrive_app/core/architecture/feature_module.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/state/app_core_providers.dart';
import 'package:thrive_app/modules/health/application/health_providers.dart';
import 'package:thrive_app/modules/health/data/health_repository_impl.dart';
import 'package:thrive_app/modules/health/presentation/health_page.dart';

class HealthModule implements FeatureModule {
  HealthModule({required this.brandAssetRegistry, this.shouldFail = false});

  final BrandAssetRegistry brandAssetRegistry;
  final bool shouldFail;
  AppLogger? _logger;

  @override
  String get id => 'health';

  @override
  void configure(AppLogger logger) {
    _logger = logger;
    logger.info(
      code: 'feature_module_configured',
      message: 'Feature module configured',
      metadata: <String, Object?>{'module': id},
    );
  }

  @override
  List<FeatureRoute> get routes {
    final logger = _logger;
    if (logger == null) {
      throw StateError('Module must be configured before routes can be read.');
    }

    return <FeatureRoute>[
      FeatureRoute(
        path: '/health',
        requiresAuthentication: true,
        requiresFamilyWorkspace: true,
        builder: (context) => ProviderScope(
          overrides: <Override>[
            appLoggerProvider.overrideWithValue(logger),
            healthRepositoryProvider.overrideWithValue(
              HealthRepositoryImpl(shouldFail: shouldFail),
            ),
          ],
          child: HealthPage(
            brandAssetRegistry: brandAssetRegistry,
            logger: logger,
          ),
        ),
      ),
    ];
  }
}
