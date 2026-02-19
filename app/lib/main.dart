import 'package:flutter/widgets.dart';
import 'package:thrive_app/core/app.dart';
import 'package:thrive_app/core/architecture/module_registry.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/modules/health/health_module.dart';

void main() {
  final logger = InMemoryAppLogger();
  final registry = ModuleRegistry(logger: logger)
    ..registerModule(HealthModule());

  runApp(ThriveApp(registry: registry));
}
