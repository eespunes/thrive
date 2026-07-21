import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> goToLists(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-lists')));
  await tester.pumpAndSettle();
}

/// Finds the single checkbox `GestureDetector` whose `ValueKey` starts with
/// [prefix] (e.g. `task-check-` / `shop-check-`) — item ids are generated at
/// runtime, so tests can't reference them directly.
Finder findCheckbox(String prefix) {
  return find.byWidgetPredicate(
    (w) =>
        w is GestureDetector &&
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith(prefix),
  );
}

void main() {
  testWidgets('Lists hub shows the empty state with no lists', (tester) async {
    await pumpApp(tester);
    await goToLists(tester);
    expect(find.text('No lists yet'), findsOneWidget);
  });

  testWidgets('create a to-do list, add a task, toggle it done', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToLists(tester);

    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    expect(find.text('New list'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'Household');
    await tester.pump();
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();

    expect(find.text('Household'), findsOneWidget);
    expect(find.text('TO-DO'), findsOneWidget);

    await tester.tap(find.text('Household'));
    await tester.pumpAndSettle();
    expect(find.text('No open tasks — all done here.'), findsOneWidget);

    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Take out the bins');
    await tester.pump();
    await tester.tap(find.text('Add task').last);
    await tester.pumpAndSettle();

    expect(find.text('Take out the bins'), findsOneWidget);

    // Check it off -> moves under "Completed".
    await tester.tap(findCheckbox('task-check-'));
    await tester.pumpAndSettle();
    expect(find.textContaining('COMPLETED'), findsOneWidget);
  });

  testWidgets(
    'create a shopping list, quick-add an item, check it off, clear bought',
    (tester) async {
      await pumpApp(tester);
      await goToLists(tester);

      await tester.tap(find.text('New list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shopping'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Supermarket');
      await tester.pump();
      await tester.tap(find.text('Create list'));
      await tester.pumpAndSettle();

      expect(find.text('Supermarket'), findsOneWidget);
      expect(find.text('SHOPPING'), findsOneWidget);

      await tester.tap(find.text('Supermarket'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing to buy. Add an item above.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Milk');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);

      // Check it off -> moves under "Bought".
      await tester.tap(findCheckbox('shop-check-'));
      await tester.pumpAndSettle();
      expect(find.textContaining('BOUGHT'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsNothing);
      expect(find.text('Nothing to buy. Add an item above.'), findsOneWidget);
    },
  );

  testWidgets('delete a list via swipe + confirm', (tester) async {
    await pumpApp(tester);
    await goToLists(tester);

    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Chores');
    await tester.pump();
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();
    expect(find.text('Chores'), findsOneWidget);

    await tester.drag(find.text('Chores'), const Offset(-220, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Chores'), findsNothing);
    expect(find.text('No lists yet'), findsOneWidget);
  });

  testWidgets(
    'Assigned to me filter hides lists with no tasks assigned to me',
    (tester) async {
      await pumpApp(tester);
      await goToLists(tester);

      await tester.tap(find.text('New list'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Household');
      await tester.pump();
      await tester.tap(find.text('Create list'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('lists-filter-me')));
      await tester.pumpAndSettle();
      expect(find.text('Nothing assigned to you yet.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('lists-filter-all')));
      await tester.pumpAndSettle();
      expect(find.text('Household'), findsOneWidget);
    },
  );
}
