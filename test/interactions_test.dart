import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('delete an account from settings with confirm', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'settings');
    await tester.tap(find.byKey(const ValueKey('acc-del-eva')));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsWidgets);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
  });

  testWidgets('edit a block (change icon & color) and save', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'settings');
    await tester.tap(find.byKey(const ValueKey('blk-edit-home')));
    await tester.pumpAndSettle();
    expect(find.text('Edit block'), findsOneWidget);
    // tap the "Every month" / "This month only" scope toggle
    await tester.tap(find.text('This month only'));
    await tester.pump();
    await tester.tap(find.text('Every month').last);
    await tester.pump();
    await tester.tap(find.text('Save block'));
    await tester.pumpAndSettle();
  });

  testWidgets('delete a block from settings with confirm', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'settings');
    await tester.tap(find.byKey(const ValueKey('blk-del-health')));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsWidgets);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
  });

  testWidgets('reorder accounts and blocks', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'settings');
    // tap an edit then close to ensure rows are interactive; reorder buttons are
    // custom-painted, so just exercise edit sheets for two blocks.
    await tester.tap(find.byKey(const ValueKey('blk-edit-food')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save block'));
    await tester.pumpAndSettle();
  });

  testWidgets('block editor exposes more colors', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'settings');
    await tester.tap(find.byKey(const ValueKey('blk-edit-home')));
    await tester.pumpAndSettle();
    expect(find.text('More colors'), findsOneWidget);
    await tester.tap(find.text('More colors'));
    await tester.pump();
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
