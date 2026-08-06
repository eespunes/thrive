import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('utils', () {
    test('dayNumFromMarker parses leading digits', () {
      expect(dayNumFromMarker('24th'), 24);
      expect(dayNumFromMarker('27e'), 27);
      expect(dayNumFromMarker('1st'), 1);
      expect(dayNumFromMarker('-'), isNull);
      expect(dayNumFromMarker(''), isNull);
      expect(dayNumFromMarker(null), isNull);
    });

    test('ordinal formats day numbers', () {
      expect(ordinal(1), '1st');
      expect(ordinal(2), '2nd');
      expect(ordinal(3), '3rd');
      expect(ordinal(4), '4th');
      expect(ordinal(11), '11th');
      expect(ordinal(12), '12th');
      expect(ordinal(13), '13th');
      expect(ordinal(21), '21st');
      expect(ordinal(24), '24th');
    });

    test('daysInMonthOf handles short/long months (0-based monthIdx)', () {
      expect(daysInMonthOf(2026, 5), 30); // June
      expect(daysInMonthOf(2026, 1), 28); // Feb, non-leap
      expect(daysInMonthOf(2024, 1), 29); // Feb, leap
      expect(daysInMonthOf(2026, 0), 31); // Jan
    });

    test('resolveMoneyDay keeps the date when shift is none', () {
      // June 6th 2026 is a Saturday.
      final r = resolveMoneyDay(6, 'none', 2026, 5);
      expect(r.day, 6);
      expect(r.movedFrom, isNull);
    });

    test('resolveMoneyDay before moves a Saturday back to Friday', () {
      final r = resolveMoneyDay(6, 'before', 2026, 5);
      expect(r.day, 5);
      expect(r.movedFrom, 6);
    });

    test('resolveMoneyDay after moves a Sunday forward to Monday', () {
      final r = resolveMoneyDay(7, 'after', 2026, 5);
      expect(r.day, 8);
      expect(r.movedFrom, 7);
    });

    test(
      'resolveMoneyDay clamps a weekend 1st with before (no infinite loop)',
      () {
        // Feb 1st 2026 is a Sunday.
        final r = resolveMoneyDay(1, 'before', 2026, 1);
        expect(r.day, 1);
        expect(r.movedFrom, isNull);
      },
    );

    test(
      'resolveMoneyDay clamps a weekend last day with after (no infinite loop)',
      () {
        // Feb 28th 2026 (last day) is a Saturday.
        final r = resolveMoneyDay(28, 'after', 2026, 1);
        expect(r.day, 28);
        expect(r.movedFrom, isNull);
      },
    );

    test('resolveMoneyDay clamps markers beyond the month length', () {
      final r = resolveMoneyDay(31, 'none', 2026, 1); // Feb has 28 days.
      expect(r.day, 28);
    });
  });

  group('Money calendar screen', () {
    testWidgets('third finance segment opens the flow screen', (tester) async {
      await pumpApp(tester);
      await goToTab(tester, 'flow');
      expect(find.text('Money calendar'), findsWidgets);
      expect(find.text('LOWEST POINT THIS MONTH'), findsOneWidget);
      expect(find.textContaining('on the'), findsWidgets);
      expect(find.text('Money in'), findsOneWidget);
      expect(find.text('Money out'), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-start-btn')), findsOneWidget);
    });

    testWidgets('toggling between calendar and timeline views', (tester) async {
      await pumpApp(tester);
      await goToTab(tester, 'flow');
      expect(find.byKey(const ValueKey('flow-view-calendar')), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-view-timeline')), findsOneWidget);
      // Calendar grid renders a cell for day 1.
      expect(find.byKey(const ValueKey('flow-day-1')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('flow-view-timeline')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('flow-day-1')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('flow-view-calendar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('flow-day-1')), findsOneWidget);
    });

    testWidgets('tapping a day opens the day sheet with In/Out/Balance', (
      tester,
    ) async {
      await pumpApp(tester);
      await goToTab(tester, 'flow');
      await tester.tap(find.byKey(const ValueKey('flow-day-1')));
      await tester.pumpAndSettle();
      expect(find.text('IN'), findsOneWidget);
      expect(find.text('OUT'), findsOneWidget);
      expect(find.text('BALANCE AFTER'), findsOneWidget);
    });

    testWidgets('Start button opens the open-balance sheet', (tester) async {
      await pumpApp(tester);
      await goToTab(tester, 'flow');
      await tester.tap(find.byKey(const ValueKey('flow-start-btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('What sits on your accounts'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '1500');
      await tester.tap(find.text('Save start balance'));
      await tester.pumpAndSettle();
    });

    testWidgets('shift field appears in the expense edit sheet', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('RENT').first);
      await tester.pumpAndSettle();
      expect(find.text('IF IT LANDS ON A WEEKEND'), findsOneWidget);
      expect(find.text('Keep the date'), findsOneWidget);
      expect(find.text('Friday before'), findsOneWidget);
      expect(find.text('Monday after'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('expense-shift-before')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();
    });

    testWidgets('shift field appears in the income edit sheet', (tester) async {
      await pumpApp(tester);
      final income = firstIncomeLabel(tester);
      await tester.tap(find.text(income).first);
      await tester.pumpAndSettle();
      expect(find.text('PAY DAY'), findsOneWidget);
      expect(find.text('IF IT LANDS ON A WEEKEND'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();
    });
  });
}
