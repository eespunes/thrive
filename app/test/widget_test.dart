import 'package:flutter/material.dart';
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

const Duration _startupRoutingWait = Duration(milliseconds: 320);

Future<void> _pumpPastSplashStartupRouting(WidgetTester tester) async {
  await tester.pump(_startupRoutingWait);
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('shows branded splash at app startup', (tester) async {
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
          isAuthenticated: false,
          hasActiveFamilyWorkspace: false,
        ),
      ),
    );

    expect(find.byKey(const Key('thrive_splash_screen')), findsOneWidget);
    expect(find.text('Thrive'), findsOneWidget);

    // Drain splash timer so no pending timers remain after test teardown.
    await _pumpPastSplashStartupRouting(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('routes unauthenticated users to login after splash', (
    tester,
  ) async {
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
          isAuthenticated: false,
          hasActiveFamilyWorkspace: false,
        ),
      ),
    );
    await _pumpPastSplashStartupRouting(tester);

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('routes authenticated users to home after splash', (
    tester,
  ) async {
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
    await _pumpPastSplashStartupRouting(tester);

    expect(find.text('Open Health Module'), findsOneWidget);
    expect(find.text(thriveVersionLabel), findsOneWidget);
  });
}
