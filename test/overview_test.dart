import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

Finder _textStartingWith(String prefix) => find.byWidgetPredicate(
  (widget) => widget is Text && (widget.data?.startsWith(prefix) ?? false),
);

void main() {
  testWidgets('finance overview renders the v2 hero and envelopes', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('SAFE TO SPEND'), findsOneWidget);
    expect(find.text('INCOME RECEIVED'), findsOneWidget);
    expect(find.text('PLANNED SPEND'), findsOneWidget);
    expect(find.text('STILL OPEN'), findsOneWidget);
    expect(find.byKey(const ValueKey('envelope-home')), findsOneWidget);
  });

  testWidgets('a capped envelope fills across the full card width', (
    tester,
  ) async {
    await pumpApp(tester);
    final card = find.byKey(const ValueKey('envelope-food'));
    final fill = find.descendant(
      of: card,
      matching: find.byType(FractionallySizedBox),
    );
    expect(fill, findsOneWidget);
    final fillSize = tester.getSize(fill);
    expect(fillSize.width, closeTo(tester.getSize(card).width, 4));
    expect(fillSize.height, greaterThan(0));
  });

  testWidgets('finance tabs switch without changing the month', (tester) async {
    await pumpApp(tester);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('June 2026'), findsWidgets);

    await goToTab(tester, 'list');
    expect(find.text('All items'), findsOneWidget);
    expect(find.text('June 2026'), findsWidgets);

    await goToTab(tester, 'stats');
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Month view'), findsOneWidget);

    await goToTab(tester, 'calendar');
    expect(find.text('Money calendar'), findsOneWidget);
    expect(find.text('June 2026 · day by day'), findsOneWidget);
  });

  testWidgets('envelope sheet toggles an open item in place', (tester) async {
    await pumpApp(tester);
    final before = thriveDebug.unpaidItemsThisMonth().length;
    final first = thriveDebug.unpaidItemsThisMonth().first;

    await tester.tap(find.byKey(ValueKey('envelope-${first.$1.key}')));
    await tester.pumpAndSettle();

    expect(find.text(first.$1.title), findsWidgets);
    await tester.tap(find.text('Open').first);
    await tester.pumpAndSettle();

    expect(find.text(first.$1.title), findsWidgets);
    expect(thriveDebug.unpaidItemsThisMonth().length, before - 1);
  });

  testWidgets('income sheet toggles a source in place', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('INCOME RECEIVED'));
    await tester.pumpAndSettle();
    expect(find.text('Income'), findsWidgets);
    final tappedLabel = find.text('Pending').evaluate().isNotEmpty
        ? 'Pending'
        : 'In';
    final before = find.text(tappedLabel).evaluate().length;
    await tester.tap(find.text(tappedLabel).first);
    await tester.pumpAndSettle();
    expect(find.text(tappedLabel).evaluate().length, before - 1);
  });

  testWidgets('accounts sheet opens from still open hero tile', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('STILL OPEN'));
    await tester.pumpAndSettle();
    expect(find.text('STILL TO PAY FROM'), findsOneWidget);
  });

  testWidgets('list tab shows summary tiles and dated sections', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToTab(tester, 'list');
    expect(find.text('ITEMS'), findsOneWidget);
    expect(find.text('PAID TOTAL'), findsOneWidget);
    expect(find.text('OPEN TOTAL'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data?.contains('·') ?? false),
      ),
      findsWidgets,
    );
  });

  testWidgets('stats tab switches scopes', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'stats');
    expect(find.text('NET RESULT'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stats-year')));
    await tester.pumpAndSettle();
    expect(find.text('Full year 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stats-all')));
    await tester.pumpAndSettle();
    expect(find.text('All time'), findsWidgets);
  });

  testWidgets('closed months keep overview toggles inert', (tester) async {
    await pumpApp(tester);
    final before = thriveDebug.unpaidItemsThisMonth().length;
    final first = thriveDebug.unpaidItemsThisMonth().first;
    thriveDebug.closeMonth();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('envelope-${first.$1.key}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open').first);
    await tester.pumpAndSettle();

    expect(thriveDebug.unpaidItemsThisMonth().length, before);
    expect(find.text('Month closed'), findsWidgets);
  });

  testWidgets('calendar cells show income lines', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'calendar');
    expect(find.byKey(const ValueKey('flow-day-1')), findsOneWidget);
    expect(_textStartingWith('+€'), findsWidgets);
  });
}
