import 'package:flutter/material.dart';
import 'package:thrive_app/core/architecture/feature_module.dart';
import 'package:thrive_app/core/observability/app_logger.dart';

class AppRoutePaths {
  static const String home = '/';
  static const String login = '/login';
  static const String familyWorkspace = '/family/workspace';
}

class AppRouteGuardState {
  const AppRouteGuardState({
    required this.isAuthenticated,
    required this.hasActiveFamilyWorkspace,
  });

  final bool isAuthenticated;
  final bool hasActiveFamilyWorkspace;
}

typedef AppRouteGuardStateReader = AppRouteGuardState Function();
typedef UnknownRouteBuilder =
    Widget Function(BuildContext context, String requestedPath);

enum RouteResolutionOutcome {
  allowed,
  redirectedToLogin,
  redirectedToFamilyWorkspace,
  unknownRouteFallback,
}

class AppRouteRegistry {
  AppRouteRegistry({
    required List<FeatureRoute> featureRoutes,
    required this.logger,
    required this.routeGuardStateReader,
    required WidgetBuilder homeBuilder,
    required WidgetBuilder loginBuilder,
    required WidgetBuilder familyWorkspaceBuilder,
    required this.unknownRouteBuilder,
  }) : _routes = <String, FeatureRoute>{
         AppRoutePaths.home: FeatureRoute(
           path: AppRoutePaths.home,
           builder: homeBuilder,
         ),
         AppRoutePaths.login: FeatureRoute(
           path: AppRoutePaths.login,
           builder: loginBuilder,
         ),
         AppRoutePaths.familyWorkspace: FeatureRoute(
           path: AppRoutePaths.familyWorkspace,
           builder: familyWorkspaceBuilder,
           requiresAuthentication: true,
         ),
       } {
    for (final route in featureRoutes) {
      if (_routes.containsKey(route.path)) {
        throw StateError(
          'Route already registered in AppRouteRegistry: ${route.path}',
        );
      }
      _routes[route.path] = route;
    }
  }

  final AppLogger logger;
  final AppRouteGuardStateReader routeGuardStateReader;
  final UnknownRouteBuilder unknownRouteBuilder;
  final Map<String, FeatureRoute> _routes;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final requestedPath = _normalizePath(settings.name);
    final route = _routes[requestedPath];
    final state = routeGuardStateReader();

    if (route == null) {
      logger.warning(
        code: 'route_unknown_fallback',
        message: 'Unknown route requested; rendering safe fallback',
        metadata: <String, Object?>{
          'requestedPath': requestedPath,
          'resolvedPath': AppRoutePaths.home,
          'outcome': RouteResolutionOutcome.unknownRouteFallback.name,
        },
      );

      return MaterialPageRoute<void>(
        settings: RouteSettings(
          name: requestedPath,
          arguments: settings.arguments,
        ),
        builder: (context) => unknownRouteBuilder(context, requestedPath),
      );
    }

    final guardDecision = _evaluateGuards(route: route, state: state);
    if (!guardDecision.allowed) {
      final redirectPath = guardDecision.redirectPath!;
      final redirectRoute = _routes[redirectPath];
      if (redirectRoute == null) {
        throw StateError('Missing redirect route: $redirectPath');
      }

      logger.warning(
        code: 'route_guard_blocked',
        message: 'Route blocked by guard; redirecting to safe route',
        metadata: <String, Object?>{
          'requestedPath': requestedPath,
          'resolvedPath': redirectPath,
          'reason': guardDecision.reason,
          'outcome': guardDecision.outcome.name,
          'isAuthenticated': state.isAuthenticated,
          'hasActiveFamilyWorkspace': state.hasActiveFamilyWorkspace,
        },
      );

      return MaterialPageRoute<void>(
        settings: RouteSettings(
          name: redirectPath,
          arguments: settings.arguments,
        ),
        builder: (context) => redirectRoute.builder(context),
      );
    }

    logger.info(
      code: 'route_navigation_resolved',
      message: 'Route resolved successfully',
      metadata: <String, Object?>{
        'requestedPath': requestedPath,
        'resolvedPath': requestedPath,
        'outcome': RouteResolutionOutcome.allowed.name,
      },
    );

    return MaterialPageRoute<void>(
      settings: RouteSettings(
        name: requestedPath,
        arguments: settings.arguments,
      ),
      builder: (context) => route.builder(context),
    );
  }

  _GuardDecision _evaluateGuards({
    required FeatureRoute route,
    required AppRouteGuardState state,
  }) {
    if (route.requiresAuthentication && !state.isAuthenticated) {
      return const _GuardDecision.blocked(
        redirectPath: AppRoutePaths.login,
        reason: 'auth_required',
        outcome: RouteResolutionOutcome.redirectedToLogin,
      );
    }

    if (route.requiresFamilyWorkspace && !state.hasActiveFamilyWorkspace) {
      return const _GuardDecision.blocked(
        redirectPath: AppRoutePaths.familyWorkspace,
        reason: 'family_workspace_required',
        outcome: RouteResolutionOutcome.redirectedToFamilyWorkspace,
      );
    }

    return const _GuardDecision.allowed();
  }

  String _normalizePath(String? routeName) {
    if (routeName == null || routeName.trim().isEmpty) {
      return AppRoutePaths.home;
    }

    final parsedUri = Uri.tryParse(routeName.trim());
    final candidatePath = parsedUri?.path ?? routeName.trim();
    if (candidatePath.isEmpty || candidatePath == '.') {
      return AppRoutePaths.home;
    }

    if (candidatePath.startsWith('/')) {
      return candidatePath;
    }
    return '/$candidatePath';
  }
}

class _GuardDecision {
  const _GuardDecision.allowed()
    : allowed = true,
      redirectPath = null,
      reason = null,
      outcome = RouteResolutionOutcome.allowed;

  const _GuardDecision.blocked({
    required this.redirectPath,
    required this.reason,
    required this.outcome,
  }) : allowed = false;

  final bool allowed;
  final String? redirectPath;
  final String? reason;
  final RouteResolutionOutcome outcome;
}
