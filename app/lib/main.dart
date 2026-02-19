import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thrive_app/core/app.dart';
import 'package:thrive_app/core/architecture/module_registry.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/branding/thrive_branding.dart';
import 'package:thrive_app/core/design_system/thrive_theme.dart';
import 'package:thrive_app/core/navigation/app_route_registry.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/state/app_core_providers.dart';
import 'package:thrive_app/core/state/thrive_provider_observer.dart';
import 'package:thrive_app/modules/health/health_module.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = InMemoryAppLogger();
  final brandAssetRegistry = BrandAssetRegistry(logger: logger);
  ThriveBranding.registerOfficialAssets(brandAssetRegistry);
  final theme = ThriveTheme.build(logger: logger);
  final routeGuardState = ValueNotifier<AppRouteGuardState>(
    const AppRouteGuardState(
      isAuthenticated: bool.fromEnvironment(
        'THRIVE_AUTHENTICATED',
        defaultValue: false,
      ),
      hasActiveFamilyWorkspace: bool.fromEnvironment(
        'THRIVE_HAS_ACTIVE_FAMILY_WORKSPACE',
        defaultValue: false,
      ),
    ),
  );

  final registry = ModuleRegistry(logger: logger)
    ..registerModule(HealthModule(brandAssetRegistry: brandAssetRegistry));

  runApp(
    ProviderScope(
      observers: <ProviderObserver>[ThriveProviderObserver(logger: logger)],
      overrides: <Override>[appLoggerProvider.overrideWithValue(logger)],
      child: ThriveApp(
        registry: registry,
        theme: theme,
        brandAssetRegistry: brandAssetRegistry,
        logger: logger,
        routeGuardStateReader: () => routeGuardState.value,
      ),
    ),
  );
}
