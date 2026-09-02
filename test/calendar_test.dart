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
Future<void> openCalManage(WidgetTester tester, {bool imports = false}) async {
  await tester.tap(find.byKey(const ValueKey('nav-more')));
  await tester.pumpAndSettle();
  await tapHubRow(
    tester,
    'planning',
    imports ? 'more-calimports' : 'more-calmanage',
  );
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

/// Opens an event from Month view: tapping an event bar there now always
/// opens the day-detail sheet first (issue #198), so this taps the bar/day
/// then the event card inside the sheet to reach the event view/editor.
Future<void> openMonthEvent(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).first);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w is Text && w.data == title && w.style?.fontSize == 13.5,
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, Object> calendarPrefs({
  required List<CalendarEvent> events,
  List<EventCategory> categories = const [],
  List<ImportedCalendar> importedCalendars = const [],
  List<TaskList> taskLists = const [],
  List<String>? layerFilter,
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
    ..importedCalendars = importedCalendars
    ..taskLists = taskLists;
  final payload = <String, Object>{
    'year': 2026,
    'monthIdx': 6,
    'screen': 'overview',
    'tab': 'home',
    'familyId': 'fam_main',
    'families': [family.toJson()],
    'workspaces': {'fam_main': ws.toJson()},
  };
  if (layerFilter != null) payload['layerFilter'] = layerFilter;
  return {'flutter.$kStorageKeyV4': json.encode(payload)};
}

String addDaysForTest(String iso, int n) {
  final d = DateTime.parse('${iso}T00:00:00Z').add(Duration(days: n));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String addMonthsForTest(String iso, int n) {
  final d = DateTime.parse('${iso}T00:00:00Z');
  final total = d.month - 1 + n;
  // Floor division so negative offsets roll the year backward correctly
  // (Dart's `~/` truncates toward zero, not floor).
  final year = d.year + (total < 0 ? (total - 11) ~/ 12 : total ~/ 12);
  final month = total % 12 + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  final day = d.day > lastDay ? lastDay : d.day;
  return '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

String monthStartForTest(String iso) {
  final d = DateTime.parse('${iso}T00:00:00Z');
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-01';
}

String startOfWeekForTest(String iso) {
  final d = DateTime.parse('${iso}T00:00:00Z');
  return addDaysForTest(iso, -(d.weekday - 1));
}

List<String> monthGridForTest(String anchor) {
  final start = startOfWeekForTest(monthStartForTest(anchor));
  return [for (var i = 0; i < 42; i++) addDaysForTest(start, i)];
}

String monthTitleForTest(String iso) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final d = DateTime.parse('${iso}T00:00:00Z');
  return '${months[d.month - 1]} ${d.year}';
}

String prettyDateForTest(String iso) => shortDateForTest(iso);

String shortDateForTest(String iso) {
  final d = DateTime.parse('${iso}T00:00:00Z');
  return '${d.day.toString().padLeft(2, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.year.toString().padLeft(4, '0')}';
}

/// Ticket-editor helpers: the editor is now the WYSIWYG ticket with trays
/// (epic: replace `_EventEditSheet`), so repeat/reminder/when controls live
/// behind their ticket elements.
Future<void> openTicketTray(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key), warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> setTicketRepeat(WidgetTester tester, {String? cadence}) async {
  await openTicketTray(tester, const ValueKey('ticket-badge-repeat'));
  await tester.tap(find.byKey(const ValueKey('ticket-again-yes')));
  await tester.pumpAndSettle();
  if (cadence != null && cadence != 'weekly') {
    await tester.tap(find.byKey(ValueKey('ticket-cad-$cadence')));
    await tester.pumpAndSettle();
  }
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

  test('defaultCalendarEndTimeForStart returns one hour later', () {
    expect(defaultCalendarEndTimeForStart('09:00'), '10:00');
    expect(defaultCalendarEndTimeForStart('10:35'), '11:35');
    expect(defaultCalendarEndTimeForStart('23:30'), '00:30');
  });

  test('calendarReminderLabel describes supported event reminders', () {
    expect(calendarReminderLabel('none'), 'No reminder');
    expect(calendarReminderLabel('at'), 'On time');
    expect(calendarReminderLabel('5m'), '5 minutes before');
    expect(calendarReminderLabel('15m'), '15 minutes before');
    expect(calendarReminderLabel('30m'), '30 minutes before');
    expect(calendarReminderLabel('1h'), '1 hour before');
    expect(calendarReminderLabel('2h'), '2 hours before');
    expect(calendarReminderLabel('1d'), '1 day before');
    expect(calendarReminderLabel('2d'), '2 days before');
  });

  test('calendarRepeatLabel describes non-custom and custom repeat units', () {
    expect(
      calendarRepeatLabel(
        CalendarEvent(
          id: 'e1',
          title: 'T',
          date: '2026-08-01',
          color: B.primary,
          recur: 'weekly',
        ),
      ),
      'weekly',
    );
    expect(
      calendarRepeatLabel(
        CalendarEvent(
          id: 'e2',
          title: 'T',
          date: '2026-08-01',
          color: B.primary,
          recur: 'custom',
          recurEvery: 1,
          recurUnit: 'day',
        ),
      ),
      'every day',
    );
    expect(
      calendarRepeatLabel(
        CalendarEvent(
          id: 'e3',
          title: 'T',
          date: '2026-08-01',
          color: B.primary,
          recur: 'custom',
          recurEvery: 3,
          recurUnit: 'month',
        ),
      ),
      'every 3 months',
    );
    expect(
      calendarRepeatLabel(
        CalendarEvent(
          id: 'e4',
          title: 'T',
          date: '2026-08-01',
          color: B.primary,
          recur: 'custom',
          recurEvery: 2,
          recurUnit: 'year',
        ),
      ),
      'every 2 years',
    );
    expect(
      calendarRepeatLabel(
        CalendarEvent(
          id: 'e5',
          title: 'T',
          date: '2026-08-01', // Saturday
          color: B.primary,
          recur: 'custom',
          recurEvery: 1,
          recurUnit: 'week',
        ),
      ),
      contains('every week on'),
    );
  });

  test('category palette offers a broad set of colours', () {
    expect(kCatColors.length, greaterThanOrEqualTo(20));
    expect(kCatColors.toSet(), hasLength(kCatColors.length));
    expect(kEventColors, kCatColors);
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
            'Only https/webcal links are supported',
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

  testWidgets('month events use flat solid colors and category visuals', (
    tester,
  ) async {
    // Pin "today" to mid-month: a real month-end date renders the event into
    // both the month cell and the grid's adjacent-month overflow row (#flaky).
    debugNowOverride = () => DateTime(2026, 6, 15);
    addTearDown(() => debugNowOverride = null);
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
      List<String>? attendees,
    }) => CalendarEvent(
      id: id,
      title: 'Event $id',
      date: todayIso(),
      endDate: endDate,
      color: color,
      category: categoryId ?? category.id,
      attendees: attendees,
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
          event('plain', plainColor, categoryId: '', attendees: const []),
          event(
            'member',
            plainColor,
            categoryId: '',
            attendees: const ['erik'],
          ),
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
      'member': plainColor,
    }.entries) {
      final id = entry.key;
      final bar = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('cal-bar-$id-'),
      );
      expect(bar, findsOneWidget);
      if (id == 'one' || id == 'two') {
        expect(
          find.descendant(of: bar, matching: find.byType(SvgPicture)),
          findsOneWidget,
        );
      }
      final matchingDecorations = tester
          .widgetList<Container>(
            find.descendant(of: bar, matching: find.byType(Container)),
          )
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .where(
            (container) =>
                container.color == entry.value &&
                (container.boxShadow?.isNotEmpty != true),
          )
          .toList();
      expect(matchingDecorations, isNotEmpty);
    }
  });

  testWidgets('month view shades days outside the selected month', (
    tester,
  ) async {
    final today = todayIso();
    final grid = monthGridForTest(today);
    final currentMonth = DateTime.parse('${today}T00:00:00Z').month;
    final previousMonthDay = grid.firstWhere(
      (iso) => DateTime.parse('${iso}T00:00:00Z').month != currentMonth,
    );
    final selectedMonthDay = grid.firstWhere(
      (iso) => DateTime.parse('${iso}T00:00:00Z').month == currentMonth,
    );

    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    final previousMonth = tester.widget<Container>(
      find.byKey(ValueKey('cal-day-bg-$previousMonthDay')),
    );
    final selectedMonth = tester.widget<Container>(
      find.byKey(ValueKey('cal-day-bg-$selectedMonthDay')),
    );

    final previousDecoration = previousMonth.decoration! as BoxDecoration;
    final selectedDecoration = selectedMonth.decoration! as BoxDecoration;
    expect(previousDecoration.color, const Color(0xfff0f2f6));
    expect(selectedDecoration.color, Colors.transparent);
    expect((selectedDecoration.border! as Border).left.color, B.line);
  });

  testWidgets('month view fades event bars outside the selected month', (
    tester,
  ) async {
    final today = todayIso();
    final grid = monthGridForTest(today);
    final currentMonth = DateTime.parse('${today}T00:00:00Z').month;
    final outsideDate = grid.firstWhere(
      (iso) => DateTime.parse('${iso}T00:00:00Z').month != currentMonth,
    );
    final insideDate = grid.firstWhere(
      (iso) => DateTime.parse('${iso}T00:00:00Z').month == currentMonth,
    );

    await pumpApp(
      tester,
      prefs: calendarPrefs(
        events: [
          CalendarEvent(
            id: 'outside',
            title: 'Outside month',
            date: outsideDate,
            color: const Color(0xff1684b4),
            reminder: 'none',
          ),
          CalendarEvent(
            id: 'inside',
            title: 'Inside month',
            date: insideDate,
            color: const Color(0xff1684b4),
            reminder: 'none',
          ),
        ],
      ),
      landOnDefaultTab: true,
    );
    await goToCalendar(tester);

    final fadedBar = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'cal-bar-outside-',
          ),
    );
    final normalBar = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('cal-bar-inside-'),
    );
    expect(fadedBar, findsOneWidget);
    expect(normalBar, findsOneWidget);

    final fadedOpacity = tester.widget<Opacity>(
      find.descendant(of: fadedBar, matching: find.byType(Opacity)),
    );
    final normalOpacity = tester.widget<Opacity>(
      find.descendant(of: normalBar, matching: find.byType(Opacity)),
    );
    expect(fadedOpacity.opacity, .45);
    expect(normalOpacity.opacity, 1);
  });

  testWidgets('month weekday header aligns with day columns', (tester) async {
    final grid = monthGridForTest(todayIso());
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    final headerFirst = tester.getTopLeft(
      find.byKey(const ValueKey('cal-weekday-0')),
    );
    final dayFirst = tester.getTopLeft(
      find.byKey(ValueKey('cal-day-bg-${grid.first}')),
    );
    final headerLast = tester.getTopRight(
      find.byKey(const ValueKey('cal-weekday-6')),
    );
    final dayLast = tester.getTopRight(
      find.byKey(ValueKey('cal-day-bg-${grid[6]}')),
    );
    expect(headerFirst.dx, closeTo(dayFirst.dx, 0.01));
    expect(headerLast.dx, closeTo(dayLast.dx, 0.01));

    final headerCell = tester.widget<Container>(
      find.byKey(const ValueKey('cal-weekday-1')),
    );
    final headerBorder =
        (headerCell.decoration! as BoxDecoration).border! as Border;
    expect(headerBorder.left.color, const Color(0xffd5dce8));
    expect(headerBorder.bottom.color, const Color(0xffd5dce8));
  });

  testWidgets('month view highlights today with a cell border', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    final todayCell = tester.widget<Container>(
      find.byKey(ValueKey('cal-day-bg-${todayIso()}')),
    );
    final focus = todayCell.foregroundDecoration! as BoxDecoration;
    expect((focus.border! as Border).top.color, B.primary);
  });

  testWidgets('month view scrolls horizontally between months', (tester) async {
    final today = todayIso();
    final nextMonth = addMonthsForTest(today, 1);
    final nextMonthStart = monthStartForTest(nextMonth);
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    expect(find.text(monthTitleForTest(today)), findsOneWidget);
    await tester.fling(
      find.byKey(const ValueKey('cal-pager-month')),
      const Offset(-700, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(find.text(monthTitleForTest(nextMonth)), findsOneWidget);
    expect(find.byKey(ValueKey('cal-day-bg-$nextMonthStart')), findsOneWidget);
  });

  testWidgets('tapping a day in Month view opens its day-detail sheet', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(ValueKey('cal-day-${todayIso()}')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing scheduled for this day.'), findsOneWidget);
    expect(find.text('Add event for this day'), findsOneWidget);
  });

  testWidgets(
    'tapping empty month day space offers adding an event for that day',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(ValueKey('cal-day-bg-${todayIso()}')));
      await tester.pumpAndSettle();
      expect(find.text('Nothing scheduled for this day.'), findsOneWidget);
      await tester.tap(find.text('Add event for this day'));
      await tester.pumpAndSettle();
      expect(find.text('New event'), findsOneWidget);
      // The ticket's when-line carries the day ("Thu 27-08 · …").
      final iso = todayIso();
      expect(
        find.textContaining('${iso.substring(8)}-${iso.substring(5, 7)} ·'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'tapping a non-today day in Month view opens that day, not today (#198)',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      final today = todayIso();
      final grid = monthGridForTest(today);
      final otherDay = grid.firstWhere((iso) => iso != today);

      await tester.tap(find.byKey(ValueKey('cal-day-$otherDay')));
      await tester.pumpAndSettle();

      // The sheet header should show the tapped day's date, not today's.
      expect(find.text(prettyDateForTest(otherDay)), findsOneWidget);
      expect(find.text(prettyDateForTest(today)), findsNothing);
    },
  );

  testWidgets(
    'tapping an event bar in Month view opens the day list, not the event (#198)',
    (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: [
            CalendarEvent(
              id: 'e1',
              title: 'Team lunch',
              date: today,
              color: const Color(0xff1684b4),
              reminder: 'none',
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);

      // Tap the event bar itself (not empty day background).
      await tester.tap(find.text('Team lunch').first);
      await tester.pumpAndSettle();

      // It should open the day-detail sheet (showing the day's date and an
      // event card), not jump straight to the event editor/view.
      expect(find.text(prettyDateForTest(today)), findsOneWidget);
      expect(find.text('New event'), findsNothing);
    },
  );

  testWidgets('tapping a day in a paged-to month opens that day (#198)', (
    tester,
  ) async {
    final today = todayIso();
    final nextMonth = addMonthsForTest(today, 1);
    final nextMonthGrid = monthGridForTest(nextMonth);
    final dayInNextMonth = nextMonthGrid.firstWhere(
      (iso) =>
          DateTime.parse('${iso}T00:00:00Z').month ==
          DateTime.parse('${nextMonth}T00:00:00Z').month,
    );

    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.fling(
      find.byKey(const ValueKey('cal-pager-month')),
      const Offset(0, -700),
      1200,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('cal-day-$dayInNextMonth')));
    await tester.pumpAndSettle();

    expect(find.text(prettyDateForTest(dayInNextMonth)), findsOneWidget);
    expect(find.text(prettyDateForTest(today)), findsNothing);
  });

  test('addMonthsForTest rolls the year backward across a year boundary', () {
    // Forward across the year boundary: Dec 2026 -> Jan 2027.
    expect(addMonthsForTest('2026-12-15', 1), '2027-01-15');
    // Backward from that result must land back on Dec 2026, not 2027
    // (regression for a truncating, rather than flooring, division of
    // a negative month offset).
    expect(addMonthsForTest('2027-01-15', -1), '2026-12-15');
  });

  test('recurringEventDates still yields occurrences for a daily series '
      'started years before the viewed range', () {
    // Regression: the occurrence guard used to count every step from the
    // series start, so a ~2.5-year-old daily event exhausted the default
    // 900-occurrence budget before reaching the viewed month and silently
    // disappeared from it.
    final ev = CalendarEvent(
      id: 'ev-old-daily',
      title: 'Old daily',
      date: '2023-01-05',
      recur: 'daily',
      color: const Color(0xFF112233),
    );
    final dates = recurringEventDates(ev, '2026-08-01', '2026-08-31');
    expect(dates.length, 31);
    expect(dates.first, '2026-08-01');
    expect(dates.last, '2026-08-31');
  });

  test('a monthly series on the 31st recovers the 31st after a short month '
      'instead of drifting', () {
    // Regression: each occurrence was derived from the previous one, so the
    // February clamp stuck (Jan 31 -> Feb 28 -> Mar 28 forever).
    final ev = CalendarEvent(
      id: 'ev-monthly-31',
      title: 'Monthly on the 31st',
      date: '2026-01-31',
      recur: 'monthly',
      color: const Color(0xFF112233),
    );
    final dates = recurringEventDates(ev, '2026-01-01', '2026-04-30');
    expect(dates, ['2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30']);
  });

  test('a yearly series on Feb 29 clamps only in non-leap years', () {
    final ev = CalendarEvent(
      id: 'ev-leap-yearly',
      title: 'Leap day',
      date: '2024-02-29',
      recur: 'yearly',
      color: const Color(0xFF112233),
    );
    final dates = recurringEventDates(ev, '2024-01-01', '2028-12-31');
    expect(dates, [
      '2024-02-29',
      '2025-02-28',
      '2026-02-28',
      '2027-02-28',
      '2028-02-29',
    ]);
  });

  test('weekNumberLabelForTest follows ISO-8601 week numbering', () {
    // 2026-01-01 is a Thursday, so it anchors week 1; the following Sunday
    // still belongs to week 1 and Monday starts week 2. Computed fully in
    // UTC — mixing a local Jan 1 with the UTC date used to shift the week
    // number by one for UTC+X (e.g. CET) users.
    expect(weekNumberLabelForTest('2026-01-01'), 'Week 1');
    expect(weekNumberLabelForTest('2026-01-04'), 'Week 1');
    expect(weekNumberLabelForTest('2026-01-05'), 'Week 2');
    expect(weekNumberLabelForTest('2026-08-24'), 'Week 35');
  });

  testWidgets('swiping forward then back across a year boundary restores the '
      'original year (month view)', (tester) async {
    final today = DateTime.now();
    // Number of forward swipes needed to land on December of the next
    // December occurring on/after this month (0 if already December).
    final monthsToDecember = (12 - today.month) % 12;

    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    for (var i = 0; i < monthsToDecember; i++) {
      await tester.fling(
        find.byKey(const ValueKey('cal-pager-month')),
        const Offset(-700, 0),
        1200,
      );
      await tester.pumpAndSettle();
    }

    final decemberYear = today.year;
    final decemberLabel = '${kMonthsEn[11]} $decemberYear';
    expect(find.text(decemberLabel), findsOneWidget);

    // Swipe forward once: December -> January of the following year.
    await tester.fling(
      find.byKey(const ValueKey('cal-pager-month')),
      const Offset(-700, 0),
      1200,
    );
    await tester.pumpAndSettle();
    final januaryLabel = '${kMonthsEn[0]} ${decemberYear + 1}';
    expect(find.text(januaryLabel), findsOneWidget);

    // Swipe back once: must restore December of the *original* year,
    // not the following one.
    await tester.fling(
      find.byKey(const ValueKey('cal-pager-month')),
      const Offset(700, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.text(decemberLabel), findsOneWidget);
    expect(find.text('${kMonthsEn[11]} ${decemberYear + 1}'), findsNothing);
  });

  testWidgets(
    'day-detail sheet shows the tapped day events, not today\'s (#198)',
    (tester) async {
      final today = todayIso();
      final grid = monthGridForTest(today);
      final otherDay = grid.firstWhere(
        (iso) =>
            iso != today &&
            DateTime.parse('${iso}T00:00:00Z').month ==
                DateTime.parse('${today}T00:00:00Z').month,
      );

      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: [
            CalendarEvent(
              id: 'today-event',
              title: 'Today only event',
              date: today,
              color: const Color(0xff1684b4),
              reminder: 'none',
            ),
            CalendarEvent(
              id: 'other-event',
              title: 'Other day event',
              date: otherDay,
              color: const Color(0xffef4444),
              reminder: 'none',
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);

      await tester.tap(find.byKey(ValueKey('cal-day-$otherDay')));
      await tester.pumpAndSettle();

      // Bars in the month grid also render event titles (in white, size 9)
      // behind the sheet, so match on the sheet's larger agenda-style title
      // to check what's actually listed inside the day-detail sheet.
      bool isCardTitle(Widget w) => w is Text && w.style?.fontSize == 13.5;
      expect(
        find.byWidgetPredicate(
          (w) => isCardTitle(w) && (w as Text).data == 'Other day event',
        ),
        findsOneWidget,
      );
      final row = find.byKey(ValueKey('event-other-event-$otherDay'));
      expect(row, findsOneWidget);
      final container = tester.widget<Container>(
        find.descendant(of: row, matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xffef4444));
      expect(
        find.byWidgetPredicate(
          (w) => isCardTitle(w) && (w as Text).data == 'Today only event',
        ),
        findsNothing,
      );
    },
  );

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
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Dentist'), findsWidgets);
  });

  testWidgets('event editor can create a to-do event on any selected layer', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event-kind-event')), findsOneWidget);
    expect(find.byKey(const ValueKey('event-kind-todo')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('event-kind-todo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-layer-content')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Return library book');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    final ev = thriveDebug.events.singleWhere(
      (e) => e.title == 'Return library book',
    );
    expect(ev.layerId, 'content');
    expect(ev.todo, isTrue);

    await setCalView(tester, 'agenda');
    expect(find.text('Return library book'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
    expect(
      find.byKey(ValueKey('event-check-${ev.id}-${todayIso()}')),
      findsOneWidget,
    );
  });

  testWidgets('All-day toggle hides the start/end time fields', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await openTicketTray(tester, const ValueKey('ticket-when'));
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);

    await tester.tap(find.text('All-day'));
    await tester.pumpAndSettle();
    expect(find.text('09:00'), findsNothing);
    expect(find.text('10:00'), findsNothing);
  });

  testWidgets('event time picker opens in keyboard input mode', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await openTicketTray(tester, const ValueKey('ticket-when'));
    await tester.tap(find.byKey(const ValueKey('event-time-start')));
    await tester.pumpAndSettle();

    // The custom overwrite-on-type dialog (hour + minute boxes).
    expect(find.byKey(const ValueKey('time-input-hour')), findsOneWidget);
    expect(find.byKey(const ValueKey('time-input-minute')), findsOneWidget);
  });

  testWidgets('event editor offers all reminder options', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await openTicketTray(tester, const ValueKey('ticket-badge-reminder'));

    // Two-question design (2a): yes/no first, offsets after a yes.
    expect(find.text('Want a heads-up?'), findsOneWidget);
    expect(find.text('No thanks'), findsOneWidget);
    expect(find.text('Yes, remind us'), findsOneWidget);
    expect(find.text('On time'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('1 hour'), findsOneWidget);
    expect(find.text('2 hours'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('2 days'), findsOneWidget);
  });

  testWidgets(
    'event editor shows optional repeat end date for recurring events',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('event-repeat-end-date')), findsNothing);

      await setTicketRepeat(tester);

      final repeatEnd = find.byKey(const ValueKey('event-repeat-end-date'));
      expect(repeatEnd, findsOneWidget);
      expect(
        find.descendant(of: repeatEnd, matching: find.text('Never')),
        findsOneWidget,
      );
    },
  );

  testWidgets('repeat tray covers intervals and nth-weekday months', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Padel');
    await tester.pump();
    await setTicketRepeat(tester);

    // Weekly: weekday circles + interval chips (2a).
    expect(
      find.byKey(const ValueKey('event-custom-weekday-1')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('event-custom-every-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    final ev = thriveDebug.events.singleWhere((e) => e.title == 'Padel');
    expect(ev.recur, 'custom');
    expect(ev.recurUnit, 'week');
    expect(ev.recurEvery, 2);

    // Monthly: same-date vs same-weekday, writing the nth fields (#262).
    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Board games');
    await tester.pump();
    await setTicketRepeat(tester, cadence: 'monthly');
    await tester.tap(find.byKey(const ValueKey('ticket-month-nth')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ticket-nth-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ticket-nthday-5')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Repeats every second Friday'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    final bg = thriveDebug.events.singleWhere((e) => e.title == 'Board games');
    expect(bg.recur, 'monthly');
    expect(bg.monthlyMode, 'nthWeekday');
    expect(bg.monthlyNth, 2);
    expect(bg.monthlyWeekday, 5);
  });

  testWidgets('the multi-day toggle reveals an end-date field', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await openTicketTray(tester, const ValueKey('ticket-when'));
    final dates = find.text(shortDateForTest(todayIso()));
    final before = dates.evaluate().length;

    await tester.tap(find.text('Multi-day'));
    await tester.pumpAndSettle();
    // The end-date box appears, showing the same day again.
    expect(dates.evaluate().length, before + 1);
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
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(scheduler.scheduledEvents, hasLength(1));
    expect(scheduler.scheduledEvents.single.title, 'Team lunch');
    final eventId = scheduler.scheduledEvents.single.id;

    await openMonthEvent(tester, 'Team lunch');
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Team lunch'), findsNothing);
    expect(scheduler.cancelledEvents, [eventId]);
  });

  testWidgets('creating a category from the event editor opens the '
      'full-screen category studio (#325)', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await openTicketTray(tester, const ValueKey('ticket-category'));
    await tester.tap(find.byKey(const ValueKey('event-new-category')));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('badge-stage-name')),
      'Work',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();

    expect(thriveDebug.eventCategories.map((c) => c.name), contains('Work'));
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

    // The categories sub-screen (#325) lists the seeded category with its
    // layer + assignment subtitle.
    expect(find.byKey(const ValueKey('cats-row-family')), findsOneWidget);
    expect(find.textContaining('no one assigned'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('studio-back')));
    await tester.pumpAndSettle();

    await openCalManage(tester, imports: true);
    // The imports sub-screen (#326) carries the assigned category, feed
    // type, event count and sync state in the row subtitle, plus the
    // Shown status pill.
    expect(find.byKey(const ValueKey('imports-row-school-feed')), findsOne);
    expect(find.textContaining('Family · ICS · 1 event'), findsOneWidget);
    expect(find.text('Shown'), findsOneWidget);
  });

  testWidgets('editing an imported calendar updates its settings', (
    tester,
  ) async {
    final imported = ImportedCalendar(
      id: 'training-feed',
      name: 'Training',
      provider: 'ics',
      color: kCatColors.first,
      url: 'https://example.com/training.ics',
      autoSync: false,
      events: [
        ImportedCalendarEvent(
          id: 'training-1',
          title: 'Imported training',
          date: todayIso(),
        ),
      ],
    );

    await pumpApp(
      tester,
      prefs: calendarPrefs(events: const [], importedCalendars: [imported]),
      landOnDefaultTab: true,
    );
    await openCalManage(tester, imports: true);

    await tester.tap(find.byKey(const ValueKey('imports-row-training-feed')));
    await tester.pumpAndSettle();
    expect(find.text('Edit imported calendar'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('imp-name')),
      'School training',
    );
    await tester.tap(find.byKey(const ValueKey('imp-visible')));
    await tester.pumpAndSettle();
    final newColor = kCatColors[2];
    final newHex = (newColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(
      6,
      '0',
    );
    await tester.tap(find.text('RGB / Hex'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('hex-color-input')),
      newHex,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();

    expect(find.text('School training'), findsWidgets);
    expect(find.text('Hidden'), findsOneWidget);
    final cal = thriveDebug.importedCalendars.single;
    expect(cal.color, newColor);
    expect(cal.visible, isFalse);

    await tester.tap(find.byKey(const ValueKey('studio-back')));
    await tester.pumpAndSettle();
    await goToCalendar(tester);
    await setCalView(tester, 'agenda');
    expect(find.text('Imported training'), findsNothing);
  });

  testWidgets("assigning a category to an imported calendar hands it that "
      "category's colour", (tester) async {
    final work = EventCategory(
      id: 'work',
      name: 'Work',
      color: kCatColors.first,
      icon: 'briefcase',
    );
    final imported = ImportedCalendar(
      id: 'training-feed',
      name: 'Training',
      provider: 'ics',
      color: kCatColors[1],
      url: 'https://example.com/training.ics',
      autoSync: false,
    );
    await pumpApp(
      tester,
      prefs: calendarPrefs(
        events: const [],
        categories: [work],
        importedCalendars: [imported],
      ),
      landOnDefaultTab: true,
    );
    await openCalManage(tester, imports: true);
    await tester.tap(find.byKey(const ValueKey('imports-row-training-feed')));
    await tester.pumpAndSettle();

    // Category chips carry the category's tint; picking one tags the feed
    // (the badge colour stays the feed's own, per the #326 design).
    await tester.ensureVisible(find.byKey(const ValueKey('imp-cat-work')));
    await tester.tap(
      find.byKey(const ValueKey('imp-cat-work')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(thriveDebug.importedCalendars.single.category, 'work');
    expect(find.textContaining('Work · ICS'), findsOneWidget);

    // Clearing the category ("None") untags it again.
    await tester.tap(find.byKey(const ValueKey('imports-row-training-feed')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('imp-cat-none')));
    await tester.tap(
      find.byKey(const ValueKey('imp-cat-none')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(thriveDebug.importedCalendars.single.category, isNull);
  });

  testWidgets('changing an imported calendar reminder persists it', (
    tester,
  ) async {
    final imported = ImportedCalendar(
      id: 'training-feed',
      name: 'Training',
      provider: 'ics',
      color: kCatColors.first,
      url: 'https://example.com/training.ics',
      autoSync: false,
      events: [
        ImportedCalendarEvent(
          id: 'training-1',
          title: 'Imported training',
          date: todayIso(),
        ),
      ],
    );

    await pumpApp(
      tester,
      prefs: calendarPrefs(events: const [], importedCalendars: [imported]),
      landOnDefaultTab: true,
    );
    await openCalManage(tester, imports: true);

    await tester.tap(find.byKey(const ValueKey('imports-row-training-feed')));
    await tester.pumpAndSettle();
    expect(find.text('DEFAULT REMINDER'), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('imp-reminder-1d')),
      find.byType(SingleChildScrollView).last,
      const Offset(-50, 0),
    );
    await tester.tap(
      find.byKey(const ValueKey('imp-reminder-1d')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();

    expect(thriveDebug.importedCalendars.single.reminder, '1d');
  });

  testWidgets(
    'every colour chooser uses the shared two-tab panel (#325/#326)',
    (tester) async {
      final imported = ImportedCalendar(
        id: 'training-feed',
        name: 'Training',
        provider: 'ics',
        color: kCatColors.first,
        url: 'https://example.com/training.ics',
        autoSync: false,
        events: const [],
      );
      await pumpApp(
        tester,
        prefs: calendarPrefs(events: const [], importedCalendars: [imported]),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);

      // Category studio: the shared two-tab colour panel.
      await openCalManage(tester);
      await tester.enterText(
        find.byKey(const ValueKey('list-add-input')),
        'Palettes',
      );
      await tester.tap(find.byKey(const ValueKey('list-add-button')));
      await tester.pumpAndSettle();
      expect(find.text('Palette'), findsWidgets);
      expect(find.text('RGB / Hex'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('studio-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio-back')));
      await tester.pumpAndSettle();

      // Imported-calendar studio: same shared panel.
      await openCalManage(tester, imports: true);
      await tester.tap(find.byKey(const ValueKey('imports-row-training-feed')));
      await tester.pumpAndSettle();
      expect(find.text('Palette'), findsWidgets);
      expect(find.text('RGB / Hex'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('studio-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio-back')));
      await tester.pumpAndSettle();

      // Event editor keeps the app's single two-tab colour panel.
      await goToCalendar(tester);
      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Picnic');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();
      await openMonthEvent(tester, 'Picnic');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await openTicketTray(tester, const ValueKey('ticket-colour'));
      expect(find.text('Palette'), findsOneWidget);
      await tester.tap(find.byType(AnimatedContainer).last);
      await tester.pump();
    },
  );

  testWidgets('assigning a category to a new event selects its chip', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    // Create the category via the Categories sub-screen first (#325
    // add-then-open: the add row creates it and opens its studio).
    await openCalManage(tester);
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'Family',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(find.text('Family'), findsWidgets);

    // Back out of the sub-screen, then create an event and pick the new
    // category.
    await tester.tap(find.byKey(const ValueKey('studio-back')));
    await tester.pumpAndSettle();
    await goToCalendar(tester);
    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Dinner');
    await tester.pump();
    await openTicketTray(tester, const ValueKey('ticket-category'));
    await tester.tap(find.text('Family').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Dinner'), findsWidgets);

    // The new category has no members assigned, so the event should have
    // no attendees either — it must not fall back to "me".
    await openMonthEvent(tester, 'Dinner');
    expect(find.text('ATTENDEES'), findsOneWidget);
    final attendeesWrap = tester.widget<Wrap>(find.byType(Wrap));
    expect(attendeesWrap.children, isEmpty);
  });

  testWidgets(
    'creating a new event with no category selected has no attendees',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Solo errand');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();

      await openMonthEvent(tester, 'Solo errand');
      expect(find.text('ATTENDEES'), findsOneWidget);
      final attendeesWrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(attendeesWrap.children, isEmpty);
    },
  );

  testWidgets(
    'a weekly recurring event: delete "this event only" keeps the series',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Standup');
      await tester.pump();
      await setTicketRepeat(tester);
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();

      await openMonthEvent(tester, 'Standup');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this event only'), findsOneWidget);
      expect(find.text('Delete this and future events'), findsOneWidget);
      expect(find.text('Delete the whole occurrence'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('recur-delete-one')));
      await tester.pumpAndSettle();

      // Today's occurrence is gone from Agenda...
      await setCalView(tester, 'agenda');
      expect(find.text('Standup'), findsNothing);

      // ...but the series continues: paging Month view forward a week
      // still shows it (Agenda is single-day now, so the next weekly
      // occurrence — 7 days out — isn't reachable from its week strip).
      await setCalView(tester, 'month');
      await tester.fling(
        find.byKey(const ValueKey('cal-pager-month')),
        const Offset(-700, 0),
        1200,
      );
      await tester.pumpAndSettle();
      expect(find.text('Standup'), findsWidgets);
    },
  );

  testWidgets('editing a recurring event asks which occurrences to save', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Practice');
    await tester.pump();
    await setTicketRepeat(tester);
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    await openMonthEvent(tester, 'Practice');
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Practice updated');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Save this event only'), findsOneWidget);
    expect(find.text('Save this and future events'), findsOneWidget);
    expect(find.text('Save the whole occurrence'), findsOneWidget);
  });

  testWidgets(
    'saving "this event only" on a recurring event adds a one-off exception',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Standup');
      await tester.pump();
      await setTicketRepeat(tester);
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();

      await openMonthEvent(tester, 'Standup');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Standup once');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recur-edit-one')));
      await tester.pumpAndSettle();

      // Today's single occurrence is the renamed exception...
      await setCalView(tester, 'agenda');
      expect(find.text('Standup once'), findsWidgets);
      expect(find.text('Standup'), findsNothing);

      // ...but the rest of the series keeps its original title (Agenda is
      // single-day now, so the next weekly occurrence — 7 days out — isn't
      // reachable from its week strip; check Month view instead).
      await setCalView(tester, 'month');
      await tester.fling(
        find.byKey(const ValueKey('cal-pager-month')),
        const Offset(-700, 0),
        1200,
      );
      await tester.pumpAndSettle();
      expect(find.text('Standup'), findsWidgets);
    },
  );

  testWidgets(
    'saving "this and future events" reschedules the rest of the series',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Practice');
      await tester.pump();
      await setTicketRepeat(tester);
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();

      await openMonthEvent(tester, 'Practice');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Practice v2');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recur-edit-future')));
      await tester.pumpAndSettle();

      await setCalView(tester, 'agenda');
      expect(find.text('Practice v2'), findsWidgets);
    },
  );

  testWidgets(
    'saving "the whole occurrence" updates every event in the series',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Yoga');
      await tester.pump();
      await setTicketRepeat(tester);
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();

      await openMonthEvent(tester, 'Yoga');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Yoga renamed');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recur-edit-all')));
      await tester.pumpAndSettle();

      await setCalView(tester, 'agenda');
      expect(find.text('Yoga renamed'), findsWidgets);
      expect(find.text('Yoga'), findsNothing);
    },
  );

  testWidgets(
    'deleting "this and future events" of a recurring series removes them',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Book club');
      await tester.pump();
      await setTicketRepeat(tester);
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();

      await openMonthEvent(tester, 'Book club');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recur-delete-future')));
      await tester.pumpAndSettle();

      await setCalView(tester, 'agenda');
      expect(find.text('Book club'), findsNothing);
    },
  );

  testWidgets(
    'deleting "the whole occurrence" of a recurring series removes it entirely',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Choir');
      await tester.pump();
      await setTicketRepeat(tester);
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();

      await openMonthEvent(tester, 'Choir');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recur-delete-all')));
      await tester.pumpAndSettle();

      await setCalView(tester, 'agenda');
      expect(find.text('Choir'), findsNothing);
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

    await openCalManage(tester, imports: true);
    expect(find.byKey(const ValueKey('list-add-input')), findsOneWidget);

    // Paste-a-link add flow (#326): importing opens the feed editor, where
    // the name can be set before saving.
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'https://example.com/team.ics',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    expect(find.text('Edit imported calendar'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('imp-name')),
      'Erik · Work',
    );
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();

    expect(find.text('Erik · Work'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('studio-back')));
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

      await openCalManage(tester, imports: true);
      await tester.enterText(
        find.byKey(const ValueKey('list-add-input')),
        'https://example.com/team.ics',
      );
      await tester.tap(find.byKey(const ValueKey('list-add-button')));
      await tester.pumpAndSettle();
      // The editor opens straight after importing — flip Location off there.
      await tester.tap(find.byKey(const ValueKey('imp-location')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('studio-back')));
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
      await openCalManage(tester, imports: true);
      await tester.enterText(
        find.byKey(const ValueKey('list-add-input')),
        'https://example.com/team.ics',
      );
      await tester.tap(find.byKey(const ValueKey('list-add-button')));
      await tester.pumpAndSettle();
      // The editor opens straight after importing; keep the defaults.
      await tester.tap(find.byKey(const ValueKey('studio-save')));
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
      await tapHubRow(tester, 'planning', 'more-calimports');
      final calId = thriveDebug.importedCalendars.single.id;
      await tester.tap(find.byKey(ValueKey('imp-chip-autosync-$calId')));
      await tester.pumpAndSettle();
      expect(find.text('✕ Auto-sync off'), findsOneWidget);

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
    await openCalManage(tester, imports: true);
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'https://example.com/team.ics',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();

    icsHttpGetOverride = (uri) async => http.Response('nope', 500);
    // The per-row "↻ Sync now" quick chip is keyed per calendar id.
    final calId = thriveDebug.importedCalendars.single.id;
    await tester.tap(find.byKey(ValueKey('imp-chip-sync-$calId')));
    await tester.pumpAndSettle();

    expect(find.text('Calendar link returned 500'), findsOneWidget);
    expect(thriveDebug.failedImportIds, contains(calId));
    expect(find.text('Failing'), findsWidgets);
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
      await openCalManage(tester, imports: true);
      await tester.enterText(
        find.byKey(const ValueKey('list-add-input')),
        'https://example.com/team.ics',
      );
      await tester.tap(find.byKey(const ValueKey('list-add-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();

      // Toggle both quick chips off from the list (post-import).
      final calId = thriveDebug.importedCalendars.single.id;
      await tester.tap(find.byKey(ValueKey('imp-chip-loc-$calId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('imp-chip-desc-$calId')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('studio-back')));
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
    await openCalManage(tester, imports: true);
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'https://example.com/team.ics',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('imp-name')), 'Fixtures');
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(find.text('Fixtures'), findsWidgets);

    // Removal lives inside the feed studio — its counting confirm states
    // the events disappear (#326).
    final calId = thriveDebug.importedCalendars.single.id;
    await tester.tap(find.byKey(ValueKey('imports-row-$calId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('disappear from the calendar'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
    await tester.pumpAndSettle();

    expect(thriveDebug.importedCalendars, isEmpty);
    expect(find.text('Fixtures'), findsNothing);
  });

  testWidgets(
    'editing a category renames it; deleting it clears it from events',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await openCalManage(tester);
      await tester.enterText(
        find.byKey(const ValueKey('list-add-input')),
        'Family',
      );
      await tester.tap(find.byKey(const ValueKey('list-add-button')));
      await tester.pumpAndSettle();
      // Add-then-open: rename inside the studio and save.
      expect(find.text('Edit category'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('badge-stage-name')),
        'Household',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();
      expect(find.text('Household'), findsWidgets);

      // Assign it to an event, then delete the category and confirm the
      // event survives without it.
      await tester.tap(find.byKey(const ValueKey('studio-back')));
      await tester.pumpAndSettle();
      await goToCalendar(tester);
      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Dinner');
      await tester.pump();
      await openTicketTray(tester, const ValueKey('ticket-category'));
      await tester.tap(find.text('Household').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();

      await openCalManage(tester);
      final catId = thriveDebug.eventCategories.single.id;
      await tester.tap(find.byKey(ValueKey('cats-row-$catId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio-delete')));
      await tester.pumpAndSettle();
      // The counting confirm spells out the events keep their times.
      expect(find.textContaining('keep their times'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
      await tester.pumpAndSettle();

      expect(thriveDebug.eventCategories, isEmpty);
      await tester.tap(find.byKey(const ValueKey('studio-back')));
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
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
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

  testWidgets(
    "a daily recurring event's occurrence appears on multiple days of the "
    'agenda week strip',
    (tester) async {
      // Dated at the Monday start of the current week (rather than "today",
      // via Quick-Add) so every one of the strip's 7 day-cells this week has
      // an occurrence, regardless of which weekday the suite happens to run
      // on — Agenda only ever shows one day at a time now, so multiple
      // occurrences are checked by tapping between strip cells instead of a
      // single all-dates-at-once list.
      final weekStart = startOfWeekForTest(todayIso());
      final weekEnd = addDaysForTest(weekStart, 6);
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: [
            CalendarEvent(
              id: 'daily1',
              title: 'Daily pill',
              date: weekStart,
              start: '09:00',
              end: '09:05',
              color: kEventColors.first,
              reminder: 'none',
              recur: 'daily',
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');

      await tester.tap(find.byKey(ValueKey('cal-week-strip-$weekStart')));
      await tester.pumpAndSettle();
      expect(find.text('Daily pill'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('cal-week-strip-$weekEnd')));
      await tester.pumpAndSettle();
      expect(find.text('Daily pill'), findsOneWidget);
    },
  );

  testWidgets('a monthly recurring event expands multiple occurrences', (
    tester,
  ) async {
    // Agenda is single-day now, so a monthly series' next occurrence (a
    // month out) isn't reachable from the week strip — verified via
    // Month view paging instead, which already covers cross-month
    // recurrence expansion.
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Monthly bill');
    await tester.pump();
    await setTicketRepeat(tester, cadence: 'monthly');
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Monthly bill'), findsWidgets);

    await tester.fling(
      find.byKey(const ValueKey('cal-pager-month')),
      const Offset(-700, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.text('Monthly bill'), findsWidgets);
  });

  testWidgets('a recurring event stops at its repeat end date', (tester) async {
    // Dated at the Monday start of the current week (rather than "today")
    // so the 3-day probe window below always falls within a single week's
    // agenda strip, regardless of which weekday the suite runs on.
    final weekStart = startOfWeekForTest(todayIso());
    final weekStartPlus1 = addDaysForTest(weekStart, 1);
    final weekStartPlus2 = addDaysForTest(weekStart, 2);
    await pumpApp(
      tester,
      prefs: calendarPrefs(
        events: [
          CalendarEvent(
            id: 'daily-limited',
            title: 'Limited daily',
            date: weekStart,
            endDate: weekStartPlus1,
            start: '09:00',
            end: '10:00',
            color: kEventColors.first,
            reminder: 'none',
            recur: 'daily',
          ),
        ],
      ),
      landOnDefaultTab: true,
    );
    await goToCalendar(tester);
    await setCalView(tester, 'agenda');

    await tester.tap(find.byKey(ValueKey('cal-week-strip-$weekStart')));
    await tester.pumpAndSettle();
    expect(find.text('Limited daily'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('cal-week-strip-$weekStartPlus1')));
    await tester.pumpAndSettle();
    expect(find.text('Limited daily'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('cal-week-strip-$weekStartPlus2')));
    await tester.pumpAndSettle();
    expect(find.text('Limited daily'), findsNothing);
  });

  test('custom weekly recurrence expands selected weekdays by interval', () {
    final ev = CalendarEvent(
      id: 'custom-weekly',
      title: 'Custom weekly',
      date: '2026-07-20',
      endDate: '2026-08-05',
      start: '09:00',
      end: '10:00',
      color: kEventColors.first,
      reminder: 'none',
      recur: 'custom',
      recurEvery: 2,
      recurUnit: 'week',
      recurWeekdays: const [1, 3],
    );

    expect(recurringEventDates(ev, '2026-07-20', '2026-08-10'), [
      '2026-07-20',
      '2026-07-22',
      '2026-08-03',
      '2026-08-05',
    ]);
  });

  testWidgets(
    'a member filter hides events not assigned to that member, a category '
    'filter hides events tagged with a different category',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await openCalManage(tester);
      await tester.enterText(
        find.byKey(const ValueKey('list-add-input')),
        'Work',
      );
      await tester.tap(find.byKey(const ValueKey('list-add-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio-back')));
      await tester.pumpAndSettle();

      await goToCalendar(tester);
      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Standup');
      await tester.pump();
      await openTicketTray(tester, const ValueKey('ticket-category'));
      await tester.tap(find.text('Work').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
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
      await tester.enterText(
        find.byKey(const ValueKey('list-add-input')),
        'Personal',
      );
      await tester.tap(find.byKey(const ValueKey('list-add-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio-back')));
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

  testWidgets(
    'a category can be created on a non-appt layer, and only shows up as an '
    'option for events on that same layer',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await openCalManage(tester);
      await tester.enterText(
        find.byKey(const ValueKey('list-add-input')),
        'Chores',
      );
      await tester.tap(find.byKey(const ValueKey('list-add-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cat-layer-task')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio-back')));
      await tester.pumpAndSettle();

      await goToCalendar(tester);
      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await openTicketTray(tester, const ValueKey('ticket-category'));
      expect(find.text('Chores'), findsNothing);

      await openTicketTray(tester, const ValueKey('ticket-tab-layer'));
      await tester.tap(find.byKey(const ValueKey('event-layer-task')));
      await tester.pumpAndSettle();
      await openTicketTray(tester, const ValueKey('ticket-category'));
      expect(find.text('Chores'), findsOneWidget);
    },
  );

  testWidgets('filter sheet shows all 3 layer toggles', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);
    await setCalView(tester, 'agenda');

    await openCalFilters(tester);
    expect(find.text('LAYERS'), findsOneWidget);
    for (final layer in kDefaultCalendarLayers()) {
      final chip = find.byKey(ValueKey('cal-filter-layer-${layer.id}'));
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: find.text(layer.label)),
        findsOneWidget,
      );
    }
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
    'filter sheet only lists categories belonging to a currently-enabled '
    'layer, and disabling a layer clears any of its category filters',
    (tester) async {
      final work = EventCategory(
        id: 'work',
        name: 'Work',
        color: kCatColors.first,
        icon: 'briefcase',
        layerId: 'appt',
      );
      final chores = EventCategory(
        id: 'chores',
        name: 'Chores',
        color: kCatColors[1],
        icon: 'home',
        layerId: 'task',
      );
      await pumpApp(
        tester,
        prefs: calendarPrefs(categories: [work, chores], events: const []),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');

      await openCalFilters(tester);
      expect(find.byKey(const ValueKey('cal-filter-cat-work')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cal-filter-cat-chores')),
        findsOneWidget,
      );

      // Disabling the 'task' layer hides its category from the list.
      await tester.tap(find.byKey(const ValueKey('cal-filter-layer-task')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cal-filter-cat-work')), findsOneWidget);
      expect(find.byKey(const ValueKey('cal-filter-cat-chores')), findsNothing);
    },
  );

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

  testWidgets(
    'multi-day event renders as a month span and agenda-style detail',
    (tester) async {
      // Pin "today" to mid-month so the 3-day span stays within one month grid
      // and isn't also drawn in the adjacent-month overflow row (#flaky).
      debugNowOverride = () => DateTime(2026, 6, 15);
      addTearDown(() => debugNowOverride = null);
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

      final row = find.byKey(ValueKey('event-span1-${todayIso()}'));
      expect(row, findsOneWidget);
      final container = tester.widget<Container>(
        find.descendant(of: row, matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, kEventColors[3]);
    },
  );

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
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    await openMonthEvent(tester, 'Original title');
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Updated title');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
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
    await openCalManage(tester, imports: true);
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'https://example.com/team.ics',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();

    // The per-row 👁/🚫 quick chip flips visibility.
    final calId = thriveDebug.importedCalendars.single.id;
    await tester.tap(find.byKey(ValueKey('imp-chip-vis-$calId')));
    await tester.pumpAndSettle();
    expect(find.text('Hidden'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('studio-back')));
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
    await openCalManage(tester, imports: true);
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'https://example.com/team.ics',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();

    icsHttpGetOverride = (uri) async => http.Response(
      'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:1\r\nSUMMARY:v1\r\n'
      'DTSTART:${today}T100000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n'
      'BEGIN:VEVENT\r\nUID:2\r\nSUMMARY:v2\r\n'
      'DTSTART:${today}T110000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
      200,
    );
    final calId = thriveDebug.importedCalendars.single.id;
    await tester.tap(find.byKey(ValueKey('imp-chip-sync-$calId')));
    await tester.pumpAndSettle();

    expect(find.text('Calendar synced (2 events)'), findsOneWidget);
    expect(find.textContaining('2 events · Synced just now'), findsOneWidget);
  });

  // Note: coverage for tasks with a due date appearing on the calendar (and
  // being read-only there) lives in the
  // "tasks with a due date appear in the calendar (#199)" group below.

  test('IcsImportException.toString() returns its message', () {
    expect(IcsImportException('boom').toString(), 'boom');
  });

  test(
    'contrastOn picks dark text for light colours, white for dark colours',
    () {
      // Pale yellow: light enough that white text would be unreadable.
      expect(contrastOn(const Color(0xfffde047)), B.ink);
      // Deep teal/navy: dark enough that white text stays readable.
      expect(contrastOn(const Color(0xff0f172a)), Colors.white);
      expect(contrastOn(const Color(0xff0E9A8D)), Colors.white);
    },
  );

  test('eurBare strips the euro glyph + nbsp from eur()', () {
    expect(eurBare(1234.5), '1.234,50');
    expect(eurBare(-5, cents: false), '\u22125');
  });

  group('to-do/content layer events on the calendar', () {
    testWidgets('shows a to-do-layer event in Month view coloured by its '
        'assignee', (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: [
            CalendarEvent(
              id: 't1',
              title: 'Take out bins',
              allDay: true,
              date: today,
              color: kCatColors.first,
              attendees: const ['erik'],
              layerId: 'task',
              todo: true,
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);

      final bar = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('cal-bar-t1-'),
      );
      expect(bar, findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.text('Take out bins')),
        findsOneWidget,
      );
      final usesAssigneeColor = tester
          .widgetList<Container>(
            find.descendant(of: bar, matching: find.byType(Container)),
          )
          .any(
            (container) =>
                container.decoration is BoxDecoration &&
                (container.decoration! as BoxDecoration).color ==
                    kMemberColors[1],
          );
      expect(usesAssigneeColor, isTrue);
    });

    testWidgets(
      'a completed to-do-layer event stays visible on the calendar with a '
      'done (strikethrough) treatment, instead of disappearing',
      (tester) async {
        final today = todayIso();
        await pumpApp(
          tester,
          prefs: calendarPrefs(
            events: [
              CalendarEvent(
                id: 't1',
                title: 'Done already',
                allDay: true,
                date: today,
                color: kCatColors.first,
                attendees: const ['erik'],
                layerId: 'task',
                todo: true,
                done: true,
              ),
            ],
          ),
          landOnDefaultTab: true,
        );
        await goToCalendar(tester);
        await setCalView(tester, 'agenda');

        expect(find.text('Done already'), findsOneWidget);
        final titleWidget = tester.widget<Text>(find.text('Done already'));
        expect(titleWidget.style?.decoration, TextDecoration.lineThrough);
      },
    );

    testWidgets('tapping a to-do-layer occurrence opens the same editable '
        'event view as an appointment', (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: [
            CalendarEvent(
              id: 't1',
              title: 'Take out bins',
              allDay: true,
              date: today,
              color: kCatColors.first,
              attendees: const ['erik'],
              layerId: 'task',
              todo: true,
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);
      await openMonthEvent(tester, 'Take out bins');

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('a content-layer occurrence in the day-detail sheet uses the '
        'agenda row style without a checkbox', (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: [
            CalendarEvent(
              id: 'c1',
              title: 'Film reel',
              allDay: true,
              date: today,
              color: kCatColors.first,
              attendees: const ['erik'],
              layerId: 'content',
              recur: 'weekly',
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);

      await tester.tap(find.byKey(ValueKey('cal-day-$today')));
      await tester.pumpAndSettle();

      final cardTitle = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Film reel' && w.style?.fontSize == 13.5,
      );
      expect(cardTitle, findsOneWidget);
      expect(find.byKey(ValueKey('event-c1-$today')), findsOneWidget);
      expect(find.byKey(ValueKey('event-check-c1-$today')), findsNothing);
    });

    testWidgets('a to-do can be completed from the Month day-detail sheet', (
      tester,
    ) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: [
            CalendarEvent(
              id: 't1',
              title: 'Take out bins',
              allDay: true,
              date: today,
              color: kCatColors.first,
              attendees: const ['erik'],
              layerId: 'task',
              todo: true,
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);

      await tester.tap(find.byKey(ValueKey('cal-day-$today')));
      await tester.pumpAndSettle();

      final row = find.byKey(ValueKey('event-t1-$today'));
      final checkbox = find.byKey(ValueKey('event-check-t1-$today'));
      expect(row, findsOneWidget);
      expect(checkbox, findsOneWidget);

      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      expect(thriveDebug.events.singleWhere((e) => e.id == 't1').done, isTrue);
      expect(row, findsOneWidget);
      final sheetTitle = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data == 'Take out bins' &&
              w.style?.fontSize == 13.5,
        ),
      );
      expect(sheetTitle.style?.decoration, TextDecoration.lineThrough);
    });
  });

  group('calendar layer toggles + task/content occurrence checkboxes', () {
    testWidgets('filter sheet layer toggles independently hide '
        'appointment/task/content occurrences, and the last enabled layer '
        'cannot be disabled', (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: [
            CalendarEvent(
              id: 'e1',
              title: 'Team sync',
              allDay: true,
              date: today,
              color: kCatColors.first,
            ),
            CalendarEvent(
              id: 't1',
              title: 'Take out bins',
              allDay: true,
              date: today,
              color: kCatColors[1],
              attendees: const ['erik'],
              layerId: 'task',
              todo: true,
            ),
            CalendarEvent(
              id: 'c1',
              title: 'Film reel',
              allDay: true,
              date: today,
              color: kCatColors[2],
              attendees: const ['erik'],
              layerId: 'content',
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);

      expect(find.text('Team sync'), findsOneWidget);
      expect(find.text('Take out bins'), findsOneWidget);
      expect(find.text('Film reel'), findsOneWidget);

      // Layer toggles now live in the filter sheet, not header chips.
      await openCalFilters(tester);
      expect(find.text('LAYERS'), findsOneWidget);

      // Turning off the to-dos layer hides only the chore occurrence.
      await tester.tap(find.byKey(const ValueKey('cal-filter-layer-task')));
      await tester.pumpAndSettle();
      expect(find.text('Take out bins'), findsNothing);
      expect(find.text('Team sync'), findsOneWidget);
      expect(find.text('Film reel'), findsOneWidget);

      // Turning off content too hides that occurrence, leaving only the
      // appointment — the only remaining enabled layer.
      await tester.tap(find.byKey(const ValueKey('cal-filter-layer-content')));
      await tester.pumpAndSettle();
      expect(find.text('Film reel'), findsNothing);
      expect(find.text('Team sync'), findsOneWidget);

      // Tapping the last remaining enabled layer's chip must be ignored —
      // at least one layer always stays visible.
      await tester.tap(find.byKey(const ValueKey('cal-filter-layer-appt')));
      await tester.pumpAndSettle();
      expect(find.text('Team sync'), findsOneWidget);

      // Re-enabling brings the hidden occurrences back.
      await tester.tap(find.byKey(const ValueKey('cal-filter-layer-task')));
      await tester.tap(find.byKey(const ValueKey('cal-filter-layer-content')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show all events'));
      await tester.pumpAndSettle();
      expect(find.text('Take out bins'), findsOneWidget);
      expect(find.text('Film reel'), findsOneWidget);
    });

    testWidgets(
      "checking a non-recurring to-do-layer event's box marks it done and "
      'shows it with a done treatment, without removing it from the '
      'calendar',
      (tester) async {
        final today = todayIso();
        await pumpApp(
          tester,
          prefs: calendarPrefs(
            events: [
              CalendarEvent(
                id: 't1',
                title: 'Take out bins',
                allDay: true,
                date: today,
                color: kCatColors.first,
                attendees: const ['erik'],
                layerId: 'task',
                todo: true,
              ),
            ],
          ),
          landOnDefaultTab: true,
        );
        await goToCalendar(tester);

        Finder monthBar() => find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('cal-bar-t1-'),
        );
        final checkbox = find.byKey(ValueKey('cal-check-t1-$today'));

        expect(monthBar(), findsOneWidget);
        expect(checkbox, findsOneWidget);
        expect(
          find.descendant(of: monthBar(), matching: find.text('Take out bins')),
          findsOneWidget,
        );
        await tester.tap(checkbox);
        await tester.pumpAndSettle();

        expect(monthBar(), findsOneWidget);
        expect(checkbox, findsOneWidget);
        final titleWidget = tester.widget<Text>(find.text('Take out bins'));
        expect(titleWidget.style?.decoration, TextDecoration.lineThrough);
      },
    );

    testWidgets(
      "checking one occurrence of a recurring to-do-layer event's box only "
      'completes that date — a later occurrence stays visible, visible '
      'count unchanged, and untouched (not done)',
      (tester) async {
        // Pin "today" to mid-month so today+7 stays in the same month grid and
        // the later occurrence is visible rather than in the next month (#flaky).
        debugNowOverride = () => DateTime(2026, 6, 15);
        addTearDown(() => debugNowOverride = null);
        final today = todayIso();
        final future = addDaysForTest(today, 7);
        await pumpApp(
          tester,
          prefs: calendarPrefs(
            events: [
              CalendarEvent(
                id: 't1',
                title: 'Water plants',
                allDay: true,
                date: today,
                color: kCatColors.first,
                attendees: const ['erik'],
                layerId: 'task',
                todo: true,
                recur: 'weekly',
              ),
            ],
          ),
          landOnDefaultTab: true,
        );
        await goToCalendar(tester);

        final todayCheckbox = ValueKey('cal-check-t1-$today');
        final futureCheckbox = ValueKey('cal-check-t1-$future');
        expect(find.byKey(todayCheckbox), findsOneWidget);
        expect(find.byKey(futureCheckbox), findsOneWidget);
        final countBefore = find.text('Water plants').evaluate().length;

        await tester.tap(find.byKey(todayCheckbox));
        await tester.pumpAndSettle();

        // Both occurrences stay on the calendar (done occurrences are
        // never removed) — only today's picks up the done/strikethrough
        // treatment, the later one is untouched.
        expect(find.byKey(todayCheckbox), findsOneWidget);
        expect(find.byKey(futureCheckbox), findsOneWidget);
        expect(find.text('Water plants').evaluate().length, countBefore);

        final titles = tester.widgetList<Text>(find.text('Water plants'));
        final decorations = titles.map((t) => t.style?.decoration).toList();
        expect(decorations, contains(TextDecoration.lineThrough));
        expect(decorations, contains(TextDecoration.none));
      },
    );

    testWidgets(
      'content-layer occurrences render with the same uniform solid-colour '
      'Month-view bar as any other layer, no dashed outline (calendar '
      'layers uniform rendering)',
      (tester) async {
        final today = todayIso();
        await pumpApp(
          tester,
          prefs: calendarPrefs(
            events: [
              CalendarEvent(
                id: 'c1',
                title: 'Film reel',
                allDay: true,
                date: today,
                color: kCatColors[2],
                attendees: const ['erik'],
                layerId: 'content',
              ),
            ],
          ),
          landOnDefaultTab: true,
        );
        await goToCalendar(tester);

        final bar = find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('cal-bar-c1-'),
        );
        expect(bar, findsOneWidget);
        final hasDashedOutline = tester
            .widgetList<Container>(
              find.descendant(of: bar, matching: find.byType(Container)),
            )
            .any(
              (c) =>
                  c.foregroundDecoration != null &&
                  c.foregroundDecoration!.runtimeType.toString().contains(
                    'Dashed',
                  ),
            );
        expect(hasDashedOutline, isFalse);
        final usesSolidFill = tester
            .widgetList<Container>(
              find.descendant(of: bar, matching: find.byType(Container)),
            )
            .any(
              (c) =>
                  c.decoration is BoxDecoration &&
                  (c.decoration! as BoxDecoration).color == kCatColors[2],
            );
        expect(usesSolidFill, isTrue);
      },
    );

    testWidgets('agenda view groups the day by enabled layers and keeps '
        'uniform row styling inside each layer', (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: [
            CalendarEvent(
              id: 'e1',
              title: 'Team sync',
              allDay: false,
              date: today,
              start: '09:00',
              end: '09:30',
              color: kCatColors.first,
              attendees: const ['erik'],
            ),
            CalendarEvent(
              id: 't1',
              title: 'Take out bins',
              allDay: false,
              date: today,
              start: '10:00',
              end: '10:15',
              color: kCatColors[1],
              attendees: const ['erik'],
              layerId: 'task',
            ),
            CalendarEvent(
              id: 'c1',
              title: 'Film reel',
              allDay: false,
              date: today,
              start: '11:00',
              end: '12:00',
              color: kCatColors[2],
              attendees: const ['erik'],
              layerId: 'content',
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');

      expect(
        find.byKey(ValueKey('agenda-layer-header-appt-$today')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('agenda-layer-header-task-$today')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('agenda-layer-header-content-$today')),
        findsOneWidget,
      );
      expect(find.text('Appointments'), findsOneWidget);
      expect(find.text('To-Dos'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      expect(find.byKey(ValueKey('agenda-appt-e1-$today')), findsOneWidget);
      expect(find.byKey(ValueKey('agenda-appt-t1-$today')), findsOneWidget);
      expect(find.byKey(ValueKey('agenda-appt-c1-$today')), findsOneWidget);

      final appointmentsY = tester
          .getTopLeft(find.byKey(ValueKey('agenda-layer-header-appt-$today')))
          .dy;
      final taskY = tester
          .getTopLeft(find.byKey(ValueKey('agenda-layer-header-task-$today')))
          .dy;
      final contentY = tester
          .getTopLeft(
            find.byKey(ValueKey('agenda-layer-header-content-$today')),
          )
          .dy;
      expect(appointmentsY, lessThan(taskY));
      expect(taskY, lessThan(contentY));
    });

    testWidgets('agenda enabled layers show an empty state when that layer '
        'has no events for the selected day', (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          layerFilter: const ['appt', 'task'],
          events: [
            CalendarEvent(
              id: 'e1',
              title: 'Team sync',
              allDay: true,
              date: today,
              color: kCatColors.first,
              attendees: const ['erik'],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');

      expect(find.byKey(ValueKey('agenda-appt-e1-$today')), findsOneWidget);
      expect(
        find.byKey(ValueKey('agenda-layer-empty-task-$today')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('agenda-layer-empty-content-$today')),
        findsNothing,
      );
      expect(find.text('No events yet'), findsOneWidget);
      expect(
        find.byKey(ValueKey('agenda-layer-header-content-$today')),
        findsNothing,
      );
    });

    testWidgets(
      "an appointment row in agenda falls back to the member's colour when "
      'the event colour is still default',
      (tester) async {
        final today = todayIso();
        await pumpApp(
          tester,
          prefs: calendarPrefs(
            events: [
              CalendarEvent(
                id: 'e1',
                title: 'Team sync',
                allDay: true,
                date: today,
                color: kCatColors.first,
                attendees: const ['erik'],
              ),
            ],
          ),
          landOnDefaultTab: true,
        );
        await goToCalendar(tester);
        await setCalView(tester, 'agenda');

        final row = find.byKey(ValueKey('agenda-appt-e1-$today'));
        expect(row, findsOneWidget);
        final container = tester.widget<Container>(
          find.descendant(of: row, matching: find.byType(Container)).first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, kMemberColors[1]);
        expect(decoration.boxShadow?.isNotEmpty ?? false, isFalse);
        expect(
          find.byKey(ValueKey('agenda-attendees-e1-$today')),
          findsOneWidget,
        );
        expect(find.text('Erik Janssen'), findsNothing);
      },
    );

    testWidgets('agenda event text contrasts against the event colour', (
      tester,
    ) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: [
            CalendarEvent(
              id: 'e1',
              title: 'Bright event',
              allDay: true,
              date: today,
              color: const Color(0xfffde047),
              attendees: const [],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');

      final title = tester.widget<Text>(find.text('Bright event'));
      expect(title.style?.color, B.ink);
    });

    testWidgets('agenda event colour wins over assigned person colour', (
      tester,
    ) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: [
            CalendarEvent(
              id: 'e1',
              title: 'Blue event',
              allDay: true,
              date: today,
              color: kCatColors[2],
              attendees: const ['erik'],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');

      final row = find.byKey(ValueKey('agenda-appt-e1-$today'));
      final container = tester.widget<Container>(
        find.descendant(of: row, matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, kCatColors[2]);
    });

    testWidgets(
      'a content-layer row in agenda uses the same uniform appointment-row '
      'style as any other normal event, without a done checkbox',
      (tester) async {
        final today = todayIso();
        await pumpApp(
          tester,
          prefs: calendarPrefs(
            events: [
              CalendarEvent(
                id: 'c1',
                title: 'Film reel',
                allDay: true,
                date: today,
                color: kCatColors[2],
                attendees: const ['erik'],
                layerId: 'content',
              ),
            ],
          ),
          landOnDefaultTab: true,
        );
        await goToCalendar(tester);
        await setCalView(tester, 'agenda');

        final row = find.byKey(ValueKey('agenda-appt-c1-$today'));
        expect(row, findsOneWidget);
        final container = tester.widget<Container>(
          find.descendant(of: row, matching: find.byType(Container)).first,
        );
        expect(container.foregroundDecoration, isNull);
        expect(find.byKey(ValueKey('event-check-c1-$today')), findsNothing);
        expect(
          find.byKey(ValueKey('agenda-attendees-c1-$today')),
          findsOneWidget,
        );
      },
    );

    testWidgets('a categorized event row in agenda shows its category', (
      tester,
    ) async {
      final today = todayIso();
      final activity = EventCategory(
        id: 'activity',
        name: 'Activity',
        color: kCatColors.last,
        icon: 'star',
      );
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          categories: [activity],
          events: [
            CalendarEvent(
              id: 'e1',
              title: 'Football',
              allDay: true,
              date: today,
              category: activity.id,
              color: kCatColors.first,
              attendees: const ['me', 'erik'],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');

      expect(find.byKey(ValueKey('agenda-appt-e1-$today')), findsOneWidget);
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(ValueKey('agenda-appt-e1-$today')),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, activity.color);
      expect(
        find.byKey(ValueKey('agenda-title-category-e1-$today')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('agenda-attendees-e1-$today')),
        findsOneWidget,
      );
      expect(find.text('Eva Janssen'), findsNothing);
      expect(find.text('Erik Janssen'), findsNothing);
      expect(find.byKey(ValueKey('event-check-e1-$today')), findsNothing);
    });

    testWidgets('the Agenda week strip renders 7 cells for the Mon-Sun week '
        'containing the selected day', (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');

      final weekStart = startOfWeekForTest(todayIso());
      for (var i = 0; i < 7; i++) {
        expect(
          find.byKey(
            ValueKey('cal-week-strip-${addDaysForTest(weekStart, i)}'),
          ),
          findsOneWidget,
        );
      }
      // No 8th cell leaks in from an adjacent week.
      expect(
        find.byKey(ValueKey('cal-week-strip-${addDaysForTest(weekStart, 7)}')),
        findsNothing,
      );
    });

    testWidgets('tapping a non-selected week-strip cell switches which day\'s '
        'sections render', (tester) async {
      final today = todayIso();
      final tomorrow = addDaysForTest(today, 1);
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: [
            CalendarEvent(
              id: 'today-only',
              title: 'Today only appt',
              date: today,
              color: kCatColors.first,
              attendees: const ['erik'],
            ),
            CalendarEvent(
              id: 'tomorrow-only',
              title: 'Tomorrow only appt',
              date: tomorrow,
              color: kCatColors.first,
              attendees: const ['erik'],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');

      expect(find.text('Today only appt'), findsOneWidget);
      expect(find.text('Tomorrow only appt'), findsNothing);

      await tester.tap(find.byKey(ValueKey('cal-week-strip-$tomorrow')));
      await tester.pumpAndSettle();

      expect(find.text('Today only appt'), findsNothing);
      expect(find.text('Tomorrow only appt'), findsOneWidget);
    });

    testWidgets(
      "a week-strip day's dot only shows for a layer with an occurrence "
      'that day AND enabled in layerFilter',
      (tester) async {
        final today = todayIso();
        await pumpApp(
          tester,
          prefs: calendarPrefs(
            events: [
              CalendarEvent(
                id: 'e1',
                title: 'Team sync',
                allDay: true,
                date: today,
                color: kCatColors.first,
                attendees: const ['erik'],
              ),
            ],
          ),
          landOnDefaultTab: true,
        );
        await goToCalendar(tester);
        await setCalView(tester, 'agenda');

        Row dotsRowOf(String iso) => tester.widget<Row>(
          find.descendant(
            of: find.byKey(ValueKey('cal-week-strip-$iso')),
            matching: find.byWidgetPredicate(
              (w) => w is Row && w.mainAxisSize == MainAxisSize.min,
            ),
          ),
        );

        // The appt layer has an occurrence today, so its dot shows.
        expect(
          find.byKey(ValueKey('cal-week-strip-dot-$today-0')),
          findsOneWidget,
        );
        expect(dotsRowOf(today).children.length, 1);

        // Disabling the appt layer hides that day's dot even though
        // the occurrence still exists.
        await openCalFilters(tester);
        await tester.tap(find.byKey(const ValueKey('cal-filter-layer-task')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cal-filter-layer-appt')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Show all events'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(ValueKey('cal-week-strip-dot-$today-0')),
          findsNothing,
        );
        expect(dotsRowOf(today).children, isEmpty);
      },
    );

    testWidgets(
      'Calendar layers settings: add a custom layer, edit it, use it for '
      'a new event, reorder it, then delete it from its studio '
      '(reassigning the event back to To-Dos)',
      (tester) async {
        final today = todayIso();
        await pumpApp(tester, landOnDefaultTab: true);

        await tester.tap(find.byKey(const ValueKey('nav-more')));
        await tester.pumpAndSettle();
        await tapHubRow(tester, 'planning', 'more-callayers');

        expect(find.byKey(const ValueKey('layers-row-appt')), findsOneWidget);

        // Add by label (#327): stays on the list and toasts.
        await tester.enterText(
          find.byKey(const ValueKey('list-add-input')),
          'Workouts',
        );
        await tester.tap(find.byKey(const ValueKey('list-add-button')));
        await tester.pumpAndSettle();
        expect(find.text('Workouts'), findsOneWidget);
        final layerId = thriveDebug.calendarLayers
            .singleWhere((l) => l.label == 'Workouts')
            .id;
        expect(thriveDebug.layerFilter, contains(layerId));

        // Hold-and-drag reorder: "Workouts" was appended last; dragging it
        // up one slot moves it before "Content" in the shared order.
        await tester.ensureVisible(find.byKey(ValueKey('layers-row-$layerId')));
        final rowFinder = find.byKey(ValueKey('layers-row-$layerId'));
        final gesture = await tester.startGesture(tester.getCenter(rowFinder));
        await tester.pump(const Duration(milliseconds: 400));
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(0, -10));
          await tester.pump(const Duration(milliseconds: 30));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          thriveDebug.calendarLayers
              .map((l) => l.label)
              .toList()
              .indexOf('Workouts'),
          lessThan(3),
        );

        // Disable then re-enable it via its row toggle.
        await tester.tap(find.byKey(ValueKey('layers-toggle-$layerId')));
        await tester.pumpAndSettle();
        expect(thriveDebug.layerFilter, isNot(contains(layerId)));
        await tester.tap(find.byKey(ValueKey('layers-toggle-$layerId')));
        await tester.pumpAndSettle();
        expect(thriveDebug.layerFilter, contains(layerId));

        // Tapping the row opens its studio, pre-filled — rename and save.
        await tester.tap(find.byKey(ValueKey('layers-row-$layerId')));
        await tester.pumpAndSettle();
        expect(find.text('Edit layer'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('badge-stage-name')),
          'Fitness',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('studio-save')));
        await tester.pumpAndSettle();
        expect(find.text('Fitness'), findsOneWidget);
        expect(find.text('Workouts'), findsNothing);

        // Back out of the sub-screen before switching tabs.
        await tester.tap(find.byKey(const ValueKey('studio-back')));
        await tester.pumpAndSettle();

        // Create a calendar event directly on the renamed "Fitness" layer
        // via the event editor's layer picker (to-do/content items are
        // just CalendarEvents tagged with a layerId — there's no separate
        // Lists-driven creation flow any more).
        await goToCalendar(tester);
        await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Gym session');
        await tester.pump();
        final fitnessChip = find.text('Fitness');
        await tester.ensureVisible(fitnessChip);
        await tester.tap(fitnessChip);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
        await tester.pumpAndSettle();

        await setCalView(tester, 'agenda');
        expect(find.text('Gym session'), findsOneWidget);
        // A custom-layer normal event renders in its layer section without
        // a done checkbox.
        expect(find.text('Fitness'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('event-check-'),
          ),
          findsNothing,
        );

        // Deleting the layer from its studio (#327) reassigns "Gym session"
        // back to To-Dos instead of leaving it pointed at a deleted layer.
        await tester.tap(find.byKey(const ValueKey('nav-more')));
        await tester.pumpAndSettle();
        await tapHubRow(tester, 'planning', 'more-callayers');
        final fitnessLayerId = thriveDebug.calendarLayers
            .singleWhere((layer) => layer.label == 'Fitness')
            .id;
        final fitnessRow = find.byKey(ValueKey('layers-row-$fitnessLayerId'));
        await tester.ensureVisible(fitnessRow);
        await tester.tap(fitnessRow);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('studio-delete')));
        await tester.pumpAndSettle();
        // The counting confirm counts the event it takes with it.
        expect(find.textContaining('1 event'), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
        await tester.pumpAndSettle();
        expect(fitnessRow, findsNothing);

        // Back out of the sub-screen before switching tabs.
        await tester.tap(find.byKey(const ValueKey('studio-back')));
        await tester.pumpAndSettle();

        await goToCalendar(tester);
        await setCalView(tester, 'agenda');
        // The deleted custom layer no longer has a section; the reassigned
        // occurrence renders in the To-Dos section with the uniform agenda
        // row style.
        expect(find.text('Gym session'), findsOneWidget);
        expect(find.text('Fitness'), findsNothing);
        expect(
          find.byKey(ValueKey('agenda-layer-header-task-$today')),
          findsOneWidget,
        );
      },
    );

    testWidgets('default calendar layers delete down to the min-1 guard '
        '(#327)', (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);

      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();
      await tapHubRow(tester, 'planning', 'more-callayers');

      // The first two default layers delete like any custom layer.
      for (final id in ['appt', 'task']) {
        final row = find.byKey(ValueKey('layers-row-$id'));
        expect(row, findsOneWidget);
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('studio-delete')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
        await tester.pumpAndSettle();

        expect(row, findsNothing);
        expect(
          thriveDebug.calendarLayers.any((layer) => layer.id == id),
          isFalse,
        );
        expect(thriveDebug.layerFilter.contains(id), isFalse);
      }

      // The last remaining layer's studio has NO delete link (min-1) and
      // its visibility toggle refuses to switch the last layer off.
      await tester.tap(find.byKey(const ValueKey('layers-toggle-content')));
      await tester.pumpAndSettle();
      expect(thriveDebug.layerFilter, contains('content'));
      expect(find.text('At least one layer stays on'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('layers-row-content')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('studio-delete')), findsNothing);
    });

    testWidgets('creating the very first layer retroactively reassigns every '
        'pre-existing event/category (simulates a family whose data predates '
        'layers entirely) instead of leaving them orphaned', (tester) async {
      await pumpApp(tester, signedIn: false);

      // Simulate a family that upgraded straight into a workspace with NO
      // calendar layers, but whose events/categories already carry the
      // model's implicit `'appt'` layerId fallback (i.e. they never
      // explicitly chose a layer, because layers didn't exist yet).
      thriveDebug.restoreV4({
        'familyId': 'fam_main',
        'families': [
          {'id': 'fam_main', 'name': 'Test family', 'members': []},
        ],
        'workspaces': {
          'fam_main': {
            'accounts': [],
            'cats': [],
            'data': {},
            'calendarLayers': [],
            'events': [
              {'id': 'ev1', 'title': 'Legacy event', 'date': todayIso()},
            ],
            'eventCategories': [
              {
                'id': 'cat1',
                'name': 'Legacy category',
                'color': kMemberColors[0].toARGB32(),
                'icon': 'briefcase',
              },
            ],
          },
        },
      });
      await tester.pump();

      expect(thriveDebug.calendarLayers, isEmpty);
      expect(thriveDebug.events.single.layerId, 'appt');
      expect(thriveDebug.eventCategories.single.layerId, 'appt');

      thriveDebug.addCalendarLayer(
        label: 'My first layer',
        icon: 'star',
        color: kMemberColors[1],
      );

      expect(thriveDebug.calendarLayers, hasLength(1));
      final newLayerId = thriveDebug.calendarLayers.single.id;
      expect(thriveDebug.events.single.layerId, newLayerId);
      expect(thriveDebug.eventCategories.single.layerId, newLayerId);
    });

    testWidgets(
      'creating a SECOND layer never retroactively reassigns anything '
      '(the bulk reassignment only fires the very first time)',
      (tester) async {
        await pumpApp(tester, landOnDefaultTab: true);
        // The default fixture already seeds the 3 built-in layers, so
        // adding another one here must be a pure append.
        final before = thriveDebug.events.map((e) => e.layerId).toList();

        thriveDebug.addCalendarLayer(
          label: 'Extra layer',
          icon: 'star',
          color: kMemberColors[1],
        );

        expect(thriveDebug.events.map((e) => e.layerId).toList(), before);
      },
    );
  });
}

String _isoNow() => todayIso();
