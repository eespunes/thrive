import 'package:family_money_management_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

// The pure serialization/digest layer behind the Firestore workspace
// subcollection (lib/src/features/account/data/workspace_sections.dart).
// These are the invariants the sync engine relies on: a lossless
// sections round-trip, digest stability for unchanged payloads, and the
// meta digest ignoring server-managed fields. Models are built via
// fromJson - the same path real section payloads take.

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
    cards: [
      DiscountCard.fromJson({
        'id': 'card1',
        'name': 'Albert Heijn',
        'number': '5901234123457',
        'codeType': 'barcode',
        'color': 0xff1684B4,
        'photo': 'aGk=',
        'timesUsed': 2,
        'lastUsed': 1755000000000,
      }),
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
      // what another reassembles - except card photos, which deliberately
      // never travel through the cloud (issue #234), and events, which now live
      // in the per-event `events` subcollection rather than section docs.
      // Restore/align both, then compare.
      mergeCardPhotos(rebuilt!.cards, ws.cards);
      rebuilt.events
        ..clear()
        ..addAll(ws.events);
      expect(rebuilt.toJson(), ws.toJson());
    });

    test('card photos stay on-device: excluded from the per-card doc', () {
      final ws = _sampleWorkspace();
      final sections = workspaceSections(ws);
      final cardDoc = sections['card_card1']!;
      expect(cardDoc.containsKey('photo'), isFalse);
      expect(cardDoc['number'], '5901234123457');
      final rebuilt = workspaceFromSections(sections)!;
      expect(rebuilt.cards.single.photo, isNull);
      expect(rebuilt.cards.single.timesUsed, 2);
    });

    test('a fresh or sample workspace seeds no cards', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      expect(Workspace.empty().cards, isEmpty);
      expect((await buildSampleWorkspace()).cards, isEmpty);
    });

    test('returns null for an unmigrated (empty-section) family', () {
      expect(workspaceFromSections(const {}), isNull);
    });

    test('splits into per-item docs: card/list/budget-month/import', () {
      final sections = workspaceSections(_sampleWorkspace());
      expect(sections.keys, containsAll(['settings', 'weekly']));
      // Per-item docs (was one `cards`/`lists`/`budget_<year>` array doc each),
      // so concurrent edits to different items can't overwrite each other.
      expect(sections['card_card1'], isNotNull);
      expect(sections['list_task_tl1'], isNotNull);
      expect(sections['budget_2026_Januari'], isNotNull);
      // The old coarse array docs are gone.
      expect(sections.containsKey('cards'), isFalse);
      expect(sections.containsKey('lists'), isFalse);
      expect(sections.containsKey('budget_2026'), isFalse);
      expect(sections.containsKey('events'), isFalse);
      expect(sections['import_ic1'], isNotNull);
      expect(sections['import_ic2'], isNotNull);
    });

    test('round-trips per-item docs (cards, lists, budget months)', () {
      final ws = _sampleWorkspace();
      // Two of each kind so a per-item split is exercised.
      ws.taskLists.add(TaskList.fromJson({'id': 'tl2', 'name': 'Groceries'}));
      ws.data[2026]!['Februari'] = MonthData();
      final rebuilt = workspaceFromSections(workspaceSections(ws))!;
      expect(rebuilt.cards.map((c) => c.id).toSet(), {'card1'});
      expect(rebuilt.taskLists.map((l) => l.id).toSet(), {'tl1', 'tl2'});
      expect(rebuilt.data[2026]!.keys.toSet(), {'Januari', 'Februari'});
    });

    test('legacy coarse docs still load; per-item docs win on clash', () {
      // A family mid-migration briefly has both shapes. Reassembly reads both
      // and lets the newer per-item doc win.
      final ws = _sampleWorkspace();
      final sections = workspaceSections(ws);
      sections['cards'] = {
        'cards': [
          {'id': 'card1', 'name': 'STALE', 'number': '000', 'codeType': 'x'},
          {'id': 'legacy-card', 'name': 'Old', 'number': '1', 'codeType': 'x'},
        ],
      };
      sections['budget_2026'] = {
        'months': {
          'Januari': {
            'blocks': <String, dynamic>{},
            'caps': <String, dynamic>{},
          },
          'Maart': {'blocks': <String, dynamic>{}, 'caps': <String, dynamic>{}},
        },
      };
      final rebuilt = workspaceFromSections(sections)!;
      // Per-card doc (Albert Heijn) wins over the stale legacy copy.
      expect(
        rebuilt.cards.firstWhere((c) => c.id == 'card1').name,
        'Albert Heijn',
      );
      expect(rebuilt.cards.any((c) => c.id == 'legacy-card'), isTrue);
      // Legacy-only month is kept; the per-month doc is still present too.
      expect(rebuilt.data[2026]!.keys, containsAll(['Januari', 'Maart']));
    });

    test(
      'events are per-year docs LOCALLY but excluded for the CLOUD path',
      () {
        // Local persistence (default) keeps events sharded per year in section
        // docs - single device, no concurrent-write conflict.
        final local = workspaceSections(_sampleWorkspace());
        expect(local.containsKey('events_2026'), isTrue);
        // includeEvents:false drops the per-year event docs.
        final cloud = workspaceSections(
          _sampleWorkspace(),
          includeEvents: false,
        );
        expect(cloud.keys.any((k) => k.startsWith('events_')), isFalse);
        expect(cloud.containsKey('events'), isFalse);
        // Everything else is identical between the two modes.
        expect(
          cloud.keys.toSet(),
          local.keys.where((k) => !k.startsWith('events_')).toSet(),
        );
      },
    );

    test('workspaceFromSections still reads legacy event docs (migration '
        'seeding), sharded docs winning on id clash', () {
      // workspaceSections no longer emits event docs, but reassembly must still
      // read pre-migration `events` / `events_*` docs so the lazy in-app
      // migration can seed the workspace before rewriting them per-event.
      final sections = workspaceSections(_sampleWorkspace());
      sections['events'] = {
        'events': [
          {'id': 'ev1', 'title': 'Stale legacy copy', 'date': '2026-03-02'},
          {'id': 'legacy-only', 'title': 'Old event', 'date': '2024-01-05'},
        ],
      };
      sections['events_2026'] = {
        'events': [
          {'id': 'ev1', 'title': 'Dentist', 'date': '2026-03-02'},
        ],
      };
      final rebuilt = workspaceFromSections(sections)!;
      expect(rebuilt.events.singleWhere((e) => e.id == 'ev1').title, 'Dentist');
      expect(rebuilt.events.any((e) => e.id == 'legacy-only'), isTrue);
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
      final a = sectionDigest(workspaceSections(ws)['budget_2026_Januari']!);
      final b = sectionDigest(workspaceSections(ws)['budget_2026_Januari']!);
      expect(a, b);
      ws.data[2026]!['Januari']!.blocks['home']!.first.label = 'Mortgage';
      final c = sectionDigest(workspaceSections(ws)['budget_2026_Januari']!);
      expect(c, isNot(a));
    });

    test('does not depend on map key order', () {
      expect(
        sectionDigest({
          'a': 1,
          'b': {'x': 1, 'y': 2},
        }),
        sectionDigest({
          'b': {'y': 2, 'x': 1},
          'a': 1,
        }),
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
