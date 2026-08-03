import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The glyph picker's emoji field opens the in-app emoji picker from its `+`
/// tile. The Recents tab starts empty, so we hop to Smileys (tab 1) and tap
/// its first emoji (😀), mirroring `family_emoji_features_test.dart`.
Future<String> _pickEmoji(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('glyph-pick-emoji')));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Tab).at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('😀').first);
  await tester.pumpAndSettle();
  return '😀';
}

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

  testWidgets('create a list with a chosen emoji shows it on the card', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToLists(tester);

    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Chores');
    await tester.pump();
    final emoji = await _pickEmoji(tester);
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();

    expect(find.text('Chores'), findsOneWidget);
    expect(find.text(emoji), findsOneWidget);
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

  testWidgets(
    'assign a task to a member and pick its due date via the native picker',
    (tester) async {
      await pumpApp(tester);
      await goToLists(tester);

      await tester.tap(find.text('New list'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Household');
      await tester.pump();
      await tester.tap(find.text('Create list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Household'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Take out bins');
      await tester.pump();

      // Assign to the signed-in member (the only one seeded by default).
      await tester.tap(find.text('Eva Janssen'));
      await tester.pump();

      // Open the native date picker instead of relying on the toggle's
      // "defaults to today" shortcut.
      await tester.tap(find.text('Due date'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final todayIsoText =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      await tester.tap(find.text(todayIsoText));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add task').last);
      await tester.pumpAndSettle();
      expect(find.text('Take out bins'), findsOneWidget);
    },
  );

  testWidgets(
    'add a task with a due date, edit it, un-complete it, then delete it',
    (tester) async {
      await pumpApp(tester);
      await goToLists(tester);

      await tester.tap(find.text('New list'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Household');
      await tester.pump();
      await tester.tap(find.text('Create list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Household'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Take out bins');
      await tester.pump();
      // The "Due date" toggle defaults to today — no need to open the
      // native date picker to have a valid due date set.
      await tester.tap(find.text('Due date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add task').last);
      await tester.pumpAndSettle();
      expect(find.text('Take out bins'), findsOneWidget);

      // Edit: reopen the sheet and change the title (saveTask's editing
      // branch, task still has a due date -> reschedule).
      await tester.tap(find.text('Take out bins'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Take out trash');
      await tester.pump();
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();
      expect(find.text('Take out trash'), findsOneWidget);

      // Toggle done (cancels reminder), then toggle again (reschedules,
      // since it still has a due date).
      await tester.tap(findCheckbox('task-check-'));
      await tester.pumpAndSettle();
      expect(find.textContaining('COMPLETED'), findsOneWidget);
      await tester.tap(findCheckbox('task-check-'));
      await tester.pumpAndSettle();
      expect(find.textContaining('COMPLETED'), findsNothing);

      // Delete the task itself (cancels its reminder).
      await tester.drag(find.text('Take out trash'), const Offset(-220, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').first, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Take out trash'), findsNothing);
    },
  );

  testWidgets('deleting a list with tasks cancels their reminders', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToLists(tester);

    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Chores');
    await tester.pump();
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chores'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Vacuum');
    await tester.pump();
    await tester.tap(find.text('Add task').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('back-row')));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Chores'), const Offset(-220, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Chores'), findsNothing);
  });

  testWidgets('adjust shopping item quantity and delete it', (tester) async {
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
    await tester.tap(find.text('Supermarket'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Eggs');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('−'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await tester.drag(find.text('Eggs'), const Offset(-220, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Eggs'), findsNothing);
  });

  testWidgets('delete a shopping list via swipe + confirm', (tester) async {
    await pumpApp(tester);
    await goToLists(tester);

    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Pharmacy');
    await tester.pump();
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();
    expect(find.text('Pharmacy'), findsOneWidget);

    await tester.drag(find.text('Pharmacy'), const Offset(-220, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Pharmacy'), findsNothing);
    expect(find.text('No lists yet'), findsOneWidget);
  });
}
