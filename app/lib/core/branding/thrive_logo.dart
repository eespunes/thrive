import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/design_system/design_tokens.dart';
import 'package:thrive_app/core/observability/app_logger.dart';

typedef SvgAssetLoader = Future<String> Function(String assetPath);

class ThriveLogo extends StatefulWidget {
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
  State<ThriveLogo> createState() => _ThriveLogoState();
}

class _ThriveLogoState extends State<ThriveLogo> {
  String? _cachedAssetPath;
  SvgAssetLoader? _cachedLoader;
  Future<String>? _cachedFuture;

  Future<String> _loadWithLogging({
    required String assetPath,
    required SvgAssetLoader loader,
  }) async {
    try {
      return await loader(assetPath);
    } catch (error) {
      widget.logger.error(
        code: 'brand_asset_render_failed',
        message: 'Failed to render Thrive logo asset.',
        metadata: <String, Object?>{
          'variant': widget.variant.name,
          'assetPath': assetPath,
          'error': error.toString(),
        },
      );
      rethrow;
    }
  }

  Future<String> _logoFuture({
    required String assetPath,
    required SvgAssetLoader loader,
  }) {
    final shouldRefresh =
        _cachedFuture == null ||
        _cachedAssetPath != assetPath ||
        !identical(_cachedLoader, loader);

    if (shouldRefresh) {
      _cachedAssetPath = assetPath;
      _cachedLoader = loader;
      _cachedFuture = _loadWithLogging(assetPath: assetPath, loader: loader);
    }

    return _cachedFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final pathResult = widget.registry.logoPath(widget.variant);

    return pathResult.when(
      success: (assetPath) {
        final load = widget.assetLoader ?? rootBundle.loadString;

        return FutureBuilder<String>(
          future: _logoFuture(assetPath: assetPath, loader: load),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return SizedBox(
                width: widget.width,
                height: widget.height,
                child: const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading logo',
                  ),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return _LogoFallback(
                message: 'Logo no disponible',
                width: widget.width,
                height: widget.height,
              );
            }

            return SvgPicture.string(
              snapshot.data!,
              width: widget.width,
              height: widget.height,
              semanticsLabel: 'Thrive logo',
            );
          },
        );
      },
      failure: (failure) => _LogoFallback(
        message: failure.userMessage,
        width: widget.width,
        height: widget.height,
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
