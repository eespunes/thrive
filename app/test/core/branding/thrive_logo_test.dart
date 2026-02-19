import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/branding/thrive_branding.dart';
import 'package:thrive_app/core/branding/thrive_logo.dart';
import 'package:thrive_app/core/observability/app_logger.dart';

void main() {
  testWidgets('renders svg when asset loading succeeds', (tester) async {
    final logger = InMemoryAppLogger();
    final registry = BrandAssetRegistry(logger: logger);
    ThriveBranding.registerOfficialAssets(registry);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThriveLogo(
            registry: registry,
            logger: logger,
            assetLoader: (_) async =>
                '<svg viewBox="0 0 10 10"><rect width="10" height="10" /></svg>',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('shows fallback when asset loading fails', (tester) async {
    final logger = InMemoryAppLogger();
    final registry = BrandAssetRegistry(logger: logger);
    ThriveBranding.registerOfficialAssets(registry);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThriveLogo(
            registry: registry,
            logger: logger,
            assetLoader: (_) => Future<String>.error(Exception('missing file')),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Logo no disponible'), findsOneWidget);
    expect(logger.events.last.code, 'brand_asset_render_failed');
  });
}
