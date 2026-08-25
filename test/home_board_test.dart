import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// The Home board epic (#223): default board, edit mode, picker, sizes,
// options, per-user persistence, catalogue rendering, micro actions and
// kid-safe boards.

void seedRichWorkspace() {
  final today = todayIso();
  thriveDebug.mutateState(() {
    thriveDebug.events.add(
      CalendarEvent(
        id: 'ev1',
        title: 'Dentist',
        date: today,
        allDay: true,
        color: const Color(0xff1684B4),
        reminder: 'none',
      ),
    );
    thriveDebug.events.add(
      CalendarEvent(
        id: 'ev2',
        title: 'Grandma day',
        date: today,
        allDay: true,
        recur: 'yearly',
        color: const Color(0xffe11d48),
        reminder: 'none',
      ),
    );
    thriveDebug.taskLists.add(
      TaskList(
        id: 'tl1',
        name: 'Household',
        color: const Color(0xff0E9A8D),
        tasks: [ListTask(id: 't1', title: 'Fix tap', assignee: 'me')],
      ),
    );
    thriveDebug.shoppingLists.add(
      ShoppingList(
        id: 'sl1',
        name: 'Groceries',
        items: [
          ShopItem(id: 's1', name: 'Milk', qty: 2),
          ShopItem(id: 's2', name: 'Bread'),
        ],
      ),
    );
    thriveDebug.weeklyPlan[today] = DayPlan(dateIso: today, dinner: 'Tacos');
    thriveDebug.cards.add(
      DiscountCard(
        id: 'c1',
        name: 'Albert Heijn',
        number: '5901234123457',
        color: const Color(0xff1684B4),
      ),
    );
    thriveDebug.starsMap['me'] = 3;
    thriveDebug.importedCalendars.add(
      ImportedCalendar.fromJson({
        'id': 'ic1',
        'name': 'School feed',
        'url': 'https://x/a.ics',
      }),
    );
  });
}

void main() {
  testWidgets('first run shows the default board with the add affordance', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    expect(thriveDebug.homeBoard, isNull); // never edited
    expect(thriveDebug.effectiveHomeBoard().map((e) => e.widgetId), [
      'balance',
      'today',
      'tasks',
      'shopping',
    ]);
    expect(find.textContaining('PROJECTED BALANCE'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-add-widget')), findsOneWidget);
  });

  testWidgets('edit mode: remove persists; emptied board stays empty', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    kAnalyticsEvents.clear();
    await tester.tap(find.byKey(const ValueKey('home-edit-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-edit-list')), findsOneWidget);

    // Remove everything.
    for (var i = 3; i >= 0; i--) {
      await tester.tap(find.byKey(ValueKey('home-remove-$i')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('home-edit-toggle')));
    await tester.pumpAndSettle();
    expect(thriveDebug.homeBoard, isEmpty);
    expect(find.text('Your board is empty'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-add-widget')), findsOneWidget);
    expect(
      kAnalyticsEvents.where((e) => e.name == 'home_widget_removed').length,
      4,
    );

    // Survives a reboot: still deliberately empty, not re-defaulted.
    await rebootApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    expect(thriveDebug.homeBoard, isEmpty);
    expect(find.text('Your board is empty'), findsOneWidget);
  });

  testWidgets('reorder + long-press enters edit mode', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.longPress(find.textContaining('PROJECTED BALANCE'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-edit-list')), findsOneWidget);

    thriveDebug.reorderHomeWidget(0, 3);
    await tester.pumpAndSettle();
    expect(thriveDebug.homeBoard!.map((e) => e.widgetId).toList(), [
      'today',
      'tasks',
      'shopping',
      'balance',
    ]);
    await rebootApp(tester);
    expect(thriveDebug.homeBoard!.map((e) => e.widgetId).toList(), [
      'today',
      'tasks',
      'shopping',
      'balance',
    ]);
  });

  testWidgets('picker: category filters, greyed placed widgets, add', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    kAnalyticsEvents.clear();
    await tester.tap(find.byKey(const ValueKey('home-add-widget')));
    await tester.pumpAndSettle();
    expect(find.text('Add a widget'), findsWidgets);

    // Placed widgets are greyed out.
    expect(find.text('Already on your board'), findsNWidgets(4));

    // Category filter narrows the list.
    await tester.tap(find.byKey(const ValueKey('picker-filter-money')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('picker-w-meals')), findsNothing);
    expect(find.byKey(const ValueKey('picker-w-savings')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('picker-w-savings')));
    await tester.pumpAndSettle();
    expect(thriveDebug.homeBoard!.last.widgetId, 'savings');
    expect(kAnalyticsEvents.map((e) => e.name), contains('home_widget_added'));
  });

  testWidgets('size chip cycles only supported sizes', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('home-edit-toggle')));
    await tester.pumpAndSettle();
    // Entry 0 is balance (m/l).
    expect(thriveDebug.effectiveHomeBoard()[0].size, 'm');
    await tester.tap(find.byKey(const ValueKey('home-size-0')));
    await tester.pumpAndSettle();
    expect(thriveDebug.homeBoard![0].size, 'l');
    await tester.tap(find.byKey(const ValueKey('home-size-0')));
    await tester.pumpAndSettle();
    expect(thriveDebug.homeBoard![0].size, 'm');
  });

  testWidgets('options: tasks only-mine toggle stored on the entry', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('home-edit-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-edit-opts-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Only my tasks'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(thriveDebug.homeBoard![2].options['onlyMine'], isFalse);
  });

  testWidgets('every catalogue widget renders in every supported size', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    seedRichWorkspace();
    for (final def in kHomeWidgetCatalog) {
      for (final size in def.sizes) {
        thriveDebug.mutateState(
          () => thriveDebug.homeBoard = [
            BoardEntry(widgetId: def.id, size: size),
          ],
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('home-w-${def.id}-0')),
          findsOneWidget,
          reason: '${def.id} at $size should render',
        );
      }
    }
    // And a paired row of two S widgets.
    thriveDebug.mutateState(
      () => thriveDebug.homeBoard = [
        BoardEntry(widgetId: 'income', size: 's'),
        BoardEntry(widgetId: 'savings', size: 's'),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-w-income-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-w-savings-1')), findsOneWidget);
  });

  testWidgets('micro actions: pay a bill and tick a shopping item in place', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    seedRichWorkspace();
    final (cat, bill) = thriveDebug.unpaidItemsThisMonth().first;
    thriveDebug.mutateState(
      () => thriveDebug.homeBoard = [
        BoardEntry(widgetId: 'next_bills'),
        BoardEntry(widgetId: 'shopping'),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('home-bill-pay-${bill.id}')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(bill.paid, isTrue);
    expect(cat.isIncome, isFalse);

    await tester.tap(
      find.byKey(const ValueKey('home-shop-tick-s1')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(
      thriveDebug.shoppingLists
          .firstWhere((l) => l.id == 'sl1')
          .items
          .firstWhere((i) => i.id == 's1')
          .checked,
      isTrue,
    );
  });

  testWidgets('quick actions widget runs its actions', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.mutateState(
      () => thriveDebug.homeBoard = [
        BoardEntry(widgetId: 'quick_actions', size: 'm'),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('home-qa-add_event')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    // Both the widget's button label and the opened editor's title match.
    expect(find.text('New event'), findsNWidgets(2));
  });

  testWidgets('family note + divider store their text via options', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.mutateState(
      () => thriveDebug.homeBoard = [
        BoardEntry(widgetId: 'family_note'),
        BoardEntry(widgetId: 'divider'),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing pinned.'), findsOneWidget);

    await tester.tap(find.text('Write a note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Grandma arrives Friday!',
    );
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Grandma arrives Friday!'), findsOneWidget);
    expect(
      thriveDebug.homeBoard![0].options['text'],
      'Grandma arrives Friday!',
    );
  });

  testWidgets('kid profiles get the kid-safe subset only', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    // Mark my member row as a kid.
    thriveDebug.mutateState(() {
      thriveDebug.curFamily()!.members.first.role = 'kid';
    });
    await tester.pumpAndSettle();
    expect(thriveDebug.amIKidProfile(), isTrue);

    // Money widgets are neither offered…
    final offered = thriveDebug.offeredHomeWidgets().map((d) => d.id).toSet();
    expect(offered.contains('balance'), isFalse);
    expect(offered.contains('next_bills'), isFalse);
    expect(offered, contains('today'));
    expect(offered, contains('meals'));
    expect(offered, contains('pocket_money'));

    // …nor renderable, even when stored on the board.
    thriveDebug.mutateState(
      () => thriveDebug.homeBoard = [
        BoardEntry(widgetId: 'balance'),
        BoardEntry(widgetId: 'meals'),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('PROJECTED BALANCE'), findsNothing);
    // The filtered board renders meals first (balance was dropped).
    expect(find.byKey(const ValueKey('home-w-meals-0')), findsOneWidget);
  });

  testWidgets('kid toggle in the member edit sheet flips the role', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    final other = thriveDebug.curFamily()!.members.firstWhere(
      (m) => m.role != 'owner',
    );
    thriveDebug.editMember(other.id, other.name, other.email, kid: true);
    await tester.pumpAndSettle();
    expect(other.role, 'kid');
    thriveDebug.editMember(other.id, other.name, other.email, kid: false);
    await tester.pumpAndSettle();
    expect(other.role, 'member');
    // Owners can never become kids.
    final owner = thriveDebug.curFamily()!.members.firstWhere(
      (m) => m.role == 'owner',
    );
    thriveDebug.editMember(owner.id, owner.name, owner.email, kid: true);
    await tester.pumpAndSettle();
    expect(owner.role, 'owner');
  });

  testWidgets('options sheets: blocks, whose events, list, quick actions', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    seedRichWorkspace();
    thriveDebug.mutateState(
      () => thriveDebug.homeBoard = [
        BoardEntry(widgetId: 'budget_blocks'),
        BoardEntry(widgetId: 'today'),
        BoardEntry(widgetId: 'shopping'),
        BoardEntry(widgetId: 'quick_actions', size: 'm'),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-edit-toggle')));
    await tester.pumpAndSettle();

    // Budget blocks: pick a specific block.
    await tester.tap(find.byKey(const ValueKey('home-edit-opts-0')));
    await tester.pumpAndSettle();
    final firstChip = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String>
          ? (w.key! as ValueKey<String>).value.startsWith('opt-block-')
          : false,
    );
    await tester.tap(firstChip.first);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(thriveDebug.homeBoard![0].options['blocks'], isNotEmpty);

    // Today: just me.
    await tester.tap(find.byKey(const ValueKey('home-edit-opts-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('opt-who-me')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(thriveDebug.homeBoard![1].options['who'], 'me');

    // Shopping: pick the seeded list.
    await tester.tap(find.byKey(const ValueKey('home-edit-opts-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('opt-list-sl1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(thriveDebug.homeBoard![2].options['listId'], 'sl1');

    // Quick actions: swap one of the four.
    await tester.tap(find.byKey(const ValueKey('home-edit-opts-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('opt-qa-add_expense')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('opt-qa-open_wallet')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(
      thriveDebug.homeBoard![3].options['actions'],
      isNot(contains('add_expense')),
    );
    expect(
      thriveDebug.homeBoard![3].options['actions'],
      contains('open_wallet'),
    );

    // Leaving edit mode renders "My day" (who=me) with the seeded event.
    await tester.tap(find.byKey(const ValueKey('home-edit-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('My day'), findsOneWidget);
  });

  testWidgets('imported feed eye + week strip day tap act in place', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    seedRichWorkspace();
    thriveDebug.mutateState(
      () => thriveDebug.homeBoard = [
        BoardEntry(widgetId: 'imported_cals'),
        BoardEntry(widgetId: 'week_strip'),
        BoardEntry(widgetId: 'family_day', size: 'l'),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('School feed'), findsOneWidget);
    expect(thriveDebug.importedCalendars.first.visible, isTrue);
    await tester.tap(
      find.byKey(const ValueKey('home-feed-eye-ic1')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(thriveDebug.importedCalendars.first.visible, isFalse);

    await tester.tap(find.text('This week'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(thriveDebug.tab, 'calendar');
  });

  test('board model: parse validates widgets and sizes', () {
    expect(parseHomeBoard('nope'), isNull);
    expect(parseHomeBoard(null), isNull);
    final parsed = parseHomeBoard([
      {'widgetId': 'balance', 'size': 'l'},
      {'widgetId': 'gone-widget'},
      {'widgetId': 'income', 'size': 'l'}, // unsupported → clamped to s
      {
        'widgetId': 'tasks',
        'options': {'onlyMine': true},
      },
    ])!;
    expect(parsed.map((e) => e.widgetId), ['balance', 'income', 'tasks']);
    expect(parsed[0].size, 'l');
    expect(parsed[1].size, 's');
    expect(parsed[2].options['onlyMine'], isTrue);
    final json = parsed.map((e) => e.toJson()).toList();
    expect(parseHomeBoard(json)!.map((e) => e.toJson()).toList(), json);
  });

  test('catalogue invariants: unique ids, valid sizes, kid subset', () {
    final ids = kHomeWidgetCatalog.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final d in kHomeWidgetCatalog) {
      expect(d.sizes, isNotEmpty);
      expect(d.sizes.every(const {'s', 'm', 'l'}.contains), isTrue);
      expect(const {'money', 'calendar', 'home'}.contains(d.category), isTrue);
    }
    final kidSafe = kHomeWidgetCatalog.where((d) => d.kidSafe).map((d) => d.id);
    expect(kidSafe, containsAll(['today', 'meals', 'chores', 'pocket_money']));
    // No money widget except pocket money is kid-safe.
    expect(
      kHomeWidgetCatalog
          .where((d) => d.category == 'money' && d.kidSafe)
          .map((d) => d.id),
      ['pocket_money'],
    );
  });
}
