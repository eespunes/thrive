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
  await tester.tap(find.byKey(const ValueKey('cal-header-view')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('cal-view-kitchen-dashboard')));
  await tester.pumpAndSettle();
}

Future<void> _pickEmoji(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('glyph-pick-emoji')));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Tab).at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('😀').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'picture-mode quick-add via emoji, glyph re-edit and remove control',
    (tester) async {
      await pumpApp(
        tester,
        prefs: _prefs(picMembers: {'erik': true}),
        landOnDefaultTab: true,
      );
      await _openKitchen(tester);

      // Quick-add for the picture-mode member: pick an emoji, no title.
      await tester.tap(find.byKey(const ValueKey('kitchen-quick-add-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('kitchen-add-assignee-erik')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kitchen-add-image')), findsOneWidget);
      await _pickEmoji(tester);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      final item = thriveDebug.events.singleWhere((e) => e.kitchenOrigin);
      expect(item.emoji, '😀');

      // Re-open the tile's glyph sheet and clear the glyph.
      await tester.tap(find.byKey(ValueKey('kitchen-pic-edit-${item.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Task picture'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('glyph-clear')));
      await tester.pumpAndSettle();
      expect(item.emoji, isNull);
      // Dismiss the sheet.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Remove the kitchen item with its overlay control.
      await tester.tap(find.byKey(ValueKey('kitchen-remove-${item.id}')));
      await tester.pumpAndSettle();
      expect(thriveDebug.events.where((e) => e.kitchenOrigin), isEmpty);
    },
  );

  testWidgets('kitchen wall layer filter can be re-enabled', (tester) async {
    await pumpApp(tester, prefs: _prefs(), landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tapHubRow(tester, 'planning', 'more-kitchen-settings');

    await tester.tap(find.byKey(const ValueKey('kitchen-wall-layer-task')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kitchen-wall-layer-task')));
    await tester.pumpAndSettle();
  });

  testWidgets('kitchen dashboard with no family members shows an empty note', (
    tester,
  ) async {
    await pumpApp(tester, prefs: _prefs(members: []), landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tapHubRow(tester, 'planning', 'more-kitchen-settings');
    expect(find.text('No family members yet.'), findsOneWidget);
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
