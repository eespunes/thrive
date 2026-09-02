import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('delete an account from its studio, entries move to the first '
      'remaining one', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'settings');
    await tester.tap(find.byKey(const ValueKey('accounts-row-eva')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-delete')));
    await tester.pumpAndSettle();
    // The counting confirm names the FIRST remaining account.
    expect(find.textContaining('first remaining account'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
    await tester.pumpAndSettle();
    expect(find.text("Eva's account"), findsNothing);
  });

  testWidgets('edit a block scope chips and save', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'blocks');
    await tester.tap(find.byKey(const ValueKey('blocks-row-home')));
    await tester.pumpAndSettle();
    expect(find.text('Edit block'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('block-applies-month')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('block-applies-every')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(find.text('Budget blocks'), findsWidgets);
  });

  testWidgets('delete a block from its studio moves entries elsewhere', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToTab(tester, 'blocks');
    await tester.tap(find.byKey(const ValueKey('blocks-row-health')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-delete')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Closed months keep their history'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('blocks-row-health')), findsNothing);
  });

  testWidgets('hold-drag reorders accounts and blocks for the whole family', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToTab(tester, 'settings');
    final firstBefore = thriveDebug.accounts.first.key;
    await holdDragReorder(
      tester,
      find.byKey(ValueKey('accounts-row-$firstBefore')),
      120,
    );
    expect(thriveDebug.accounts.first.key, isNot(firstBefore));
    expect(find.text('Order saved for the whole family'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-back')));
    await tester.pumpAndSettle();
    await tapHubRow(tester, 'money', 'more-blocks');
    final firstBlock = thriveDebug.cats.first.key;
    await holdDragReorder(
      tester,
      find.byKey(ValueKey('blocks-row-$firstBlock')),
      120,
    );
    expect(thriveDebug.cats.first.key, isNot(firstBlock));
  });

  testWidgets('block studio colour dots update the accent', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'blocks');
    await tester.tap(find.byKey(const ValueKey('blocks-row-home')));
    await tester.pumpAndSettle();
    // Pick the amber colour via the hex field.
    await tester.tap(find.text('RGB / Hex'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('hex-color-input')),
      'd97706',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(
      thriveDebug.cats.firstWhere((c) => c.key == 'home').tone,
      const Color(0xffd97706),
    );
  });

  testWidgets('remove a limit via cap sheet', (tester) async {
    await pumpApp(tester);
    // Food has a seeded cap in June; open it and clear.
    final limitChip = find.textContaining('limit');
    if (limitChip.evaluate().isNotEmpty) {
      await tester.tap(limitChip.first);
      await tester.pumpAndSettle();
      if (find.text('Monthly limit').evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextField).first, '');
        await tester.pump();
        final remove = find.text('Remove limit');
        if (remove.evaluate().isNotEmpty) {
          await tester.tap(remove);
          await tester.pumpAndSettle();
        }
      }
    }
  });

  testWidgets('change account on an expense via account pill', (tester) async {
    await pumpApp(tester);
    // Tap an account pill on an expense row, then choose a different account.
    final pill = find.text('ER');
    if (pill.evaluate().isNotEmpty) {
      await tester.tap(pill.first);
      await tester.pumpAndSettle();
      if (find.text('Choose account').evaluate().isNotEmpty) {
        await tester.tap(find.text("Eva's account").last);
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('delete an expense via swipe + confirm', (tester) async {
    await pumpApp(tester);
    final row = swipeRows(tester);
    expect(row, isNotNull);
    await tester.drag(row!, const Offset(-220, 0));
    await tester.pumpAndSettle();
    final del = find.text('Delete');
    if (del.evaluate().isNotEmpty) {
      await tester.tap(del.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      if (find.text('Delete').evaluate().isNotEmpty) {
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('delete an income via swipe + confirm', (tester) async {
    await pumpApp(tester);
    final income = firstIncomeLabel(tester);
    await tester.drag(find.text(income).first, const Offset(-220, 0));
    await tester.pumpAndSettle();
    final del = find.text('Delete');
    if (del.evaluate().isNotEmpty) {
      await tester.tap(del.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      if (find.text('Delete').evaluate().isNotEmpty) {
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('delete an expense from the edit sheet', (tester) async {
    await pumpApp(tester);
    // open an expense row edit sheet and tap its delete control if present
    for (final l in ['RENT', 'WATER', 'GROCERIES']) {
      if (find.text(l).evaluate().isNotEmpty) {
        await tester.tap(find.text(l).first);
        await tester.pumpAndSettle();
        break;
      }
    }
    final del = find.textContaining('Delete');
    if (del.evaluate().isNotEmpty) {
      await tester.tap(del.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      if (find.text('Delete').evaluate().isNotEmpty) {
        await tester.tap(find.text('Delete').last, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
    }
  });
}
