import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

Future<void> goToLists(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-lists')));
  await tester.pumpAndSettle();
}

/// Pins a note through the sheet (empty-state button or the dashed
/// "＋ pin a new note" at the wall's end).
Future<void> pinNote(
  WidgetTester tester,
  String name, {
  bool shopping = false,
}) async {
  await tester.tap(find.textContaining(RegExp('[Pp]in a new note')).first);
  await tester.pumpAndSettle();
  if (shopping) {
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byType(TextField).last, name);
  await tester.pump();
  await tester.tap(find.text('Pin it to the door'));
  await tester.pumpAndSettle();
  expect(find.text(name), findsOneWidget);
}

/// Writes a line straight onto the only visible note's add-line input.
Future<void> addLine(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Finds the single `GestureDetector` whose `ValueKey` starts with [prefix]
/// (e.g. `task-check-`) — item ids are generated at runtime.
Finder byKeyPrefix(String prefix) {
  return find.byWidgetPredicate(
    (w) =>
        w is GestureDetector &&
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith(prefix),
  );
}

void main() {
  testWidgets('the wall shows the empty state with no notes', (tester) async {
    await pumpApp(tester);
    await goToLists(tester);
    expect(find.text('Nothing on the door yet'), findsOneWidget);
  });

  testWidgets('pin a to-do note, write a line on it, tick it done', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToLists(tester);
    await pinNote(tester, 'Household');

    await addLine(tester, 'Take out the bins');
    expect(find.text('Take out the bins'), findsOneWidget);

    final task = thriveDebug.taskLists.first.tasks.single;
    expect(task.assignee, isNull);
    expect(task.due, isNotNull); // defaults to "This week"
    expect(find.text('1 left'), findsOneWidget);

    // Ticking an unassigned line claims it for the ticker (#303/#316).
    await tester.tap(byKeyPrefix('task-check-'));
    await tester.pumpAndSettle();
    expect(task.done, isTrue);
    expect(task.assignee, isNotNull);
    expect(find.text('done!'), findsOneWidget);
  });

  testWidgets('edit a note via ✎ (rename + re-paper), then unpin it', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToLists(tester);
    await pinNote(tester, 'Chores');
    await addLine(tester, 'Vacuum');

    await tester.tap(byKeyPrefix('note-edit-'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Weekend chores');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('note-paper-2')));
    await tester.pump();
    await tester.tap(find.text('Save the note'));
    await tester.pumpAndSettle();
    expect(find.text('Weekend chores'), findsOneWidget);

    // Unpin: visible in the sheet, confirm counts what goes with it.
    await tester.tap(byKeyPrefix('note-edit-'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-unpin')));
    await tester.pumpAndSettle();
    expect(find.textContaining('takes its 1 line with it'), findsOneWidget);
    await tester.tap(find.text('Unpin').last);
    await tester.pumpAndSettle();
    expect(find.text('Weekend chores'), findsNothing);
    expect(find.text('Nothing on the door yet'), findsOneWidget);
  });

  testWidgets(
    'grocery add-line parses quantities and bumps duplicates (#304)',
    (tester) async {
      await pumpApp(tester);
      await goToLists(tester);
      await pinNote(tester, 'Supermarket', shopping: true);

      await addLine(tester, '5x milk');
      final item = thriveDebug.shoppingLists.first.items.single;
      expect(item.name, 'Milk');
      expect(item.qty, 5);

      // Same name (case-insensitive) bumps the count, no duplicate line.
      await addLine(tester, 'milk x2');
      expect(thriveDebug.shoppingLists.first.items.length, 1);
      expect(item.qty, 7);

      await addLine(tester, '3 eggs');
      expect(thriveDebug.shoppingLists.first.items.first.name, 'Eggs');
      expect(thriveDebug.shoppingLists.first.items.first.qty, 3);
    },
  );

  testWidgets('grocery stepper: ±, cap behaviour, − at ×1 removes with Undo', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToLists(tester);
    await pinNote(tester, 'Supermarket', shopping: true);
    await addLine(tester, 'Eggs');

    expect(find.text('×1'), findsOneWidget);
    await tester.tap(byKeyPrefix('shop-plus-'));
    await tester.pumpAndSettle();
    expect(find.text('×2'), findsOneWidget);

    await tester.tap(byKeyPrefix('shop-minus-'));
    await tester.pumpAndSettle();
    expect(find.text('×1'), findsOneWidget);

    // − at ×1 crosses the line off — no confirm, but a 4s Undo (#319).
    await tester.tap(byKeyPrefix('shop-minus-'));
    await tester.pumpAndSettle();
    expect(find.text('Eggs'), findsNothing);
    expect(find.textContaining('crossed off'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toast-undo')));
    await tester.pumpAndSettle();
    expect(find.text('Eggs'), findsOneWidget);
    expect(thriveDebug.shoppingLists.first.items.single.qty, 1);
  });

  testWidgets('checked grocery lines keep a static ×N and sink', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToLists(tester);
    await pinNote(tester, 'Supermarket', shopping: true);
    await addLine(tester, '4x butter');

    await tester.tap(byKeyPrefix('shop-check-'));
    await tester.pumpAndSettle();
    expect(thriveDebug.shoppingLists.first.items.single.checked, isTrue);
    // Quantity survives the check; stepper is gone, static ×4 remains.
    expect(find.text('×4'), findsOneWidget);
    expect(byKeyPrefix('shop-plus-'), findsNothing);
  });

  testWidgets(
    'line edit sheet: rename, due chip, assignee chip, cross off + Undo',
    (tester) async {
      await pumpApp(tester);
      await goToLists(tester);
      await pinNote(tester, 'Household');
      await addLine(tester, 'First');
      await addLine(tester, 'Second');
      await addLine(tester, 'Third');

      // Tap the middle line's TEXT to edit it (#315).
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Second (renamed)');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('line-due-Today')));
      await tester.pump();
      await tester.tap(find.text('Eva Janssen'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final t = thriveDebug.taskLists.first.tasks[1];
      expect(t.title, 'Second (renamed)');
      expect(t.due, todayIso());
      expect(t.assignee, isNotNull);
      expect(find.text('TODAY'), findsOneWidget);

      // Cross it off: no confirm; Undo restores it at position 1 (#315).
      await tester.tap(find.text('Second (renamed)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('line-crossoff')));
      await tester.pumpAndSettle();
      expect(find.text('Second (renamed)'), findsNothing);
      expect(thriveDebug.taskLists.first.tasks.length, 2);

      await tester.tap(find.byKey(const ValueKey('toast-undo')));
      await tester.pumpAndSettle();
      final restored = thriveDebug.taskLists.first.tasks[1];
      expect(restored.title, 'Second (renamed)');
      expect(restored.due, todayIso());
      expect(restored.assignee, isNotNull);
    },
  );

  testWidgets('grocery edit sheet has no due/assignee and can cross off', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToLists(tester);
    await pinNote(tester, 'Supermarket', shopping: true);
    await addLine(tester, 'Bread');

    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();
    expect(find.text('Edit item'), findsOneWidget);
    expect(find.text('Due'), findsNothing);
    expect(find.text('Who’s on it'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('line-crossoff')));
    await tester.pumpAndSettle();
    expect(find.text('Bread'), findsNothing);
    expect(find.textContaining('crossed off'), findsOneWidget);
  });

  testWidgets('assign via the avatar: "Who\'s on it?" sheet and hand-back', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToLists(tester);
    await pinNote(tester, 'Household');
    await addLine(tester, 'Take out bins');

    await tester.tap(byKeyPrefix('task-assign-'));
    await tester.pumpAndSettle();
    expect(find.text('Who’s on it?'), findsOneWidget);
    expect(find.text('0 open'), findsWidgets); // fair-share loads
    expect(find.text('Anyone — first to grab it'), findsOneWidget);

    await tester.tap(find.text('Eva Janssen'));
    await tester.pumpAndSettle();
    expect(thriveDebug.taskLists.first.tasks.single.assignee, isNotNull);

    // Load now reflects the open assigned task; hand it back to Anyone.
    await tester.tap(byKeyPrefix('task-assign-'));
    await tester.pumpAndSettle();
    expect(find.text('1 open'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('assign-anyone')));
    await tester.pumpAndSettle();
    expect(thriveDebug.taskLists.first.tasks.single.assignee, isNull);
  });

  testWidgets(
    'Just me keeps unassigned lines visible and hides shopping notes (#307)',
    (tester) async {
      await pumpApp(tester);
      await goToLists(tester);
      await pinNote(tester, 'Household');
      await addLine(tester, 'Up for grabs');
      await pinNote(tester, 'Supermarket', shopping: true);

      await tester.tap(find.byKey(const ValueKey('lists-filter-me')));
      await tester.pumpAndSettle();
      // Unassigned tasks stay everyone's until claimed.
      expect(find.text('Up for grabs'), findsOneWidget);
      expect(find.text('Supermarket'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('lists-filter-all')));
      await tester.pumpAndSettle();
      expect(find.text('Supermarket'), findsOneWidget);
    },
  );

  testWidgets('sort chips reorder open lines; done lines always sink (#317)', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToLists(tester);
    await pinNote(tester, 'Household');
    await addLine(tester, 'Someday thing');
    await addLine(tester, 'Today thing');

    // Give the lines distinct dues via the edit sheet.
    await tester.tap(find.text('Someday thing'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('line-due-Someday')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today thing'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('line-due-Today')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    Offset yOf(String t) => tester.getTopLeft(find.text(t));
    // List order: authoring order.
    expect(yOf('Someday thing').dy, lessThan(yOf('Today thing').dy));

    await tester.tap(find.byKey(const ValueKey('lists-sort-due')));
    await tester.pumpAndSettle();
    expect(yOf('Today thing').dy, lessThan(yOf('Someday thing').dy));

    // Done lines sink regardless of due.
    await tester.tap(byKeyPrefix('task-check-').first);
    await tester.pumpAndSettle();
    expect(yOf('Someday thing').dy, lessThan(yOf('Today thing').dy));
  });

  testWidgets('By person groups by assignee with unassigned last (#317)', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToLists(tester);
    await pinNote(tester, 'Household');
    await addLine(tester, 'Nobody yet');
    await addLine(tester, 'Eva task');

    // Assign the second line to Eva via its avatar.
    await tester.tap(byKeyPrefix('task-assign-').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eva Janssen'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('lists-sort-who')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Eva task')).dy,
      lessThan(tester.getTopLeft(find.text('Nobody yet')).dy),
    );
  });

  testWidgets('a note folds to its header and remembers the open count', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToLists(tester);
    await pinNote(tester, 'Household');
    await addLine(tester, 'Hidden when folded');

    await tester.tap(byKeyPrefix('note-fold-'));
    await tester.pumpAndSettle();
    expect(find.text('Hidden when folded'), findsNothing);
    expect(find.text('Household'), findsOneWidget);
    expect(find.text('1 left'), findsOneWidget);

    await tester.tap(byKeyPrefix('note-fold-'));
    await tester.pumpAndSettle();
    expect(find.text('Hidden when folded'), findsOneWidget);
  });

  testWidgets('the live subtitle counts notes and open things', (tester) async {
    await pumpApp(tester);
    await goToLists(tester);
    await pinNote(tester, 'Household');
    await addLine(tester, 'One');
    await addLine(tester, 'Two');
    await pinNote(tester, 'Supermarket', shopping: true);
    final shopId = thriveDebug.shoppingLists.first.id;
    await tester.enterText(
      find.descendant(
        of: find.byKey(ValueKey('note-add-$shopId')),
        matching: find.byType(TextField),
      ),
      'Milk',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('2 notes · 3 things to do'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('lists-filter-me')));
    await tester.pumpAndSettle();
    // Recounts under the filter: shopping excluded, unassigned kept.
    expect(find.text('1 note · 2 things to do'), findsOneWidget);
  });
}
