import 'package:flutter/material.dart';
import 'package:thrive_app/core/architecture/module_registry.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/branding/thrive_logo.dart';
import 'package:thrive_app/core/design_system/components/thrive_primary_button.dart';
import 'package:thrive_app/core/design_system/components/thrive_surface_card.dart';
import 'package:thrive_app/core/design_system/design_tokens.dart';
import 'package:thrive_app/core/navigation/app_route_registry.dart';
import 'package:thrive_app/core/observability/app_logger.dart';

class ThriveApp extends StatelessWidget {
  const ThriveApp({
    required this.registry,
    required this.theme,
    required this.brandAssetRegistry,
    required this.logger,
    required this.routeGuardStateReader,
    super.key,
  });

  final ModuleRegistry registry;
  final ThemeData theme;
  final BrandAssetRegistry brandAssetRegistry;
  final AppLogger logger;
  final AppRouteGuardStateReader routeGuardStateReader;

  @override
  Widget build(BuildContext context) {
    final routeRegistry = AppRouteRegistry(
      featureRoutes: registry.buildFeatureRoutes(),
      logger: logger,
      routeGuardStateReader: routeGuardStateReader,
      homeBuilder: (context) =>
          _HomePage(brandAssetRegistry: brandAssetRegistry, logger: logger),
      loginBuilder: (context) =>
          _LoginPage(brandAssetRegistry: brandAssetRegistry, logger: logger),
      familyWorkspaceBuilder: (context) => const _FamilyWorkspacePage(),
      unknownRouteBuilder: (context, requestedPath) =>
          _UnknownRoutePage(requestedPath: requestedPath),
    );

    return MaterialApp(
      title: 'Thrive',
      theme: theme,
      initialRoute: AppRoutePaths.home,
      onGenerateRoute: routeRegistry.onGenerateRoute,
      onUnknownRoute: routeRegistry.onGenerateRoute,
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.brandAssetRegistry, required this.logger});

  final BrandAssetRegistry brandAssetRegistry;
  final AppLogger logger;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thrive')),
      body: Padding(
        padding: const EdgeInsets.all(ThriveSpacing.lg),
        child: ThriveSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ThriveLogo(registry: brandAssetRegistry, logger: logger),
              const SizedBox(height: ThriveSpacing.lg),
              Text(
                'Family finance that everyone can use.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ThriveSpacing.lg),
              ThrivePrimaryButton(
                onPressed: () => Navigator.of(context).pushNamed('/health'),
                label: 'Open Health Module',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginPage extends StatelessWidget {
  const _LoginPage({required this.brandAssetRegistry, required this.logger});

  final BrandAssetRegistry brandAssetRegistry;
  final AppLogger logger;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ThriveSpacing.lg),
          child: ThriveSurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ThriveLogo(registry: brandAssetRegistry, logger: logger),
                const SizedBox(height: ThriveSpacing.lg),
                Text(
                  'Welcome to Thrive',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: ThriveSpacing.md),
                ThrivePrimaryButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutePaths.home,
                        (route) => false,
                      ),
                  label: 'Continue with Google',
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutePaths.home),
                  child: const Text('or sign in with email'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FamilyWorkspacePage extends StatelessWidget {
  const _FamilyWorkspacePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Workspace')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ThriveSpacing.lg),
          child: ThriveSurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Select or create your family workspace.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ThriveSpacing.lg),
                ThrivePrimaryButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutePaths.home,
                        (route) => false,
                      ),
                  label: 'Back to Home',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnknownRoutePage extends StatelessWidget {
  const _UnknownRoutePage({required this.requestedPath});

  final String requestedPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ThriveSpacing.lg),
          child: ThriveSurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'We could not open that page.',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ThriveSpacing.sm),
                Text(
                  'Requested route: $requestedPath',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ThriveSpacing.lg),
                ThrivePrimaryButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutePaths.home,
                        (route) => false,
                      ),
                  label: 'Go Home',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
