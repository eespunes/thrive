import 'package:flutter/widgets.dart';
import 'package:thrive_app/core/app.dart';
import 'package:thrive_app/core/architecture/module_registry.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/branding/thrive_branding.dart';
import 'package:thrive_app/core/design_system/thrive_theme.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/modules/health/health_module.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = InMemoryAppLogger();
  final brandAssetRegistry = BrandAssetRegistry(logger: logger);
  ThriveBranding.registerOfficialAssets(brandAssetRegistry);
  final theme = ThriveTheme.build(logger: logger);

  final registry = ModuleRegistry(logger: logger)
    ..registerModule(HealthModule(brandAssetRegistry: brandAssetRegistry));

  runApp(
    ThriveApp(
      registry: registry,
      theme: theme,
      brandAssetRegistry: brandAssetRegistry,
      logger: logger,
    ),
  );
}
