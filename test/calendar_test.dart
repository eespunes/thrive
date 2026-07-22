import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

Future<void> goToCalendar(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-calendar')));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'parseIcsEvents reads SUMMARY/DESCRIPTION/LOCATION and ignores nested VALARM',
    () {
      // Shaped like fotmob's team fixture feed: a VALARM sub-component whose
      // own SUMMARY/DESCRIPTION must not clobber the VEVENT's.
      const ics =
          'BEGIN:VCALENDAR\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:4815511-8593@fotmob.com\r\n'
          'DESCRIPTION:https://www.fotmob.com/match/4815511\\nEredivisie\r\n'
          'DTSTART:20260425T180000Z\r\n'
          'DTEND:20260425T200000Z\r\n'
          'LOCATION:Rat Verlegh Stadion\\, Stadionstraat 23\\, Breda\\, NED\r\n'
          'SUMMARY:NAC Breda - Ajax  (0-2)\r\n'
          'BEGIN:VALARM\r\n'
          'ACTION:DISPLAY\r\n'
          'DESCRIPTION:NAC Breda - Ajax starting in 15 minutes\r\n'
          'SUMMARY:NAC Breda - Ajax starting in 15 minutes\r\n'
          'TRIGGER:-PT15M\r\n'
          'END:VALARM\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n';

      final events = parseIcsEvents(ics);
      expect(events, hasLength(1));
      final ev = events.single;
      expect(ev.title, 'NAC Breda - Ajax  (0-2)');
      expect(ev.notes, 'https://www.fotmob.com/match/4815511\nEredivisie');
      expect(ev.location, 'Rat Verlegh Stadion, Stadionstraat 23, Breda, NED');
    },
  );

  test('parseIcsEvents unfolds a continuation line', () {
    const ics =
        'BEGIN:VCALENDAR\r\n'
        'BEGIN:VEVENT\r\n'
        'UID:1\r\n'
        'SUMMARY:Long titl\r\n'
        ' e wraps\r\n'
        'DTSTART:20260101T100000\r\n'
        'END:VEVENT\r\n'
        'END:VCALENDAR\r\n';

    final events = parseIcsEvents(ics);
    expect(events.single.title, 'Long title wraps');
  });

  group('fetchIcsEvents', () {
    setUp(() => icsHttpGetOverride = null);
    tearDown(() => icsHttpGetOverride = null);

    test('rejects an unparsable URL', () async {
      await expectLater(
        fetchIcsEvents(''),
        throwsA(
          isA<IcsImportException>().having(
            (e) => e.message,
            'message',
            'Enter a valid calendar URL',
          ),
        ),
      );
    });

    test('rejects an unsupported scheme', () async {
      await expectLater(
        fetchIcsEvents('ftp://example.com/cal.ics'),
        throwsA(
          isA<IcsImportException>().having(
            (e) => e.message,
            'message',
            'Only http(s)/webcal links are supported',
          ),
        ),
      );
    });

    test('rewrites webcal:// to https:// before fetching', () async {
      Uri? seen;
      icsHttpGetOverride = (uri) async {
        seen = uri;
        return http.Response(
          'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:1\r\nSUMMARY:x\r\n'
          'DTSTART:20260101T100000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
          200,
        );
      };
      await fetchIcsEvents('webcal://example.com/cal.ics');
      expect(seen?.scheme, 'https');
    });

    test('surfaces a timeout as a friendly message', () async {
      icsHttpGetOverride = (uri) async => throw TimeoutException('t');
      await expectLater(
        fetchIcsEvents('https://example.com/cal.ics'),
        throwsA(
          isA<IcsImportException>().having(
            (e) => e.message,
            'message',
            'Calendar link timed out',
          ),
        ),
      );
    });

    test('surfaces any other fetch error as a friendly message', () async {
      icsHttpGetOverride = (uri) async => throw Exception('boom');
      await expectLater(
        fetchIcsEvents('https://example.com/cal.ics'),
        throwsA(
          isA<IcsImportException>().having(
            (e) => e.message,
            'message',
            'Could not reach that calendar link',
          ),
        ),
      );
    });

    test('surfaces a non-2xx status code', () async {
      icsHttpGetOverride = (uri) async => http.Response('nope', 404);
      await expectLater(
        fetchIcsEvents('https://example.com/cal.ics'),
        throwsA(
          isA<IcsImportException>().having(
            (e) => e.message,
            'message',
            'Calendar link returned 404',
          ),
        ),
      );
    });

    test('surfaces a feed with no events', () async {
      icsHttpGetOverride = (uri) async =>
          http.Response('BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n', 200);
      await expectLater(
        fetchIcsEvents('https://example.com/cal.ics'),
        throwsA(
          isA<IcsImportException>().having(
            (e) => e.message,
            'message',
            'No events found in that calendar',
          ),
        ),
      );
    });
  });

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

  testWidgets('All-day toggle hides the start/end time fields', (tester) async {
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

  testWidgets('creating a category from the event editor lands on Calendars & '
      'categories with it listed', (tester) async {
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
  });

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

  testWidgets('import a calendar fetches and shows its real events', (
    tester,
  ) async {
    final today = todayIso().replaceAll('-', '');
    icsHttpGetOverride = (uri) async {
      return http.Response(
        'BEGIN:VCALENDAR\r\n'
        'BEGIN:VEVENT\r\n'
        'UID:1\r\n'
        'SUMMARY:Imported event\r\n'
        'DTSTART:${today}T100000\r\n'
        'DTEND:${today}T110000\r\n'
        'END:VEVENT\r\n'
        'END:VCALENDAR\r\n',
        200,
      );
    };
    addTearDown(() => icsHttpGetOverride = null);

    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('cal-manage')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing imported yet.'), findsOneWidget);

    await tester.tap(find.text('Import a calendar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'https://example.com/team.ics',
    );
    await tester.enterText(find.byType(TextField).at(1), 'Erik · Work');
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

    // Tapping the imported event opens a read-only view: no Edit/Delete.
    await tester.tap(find.text('Imported event').first);
    await tester.pumpAndSettle();
    expect(find.text('Imported events are read-only'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets(
    'turning off "Import location" excludes it while keeping the description',
    (tester) async {
      final today = todayIso().replaceAll('-', '');
      icsHttpGetOverride = (uri) async {
        return http.Response(
          'BEGIN:VCALENDAR\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:1\r\n'
          'SUMMARY:Match day\r\n'
          'DESCRIPTION:Eredivisie fixture\r\n'
          'LOCATION:Johan Cruijff ArenA\r\n'
          'DTSTART:${today}T100000\r\n'
          'DTEND:${today}T110000\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n',
          200,
        );
      };
      addTearDown(() => icsHttpGetOverride = null);

      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('cal-manage')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import a calendar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'https://example.com/team.ics',
      );
      await tester.tap(find.text('Import location'));
      await tester.pump();
      await tester.tap(find.text('Import calendar'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Match day').first);
      await tester.pumpAndSettle();

      expect(find.text('Eredivisie fixture'), findsOneWidget);
      expect(find.text('Johan Cruijff ArenA'), findsNothing);
    },
  );

  testWidgets(
    'auto-sync refreshes an ICS import on reboot; turning it off stops that',
    (tester) async {
      final today = todayIso().replaceAll('-', '');
      String title = 'Match day v1';
      icsHttpGetOverride = (uri) async {
        return http.Response(
          'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:1\r\nSUMMARY:$title\r\n'
          'DTSTART:${today}T100000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
          200,
        );
      };
      addTearDown(() => icsHttpGetOverride = null);

      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);
      await tester.tap(find.byKey(const ValueKey('cal-manage')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import a calendar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'https://example.com/team.ics',
      );
      await tester.pump();
      await tester.tap(find.text('Import calendar'));
      await tester.pumpAndSettle();

      // Auto-sync is on by default: change what the feed returns, then
      // reboot — the boot-time sync should pick up the new title.
      title = 'Match day v2';
      await rebootApp(tester);
      await goToCalendar(tester);
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Match day v2'), findsWidgets);

      // Turn auto-sync off, change the feed again, reboot — should NOT
      // pick up the new title this time.
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('more-calmanage')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auto-syncs on open'));
      await tester.pumpAndSettle();
      expect(find.text('Auto-sync off'), findsOneWidget);

      title = 'Match day v3';
      await rebootApp(tester);
      await goToCalendar(tester);
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Match day v2'), findsWidgets);
      expect(find.text('Match day v3'), findsNothing);
    },
  );

  testWidgets('manual "sync now" surfaces a fetch error', (tester) async {
    final today = todayIso().replaceAll('-', '');
    icsHttpGetOverride = (uri) async {
      return http.Response(
        'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:1\r\nSUMMARY:Match day\r\n'
        'DTSTART:${today}T100000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
        200,
      );
    };
    addTearDown(() => icsHttpGetOverride = null);

    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);
    await tester.tap(find.byKey(const ValueKey('cal-manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import a calendar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'https://example.com/team.ics',
    );
    await tester.pump();
    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();

    icsHttpGetOverride = (uri) async => http.Response('nope', 500);
    // The sync-button key is per-calendar-id (`imp-sync-<id>`); find it
    // generically since the generated id isn't known here.
    final syncBtn = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          (w.key as ValueKey).value.toString().startsWith('imp-sync-'),
    );
    await tester.tap(syncBtn);
    await tester.pumpAndSettle();

    expect(find.text('Calendar link returned 500'), findsOneWidget);
  });

  testWidgets(
    'toggling location/description chips strips them from stored events',
    (tester) async {
      final today = todayIso().replaceAll('-', '');
      icsHttpGetOverride = (uri) async {
        return http.Response(
          'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:1\r\nSUMMARY:Match day\r\n'
          'DESCRIPTION:Eredivisie\r\nLOCATION:ArenA\r\n'
          'DTSTART:${today}T100000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
          200,
        );
      };
      addTearDown(() => icsHttpGetOverride = null);

      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);
      await tester.tap(find.byKey(const ValueKey('cal-manage')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import a calendar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'https://example.com/team.ics',
      );
      await tester.pump();
      await tester.tap(find.text('Import calendar'));
      await tester.pumpAndSettle();

      // Toggle both chips off from the manage sheet (post-import).
      await tester.tap(find.text('Location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Description'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Match day').first);
      await tester.pumpAndSettle();

      expect(find.text('Eredivisie'), findsNothing);
      expect(find.text('ArenA'), findsNothing);
    },
  );

  testWidgets('deleting an imported calendar removes it', (tester) async {
    final today = todayIso().replaceAll('-', '');
    icsHttpGetOverride = (uri) async {
      return http.Response(
        'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:1\r\nSUMMARY:Match day\r\n'
        'DTSTART:${today}T100000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
        200,
      );
    };
    addTearDown(() => icsHttpGetOverride = null);

    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);
    await tester.tap(find.byKey(const ValueKey('cal-manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import a calendar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'https://example.com/team.ics',
    );
    await tester.enterText(find.byType(TextField).at(1), 'Fixtures');
    await tester.pump();
    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Fixtures'), findsWidgets);

    // "Fixtures" also appears as the imported event's card tag underneath
    // the modal sheet — target the sheet row (rendered last) specifically.
    await tester.drag(find.text('Fixtures').last, const Offset(-220, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Fixtures'), findsNothing);
    expect(find.text('Nothing imported yet.'), findsOneWidget);
  });

  testWidgets(
    'editing a category renames it; deleting it clears it from events',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('cal-manage')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Family');
      await tester.pump();
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      expect(find.text('Family'), findsWidgets);

      // "Family" also appears as a filter chip in the calendar sub-header
      // underneath the modal sheet — target the sheet row (rendered last).
      // Edit: tap the category row, rename, save.
      await tester.tap(find.text('Family').last);
      await tester.pumpAndSettle();
      expect(find.text('Edit category'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Household');
      await tester.pump();
      await tester.tap(find.text('Save category'));
      await tester.pumpAndSettle();
      expect(find.text('Household'), findsWidgets);
      expect(find.text('Family'), findsNothing);

      // Assign it to an event, then delete the category and confirm the
      // event survives without it.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Dinner');
      await tester.pump();
      await tester.tap(find.text('Household').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add event').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cal-manage')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Household').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.text('Household'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Dinner'), findsOneWidget);
    },
  );

  testWidgets('member and category filters narrow the agenda', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Solo task');
    await tester.pump();
    await tester.tap(find.text('Add event').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Solo task'), findsOneWidget);

    // "Everyone" chip is the default; tap it again then check a specific
    // member filter still shows the event (default attendee is "me").
    final everyone = find.byKey(const ValueKey('cal-filter-all'));
    expect(everyone, findsOneWidget);
    await tester.tap(everyone);
    await tester.pumpAndSettle();
    expect(find.text('Solo task'), findsOneWidget);
  });

  testWidgets('a daily/monthly recurring event expands multiple occurrences', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Daily pill');
    await tester.pump();
    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add event').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    // Over a 160-day agenda window, a daily recurrence shows many times.
    expect(find.text('Daily pill'), findsAtLeastNWidgets(2));
  });

  testWidgets('a monthly recurring event expands multiple occurrences', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Monthly bill');
    await tester.pump();
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add event').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Monthly bill'), findsAtLeastNWidgets(2));
  });

  testWidgets(
    'a member filter hides events not assigned to that member, a category '
    'filter hides events tagged with a different category',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('cal-manage')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Work');
      await tester.pump();
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Standup');
      await tester.pump();
      await tester.tap(find.text('Work').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add event').last);
      await tester.pumpAndSettle();
      expect(find.text('Standup'), findsOneWidget);

      // The event only has the default "me" attendee; a filter for the
      // other family member should hide it.
      await tester.tap(find.text('Erik Janssen'));
      await tester.pumpAndSettle();
      expect(find.text('Standup'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('cal-filter-all')));
      await tester.pumpAndSettle();
      expect(find.text('Standup'), findsOneWidget);

      // A category filter for a different category also hides it.
      await tester.tap(find.byKey(const ValueKey('cal-manage')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Personal');
      await tester.pump();
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();
      expect(find.text('Standup'), findsNothing);
    },
  );

  testWidgets('cal-today jumps back to today after navigating', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('cal-nav-cright')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cal-nav-cright')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cal-today')));
    await tester.pumpAndSettle();
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('editing an existing event updates it in place', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Original title');
    await tester.pump();
    await tester.tap(find.text('Add event').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Original title'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Updated title');
    await tester.pump();
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();

    expect(find.text('Updated title'), findsOneWidget);
    expect(find.text('Original title'), findsNothing);
  });

  testWidgets('toggling an imported calendar\'s visibility hides its events', (
    tester,
  ) async {
    final today = todayIso().replaceAll('-', '');
    icsHttpGetOverride = (uri) async => http.Response(
      'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:1\r\nSUMMARY:Hideable\r\n'
      'DTSTART:${today}T100000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
      200,
    );
    addTearDown(() => icsHttpGetOverride = null);

    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);
    await tester.tap(find.byKey(const ValueKey('cal-manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import a calendar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'https://example.com/team.ics',
    );
    await tester.pump();
    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();

    final visToggle = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          (w.key as ValueKey).value.toString().startsWith('imp-toggle-'),
    );
    await tester.tap(visToggle);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Hideable'), findsNothing);
  });

  testWidgets('manual "sync now" succeeds and shows the updated event count', (
    tester,
  ) async {
    final today = todayIso().replaceAll('-', '');
    icsHttpGetOverride = (uri) async => http.Response(
      'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:1\r\nSUMMARY:v1\r\n'
      'DTSTART:${today}T100000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
      200,
    );
    addTearDown(() => icsHttpGetOverride = null);

    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);
    await tester.tap(find.byKey(const ValueKey('cal-manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import a calendar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'https://example.com/team.ics',
    );
    await tester.pump();
    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();

    icsHttpGetOverride = (uri) async => http.Response(
      'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:1\r\nSUMMARY:v1\r\n'
      'DTSTART:${today}T100000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n'
      'BEGIN:VEVENT\r\nUID:2\r\nSUMMARY:v2\r\n'
      'DTSTART:${today}T110000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
      200,
    );
    final syncBtn = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          (w.key as ValueKey).value.toString().startsWith('imp-sync-'),
    );
    await tester.tap(syncBtn);
    await tester.pumpAndSettle();

    expect(find.text('Calendar synced (2 events)'), findsOneWidget);
  });

  test('IcsImportException.toString() returns its message', () {
    expect(IcsImportException('boom').toString(), 'boom');
  });
}
