import 'package:flutter/material.dart';
import 'package:thrive_app/core/architecture/feature_module.dart';
import 'package:thrive_app/core/observability/app_logger.dart';

class ModuleRegistry {
  ModuleRegistry({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;
  final Map<String, FeatureRouteBuilder> _routes = {};

  void registerModule(FeatureModule module) {
    module.configure(_logger);

    for (final route in module.routes) {
      if (_routes.containsKey(route.path)) {
        throw StateError('Route already registered: ${route.path}');
      }
      _routes[route.path] = route.builder;
    }

    _logger.info(
      code: 'module_registered',
      message: 'Module ${module.id} registered',
      metadata: <String, Object?>{
        'module': module.id,
        'routeCount': module.routes.length,
      },
    );
  }

  Map<String, WidgetBuilder> buildRoutes() {
    return Map<String, WidgetBuilder>.unmodifiable(
      _routes.map(
        (path, builder) => MapEntry<String, WidgetBuilder>(
          path,
          (context) => builder(context),
        ),
      ),
    );
  }
}
