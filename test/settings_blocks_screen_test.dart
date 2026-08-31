import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'settings_v2_seed.dart';

/// Budget blocks sub-screen extras (#329): the warn-near-limits toggle, the
/// 90% nudge, the limit field writing this month's cap, and the delete
/// migration keeping entries.
void main() {
  Future<void> openBlocks(WidgetTester tester) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    await openMoreHub(tester);
    await tapHubRow(tester, 'money', 'more-blocks');
  }

  testWidgets('rows spell out direction, savings and the amber month scope', (
    tester,
  ) async {
    await openBlocks(tester);
    expect(find.text('Receives'), findsOneWidget); // income block
    expect(find.text('Withdraws · counts as savings'), findsOneWidget);
    expect(find.text('Every month · end dates'), findsOneWidget); // debt
    // No temporary block seeded → no amber month value yet.
    expect(find.textContaining('only'), findsNothing);
  });

  testWidgets('warn toggle flips, toasts and survives a reboot', (
    tester,
  ) async {
    await openBlocks(tester);
    expect(thriveDebug.budgetLimitWarn, isTrue);
    await tester.tap(find.byKey(const ValueKey('blocks-warn-toggle')));
    await tester.pump();
    expect(thriveDebug.budgetLimitWarn, isFalse);
    expect(find.text('Limit warnings off'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await rebootApp(tester);
    expect(thriveDebug.budgetLimitWarn, isFalse);
  });

  testWidgets('the studio limit field writes this month’s cap', (tester) async {
    await openBlocks(tester);
    await tester.tap(find.byKey(const ValueKey('blocks-row-food')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('block-limit')), '850');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(thriveDebug.data[2026]![kMonthKeys[6]]!.caps['food'], 850);
    expect(find.textContaining('Withdraws · limit'), findsOneWidget);
  });

  testWidgets('saving an entry at 90% of the cap nudges — unless warnings '
      'are off', (tester) async {
    await openBlocks(tester);
    // Give Food a €100 cap, then add a €95 entry.
    await tester.tap(find.byKey(const ValueKey('blocks-row-food')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('block-limit')), '100');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    thriveDebug.saveExpense(
      'add',
      'food',
      null,
      payee: 'Market',
      label: 'Groceries',
      amount: 95,
      paid: false,
      account: 'shared',
      recurring: false,
    );
    await tester.pump();
    expect(find.textContaining('Food is at 95% of its'), findsOneWidget);

    // With the warn toggle off, the same save keeps the plain toast.
    await tester.tap(find.byKey(const ValueKey('blocks-warn-toggle')));
    await tester.pump();
    thriveDebug.saveExpense(
      'add',
      'food',
      null,
      payee: 'Market',
      label: 'More groceries',
      amount: 5,
      paid: false,
      account: 'shared',
      recurring: false,
    );
    await tester.pump();
    expect(find.textContaining('% of its'), findsNothing);
  });

  testWidgets('deleting a block moves its open-month entries elsewhere', (
    tester,
  ) async {
    await openBlocks(tester);
    thriveDebug.saveExpense(
      'add',
      'health',
      null,
      payee: 'Pharmacy',
      label: 'Vitamins',
      amount: 12,
      paid: false,
      account: 'shared',
      recurring: false,
    );
    await tester.pump();
    final before =
        thriveDebug.data[2026]![kMonthKeys[6]]!.blocks['health']!.length;
    expect(before, greaterThan(0));
    await tester.tap(find.byKey(const ValueKey('blocks-row-health')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
    await tester.pumpAndSettle();
    expect(thriveDebug.cats.any((c) => c.key == 'health'), isFalse);
    // The entries moved into the first remaining withdraws block.
    final fallbackKey = thriveDebug.cats.firstWhere((c) => !c.isIncome).key;
    final moved = thriveDebug.data[2026]![kMonthKeys[6]]!.blocks[fallbackKey]!;
    expect(moved.any((it) => it.label == 'Vitamins'), isTrue);
  });
}
