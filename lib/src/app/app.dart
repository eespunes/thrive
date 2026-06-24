part of 'package:family_money_management_app/main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();
  runApp(const ThriveApp());
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
  } on FirebaseException catch (e) {
    debugPrint('Firebase init failed (${e.code}): ${e.message}');
  } on PlatformException catch (e) {
    debugPrint('Firebase init failed (${e.code}): ${e.message}');
  }
}

class ThriveApp extends StatelessWidget {
  const ThriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Thrive',
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
      home: const ThriveHome(),
    );
  }
}
