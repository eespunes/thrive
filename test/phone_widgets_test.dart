import 'dart:convert';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'helpers.dart';

// The Android home-screen widgets (epic #224): payload building, the
// till-code PNG, background widget actions on the raw v4 blob, deep-link
// routing and the hide-amounts privacy option.

/// Payload-building tests pin the clock: with the real date, any bill whose
/// due day is <= today counts as "due today", so fixed markers like '28'
/// made the money assertions fail from the 28th of each month onward.
final DateTime _testNow = DateTime(2026, 3, 10);

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

Workspace _ws([DateTime? now]) {
  final month = MonthData();
  month.blocks['income'] = [
    ExpenseItem.fromJson({
      'id': 'inc1',
      'label': 'Salary',
      'marker': '1',
      'amount': 3000,
      'paid': true,
      'account': 'shared',
    }),
  ];
  month.blocks['home'] = [
    ExpenseItem.fromJson({
      'id': 'rent',
      'label': 'Rent',
      'marker': '1',
      'amount': 900,
      'paid': true,
      'account': 'shared',
    }),
    ExpenseItem.fromJson({
      'id': 'net',
      'payee': 'Internet and TV',
      'label': 'Internet',
      'marker': '${(now ?? DateTime.now()).day}',
      'amount': 94.95,
      'paid': false,
      'account': 'shared',
      'cardId': 'c1',
    }),
    ExpenseItem.fromJson({
      'id': 'later',
      'label': 'Insurance',
      // Always strictly in the future so it never counts into dueToday —
      // a fixed '28' made this test fail on the 28th–31st of each month.
      'marker': '${DateTime.now().day + 1}',
      'amount': 50,
      'paid': false,
      'account': 'shared',
    }),
  ];
  final cats = [
    Category.fromJson({
      'key': 'income',
      'title': 'Income',
      'icon': 'wallet',
      'isIncome': true,
    }),
    Category.fromJson({'key': 'home', 'title': 'Home', 'icon': 'home'}),
  ];
  now ??= DateTime.now();
  return Workspace(
    accounts: [],
    cats: cats,
    data: {
      now.year: {kMonthKeys[now.month - 1]: month},
    },
    events: [
      CalendarEvent(
        id: 'ev1',
        title: 'Dentist',
        date: _iso(now),
        start: '14:30',
        end: '15:00',
        color: const Color(0xffe11d48),
        reminder: 'none',
      ),
      CalendarEvent(
        id: 'ev2',
        title: 'Not today',
        date: '2000-01-01',
        color: const Color(0xff000000),
        reminder: 'none',
      ),
    ],
    taskLists: [
      TaskList(
        id: 'tl1',
        name: 'House',
        color: const Color(0xff0E9A8D),
        tasks: [
          ListTask(id: 't1', title: 'Bins'),
          ListTask(id: 'tdone', title: 'Done', done: true),
        ],
      ),
    ],
    shoppingLists: [
      ShoppingList(
        id: 'sl1',
        name: 'Groceries',
        items: [
          ShopItem(id: 's1', name: 'Milk'),
          ShopItem(id: 's2', name: 'Bread', checked: true),
        ],
      ),
    ],
    cards: [
      DiscountCard(
        id: 'c0',
        name: 'Rarely used',
        number: '111',
        color: const Color(0xff475569),
      ),
      DiscountCard(
        id: 'c1',
        name: 'Supermarket',
        number: '5901234123457',
        color: const Color(0xff0f9d6a),
        timesUsed: 14,
      ),
    ],
  );
}

Map<String, dynamic> _payload({bool hide = false, bool kid = false}) {
  final now = _testNow;
  return buildPhoneWidgetPayload(
    now: now,
    ws: _ws(now),
    year: now.year,
    monthIdx: now.month - 1,
    kid: kid,
    hideAmounts: hide,
  );
}

void main() {
  test('payload: money numbers, due labels and bill order', () {
    final p = _payload();
    final money = p['money'] as Map;
    expect(money['balance'], eur(3000 - 1044.95));
    expect(money['stillToPay'], eur(144.95));
    expect(money['dueToday'], eur(94.95));
    expect(money['progress'], greaterThan(80));
    final bills = money['bills'] as List;
    expect(bills.length, 2);
    expect((bills[0] as Map)['label'], 'Internet and TV');
    expect((bills[0] as Map)['due'], 'Today');
    expect((bills[0] as Map)['primary'], isTrue);
    expect((bills[1] as Map)['label'], 'Insurance');
    expect(money['monthKey'], kMonthKeys[_testNow.month - 1]);
  });

  test('payload: today events, tasks, top card and shopping', () {
    final p = _payload();
    final events = (p['today'] as Map)['events'] as List;
    expect(events.length, 1);
    expect((events[0] as Map)['title'], 'Dentist');
    expect((events[0] as Map)['time'], '14:30');
    final tasks = (p['today'] as Map)['tasks'] as List;
    expect(tasks.map((t) => (t as Map)['id']), ['t1']); // done excluded
    final card = p['card'] as Map;
    expect(card['id'], 'c1'); // most used wins
    expect(card['hint'], 'Tap to enlarge · used 14×');
    final shopping = p['shopping'] as Map;
    expect(shopping['left'], 1);
    expect(shopping['items'], ['Milk']);
    expect((p['quickActions'] as List).length, 4);
  });

  test('payload: hide-amounts masks every money string (#257)', () {
    final p = _payload(hide: true);
    final money = p['money'] as Map;
    expect(money['balance'], '€ ••••');
    expect(money['stillToPay'], '€ ••••');
    expect(((money['bills'] as List)[0] as Map)['amount'], '€ ••••');
    expect(widgetEur(12.5, false), eur(12.5));
  });

  test('payload: kid flag carried for the native side (#257)', () {
    expect(_payload(kid: true)['kid'], isTrue);
    expect(_payload()['kid'], isFalse);
  });

  test('renderCardCodePng draws a real code, and never throws', () {
    final png = renderCardCodePng(
      DiscountCard(
        id: 'c',
        name: 'S',
        number: '5901234123457',
        color: const Color(0xff000000),
      ),
    );
    final decoded = img.decodePng(png)!;
    var dark = 0;
    for (var x = 0; x < decoded.width; x += 2) {
      if (decoded.getPixel(x, decoded.height ~/ 2).r < 100) dark++;
    }
    expect(dark, greaterThan(5));

    final qr = img.decodePng(
      renderCardCodePng(
        DiscountCard(
          id: 'q',
          name: 'Q',
          number: '1234',
          codeType: 'qr',
          color: const Color(0xff000000),
        ),
      ),
    )!;
    expect(qr.width, qr.height);

    // Unrenderable content falls back to a blank plate, no throw.
    expect(
      renderCardCodePng(
        DiscountCard(
          id: 'e',
          name: 'E',
          number: '',
          color: const Color(0xff000000),
        ),
      ),
      isNotEmpty,
    );
  });

  group('applyPhoneWidgetAction', () {
    Map<String, dynamic> v4() => {
      'familyId': 'fam',
      'year': DateTime.now().year,
      'monthIdx': DateTime.now().month - 1,
      'workspaces': {'fam': _ws().toJson()},
    };

    test('tick_task toggles the task in place', () {
      final blob = v4();
      final uri = Uri.parse('thrive://act?do=tick_task&list=tl1&task=t1');
      expect(applyPhoneWidgetAction(blob, uri), isTrue);
      final ws = Workspace.fromJson(
        Map<String, dynamic>.from((blob['workspaces'] as Map)['fam'] as Map),
      );
      expect(ws.taskLists.first.tasks.first.done, isTrue);
      // Unknown task: no change.
      expect(
        applyPhoneWidgetAction(
          blob,
          Uri.parse('thrive://act?do=tick_task&list=tl1&task=nope'),
        ),
        isFalse,
      );
    });

    test('pay_bill pays the item and logs a card use', () {
      final blob = v4();
      final monthKey = kMonthKeys[DateTime.now().month - 1];
      final uri = Uri.parse(
        'thrive://act?do=pay_bill&year=${DateTime.now().year}'
        '&month=$monthKey&cat=home&id=net',
      );
      expect(applyPhoneWidgetAction(blob, uri), isTrue);
      final ws = Workspace.fromJson(
        Map<String, dynamic>.from((blob['workspaces'] as Map)['fam'] as Map),
      );
      final it = ws.data.values.first.values.first.blocks['home']!.firstWhere(
        (x) => x.id == 'net',
      );
      expect(it.paid, isTrue);
      expect(ws.cards.firstWhere((c) => c.id == 'c1').timesUsed, 15);
      // Already paid: refuses.
      expect(applyPhoneWidgetAction(blob, uri), isFalse);
    });

    test('closed months and unknown actions refuse', () {
      final blob = v4();
      final monthKey = kMonthKeys[DateTime.now().month - 1];
      final wsMap = (blob['workspaces'] as Map)['fam'] as Map;
      (((wsMap['data'] as Map)['${DateTime.now().year}'] as Map)[monthKey]
              as Map)['closed'] =
          true;
      expect(
        applyPhoneWidgetAction(
          blob,
          Uri.parse(
            'thrive://act?do=pay_bill&year=${DateTime.now().year}'
            '&month=$monthKey&cat=home&id=net',
          ),
        ),
        isFalse,
      );
      expect(
        applyPhoneWidgetAction(blob, Uri.parse('thrive://act?do=wat')),
        isFalse,
      );
      expect(
        applyPhoneWidgetAction({'familyId': 'x'}, Uri.parse('thrive://act')),
        isFalse,
      );
    });

    test('phoneWidgetPayloadFromV4 rebuilds after an action', () {
      final blob = v4();
      applyPhoneWidgetAction(
        blob,
        Uri.parse('thrive://act?do=tick_task&list=tl1&task=t1'),
      );
      final p = phoneWidgetPayloadFromV4(blob)!;
      expect(((p['today'] as Map)['tasks'] as List), isEmpty);
      expect(phoneWidgetPayloadFromV4({'familyId': 'x'}), isNull);
    });
  });

  testWidgets('handleWidgetLaunch routes every target with analytics', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    kAnalyticsEvents.clear();
    thriveDebug.saveCard(
      DiscountCard(
        id: 'c1',
        name: 'Supermarket',
        number: '5901234123457',
        color: const Color(0xff0f9d6a),
      ),
    );
    await tester.pumpAndSettle();

    thriveDebug.handleWidgetLaunch(Uri.parse('thrive://open?target=finance'));
    await tester.pumpAndSettle();
    expect(thriveDebug.tab, 'finance');

    thriveDebug.handleWidgetLaunch(Uri.parse('thrive://open?target=calendar'));
    await tester.pumpAndSettle();
    expect(thriveDebug.tab, 'calendar');

    thriveDebug.handleWidgetLaunch(
      Uri.parse('thrive://open?target=card&id=c1'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ready for the scanner'), findsOneWidget);
    await tester.tapAt(const Offset(210, 40));
    await tester.pumpAndSettle();

    thriveDebug.handleWidgetLaunch(Uri.parse('thrive://open?target=scan'));
    await tester.pumpAndSettle();
    expect(find.text('Scan a discount card'), findsOneWidget);
    await tester.tapAt(const Offset(210, 40));
    await tester.pumpAndSettle();

    thriveDebug.handleWidgetLaunch(Uri.parse('thrive://open?target=event'));
    await tester.pumpAndSettle();
    expect(find.text('New event'), findsOneWidget);
    await tester.tapAt(const Offset(210, 40));
    await tester.pumpAndSettle();

    thriveDebug.handleWidgetLaunch(Uri.parse('thrive://open?target=tasks'));
    await tester.pumpAndSettle();
    expect(thriveDebug.tab, 'lists');

    thriveDebug.handleWidgetLaunch(Uri.parse('thrive://open?target=nope'));
    await tester.pumpAndSettle();
    expect(thriveDebug.tab, 'home');

    expect(
      kAnalyticsEvents.where((e) => e.name == 'android_widget_opened').length,
      7,
    );
  });

  testWidgets('hide-amounts toggle in More persists across reboot', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(thriveDebug.widgetHideAmounts, isFalse);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tapHubRow(tester, 'money', 'more-widget-privacy');
    expect(thriveDebug.widgetHideAmounts, isTrue);
    expect(
      (thriveDebug.phoneWidgetPayload()['money'] as Map)['balance'],
      '€ ••••',
    );

    await rebootApp(tester);
    expect(thriveDebug.widgetHideAmounts, isTrue);
  });

  test('provider list matches the shipped widget set', () {
    expect(kPhoneWidgetProviders, [
      'MoneyWidgetProvider',
      'TodayWidgetProvider',
      'CardWidgetProvider',
      'QuickActionsWidgetProvider',
      'ShoppingWidgetProvider',
    ]);
  });

  test('payload survives a json round-trip (what the native side reads)', () {
    final decoded =
        json.decode(json.encode(_payload())) as Map<String, dynamic>;
    expect((decoded['money'] as Map)['month'], isNotEmpty);
    expect(decoded['card'], isNotNull);
  });
}
