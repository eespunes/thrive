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
  testWidgets('ticket elements open their trays and log analytics', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await openEditor(tester);
    kAnalyticsEvents.clear();

    // New events start on Kind & layer (#264).
    expect(find.text('KIND & LAYER'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ticket-when')));
    await tester.pumpAndSettle();
    expect(find.text('WHEN'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ticket-badge-repeat')));
    await tester.pumpAndSettle();
    expect(find.text('Does it happen again?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ticket-badge-reminder')));
    await tester.pumpAndSettle();
    expect(find.text('Want a heads-up?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ticket-place')));
    await tester.pumpAndSettle();
    expect(find.text('PLACE & NOTES'), findsOneWidget);

    expect(
      kAnalyticsEvents.where((e) => e.name == 'ticket_tray_opened').length,
      4,
    );
    // Exactly one tray open at a time.
    expect(find.text('WHEN'), findsNothing);
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

  testWidgets('to-do paper state: live checkbox previews and saves done', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Take out bins');
    await tester.pump();
    expect(find.byKey(const ValueKey('ticket-check')), findsNothing);
    expect(find.text('THRIVE'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('event-kind-todo')));
    await tester.pumpAndSettle();
    // The ticket transformed (#265): TO-DO stub mark + live checkbox.
    expect(find.text('TO-DO'), findsOneWidget);
    expect(find.text('THRIVE'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ticket-check')));
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
    await tester.tap(find.byKey(const ValueKey('ticket-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-cat-sport')));
    await tester.pumpAndSettle();

    // Colour tray shows the locked "from category" swatch (#266).
    await tester.tap(find.byKey(const ValueKey('ticket-colour')));
    await tester.pumpAndSettle();
    expect(find.text("The ticket takes the category's colour"), findsOneWidget);

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
    await tester.tap(find.byKey(const ValueKey('ticket-when')));
    await tester.pumpAndSettle();
    expect(find.text('Multi-day'), findsNothing);
    expect(
      find.text('Multi-day is off while the event repeats'),
      findsOneWidget,
    );
  });

  testWidgets('reminder tray: no thanks clears, ring line matches the event', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Dentist');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ticket-badge-reminder')));
    await tester.pumpAndSettle();
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
  await tester.tap(find.byKey(const ValueKey('ticket-badge-repeat')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('ticket-again-yes')));
  await tester.pumpAndSettle();
}
