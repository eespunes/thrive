import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> goToWeekly(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-more')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('more-weekly')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Weekly plan shows a 7-day grid with empty meal slots', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToWeekly(tester);

    expect(find.text('Weekly plan'), findsWidgets);
    expect(find.textContaining('Add Breakfast'), findsWidgets);
    expect(find.textContaining('Add Lunch'), findsWidgets);
    expect(find.textContaining('Add Dinner'), findsWidgets);
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('set a meal for a day, it shows in the grid and on Home', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToWeekly(tester);

    // Today's dinner slot: find the row directly under the TODAY badge.
    final todayCard = find.ancestor(
      of: find.text('TODAY'),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.key is ValueKey<String>,
      ),
    );
    final dinnerRow = find.descendant(
      of: todayCard,
      matching: find.byWidgetPredicate(
        (w) =>
            w is GestureDetector &&
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.endsWith('-dinner'),
      ),
    );
    expect(dinnerRow, findsOneWidget);
    await tester.tap(dinnerRow);
    await tester.pumpAndSettle();

    expect(find.text('Dinner'), findsWidgets);
    await tester.enterText(
      find.byType(TextField).first,
      'Pasta with tomato sauce',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Pasta with tomato sauce'), findsOneWidget);

    // Surfaces on Home's "Today's dinner" glance card.
    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('Pasta with tomato sauce'), findsOneWidget);
  });

  testWidgets('set breakfast and lunch, then clear the dinner meal', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToWeekly(tester);

    final todayCard = find.ancestor(
      of: find.text('TODAY'),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.key is ValueKey<String>,
      ),
    );
    Finder mealRow(String slot) => find.descendant(
      of: todayCard,
      matching: find.byWidgetPredicate(
        (w) =>
            w is GestureDetector &&
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.endsWith('-$slot'),
      ),
    );

    await tester.tap(mealRow('breakfast'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Oats');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Oats'), findsOneWidget);

    await tester.tap(mealRow('lunch'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Salad');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Salad'), findsOneWidget);

    // Set a dinner, then re-open and clear it via the sheet's "Clear" link.
    await tester.tap(mealRow('dinner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Tacos');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Tacos'), findsOneWidget);

    await tester.tap(mealRow('dinner'));
    await tester.pumpAndSettle();
    expect(find.text('Clear'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Tacos'), findsNothing);
    expect(find.textContaining('Add Dinner'), findsWidgets);
  });

  testWidgets('set and clear a day note', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToWeekly(tester);

    final noteRow = find.byWidgetPredicate(
      (w) =>
          w is GestureDetector &&
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('note-'),
    );
    await tester.tap(noteRow.first);
    await tester.pumpAndSettle();

    expect(find.text('Note'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Bring the cake');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Bring the cake'), findsOneWidget);

    await tester.tap(find.text('Bring the cake'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Add a note'), findsWidgets);
  });

  testWidgets('week navigation switches the visible date range', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToWeekly(tester);

    final before = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    await tester.tap(find.byKey(const ValueKey('week-next')));
    await tester.pumpAndSettle();

    final after = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    expect(before, isNot(equals(after)));
  });
}
