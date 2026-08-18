import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

/// Same shape as `calendar_test.dart`'s `calendarPrefs` — a two-member family
/// ('me' / 'erik') with a given set of task lists seeded on the shared
/// workspace, so the kitchen dashboard has real per-member occurrences to
/// render.
Map<String, Object> _kitchenPrefs({List<TaskList> taskLists = const []}) {
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
  final ws = Workspace.empty()..taskLists = taskLists;
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
  await tester.tap(find.byKey(const ValueKey('cal-header-kitchen-dashboard')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kitchen dashboard renders one column per family member', (
    tester,
  ) async {
    final today = todayIso();
    await pumpApp(
      tester,
      prefs: _kitchenPrefs(
        taskLists: [
          TaskList(
            id: 'tl1',
            name: 'Chores',
            color: kCatColors.first,
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
    await _openKitchenDashboard(tester);

    expect(find.byKey(const ValueKey('kitchen-dashboard')), findsOneWidget);
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
        taskLists: [
          TaskList(
            id: 'tl1',
            name: 'Chores',
            color: kCatColors.first,
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
    await _openKitchenDashboard(tester);

    expect(find.text('Water plants'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('event-check-task_tl1_t1-$today')));
    await tester.pumpAndSettle();

    // Today's occurrence is gone from the dashboard now that it's done —
    // per-occurrence semantics: only the tapped date's completion
    // changed, not the whole recurring series (verified in depth by
    // calendar_test.dart's equivalent Month-view checkbox test).
    expect(find.text('Water plants'), findsNothing);
  });

  testWidgets(
    'star/progress indicator reflects completed-vs-total for a member with '
    'some tasks done and some not today',
    (tester) async {
      final today = todayIso();
      await pumpApp(
        tester,
        prefs: _kitchenPrefs(
          taskLists: [
            TaskList(
              id: 'tl1',
              name: 'Chores',
              color: kCatColors.first,
              tasks: [
                ListTask(
                  id: 't1',
                  title: 'Take out bins',
                  assignee: 'erik',
                  due: today,
                  done: true,
                ),
                ListTask(
                  id: 't2',
                  title: 'Water plants',
                  assignee: 'erik',
                  due: today,
                ),
              ],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await _openKitchenDashboard(tester);

      // Erik: 1 done ('Take out bins', excluded from the tile list since
      // eventOccurrences() never returns done occurrences) out of 2 total.
      expect(find.text('1/2 today'), findsOneWidget);
      // Eva has nothing assigned today.
      expect(find.text('0/0 today'), findsOneWidget);
      // Only the still-outstanding task renders as a tile.
      expect(find.text('Water plants'), findsOneWidget);
      expect(find.text('Take out bins'), findsNothing);
    },
  );
}
