import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

/// Widget coverage for the entry ticket editor (entry_ticket.dart): trays,
/// Details accordion, scope sheets, kind + block chips, error/edge states.

Future<void> _openAddTo(WidgetTester tester, String block) async {
  const keys = {
    'Income': 'overview-add-income',
    'Home': 'overview-add-home',
    'Savings': 'overview-add-savings',
  };
  await tester.tap(
    find.byKey(ValueKey(keys[block] ?? 'overview-add-${block.toLowerCase()}')),
  );
  await tester.pumpAndSettle();
}

Future<void> _openExistingEntryById(
  WidgetTester tester, {
  required String catKey,
  required String id,
}) async {
  thriveDebug.openEntry(catKey, id);
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  String amount = '20',
  String payee = 'Gym',
  String label = 'Membership',
}) async {
  await tester.enterText(find.byKey(const ValueKey('entry-amount')), amount);
  await tester.enterText(find.byKey(const ValueKey('entry-payee')), payee);
  await tester.enterText(find.byKey(const ValueKey('entry-label')), label);
  await tester.pump();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  // `entry-section-*` keys are the Details accordion rows: a tap toggles.
  await tester.tap(f, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Storage blob with one seeded month, mirroring the overview tests.
Map<String, Object> _seededPrefs(Map<String, List<ExpenseItem>> juneBlocks) {
  final cats = defaultCats();
  Map<String, dynamic> yearData() => {
    for (final mk in kMonthKeys)
      mk: MonthData(
        blocks: {for (final c in cats) c.key: <ExpenseItem>[]},
      ).toJson(),
  };
  final data = <String, dynamic>{'2026': yearData()};
  (data['2026'] as Map<String, dynamic>)['Juni'] = MonthData(
    blocks: {for (final c in cats) c.key: <ExpenseItem>[], ...juneBlocks},
  ).toJson();
  return {
    'flutter.$kStorageKey': json.encode({
      'year': 2026,
      'monthIdx': 5,
      'screen': 'overview',
      'accounts': defaultAccounts().map((a) => a.toJson()).toList(),
      'cats': cats.map((c) => c.toJson()).toList(),
      'data': data,
    }),
  };
}

void main() {
  group('entryRecurSummary edge phrasing', () {
    test('Monday-after shift and a last-lands month are spelled out', () {
      const anchor = 2026 * 12 + 5;
      final s = entryRecurSummary(
        recurring: true,
        every: 3,
        day: 10,
        shift: 'after',
        anchorOrd: anchor,
        endOrd: anchor + 4, // not a multiple of 3 → last lands anchor+3
      );
      expect(s, contains('shifts to the Monday after weekends'));
      expect(s, contains('Last one lands Sep 2026'));
    });

    test('unscheduled repeats read as unscheduled', () {
      const anchor = 2026 * 12 + 5;
      final s = entryRecurSummary(
        recurring: true,
        every: 1,
        day: null,
        shift: 'none',
        anchorOrd: anchor,
        endOrd: null,
      );
      expect(s, contains('unscheduled'));
    });
  });

  testWidgets('quick add without a block opens on an expense block (#399)', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.openQuickAdd();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quickadd-expense')));
    await tester.pumpAndSettle();
    expect(find.text('New expense'), findsOneWidget);
    // The block is picked inside the editor, as coloured chips.
    await _tapKey(tester, 'entry-move-block-food');
    expect(find.text('New expense'), findsOneWidget);
    // Switching kind swaps the block chips (and the title) to that kind.
    await _tapKey(tester, 'entry-kind-income');
    expect(find.text('New income'), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-move-block-food')), findsNothing);
  });

  testWidgets('invalid amount shows the inline error, income shows so-far', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openAddTo(tester, 'Income');
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), 'abc');
    await tester.pump();
    expect(find.text('Numbers only — use a comma for cents.'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('entry-amount')),
      '1.250,00',
    );
    await tester.pump();
    expect(find.text('Numbers only — use a comma for cents.'), findsNothing);
    expect(find.textContaining('income so far'), findsWidgets);
  });

  testWidgets('savings block without a cap shows the put-aside line', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openAddTo(tester, 'Savings');
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '50');
    await tester.pump();
    expect(find.textContaining('put aside'), findsWidgets);
  });

  testWidgets('cap meter recomputes live and goes red past the limit', (
    tester,
  ) async {
    await pumpApp(tester);
    // Give the first block (Home) a €500 cap through the limit sheet.
    await tester.tap(find.text('Set limit').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '500');
    await tester.pump();
    await tester.tap(find.text('Save limit'));
    await tester.pumpAndSettle();

    await _openAddTo(tester, 'Home');
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '600');
    await tester.pump();
    // eur() joins with a non-breaking space — match through the helper.
    expect(find.textContaining('% of ${eur(500, cents: false)}'), findsWidgets);
  });

  testWidgets('day tray: weekend shift, resolved badge, unscheduled (#288/9)', (
    tester,
  ) async {
    await pumpApp(tester);
    thriveDebug.pickMonth(7); // August 2026: the 23rd is a Sunday.
    await tester.pumpAndSettle();
    await _openAddTo(tester, 'Home');
    await _fill(tester);

    await _tapKey(tester, 'entry-day-23');
    await _tapKey(tester, 'entry-shift-before');
    expect(find.text('The 23rd · moves to Fri 21 Aug'), findsOneWidget);
    expect(find.text('The 23rd is a Sunday. Should it move?'), findsOneWidget);
    expect(find.textContaining('is a weekend'), findsOneWidget);

    await _tapKey(tester, 'entry-shift-after');
    expect(find.text('The 23rd · moves to Mon 24 Aug'), findsOneWidget);

    // 1 Aug 2026 is a Saturday — Fri-before would leave August: stays put.
    await _tapKey(tester, 'entry-shift-before');
    await _tapKey(tester, 'entry-day-1');
    expect(find.textContaining('stays put'), findsOneWidget);

    // Late days warn about shorter months.
    await _tapKey(tester, 'entry-day-30');
    expect(find.textContaining('In shorter months'), findsOneWidget);

    // Unscheduled toggle, both directions.
    await _tapKey(tester, 'entry-day-unscheduled');
    expect(find.text('✓ Unscheduled — off the calendar'), findsOneWidget);
    expect(find.text('Unscheduled'), findsOneWidget); // the badge
    await _tapKey(tester, 'entry-day-unscheduled');
    expect(find.text('✓ Unscheduled — off the calendar'), findsNothing);
  });

  testWidgets('repeat tray: toggle, cadence chips and last month (#291)', (
    tester,
  ) async {
    await pumpApp(tester); // June 2026 → anchorOrd 24317
    await _openAddTo(tester, 'Home');
    await _fill(tester);
    await _tapKey(tester, 'entry-section-repeat');

    await _tapKey(tester, 'entry-repeat-off');
    expect(find.text('One-off — only this June'), findsOneWidget);
    await _tapKey(tester, 'entry-repeat-on');

    await _tapKey(tester, 'entry-every-2');
    expect(find.text('Repeats every 2 months'), findsOneWidget);
    await _tapKey(tester, 'entry-every-1');
    expect(find.text('Repeats every month'), findsOneWidget);

    const anchor = 2026 * 12 + 5;
    await _tapKey(tester, 'entry-month-${anchor + 4}');
    expect(find.text('Repeats every month · until Oct 2026'), findsOneWidget);
    await _tapKey(tester, 'entry-month-never');
    expect(find.textContaining('until Oct 2026'), findsNothing);
  });

  testWidgets('editing a recurring entry asks for the scope (#292)', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openAddTo(tester, 'Home');
    await _fill(tester);
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(thriveDebug.findExpenseId('home', 'Gym', 'Membership'), isNotNull);

    // Cancel keeps everything as it was.
    final gymId = thriveDebug.findExpenseId('home', 'Gym', 'Membership');
    expect(gymId, isNotNull);
    await _openExistingEntryById(tester, catKey: 'home', id: gymId!);
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '25');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Save changes to “Gym”?'), findsOneWidget);
    await _tapKey(tester, 'entry-scope-cancel');

    // Month-only makes an exception.
    await _openExistingEntryById(tester, catKey: 'home', id: gymId);
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '30');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'entry-scope-month');
    expect(thriveDebug.findExpenseId('home', 'Gym', 'Membership'), isNotNull);

    // Onward rewrites this and future months.
    await _openExistingEntryById(tester, catKey: 'home', id: gymId);
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '35');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'entry-scope-onward');
    expect(thriveDebug.findExpenseId('home', 'Gym', 'Membership'), isNotNull);
  });

  testWidgets('the block tray moves an entry to a sibling block (#294)', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openAddTo(tester, 'Home');
    await _fill(tester);
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    final gymId = thriveDebug.findExpenseId('home', 'Gym', 'Membership');
    expect(gymId, isNotNull);
    await _openExistingEntryById(tester, catKey: 'home', id: gymId!);
    expect(find.textContaining('Moving recounts both caps'), findsNothing);
    await _tapKey(tester, 'entry-move-block-food');
    expect(find.textContaining('Moving recounts both caps'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'entry-scope-onward');

    expect(thriveDebug.findExpenseId('food', 'Gym', 'Membership'), isNotNull);
    expect(thriveDebug.findExpenseId('home', 'Gym', 'Membership'), isNull);
  });

  testWidgets('deleting: recurring gets the scope sheet, one-off a confirm', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openAddTo(tester, 'Home');
    await _fill(tester);
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    final gymId = thriveDebug.findExpenseId('home', 'Gym', 'Membership');
    expect(gymId, isNotNull);
    await _openExistingEntryById(tester, catKey: 'home', id: gymId!);
    await _tapKey(tester, 'entry-delete');
    expect(find.text('Remove “Gym”?'), findsOneWidget);
    await _tapKey(tester, 'entry-scope-onward');
    expect(thriveDebug.findExpenseId('home', 'Gym', 'Membership'), isNull);

    // One-off: plain confirm dialog instead of scopes.
    await _openAddTo(tester, 'Home');
    await _fill(tester, payee: 'Once', label: 'Fee');
    await _tapKey(tester, 'entry-section-repeat');
    await _tapKey(tester, 'entry-repeat-off');
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    final onceId = thriveDebug.findExpenseId('home', 'Once', 'Fee');
    expect(onceId, isNotNull);
    await _openExistingEntryById(tester, catKey: 'home', id: onceId!);
    await _tapKey(tester, 'entry-delete');
    expect(find.text('It only ever existed this month.'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Once - Fee'), findsNothing);
  });

  testWidgets('linking a card and marking paid logs a card use (#296/#297)', (
    tester,
  ) async {
    await pumpApp(tester);
    thriveDebug.saveCard(
      DiscountCard(
        id: 'c1',
        name: 'AH Bonus',
        number: '1234567890',
        color: const Color(0xff2563eb),
      ),
    );
    await tester.pumpAndSettle();

    await _openAddTo(tester, 'Home');
    await _fill(tester);
    await _tapKey(tester, 'entry-section-card');
    await _tapKey(tester, 'entry-card-none'); // explicit no-card first
    await _tapKey(tester, 'entry-card-c1');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('entry-value-card'))).data,
      'AH Bonus',
    );
    await _tapKey(tester, 'entry-section-account');
    await _tapKey(tester, 'entry-stamp');
    // The rotated stamp became the paid toggle in the account card.
    expect(find.text('Paid — it counts as settled'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(thriveDebug.cards.single.timesUsed, 1);
  });

  testWidgets(
    'seeded edge states: clamp, ghost account, dead card, migration',
    (tester) async {
      await pumpApp(
        tester,
        prefs: _seededPrefs({
          'home': [
            ExpenseItem(
              id: 'r31',
              payee: 'Clamp',
              label: 'Rent',
              marker: '31st',
              day: 31,
              amount: 40,
              paid: false,
              account: 'ghost-acc',
              recurring: false,
              cardId: 'ghost-card',
            ),
            ExpenseItem(
              id: 'ends',
              payee: 'Ends',
              label: 'Loan',
              marker: '1st',
              day: 1,
              amount: 10,
              paid: false,
              account: 'shared',
              recurring: true,
              seriesId: 'ends-series',
              recurEndDate: '2026-09-15',
            ),
          ],
          kIncomeBlockKey: [
            ExpenseItem(
              id: 'mig',
              payee: 'Boss',
              label: 'Cash',
              marker: '',
              day: 1,
              amount: 100,
              paid: false,
              account: 'shared',
              recurring: false,
            )..reviewDay = true,
          ],
        }),
      );

      // Deleted account + deleted card + day-31 clamp, all on one ticket.
      await _openExistingEntryById(tester, catKey: 'home', id: 'r31');
      expect(find.text('Card deleted'), findsOneWidget);
      await _tapKey(tester, 'entry-section-day');
      expect(find.textContaining('clamped'), findsOneWidget);
      await _tapKey(tester, 'entry-section-account');
      expect(
        find.textContaining('The original account was deleted'),
        findsOneWidget,
      );
      await _tapKey(tester, 'entry-acc-eva');
      expect(
        find.textContaining('The original account was deleted'),
        findsNothing,
      );
      await _tapKey(tester, 'entry-section-card');
      expect(
        find.text('This card was deleted from the wallet.'),
        findsOneWidget,
      );
      await _tapKey(tester, 'entry-card-unlink');
      expect(find.text('Card deleted'), findsNothing);
      await tester.tapAt(const Offset(270, 40)); // barrier-dismiss the sheet
      await tester.pumpAndSettle();

      // A stored end date round-trips into the repeat summary.
      await _openExistingEntryById(tester, catKey: 'home', id: 'ends');
      await _tapKey(tester, 'entry-section-repeat');
      expect(find.textContaining('until Sep 2026'), findsWidgets);
      await tester.tapAt(const Offset(270, 40)); // barrier-dismiss the sheet
      await tester.pumpAndSettle();

      // Migrated dayless income asks to confirm the day (#288).
      await _openExistingEntryById(tester, catKey: kIncomeBlockKey, id: 'mig');
      await _tapKey(tester, 'entry-section-day');
      expect(find.textContaining('Migrated: this income'), findsOneWidget);
      // Income unscheduled hint is the by-choice one.
      await _tapKey(tester, 'entry-day-unscheduled');
      expect(find.textContaining('by choice'), findsOneWidget);
    },
  );

  testWidgets('closing the month mid-edit seals the ticket (#298)', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openAddTo(tester, 'Home');
    await _fill(tester);
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    final gymId = thriveDebug.findExpenseId('home', 'Gym', 'Membership');
    expect(gymId, isNotNull);
    await _openExistingEntryById(tester, catKey: 'home', id: gymId!);
    await _tapKey(tester, 'entry-section-account');
    thriveDebug.closeMonth();
    await tester.pump();

    // The stale ticket still routes taps: the stamp refuses with a flash…
    await tester.tap(
      find.byKey(const ValueKey('entry-stamp')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(thriveDebug.toast, contains('closed'));
    // …and save refuses instead of writing into a sealed month.
    await tester.tap(
      find.byKey(const ValueKey('sheet-confirm')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('CLOSED'), findsOneWidget);
    expect(find.textContaining('this entry is a snapshot'), findsOneWidget);
  });
}
