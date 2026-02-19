import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/design_system/design_tokens.dart';
import 'package:thrive_app/core/observability/app_logger.dart';

typedef SvgAssetLoader = Future<String> Function(String assetPath);

class ThriveLogo extends StatelessWidget {
  const ThriveLogo({
    required this.registry,
    required this.logger,
    this.variant = BrandLogoVariant.colored,
    this.width = 168,
    this.height = 54,
    this.assetLoader,
    super.key,
  });

  final BrandAssetRegistry registry;
  final AppLogger logger;
  final BrandLogoVariant variant;
  final double width;
  final double height;
  final SvgAssetLoader? assetLoader;

  @override
  Widget build(BuildContext context) {
    final pathResult = registry.logoPath(variant);

    return pathResult.when(
      success: (assetPath) {
        final load = assetLoader ?? rootBundle.loadString;

        return FutureBuilder<String>(
          future: load(assetPath),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return SizedBox(
                width: width,
                height: height,
                child: const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading logo',
                  ),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              logger.error(
                code: 'brand_asset_render_failed',
                message: 'Failed to render Thrive logo asset.',
                metadata: <String, Object?>{
                  'variant': variant.name,
                  'assetPath': assetPath,
                  'error': snapshot.error?.toString(),
                },
              );
              return _LogoFallback(
                message: 'Logo no disponible',
                width: width,
                height: height,
              );
            }

            return SvgPicture.string(
              snapshot.data!,
              width: width,
              height: height,
              semanticsLabel: 'Thrive logo',
            );
          },
        );
      },
      failure: (failure) => _LogoFallback(
        message: failure.userMessage,
        width: width,
        height: height,
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({
    required this.message,
    required this.width,
    required this.height,
  });

  final String message;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ThriveRadius.card,
        border: Border.all(color: ThriveColors.mint),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
