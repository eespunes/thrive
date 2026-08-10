import 'package:family_money_management_app/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('ThriveApp boots and shows the home shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Thrive',
      packageName: 'com.thrive.app',
      version: '2.7.1',
      buildNumber: '46',
      buildSignature: '',
    );
    await tester.pumpWidget(const ThriveApp());
    await tester.pump();
    expect(find.byType(ThriveHome), findsOneWidget);
  });
}
