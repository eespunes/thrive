import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

Future<void> _openChooser(WidgetTester tester) async {
  thriveDebug.openQuickAdd();
  await tester.pumpAndSettle();
  expect(find.text('What would you like to add?'), findsOneWidget);
}

Future<void> _createList(
  WidgetTester tester,
  String name, {
  bool shopping = false,
}) async {
  await tester.tap(find.byKey(const ValueKey('nav-lists')));
  await tester.pumpAndSettle();
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

void main() {
  testWidgets('quick-add chooser -> Event opens the event editor', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await _openChooser(tester);
    expect(find.byKey(const ValueKey('quickadd-event')), findsOneWidget);
    expect(find.byKey(const ValueKey('quickadd-task')), findsOneWidget);
    expect(find.byKey(const ValueKey('quickadd-shopping')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quickadd-event')));
    await tester.pumpAndSettle();
    expect(find.text('What would you like to add?'), findsNothing);
    expect(find.text('New event'), findsOneWidget);
  });

  testWidgets('quick-add Task with no lists prompts to create a to-do list', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await _openChooser(tester);
    await tester.tap(find.byKey(const ValueKey('quickadd-task')));
    await tester.pumpAndSettle();
    // Landed on the Lists tab with the pin-a-note sheet open.
    expect(thriveDebug.tab, 'lists');
    expect(find.text('Pin it to the door'), findsOneWidget);
  });

  testWidgets('quick-add Task with one list opens its task sheet directly', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await _createList(tester, 'Household');
    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();

    await _openChooser(tester);
    await tester.tap(find.byKey(const ValueKey('quickadd-task')));
    await tester.pumpAndSettle();
    expect(thriveDebug.tab, 'lists');
    // The task editor sheet is open on the single list.
    expect(find.text('Add task'), findsWidgets);
  });

  testWidgets('quick-add Task with two lists shows the list picker', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await _createList(tester, 'Household');
    await _createList(tester, 'Errands');
    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();

    await _openChooser(tester);
    await tester.tap(find.byKey(const ValueKey('quickadd-task')));
    await tester.pumpAndSettle();
    expect(find.text('Add a task'), findsOneWidget);
    expect(find.text('Which list should it go on?'), findsOneWidget);

    final secondId = thriveDebug.taskLists
        .firstWhere((l) => l.name == 'Errands')
        .id;
    await tester.tap(find.byKey(ValueKey('pick-list-$secondId')));
    await tester.pumpAndSettle();
    expect(thriveDebug.tab, 'lists');
    expect(find.text('Add task'), findsWidgets);
  });

  testWidgets(
    'quick-add Shopping item with no lists prompts to create a shopping list',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await _openChooser(tester);
      await tester.tap(find.byKey(const ValueKey('quickadd-shopping')));
      await tester.pumpAndSettle();
      expect(thriveDebug.tab, 'lists');
      expect(find.text('Pin it to the door'), findsOneWidget);
    },
  );

  testWidgets(
    'quick-add Shopping item with one list lands on its detail screen',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await _createList(tester, 'Supermarket', shopping: true);
      await tester.tap(find.byKey(const ValueKey('nav-home')));
      await tester.pumpAndSettle();

      await _openChooser(tester);
      await tester.tap(find.byKey(const ValueKey('quickadd-shopping')));
      await tester.pumpAndSettle();
      expect(thriveDebug.tab, 'lists');
      // The wall shows the note, ready for its in-place add-line.
      expect(find.text('Supermarket'), findsOneWidget);
    },
  );

  testWidgets('quick-add Shopping item with two lists shows the list picker', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await _createList(tester, 'Supermarket', shopping: true);
    await _createList(tester, 'Pharmacy', shopping: true);
    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();

    await _openChooser(tester);
    await tester.tap(find.byKey(const ValueKey('quickadd-shopping')));
    await tester.pumpAndSettle();
    expect(find.text('Add a shopping item'), findsOneWidget);

    final id = thriveDebug.shoppingLists
        .firstWhere((l) => l.name == 'Pharmacy')
        .id;
    await tester.tap(find.byKey(ValueKey('pick-list-$id')));
    await tester.pumpAndSettle();
    expect(thriveDebug.tab, 'lists');
    expect(find.text('Pharmacy'), findsOneWidget);
  });
}
