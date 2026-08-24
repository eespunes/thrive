import 'package:family_money_management_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

// The pure serialization/digest layer behind the Firestore workspace
// subcollection (lib/src/features/account/data/workspace_sections.dart).
// These are the invariants the sync engine relies on: a lossless
// sections round-trip, digest stability for unchanged payloads, and the
// meta digest ignoring server-managed fields. Models are built via
// fromJson — the same path real section payloads take.

Workspace _sampleWorkspace() {
  final month = MonthData();
  month.blocks['home'] = [
    ExpenseItem.fromJson({
      'id': 'e1',
      'label': 'Rent',
      'marker': '1',
      'amount': 900,
      'paid': true,
      'account': 'shared',
    }),
  ];
  return Workspace(
    accounts: [
      Account.fromJson({
        'key': 'shared',
        'name': 'Shared account',
        'short': 'Shared',
        'initials': 'SH',
        'color': 0xff112233,
      }),
    ],
    cats: defaultCats(),
    data: {
      2026: {'Januari': month},
    },
    events: [
      CalendarEvent.fromJson({
        'id': 'ev1',
        'title': 'Dentist',
        'date': '2026-03-02',
      }),
    ],
    taskLists: [
      TaskList.fromJson({'id': 'tl1', 'name': 'Chores'}),
    ],
    importedCalendars: [
      ImportedCalendar.fromJson({
        'id': 'ic1',
        'name': 'Team',
        'url': 'https://x/a.ics',
      }),
      ImportedCalendar.fromJson({
        'id': 'ic2',
        'name': 'School',
        'url': 'https://x/b.ics',
      }),
    ],
  );
}

FamilyMember _member(String id, String uid, String role, [String? status]) =>
    FamilyMember.fromJson({
      'id': id,
      'name': id,
      'email': '',
      'initials': id.substring(0, 1).toUpperCase(),
      if (uid.isNotEmpty) 'uid': uid,
      'role': role,
      'status': status ?? 'active',
    });

void main() {
  group('workspaceSections', () {
    test('round-trips a workspace losslessly through section docs', () {
      final ws = _sampleWorkspace();
      final rebuilt = workspaceFromSections(workspaceSections(ws));
      expect(rebuilt, isNotNull);
      // JSON equality is the contract: what one device uploads is exactly
      // what another reassembles.
      expect(rebuilt!.toJson(), ws.toJson());
    });

    test('returns null for an unmigrated (empty-section) family', () {
      expect(workspaceFromSections(const {}), isNull);
    });

    test('splits per budget year and per imported calendar', () {
      final sections = workspaceSections(_sampleWorkspace());
      expect(
        sections.keys,
        containsAll(['settings', 'events', 'lists', 'weekly', 'budget_2026']),
      );
      expect(sections['import_ic1'], isNotNull);
      expect(sections['import_ic2'], isNotNull);
    });

    test('imported calendars keep their display order', () {
      final ws = _sampleWorkspace();
      final rebuilt = workspaceFromSections(workspaceSections(ws))!;
      expect(rebuilt.importedCalendars.map((c) => c.id).toList(), [
        'ic1',
        'ic2',
      ]);
    });

    test('a deleted imported calendar produces no stale section', () {
      final ws = _sampleWorkspace();
      ws.importedCalendars.removeAt(0);
      expect(workspaceSections(ws).containsKey('import_ic1'), isFalse);
    });
  });

  group('sectionDigest', () {
    test('is stable for identical payloads and differs on any change', () {
      final ws = _sampleWorkspace();
      final a = sectionDigest(workspaceSections(ws)['events']!);
      final b = sectionDigest(workspaceSections(ws)['events']!);
      expect(a, b);
      ws.events.first.title = 'Doctor';
      final c = sectionDigest(workspaceSections(ws)['events']!);
      expect(c, isNot(a));
    });
  });

  group('metaDocDigest', () {
    test('ignores timestamps and join-credential extras', () {
      final base = {
        'name': 'Fam',
        'username': 'fam',
        'ownerUid': 'u1',
        'memberUids': ['u1'],
        'members': const [],
      };
      final withExtras = {
        ...base,
        'updatedAtMillis': 123,
        'joinHash': 'deadbeef',
        'joinScheme': 2,
      };
      expect(metaDocDigest(base), metaDocDigest(withExtras));
      expect(
        metaDocDigest({...base, 'name': 'Renamed'}),
        isNot(metaDocDigest(base)),
      );
    });
  });

  group('dedupeMembers', () {
    test('collapses duplicate uids preferring the owner row', () {
      final out = dedupeMembers([
        _member('a', 'u1', 'member'),
        _member('b', 'u1', 'owner'),
        _member('c', '', 'member', 'invited'),
      ]);
      expect(out.length, 2);
      expect(out.first.role, 'owner');
      expect(out.last.status, 'invited');
    });
  });
}
