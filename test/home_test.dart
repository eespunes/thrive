import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

Map<String, Object> homeEventPrefs() {
  final category = EventCategory(
    id: 'family',
    name: 'Family',
    color: const Color(0xff0f9d6a),
    icon: 'star',
  );
  return homePrefsWithEvents(
    events: [
      CalendarEvent(
        id: 'upcoming',
        title: 'Family dinner',
        date: todayIso(),
        color: const Color(0xffe11d48),
        category: category.id,
        reminder: 'none',
      ),
    ],
    categories: [category],
  );
}

Map<String, Object> homePrefsWithEvents({
  required List<CalendarEvent> events,
  List<EventCategory> categories = const [],
  List<TaskList> taskLists = const [],
  String selfMemberId = 'me',
  String? selfMemberUid,
}) {
  final family = Family(
    id: 'fam_main',
    name: 'Janssen family',
    username: 'janssen',
    members: [
      FamilyMember(
        id: selfMemberId,
        name: 'Eva Janssen',
        email: 'eva.janssen@gmail.com',
        initials: 'EJ',
        color: kMemberColors.first,
        role: 'owner',
        uid: selfMemberUid,
      ),
      FamilyMember(
        id: 'other',
        name: 'Sam Janssen',
        email: 'sam.janssen@gmail.com',
        initials: 'SJ',
        color: kMemberColors[1],
        role: 'member',
      ),
    ],
  );
  final workspace = Workspace.empty()
    ..events = events
    ..eventCategories = categories
    ..taskLists = taskLists;
  return {
    'flutter.$kStorageKeyV4': json.encode({
      'year': 2026,
      'monthIdx': 6,
      'screen': 'overview',
      'tab': 'home',
      'familyId': family.id,
      'families': [family.toJson()],
      'workspaces': {family.id: workspace.toJson()},
    }),
  };
}

String addHomeDaysForTest(String iso, int n) {
  final p = iso.split('-').map(int.parse).toList();
  final d = DateTime(p[0], p[1], p[2]).add(Duration(days: n));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

String homeTimeForTest(int minutes) {
  final clamped = minutes.clamp(0, 1439);
  final hour = clamped ~/ 60;
  final minute = clamped % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

void main() {
  testWidgets('today event uses the agenda-style category visual', (
    tester,
  ) async {
    const categoryColor = Color(0xff0f9d6a);
    await pumpApp(tester, prefs: homeEventPrefs(), landOnDefaultTab: true);
    final today = todayIso();

    final visual = find.byKey(
      ValueKey('agenda-title-category-upcoming-$today'),
    );
    final surface = tester.widget<Container>(
      find.byKey(ValueKey('home-event-surface-upcoming-$today')),
    );
    expect(find.text('Family dinner'), findsOneWidget);
    expect(visual, findsOneWidget);
    expect((surface.decoration! as BoxDecoration).color, categoryColor);
    expect(
      find.descendant(of: visual, matching: find.byType(SvgPicture)),
      findsOneWidget,
    );
  });

  testWidgets("Home today's events shows three rows and scrolls to the rest", (
    tester,
  ) async {
    final today = todayIso();
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final events = <CalendarEvent>[
      for (var i = 1; i <= 5; i++)
        CalendarEvent(
          id: 'today-$i',
          title: 'Today event $i',
          date: today,
          allDay: true,
          color: const Color(0xff2563eb),
          reminder: 'none',
        ),
      CalendarEvent(
        id: 'tomorrow',
        title: 'Tomorrow event',
        date: addHomeDaysForTest(today, 1),
        allDay: true,
        color: const Color(0xff2563eb),
        reminder: 'none',
      ),
      if (nowMinutes > 0)
        CalendarEvent(
          id: 'past-timed',
          title: 'Past timed event',
          date: today,
          allDay: false,
          start: homeTimeForTest(nowMinutes - 20),
          end: homeTimeForTest(nowMinutes - 1),
          color: const Color(0xff2563eb),
          reminder: 'none',
        ),
    ];

    await pumpApp(
      tester,
      prefs: homePrefsWithEvents(events: events),
      landOnDefaultTab: true,
    );

    expect(
      find.byKey(const ValueKey('home-today-events-scroll')),
      findsOneWidget,
    );
    expect(find.text('Today event 1'), findsOneWidget);
    expect(find.text('Today event 2'), findsOneWidget);
    expect(find.text('Today event 3'), findsOneWidget);
    expect(find.text('Today event 4'), findsOneWidget);
    expect(find.text('Today event 5'), findsOneWidget);
    expect(find.text('Tomorrow event'), findsNothing);
    if (nowMinutes > 0) expect(find.text('Past timed event'), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('home-today-events-scroll')))
          .height,
      lessThanOrEqualTo(214),
    );
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('home-today-events-scroll')),
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    await tester.drag(scrollable, const Offset(0, -120));
    await tester.pump();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
  });

  testWidgets('Home tasks show three rows and scroll all assigned tasks', (
    tester,
  ) async {
    await pumpApp(
      tester,
      prefs: homePrefsWithEvents(
        events: const [],
        taskLists: [
          TaskList(
            id: 'house',
            name: 'Household',
            color: const Color(0xff2563eb),
            tasks: [
              for (var i = 1; i <= 5; i++)
                ListTask(id: 'mine-$i', title: 'My task $i', assignee: 'me'),
              ListTask(
                id: 'other-task',
                title: 'Other task',
                assignee: 'other',
              ),
              ListTask(id: 'unassigned-task', title: 'Unassigned task'),
              ListTask(
                id: 'done-task',
                title: 'Done task',
                assignee: 'me',
                done: true,
              ),
            ],
          ),
        ],
      ),
      landOnDefaultTab: true,
    );

    expect(find.text('My task 1'), findsOneWidget);
    expect(find.text('My task 2'), findsOneWidget);
    expect(find.text('My task 3'), findsOneWidget);
    expect(find.text('My task 4'), findsOneWidget);
    expect(find.text('My task 5'), findsOneWidget);
    expect(find.text('Other task'), findsNothing);
    expect(find.text('Unassigned task'), findsNothing);
    expect(find.text('Done task'), findsNothing);
    expect(find.byKey(const ValueKey('home-tasks-scroll')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('home-tasks-scroll'))).height,
      lessThanOrEqualTo(168),
    );
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('home-tasks-scroll')),
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    await tester.drag(scrollable, const Offset(0, -80));
    await tester.pump();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
  });

  testWidgets(
    'Home tasks assigned to my member row id appear when it differs from myId',
    (tester) async {
      await pumpApp(
        tester,
        prefs: homePrefsWithEvents(
          events: const [],
          selfMemberId: 'eva-row',
          selfMemberUid: 'me',
          taskLists: [
            TaskList(
              id: 'house',
              name: 'Household',
              color: const Color(0xff2563eb),
              tasks: [
                ListTask(
                  id: 'profile-row-task',
                  title: 'Assigned through family member row',
                  assignee: 'eva-row',
                ),
              ],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );

      expect(find.text('Assigned through family member row'), findsOneWidget);
    },
  );

  testWidgets('Home dashboard shows a greeting and empty states with no data', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    expect(find.text('Hi, Eva'), findsOneWidget);
    expect(find.text('Nothing scheduled — enjoy the calm.'), findsOneWidget);
    expect(find.text('All caught up. Nice work!'), findsOneWidget);
    expect(find.text('No lists yet'), findsOneWidget);
    expect(find.text('Not planned'), findsOneWidget);
    expect(find.textContaining('PROJECTED BALANCE'), findsOneWidget);
  });

  testWidgets('a task created in Lists shows up in Tasks due soon', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);

    await tester.tap(find.byKey(const ValueKey('nav-lists')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Household');
    await tester.pump();
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Household'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Take out the bins');
    await tester.pump();
    await tester.tap(find.text('Eva Janssen').last);
    await tester.pump();
    await tester.tap(find.text('Add task').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('Take out the bins'), findsOneWidget);
    expect(find.textContaining('Household'), findsOneWidget);

    // Tapping the task row navigates straight into its list's detail.
    await tester.tap(find.text('Take out the bins'));
    await tester.pumpAndSettle();
    expect(find.text('Household'), findsOneWidget);
    expect(find.text('Add task'), findsOneWidget);
  });

  testWidgets(
    'a shopping list created in Lists shows up in the Shopping glance',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);

      await tester.tap(find.byKey(const ValueKey('nav-lists')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shopping'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Supermarket');
      await tester.pump();
      await tester.tap(find.text('Create list'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav-home')));
      await tester.pumpAndSettle();
      expect(find.text('Supermarket'), findsOneWidget);
    },
  );

  testWidgets('tapping the projected balance card opens the Finance tab', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.textContaining('PROJECTED BALANCE'));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
  });
}
