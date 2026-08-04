part of 'package:family_money_management_app/main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();
  await NotificationService.init();
  runApp(const ThriveApp());
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    // The family document (one big `workspace` blob covering every month)
    // can grow past a few MB for long-lived families. Android's SQLite-backed
    // offline cache stores each document as a single row and crashes the
    // whole app with a fatal `SQLiteBlobTooBigException` ("Row too big to fit
    // into CursorWindow") once that row exceeds the OS's ~2MB CursorWindow
    // limit. Disabling local persistence avoids ever hitting that ceiling —
    // reads/writes just always go straight to the network instead of being
    // cached on-device, which is an acceptable trade-off for a document this
    // size (offline support was never reliable for it regardless, since the
    // very first sync after being offline would already have failed).
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  } on FirebaseException catch (e) {
    debugPrint('Firebase init failed (${e.code}): ${e.message}');
  } on PlatformException catch (e) {
    debugPrint('Firebase init failed (${e.code}): ${e.message}');
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
        return Stack(
          textDirection: TextDirection.ltr,
          children: [?child, const _GlobalErrorPopup()],
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
