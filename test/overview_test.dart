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
    expect(find.text('EXPECTED INCOME'), findsOneWidget);
    expect(find.text('PLANNED SPEND'), findsOneWidget);
    expect(find.text('STILL OPEN'), findsOneWidget);
    expect(find.byKey(const ValueKey('envelope-home')), findsOneWidget);
    expect(find.text('Add to Income'), findsNothing);
    expect(find.byKey(const ValueKey('overview-add-home')), findsNothing);
    expect(find.byKey(const ValueKey('quickadd-fab')), findsOneWidget);
  });

  testWidgets('one Finance add button opens the entry editor on each view', (
    tester,
  ) async {
    await pumpApp(tester);
    for (final view in ['overview', 'calendar', 'list']) {
      if (view != 'overview') await goToTab(tester, view);
      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      expect(find.text('New expense'), findsOneWidget);
      Navigator.of(tester.element(find.text('New expense'))).pop();
      await tester.pumpAndSettle();
    }
    await goToTab(tester, 'stats');
    expect(find.byKey(const ValueKey('quickadd-fab')), findsNothing);
  });

  testWidgets('finance content sits close below the month on every view', (
    tester,
  ) async {
    await pumpApp(tester);

    double gapTo(Finder content) =>
        tester.getTopLeft(content).dy -
        tester.getBottomLeft(find.byKey(const ValueKey('month-chip'))).dy;

    final overviewGap = gapTo(find.text('SAFE TO SPEND'));
    expect(overviewGap, inInclusiveRange(0, 30));

    void expectTabsOnBoundary() {
      final gradientBottom = tester
          .getRect(find.byKey(const ValueKey('finance-hero-gradient')))
          .bottom;
      final tabs = tester.getRect(find.byKey(const ValueKey('tab-overview')));
      expect(tabs.top, lessThan(gradientBottom));
      expect(tabs.bottom, greaterThan(gradientBottom));
    }

    expectTabsOnBoundary();

    for (final view in ['calendar', 'list', 'stats']) {
      await goToTab(tester, view);
      expect(
        gapTo(find.byKey(const ValueKey('tab-overview'))),
        inInclusiveRange(0, 30),
      );
      expectTabsOnBoundary();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Finance tabs clear the hero tiles on a phone-sized screen', (
    tester,
  ) async {
    await pumpApp(tester);
    tester.view.physicalSize = const Size(780, 1600);
    await tester.pumpAndSettle();

    final incomeTile = find
        .ancestor(
          of: find.text('EXPECTED INCOME'),
          matching: find.byType(Container),
        )
        .first;
    final tabs = tester.getRect(find.byKey(const ValueKey('finance-tabs')));
    expect(
      tabs.top,
      greaterThanOrEqualTo(tester.getRect(incomeTile).bottom + 8),
    );
    final tabBackground = tester.widget<Container>(
      find.byKey(const ValueKey('finance-tabs')),
    );
    expect((tabBackground.decoration as BoxDecoration).color, B.page);
    expect(tester.takeException(), isNull);
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
    expect(find.byKey(const ValueKey('tab-list')), findsOneWidget);
    expect(find.text('June 2026'), findsWidgets);

    await goToTab(tester, 'stats');
    expect(find.byKey(const ValueKey('tab-stats')), findsOneWidget);
    expect(find.text('June 2026'), findsWidgets);

    await goToTab(tester, 'calendar');
    expect(find.byKey(const ValueKey('tab-calendar')), findsOneWidget);
    expect(find.text('June 2026'), findsWidgets);
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

    await tester.tap(find.text('EXPECTED INCOME'));
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

  testWidgets('finance rows show the payee as title and label below (#400)', (
    tester,
  ) async {
    await pumpApp(tester);
    thriveDebug.saveExpense(
      'add',
      'food',
      null,
      payee: 'Acme Market',
      label: 'Weekly shop',
      amount: 42,
      paid: false,
      account: 'shared',
      recurring: false,
    );
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byKey(const ValueKey('envelope-food')));
    await tester.pumpAndSettle();
    expect(find.text('Acme Market'), findsWidgets);
    expect(_textStartingWith('Weekly shop · '), findsOneWidget);
    Navigator.of(tester.element(find.text('Acme Market').first)).pop();
    await tester.pumpAndSettle();

    await goToTab(tester, 'list');
    expect(find.text('Acme Market'), findsOneWidget);
    expect(_textStartingWith('Weekly shop · '), findsOneWidget);
  });

  testWidgets('stats tab switches scopes', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'stats');
    expect(find.text('NET RESULT'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stats-year')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stats-year')), findsOneWidget);

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
    expect(find.byKey(const ValueKey('quickadd-fab')), findsNothing);

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
