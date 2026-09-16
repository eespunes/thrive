import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

Map<String, Object> _prefs({
  List<FamilyMember>? members,
  List<CalendarEvent> events = const [],
  List<ImportedCalendar> imported = const [],
  Map<String, bool> picMembers = const {},
}) {
  final family = Family(
    id: 'fam_main',
    name: 'Janssen family',
    username: 'janssen',
    members:
        members ??
        [
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
    ..importedCalendars = imported
    ..picMembers = Map.of(picMembers)
    ..calendarLayers = kDefaultCalendarLayers()
    ..kitchenLayerFilter = kDefaultCalendarLayers()
        .map((layer) => layer.id)
        .toList();
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

Future<void> _openKitchen(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-calendar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('cal-view-kitchen')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'picture-mode quick-add needs a real photo, and a tile keeps its glyph '
    'sheet and remove control',
    (tester) async {
      await pumpApp(
        tester,
        prefs: _prefs(
          picMembers: {'erik': true},
          events: [
            CalendarEvent(
              id: 'k1',
              title: 'Tidy toys',
              allDay: true,
              date: todayIso(),
              color: kMemberColors[1],
              attendees: const ['erik'],
              layerId: '',
              todo: true,
              kitchenOrigin: true,
              emoji: '🧸',
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await _openKitchen(tester);

      // Quick-add offers no emoji shortcut for a picture-mode member — a
      // pre-reader's tile needs a real photo — and Add is blocked without
      // one (#334).
      await tester.tap(find.byKey(const ValueKey('kitchen-quick-add-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('kitchen-add-assignee-erik')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('glyph-pick-emoji')), findsNothing);
      expect(
        find.byKey(const ValueKey('kitchen-add-photo-camera')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('kitchen-add-photo-library')),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, 'Water plants');
      await tester.pump();
      await tester.tap(find.text('Add for today'));
      await tester.pumpAndSettle();
      expect(
        thriveDebug.events.where((e) => e.title == 'Water plants'),
        isEmpty,
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // The seeded picture tile still opens the glyph sheet for editing...
      expect(find.byKey(const ValueKey('kitchen-pic-tile-k1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kitchen-pic-edit-k1')));
      await tester.pumpAndSettle();
      expect(find.text('Task picture'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('glyph-clear')));
      await tester.pumpAndSettle();
      expect(thriveDebug.events.singleWhere((e) => e.id == 'k1').emoji, isNull);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // ...and its overlay × still takes it off the wall.
      await tester.tap(find.byKey(const ValueKey('kitchen-remove-k1')));
      await tester.pumpAndSettle();
      expect(thriveDebug.events.where((e) => e.kitchenOrigin), isEmpty);
    },
  );

  testWidgets('kitchen wall layer filter can be re-enabled', (tester) async {
    await pumpApp(tester, prefs: _prefs(), landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tapHubRow(tester, 'planning', 'more-kitchen-settings');

    // Off, then back on.
    await tester.tap(find.byKey(const ValueKey('kitchen-layer-task')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kitchen-layer-task')));
    await tester.pumpAndSettle();

    // The min-1 guard toasts instead of hiding the last layer (#281).
    await tester.tap(find.byKey(const ValueKey('kitchen-layer-task')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kitchen-layer-content')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kitchen-layer-appt')));
    await tester.pump();
    expect(thriveDebug.toast, 'At least one layer stays visible');
  });

  testWidgets('kitchen dashboard with no family members shows an empty note', (
    tester,
  ) async {
    await pumpApp(tester, prefs: _prefs(members: []), landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tapHubRow(tester, 'planning', 'more-kitchen-settings');
    // The sub-page still lists the layers, but no member rows exist.
    expect(find.byKey(const ValueKey('kitchen-layer-task')), findsOneWidget);
    expect(find.textContaining('reward stars'), findsNothing);
  });

  testWidgets(
    'multi-day, recurring and imported events appear on the kitchen wall',
    (tester) async {
      final today = todayIso();
      final d = DateTime.parse('${today}T00:00:00Z');
      String iso(DateTime x) =>
          '${x.year.toString().padLeft(4, '0')}-'
          '${x.month.toString().padLeft(2, '0')}-'
          '${x.day.toString().padLeft(2, '0')}';
      final yesterday = iso(d.subtract(const Duration(days: 1)));
      final tomorrow = iso(d.add(const Duration(days: 1)));

      await pumpApp(
        tester,
        prefs: _prefs(
          events: [
            CalendarEvent(
              id: 'span',
              title: 'Grandma visit',
              allDay: true,
              date: yesterday,
              endDate: tomorrow,
              color: kMemberColors[0],
              attendees: const ['me', 'erik'],
            ),
            CalendarEvent(
              id: 'rec',
              title: 'Feed the cat',
              allDay: true,
              date: yesterday,
              recur: 'daily',
              color: kMemberColors[1],
              attendees: const ['erik'],
              layerId: 'task',
            ),
          ],
          imported: [
            ImportedCalendar(
              id: 'imp1',
              name: 'Team feed',
              provider: 'ics',
              color: kMemberColors[2],
              events: [
                ImportedCalendarEvent(
                  id: 'ie1',
                  title: 'Match day',
                  date: today,
                  allDay: true,
                ),
              ],
            ),
          ],
        ),
        landOnDefaultTab: true,
      );
      await _openKitchen(tester);

      expect(find.text('Grandma visit'), findsWidgets);
      expect(find.text('Feed the cat'), findsWidgets);
      expect(find.text('Match day'), findsWidgets);
    },
  );
}
