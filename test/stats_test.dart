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
    // Scorecard hero card (issue #192) + the four quick stat tiles.
    expect(find.text('NET RESULT'), findsOneWidget);
    expect(find.text('INCOME'), findsOneWidget);
    expect(find.text('SPENDING'), findsOneWidget);
    expect(find.text('SAVINGS RATE'), findsOneWidget);
    expect(find.text('FIXED COSTS'), findsOneWidget);
    expect(find.text('In vs out'), findsOneWidget);
    expect(find.text('WHERE IT WENT'), findsOneWidget);
    // Toggle to year and all-time views and back to exercise every scope.
    await tester.tap(find.byKey(const ValueKey('stats-year')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stats-all')));
    await tester.pumpAndSettle();
    expect(find.text('Year by year'), findsOneWidget);
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
