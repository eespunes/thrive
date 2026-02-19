import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/branding/thrive_logo.dart';
import 'package:thrive_app/core/design_system/design_tokens.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/modules/health/application/health_providers.dart';

class HealthPage extends ConsumerWidget {
  const HealthPage({
    required this.brandAssetRegistry,
    required this.logger,
    super.key,
  });

  final BrandAssetRegistry brandAssetRegistry;
  final AppLogger logger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(healthStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Module'),
        actions: <Widget>[
          IconButton(
            onPressed: () => refreshHealthStatus(ref),
            tooltip: 'Refresh status',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        data: (result) => result.when(
          success: (status) => Center(
            child: Padding(
              padding: const EdgeInsets.all(ThriveSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ThriveLogo(
                    registry: brandAssetRegistry,
                    logger: logger,
                    variant: BrandLogoVariant.unicolor,
                  ),
                  const SizedBox(height: ThriveSpacing.lg),
                  Icon(
                    status.healthy ? Icons.check_circle : Icons.warning,
                    color: status.healthy
                        ? ThriveColors.success
                        : ThriveColors.warning,
                    size: 56,
                  ),
                  const SizedBox(height: ThriveSpacing.md),
                  Text(status.details, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          failure: (failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(ThriveSpacing.lg),
              child: Text(
                failure.userMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
        error: (error, stackTrace) {
          logger.error(
            code: 'health_provider_unhandled_error',
            message: 'Unhandled async error surfaced by healthStatusProvider',
            metadata: <String, Object?>{'error': error.toString()},
          );
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(ThriveSpacing.lg),
              child: Text(
                'No pudimos revisar el estado ahora. Intenta nuevamente en unos minutos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        },
      ),
    );
  }
}
