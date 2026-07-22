import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('open month picker, change year, pick a month', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('month-chip')));
    await tester.pumpAndSettle();
    expect(find.text('Select month & year'), findsOneWidget);
    // pick a month cell (short month label)
    await tester.tap(find.text('Mar').first);
    await tester.pumpAndSettle();
  });

  testWidgets('finance month control is consolidated into the header', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byKey(const ValueKey('month-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('month-next')), findsNothing);
    expect(find.byKey(const ValueKey('month-prev')), findsNothing);
    expect(find.byKey(const ValueKey('lock-btn')), findsOneWidget);
  });

  testWidgets('close a month then reopen it', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('lock-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Close this month?'), findsOneWidget);
    await tester.tap(find.text('Close month'));
    await tester.pumpAndSettle();
    // After closing, the lock button reopens the month.
    await tester.tap(find.byKey(const ValueKey('lock-btn')));
    await tester.pumpAndSettle();
  });
}
