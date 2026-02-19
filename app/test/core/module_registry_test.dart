import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/branding/thrive_branding.dart';
import 'package:thrive_app/core/architecture/module_registry.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/modules/health/health_module.dart';

void main() {
  test('registers module routes and emits observability events', () {
    final logger = InMemoryAppLogger();
    final brandAssetRegistry = BrandAssetRegistry(logger: logger);
    ThriveBranding.registerOfficialAssets(brandAssetRegistry);
    final registry = ModuleRegistry(logger: logger);

    registry.registerModule(
      HealthModule(brandAssetRegistry: brandAssetRegistry),
    );

    final routes = registry.buildRoutes();
    expect(routes.containsKey('/health'), isTrue);

    final codes = logger.events.map((event) => event.code).toList();
    expect(codes, contains('feature_module_configured'));
    expect(codes, contains('module_registered'));
  });

  test('fails deterministically on duplicated routes', () {
    final logger = InMemoryAppLogger();
    final brandAssetRegistry = BrandAssetRegistry(logger: logger);
    ThriveBranding.registerOfficialAssets(brandAssetRegistry);
    final registry = ModuleRegistry(logger: logger);

    registry.registerModule(
      HealthModule(brandAssetRegistry: brandAssetRegistry),
    );

    expect(
      () => registry.registerModule(
        HealthModule(brandAssetRegistry: brandAssetRegistry),
      ),
      throwsStateError,
    );
  });
}
