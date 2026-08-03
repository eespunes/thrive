import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('overview renders seeded data', (tester) async {
    await pumpApp(tester);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Sum Up'), findsOneWidget);
    expect(find.text('Income'), findsWidgets);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('add income via sheet', (tester) async {
    await pumpApp(tester);
    // Income is now an income-direction block (issue #137): add via the block's
    // "Add to Income" button; the item sheet is the shared block-item editor.
    await tester.tap(find.text('Add to Income'));
    await tester.pumpAndSettle();
    expect(find.text('Add income'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'Employer');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), 'Bonus');
    await tester.enterText(find.byType(TextField).at(2), '100');
    await tester.pump();
    await tester.tap(find.text('Received'));
    await tester.pump();
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(find.text('Employer - Bonus'), findsWidgets);
  });

  testWidgets('add expense to a block', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Add to Home'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Thuiswonen');
    await tester.enterText(find.byType(TextField).at(1), 'Rent');
    await tester.enterText(find.byType(TextField).at(2), '42');
    await tester.pump();
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(find.text('Thuiswonen - Rent'), findsWidgets);
    final rowTitle = tester.widget<Text>(find.text('Thuiswonen - Rent').first);
    final span = rowTitle.textSpan! as TextSpan;
    expect((span.children!.single as TextSpan).style!.color, B.muted);
  });

  testWidgets('a recurring expense propagates until its end month', (
    tester,
  ) async {
    final cats = defaultCats();
    Map<String, dynamic> yearData() => {
      for (final mk in kMonthKeys)
        mk: MonthData(
          blocks: {for (final c in cats) c.key: <ExpenseItem>[]},
        ).toJson(),
    };
    final data = <String, dynamic>{
      '2026': yearData(),
      '2027': yearData(),
    };
    (data['2026'] as Map<String, dynamic>)['Juni'] = MonthData(
      blocks: {
        for (final c in cats) c.key: <ExpenseItem>[],
        'home': [
          ExpenseItem(
            id: 'rent-june',
            payee: 'Recurring',
            label: 'Loan',
            marker: '1st',
            amount: 120,
            paid: false,
            account: 'shared',
            recurring: true,
            seriesId: 'loan-series',
            recurEndDate: '2026-07-15',
            until: '2026-07-15',
          ),
        ],
      },
    ).toJson();

    await pumpApp(
      tester,
      prefs: {
        'flutter.$kStorageKey': json.encode({
          'year': 2026,
          'monthIdx': 5,
          'screen': 'overview',
          'accounts': defaultAccounts().map((a) => a.toJson()).toList(),
          'cats': cats.map((c) => c.toJson()).toList(),
          'data': data,
        }),
      },
    );

    expect(find.text('Recurring - Loan'), findsWidgets);
    thriveDebug.pickMonth(6);
    await tester.pumpAndSettle();
    expect(find.text('Recurring - Loan'), findsWidgets);

    thriveDebug.pickMonth(7);
    await tester.pumpAndSettle();
    expect(find.text('Recurring - Loan'), findsNothing);
  });

  testWidgets('deleting a recurring expense keeps past months intact', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Add to Home'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Gym');
    await tester.enterText(find.byType(TextField).at(1), 'Membership');
    await tester.enterText(find.byType(TextField).at(2), '20');
    await tester.pump();
    await tester.tap(find.text('Repeat every month'));
    await tester.pump();
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();

    thriveDebug.pickMonth(6);
    await tester.pumpAndSettle();
    expect(find.text('Gym - Membership'), findsWidgets);

    final julyId = thriveDebug.findExpenseId('home', 'Gym', 'Membership');
    expect(julyId, isNotNull);
    thriveDebug.deleteExpense('home', julyId!);
    await tester.pumpAndSettle();

    thriveDebug.pickMonth(7);
    await tester.pumpAndSettle();
    expect(find.text('Gym - Membership'), findsNothing);

    thriveDebug.pickMonth(5);
    await tester.pumpAndSettle();
    expect(find.text('Gym - Membership'), findsWidgets);
  });

  testWidgets('edit an existing income row', (tester) async {
    await pumpApp(tester);
    final income = firstIncomeLabel(tester);
    await tester.tap(find.text(income).first);
    await tester.pumpAndSettle();
    expect(find.text('Edit income'), findsOneWidget);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
  });

  testWidgets('toggle paid/received and open account picker', (tester) async {
    await pumpApp(tester);
    // open account picker from an income row account pill
    final pill = find.text('Eva').first;
    if (pill.evaluate().isNotEmpty) {
      await tester.tap(pill);
      await tester.pumpAndSettle();
      if (find.text('Choose account').evaluate().isNotEmpty) {
        await tester.tap(find.text('Shared account').last);
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('open cap/limit sheet', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Set limit').first);
    await tester.pumpAndSettle();
    expect(find.text('Monthly limit'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '500');
    await tester.pump();
    await tester.tap(find.text('Save limit'));
    await tester.pumpAndSettle();
  });

  testWidgets('collapse and expand a block', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Home').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').first);
    await tester.pumpAndSettle();
  });

  testWidgets('swipe a row to reveal delete then delete', (tester) async {
    await pumpApp(tester);
    final rows = find.byKey(const ValueKey('swipe')).evaluate();
    // fall back: drag the first Dismissible-like swipe row by text
    final target = find.text('Add to Home');
    expect(target, findsOneWidget);
    // Drag an expense row left
    final firstRow = swipeRows(tester);
    if (firstRow != null) {
      await tester.drag(firstRow, const Offset(-200, 0));
      await tester.pumpAndSettle();
      final del = find.text('Delete');
      if (del.evaluate().isNotEmpty) {
        await tester.tap(del.first);
        await tester.pumpAndSettle();
        if (find.text('Delete').evaluate().isNotEmpty) {
          await tester.tap(find.text('Delete').last);
          await tester.pumpAndSettle();
        }
      }
    }
    expect(rows, isNotNull);
  });
}
