import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/app.dart';
import 'package:thrive_app/core/architecture/module_registry.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/modules/health/health_module.dart';

void main() {
  testWidgets('shows home action for registered modules', (tester) async {
    final registry = ModuleRegistry(logger: InMemoryAppLogger())
      ..registerModule(HealthModule());

    await tester.pumpWidget(ThriveApp(registry: registry));

    expect(find.text('Open Health Module'), findsOneWidget);
  });
}
