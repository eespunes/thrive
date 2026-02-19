import 'package:flutter/material.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/branding/thrive_logo.dart';
import 'package:thrive_app/core/design_system/design_tokens.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';
import 'package:thrive_app/modules/health/application/health_controller.dart';
import 'package:thrive_app/modules/health/domain/health_repository.dart';

class HealthPage extends StatelessWidget {
  const HealthPage({
    required this.controller,
    required this.brandAssetRegistry,
    required this.logger,
    super.key,
  });

  final HealthController controller;
  final BrandAssetRegistry brandAssetRegistry;
  final AppLogger logger;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Module')),
      body: FutureBuilder<AppResult<HealthStatus>>(
        future: controller.loadStatus(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return snapshot.data!.when(
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
          );
        },
      ),
    );
  }
}
