import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

/// Covers the event-display-anatomy epic (#343) and the month/agenda
/// conformance epic (#350): one rule set for every calendar surface, one
/// `passes()` gate, and the 2a chrome around them.

Map<String, Object> _prefs({
  List<CalendarEvent> events = const [],
  List<EventCategory> categories = const [],
  List<ImportedCalendar> imported = const [],
  List<String>? layerFilter,
  List<String> calFilter = const [],
  List<String> calCatFilter = const [],
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
    ..importedCalendars = imported
    ..calendarLayers = kDefaultCalendarLayers()
    ..kitchenLayerFilter = kDefaultCalendarLayers().map((l) => l.id).toList();
  return {
    'flutter.$kStorageKeyV4': json.encode({
      'year': 2026,
      'monthIdx': 6,
      'screen': 'overview',
      'tab': 'home',
      'familyId': 'fam_main',
      'families': [family.toJson()],
      'workspaces': {'fam_main': ws.toJson()},
      'layerFilter': layerFilter ?? ['appt', 'task', 'content'],
      if (calFilter.isNotEmpty) 'calFilter': calFilter,
      if (calCatFilter.isNotEmpty) 'calCatFilter': calCatFilter,
    }),
  };
}

Future<void> _goToCalendar(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-calendar')));
  await tester.pumpAndSettle();
}

Future<void> _setView(WidgetTester tester, String value) async {
  await tester.tap(find.byKey(ValueKey('cal-view-$value')));
  await tester.pumpAndSettle();
}

String _addDays(String iso, int n) {
  final d = DateTime.parse('${iso}T00:00:00Z').add(Duration(days: n));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

CalendarEvent _ev(
  String id,
  String title,
  String date, {
  bool allDay = true,
  String start = '',
  String endDate = '',
  String? category,
  List<String> attendees = const ['erik'],
  String layerId = 'appt',
  bool todo = false,
  bool birthday = false,
  String recur = 'none',
}) => CalendarEvent(
  id: id,
  title: title,
  allDay: allDay,
  date: date,
  endDate: endDate,
  start: start,
  color: kCatColors.first,
  category: category,
  attendees: List.of(attendees),
  layerId: layerId,
  todo: todo,
  birthday: birthday,
  recur: recur,
  reminder: 'none',
);

void main() {
  // ------------------------------------------------ #339 shared builder
  group('event anatomy: one builder for every kind', () {
    testWidgets('a birthday renders in its own cream/amber treatment and '
        'never shows a time', (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: _prefs(
          events: [
            _ev(
              'b1',
              'Grandma turns 78',
              today,
              birthday: true,
              recur: 'yearly',
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await _goToCalendar(tester);
      await _setView(tester, 'agenda');

      final row = find.byKey(ValueKey('agenda-appt-b1-$today'));
      expect(row, findsOneWidget);
      final surface = tester.widget<Container>(
        find.byKey(ValueKey('agenda-appt-surface-b1-$today')),
      );
      final decoration = surface.decoration! as BoxDecoration;
      expect(decoration.color, kBirthdayCream);
      // "Every year", never a clock time; and the ↻ affix still marks the
      // generated occurrence.
      expect(find.textContaining('Every year'), findsOneWidget);
      expect(find.text('Grandma turns 78 ↻'), findsOneWidget);
    });

    testWidgets('an imported occurrence is striped, carries ⇩ and says '
        'read-only', (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: _prefs(
          imported: [
            ImportedCalendar(
              id: 'feed',
              name: 'Gemeente',
              provider: 'ics',
              color: const Color(0xff475569),
              events: [
                ImportedCalendarEvent(
                  id: 'w1',
                  title: 'Waste pickup',
                  date: today,
                  start: '07:30',
                ),
              ],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await _goToCalendar(tester);
      await _setView(tester, 'agenda');

      expect(find.text('Waste pickup ⇩'), findsOneWidget);
      expect(find.textContaining('read-only'), findsOneWidget);
      final surface = tester.widget<Container>(
        find.byKey(ValueKey('agenda-appt-surface-feed_w1-$today')),
      );
      expect((surface.decoration! as BoxDecoration).gradient, isNotNull);
    });

    testWidgets('an imported feed is striped in its assigned category colour', (
      tester,
    ) async {
      final today = todayIso();
      const catColor = Color(0xff8b5cf6);
      await pumpApp(
        tester,
        prefs: _prefs(
          categories: [
            EventCategory(
              id: 'civic',
              name: 'Civic',
              color: catColor,
              icon: 'home',
            ),
          ],
          imported: [
            ImportedCalendar(
              id: 'feed',
              name: 'Gemeente',
              provider: 'ics',
              color: const Color(0xff475569),
              category: 'civic',
              events: [
                ImportedCalendarEvent(
                  id: 'w1',
                  title: 'Waste pickup',
                  date: today,
                  start: '07:30',
                ),
              ],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await _goToCalendar(tester);
      await _setView(tester, 'agenda');

      final surface = tester.widget<Container>(
        find.byKey(ValueKey('agenda-appt-surface-feed_w1-$today')),
      );
      final gradient =
          (surface.decoration! as BoxDecoration).gradient! as LinearGradient;
      // Still striped — read-only is the pattern, not a grey — but the stripes
      // are the category's colour, not the old slate.
      expect(gradient.colors.first, catColor);
      expect(gradient.colors.toSet().length, 2);
      expect(gradient.colors, isNot(contains(const Color(0xff5d6b7e))));
    });

    testWidgets('a to-do is a white dotted card with a real checkbox, and a '
        'multi-day run says which day it is', (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: _prefs(
          events: [
            _ev('t1', 'Take out the bins', today, layerId: 'task', todo: true),
            _ev(
              'm1',
              'Cabin weekend',
              _addDays(today, -1),
              endDate: _addDays(today, 1),
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await _goToCalendar(tester);
      await _setView(tester, 'agenda');

      final surface = tester.widget<Container>(
        find.byKey(ValueKey('agenda-appt-surface-t1-$today')),
      );
      expect((surface.decoration! as BoxDecoration).color, Colors.white);
      expect(
        surface.foregroundDecoration.runtimeType.toString(),
        contains('Dotted'),
      );
      expect(find.byKey(ValueKey('event-check-t1-$today')), findsOneWidget);
      expect(find.textContaining('Due this day'), findsOneWidget);

      // The multi-day run is on its second of three days.
      expect(find.textContaining('Day 2 of 3'), findsOneWidget);
    });
  });

  // ------------------------------------------------- #340 month anatomy
  group('event anatomy: month cells', () {
    testWidgets('a multi-day run paints one continuous ribbon — rounded only '
        'at its real ends, titled only on its first day', (tester) async {
      debugNowOverride = () => DateTime(2026, 6, 15);
      addTearDown(() => debugNowOverride = null);
      final start = todayIso();
      final mid = _addDays(start, 1);
      final end = _addDays(start, 2);
      await pumpApp(
        tester,
        prefs: _prefs(
          events: [_ev('m1', 'Cabin weekend', start, endDate: end)],
        ),
        landOnDefaultTab: true,
      );
      await _goToCalendar(tester);

      BoxDecoration segment(String iso) =>
          tester
                  .widget<Container>(find.byKey(ValueKey('cal-banner-m1-$iso')))
                  .decoration!
              as BoxDecoration;

      expect(
        segment(start).borderRadius,
        const BorderRadius.horizontal(left: Radius.circular(4)),
      );
      expect(segment(mid).borderRadius, BorderRadius.zero);
      expect(
        segment(end).borderRadius,
        const BorderRadius.horizontal(right: Radius.circular(4)),
      );

      // The title paints once, on the run's first visible day.
      expect(find.text('Cabin weekend'), findsOneWidget);
    });

    /// Shrinks the test surface to a phone-sized viewport and re-lays out.
    Future<void> setScreenHeight(WidgetTester tester, double logicalH) async {
      tester.view.physicalSize = Size(1080, logicalH * 2);
      await tester.pumpAndSettle();
    }

    testWidgets('a cell fills with as many bars as the screen has room for', (
      tester,
    ) async {
      debugNowOverride = () => DateTime(2026, 6, 15);
      addTearDown(() => debugNowOverride = null);
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: _prefs(
          events: [
            _ev('a1', 'All day out', today),
            for (var i = 0; i < 8; i++)
              _ev(
                't$i',
                'Timed $i',
                today,
                allDay: false,
                start: '${(9 + i).toString().padLeft(2, '0')}:00',
              ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await _goToCalendar(tester);

      int barsOnToday() => tester
          .widgetList(
            find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('cal-bar-t') &&
                  (w.key! as ValueKey<String>).value.endsWith(today),
            ),
          )
          .length;

      // The banner stays pinned above the bars, and the rest of the cell is
      // filled rather than capped at a fixed number of rows.
      expect(find.byKey(ValueKey('cal-banner-a1-$today')), findsOneWidget);
      await setScreenHeight(tester, 1400);
      final tall = barsOnToday();
      expect(tall, greaterThan(1));

      // A shorter phone gets fewer rows — and says so instead of overflowing.
      await setScreenHeight(tester, 640);
      final short = barsOnToday();
      expect(short, lessThan(tall));
      expect(find.textContaining('more'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a categorised bar leads with the category glyph, not a repeat mark',
      (tester) async {
        debugNowOverride = () => DateTime(2026, 6, 15);
        addTearDown(() => debugNowOverride = null);
        final today = todayIso();
        await pumpApp(
          tester,
          prefs: _prefs(
            categories: [
              EventCategory(
                id: 'sport',
                name: 'Sport',
                color: kCatColors.first,
                icon: 'whistle',
                emoji: '\u26bd',
              ),
            ],
            events: [
              _ev(
                't1',
                'Training',
                today,
                allDay: false,
                start: '09:00',
                category: 'sport',
                recur: 'weekly',
              ),
            ],
          ),
          landOnDefaultTab: true,
        );
        await _goToCalendar(tester);

        final bar = find.byKey(ValueKey('cal-bar-t1-$today'));
        expect(bar, findsOneWidget);
        // The category's glyph sits inside the bar, ahead of the title, and
        // the recurrence mark no longer eats the width.
        expect(
          find.descendant(of: bar, matching: find.text('\u26bd')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: bar, matching: find.text('Training')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: bar, matching: find.textContaining('\u21bb')),
          findsNothing,
        );
      },
    );

    testWidgets(
      "today's cell drops the hours that have already gone, not the ones "
      'still to come',
      (tester) async {
        debugNowOverride = () => DateTime(2026, 6, 15, 12, 30);
        addTearDown(() => debugNowOverride = null);
        final today = todayIso();
        await pumpApp(
          tester,
          prefs: _prefs(
            events: [
              _ev('t1', 'Nine', today, allDay: false, start: '09:00'),
              _ev('t2', 'Ten', today, allDay: false, start: '10:00'),
              _ev('t3', 'Six', today, allDay: false, start: '18:00'),
            ],
          ),
          landOnDefaultTab: true,
        );
        await _goToCalendar(tester);
        // Small enough that only two of the three bars fit.
        await setScreenHeight(tester, 620);

        // 09:00 and 10:00 are over at 12:30, so the slots go to the still
        // upcoming 18:00 and then the most recent past one.
        expect(find.byKey(ValueKey('cal-bar-t3-$today')), findsOneWidget);
        expect(find.byKey(ValueKey('cal-bar-t1-$today')), findsNothing);
        expect(find.text('+1 more'), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------- #342 the gate
  group('passes(): one gate for every surface', () {
    Future<void> pumpWith(
      WidgetTester tester, {
      List<String>? layerFilter,
      List<String> calFilter = const [],
      List<String> calCatFilter = const [],
      List<ImportedCalendar> imported = const [],
    }) async {
      final today = todayIso();
      final work = EventCategory(
        id: 'work',
        name: 'Work',
        color: kCatColors[1],
        icon: 'briefcase',
      );
      await pumpApp(
        tester,
        prefs: _prefs(
          categories: [work],
          layerFilter: layerFilter,
          calFilter: calFilter,
          calCatFilter: calCatFilter,
          imported: imported,
          events: [
            _ev(
              'shared',
              'Shared plan',
              today,
              attendees: const ['me', 'erik'],
            ),
            _ev('erikOnly', 'Erik only', today, attendees: const ['erik']),
            _ev('nobody', 'Unassigned', today, attendees: const []),
            _ev('tagged', 'Work sync', today, category: 'work'),
            _ev('chore', 'Chore', today, layerId: 'task', todo: true),
          ],
        ),
        landOnDefaultTab: true,
      );
      await _goToCalendar(tester);
      await _setView(tester, 'agenda');
    }

    testWidgets('a layer that is off hides only its own events', (
      tester,
    ) async {
      await pumpWith(tester, layerFilter: const ['appt']);
      expect(find.text('Shared plan'), findsOneWidget);
      expect(find.text('Chore'), findsNothing);
    });

    testWidgets('a category that is off hides its events, and never touches '
        'uncategorised ones', (tester) async {
      await pumpWith(tester, calCatFilter: const ['__none__']);
      expect(find.text('Work sync'), findsNothing);
      expect(find.text('Shared plan'), findsOneWidget);
      expect(find.text('Unassigned'), findsOneWidget);
    });

    testWidgets('an event stays visible while ANY of its people is on, and an '
        'event with nobody on it is never hidden', (tester) async {
      await pumpWith(tester, calFilter: const ['me']);
      expect(find.text('Shared plan'), findsOneWidget);
      expect(find.text('Erik only'), findsNothing);
      expect(find.text('Unassigned'), findsOneWidget);
    });

    testWidgets('an invisible imported feed is gated out everywhere', (
      tester,
    ) async {
      final today = todayIso();
      await pumpWith(
        tester,
        imported: [
          ImportedCalendar(
            id: 'feed',
            name: 'Gemeente',
            provider: 'ics',
            color: const Color(0xff475569),
            visible: false,
            events: [
              ImportedCalendarEvent(
                id: 'w1',
                title: 'Waste pickup',
                date: today,
              ),
            ],
          ),
        ],
      );
      expect(find.textContaining('Waste pickup'), findsNothing);
    });
  });

  // -------------------------------------------- #344/#345/#346/#347/#348
  group('month & agenda chrome', () {
    testWidgets('the header title block is the month selector, and a past '
        'month carries the PAST pill', (tester) async {
      await pumpApp(tester, prefs: _prefs(), landOnDefaultTab: true);
      await _goToCalendar(tester);

      expect(find.byKey(const ValueKey('cal-past-pill')), findsNothing);

      // Travel back a month through the Go-to-month sheet.
      final lastMonth = DateTime(
        DateTime.parse('${todayIso()}T00:00:00Z').year,
        DateTime.parse('${todayIso()}T00:00:00Z').month - 1,
      );
      await tester.tap(find.byKey(const ValueKey('cal-month-title')));
      await tester.pumpAndSettle();
      expect(find.text('Go to month'), findsOneWidget);
      await tester.tap(
        find.byKey(
          ValueKey('cal-pick-month-${lastMonth.year}-${lastMonth.month}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cal-past-pill')), findsOneWidget);

      // A past day is view-only: no add button, an amber notice instead.
      await tester.tap(
        find.byKey(
          ValueKey(
            'cal-day-bg-${_isoOfForTest(lastMonth.year, lastMonth.month, 1)}',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day-sheet-add')), findsNothing);
      expect(
        find.byKey(const ValueKey('day-sheet-past-notice')),
        findsOneWidget,
      );
    });

    testWidgets('the Go-to-month sheet counts each month\'s events and jumps '
        'back to today', (tester) async {
      final today = todayIso();
      final now = DateTime.parse('${today}T00:00:00Z');
      await pumpApp(
        tester,
        prefs: _prefs(events: [_ev('e1', 'Only plan', today)]),
        landOnDefaultTab: true,
      );
      await _goToCalendar(tester);
      await tester.tap(find.byKey(const ValueKey('cal-month-title')));
      await tester.pumpAndSettle();

      expect(find.text('1 event'), findsOneWidget);
      expect(find.text('Nothing yet'), findsWidgets);
      expect(
        find.text('${kMonthsEn[now.month - 1]} ${now.year} · now'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('cal-jump-today')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cal-past-pill')), findsNothing);
    });

    testWidgets('tapping a ghost day travels to its month and opens it', (
      tester,
    ) async {
      debugNowOverride = () => DateTime(2026, 6, 15);
      addTearDown(() => debugNowOverride = null);
      await pumpApp(tester, prefs: _prefs(), landOnDefaultTab: true);
      await _goToCalendar(tester);

      final grid = _monthGrid(todayIso());
      final currentMonth = DateTime.parse('${todayIso()}T00:00:00Z').month;
      final ghost = grid.lastWhere(
        (iso) => DateTime.parse('${iso}T00:00:00Z').month != currentMonth,
      );

      await tester.tap(find.byKey(ValueKey('cal-day-bg-$ghost')));
      await tester.pumpAndSettle();

      // The day sheet opened for the ghost day...
      expect(find.byKey(const ValueKey('day-sheet-add')), findsOneWidget);
      // ...and the calendar travelled to that day's month.
      final state = tester.state(find.byType(ThriveHome, skipOffstage: false));
      expect((state as dynamic).calAnchor, ghost);
    });

    testWidgets('the agenda heads the day with its event count and keeps the '
        'week strip inside the month', (tester) async {
      debugNowOverride = () => DateTime(2026, 6, 15);
      addTearDown(() => debugNowOverride = null);
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: _prefs(
          events: [
            _ev('e1', 'One', today),
            _ev('e2', 'Two', today, allDay: false, start: '10:00'),
          ],
        ),
        landOnDefaultTab: true,
      );
      await _goToCalendar(tester);
      await _setView(tester, 'agenda');

      expect(
        find.byKey(const ValueKey('cal-agenda-day-count')),
        findsOneWidget,
      );
      expect(find.text('2 events'), findsOneWidget);
      expect(find.textContaining('Today · '), findsOneWidget);
      expect(find.text('‹ swipe to change month ›'), findsOneWidget);

      // Every strip cell that renders belongs to the shown month.
      final strip = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('cal-week-strip-2'),
      );
      for (final element in strip.evaluate()) {
        final iso = (element.widget.key! as ValueKey<String>).value.substring(
          'cal-week-strip-'.length,
        );
        expect(DateTime.parse('${iso}T00:00:00Z').month, 6);
      }
    });

    testWidgets('the day sheet and agenda head the day in the design\'s '
        'wording, not the app\'s numeric date', (tester) async {
      debugNowOverride = () => DateTime(2026, 6, 17);
      addTearDown(() => debugNowOverride = null);
      const weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const weekdaysFull = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final today = todayIso();
      final d = DateTime.parse('${today}T00:00:00Z');

      await pumpApp(tester, prefs: _prefs(), landOnDefaultTab: true);
      await _goToCalendar(tester);

      await tester.tap(find.byKey(ValueKey('cal-day-bg-$today')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '${weekdaysShort[d.weekday - 1]} ${d.day} '
          '${kMonthsEn[d.month - 1].substring(0, 3)}',
        ),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(200, 60));
      await tester.pumpAndSettle();

      await _setView(tester, 'agenda');
      expect(
        find.text(
          'Today \u00b7 ${weekdaysFull[d.weekday - 1]} ${d.day} '
          '${kMonthsEn[d.month - 1]}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('agenda sections follow the design order, with Birthdays '
        'between the appointment layers and To-Dos', (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: _prefs(
          events: [
            _ev('a1', 'Dentist', today, allDay: false, start: '09:00'),
            _ev('b1', 'Grandma turns 78', today, birthday: true),
            _ev('t1', 'Bins', today, layerId: 'task', todo: true),
          ],
        ),
        landOnDefaultTab: true,
      );
      await _goToCalendar(tester);
      await _setView(tester, 'agenda');

      double headingY(String keyId) => tester
          .getTopLeft(find.byKey(ValueKey('agenda-layer-header-$keyId-$today')))
          .dy;

      expect(headingY('appt'), lessThan(headingY('birthday')));
      expect(headingY('birthday'), lessThan(headingY('task')));
    });

    testWidgets(
      'an empty day gets the calm copy, in the sheet and the agenda',
      (tester) async {
        await pumpApp(tester, prefs: _prefs(), landOnDefaultTab: true);
        await _goToCalendar(tester);
        await _setView(tester, 'agenda');
        expect(
          find.text('Nothing scheduled — enjoy the calm.'),
          findsOneWidget,
        );

        await _setView(tester, 'month');
        await tester.tap(find.byKey(ValueKey('cal-day-bg-${todayIso()}')));
        await tester.pumpAndSettle();
        expect(find.text('Nothing planned — enjoy the calm.'), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------- #349 filters
  group('filters', () {
    testWidgets('member and category filters persist per user', (tester) async {
      await pumpApp(tester, prefs: _prefs(), landOnDefaultTab: true);
      await _goToCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('cal-header-filter')));
      await tester.pumpAndSettle();
      expect(find.text('What do you want to see?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cal-filter-member-erik')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // The debounced persist runs on a 2s timer; a reboot must bring the
      // per-user filter back (never family-wide, #349).
      await tester.pump(const Duration(seconds: 3));
      await rebootApp(tester);
      final state = tester.state(find.byType(ThriveHome, skipOffstage: false));
      expect((state as dynamic).calFilter, contains('me'));
      expect((state as dynamic).calFilter, isNot(contains('erik')));
    });

    testWidgets(
      'the funnel button tints and dots itself when anything is off',
      (tester) async {
        await pumpApp(
          tester,
          prefs: _prefs(layerFilter: const ['appt']),
          landOnDefaultTab: true,
        );
        await _goToCalendar(tester);

        final button = find.byKey(const ValueKey('cal-header-filter'));
        final box = tester.widget<Container>(
          find.descendant(of: button, matching: find.byType(Container)).first,
        );
        expect((box.decoration! as BoxDecoration).color, B.soft);

        // "Show all" puts every layer, category and member back on.
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cal-filter-clear')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        final after = tester.widget<Container>(
          find.descendant(of: button, matching: find.byType(Container)).first,
        );
        expect((after.decoration! as BoxDecoration).color, Colors.white);
      },
    );
  });
}

/// The app's 42-cell month grid, mirrored for assertions.
List<String> _monthGrid(String anchor) {
  final d = DateTime.parse('${anchor}T00:00:00Z');
  final first = DateTime.utc(d.year, d.month, 1);
  final start = first.subtract(Duration(days: (first.weekday - 1) % 7));
  return [
    for (var i = 0; i < 42; i++)
      _isoOfForTest(
        start.add(Duration(days: i)).year,
        start.add(Duration(days: i)).month,
        start.add(Duration(days: i)).day,
      ),
  ];
}

String _isoOfForTest(int y, int m, int d) =>
    '${y.toString().padLeft(4, '0')}-'
    '${m.toString().padLeft(2, '0')}-'
    '${d.toString().padLeft(2, '0')}';
