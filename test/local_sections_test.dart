import 'dart:convert';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

// Local per-section workspace persistence: the v4 blob keeps meta+families
// only, workspaces live under `thrive.ws.<familyId>.<sectionId>` keys, and
// a legacy blob with embedded workspaces still loads (and migrates on the
// first save).

void main() {
  testWidgets('saves workspaces as section keys, not inside the v4 blob', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    // Any mutation triggers a (debounced) persist.
    thriveDebug.mutateState(() {
      thriveDebug.events.add(
        CalendarEvent(
          id: 'sec1',
          title: 'Sectioned event',
          date: todayIso(),
          allDay: true,
          color: const Color(0xff7c3aed),
        ),
      );
    });
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    // The debounced persist flushes on dispose — the reboot guarantees it.
    await rebootApp(tester);
    final prefs = await SharedPreferences.getInstance();
    final v4 = jsonDecode(prefs.getString(kStorageKeyV4)!) as Map;
    expect(v4.containsKey('workspaces'), isFalse);
    final sectionKeys = prefs
        .getKeys()
        .where((k) => k.startsWith(kWsSectionPrefix))
        .toList();
    expect(sectionKeys, isNotEmpty);
    expect(
      sectionKeys.any((k) => k.contains('.events_')),
      isTrue,
      reason: 'events are sharded per year locally too',
    );

    // And the reboot loads the event back from those section keys.
    await rebootApp(tester);
    expect(thriveDebug.events.any((e) => e.title == 'Sectioned event'), isTrue);
  });

  testWidgets('a legacy blob with embedded workspaces still loads', (
    tester,
  ) async {
    // The legacy shape: a v4 blob with the workspaces map embedded.
    final ws = Workspace.empty()
      ..events = [
        CalendarEvent(
          id: 'legacy1',
          title: 'Legacy event',
          date: todayIso(),
          allDay: true,
          color: const Color(0xff1684B4),
        ),
      ];
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
      ],
    );
    await pumpApp(
      tester,
      landOnDefaultTab: true,
      prefs: {
        kStorageKeyV4: jsonEncode({
          'familyId': 'fam_main',
          'families': [family.toJson()],
          'workspaces': {'fam_main': ws.toJson()},
        }),
      },
    );
    expect(thriveDebug.events.any((e) => e.id == 'legacy1'), isTrue);
  });
}
