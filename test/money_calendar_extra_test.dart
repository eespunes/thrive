import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

/// Whether the app's seeded June-2026 budget month lies in the past relative
/// to the real clock (these tests run on the real date).
bool get _junePast {
  final d = DateTime.now();
  return (2026 * 12 + 5) < (d.year * 12 + (d.month - 1));
}

void main() {
  testWidgets(
    'past month with unpaid items shows the overdue banner; tapping it '
    'jumps to the timeline',
    (tester) async {
      if (!_junePast) return;
      await pumpApp(tester);
      await goToTab(tester, 'flow');

      final banner = find.byKey(const ValueKey('flow-overdue-banner'));
      expect(banner, findsOneWidget);
      await tester.tap(banner);
      await tester.pumpAndSettle();
      // Timeline view took over from the calendar grid.
      expect(find.byKey(const ValueKey('flow-day-1')), findsNothing);
      expect(find.byKey(const ValueKey('flow-timeline-day-1')), findsWidgets);
    },
  );

  testWidgets('timeline rows open the editor, show the weekend-shift badge and '
      'toggle paid/received', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'flow');
    await tester.tap(find.byKey(const ValueKey('flow-view-timeline')));
    await tester.pumpAndSettle();

    // DEDUCTIBLE sits on the 27th — a Saturday in June 2026. Open it from
    // the timeline row and give it a "Friday before" weekend shift.
    final dedId = thriveDebug.findExpenseId('health', '', 'DEDUCTIBLE');
    expect(dedId, isNotNull);
    final dedRow = find.byKey(ValueKey('flow-row-out-$dedId'));
    await tester.ensureVisible(dedRow);
    await tester.pumpAndSettle();
    await tester.tap(dedRow);
    await tester.pumpAndSettle();
    expect(find.text('IF IT LANDS ON A WEEKEND'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('expense-shift-before')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    // The row moved to the 26th and carries a "from 27th" badge.
    await tester.ensureVisible(find.byKey(ValueKey('flow-row-out-$dedId')));
    await tester.pumpAndSettle();
    expect(find.text('from 27th'), findsOneWidget);

    // Toggle it paid via the row's check circle.
    final check = find
        .descendant(
          of: find.byKey(ValueKey('flow-row-out-$dedId')),
          matching: find.byType(GestureDetector),
        )
        .last;
    await tester.tap(check, warnIfMissed: false);
    await tester.pumpAndSettle();

    // And an income row's check toggles received.
    final incomeId = thriveDebug.firstIncomeId();
    expect(incomeId, isNotNull);
    final inRow = find.byKey(ValueKey('flow-row-in-$incomeId'));
    await tester.ensureVisible(inRow);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: inRow, matching: find.byType(GestureDetector)).last,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    // Tapping empty space clears any swiped row state.
    await tester.tapAt(const Offset(540, 200));
    await tester.pumpAndSettle();
  });

  testWidgets('a year without data renders the empty timeline card', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToTab(tester, 'flow');
    thriveDebug.setYear(2027);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('flow-view-timeline')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flow-timeline-day-1')), findsNothing);
    expect(find.textContaining('No'), findsWidgets);
  });

  testWidgets('viewing the real current month draws the today marker', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToTab(tester, 'flow');
    final now = DateTime.now();
    thriveDebug.setYear(now.year);
    thriveDebug.pickMonth(now.month - 1);
    await tester.pumpAndSettle();

    // The calendar grid renders every day of the current month (today ring
    // included) and the balance chart paints its today line.
    expect(find.byKey(ValueKey('flow-day-${now.day}')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('flow-view-timeline')));
    await tester.pumpAndSettle();
  });
}
