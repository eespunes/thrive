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
Future<void> openCalManage(WidgetTester tester, {bool imports = false}) async {
  await tester.tap(find.byKey(const ValueKey('nav-more')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(ValueKey(imports ? 'more-calimports' : 'more-calmanage')),
  );
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

String addMonthsForTest(String iso, int n) {
  final d = DateTime.parse('${iso}T00:00:00Z');
  final total = d.month - 1 + n;
  final year = d.year + total ~/ 12;
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
      'member': kMemberColors[1],
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
      expect(find.text(shortDateForTest(todayIso())), findsOneWidget);
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
      // behind the sheet, so match on the sheet's larger event-card title
      // style to check what's actually listed inside the day-detail sheet.
      bool isCardTitle(Widget w) => w is Text && w.style?.fontSize == 13.5;
      expect(
        find.byWidgetPredicate(
          (w) => isCardTitle(w) && (w as Text).data == 'Other day event',
        ),
        findsOneWidget,
      );
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

  testWidgets('event time picker opens in keyboard input mode', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-time-start')));
    await tester.pumpAndSettle();

    expect(find.text('Hour'), findsOneWidget);
    expect(find.text('Minute'), findsOneWidget);
  });

  testWidgets('event editor offers all reminder options', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();

    expect(find.text('No reminder'), findsOneWidget);
    expect(find.text('On time'), findsOneWidget);
    expect(find.text('5 min before'), findsOneWidget);
    expect(find.text('15 min before'), findsOneWidget);
    expect(find.text('30 min before'), findsOneWidget);
    expect(find.text('1 hour before'), findsOneWidget);
    expect(find.text('2 hours before'), findsOneWidget);
    expect(find.text('1 day before'), findsOneWidget);
    expect(find.text('2 days before'), findsOneWidget);
  });

  testWidgets(
    'event editor shows optional repeat end date for recurring events',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      expect(find.text('REPEAT ENDS'), findsNothing);

      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();

      expect(find.text('REPEAT ENDS'), findsOneWidget);
      final repeatEnd = find.byKey(const ValueKey('event-repeat-end-date'));
      expect(repeatEnd, findsOneWidget);
      expect(
        find.descendant(of: repeatEnd, matching: find.text('Never')),
        findsOneWidget,
      );
    },
  );

  testWidgets('event editor shows custom repeat controls', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Custom'));
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    expect(find.text('EVERY'), findsOneWidget);
    expect(find.text('ON DAYS'), findsOneWidget);
    expect(find.text('Days'), findsOneWidget);
    expect(find.text('Weeks'), findsOneWidget);
    expect(find.text('Months'), findsOneWidget);
    expect(find.text('Years'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('event-custom-weekday-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('event-custom-every-2')));
    await tester.tap(find.text('Months'));
    await tester.pumpAndSettle();
    expect(find.text('ON DAYS'), findsNothing);
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

  testWidgets('creating a category from the event editor lands on '
      'Categories with it listed', (tester) async {
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

    // Saving routes to "Categories" with the new category listed (matches
    // the design's `saveCategory()`).
    expect(find.text('Categories'), findsWidgets);
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

    final catMarker = tester.widget<Container>(
      find.byKey(const ValueKey('cat-marker-family')),
    );
    expect(catMarker.color, categoryColor);
    expect(catMarker.constraints?.maxWidth, 4);

    // Close the categories sheet before opening the imports sheet.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await openCalManage(tester, imports: true);
    final impMarker = tester.widget<Container>(
      find.byKey(const ValueKey('imp-marker-school-feed')),
    );
    expect(impMarker.color, categoryColor);
    expect(impMarker.constraints?.maxWidth, 4);
    final importVisual = find.byKey(const ValueKey('imp-visual-school-feed'));
    expect(
      find.descendant(of: importVisual, matching: find.byType(SvgPicture)),
      findsOneWidget,
    );
    expect(find.text('Family · ICS / web link · 1 event'), findsOneWidget);
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

    await tester.tap(find.byKey(const ValueKey('imp-settings-training-feed')));
    await tester.pumpAndSettle();
    expect(find.text('Edit imported calendar'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'School training');
    await tester.tap(find.text('Show this calendar'));
    await tester.tap(find.text('Colors'));
    await tester.pumpAndSettle();
    final swatch = find.byType(AnimatedContainer).last;
    final newColor =
        (tester.widget<AnimatedContainer>(swatch).decoration as BoxDecoration)
            .color!;
    await tester.tap(swatch);
    await tester.pump();
    await tester.tap(find.text('Save calendar'));
    await tester.pumpAndSettle();

    expect(find.text('School training'), findsWidgets);
    final marker = tester.widget<Container>(
      find.byKey(const ValueKey('imp-marker-training-feed')),
    );
    expect(marker.color, newColor);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await goToCalendar(tester);
    await setCalView(tester, 'agenda');
    expect(find.text('Imported training'), findsNothing);
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

    await tester.tap(find.byKey(const ValueKey('imp-settings-training-feed')));
    await tester.pumpAndSettle();
    expect(find.text('REMINDER'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('1 day before'),
      find.byType(SingleChildScrollView).last,
      const Offset(-50, 0),
    );
    await tester.tap(find.text('1 day before'));
    await tester.pump();
    await tester.tap(find.text('Save calendar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('imp-settings-training-feed')));
    await tester.pumpAndSettle();
    final chip = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.text('1 day before'),
            matching: find.byType(Container),
          ),
        )
        .first;
    final decoration = chip.decoration as BoxDecoration;
    expect(decoration.color, B.soft);
  });

  testWidgets(
    'category, event, member colour and imported-calendar pickers all expose more colors',
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

      // Category sheet.
      await openCalManage(tester);
      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();
      expect(find.text('Colors'), findsOneWidget);
      await tester.tap(find.text('Colors'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AnimatedContainer).last);
      await tester.pump();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Family member colours.
      await goToCalendar(tester);
      await openCalManage(tester);
      expect(find.text('Colors'), findsWidgets);

      // Close the categories sheet before opening the imports sheet.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Imported calendar sheet.
      await openCalManage(tester, imports: true);
      await tester.tap(
        find.byKey(const ValueKey('imp-settings-training-feed')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Colors'), findsOneWidget);
      await tester.tap(find.text('Colors'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AnimatedContainer).last);
      await tester.pump();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Event editor.
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
      expect(find.text('Colors'), findsOneWidget);
      await tester.tap(find.text('Colors'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AnimatedContainer).last);
      await tester.pump();
    },
  );

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
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
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
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
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
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
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
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
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
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
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
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
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
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
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

      await openCalManage(tester, imports: true);
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
      await openCalManage(tester, imports: true);
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
      await tester.tap(find.byKey(const ValueKey('more-calimports')));
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
    await openCalManage(tester, imports: true);
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
      await openCalManage(tester, imports: true);
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
    await openCalManage(tester, imports: true);
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
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
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
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
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

  testWidgets('filter sheet shows all 3 layer toggles', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToCalendar(tester);
    await setCalView(tester, 'agenda');

    await openCalFilters(tester);
    expect(find.text('LAYERS'), findsOneWidget);
    for (final (id, label, _, _) in kCalLayers) {
      expect(find.byKey(ValueKey('cal-filter-layer-$id')), findsOneWidget);
      expect(find.text(label), findsOneWidget);
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
    await openCalManage(tester, imports: true);
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

  group('tasks with a due date appear in the calendar (#199)', () {
    TaskList taskList({List<ListTask>? tasks}) => TaskList(
      id: 'tl1',
      name: 'Chores',
      color: kCatColors.first,
      tasks: tasks,
    );

    testWidgets('shows a due task in Month view coloured by its assignee', (
      tester,
    ) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: const [],
          taskLists: [
            taskList(
              tasks: [
                ListTask(
                  id: 't1',
                  title: 'Take out bins',
                  assignee: 'erik',
                  due: today,
                ),
              ],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);

      final bar = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'cal-bar-task_tl1_t1-',
            ),
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

    testWidgets('does not show a completed task in the calendar', (
      tester,
    ) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: const [],
          taskLists: [
            taskList(
              tasks: [
                ListTask(
                  id: 't1',
                  title: 'Done already',
                  assignee: 'erik',
                  due: today,
                  done: true,
                ),
              ],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');

      expect(find.text('Done already'), findsNothing);
    });

    testWidgets('tapping a task occurrence opens a read-only task view', (
      tester,
    ) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: const [],
          taskLists: [
            taskList(
              tasks: [
                ListTask(
                  id: 't1',
                  title: 'Take out bins',
                  assignee: 'erik',
                  due: today,
                ),
              ],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);
      await openMonthEvent(tester, 'Take out bins');

      expect(find.text('Task due date — open in Lists'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('task-open-list')));
      await tester.pumpAndSettle();

      expect(find.text('Chores'), findsWidgets);
    });
  });

  group('calendar layer toggles + task/content occurrence checkboxes', () {
    TaskList chores({List<ListTask>? tasks}) => TaskList(
      id: 'tl1',
      name: 'Chores',
      color: kCatColors.first,
      tasks: tasks,
    );

    TaskList content({List<ListTask>? tasks}) => TaskList(
      id: 'tl2',
      name: 'Content plan',
      color: kCatColors[1],
      kind: 'content',
      tasks: tasks,
    );

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
          ],
          taskLists: [
            chores(
              tasks: [
                ListTask(
                  id: 't1',
                  title: 'Take out bins',
                  assignee: 'erik',
                  due: today,
                ),
              ],
            ),
            content(
              tasks: [
                ListTask(
                  id: 'c1',
                  title: 'Film reel',
                  assignee: 'erik',
                  due: today,
                ),
              ],
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
      "checking a non-recurring task's box marks it done and removes it "
      'from the calendar',
      (tester) async {
        final today = todayIso();
        await pumpApp(
          tester,
          prefs: calendarPrefs(
            events: const [],
            taskLists: [
              chores(
                tasks: [
                  ListTask(
                    id: 't1',
                    title: 'Take out bins',
                    assignee: 'erik',
                    due: today,
                  ),
                ],
              ),
            ],
          ),
          landOnDefaultTab: true,
        );
        await goToCalendar(tester);

        expect(find.text('Take out bins'), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('cal-check-task_tl1_t1-$today')));
        await tester.pumpAndSettle();

        expect(find.text('Take out bins'), findsNothing);
      },
    );

    testWidgets(
      "checking one occurrence of a recurring task's box only completes "
      'that date — a later occurrence stays visible and untouched',
      (tester) async {
        final today = todayIso();
        final future = addDaysForTest(today, 7);
        await pumpApp(
          tester,
          prefs: calendarPrefs(
            events: const [],
            taskLists: [
              chores(
                tasks: [
                  ListTask(
                    id: 't1',
                    title: 'Water plants',
                    assignee: 'erik',
                    due: today,
                    recur: 'weekly',
                  ),
                ],
              ),
            ],
          ),
          landOnDefaultTab: true,
        );
        await goToCalendar(tester);

        final todayCheckbox = ValueKey('cal-check-task_tl1_t1-$today');
        final futureCheckbox = ValueKey('cal-check-task_tl1_t1-$future');
        expect(find.byKey(todayCheckbox), findsOneWidget);
        expect(find.byKey(futureCheckbox), findsOneWidget);
        final countBefore = find.text('Water plants').evaluate().length;

        await tester.tap(find.byKey(todayCheckbox));
        await tester.pumpAndSettle();

        // Only today's occurrence is gone — the later one (and any other
        // still-visible occurrence of the series) is untouched.
        expect(find.byKey(todayCheckbox), findsNothing);
        expect(find.byKey(futureCheckbox), findsOneWidget);
        expect(find.text('Water plants').evaluate().length, countBefore - 1);
      },
    );

    testWidgets('content-layer occurrences render with a dashed pink outline, '
        'distinct from a household task occurrence', (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: const [],
          taskLists: [
            content(
              tasks: [
                ListTask(
                  id: 'c1',
                  title: 'Film reel',
                  assignee: 'erik',
                  due: today,
                ),
              ],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);

      final bar = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'cal-bar-task_tl2_c1-',
            ),
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
      expect(hasDashedOutline, isTrue);
    });

    testWidgets(
      'agenda view renders separate labeled sections per layer per day',
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
            taskLists: [
              chores(
                tasks: [
                  ListTask(
                    id: 't1',
                    title: 'Take out bins',
                    assignee: 'erik',
                    due: today,
                  ),
                ],
              ),
              content(
                tasks: [
                  ListTask(
                    id: 'c1',
                    title: 'Film reel',
                    assignee: 'erik',
                    due: today,
                  ),
                ],
              ),
            ],
          ),
          landOnDefaultTab: true,
        );
        await goToCalendar(tester);
        await setCalView(tester, 'agenda');

        expect(find.text('TO-DOS'), findsOneWidget);
        expect(find.text('CONTENT CREATION'), findsOneWidget);
        expect(find.text('SCHEDULE'), findsOneWidget);
        expect(
          find.byKey(ValueKey('agenda-section-task-$today')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('agenda-section-content-$today')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('agenda-section-appt-$today')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      "an appointment row in agenda shows the member's colour as its block "
      'background',
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
        // The block has a soft drop shadow tinted with its own background
        // colour (mockup's `apptRow` box-shadow), not a plain flat card.
        expect(decoration.boxShadow, isNotNull);
        expect(decoration.boxShadow, isNotEmpty);
        expect(decoration.boxShadow!.first.color, isNot(Colors.transparent));
      },
    );

    testWidgets('a content row in agenda has a dashed border', (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: calendarPrefs(
          events: const [],
          taskLists: [
            content(
              tasks: [
                ListTask(
                  id: 'c1',
                  title: 'Film reel',
                  assignee: 'erik',
                  due: today,
                ),
              ],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await goToCalendar(tester);
      await setCalView(tester, 'agenda');

      final row = find.byKey(ValueKey('agenda-content-task_tl2_c1-$today'));
      expect(row, findsOneWidget);
      final container = tester.widget<Container>(row);
      expect(
        container.foregroundDecoration!.runtimeType.toString(),
        contains('Dashed'),
      );
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
  });
}

String _isoNow() => todayIso();
