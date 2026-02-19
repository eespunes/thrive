import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/architecture/feature_module.dart';
import 'package:thrive_app/core/navigation/app_route_registry.dart';
import 'package:thrive_app/core/observability/app_logger.dart';

void main() {
  testWidgets('allows protected navigation when guard conditions are met', (
    tester,
  ) async {
    final logger = InMemoryAppLogger();
    final app = _buildApp(
      logger: logger,
      state: const AppRouteGuardState(
        isAuthenticated: true,
        hasActiveFamilyWorkspace: true,
      ),
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    final navigatorState = tester.state<NavigatorState>(find.byType(Navigator));
    navigatorState.pushNamed('/health');
    await tester.pumpAndSettle();

    expect(find.text('Health'), findsOneWidget);

    final routeResolved = logger.events.any(
      (event) =>
          event.code == 'route_navigation_resolved' &&
          event.metadata['requestedPath'] == '/health' &&
          event.metadata['resolvedPath'] == '/health',
    );
    expect(routeResolved, isTrue);
  });

  testWidgets('redirects to login when route requires authentication', (
    tester,
  ) async {
    final logger = InMemoryAppLogger();
    final app = _buildApp(
      logger: logger,
      state: const AppRouteGuardState(
        isAuthenticated: false,
        hasActiveFamilyWorkspace: false,
      ),
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    final navigatorState = tester.state<NavigatorState>(find.byType(Navigator));
    navigatorState.pushNamed('/health');
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);

    final guardEvent = logger.events.lastWhere(
      (event) => event.code == 'route_guard_blocked',
    );
    expect(guardEvent.metadata['resolvedPath'], '/login');
    expect(guardEvent.metadata['reason'], 'auth_required');
  });

  testWidgets('redirects to family route when workspace is missing', (
    tester,
  ) async {
    final logger = InMemoryAppLogger();
    final app = _buildApp(
      logger: logger,
      state: const AppRouteGuardState(
        isAuthenticated: true,
        hasActiveFamilyWorkspace: false,
      ),
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    final navigatorState = tester.state<NavigatorState>(find.byType(Navigator));
    navigatorState.pushNamed('/health');
    await tester.pumpAndSettle();

    expect(find.text('Family'), findsOneWidget);

    final guardEvent = logger.events.lastWhere(
      (event) => event.code == 'route_guard_blocked',
    );
    expect(guardEvent.metadata['resolvedPath'], '/family/workspace');
    expect(guardEvent.metadata['reason'], 'family_workspace_required');
  });

  testWidgets('normalizes deep-link route names with query params', (
    tester,
  ) async {
    final logger = InMemoryAppLogger();
    final app = _buildApp(
      logger: logger,
      state: const AppRouteGuardState(
        isAuthenticated: true,
        hasActiveFamilyWorkspace: true,
      ),
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    final navigatorState = tester.state<NavigatorState>(find.byType(Navigator));
    navigatorState.pushNamed('/health?source=notification');
    await tester.pumpAndSettle();

    expect(find.text('Health'), findsOneWidget);
  });

  testWidgets('renders unknown route fallback for unregistered routes', (
    tester,
  ) async {
    final logger = InMemoryAppLogger();
    final app = _buildApp(
      logger: logger,
      state: const AppRouteGuardState(
        isAuthenticated: true,
        hasActiveFamilyWorkspace: true,
      ),
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    final navigatorState = tester.state<NavigatorState>(find.byType(Navigator));
    navigatorState.pushNamed('/missing-path');
    await tester.pumpAndSettle();

    expect(find.text('Unknown: /missing-path'), findsOneWidget);

    final unknownEvent = logger.events.lastWhere(
      (event) => event.code == 'route_unknown_fallback',
    );
    expect(unknownEvent.metadata['requestedPath'], '/missing-path');
  });
}

Widget _buildApp({
  required InMemoryAppLogger logger,
  required AppRouteGuardState state,
}) {
  final routeRegistry = AppRouteRegistry(
    featureRoutes: <FeatureRoute>[
      const FeatureRoute(
        path: '/health',
        requiresAuthentication: true,
        requiresFamilyWorkspace: true,
        builder: _healthBuilder,
      ),
    ],
    logger: logger,
    routeGuardStateReader: () => state,
    homeBuilder: _homeBuilder,
    loginBuilder: _loginBuilder,
    familyWorkspaceBuilder: _familyBuilder,
    unknownRouteBuilder: _unknownBuilder,
  );

  return MaterialApp(
    initialRoute: AppRoutePaths.home,
    onGenerateRoute: routeRegistry.onGenerateRoute,
  );
}

Widget _homeBuilder(BuildContext context) =>
    const Scaffold(body: Center(child: Text('Home')));

Widget _loginBuilder(BuildContext context) =>
    const Scaffold(body: Center(child: Text('Login')));

Widget _familyBuilder(BuildContext context) =>
    const Scaffold(body: Center(child: Text('Family')));

Widget _healthBuilder(BuildContext context) =>
    const Scaffold(body: Center(child: Text('Health')));

Widget _unknownBuilder(BuildContext context, String requestedPath) =>
    Scaffold(body: Center(child: Text('Unknown: $requestedPath')));
