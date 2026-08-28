import 'dart:convert';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic family + workspace seed for the Settings v2 sub-screen
/// tests (#325–#329, #276, #281, #282): three members (one invited), the
/// default accounts/blocks, three calendar layers, two event categories, an
/// imported ICS feed, a discount card and a couple of calendar events.
Map<String, Object> settingsV2Prefs() {
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
        id: 'm2',
        name: 'Erik Janssen',
        email: 'erik.janssen@outlook.com',
        initials: 'EJ',
        color: kMemberColors[1],
        role: 'member',
      ),
      FamilyMember(
        id: 'm3',
        name: 'Lisa Janssen',
        email: 'lisa.j@icloud.com',
        initials: 'LJ',
        color: kMemberColors[2],
        role: 'member',
        status: 'invited',
      ),
    ],
  );
  final ws = Workspace.empty()
    ..accounts = defaultAccounts()
    ..cats = defaultCats();
  ws.calendarLayers.addAll(kDefaultCalendarLayers());
  ws.eventCategories.addAll([
    EventCategory(
      id: 'ec1',
      name: 'Family',
      color: const Color(0xff7c3aed),
      icon: 'users',
      members: ['me', 'm2'],
    ),
    EventCategory(
      id: 'ec2',
      name: 'Work',
      color: const Color(0xff1684B4),
      icon: 'briefcase',
      layerId: kLayerTask,
    ),
  ]);
  ws.events.addAll([
    CalendarEvent(
      id: 'ev1',
      title: 'Dentist',
      date: '2026-07-10',
      color: const Color(0xff7c3aed),
      layerId: kLayerAppt,
      category: 'ec1',
    ),
    CalendarEvent(
      id: 'ev2',
      title: 'Laundry',
      date: '2026-07-11',
      color: const Color(0xff1684B4),
      layerId: kLayerTask,
      todo: true,
    ),
  ]);
  ws.importedCalendars.add(
    ImportedCalendar(
      id: 'imp1',
      name: 'School holidays NL',
      provider: 'ics',
      color: const Color(0xffd97706),
      url: 'https://example.com/school.ics',
      // No auto-sync: tests must not attempt a real network fetch on boot.
      autoSync: false,
      events: [
        ImportedCalendarEvent(
          id: 'ie1',
          title: 'Summer break',
          date: '2026-07-20',
        ),
      ],
    ),
  );
  ws.cards.add(
    DiscountCard(
      id: 'k1',
      name: 'Albert Heijn',
      number: '262012345678',
      color: const Color(0xff0f9d6a),
    ),
  );
  return {
    'flutter.$kStorageKeyV4': json.encode({
      'year': 2026,
      'monthIdx': 6,
      'screen': 'overview',
      'tab': 'home',
      'familyId': family.id,
      'families': [family.toJson()],
      'workspaces': {family.id: ws.toJson()},
    }),
  };
}

Future<void> openMoreHub(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-more')));
  await tester.pumpAndSettle();
}
