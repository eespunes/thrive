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
      // what another reassembles — except card photos, which deliberately
      // never travel through the cloud (issue #234). Restore them via the
      // same merge the sync engine applies, then compare.
      mergeCardPhotos(rebuilt!.cards, ws.cards);
      expect(rebuilt.toJson(), ws.toJson());
    });

    test('card photos stay on-device: excluded from the cards section', () {
      final ws = _sampleWorkspace();
      final sections = workspaceSections(ws);
      final cardsSection = (sections['cards']!['cards'] as List).cast<Map>();
      expect(cardsSection.single.containsKey('photo'), isFalse);
      expect(cardsSection.single['number'], '5901234123457');
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

    test(
      'splits per budget year, per events year and per imported calendar',
      () {
        final sections = workspaceSections(_sampleWorkspace());
        expect(
          sections.keys,
          containsAll([
            'settings',
            'events_2026',
            'lists',
            'weekly',
            'budget_2026',
          ]),
        );
        // No monolithic all-events doc any more (it overflowed Firestore's
        // 1 MB doc limit around ~3,000 events).
        expect(sections.containsKey('events'), isFalse);
        expect(sections['import_ic1'], isNotNull);
        expect(sections['import_ic2'], isNotNull);
      },
    );

    test('events span multiple year docs and round-trip', () {
      final ws = _sampleWorkspace();
      ws.events.add(
        CalendarEvent.fromJson({
          'id': 'ev2',
          'title': 'NYE party',
          'date': '2027-12-31',
        }),
      );
      final sections = workspaceSections(ws);
      expect(sections['events_2026'], isNotNull);
      expect(sections['events_2027'], isNotNull);
      final rebuilt = workspaceFromSections(sections)!;
      expect(rebuilt.events.map((e) => e.id).toSet(), {'ev1', 'ev2'});
    });

    test('legacy all-events doc still loads, sharded docs win on id clash', () {
      final sections = workspaceSections(_sampleWorkspace());
      sections['events'] = {
        'events': [
          {'id': 'ev1', 'title': 'Stale legacy copy', 'date': '2026-03-02'},
          {'id': 'legacy-only', 'title': 'Old event', 'date': '2024-01-05'},
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
      final a = sectionDigest(workspaceSections(ws)['events_2026']!);
      final b = sectionDigest(workspaceSections(ws)['events_2026']!);
      expect(a, b);
      ws.events.first.title = 'Doctor';
      final c = sectionDigest(workspaceSections(ws)['events_2026']!);
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

  group('workspaceFromDoc', () {
    test('loads a legacy single-doc workspace map', () {
      final ws = _sampleWorkspace();
      final loaded = workspaceFromDoc({'workspace': ws.toJson()});
      expect(loaded.toJson(), ws.toJson());
    });

    test('falls back to an empty workspace when the blob is absent', () {
      final loaded = workspaceFromDoc({'name': 'Fam'});
      expect(loaded.accounts, isEmpty);
      expect(loaded.events, isEmpty);
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

  group('mergeDirtySection', () {
    Map<String, dynamic> ev(String id, [String title = 't']) => {
      'id': id,
      'title': title,
    };

    test('events: unions by id — remote adds kept, local wins on both', () {
      final local = {
        'events': [ev('a', 'local-edit'), ev('b')],
      };
      final remote = {
        'events': [ev('a', 'remote-edit'), ev('c', 'remote-add')],
      };
      final merged = mergeDirtySection('events_2026', local, remote);
      final ids = [for (final e in merged['events'] as List) e['id']];
      expect(ids, ['a', 'b', 'c']);
      // Local version wins for items present on both sides.
      expect((merged['events'] as List).first['title'], 'local-edit');
    });

    test('events: malformed shape falls back to local wholesale', () {
      final local = {
        'events': [ev('a')],
      };
      expect(
        mergeDirtySection('events_2026', local, {'events': 'nope'}),
        local,
      );
      expect(
        mergeDirtySection('events_2026', local, {
          'events': [
            {'title': 'no id'},
          ],
        }),
        local,
      );
      // Input payload never mutated.
      expect((local['events'] as List).length, 1);
    });

    test('cards: unions by id', () {
      final merged = mergeDirtySection(
        'cards',
        {
          'cards': [ev('c1')],
        },
        {
          'cards': [ev('c1'), ev('c2')],
        },
      );
      expect([for (final c in merged['cards'] as List) c['id']], ['c1', 'c2']);
    });

    test('lists: unions lists AND items within a shared list', () {
      final local = {
        'taskLists': [
          {
            'id': 'tl1',
            'name': 'local-name',
            'tasks': [ev('t1', 'local')],
          },
        ],
        'shoppingLists': [
          {
            'id': 'sl1',
            'items': [ev('s1')],
          },
        ],
      };
      final remote = {
        'taskLists': [
          {
            'id': 'tl1',
            'name': 'remote-name',
            'tasks': [ev('t1', 'remote'), ev('t2', 'remote-add')],
          },
          {'id': 'tl2', 'tasks': <Object>[]},
        ],
        'shoppingLists': [
          {
            'id': 'sl1',
            'items': [ev('s2')],
          },
        ],
      };
      final merged = mergeDirtySection('lists', local, remote);
      final tls = (merged['taskLists'] as List).cast<Map>();
      expect([for (final l in tls) l['id']], ['tl1', 'tl2']);
      // List-level fields keep the local version.
      expect(tls.first['name'], 'local-name');
      final tasks = (tls.first['tasks'] as List).cast<Map>();
      expect([for (final t in tasks) t['id']], ['t1', 't2']);
      expect(tasks.first['title'], 'local');
      final items = ((merged['shoppingLists'] as List).first['items'] as List)
          .cast<Map>();
      expect([for (final i in items) i['id']], ['s1', 's2']);
    });

    test('budget: merges per month at block-item level', () {
      final local = {
        'months': {
          'Juli': {
            'blocks': {
              'home': [ev('x1', 'local')],
            },
            'caps': {'home': 100},
            'closed': true,
          },
        },
      };
      final remote = {
        'months': {
          'Juli': {
            'blocks': {
              'home': [ev('x1', 'remote'), ev('x2', 'remote-add')],
              'food': [ev('f1')],
            },
            'caps': {'home': 999},
            'closed': false,
          },
          'Juni': {
            'blocks': {
              'home': [ev('y1')],
            },
          },
        },
      };
      final merged = mergeDirtySection('budget_2026', local, remote);
      final months = merged['months'] as Map;
      // Remote-only month added wholesale.
      expect(months.containsKey('Juni'), isTrue);
      final juli = months['Juli'] as Map;
      // Month-level fields keep the local version.
      expect((juli['caps'] as Map)['home'], 100);
      expect(juli['closed'], isTrue);
      final home = ((juli['blocks'] as Map)['home'] as List).cast<Map>();
      expect([for (final i in home) i['id']], ['x1', 'x2']);
      expect(home.first['title'], 'local');
      // Remote-only block added.
      expect((juli['blocks'] as Map).containsKey('food'), isTrue);
    });

    test('budget: unexpected month shape keeps local', () {
      final local = {
        'months': {'Juli': 'weird'},
      };
      final merged = mergeDirtySection('budget_2026', local, {
        'months': {
          'Juli': {'blocks': <String, Object>{}},
        },
      });
      expect((merged['months'] as Map)['Juli'], 'weird');
    });

    test('settings/weekly/imports keep dirty-local-wins', () {
      final settings = <String, dynamic>{'kitchenEnabled': true};
      expect(
        mergeDirtySection('settings', settings, {'kitchenEnabled': false}),
        same(settings),
      );
      final weekly = <String, dynamic>{
        'weeklyPlan': {'mon': <String, Object>{}},
      };
      expect(
        mergeDirtySection('weekly', weekly, {'weeklyPlan': <String, Object>{}}),
        same(weekly),
      );
      final imp = <String, dynamic>{'calendar': <String, Object>{}, 'order': 0};
      expect(mergeDirtySection('import_ic1', imp, {}), same(imp));
    });

    test('a merged events section still decodes via workspaceFromSections', () {
      final merged = {
        ...workspaceSections(Workspace.empty()),
        'events_2026': mergeDirtySection(
          'events_2026',
          {
            'events': [
              {'id': 'a', 'title': 'A', 'date': '2026-01-01'},
            ],
          },
          {
            'events': [
              {'id': 'b', 'title': 'B', 'date': '2026-01-02'},
            ],
          },
        ),
      };
      final ws = workspaceFromSections(merged)!;
      expect({for (final e in ws.events) e.id}, {'a', 'b'});
    });
  });
}
