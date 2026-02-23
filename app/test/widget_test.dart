import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/app.dart';
import 'package:thrive_app/core/architecture/module_registry.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/branding/thrive_branding.dart';
import 'package:thrive_app/core/design_system/thrive_theme.dart';
import 'package:thrive_app/core/navigation/app_route_registry.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/version/spec_version.dart';
import 'package:thrive_app/modules/health/health_module.dart';

void main() {
  testWidgets('shows home action for registered modules', (tester) async {
    final logger = InMemoryAppLogger();
    final brandAssetRegistry = BrandAssetRegistry(logger: logger);
    ThriveBranding.registerOfficialAssets(brandAssetRegistry);
    final theme = ThriveTheme.build(logger: logger);
    final registry = ModuleRegistry(logger: logger)
      ..registerModule(HealthModule(brandAssetRegistry: brandAssetRegistry));

    await tester.pumpWidget(
      ThriveApp(
        registry: registry,
        theme: theme,
        brandAssetRegistry: brandAssetRegistry,
        logger: logger,
        routeGuardStateReader: () => const AppRouteGuardState(
          isAuthenticated: true,
          hasActiveFamilyWorkspace: true,
        ),
      ),
    );

    expect(find.text('Open Health Module'), findsOneWidget);
    expect(find.text(thriveVersionLabel), findsOneWidget);
  });
}
