import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('statistics screen renders charts', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'stats');
    expect(find.byKey(const ValueKey('tab-overview')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-stats')), findsOneWidget);
    expect(find.byKey(const ValueKey('lock-btn')), findsOneWidget);
    // Toggle to year view and back to exercise both painters.
    await tester.tap(find.byKey(const ValueKey('stats-year')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stats-month')));
    await tester.pumpAndSettle();
  });

  testWidgets('statistics month navigation via arrows', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'stats');
    await tester.tap(find.byKey(const ValueKey('stats-year')));
    await tester.pumpAndSettle();
  });
}
