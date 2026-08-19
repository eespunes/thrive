import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

/// Same shape as `calendar_test.dart`'s `calendarPrefs` — a two-member family
/// ('me' / 'erik') with a given set of calendar events seeded on the shared
/// workspace, so the kitchen dashboard has real per-member occurrences to
/// render.
Map<String, Object> _kitchenPrefs({List<CalendarEvent> events = const []}) {
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
    ..calendarLayers = kDefaultCalendarLayers();
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

    // Today's occurrence is gone from the dashboard now that it's done —
    // per-occurrence semantics: only the tapped date's completion
    // changed, not the whole recurring series (verified in depth by
    // calendar_test.dart's equivalent Month-view checkbox test).
    expect(find.text('Water plants'), findsNothing);
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
      // occurrence drops off today's column.
      expect(find.text('Film reel'), findsNothing);
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
      // Only the still-outstanding task renders as a tile.
      expect(find.text('Water plants'), findsOneWidget);
      expect(find.text('Take out bins'), findsNothing);
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

      // Once done, the occurrence no longer surfaces (mirrors the
      // text-mode checkbox test above).
      expect(find.byKey(const ValueKey('kitchen-pic-tile-t1')), findsNothing);
    },
  );

  testWidgets(
    'quick-add creates a kitchen-origin item visible immediately in the '
    "assignee's column, with a remove control, and it also shows up on the "
    'phone Agenda view',
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
      expect(find.byKey(ValueKey('kitchen-remove-${ev.id}')), findsOneWidget);

      // ...and it's a real CalendarEvent, so it also renders on the phone's
      // Agenda view (reusing the same rendering, not a fork of it).
      await tester.tap(find.byKey(const ValueKey('kitchen-dashboard-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-calendar')));
      await tester.pumpAndSettle();
      expect(find.text('Feed the cat'), findsWidgets);
    },
  );

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
    'a disabled kitchen display shows a re-enable prompt on the "Kitchen '
    'dashboard" More row, and tapping it re-enables the display',
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

      expect(find.text('Wall-tablet family view'), findsNothing);
      expect(find.text('Disabled — tap to re-enable'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('more-kitchen')));
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
