part of 'package:family_money_management_app/main.dart';

void main() {
  runApp(const FamilyMoneyApp());
}

class FamilyMoneyApp extends StatelessWidget {
  const FamilyMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Thrive',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.page,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.indigo,
          brightness: Brightness.light,
        ),
        fontFamily: 'Avenir',
        textTheme: const TextTheme(bodyMedium: TextStyle(color: AppColors.ink)),
      ),
      home: const BudgetDashboard(),
    );
  }
}
