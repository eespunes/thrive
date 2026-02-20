import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

enum BrandLogoVariant { colored, unicolor, monochrome }

class BrandAssetRegistry {
  BrandAssetRegistry({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;
  final Map<BrandLogoVariant, String> _logoAssets =
      <BrandLogoVariant, String>{};

  AppResult<void> registerThriveLogos(Map<BrandLogoVariant, String> assets) {
    if (!assets.containsKey(BrandLogoVariant.colored) ||
        !assets.containsKey(BrandLogoVariant.unicolor)) {
      const failure = FailureDetail(
        code: 'brand_assets_incomplete',
        developerMessage:
            'Thrive brand assets are incomplete. colored and unicolor are required.',
        userMessage:
            'We could not complete the brand visual setup right now.',
        recoverable: true,
      );

      _logger.error(code: failure.code, message: failure.developerMessage);
      return const AppFailure<void>(failure);
    }

    _logoAssets
      ..clear()
      ..addAll(assets);

    _logger.info(
      code: 'brand_assets_registered',
      message: 'Thrive brand assets registered',
      metadata: <String, Object?>{'assetCount': _logoAssets.length},
    );

    return const AppSuccess<void>(null);
  }

  AppResult<String> logoPath(BrandLogoVariant variant) {
    if (_logoAssets.isEmpty) {
      const failure = FailureDetail(
        code: 'brand_assets_not_registered',
        developerMessage: 'BrandAssetRegistry used before registration.',
        userMessage: 'We could not load the official logo right now.',
        recoverable: true,
      );
      _logger.warning(code: failure.code, message: failure.developerMessage);
      return const AppFailure<String>(failure);
    }

    final directPath = _logoAssets[variant];
    if (directPath != null) {
      return AppSuccess<String>(directPath);
    }

    final fallbackPath = _logoAssets[BrandLogoVariant.unicolor];
    if (fallbackPath != null) {
      _logger.warning(
        code: 'brand_asset_fallback',
        message:
            'Requested logo variant unavailable. Falling back to unicolor.',
        metadata: <String, Object?>{'requestedVariant': variant.name},
      );
      return AppSuccess<String>(fallbackPath);
    }

    const failure = FailureDetail(
      code: 'brand_asset_missing',
      developerMessage:
          'Requested logo variant missing and no fallback available.',
      userMessage: 'We could not display the official logo right now.',
      recoverable: true,
    );

    _logger.error(code: failure.code, message: failure.developerMessage);
    return const AppFailure<String>(failure);
  }
}
