import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> goToCalendar(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-calendar')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Calendar month view shows the empty state with no events', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);
    expect(find.text('No events'), findsOneWidget);
    expect(find.text('Nothing planned for this day.'), findsOneWidget);
  });

  testWidgets('add an event via the FAB and see it in month view', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    expect(find.text('New event'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Dentist');
    await tester.pump();
    await tester.tap(find.text('Add event').last);
    await tester.pumpAndSettle();

    expect(find.text('Dentist'), findsOneWidget);
    expect(find.text('No events'), findsNothing);
  });

  testWidgets('All-day toggle hides the start/end time fields', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);

    await tester.tap(find.text('All-day'));
    await tester.pumpAndSettle();
    expect(find.text('09:00'), findsNothing);
    expect(find.text('10:00'), findsNothing);
  });

  testWidgets('view, edit and delete a one-off event', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Team lunch');
    await tester.pump();
    await tester.tap(find.text('Add event').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Team lunch'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Team lunch'), findsNothing);
    expect(find.text('No events'), findsOneWidget);
  });

  testWidgets(
    'creating a category from the event editor lands on Calendars & '
    'categories with it listed',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('event-new-category')));
      await tester.pumpAndSettle();
      expect(find.text('New category'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, 'Work');
      await tester.pump();
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();

      // Saving routes to "Calendars & categories" with the new category
      // listed (matches the design's `saveCategory()`).
      expect(find.text('Calendars & categories'), findsWidgets);
      expect(find.text('Work'), findsWidgets);
    },
  );

  testWidgets('assigning a category to a new event selects its chip', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    // Create the category via the management sheet first.
    await tester.tap(find.byKey(const ValueKey('cal-manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Family');
    await tester.pump();
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    expect(find.text('Family'), findsWidgets);

    // Dismiss the management sheet (tap the barrier above it), then create
    // an event and pick the new category.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Dinner');
    await tester.pump();
    await tester.tap(find.text('Family').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add event').last);
    await tester.pumpAndSettle();

    expect(find.text('Dinner'), findsOneWidget);
  });

  testWidgets(
    'a weekly recurring event: delete "this event only" keeps the series',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Standup');
      await tester.pump();
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add event').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Standup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this event only'), findsOneWidget);
      expect(find.text('Delete all events'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('recur-delete-one')));
      await tester.pumpAndSettle();

      // Jump to next week — the series continues there.
      await tester.tap(find.byKey(const ValueKey('nav-lists')));
      await tester.pumpAndSettle();
      await goToCalendar(tester);
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Standup'), findsWidgets);
    },
  );

  testWidgets('import a calendar shows its read-only sample events', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('cal-manage')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing imported yet.'), findsOneWidget);

    await tester.tap(find.text('Import a calendar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Erik · Work');
    await tester.pump();
    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Erik · Work'), findsWidgets);

    // Dismiss the management sheet (tap the barrier above it) to reach the
    // calendar sub-header underneath.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Imported event'), findsWidgets);
  });
}
