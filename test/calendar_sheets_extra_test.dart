import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

Future<void> _goToCalendar(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-calendar')));
  await tester.pumpAndSettle();
}

Future<void> _openEditor(WidgetTester tester) async {
  await _goToCalendar(tester);
  await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
  await tester.pumpAndSettle();
  expect(find.text('New event'), findsOneWidget);
}

Future<void> _pickEmoji(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('glyph-pick-emoji')));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Tab).at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('😀').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('event editor small controls: kind, location, attendees, '
      'reminder, repeat chips and custom weekdays', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await _openEditor(tester);

    // Kind toggle To-Do -> Event.
    await tester.tap(find.byKey(const ValueKey('event-kind-todo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-kind-event')));
    await tester.pumpAndSettle();

    // Location field.
    await tester.enterText(find.byType(TextField).at(1), 'Park');
    await tester.pump();

    // Attendee chip toggles off and on.
    await tester.tap(find.byKey(const ValueKey('event-att-me')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('event-att-me')));
    await tester.pump();

    // Reminder chip.
    await tester.ensureVisible(find.text('1 day before'));
    await tester.tap(find.text('1 day before'));
    await tester.pump();

    // Repeat: Weekly (repeat-ends appears), then Monthly, then None.
    await tester.ensureVisible(find.text('Weekly'));
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-repeat-end-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();

    // Custom repeat weekday chips add + remove.
    await tester.ensureVisible(find.text('Custom'));
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-custom-weekday-3')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('event-custom-weekday-3')));
    await tester.pump();
  });

  testWidgets('deleting from the editor: plain events confirm, recurring '
      'events offer the recurrence sheet', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);

    // Plain event.
    await _openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Temp event');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    final plain = thriveDebug.events.singleWhere(
      (e) => e.title == 'Temp event',
    );

    await tester.tap(find.text('Temp event').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('event-${plain.id}-${plain.date}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete event'));
    await tester.tap(find.text('Delete event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(thriveDebug.events.where((e) => e.id == plain.id), isEmpty);

    // Recurring event → recurrence delete sheet.
    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Weekly thing');
    await tester.pump();
    await tester.ensureVisible(find.text('Weekly'));
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    final rec = thriveDebug.events.singleWhere(
      (e) => e.title == 'Weekly thing',
    );
    await tester.tap(find.text('Weekly thing').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('event-${rec.id}-${rec.date}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete event'));
    await tester.tap(find.text('Delete event'));
    await tester.pumpAndSettle();
    // The recurrence-aware delete sheet offers scoped options.
    expect(find.text('Delete recurring event'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recur-delete-all')));
    await tester.pumpAndSettle();
    if (find.text('Delete').evaluate().isNotEmpty) {
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
    }
    expect(thriveDebug.events.where((e) => e.title == 'Weekly thing'), isEmpty);
  });

  testWidgets('multi-day event view shows the date span', (tester) async {
    final today = DateTime.now();
    await pumpApp(tester, landOnDefaultTab: true);
    await _openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Trip');
    await tester.pump();
    await tester.tap(find.text('Multi-day'));
    await tester.pumpAndSettle();
    if (today.day < 28) {
      // Pick tomorrow as the end date so the span is real.
      final endField = find.text(
        '${today.day.toString().padLeft(2, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-${today.year}',
      );
      await tester.tap(endField.last);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.text('${today.day + 1}'),
            )
            .last,
      );
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    final trip = thriveDebug.events.singleWhere((e) => e.title == 'Trip');
    await tester.tap(find.text('Trip').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('event-${trip.id}-${trip.date}')));
    await tester.pumpAndSettle();
    if (today.day < 28) {
      expect(find.textContaining('–'), findsWidgets);
    }
  });

  testWidgets('category management: member chips, emoji, edit and delete', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('more-calmanage')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Work');
    await tester.pump();
    await _pickEmoji(tester);
    // Assign a member, un-assign, re-assign.
    await tester.tap(find.byKey(const ValueKey('cat-member-me')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cat-member-me')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cat-member-me')));
    await tester.pump();
    await tester.ensureVisible(find.text('Add category'));
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsWidgets);
    expect(find.text('1 member'), findsOneWidget);

    // Swipe the category row open and delete it.
    final cat = thriveDebug.eventCategories.single;
    await tester.drag(
      find.byKey(ValueKey('cat-${cat.id}')),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(thriveDebug.eventCategories, isEmpty);
  });

  testWidgets('layer management: add with colour + emoji, edit and delete', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('more-callayers')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ Add layer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Sports');
    await tester.pump();
    await _pickEmoji(tester);
    await tester.ensureVisible(find.text('Add layer'));
    await tester.tap(find.text('Add layer'));
    await tester.pumpAndSettle();

    final layer = thriveDebug.calendarLayers.firstWhere(
      (l) => l.label == 'Sports',
    );

    // Edit the custom layer, change its emoji, then delete it.
    await tester.tap(find.byKey(ValueKey('cal-manage-layer-edit-${layer.id}')));
    await tester.pumpAndSettle();
    await _pickEmoji(tester);
    await tester.ensureVisible(
      find.byKey(ValueKey('cal-manage-layer-delete-${layer.id}')),
    );
    await tester.tap(
      find.byKey(ValueKey('cal-manage-layer-delete-${layer.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(thriveDebug.calendarLayers.where((l) => l.id == layer.id), isEmpty);
  });

  testWidgets('calendar month picker year arrows change the year', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await _goToCalendar(tester);
    await tester.tap(find.byKey(const ValueKey('cal-month-title')));
    await tester.pumpAndSettle();

    final year = DateTime.now().year;
    expect(find.text('$year'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('cal-year-cleft')));
    await tester.pumpAndSettle();
    expect(find.text('${year - 1}'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('cal-year-cright')));
    await tester.pumpAndSettle();
    expect(find.text('$year'), findsWidgets);
  });
}
