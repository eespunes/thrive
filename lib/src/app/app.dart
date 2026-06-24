part of 'package:family_money_management_app/main.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ThriveApp());
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
