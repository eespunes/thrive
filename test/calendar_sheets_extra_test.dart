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

Future<void> _openTray(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key), warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _repeatYes(WidgetTester tester) async {
  await _openTray(tester, const ValueKey('ticket-badge-repeat'));
  await tester.tap(find.byKey(const ValueKey('ticket-again-yes')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('event editor small controls: kind, location, attendees, '
      'reminder and the repeat tray', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await _openEditor(tester);

    // Kind toggle To-Do -> Event (initial tray is Kind & layer).
    await tester.tap(find.byKey(const ValueKey('event-kind-todo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-kind-event')));
    await tester.pumpAndSettle();

    // Location field lives in the Place & notes tray.
    await _openTray(tester, const ValueKey('ticket-place'));
    await tester.enterText(find.byType(TextField).at(1), 'Park');
    await tester.pump();

    // Attendee chip toggles off and on (People tray).
    await _openTray(tester, const ValueKey('ticket-people'));
    await tester.tap(find.byKey(const ValueKey('event-att-me')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('event-att-me')));
    await tester.pump();

    // Reminder: two-question tray, then an offset chip.
    await _openTray(tester, const ValueKey('ticket-badge-reminder'));
    await tester.tap(find.text('1 day'));
    await tester.pump();

    // Repeat: yes -> weekly with interval + weekday chips; repeat ends;
    // monthly; then back to "No, just once".
    await _repeatYes(tester);
    await tester.tap(find.byKey(const ValueKey('event-repeat-end-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-custom-weekday-3')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('event-custom-weekday-3')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ticket-cad-monthly')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ticket-again-no')));
    await tester.pumpAndSettle();
    expect(find.text('Happens once'), findsOneWidget);
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
    await _repeatYes(tester);
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
    await _openTray(tester, const ValueKey('ticket-when'));
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
    await tapHubRow(tester, 'planning', 'more-calmanage');

    // Add-then-open (#325): typing a name creates the category with
    // defaults and lands straight in its full-screen studio.
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'Work',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    expect(find.text('Edit category'), findsOneWidget);

    // Free emoji input on the badge stage (no fixed grid).
    await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-link')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('badge-stage-emoji-input')),
      '😀',
    );
    await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-use')));
    await tester.pumpAndSettle();

    // Assign a member, un-assign, re-assign.
    await tester.tap(find.byKey(const ValueKey('cat-person-me')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cat-person-me')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cat-person-me')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();

    final cat = thriveDebug.eventCategories.single;
    expect(cat.emoji, '😀');
    expect(cat.members, ['me']);
    expect(find.text('Work'), findsWidgets);
    expect(find.textContaining('1 member'), findsOneWidget);

    // Delete from inside the studio — the counting confirm spells out that
    // events keep their times.
    await tester.tap(find.byKey(ValueKey('cats-row-${cat.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
    await tester.pumpAndSettle();
    expect(thriveDebug.eventCategories, isEmpty);
  });

  testWidgets('layer management: add with colour + emoji, edit and delete', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tapHubRow(tester, 'planning', 'more-callayers');

    // Adding a layer toasts and stays on the list (#327).
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'Sports',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    final layer = thriveDebug.calendarLayers.firstWhere(
      (l) => l.label == 'Sports',
    );

    // Edit the custom layer, set an emoji through the free input, save.
    await tester.tap(find.byKey(ValueKey('layers-row-${layer.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Edit layer'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-link')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('badge-stage-emoji-input')),
      '⚽',
    );
    await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-use')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(
      thriveDebug.calendarLayers.firstWhere((l) => l.id == layer.id).emoji,
      '⚽',
    );

    // Delete it from its studio; the counting confirm moves its events.
    await tester.tap(find.byKey(ValueKey('layers-row-${layer.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
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
