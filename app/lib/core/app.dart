import 'package:flutter/material.dart';
import 'package:thrive_app/core/architecture/module_registry.dart';
import 'package:thrive_app/core/branding/brand_asset_registry.dart';
import 'package:thrive_app/core/branding/thrive_logo.dart';
import 'package:thrive_app/core/design_system/components/thrive_primary_button.dart';
import 'package:thrive_app/core/design_system/components/thrive_surface_card.dart';
import 'package:thrive_app/core/design_system/design_tokens.dart';
import 'package:thrive_app/core/forms/email_sign_in_repository.dart';
import 'package:thrive_app/core/forms/field_validation.dart';
import 'package:thrive_app/core/navigation/app_route_registry.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';
import 'package:thrive_app/core/version/spec_version.dart';

const bool _forceVersionOverlay = bool.fromEnvironment(
  'THRIVE_SHOW_VERSION_OVERLAY',
  defaultValue: false,
);
const String _thriveEnvironment = String.fromEnvironment(
  'THRIVE_ENV',
  defaultValue: 'dev',
);
const bool _showVersionOverlay =
    _forceVersionOverlay || _thriveEnvironment != 'prod';
const Duration _minimumSplashDuration = Duration(milliseconds: 1200);

class ThriveApp extends StatefulWidget {
  const ThriveApp({
    required this.registry,
    required this.theme,
    required this.brandAssetRegistry,
    required this.logger,
    required this.routeGuardStateReader,
    super.key,
  });

  final ModuleRegistry registry;
  final ThemeData theme;
  final BrandAssetRegistry brandAssetRegistry;
  final AppLogger logger;
  final AppRouteGuardStateReader routeGuardStateReader;

  @override
  State<ThriveApp> createState() => _ThriveAppState();
}

class _ThriveAppState extends State<ThriveApp> {
  late AppRouteRegistry _routeRegistry;

  @override
  void initState() {
    super.initState();
    _routeRegistry = _buildRouteRegistry();
  }

  @override
  void didUpdateWidget(covariant ThriveApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldRebuildRegistry =
        oldWidget.registry != widget.registry ||
        oldWidget.logger != widget.logger ||
        oldWidget.brandAssetRegistry != widget.brandAssetRegistry ||
        oldWidget.routeGuardStateReader != widget.routeGuardStateReader;
    if (shouldRebuildRegistry) {
      _routeRegistry = _buildRouteRegistry();
    }
  }

  AppRouteRegistry _buildRouteRegistry() {
    return AppRouteRegistry(
      featureRoutes: widget.registry.buildFeatureRoutes(),
      logger: widget.logger,
      routeGuardStateReader: widget.routeGuardStateReader,
      splashBuilder: (context) => _SplashPage(
        brandAssetRegistry: widget.brandAssetRegistry,
        logger: widget.logger,
        routeGuardStateReader: widget.routeGuardStateReader,
      ),
      homeBuilder: (context) => _HomePage(
        brandAssetRegistry: widget.brandAssetRegistry,
        logger: widget.logger,
      ),
      loginBuilder: (context) => _LoginPage(
        brandAssetRegistry: widget.brandAssetRegistry,
        logger: widget.logger,
      ),
      familyWorkspaceBuilder: (context) => const _FamilyWorkspacePage(),
      unknownRouteBuilder: (context, requestedPath) =>
          _UnknownRoutePage(requestedPath: requestedPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thrive',
      theme: widget.theme,
      initialRoute: AppRoutePaths.splash,
      onGenerateRoute: _routeRegistry.onGenerateRoute,
      onGenerateInitialRoutes: _buildInitialRoutes,
      builder: (context, child) => _showVersionOverlay
          ? _VersionOverlay(child: child)
          : child ?? const SizedBox.shrink(),
    );
  }

  List<Route<dynamic>> _buildInitialRoutes(String initialRoute) {
    return <Route<dynamic>>[
      _routeRegistry.onGenerateRoute(
        const RouteSettings(name: AppRoutePaths.splash),
      ),
    ];
  }
}

class _VersionOverlay extends StatelessWidget {
  const _VersionOverlay({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child ?? const SizedBox.shrink(),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomRight,
            child: IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  thriveVersionLabel,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashPage extends StatefulWidget {
  const _SplashPage({
    required this.brandAssetRegistry,
    required this.logger,
    required this.routeGuardStateReader,
  });

  final BrandAssetRegistry brandAssetRegistry;
  final AppLogger logger;
  final AppRouteGuardStateReader routeGuardStateReader;

  @override
  State<_SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<_SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupRouting();
    });
  }

  Future<void> _runStartupRouting() async {
    await Future<void>.delayed(_minimumSplashDuration);
    if (!mounted) {
      return;
    }

    final guardState = widget.routeGuardStateReader();
    final destination = guardState.isAuthenticated
        ? AppRoutePaths.home
        : AppRoutePaths.login;

    widget.logger.info(
      code: 'splash_routing_resolved',
      message: 'Splash startup routing completed',
      metadata: <String, Object?>{
        'isAuthenticated': guardState.isAuthenticated,
        'destination': destination,
      },
    );

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(destination, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('thrive_splash_screen'),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF165EA8), ThriveColors.mint],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                child: ThriveLogo(
                  registry: widget.brandAssetRegistry,
                  logger: widget.logger,
                  variant: BrandLogoVariant.unicolor,
                  width: 180,
                  height: 180,
                ),
              ),
              const SizedBox(height: ThriveSpacing.md),
              const Text(
                'Thrive',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: ThriveTypography.titleFontFamily,
                  fontSize: 46,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.brandAssetRegistry, required this.logger});

  final BrandAssetRegistry brandAssetRegistry;
  final AppLogger logger;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thrive')),
      body: Padding(
        padding: const EdgeInsets.all(ThriveSpacing.lg),
        child: ThriveSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ThriveLogo(registry: brandAssetRegistry, logger: logger),
              const SizedBox(height: ThriveSpacing.lg),
              Text(
                'Family finance that everyone can use.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ThriveSpacing.lg),
              ThrivePrimaryButton(
                onPressed: () => Navigator.of(context).pushNamed('/health'),
                label: 'Open Health Module',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginPage extends StatefulWidget {
  const _LoginPage({required this.brandAssetRegistry, required this.logger});

  final BrandAssetRegistry brandAssetRegistry;
  final AppLogger logger;

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final EmailSignInRepository _emailSignInRepository =
      const DemoEmailSignInRepository();

  bool _showEmailForm = false;
  bool _isSubmitting = false;
  FailureDetail? _globalFailure;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailSignIn({required bool isRetry}) async {
    if (_isSubmitting) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      widget.logger.warning(
        code: 'form_validation_failed',
        message: 'Email sign-in form rejected invalid input',
        metadata: <String, Object?>{
          'flow': 'email_sign_in',
          'isRetry': isRetry,
          'emailEmpty': _emailController.text.trim().isEmpty,
          'passwordLength': _passwordController.text.length,
        },
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _globalFailure = null;
    });

    final result = await _emailSignInRepository.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    var signInSucceeded = false;
    FailureDetail? signInFailure;

    result.when(
      success: (_) {
        signInSucceeded = true;
        widget.logger.info(
          code: 'email_sign_in_succeeded',
          message: 'Email sign-in succeeded',
        );
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutePaths.home, (route) => false);
      },
      failure: (failure) {
        widget.logger.warning(
          code: failure.code,
          message: failure.developerMessage,
          metadata: <String, Object?>{
            'recoverable': failure.recoverable,
            'flow': 'email_sign_in',
          },
        );
        signInFailure = failure;
      },
    );

    if (!mounted || signInSucceeded) {
      return;
    }

    setState(() {
      _globalFailure = signInFailure;
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ThriveSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ThriveSurfaceCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ThriveLogo(
                      registry: widget.brandAssetRegistry,
                      logger: widget.logger,
                    ),
                    const SizedBox(height: ThriveSpacing.lg),
                    Text(
                      'Welcome to Thrive',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: ThriveSpacing.md),
                    ThrivePrimaryButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutePaths.home,
                            (route) => false,
                          ),
                      label: 'Continue with Google',
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showEmailForm = true;
                          _globalFailure = null;
                        });
                      },
                      child: const Text('or sign in with email'),
                    ),
                    if (_showEmailForm) ...<Widget>[
                      const SizedBox(height: ThriveSpacing.lg),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: <Widget>[
                            TextFormField(
                              key: const Key('email_sign_in_email_field'),
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const <String>[
                                AutofillHints.email,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              validator: (value) {
                                final fieldValue = value ?? '';
                                return validateField(
                                  fieldValue,
                                  <FieldValidator>[
                                    ThriveFieldValidators.required(
                                      message: 'Email is required.',
                                    ),
                                    ThriveFieldValidators.email(
                                      message: 'Enter a valid email.',
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: ThriveSpacing.md),
                            TextFormField(
                              key: const Key('email_sign_in_password_field'),
                              controller: _passwordController,
                              obscureText: true,
                              autofillHints: const <String>[
                                AutofillHints.password,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                              validator: (value) {
                                final fieldValue = value ?? '';
                                return validateField(fieldValue, <
                                  FieldValidator
                                >[
                                  ThriveFieldValidators.required(
                                    message: 'Password is required.',
                                  ),
                                  ThriveFieldValidators.minLength(
                                    8,
                                    message:
                                        'Password must be at least 8 characters long.',
                                  ),
                                ]);
                              },
                            ),
                            const SizedBox(height: ThriveSpacing.md),
                            ThrivePrimaryButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _submitEmailSignIn(isRetry: false),
                              label: _isSubmitting
                                  ? 'Signing in...'
                                  : 'Sign in with email',
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_globalFailure != null) ...<Widget>[
                      const SizedBox(height: ThriveSpacing.md),
                      Semantics(
                        liveRegion: true,
                        label: 'Error',
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: ThriveRadius.card,
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          padding: const EdgeInsets.all(ThriveSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _globalFailure!.userMessage,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: ThriveSpacing.sm),
                              TextButton(
                                key: const Key('email_sign_in_retry_button'),
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        widget.logger.info(
                                          code: 'email_sign_in_retry_requested',
                                          message:
                                              'User requested retry for failed email sign-in',
                                        );
                                        _submitEmailSignIn(isRetry: true);
                                      },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FamilyWorkspacePage extends StatelessWidget {
  const _FamilyWorkspacePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Workspace')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ThriveSpacing.lg),
          child: ThriveSurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Select or create your family workspace.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ThriveSpacing.lg),
                ThrivePrimaryButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutePaths.home,
                        (route) => false,
                      ),
                  label: 'Back to Home',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnknownRoutePage extends StatelessWidget {
  const _UnknownRoutePage({required this.requestedPath});

  final String requestedPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ThriveSpacing.lg),
          child: ThriveSurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'We could not open that page.',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ThriveSpacing.sm),
                Text(
                  'Requested route: $requestedPath',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ThriveSpacing.lg),
                ThrivePrimaryButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutePaths.home,
                        (route) => false,
                      ),
                  label: 'Go Home',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
