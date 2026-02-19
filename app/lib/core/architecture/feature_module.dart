import 'package:flutter/widgets.dart';
import 'package:thrive_app/core/observability/app_logger.dart';

typedef FeatureRouteBuilder = Widget Function(BuildContext context);

class FeatureRoute {
  const FeatureRoute({required this.path, required this.builder});

  final String path;
  final FeatureRouteBuilder builder;
}

abstract interface class FeatureModule {
  String get id;
  void configure(AppLogger logger);
  List<FeatureRoute> get routes;
}
