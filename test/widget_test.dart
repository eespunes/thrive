import 'package:family_money_management_app/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('ThriveApp boots and shows the home shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ThriveApp());
    await tester.pump();
    expect(find.byType(ThriveHome), findsOneWidget);
  });
}
