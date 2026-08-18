import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

/// Whether the chip/toggle `GestureDetector` at [key] renders "active"
/// (its descendant `Container`'s border uses [B.primary]).
bool chipActive(WidgetTester tester, Key key) {
  final container = tester.widget<Container>(
    find
        .descendant(of: find.byKey(key), matching: find.byType(Container))
        .first,
  );
  final deco = container.decoration! as BoxDecoration;
  final border = deco.border;
  if (border is Border) return border.top.color == B.primary;
  return false;
}

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

  testWidgets(
    'create a weekly recurring task with specific weekdays persists',
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
      await tester.enterText(find.byType(TextField).first, 'Water plants');
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const ValueKey('task-recur-weekly')),
      );
      await tester.tap(find.byKey(const ValueKey('task-recur-weekly')));
      await tester.pumpAndSettle();
      // Switching to weekly defaults the weekday picker to today's weekday.
      // Toggle on whichever of Mon (1) / Wed (3) isn't already selected,
      // then toggle off today's default if it's neither of those two —
      // weekday chips are pure toggles, so the exact sequence depends on
      // today's date.
      final defaultWeekday = DateTime.now().weekday;
      for (final day in const [1, 3]) {
        if (day != defaultWeekday) {
          final f = find.byKey(ValueKey('task-recur-weekday-$day'));
          await tester.ensureVisible(f);
          await tester.tap(f);
          await tester.pumpAndSettle();
        }
      }
      if (defaultWeekday != 1 && defaultWeekday != 3) {
        final f = find.byKey(ValueKey('task-recur-weekday-$defaultWeekday'));
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tester.ensureVisible(find.text('Add task').last);
      await tester.tap(find.text('Add task').last);
      await tester.pumpAndSettle();

      expect(find.text('Water plants'), findsOneWidget);

      // Reopen the task and confirm recur/recurWeekdays round-tripped.
      await tester.tap(find.text('Water plants'));
      await tester.pumpAndSettle();
      expect(chipActive(tester, const ValueKey('task-recur-weekly')), isTrue);
      expect(
        chipActive(tester, const ValueKey('task-recur-weekday-1')),
        isTrue,
      );
      expect(
        chipActive(tester, const ValueKey('task-recur-weekday-3')),
        isTrue,
      );
      expect(
        chipActive(tester, const ValueKey('task-recur-weekday-2')),
        isFalse,
      );
    },
  );

  testWidgets(
    'editing a recurring task updates its recurEvery/recurWeekdays without '
    'affecting other tasks',
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

      // Task A: will become the recurring task we edit.
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Take out bins');
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('task-recur-custom')),
      );
      await tester.tap(find.byKey(const ValueKey('task-recur-custom')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add task').last);
      await tester.tap(find.text('Add task').last);
      await tester.pumpAndSettle();

      // Task B: a plain, non-recurring task that must stay untouched.
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Vacuum');
      await tester.pump();
      await tester.tap(find.text('Add task').last);
      await tester.pumpAndSettle();

      // Re-open task A and bump "every" to 3, add Friday (5).
      await tester.tap(find.text('Take out bins'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('task-recur-every-3')),
      );
      await tester.tap(find.byKey(const ValueKey('task-recur-every-3')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('task-recur-weekday-5')),
      );
      await tester.tap(find.byKey(const ValueKey('task-recur-weekday-5')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save task'));
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();

      // Task A: reopen and confirm the new every/weekday values stuck.
      await tester.tap(find.text('Take out bins'));
      await tester.pumpAndSettle();
      expect(chipActive(tester, const ValueKey('task-recur-custom')), isTrue);
      expect(chipActive(tester, const ValueKey('task-recur-every-3')), isTrue);
      expect(
        chipActive(tester, const ValueKey('task-recur-weekday-5')),
        isTrue,
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Task B stayed non-recurring throughout.
      await tester.tap(find.text('Vacuum'));
      await tester.pumpAndSettle();
      expect(chipActive(tester, const ValueKey('task-recur-none')), isTrue);
    },
  );

  testWidgets('creating a content-kind list defaults to pink + camera marker', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToLists(tester);

    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'YouTube');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('new-list-kind-content')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();

    expect(find.text('YouTube'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tasklist-content-badge')),
      findsOneWidget,
    );
    expect(find.textContaining('📷'), findsWidgets);

    await tester.tap(find.text('YouTube'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tasklist-detail-content-marker')),
      findsOneWidget,
    );
  });
}
