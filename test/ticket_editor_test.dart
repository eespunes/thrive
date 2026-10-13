import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// The ticket event editor (epic: replace `_EventEditSheet`): the WYSIWYG
// ticket (#263), tray navigation (#264), the to-do paper state (#265),
// coupling rules (#266), the two-question Repeat/Reminder trays (#267/#268)
// and the editor's delete flow (#269).

Future<void> openEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-calendar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Event Editor v2: essentials up front, the rest folded', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await openEditor(tester);

    // The Event/To-do switch is pinned; name, category, when and who are
    // always on the page.
    expect(find.byKey(const ValueKey('event-kind-event')), findsOneWidget);
    expect(find.byKey(const ValueKey('event-kind-todo')), findsOneWidget);
    expect(find.text('What’s happening?'), findsOneWidget);
    for (final card in ['category', 'when', 'people']) {
      expect(
        find.byKey(ValueKey('event-card-$card')),
        findsOneWidget,
        reason: 'section $card is missing',
      );
    }
    expect(find.text('When'), findsOneWidget);
    expect(find.text("Who's involved"), findsOneWidget);

    // Everything else is an Options row, folded until tapped.
    expect(find.text('Options'), findsOneWidget);
    for (final row in ['repeat', 'reminder', 'place', 'notes', 'colour']) {
      expect(find.byKey(ValueKey('event-row-$row')), findsOneWidget);
      expect(find.byKey(ValueKey('event-row-$row-open')), findsNothing);
    }
    expect(find.text("Doesn't repeat"), findsOneWidget);
    expect(find.text('1 hour before'), findsOneWidget);
    expect(find.text('Add a place'), findsOneWidget);
    expect(find.text('Calendar & colour'), findsOneWidget);

    // Only one row is open at a time.
    await openEventOption(tester, 'repeat');
    expect(find.byKey(const ValueKey('event-row-repeat-open')), findsOneWidget);
    await openEventOption(tester, 'reminder');
    expect(find.byKey(const ValueKey('event-row-repeat-open')), findsNothing);
    expect(
      find.byKey(const ValueKey('event-row-reminder-open')),
      findsOneWidget,
    );

    // The colour row already folds, so its selector shows directly.
    await openEventOption(tester, 'colour');
    expect(find.byKey(const ValueKey('colour-toggle')), findsNothing);
    expect(find.text('Palette'), findsOneWidget);
    expect(find.text('RGB / Hex'), findsOneWidget);
  });

  testWidgets('save is disabled until the title is non-empty', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await openEditor(tester);
    final before = thriveDebug.events.length;
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(thriveDebug.events.length, before);
    await tester.enterText(find.byType(TextField).first, 'Picnic');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(thriveDebug.events.length, before + 1);
  });

  testWidgets('to-do kind reveals the done toggle and saves it ticked', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Take out bins');
    await tester.pump();
    // An event has no done state, so the toggle only exists for to-dos.
    expect(find.byKey(const ValueKey('event-done')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('event-kind-todo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    final ev = thriveDebug.events.singleWhere(
      (e) => e.title == 'Take out bins',
    );
    expect(ev.todo, isTrue);
    expect(ev.done, isTrue);
  });

  testWidgets('coupling: category repaints the ticket and swaps attendees', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.mutateState(() {
      thriveDebug.eventCategories.add(
        EventCategory(
          id: 'sport',
          name: 'Sport',
          color: const Color(0xff7c3aed),
          icon: 'star',
          members: ['other'],
        ),
      );
    });
    await tester.pumpAndSettle();
    await openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Match');
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('event-card-category')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-cat-sport')));
    await tester.pumpAndSettle();

    // The category owns the colour, so the selector is replaced (#266).
    expect(find.text('Sets colour & people'), findsOneWidget);
    await openEventOption(tester, 'colour');
    expect(
      find.text(
        'Uses the Sport colour. Pick “None” as category to choose your own.',
      ),
      findsOneWidget,
    );
    expect(find.text('Palette'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    final ev = thriveDebug.events.singleWhere((e) => e.title == 'Match');
    expect(ev.category, 'sport');
    expect(ev.color, const Color(0xff7c3aed));
    expect(ev.attendees, ['other']);
  });

  testWidgets('repeat disables multi-day with the design note', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Course');
    await tester.pump();
    await setTicketRepeatFor(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('event-card-when')));
    await tester.pumpAndSettle();
    expect(find.text('Off while the event repeats'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('event-multi-day')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event-end-date')), findsNothing);
  });

  testWidgets('reminder tray: no thanks clears, ring line matches the event', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Dentist');
    await tester.pump();
    await openEventOption(tester, 'reminder');
    // Default 1h → the ring line shows an actual time.
    expect(find.byKey(const ValueKey('ticket-ring-line')), findsOneWidget);
    expect(find.textContaining('Rings '), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ticket-rem-no')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ticket-ring-line')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(
      thriveDebug.events.singleWhere((e) => e.title == 'Dentist').reminder,
      'none',
    );
  });

  testWidgets('editor delete: one-off confirms, recurring asks scope', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.mutateState(() {
      thriveDebug.events.add(
        CalendarEvent(
          id: 'w1',
          title: 'Weekly thing',
          date: todayIso(),
          allDay: true,
          color: const Color(0xff1684B4),
          recur: 'weekly',
          reminder: 'none',
        ),
      );
    });
    await tester.pumpAndSettle();
    thriveDebug.openEvent(
      thriveDebug.events.singleWhere((e) => e.id == 'w1'),
      todayIso(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ticket-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete recurring event'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recur-delete-all')));
    await tester.pumpAndSettle();
    expect(thriveDebug.events.where((e) => e.id == 'w1'), isEmpty);
  });

  test('repeatPhrase matches what rows render', () {
    final nth = CalendarEvent(
      id: 'n',
      title: 'N',
      date: '2026-09-01',
      color: const Color(0xff1684B4),
      recur: 'monthly',
      monthlyMode: 'nthWeekday',
      monthlyNth: 1,
      monthlyWeekday: 1,
    );
    expect(repeatPhrase(nth), 'Repeats every first Monday');
    expect(calendarRepeatLabel(nth), 'every first Monday');
    final custom = CalendarEvent(
      id: 'c',
      title: 'C',
      date: '2026-09-01',
      color: const Color(0xff1684B4),
      recur: 'custom',
      recurEvery: 3,
      recurUnit: 'week',
      recurWeekdays: const [2, 5],
    );
    expect(repeatPhrase(custom), 'Repeats every 3 weeks on Tuesday & Friday');
  });

  test('reminderRingLine: timed vs all-day', () {
    final timed = CalendarEvent(
      id: 't',
      title: 'T',
      date: '2026-08-28',
      start: '18:00',
      end: '19:00',
      color: const Color(0xff1684B4),
      reminder: '1h',
    );
    expect(reminderRingLine(timed), 'Rings 17:00 · Fri 28-08');
    final allDay = CalendarEvent(
      id: 'a',
      title: 'A',
      date: '2026-08-28',
      allDay: true,
      color: const Color(0xff1684B4),
      reminder: '1d',
    );
    expect(reminderRingLine(allDay), 'Rings the evening before');
    expect(reminderRingLine(allDay..reminder = 'none'), '');
  });
}

/// Same as calendar_test's helper (kept local to avoid cross-imports).
Future<void> setTicketRepeatFor(WidgetTester tester) async {
  await openEventOption(tester, 'repeat');
  await tester.tap(find.byKey(const ValueKey('ticket-cad-weekly')));
  await tester.pumpAndSettle();
}
