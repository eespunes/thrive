import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

/// Same shape as `calendar_test.dart`'s `calendarPrefs` — a two-member family
/// ('me' / 'erik') with a given set of calendar events seeded on the shared
/// workspace, so the kitchen dashboard has real per-member occurrences to
/// render.
Map<String, Object> _kitchenPrefs({
  List<CalendarEvent> events = const [],
  List<EventCategory> eventCategories = const [],
  List<CalendarLayerDef>? calendarLayers,
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
    ..eventCategories = eventCategories
    ..calendarLayers = calendarLayers ?? kDefaultCalendarLayers()
    ..kitchenLayerFilter =
        calendarLayers?.map((layer) => layer.id).toList() ??
        kDefaultCalendarLayers().map((layer) => layer.id).toList();
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

Future<void> _goToCalendar(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-calendar')));
  await tester.pumpAndSettle();
}

Future<void> _openKitchenDashboard(WidgetTester tester) async {
  await _goToCalendar(tester);
  await tester.tap(find.byKey(const ValueKey('cal-header-view')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('cal-view-kitchen-dashboard')));
  await tester.pumpAndSettle();
}

String _addDaysForKitchenTest(String iso, int n) {
  final d = DateTime.parse('${iso}T00:00:00Z').add(Duration(days: n));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

bool _nextSevenDaysCrossWeekForKitchenTest(String iso) {
  final d = DateTime.parse('${iso}T00:00:00Z');
  return d.weekday != DateTime.monday;
}

String _kitchenMainDateLabelForTest(String iso) {
  final d = DateTime.parse('${iso}T00:00:00Z');
  return kitchenMainDateLabel(d);
}

String _kitchenScheduleDateLabelForTest(String iso) {
  final d = DateTime.parse('${iso}T00:00:00Z');
  return kitchenScheduleDateLabel(d, isToday: false);
}

void main() {
  test(
    'kitchen schedule date labels include the month on the first day only',
    () {
      expect(
        kitchenScheduleDateLabel(DateTime.utc(2026, 9), isToday: false),
        'Tue, 1st September',
      );
      expect(
        kitchenScheduleDateLabel(DateTime.utc(2026, 9, 2), isToday: false),
        'Wed 2nd',
      );
      expect(
        kitchenScheduleDateLabel(DateTime.utc(2026, 9), isToday: true),
        'Today',
      );
    },
  );

  testWidgets('kitchen dashboard locks landscape and restores portrait', (
    tester,
  ) async {
    final orientationCalls = <List<dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientationCalls.add(List<dynamic>.from(call.arguments as List));
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpApp(tester, prefs: _kitchenPrefs(), landOnDefaultTab: true);
    orientationCalls.clear();

    await _openKitchenDashboard(tester);

    expect(orientationCalls, isNotEmpty);
    expect(orientationCalls.last, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);

    await tester.tap(find.byKey(const ValueKey('kitchen-dashboard-close')));
    await tester.pumpAndSettle();

    expect(orientationCalls.last, ['DeviceOrientation.portraitUp']);
  });

  testWidgets('kitchen dashboard renders one column per family member', (
    tester,
  ) async {
    final today = todayIso();
    await pumpApp(
      tester,
      prefs: _kitchenPrefs(
        events: [
          CalendarEvent(
            id: 't1',
            title: 'Take out bins',
            allDay: true,
            date: today,
            color: kCatColors.first,
            attendees: const ['erik'],
            layerId: 'task',
          ),
        ],
      ),
      landOnDefaultTab: true,
    );
    await _openKitchenDashboard(tester);

    expect(find.byKey(const ValueKey('kitchen-dashboard')), findsOneWidget);
    expect(find.text(_kitchenMainDateLabelForTest(today)), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('kitchen-left-panel')),
        matching: find.textContaining(RegExp(r'^WEEK \d+$')),
      ),
      _nextSevenDaysCrossWeekForKitchenTest(today)
          ? findsNWidgets(2)
          : findsOneWidget,
    );
    expect(find.text('No events yet'), findsWidgets);
    expect(find.byKey(const ValueKey('kitchen-column-me')), findsOneWidget);
    expect(find.byKey(const ValueKey('kitchen-column-erik')), findsOneWidget);
    expect(find.text('Eva Janssen'), findsOneWidget);
    expect(find.text('Erik Janssen'), findsOneWidget);
    // The task tile shows up under its assignee's column only.
    expect(find.text('Take out bins'), findsOneWidget);
  });

  testWidgets("tapping a task tile's checkbox completes only that occurrence", (
    tester,
  ) async {
    final today = todayIso();
    await pumpApp(
      tester,
      prefs: _kitchenPrefs(
        events: [
          CalendarEvent(
            id: 't1',
            title: 'Water plants',
            allDay: true,
            date: today,
            color: kCatColors.first,
            attendees: const ['erik'],
            layerId: 'task',
            recur: 'weekly',
          ),
        ],
      ),
      landOnDefaultTab: true,
    );
    await _openKitchenDashboard(tester);

    expect(find.text('Water plants'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('event-check-t1-$today')));
    await tester.pumpAndSettle();

    // Today's occurrence stays visible in kitchen view, but renders completed
    // (per-occurrence semantics are verified in calendar_test.dart).
    expect(find.text('Water plants'), findsOneWidget);
  });

  testWidgets(
    'a content-layer occurrence renders in its member column with the '
    "dashboard's checkColor/no-avatar tile styling, and its checkbox "
    'completes it',
    (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: _kitchenPrefs(
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
      await _openKitchenDashboard(tester);

      expect(find.text('Film reel'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('event-check-c1-$today')));
      await tester.pumpAndSettle();

      // Same per-occurrence-done semantics as a task tile: the completed
      // occurrence stays visible in kitchen view.
      expect(find.text('Film reel'), findsOneWidget);
    },
  );

  testWidgets(
    'star/progress indicator reflects completed-vs-total for a member with '
    'some tasks done and some not today',
    (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: _kitchenPrefs(
          events: [
            CalendarEvent(
              id: 't1',
              title: 'Take out bins',
              allDay: true,
              date: today,
              color: kCatColors.first,
              attendees: const ['erik'],
              layerId: 'task',
              done: true,
            ),
            CalendarEvent(
              id: 't2',
              title: 'Water plants',
              allDay: true,
              date: today,
              color: kCatColors.first,
              attendees: const ['erik'],
              layerId: 'task',
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await _openKitchenDashboard(tester);

      // Erik: 1 done ('Take out bins', excluded from the tile list since
      // eventOccurrences() never returns done occurrences) out of 2 total.
      expect(find.text('1/2'), findsOneWidget);
      // Eva has nothing assigned today.
      expect(find.text('0/0'), findsOneWidget);
      // Kitchen view keeps both done and outstanding tiles visible.
      expect(find.text('Water plants'), findsOneWidget);
      expect(find.text('Take out bins'), findsOneWidget);
    },
  );

  testWidgets("the left week panel shows today's appointments while a member's "
      'right-hand column does not', (tester) async {
    final today = todayIso();
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
      ..events = [
        CalendarEvent(
          id: 'e1',
          title: 'Football practice',
          date: today,
          start: '18:30',
          end: '20:00',
          color: kCatColors.first,
          attendees: const ['erik'],
        ),
      ];
    await pumpApp(
      tester,
      prefs: {
        'flutter.$kStorageKeyV4': json.encode({
          'year': 2026,
          'monthIdx': 6,
          'screen': 'overview',
          'tab': 'home',
          'familyId': 'fam_main',
          'families': [family.toJson()],
          'workspaces': {'fam_main': ws.toJson()},
        }),
      },
      landOnDefaultTab: true,
    );
    await _openKitchenDashboard(tester);

    // The appointment shows up in the left week panel...
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('kitchen-left-panel')),
        matching: find.text('Football practice'),
      ),
      findsOneWidget,
    );
    // ...but not inside Erik's member column, which is now task/content
    // only.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('kitchen-column-erik')),
        matching: find.text('Football practice'),
      ),
      findsNothing,
    );
  });

  testWidgets('kitchen wall appointments ignore phone calendar filters', (
    tester,
  ) async {
    final today = todayIso();
    await pumpApp(
      tester,
      prefs: _kitchenPrefs(
        events: [
          CalendarEvent(
            id: 'e1',
            title: 'Dentist',
            date: today,
            start: '09:00',
            end: '09:30',
            color: kCatColors.first,
            attendees: const ['erik'],
          ),
        ],
      ),
      landOnDefaultTab: true,
    );
    final state = tester.state(find.byType(ThriveHome, skipOffstage: false));
    (state as dynamic).layerFilter = ['task'];
    (state as dynamic).calFilter = ['me'];

    await _openKitchenDashboard(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('kitchen-left-panel')),
        matching: find.text('Dentist'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('kitchen wall schedule starts today and shows the next 7 days', (
    tester,
  ) async {
    final today = todayIso();
    final yesterday = _addDaysForKitchenTest(today, -1);
    final daySix = _addDaysForKitchenTest(today, 6);
    final daySeven = _addDaysForKitchenTest(today, 7);
    await pumpApp(
      tester,
      prefs: _kitchenPrefs(
        events: [
          CalendarEvent(
            id: 'past',
            title: 'Past appointment',
            date: yesterday,
            start: '09:00',
            end: '09:30',
            color: kCatColors.first,
            attendees: const ['erik'],
          ),
          CalendarEvent(
            id: 'today',
            title: 'Today appointment',
            date: today,
            start: '10:00',
            end: '10:30',
            color: kCatColors.first,
            attendees: const ['erik'],
          ),
          CalendarEvent(
            id: 'six',
            title: 'Day six appointment',
            date: daySix,
            start: '11:00',
            end: '11:30',
            color: kCatColors.first,
            attendees: const ['erik'],
          ),
          CalendarEvent(
            id: 'seven',
            title: 'Day seven appointment',
            date: daySeven,
            start: '12:00',
            end: '12:30',
            color: kCatColors.first,
            attendees: const ['erik'],
          ),
        ],
      ),
      landOnDefaultTab: true,
    );

    await _openKitchenDashboard(tester);

    expect(find.text('Past appointment'), findsNothing);
    expect(find.text('Today appointment'), findsOneWidget);
    expect(find.text('Day six appointment'), findsOneWidget);
    expect(find.text('Day seven appointment'), findsNothing);
    expect(find.textContaining(RegExp(r'^Week \d+ ·')), findsNothing);
    expect(find.text(_kitchenMainDateLabelForTest(today)), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text(_kitchenScheduleDateLabelForTest(daySix)), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('kitchen-left-panel')),
        matching: find.textContaining(RegExp(r'^WEEK \d+$')),
      ),
      _nextSevenDaysCrossWeekForKitchenTest(today)
          ? findsNWidgets(2)
          : findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Today appointment')).dy,
      lessThan(tester.getTopLeft(find.text('Day six appointment')).dy),
    );
  });

  testWidgets(
    'kitchen wall schedule shows timed calendar items from visible layers',
    (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: _kitchenPrefs(
          events: [
            CalendarEvent(
              id: 'c1',
              title: 'Read together',
              allDay: false,
              date: today,
              start: '17:00',
              end: '17:30',
              color: kCatColors.last,
              attendees: const ['erik'],
              layerId: 'content',
            ),
          ],
        ),
        landOnDefaultTab: true,
      );

      await _openKitchenDashboard(tester);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kitchen-left-panel')),
          matching: find.text('Read together'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'kitchen wall schedule shows category icons or attendee avatars',
    (tester) async {
      final today = todayIso();
      final activity = EventCategory(
        id: 'activity',
        name: 'Activity',
        color: kCatColors.last,
        icon: 'star',
      );
      await pumpApp(
        tester,
        prefs: _kitchenPrefs(
          eventCategories: [activity],
          events: [
            CalendarEvent(
              id: 'with-cat',
              title: 'Football',
              date: today,
              start: '16:00',
              end: '17:00',
              category: activity.id,
              color: kCatColors.first,
              attendees: const ['erik'],
            ),
            CalendarEvent(
              id: 'no-cat',
              title: 'Family dinner',
              date: today,
              start: '18:00',
              end: '19:00',
              color: kCatColors.first,
              attendees: const ['me', 'erik'],
            ),
            CalendarEvent(
              id: 'event-color',
              title: 'Dentist',
              date: today,
              start: '19:30',
              end: '20:00',
              color: kCatColors[2],
              attendees: const ['erik'],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );

      await _openKitchenDashboard(tester);

      expect(find.text('Football'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('kitchen-schedule-category-with-cat')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('kitchen-schedule-attendees-with-cat')),
        findsNothing,
      );
      expect(find.text('Family dinner'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('kitchen-schedule-attendees-no-cat')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('kitchen-schedule-category-no-cat')),
        findsNothing,
      );
      expect(find.text('Dentist'), findsOneWidget);
      for (final entry in {
        'with-cat': activity.color,
        'no-cat': kMemberColors[0],
        'event-color': kCatColors[2],
      }.entries) {
        final row = tester.widget<Container>(
          find.byKey(ValueKey('kitchen-schedule-row-${entry.key}-$today')),
        );
        final decoration = row.decoration as BoxDecoration;
        expect(decoration.color, entry.value);
      }
    },
  );

  testWidgets(
    'tapping a star sets the filled count up to that star, and tapping the '
    'top filled star again clears one back down',
    (tester) async {
      await pumpApp(tester, prefs: _kitchenPrefs(), landOnDefaultTab: true);
      await _openKitchenDashboard(tester);

      await tester.tap(find.byKey(const ValueKey('kitchen-star-erik-3')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kitchen-stars-erik')),
          matching: find.byIcon(Icons.star),
        ),
        findsNWidgets(3),
      );

      // Tapping the already-filled top star (3) again clears one back down.
      await tester.tap(find.byKey(const ValueKey('kitchen-star-erik-3')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kitchen-stars-erik')),
          matching: find.byIcon(Icons.star),
        ),
        findsNWidgets(2),
      );
    },
  );

  testWidgets('reaching 5/5 stars shows the claim-reward affordance, and '
      'claiming resets stars to 0', (tester) async {
    await pumpApp(tester, prefs: _kitchenPrefs(), landOnDefaultTab: true);
    await _openKitchenDashboard(tester);

    await tester.tap(find.byKey(const ValueKey('kitchen-star-erik-5')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kitchen-claim-erik')), findsOneWidget);
    expect(find.text('Claim reward!'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('kitchen-claim-erik')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kitchen-claim-erik')), findsNothing);
    expect(find.byKey(const ValueKey('kitchen-star-erik-5')), findsOneWidget);
  });

  testWidgets(
    'picture mode renders a photo-grid for that member instead of the '
    'text/checkbox list',
    (tester) async {
      final today = todayIso();
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
        ..events = [
          CalendarEvent(
            id: 't1',
            title: 'Take out bins',
            allDay: true,
            date: today,
            color: kCatColors.first,
            attendees: const ['erik'],
            layerId: 'task',
          ),
          CalendarEvent(
            id: 't2',
            title: 'Tidy room',
            allDay: true,
            date: today,
            color: kCatColors.first,
            attendees: const ['me'],
            layerId: 'task',
          ),
        ]
        ..picMembers = {'erik': true};
      await pumpApp(
        tester,
        prefs: {
          'flutter.$kStorageKeyV4': json.encode({
            'year': 2026,
            'monthIdx': 6,
            'screen': 'overview',
            'tab': 'home',
            'familyId': 'fam_main',
            'families': [family.toJson()],
            'workspaces': {'fam_main': ws.toJson()},
          }),
        },
        landOnDefaultTab: true,
      );
      await _openKitchenDashboard(tester);

      // Erik is in picture mode: a photo-grid renders instead of the
      // text/checkbox list, and the title text is not shown as a label.
      expect(find.byKey(const ValueKey('kitchen-grid-erik')), findsOneWidget);
      expect(find.byKey(const ValueKey('kitchen-list-erik')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kitchen-column-erik')),
          matching: find.text('Take out bins'),
        ),
        findsNothing,
      );
      // Eva stays in the default text mode.
      expect(find.byKey(const ValueKey('kitchen-list-me')), findsOneWidget);
    },
  );

  testWidgets(
    'kitchen wall settings toggles picture mode for one member only',
    (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: _kitchenPrefs(
          events: [
            CalendarEvent(
              id: 't1',
              title: 'Take out bins',
              allDay: true,
              date: today,
              color: kCatColors.first,
              attendees: const ['erik'],
              layerId: 'task',
            ),
            CalendarEvent(
              id: 't2',
              title: 'Tidy room',
              allDay: true,
              date: today,
              color: kCatColors.first,
              attendees: const ['me'],
              layerId: 'task',
            ),
          ],
        ),
        landOnDefaultTab: true,
      );

      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('more-kitchen-settings')));
      await tester.pumpAndSettle();

      expect(find.text('Kitchen wall settings'), findsWidgets);
      expect(find.text('Eva Janssen'), findsWidgets);
      expect(find.text('Erik Janssen'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('kitchen-wall-picmode-erik')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await _openKitchenDashboard(tester);

      expect(find.byKey(const ValueKey('kitchen-grid-erik')), findsOneWidget);
      expect(find.byKey(const ValueKey('kitchen-list-erik')), findsNothing);
      expect(find.byKey(const ValueKey('kitchen-list-me')), findsOneWidget);
      expect(find.byKey(const ValueKey('kitchen-grid-me')), findsNothing);
    },
  );

  testWidgets('kitchen wall settings shows every calendar layer', (
    tester,
  ) async {
    final layers = [
      ...kDefaultCalendarLayers(),
      CalendarLayerDef(
        id: 'school',
        label: 'School',
        icon: 'book',
        color: kCatColors[2],
      ),
    ];
    await pumpApp(
      tester,
      prefs: _kitchenPrefs(calendarLayers: layers),
      landOnDefaultTab: true,
    );

    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('more-kitchen-settings')));
    await tester.pumpAndSettle();

    for (final layer in layers) {
      expect(find.text(layer.label), findsOneWidget);
      final toggle = tester.widget<Switch>(
        find.byKey(ValueKey('kitchen-wall-layer-${layer.id}')),
      );
      expect(toggle.value, isTrue);
    }
  });

  testWidgets('kitchen wall settings controls visible item layers', (
    tester,
  ) async {
    final today = todayIso();
    await pumpApp(
      tester,
      prefs: _kitchenPrefs(
        events: [
          CalendarEvent(
            id: 't1',
            title: 'Take out bins',
            allDay: true,
            date: today,
            color: kCatColors.first,
            attendees: const ['erik'],
            layerId: 'task',
          ),
          CalendarEvent(
            id: 'c1',
            title: 'Family photo',
            allDay: true,
            date: today,
            color: kCatColors.last,
            attendees: const ['erik'],
            layerId: 'content',
          ),
        ],
      ),
      landOnDefaultTab: true,
    );

    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('more-kitchen-settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('kitchen-wall-layer-task')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await _openKitchenDashboard(tester);

    expect(find.text('Take out bins'), findsNothing);
    expect(find.text('Family photo'), findsOneWidget);
  });

  testWidgets('quick-add uses the glyph picker for picture-mode assignees', (
    tester,
  ) async {
    await pumpApp(tester, prefs: _kitchenPrefs(), landOnDefaultTab: true);

    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('more-kitchen-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kitchen-wall-picmode-erik')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await _openKitchenDashboard(tester);
    await tester.tap(find.byKey(const ValueKey('kitchen-quick-add-fab')));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const ValueKey('kitchen-add-image')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('kitchen-add-assignee-erik')));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const ValueKey('kitchen-add-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('glyph-pick-emoji')), findsOneWidget);
    expect(find.byKey(const ValueKey('glyph-upload')), findsOneWidget);
  });

  testWidgets('tapping a kitchen picture tile opens the glyph picker', (
    tester,
  ) async {
    final today = todayIso();
    await pumpApp(
      tester,
      prefs: _kitchenPrefs(
        events: [
          CalendarEvent(
            id: 'k1',
            title: 'Picture item',
            allDay: true,
            date: today,
            color: kMemberColors[1],
            attendees: const ['erik'],
            layerId: '',
            kitchenOrigin: true,
            emoji: '⭐',
          ),
        ],
      ),
      landOnDefaultTab: true,
    );
    final state = tester.state(find.byType(ThriveHome, skipOffstage: false));
    (state as dynamic).picMembers = {'erik': true};

    await _openKitchenDashboard(tester);
    expect(find.text('⭐'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('kitchen-pic-edit-k1')));
    await tester.pumpAndSettle();

    expect(find.text('Task picture'), findsOneWidget);
    expect(find.byKey(const ValueKey('glyph-pick-emoji')), findsOneWidget);
    expect(find.byKey(const ValueKey('glyph-upload')), findsOneWidget);
    expect(find.byKey(const ValueKey('glyph-clear')), findsOneWidget);
  });

  testWidgets(
    'tapping the checkmark overlay on a picture-mode tile marks it done',
    (tester) async {
      final today = todayIso();
      final family = Family(
        id: 'fam_main',
        name: 'Janssen family',
        username: 'janssen',
        members: [
          FamilyMember(
            id: 'erik',
            name: 'Erik Janssen',
            email: 'erik.janssen@gmail.com',
            initials: 'EJ',
            color: kMemberColors[1],
            role: 'owner',
          ),
        ],
      );
      final ws = Workspace.empty()
        ..events = [
          CalendarEvent(
            id: 't1',
            title: 'Take out bins',
            allDay: true,
            date: today,
            color: kCatColors.first,
            attendees: const ['erik'],
            layerId: 'task',
          ),
        ]
        ..picMembers = {'erik': true};
      await pumpApp(
        tester,
        prefs: {
          'flutter.$kStorageKeyV4': json.encode({
            'year': 2026,
            'monthIdx': 6,
            'screen': 'overview',
            'tab': 'home',
            'familyId': 'fam_main',
            'families': [family.toJson()],
            'workspaces': {'fam_main': ws.toJson()},
          }),
        },
        landOnDefaultTab: true,
      );
      await _openKitchenDashboard(tester);

      expect(find.byKey(const ValueKey('kitchen-pic-tile-t1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kitchen-pic-check-t1')));
      await tester.pumpAndSettle();

      // Once done, the picture tile stays visible but faded/checked.
      expect(find.byKey(const ValueKey('kitchen-pic-tile-t1')), findsOneWidget);
    },
  );

  testWidgets(
    'quick-add creates a kitchen-origin item visible immediately in the '
    "assignee's column, with a remove control, and it stays off the "
    'phone calendar',
    (tester) async {
      await pumpApp(tester, prefs: _kitchenPrefs(), landOnDefaultTab: true);
      await _openKitchenDashboard(tester);

      await tester.tap(find.byKey(const ValueKey('kitchen-quick-add-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Feed the cat');
      await tester.tap(find.byKey(const ValueKey('kitchen-add-assignee-erik')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kitchen-column-erik')),
          matching: find.text('Feed the cat'),
        ),
        findsOneWidget,
      );

      // A kitchen-origin item shows a remove (x) control...
      final state = tester.state(find.byType(ThriveHome, skipOffstage: false));
      final ev = (state as dynamic).events.firstWhere(
        (e) => e.title == 'Feed the cat',
      );
      expect(ev.kitchenOrigin, isTrue);
      expect(ev.layerId, '');
      expect(ev.attendees, ['erik']);
      expect(find.byKey(ValueKey('kitchen-remove-${ev.id}')), findsOneWidget);

      // Kitchen-origin items are stored independently from calendar layers,
      // so they do not render in the phone calendar.
      await tester.tap(find.byKey(const ValueKey('kitchen-dashboard-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-calendar')));
      await tester.pumpAndSettle();
      expect(find.text('Feed the cat'), findsNothing);
    },
  );

  testWidgets(
    'kitchen-created tasks stay visible even when the calendar task layer is filtered out',
    (tester) async {
      await pumpApp(tester, prefs: _kitchenPrefs(), landOnDefaultTab: true);
      final state = tester.state(find.byType(ThriveHome, skipOffstage: false));
      (state as dynamic).layerFilter = ['appt'];

      await _openKitchenDashboard(tester);
      await tester.tap(find.byKey(const ValueKey('kitchen-quick-add-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Clear plates');
      await tester.tap(find.byKey(const ValueKey('kitchen-add-assignee-erik')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kitchen-column-erik')),
          matching: find.text('Clear plates'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('kitchen quick-add does not require calendar layers', (
    tester,
  ) async {
    await pumpApp(tester, prefs: _kitchenPrefs(), landOnDefaultTab: true);
    final state = tester.state(find.byType(ThriveHome, skipOffstage: false));
    (state as dynamic).calendarLayers = <CalendarLayerDef>[];

    await _openKitchenDashboard(tester);
    await tester.tap(find.byKey(const ValueKey('kitchen-quick-add-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('kitchen-add-layer-task')), findsNothing);
    expect(
      find.byKey(const ValueKey('kitchen-add-layer-content')),
      findsNothing,
    );

    await tester.enterText(find.byType(TextField).first, 'Wipe table');
    await tester.tap(find.byKey(const ValueKey('kitchen-add-assignee-erik')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final ev = (state as dynamic).events.firstWhere(
      (e) => e.title == 'Wipe table',
    );
    expect(ev.layerId, '');
    expect(find.text('Wipe table'), findsOneWidget);
  });

  testWidgets(
    'deleting a kitchen-origin item removes it, but a phone-created item '
    'has no remove control and cannot be deleted this way',
    (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: _kitchenPrefs(
          events: [
            CalendarEvent(
              id: 'phone1',
              title: 'Homework',
              allDay: true,
              date: today,
              color: kCatColors.first,
              attendees: const ['erik'],
              layerId: 'task',
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await _openKitchenDashboard(tester);

      // A phone-created item has no remove control.
      expect(find.byKey(const ValueKey('kitchen-remove-phone1')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('kitchen-quick-add-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Feed the cat');
      await tester.tap(find.byKey(const ValueKey('kitchen-add-assignee-erik')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(ThriveHome, skipOffstage: false));
      final ev = (state as dynamic).events.firstWhere(
        (e) => e.title == 'Feed the cat',
      );
      await tester.tap(find.byKey(ValueKey('kitchen-remove-${ev.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Feed the cat'), findsNothing);
      // The phone-created item is untouched.
      expect(find.text('Homework'), findsOneWidget);
    },
  );

  testWidgets(
    'a disabled kitchen display shows a re-enable prompt in the calendar switcher',
    (tester) async {
      final prefs = _kitchenPrefs();
      final decoded =
          json.decode(prefs['flutter.$kStorageKeyV4'] as String)
              as Map<String, dynamic>;
      final workspaces = decoded['workspaces'] as Map<String, dynamic>;
      final ws = workspaces['fam_main'] as Map<String, dynamic>;
      ws['kitchenEnabled'] = false;
      prefs['flutter.$kStorageKeyV4'] = json.encode(decoded);

      await pumpApp(tester, prefs: prefs, landOnDefaultTab: true);
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('more-kitchen')), findsNothing);
      expect(find.text('Wall-tablet family view'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('nav-calendar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cal-header-view')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('cal-view-kitchen-dashboard')),
        findsOneWidget,
      );
      expect(find.text('Disabled - tap to re-enable'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('cal-view-kitchen-dashboard')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cal-header-view')));
      await tester.pumpAndSettle();
      expect(find.text('Wall-tablet family view'), findsOneWidget);
    },
  );

  testWidgets(
    'the calendar layers settings sheet no longer shows kitchen-display or '
    'picture-mode toggles',
    (tester) async {
      await pumpApp(tester, prefs: _kitchenPrefs(), landOnDefaultTab: true);
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('more-callayers')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('cal-manage-kitchen-enabled')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('cal-manage-picmode-erik')),
        findsNothing,
      );
    },
  );
}
