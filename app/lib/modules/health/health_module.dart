import 'package:thrive_app/core/architecture/feature_module.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/modules/health/application/health_controller.dart';
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

    final controller = HealthController(
      repository: HealthRepositoryImpl(shouldFail: shouldFail),
      logger: logger,
    );

    return <FeatureRoute>[
      FeatureRoute(
        path: '/health',
        builder: (context) => HealthPage(
          controller: controller,
          brandAssetRegistry: brandAssetRegistry,
          logger: logger,
        ),
      ),
    ];
  }
}
