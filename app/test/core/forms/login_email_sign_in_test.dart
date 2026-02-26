import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/app.dart';
import 'package:thrive_app/core/architecture/module_registry.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/branding/thrive_branding.dart';
import 'package:thrive_app/core/design_system/thrive_theme.dart';
import 'package:thrive_app/core/navigation/app_route_registry.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/modules/health/health_module.dart';

void main() {
  testWidgets(
    'shows field-level validation errors when email form is invalid',
    (tester) async {
      final logger = InMemoryAppLogger();
      await tester.pumpWidget(_buildTestApp(logger: logger));
      await _pumpUntilVisible(tester, find.text('or sign in with email'));

      await tester.tap(find.text('or sign in with email'));
      await _pumpFrames(tester);

      await tester.tap(find.text('Sign in with email'));
      await _pumpFrames(tester);

      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
      expect(
        logger.events.map((event) => event.code),
        contains('form_validation_failed'),
      );
    },
  );

  testWidgets('shows mapped backend error and retry action', (tester) async {
    final logger = InMemoryAppLogger();
    await tester.pumpWidget(_buildTestApp(logger: logger));
    await _pumpUntilVisible(tester, find.text('or sign in with email'));

    await tester.tap(find.text('or sign in with email'));
    await _pumpFrames(tester);

    await tester.enterText(
      find.byKey(const Key('email_sign_in_email_field')),
      'server@thrive.dev',
    );
    await tester.enterText(
      find.byKey(const Key('email_sign_in_password_field')),
      'thrive123',
    );

    await tester.tap(find.text('Sign in with email'));
    await tester.pump(const Duration(milliseconds: 350));
    await _pumpFrames(tester);

    expect(
      find.text(
        'Our services are currently unavailable. Please try again in a few minutes.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('email_sign_in_retry_button')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('email_sign_in_retry_button')),
    );
    await tester.tap(find.byKey(const Key('email_sign_in_retry_button')));
    await tester.pump(const Duration(milliseconds: 350));
    await _pumpFrames(tester);

    expect(
      logger.events.map((event) => event.code),
      contains('email_sign_in_retry_requested'),
    );
  });

  testWidgets('retry revalidates edited fields before submitting', (
    tester,
  ) async {
    final logger = InMemoryAppLogger();
    await tester.pumpWidget(_buildTestApp(logger: logger));
    await _pumpUntilVisible(tester, find.text('or sign in with email'));

    await tester.tap(find.text('or sign in with email'));
    await _pumpFrames(tester);

    await tester.enterText(
      find.byKey(const Key('email_sign_in_email_field')),
      'server@thrive.dev',
    );
    await tester.enterText(
      find.byKey(const Key('email_sign_in_password_field')),
      'thrive123',
    );

    await tester.tap(find.text('Sign in with email'));
    await tester.pump(const Duration(milliseconds: 350));
    await _pumpFrames(tester);

    expect(find.byKey(const Key('email_sign_in_retry_button')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('email_sign_in_email_field')),
      'invalid-email',
    );

    await tester.ensureVisible(
      find.byKey(const Key('email_sign_in_retry_button')),
    );
    await tester.tap(find.byKey(const Key('email_sign_in_retry_button')));
    await _pumpFrames(tester);

    expect(find.text('Enter a valid email.'), findsOneWidget);
    expect(
      logger.events.map((event) => event.code),
      contains('form_validation_failed'),
    );
  });
}

Widget _buildTestApp({required InMemoryAppLogger logger}) {
  final brandAssetRegistry = BrandAssetRegistry(logger: logger);
  ThriveBranding.registerOfficialAssets(brandAssetRegistry);
  final theme = ThriveTheme.build(logger: logger);
  final registry = ModuleRegistry(logger: logger)
    ..registerModule(HealthModule(brandAssetRegistry: brandAssetRegistry));

  return ThriveApp(
    registry: registry,
    theme: theme,
    brandAssetRegistry: brandAssetRegistry,
    logger: logger,
    routeGuardStateReader: () => const AppRouteGuardState(
      isAuthenticated: false,
      hasActiveFamilyWorkspace: false,
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _pumpUntilVisible(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Expected finder to become visible within timeout: $finder');
}
