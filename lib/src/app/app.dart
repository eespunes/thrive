part of 'package:family_money_management_app/main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // These don't depend on each other, so run them concurrently instead of
  // paying sequential awaits before the first frame.
  await Future.wait([_lockPortraitOrientation(), _initFirebase()]);
  runApp(const ThriveApp());
  // NotificationService.init parses the full timezone database — real CPU
  // that used to gate the first frame. Reminders aren't needed at first
  // paint, so it runs after it; every reminder-scheduling path awaits the
  // same memoised init() first, so nothing can race an uninitialised plugin.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(NotificationService.init());
  });
}

const List<DeviceOrientation> _portraitOrientations = [
  DeviceOrientation.portraitUp,
];

const List<DeviceOrientation> _landscapeOrientations = [
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

Future<void> _lockPortraitOrientation() =>
    SystemChrome.setPreferredOrientations(_portraitOrientations);

Future<void> _lockLandscapeOrientation() =>
    SystemChrome.setPreferredOrientations(_landscapeOrientations);

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    try {
      // App Check attests that requests come from a genuine app install —
      // Firestore/Auth are otherwise callable by anything holding the (public)
      // API key. Debug builds use the debug provider (register its token in
      // the Firebase console for local dev). Enforcement is switched on
      // per-product in the console once real traffic is attested.
      await FirebaseAppCheck.instance.activate(
        providerAndroid: foundation.kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: foundation.kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
    } catch (e) {
      // App Check is defense-in-depth; never block startup on it (e.g. web
      // has no provider configured).
      debugPrint('App Check activation failed: $e');
    }
    // No offline data: Firestore is the only copy of family data. The disk
    // cache is off, so every screen shows what the server holds and an edit
    // is either saved on the server or visibly "Not saved" — never parked in
    // a device-local queue that can be lost or replayed stale. Must be set
    // before the first Firestore call; the cache older versions left on
    // disk is wiped (a no-op once it's gone).
    try {
      final db = FirebaseFirestore.instance;
      db.settings = const Settings(persistenceEnabled: false);
      await db.clearPersistence();
    } catch (e) {
      debugPrint('[boot] could not clear the Firestore cache: $e');
    }
    // Retired crash-loop breaker (it existed to wipe that cache).
    try {
      final prefs = await SharedPreferences.getInstance();
      unawaited(prefs.remove(kBootFailStreakKey));
      unawaited(prefs.remove(kBootIncompleteLegacyKey));
    } catch (_) {}
  } on FirebaseException catch (e) {
    debugPrint('Firebase init failed (${e.code}): ${e.message}');
  } on PlatformException catch (e) {
    debugPrint('Firebase init failed (${e.code}): ${e.message}');
  } catch (e) {
    // Any other init failure (e.g. a platform with no Firebase config) must
    // still fall through to local/demo mode instead of killing startup.
    debugPrint('Firebase init failed: $e');
  }
}

/// App-wide error channel. Any layer (widgets, cloud calls, actions) can push a
/// message here and the popup rendered in [ThriveApp]'s `builder` shows it above
/// every route — including modal bottom sheets and dialogs — until the user
/// dismisses it. This guarantees errors are never lost or left stuck silently.
final ValueNotifier<String?> appErrorNotifier = ValueNotifier<String?>(null);

/// Surfaces [message] in the global, user-closable error popup. Blank messages
/// are ignored so callers can forward nullable error strings safely.
void showAppError(String? message) {
  final msg = message?.trim() ?? '';
  if (msg.isEmpty) return;
  appErrorNotifier.value = msg;
}

/// Hides the global error popup.
void dismissAppError() => appErrorNotifier.value = null;

class ThriveApp extends StatelessWidget {
  const ThriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Thrive',
      locale: const Locale('en', 'GB'),
      supportedLocales: const [Locale('en', 'GB')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: B.page,
        colorScheme: ColorScheme.fromSeed(
          seedColor: B.primary,
          brightness: Brightness.light,
        ),
        fontFamily: 'PlusJakartaSans',
        textTheme: const TextTheme(bodyMedium: TextStyle(color: B.ink)),
      ),
      // The popup is layered above the Navigator so it floats over every route,
      // including modal bottom sheets. It is non-blocking: only the card itself
      // captures pointer events, so the UI beneath stays fully interactive.
      builder: (context, child) {
        // The layout uses many fixed-height containers around hardcoded font
        // sizes; unbounded OS text scaling clips them. Clamp until the layout
        // is audited for full dynamic-type support.
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Stack(
            textDirection: TextDirection.ltr,
            children: [?child, const _GlobalErrorPopup()],
          ),
        );
      },
      home: const ThriveHome(),
    );
  }
}

/// Closable error banner shown at the top of the app whenever
/// [appErrorNotifier] holds a message. Rendered once, globally.
class _GlobalErrorPopup extends StatelessWidget {
  const _GlobalErrorPopup();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: appErrorNotifier,
      builder: (context, message, _) {
        if (message == null) return const SizedBox.shrink();
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Material(
                key: const ValueKey('app-error-popup'),
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    decoration: BoxDecoration(
                      color: B.redSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: B.redLine),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .14),
                          blurRadius: 24,
                          spreadRadius: -8,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: ic('x', size: 16, sw: 2.6, color: B.red),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: B.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          key: const ValueKey('app-error-dismiss'),
                          behavior: HitTestBehavior.opaque,
                          onTap: dismissAppError,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 18, color: B.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
