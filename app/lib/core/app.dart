import 'package:flutter/material.dart';
import 'package:thrive_app/core/architecture/module_registry.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/branding/thrive_logo.dart';
import 'package:thrive_app/core/design_system/components/thrive_primary_button.dart';
import 'package:thrive_app/core/design_system/components/thrive_surface_card.dart';
import 'package:thrive_app/core/design_system/design_tokens.dart';
import 'package:thrive_app/core/observability/app_logger.dart';

class ThriveApp extends StatelessWidget {
  const ThriveApp({
    required this.registry,
    required this.theme,
    required this.brandAssetRegistry,
    required this.logger,
    super.key,
  });

  final ModuleRegistry registry;
  final ThemeData theme;
  final BrandAssetRegistry brandAssetRegistry;
  final AppLogger logger;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thrive',
      theme: theme,
      routes: registry.buildRoutes(),
      home: _HomePage(brandAssetRegistry: brandAssetRegistry, logger: logger),
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
