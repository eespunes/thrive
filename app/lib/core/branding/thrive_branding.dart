import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/result/app_result.dart';

abstract final class ThriveBranding {
  static const String coloredLogoPath = 'assets/logos/thrive-colored.svg';
  static const String unicolorLogoPath = 'assets/logos/thrive-unicolor.svg';

  static AppResult<void> registerOfficialAssets(BrandAssetRegistry registry) {
    return registry.registerThriveLogos(<BrandLogoVariant, String>{
      BrandLogoVariant.colored: coloredLogoPath,
      BrandLogoVariant.unicolor: unicolorLogoPath,
    });
  }
}
