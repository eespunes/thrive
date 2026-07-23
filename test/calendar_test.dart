import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

class _RecordingNotificationScheduler implements NotificationScheduler {
  final List<CalendarEvent> scheduledEvents = [];
  final List<String> cancelledEvents = [];

  @override
  Future<void> scheduleTaskReminder(ListTask task) async {}

  @override
  Future<void> cancelTaskReminder(String taskId) async {}

  @override
  Future<void> scheduleEventReminder(CalendarEvent event) async {
    scheduledEvents.add(event);
  }

  @override
  Future<void> cancelEventReminder(String eventId) async {
    cancelledEvents.add(eventId);
  }

  @override
  Future<void> syncEventReminders(Iterable<CalendarEvent> events) async {
    scheduledEvents.addAll(events);
  }
}

Future<void> goToCalendar(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-calendar')));
  await tester.pumpAndSettle();
}

/// Calendar management (categories/imports) moved behind the More hub once
/// the new header replaced the old inline sub-header's "Manage" button.
Future<void> openCalManage(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-more')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('more-calmanage')));
  await tester.pumpAndSettle();
}

/// Switches the calendar view via the header's view-switcher sheet.
Future<void> setCalView(WidgetTester tester, String value) async {
  await tester.tap(find.byKey(const ValueKey('cal-header-view')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('cal-view-$value')));
  await tester.pumpAndSettle();
}

Future<void> openCalFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('cal-header-filter')));
  await tester.pumpAndSettle();
}

Map<String, Object> calendarPrefs({
  required List<CalendarEvent> events,
  List<EventCategory> categories = const [],
  List<ImportedCalendar> importedCalendars = const [],
}) {
  final family = Family(
    id: 'fam_main',
    name: 'Janssen family',
    username: 'janssen',
    members: [
      FamilyMember(
        id: 'me',
        name: 'Eva Janssen',
        email: 'eva.janssen@gmail.com',
        initials: 'EJ',
        color: kMemberColors[0],
        role: 'owner',
      ),
      FamilyMember(
        id: 'erik',
        name: 'Erik Janssen',
        email: 'erik.janssen@gmail.com',
        initials: 'EJ',
        color: kMemberColors[1],
      ),
    ],
  );
  final ws = Workspace.empty()
    ..events = events
    ..eventCategories = categories
    ..importedCalendars = importedCalendars;
  return {
    'flutter.$kStorageKeyV4': json.encode({
      'year': 2026,
      'monthIdx': 6,
      'screen': 'overview',
      'tab': 'home',
      'familyId': 'fam_main',
      'families': [family.toJson()],
      'workspaces': {'fam_main': ws.toJson()},
    }),
  };
}

String addDaysForTest(String iso, int n) {
  final d = DateTime.parse('${iso}T00:00:00Z').add(Duration(days: n));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String shortDateForTest(String iso) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final d = DateTime.parse('${iso}T00:00:00Z');
  return '${months[d.month - 1]} ${d.day}';
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
      // The double space before the score is also collapsed by the emoji/
      // whitespace stripping applied to imported titles.
      expect(ev.title, 'NAC Breda - Ajax (0-2)');
      // The match-link URL is stripped from imported descriptions, leaving
      // just the competition name.
      expect(ev.notes, 'Eredivisie');
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

  testWidgets('calendar header shows both action icons', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    final viewButton = find.byKey(const ValueKey('cal-header-view'));
    final filterButton = find.byKey(const ValueKey('cal-header-filter'));
    expect(viewButton, findsOneWidget);
    expect(filterButton, findsOneWidget);
    expect(
      find.descendant(of: viewButton, matching: find.byType(SvgPicture)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: filterButton, matching: find.byType(SvgPicture)),
      findsOneWidget,
    );
  });

  testWidgets('month events use solid colors and category visuals', (
    tester,
  ) async {
    const categoryColor = Color(0xff0f9d6a);
    const plainColor = Color(0xffd97706);
    final category = EventCategory(
      id: 'family',
      name: 'Family',
      color: categoryColor,
      icon: 'star',
    );
    CalendarEvent event(
      String id,
      Color color, {
      String? categoryId,
      String endDate = '',
    }) => CalendarEvent(
      id: id,
      title: 'Event $id',
      date: todayIso(),
      endDate: endDate,
      color: color,
      category: categoryId ?? category.id,
      reminder: 'none',
    );
    await pumpApp(
      tester,
      prefs: calendarPrefs(
        events: [
          event('one', const Color(0xffe11d48)),
          event(
            'two',
            const Color(0xff1684b4),
            endDate: addDaysForTest(todayIso(), 1),
          ),
          event('plain', plainColor, categoryId: ''),
        ],
        categories: [category],
      ),
      landOnDefaultTab: true,
    );
    await goToCalendar(tester);

    for (final entry in {
      'one': categoryColor,
      'two': categoryColor,
      'plain': plainColor,
    }.entries) {
      final id = entry.key;
      final bar = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('cal-bar-$id-'),
      );
      expect(bar, findsOneWidget);
      if (id != 'plain') {
        expect(
          find.descendant(of: bar, matching: find.byType(SvgPicture)),
          findsOneWidget,
        );
      }
      final usesCategoryColor = tester
          .widgetList<Container>(
            find.descendant(of: bar, matching: find.byType(Container)),
          )
          .any(
            (container) =>
                container.decoration is BoxDecoration &&
                (container.decoration! as BoxDecoration).color == entry.value,
          );
      expect(usesCategoryColor, isTrue);
    }
  });

  testWidgets('month view shades days outside the selected month', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    final previousMonth = tester.widget<Container>(
      find.byKey(const ValueKey('cal-day-bg-2026-06-29')),
    );
    final selectedMonth = tester.widget<Container>(
      find.byKey(const ValueKey('cal-day-bg-2026-07-01')),
    );

    final previousDecoration = previousMonth.decoration! as BoxDecoration;
    final selectedDecoration = selectedMonth.decoration! as BoxDecoration;
    expect(previousDecoration.color, const Color(0xfff0f2f6));
    expect(selectedDecoration.color, Colors.transparent);
    expect((selectedDecoration.border! as Border).left.color, B.line);
  });

  testWidgets('tapping a day in Month view opens its day-detail sheet', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(ValueKey('cal-day-${todayIso()}')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing scheduled for this day.'), findsOneWidget);
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

    expect(find.text('Dentist'), findsWidgets);
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

  testWidgets('the multi-day toggle reveals an end-date field', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    expect(find.text('ENDS'), findsNothing);

    await tester.tap(find.text('Multi-day'));
    await tester.pumpAndSettle();
    expect(find.text('ENDS'), findsOneWidget);
  });

  testWidgets('view, edit and delete a one-off event', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);
    final originalScheduler = NotificationService.instance;
    final scheduler = _RecordingNotificationScheduler();
    NotificationService.instance = scheduler;
    addTearDown(() => NotificationService.instance = originalScheduler);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Team lunch');
    await tester.pump();
    await tester.tap(find.text('Add event').last);
    await tester.pumpAndSettle();
    expect(scheduler.scheduledEvents, hasLength(1));
    expect(scheduler.scheduledEvents.single.title, 'Team lunch');
    final eventId = scheduler.scheduledEvents.single.id;

    await tester.tap(find.text('Team lunch').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Team lunch'), findsNothing);
    expect(scheduler.cancelledEvents, [eventId]);
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

  testWidgets('calendar settings marks categories and assigned imports', (
    tester,
  ) async {
    const categoryColor = Color(0xff7c3aed);
    final category = EventCategory(
      id: 'family',
      name: 'Family',
      color: categoryColor,
      icon: 'star',
    );
    final imported = ImportedCalendar(
      id: 'school-feed',
      name: 'School calendar',
      provider: 'ics',
      color: const Color(0xff475569),
      category: category.id,
      events: [
        ImportedCalendarEvent(
          id: 'lesson',
          title: 'Parent evening',
          date: todayIso(),
        ),
      ],
    );
    await pumpApp(
      tester,
      prefs: calendarPrefs(
        events: const [],
        categories: [category],
        importedCalendars: [imported],
      ),
      landOnDefaultTab: true,
    );
    await openCalManage(tester);

    for (final key in ['cat-marker-family', 'imp-marker-school-feed']) {
      final marker = tester.widget<Container>(find.byKey(ValueKey(key)));
      expect(marker.color, categoryColor);
      expect(marker.constraints?.maxWidth, 4);
    }
    final importVisual = find.byKey(const ValueKey('imp-visual-school-feed'));
    expect(
      find.descendant(of: importVisual, matching: find.byType(SvgPicture)),
      findsOneWidget,
    );
    expect(find.text('Family · ICS / web link · 1 event'), findsOneWidget);
  });

  testWidgets('assigning a category to a new event selects its chip', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    // Create the category via the management sheet first.
    await openCalManage(tester);
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
    await goToCalendar(tester);
    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Dinner');
    await tester.pump();
    await tester.tap(find.text('Family').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add event').last);
    await tester.pumpAndSettle();

    expect(find.text('Dinner'), findsWidgets);
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

      await tester.tap(find.text('Standup').first);
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
      await setCalView(tester, 'agenda');
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

    await openCalManage(tester);
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
    // calendar screen underneath.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await goToCalendar(tester);
    await setCalView(tester, 'agenda');
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

      await openCalManage(tester);
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
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');
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
      await openCalManage(tester);
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
      await setCalView(tester, 'agenda');
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
      await setCalView(tester, 'agenda');
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
    await openCalManage(tester);
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
      await openCalManage(tester);
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
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');
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
    await openCalManage(tester);
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

      await openCalManage(tester);
      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Family');
      await tester.pump();
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      expect(find.text('Family'), findsWidgets);

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
      await goToCalendar(tester);
      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Dinner');
      await tester.pump();
      await tester.tap(find.text('Household').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add event').last);
      await tester.pumpAndSettle();

      await openCalManage(tester);
      await tester.tap(find.text('Household').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.text('Household'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await goToCalendar(tester);
      expect(find.text('Dinner'), findsWidgets);
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

    await setCalView(tester, 'agenda');
    expect(find.text('Solo task'), findsOneWidget);

    // No filters active by default; opening and closing the filter sheet
    // without picking anything leaves everything showing (default attendee
    // is "me").
    await openCalFilters(tester);
    expect(find.text('Show all events'), findsOneWidget);
    await tester.tap(find.text('Show all events'));
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

    await setCalView(tester, 'agenda');
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

    await setCalView(tester, 'agenda');
    expect(find.text('Monthly bill'), findsAtLeastNWidgets(2));
  });

  testWidgets(
    'a member filter hides events not assigned to that member, a category '
    'filter hides events tagged with a different category',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await openCalManage(tester);
      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Work');
      await tester.pump();
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await goToCalendar(tester);
      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Standup');
      await tester.pump();
      await tester.tap(find.text('Work').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add event').last);
      await tester.pumpAndSettle();

      await setCalView(tester, 'agenda');
      expect(find.text('Standup'), findsOneWidget);

      // The event only has the default "me" attendee; a filter for the
      // other family member should hide it.
      await openCalFilters(tester);
      await tester.tap(find.text('Erik Janssen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show 1 filter'));
      await tester.pumpAndSettle();
      expect(find.text('Standup'), findsNothing);

      await openCalFilters(tester);
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show all events'));
      await tester.pumpAndSettle();
      expect(find.text('Standup'), findsOneWidget);

      // A category filter for a different category also hides it.
      await openCalManage(tester);
      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Personal');
      await tester.pump();
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await goToCalendar(tester);
      await openCalFilters(tester);
      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show 1 filter'));
      await tester.pumpAndSettle();
      expect(find.text('Standup'), findsNothing);
    },
  );

  testWidgets('view picker switches to Family view and shows member events', (
    tester,
  ) async {
    await pumpApp(
      tester,
      prefs: calendarPrefs(
        events: [
          CalendarEvent(
            id: 'fam-erik',
            title: 'Guitar lesson',
            date: todayIso(),
            start: '09:00',
            end: '10:00',
            color: kEventColors.first,
            attendees: ['erik'],
          ),
          CalendarEvent(
            id: 'fam-trip',
            title: 'Family trip',
            date: todayIso(),
            endDate: addDaysForTest(todayIso(), 2),
            start: '11:00',
            end: '12:00',
            color: kEventColors[1],
            attendees: ['erik'],
          ),
        ],
      ),
      landOnDefaultTab: true,
    );
    await goToCalendar(tester);

    await setCalView(tester, 'family');

    expect(find.text('MEMBER'), findsOneWidget);
    expect(find.text('Eva Janssen'), findsOneWidget);
    expect(find.text('Erik Janssen'), findsOneWidget);
    expect(find.textContaining('Guitar lesson'), findsOneWidget);
    final familyCell = tester.widget<Container>(
      find.byKey(ValueKey('cal-family-cell-erik-${todayIso()}')),
    );
    expect(
      ((familyCell.decoration! as BoxDecoration).border! as Border).left.color,
      B.line,
    );
    expect(
      find.byKey(ValueKey('cal-family-pinned-fam-trip-${todayIso()}')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cal-family-erik-fam-trip')),
      findsNothing,
    );
  });

  testWidgets('filter sheet combines member and category filters', (
    tester,
  ) async {
    final work = EventCategory(
      id: 'work',
      name: 'Work',
      color: kCatColors.first,
      icon: 'briefcase',
    );
    final school = EventCategory(
      id: 'school',
      name: 'School',
      color: kCatColors[1],
      icon: 'book',
    );
    await pumpApp(
      tester,
      prefs: calendarPrefs(
        categories: [work, school],
        events: [
          CalendarEvent(
            id: 'mine-work',
            title: 'Work sync',
            date: todayIso(),
            start: '09:00',
            end: '10:00',
            category: work.id,
            color: work.color,
            attendees: ['me'],
          ),
          CalendarEvent(
            id: 'erik-school',
            title: 'School pickup',
            date: todayIso(),
            start: '11:00',
            end: '12:00',
            category: school.id,
            color: school.color,
            attendees: ['erik'],
          ),
        ],
      ),
      landOnDefaultTab: true,
    );
    await goToCalendar(tester);
    await setCalView(tester, 'agenda');
    expect(find.text('Work sync'), findsOneWidget);
    expect(find.text('School pickup'), findsOneWidget);

    await openCalFilters(tester);
    await tester.tap(find.byKey(const ValueKey('cal-filter-member-me')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cal-filter-cat-work')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show 2 filters'));
    await tester.pumpAndSettle();

    expect(find.text('Work sync'), findsOneWidget);
    expect(find.text('School pickup'), findsNothing);
  });

  testWidgets(
    'member filter keeps imported events when their category has that member',
    (tester) async {
      final school = EventCategory(
        id: 'school',
        name: 'School',
        color: kCatColors.first,
        icon: 'book',
        members: const ['erik'],
      );
      final imported = ImportedCalendar(
        id: 'school-feed',
        name: 'School calendar',
        provider: 'ics',
        color: const Color(0xff475569),
        category: school.id,
        events: [
          ImportedCalendarEvent(
            id: 'parent-evening',
            title: 'Parent evening',
            date: todayIso(),
          ),
        ],
      );
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: const [],
          categories: [school],
          importedCalendars: [imported],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');
      expect(find.text('Parent evening'), findsOneWidget);

      await openCalFilters(tester);
      await tester.tap(find.byKey(const ValueKey('cal-filter-member-erik')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show 1 filter'));
      await tester.pumpAndSettle();

      expect(find.text('Parent evening'), findsOneWidget);
    },
  );

  testWidgets('multi-day event renders as a month span and shows date range', (
    tester,
  ) async {
    final end = addDaysForTest(todayIso(), 2);
    await pumpApp(
      tester,
      prefs: calendarPrefs(
        events: [
          CalendarEvent(
            id: 'span1',
            title: 'Grandparents visiting',
            allDay: true,
            date: todayIso(),
            endDate: end,
            color: kEventColors[3],
            attendees: ['me', 'erik'],
          ),
        ],
      ),
      landOnDefaultTab: true,
    );
    await goToCalendar(tester);

    expect(find.text('Grandparents visiting'), findsOneWidget);
    await tester.tap(find.text('Grandparents visiting'));
    await tester.pumpAndSettle();

    expect(
      find.text('${shortDateForTest(todayIso())} – ${shortDateForTest(end)}'),
      findsOneWidget,
    );
  });

  testWidgets('Week view renders and opens a timed event block', (
    tester,
  ) async {
    await pumpApp(
      tester,
      prefs: calendarPrefs(
        events: [
          CalendarEvent(
            id: 'timed1',
            title: 'Dentist timed',
            date: todayIso(),
            start: '09:00',
            end: '10:30',
            color: kEventColors[2],
            attendees: ['me'],
          ),
          CalendarEvent(
            id: 'week-trip',
            title: 'Weekend away',
            date: todayIso(),
            endDate: addDaysForTest(todayIso(), 2),
            start: '12:00',
            end: '13:00',
            color: kEventColors[3],
            attendees: ['me'],
          ),
        ],
      ),
      landOnDefaultTab: true,
    );
    await goToCalendar(tester);
    await setCalView(tester, 'week');

    expect(find.byKey(const ValueKey('cal-timed-timed1')), findsOneWidget);
    expect(
      find.byKey(ValueKey('cal-pinned-week-week-trip-${todayIso()}')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('cal-timed-week-trip')), findsNothing);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('23:00'), findsOneWidget);
    final firstHour = tester.widget<Container>(
      find.byKey(const ValueKey('cal-week-hour-0')),
    );
    expect(
      ((firstHour.decoration! as BoxDecoration).border! as Border).top.color,
      B.line,
    );
    final dayColumns = tester.widgetList<Container>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'cal-week-day-col-',
            ),
      ),
    );
    expect(
      ((dayColumns.elementAt(1).decoration! as BoxDecoration).border! as Border)
          .left
          .color,
      B.line,
    );

    final timelineFinder = find.byKey(const ValueKey('cal-timeline-week'));
    final viewportHeight = tester.getSize(timelineFinder).height;
    final gridHeight = tester
        .getSize(find.byKey(const ValueKey('cal-hour-grid-week')))
        .height;
    expect(gridHeight, closeTo(viewportHeight * 3, 0.1));

    final scrollView = tester.widget<SingleChildScrollView>(timelineFinder);
    final rowHeight = viewportHeight / 8;
    final now = DateTime.now();
    final currentHour = now.hour + now.minute / 60;
    final expectedOffset = ((currentHour - 4) * rowHeight).clamp(
      0.0,
      gridHeight - viewportHeight,
    );
    expect(scrollView.controller!.offset, closeTo(expectedOffset, 2));

    await tester.ensureVisible(find.byKey(const ValueKey('cal-timed-timed1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cal-timed-timed1')));
    await tester.pumpAndSettle();

    expect(find.text('Dentist timed'), findsWidgets);
    expect(find.text('09:00 – 10:30'), findsOneWidget);
  });

  testWidgets('month picker jumps to a chosen month and back to today', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('cal-month-title')));
    await tester.pumpAndSettle();
    expect(find.text('Jump to a month'), findsOneWidget);

    final today = _isoNow();
    final year = int.parse(today.substring(0, 4));
    final month = int.parse(today.substring(5, 7));
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    await tester.tap(
      find.byKey(ValueKey('cal-pick-month-$nextYear-$nextMonth')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cal-month-title')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jump to today'));
    await tester.pumpAndSettle();
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

    await tester.tap(find.text('Original title').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Updated title');
    await tester.pump();
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();

    expect(find.text('Updated title'), findsWidgets);
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
    await openCalManage(tester);
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
    await goToCalendar(tester);
    await setCalView(tester, 'agenda');
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
    await openCalManage(tester);
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

String _isoNow() => todayIso();
