import 'dart:convert';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// `layerFilter` is one per-user list while calendar layers are per-family,
/// so a restored/carried-over filter can name ids the active workspace never
/// defines. Those ids can't be toggled back on from the filter sheet, so the
/// calendar would render empty with no way out.
void main() {
  Workspace customLayerWorkspace() {
    final ws = Workspace.empty()..calendarLayers.clear();
    ws.calendarLayers.addAll([
      CalendarLayerDef(
        id: 'lyr_school',
        label: 'School',
        icon: 'cal',
        color: const Color(0xff7c3aed),
      ),
      CalendarLayerDef(
        id: 'lyr_sport',
        label: 'Sport',
        icon: 'check',
        color: const Color(0xff2563eb),
      ),
    ]);
    return ws;
  }

  Map<String, Object> prefsWith({required Workspace ws, Object? layerFilter}) {
    final family = Family(
      id: 'fam_main',
      name: 'Custom layers',
      members: [
        FamilyMember(
          id: 'me',
          name: 'Eva',
          email: 'eva@example.com',
          initials: 'E',
          color: kMemberColors[0],
          role: 'owner',
        ),
      ],
    );
    return {
      'flutter.$kStorageKeyV4': json.encode({
        'familyId': family.id,
        'families': [family.toJson()],
        'workspaces': {family.id: ws.toJson()},
        'layerFilter': ?layerFilter,
      }),
    };
  }

  testWidgets('a missing filter falls back to the family\'s own layers', (
    tester,
  ) async {
    await pumpApp(tester, prefs: prefsWith(ws: customLayerWorkspace()));
    expect(thriveDebug.layerFilter, ['lyr_school', 'lyr_sport']);
  });

  testWidgets('a legacy appt/task/content filter is re-scoped, not kept', (
    tester,
  ) async {
    await pumpApp(
      tester,
      prefs: prefsWith(
        ws: customLayerWorkspace(),
        layerFilter: const ['appt', 'task', 'content'],
      ),
    );
    expect(thriveDebug.layerFilter, ['lyr_school', 'lyr_sport']);
  });

  testWidgets('a partially-valid filter keeps only the ids that exist', (
    tester,
  ) async {
    await pumpApp(
      tester,
      prefs: prefsWith(
        ws: customLayerWorkspace(),
        layerFilter: const ['appt', 'lyr_sport'],
      ),
    );
    expect(thriveDebug.layerFilter, ['lyr_sport']);
  });

  testWidgets('a default workspace still restores the built-in layers', (
    tester,
  ) async {
    await pumpApp(tester, prefs: prefsWith(ws: Workspace.empty()));
    expect(thriveDebug.layerFilter, kBuiltinLayerIds);
  });
}
