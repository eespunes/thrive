import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('Home dashboard shows a greeting and empty states with no data', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    expect(find.text('Hi, Eva'), findsOneWidget);
    expect(find.text('Nothing scheduled — enjoy the calm.'), findsOneWidget);
    expect(find.text('All caught up. Nice work!'), findsOneWidget);
    expect(find.text('No lists yet'), findsOneWidget);
    expect(find.text('Not planned'), findsOneWidget);
    expect(find.textContaining('PROJECTED BALANCE'), findsOneWidget);
  });

  testWidgets('a task created in Lists shows up in Tasks due soon', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);

    await tester.tap(find.byKey(const ValueKey('nav-lists')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Household');
    await tester.pump();
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Household'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Take out the bins');
    await tester.pump();
    await tester.tap(find.text('Add task').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('Take out the bins'), findsOneWidget);
    expect(find.textContaining('Household'), findsOneWidget);

    // Tapping the task row navigates straight into its list's detail.
    await tester.tap(find.text('Take out the bins'));
    await tester.pumpAndSettle();
    expect(find.text('Household'), findsOneWidget);
    expect(find.text('Add task'), findsOneWidget);
  });

  testWidgets(
    'a shopping list created in Lists shows up in the Shopping glance',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);

      await tester.tap(find.byKey(const ValueKey('nav-lists')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shopping'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Supermarket');
      await tester.pump();
      await tester.tap(find.text('Create list'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav-home')));
      await tester.pumpAndSettle();
      expect(find.text('Supermarket'), findsOneWidget);
    },
  );

  testWidgets('tapping the projected balance card opens the Finance tab', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.textContaining('PROJECTED BALANCE'));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
  });
}
