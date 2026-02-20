import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/branding/thrive_branding.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('registers official assets and resolves direct path', () {
    final logger = InMemoryAppLogger();
    final registry = BrandAssetRegistry(logger: logger);

    final registerResult = ThriveBranding.registerOfficialAssets(registry);
    final pathResult = registry.logoPath(BrandLogoVariant.colored);

    expect(registerResult, isA<AppSuccess<void>>());
    expect(pathResult, isA<AppSuccess<String>>());
    final path = (pathResult as AppSuccess<String>).value;
    expect(path, ThriveBranding.coloredLogoPath);
    expect(
      logger.events.any((event) => event.code == 'brand_assets_registered'),
      isTrue,
    );
  });

  test('returns user-safe failure when registry is not initialized', () {
    final logger = InMemoryAppLogger();
    final registry = BrandAssetRegistry(logger: logger);

    final result = registry.logoPath(BrandLogoVariant.colored);

    expect(result, isA<AppFailure<String>>());
    final detail = (result as AppFailure<String>).detail;
    expect(
      detail.userMessage,
      'We could not load the official logo right now.',
    );
    expect(logger.events.last.code, 'brand_assets_not_registered');
  });

  test('falls back deterministically when variant is unavailable', () {
    final logger = InMemoryAppLogger();
    final registry = BrandAssetRegistry(logger: logger);
    ThriveBranding.registerOfficialAssets(registry);

    final result = registry.logoPath(BrandLogoVariant.monochrome);

    expect(result, isA<AppSuccess<String>>());
    final path = (result as AppSuccess<String>).value;
    expect(path, ThriveBranding.unicolorLogoPath);
    expect(logger.events.last.code, 'brand_asset_fallback');
  });
}
