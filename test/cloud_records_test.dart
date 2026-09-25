import 'package:family_money_management_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

// The pure record layer behind the Firestore sync
// (lib/src/features/account/data/cloud_records.dart). These are the database
// guarantees the engine relies on: the server version is always adopted, a
// device only writes what it changed, and serialization details (key order,
// int vs double) never read as a change.

ExpenseItem _item(
  String id, {
  bool paid = false,
  int? day,
  double amount = 50,
}) => ExpenseItem.fromJson({
  'id': id,
  'label': 'Item $id',
  'marker': '',
  'amount': amount,
  'paid': paid,
  'account': 'shared',
  'recurring': false,
  'day': day,
});

Workspace _ws({List<ExpenseItem>? home}) {
  final month = MonthData(caps: {'food': 800, 'home': 1200});
  month.blocks['home'] = home ?? [_item('rent'), _item('water')];
  month.blocks['food'] = [];
  return Workspace(
    accounts: defaultAccounts(),
    cats: defaultCats(),
    data: {
      2026: {'September': month},
    },
    taskLists: [
      TaskList.fromJson({
        'id': 'tl1',
        'name': 'Chores',
        'tasks': [
          {'id': 't1', 'title': 'Bins'},
          {'id': 't2', 'title': 'Dishes', 'done': true},
        ],
      }),
    ],
    shoppingLists: [
      ShoppingList.fromJson({
        'id': 'sl1',
        'name': 'Groceries',
        'items': [
          {'id': 's1', 'name': 'Milk', 'qty': 2},
        ],
      }),
    ],
    cards: [
      DiscountCard.fromJson({
        'id': 'card1',
        'name': 'Albert Heijn',
        'number': '5901234123457',
        'codeType': 'barcode',
        'color': 0xff1684B4,
      }),
    ],
    importedCalendars: [
      ImportedCalendar.fromJson({
        'id': 'ics1',
        'name': 'Team',
        'provider': 'ics',
        'color': 0xff2563eb,
        'events': [],
      }),
    ],
    weeklyPlan: {'2026-09-24': DayPlan(dateIso: '2026-09-24', dinner: 'Pasta')},
    events: [
      CalendarEvent.fromJson({
        'id': 'ev1',
        'title': 'Dentist',
        'date': '2026-09-30',
      }),
    ],
  );
}

/// Simulates what Firestore hands back: a HashMap with arbitrary key order
/// (reversed here) and whole numbers as ints.
Object? _asFirestore(Object? v) {
  if (v is Map) {
    return {for (final k in v.keys.toList().reversed) '$k': _asFirestore(v[k])};
  }
  if (v is List) return [for (final x in v) _asFirestore(x)];
  if (v is double && v == v.roundToDouble()) return v.toInt();
  return v;
}

Records _server(Records r) => {
  for (final e in r.entries)
    e.key: normalizeRecord(
      e.key,
      _asFirestore({...e.value, 'updatedAtMillis': 1}) as Map,
    )!,
};

Map<String, dynamic> _deepCopy(Map<String, dynamic> m) =>
    Map<String, dynamic>.from(_asFirestore(_asFirestore(m)) as Map);

ExpenseItem _findItem(Workspace ws, String id) => ws
    .data[2026]!['September']!
    .blocks
    .values
    .expand((x) => x)
    .firstWhere((x) => x.id == id);

/// One device: its last-known server state and its in-memory workspace.
class _Device {
  _Device(Records server)
    : base = {...server},
      ws = workspaceFromRecords(server);
  Records base;
  Workspace ws;

  Records get local => normalizedRecords(ws);

  /// Persist: write only what this device changed; returns the writes.
  ({
    Records creates,
    Map<String, List<FieldChange>> updates,
    List<String> deletes,
  })
  persist(Records server) {
    final plan = planRecordWrites(base, local);
    plan.creates.forEach((k, v) => server[k] = v);
    plan.updates.forEach((k, changes) {
      final doc = _deepCopy(server[k]!);
      for (final c in changes) {
        Map<String, dynamic> cur = doc;
        for (final seg in c.path.sublist(0, c.path.length - 1)) {
          cur = (cur[seg] ??= <String, dynamic>{}) as Map<String, dynamic>;
        }
        if (c.delete) {
          cur.remove(c.path.last);
        } else {
          cur[c.path.last] = c.value;
        }
      }
      server[k] = doc;
    });
    for (final k in plan.deletes) {
      server.remove(k);
    }
    base = {...local};
    return plan;
  }

  /// A snapshot of [server] arrives.
  void receive(Records server) {
    final newBase = _server(server);
    final changed = {
      ...base.keys,
      ...newBase.keys,
    }.where((k) => !jsonEquals(base[k], newBase[k])).toList();
    final merged = rebaseRecords(
      oldBase: base,
      newBase: newBase,
      local: local,
      changed: changed,
    );
    base = newBase;
    ws = workspaceFromRecords(merged);
  }
}

void main() {
  group('normalization', () {
    test('records round-trip losslessly and idempotently', () {
      final r1 = normalizedRecords(_ws());
      final r2 = normalizedRecords(workspaceFromRecords(r1));
      expect(r2.keys.toSet(), r1.keys.toSet());
      for (final k in r1.keys) {
        expect(jsonEquals(r1[k], r2[k]), isTrue, reason: k);
      }
    });

    test('Firestore key order and int/double never read as a change', () {
      final local = normalizedRecords(_ws());
      final server = _server(local);
      final plan = planRecordWrites(server, local);
      expect(plan.creates, isEmpty);
      expect(plan.updates, isEmpty);
      expect(plan.deletes, isEmpty);
    });

    test('one doc per budget entry, list item, weekly day and event', () {
      final keys = normalizedRecords(_ws()).keys;
      expect(keys, contains('budgetItems/2026_September_rent'));
      expect(keys, contains('listItems/task_tl1_t1'));
      expect(keys, contains('listItems/shop_sl1_s1'));
      expect(keys, contains('weekly/2026-09-24'));
      expect(keys, contains('events/ev1'));
      expect(keys, contains('workspace/budget_2026_September'));
      final month = normalizedRecords(
        _ws(),
      )['workspace/budget_2026_September']!;
      expect(month.containsKey('blocks'), isFalse);
      expect(month['_blocks'], ['home', 'food']);
    });

    test('empty blocks and item order survive the round-trip', () {
      final ws = workspaceFromRecords(normalizedRecords(_ws()));
      final m = ws.data[2026]!['September']!;
      expect(m.blocks.keys, ['home', 'food']);
      expect(m.blocks['home']!.map((e) => e.id), ['rent', 'water']);
      expect(ws.taskLists.single.tasks.map((t) => t.id), ['t1', 't2']);
    });
  });

  group('two devices', () {
    test('a stale device never overwrites edits it did not make (the bug)', () {
      final server = _server(normalizedRecords(_ws()));
      final me = _Device(server);
      final partner = _Device(server);

      // Partner sets a date and marks rent paid; it lands on the server.
      _findItem(partner.ws, 'rent')
        ..paid = true
        ..day = 24;
      partner.persist(server);

      // My phone still has the old month. I edit something unrelated
      // BEFORE the snapshot arrives, and persist.
      me.ws.shoppingLists.single.items.single.checked = true;
      final plan = me.persist(server);
      expect(plan.updates.keys, ['listItems/shop_sl1_s1']);
      expect(plan.creates, isEmpty);
      expect(plan.deletes, isEmpty);

      // The server still has the partner's edit, and my phone adopts it.
      me.receive(server);
      final rent = _findItem(me.ws, 'rent');
      expect(rent.paid, isTrue);
      expect(rent.day, 24);
      expect(me.ws.shoppingLists.single.items.single.checked, isTrue);
    });

    test('different fields of the same entry both survive', () {
      final server = _server(normalizedRecords(_ws()));
      final a = _Device(server);
      final b = _Device(server);
      _findItem(a.ws, 'rent').paid = true;
      _findItem(b.ws, 'rent').amount = 999;
      a.persist(server);
      b.persist(server);
      a.receive(server);
      b.receive(server);
      for (final d in [a, b]) {
        final rent = _findItem(d.ws, 'rent');
        expect(rent.paid, isTrue);
        expect(rent.amount, 999);
      }
    });

    test('a pending local edit survives an incoming remote change', () {
      final server = _server(normalizedRecords(_ws()));
      final a = _Device(server);
      final b = _Device(server);
      _findItem(b.ws, 'water').paid = true;
      b.persist(server);
      // A edits rent but hasn't persisted yet (debounce) when B's change lands.
      _findItem(a.ws, 'rent').day = 3;
      a.receive(server);
      expect(_findItem(a.ws, 'rent').day, 3);
      expect(_findItem(a.ws, 'water').paid, isTrue);
      final plan = a.persist(server);
      expect(plan.updates.keys, ['budgetItems/2026_September_rent']);
      b.receive(server);
      expect(_findItem(b.ws, 'rent').day, 3);
      expect(_findItem(b.ws, 'water').paid, isTrue);
    });

    test('concurrent additions to the same month both survive', () {
      final server = _server(normalizedRecords(_ws()));
      final a = _Device(server);
      final b = _Device(server);
      a.ws.data[2026]!['September']!.blocks['food']!.add(_item('a-new'));
      b.ws.data[2026]!['September']!.blocks['food']!.add(_item('b-new'));
      a.persist(server);
      b.persist(server);
      a.receive(server);
      final ids = a.ws.data[2026]!['September']!.blocks['food']!.map(
        (e) => e.id,
      );
      expect(ids, containsAll(['a-new', 'b-new']));
    });

    test('caps of different categories are merged per key', () {
      final server = _server(normalizedRecords(_ws()));
      final a = _Device(server);
      final b = _Device(server);
      a.ws.data[2026]!['September']!.caps['food'] = 900;
      b.ws.data[2026]!['September']!.caps['home'] = 1500;
      a.persist(server);
      b.persist(server);
      a.receive(server);
      expect(a.ws.data[2026]!['September']!.caps, {'food': 900, 'home': 1500});
    });

    test('a remote delete removes an entry this device did not touch', () {
      final server = _server(normalizedRecords(_ws()));
      final a = _Device(server);
      final b = _Device(server);
      b.ws.data[2026]!['September']!.blocks['home']!.removeWhere(
        (e) => e.id == 'water',
      );
      b.persist(server);
      a.receive(server);
      expect(a.ws.data[2026]!['September']!.blocks['home']!.map((e) => e.id), [
        'rent',
      ]);
      expect(planRecordWrites(a.base, a.local).deletes, isEmpty);
      expect(planRecordWrites(a.base, a.local).creates, isEmpty);
    });
  });

  group('safety nets', () {
    test('never deletes a record the device has not loaded', () {
      final plan = planRecordWrites(const {}, normalizedRecords(_ws()));
      expect(plan.deletes, isEmpty);
    });

    test('an empty placeholder workspace is recognised', () {
      expect(
        recordsAreEmptyPlaceholder(normalizedRecords(Workspace.empty())),
        isTrue,
      );
      expect(recordsAreEmptyPlaceholder(normalizedRecords(_ws())), isFalse);
    });

    test('workspace docs never carry keys the security rules reject', () {
      // firestore.rules denies these on workspace/* so outdated apps can't
      // push whole item arrays; our own records must never contain them.
      for (final e in normalizedRecords(_ws()).entries) {
        if (splitRecordKey(e.key).$1 != kWorkspaceCol) continue;
        expect(
          e.value.keys.where(kLegacyWorkspaceKeys.contains),
          isEmpty,
          reason: e.key,
        );
      }
    });
  });

  group('legacy migration', () {
    test('legacy whole-array docs are detected', () {
      expect(isLegacyWorkspaceDoc('budget_2026', const {}), isTrue);
      expect(
        isLegacyWorkspaceDoc('budget_2026_September', const {'blocks': {}}),
        isTrue,
      );
      expect(isLegacyWorkspaceDoc('list_task_x', const {'tasks': []}), isTrue);
      expect(isLegacyWorkspaceDoc('events_2026', const {}), isTrue);
      expect(isLegacyWorkspaceDoc('weekly', const {}), isTrue);
      final current = normalizedRecords(_ws());
      for (final e in current.entries) {
        final (col, id) = splitRecordKey(e.key);
        if (col != kWorkspaceCol) continue;
        expect(isLegacyWorkspaceDoc(id, e.value), isFalse, reason: e.key);
      }
    });

    test('legacy section docs yield the same records as the new layout', () {
      final ws = _ws();
      final legacy = workspaceSections(ws)..remove('settings');
      final recs = legacyRecords({
        for (final e in legacy.entries)
          if (isLegacyWorkspaceDoc(e.key, e.value)) e.key: e.value,
      });
      final expected = normalizedRecords(ws);
      for (final k in [
        'budgetItems/2026_September_rent',
        'listItems/task_tl1_t2',
        'listItems/shop_sl1_s1',
        'weekly/2026-09-24',
        'events/ev1',
      ]) {
        expect(jsonEquals(recs[k], expected[k]), isTrue, reason: k);
      }
    });
  });
  group('merge-safe creates', () {
    /// Firestore `set(body, merge: true)`: nested maps merge, the rest replace.
    Map<String, dynamic> mergeSet(Map<String, dynamic>? doc, Map body) {
      final out = <String, dynamic>{...?doc};
      body.forEach((k, v) {
        out['$k'] = v is Map && out[k] is Map
            ? mergeSet(Map<String, dynamic>.from(out[k] as Map), v)
            : v;
      });
      return out;
    }

    test('a create reads back as exactly the local record', () {
      final recs = normalizedRecords(_ws())
        ..remove(recordKey(kWorkspaceCol, 'settings'));
      for (final e in recs.entries) {
        final body = createPayload(e.key, e.value, includeBlocks: true);
        expect(
          jsonEquals(
            normalizeRecord(e.key, _asFirestore(body) as Map),
            e.value,
          ),
          isTrue,
          reason: e.key,
        );
      }
    });

    test('two devices creating the same weekly day both keep their field', () {
      final key = recordKey(kWeeklyCol, '2026-09-28');
      Map<String, dynamic> rec(DayPlan p) =>
          normalizeRecord(key, {...p.toJson(), '_key': '2026-09-28'})!;
      final a = rec(DayPlan(dateIso: '2026-09-28', dinner: 'Pasta'));
      final b = rec(DayPlan(dateIso: '2026-09-28', lunch: 'Soup'));
      var doc = mergeSet(null, createPayload(key, a));
      doc = mergeSet(doc, createPayload(key, b));
      final out = normalizeRecord(key, doc)!;
      expect(out['dinner'], 'Pasta');
      expect(out['lunch'], 'Soup');
    });

    test('a generated occurrence created late never un-pays it', () {
      final key = recordKey(kBudgetItemsCol, '2026_September_g_rent_2026_8');
      Map<String, dynamic> rec(bool paid) => normalizeRecord(key, {
        ..._item('g_rent_2026_8', paid: paid).toJson(),
        '_year': 2026,
        '_month': 'September',
        '_block': 'home',
        '_order': 0,
      })!;
      final doc = mergeSet(
        mergeSet(null, createPayload(key, rec(true))),
        createPayload(key, rec(false)),
      );
      expect(normalizeRecord(key, doc)!['paid'], isTrue);
    });

    test('a record first seen from the server keeps its fields over a '
        'local placeholder', () {
      final key = recordKey(kWorkspaceCol, 'budget_2026_Oktober');
      final placeholder = normalizeRecord(key, {
        '_blocks': ['home'],
      })!;
      final server = normalizeRecord(key, {
        'caps': {'food': 700},
        'closed': true,
        '_blocks': ['home', 'food'],
      })!;
      final merged = rebaseRecords(
        oldBase: {key: placeholderRecord(key, placeholder)},
        newBase: {key: server},
        local: {key: placeholder},
        changed: [key],
      );
      expect(jsonEquals(merged[key], server), isTrue);
    });
  });

  group('orphan list items', () {
    test('items whose list has not arrived are kept, never deleted', () {
      final all = normalizedRecords(_ws());
      final base = {
        for (final e in all.entries)
          if (e.key != recordKey(kWorkspaceCol, 'list_task_tl1'))
            e.key: e.value,
      };
      final local = normalizedRecords(workspaceFromRecords(base));
      expect(
        local.keys.where((k) => k.startsWith('$kListItemsCol/task_')),
        isEmpty,
      );
      final orphans = orphanListItems(base, local);
      expect(orphans.keys, hasLength(2));
      expect(planRecordWrites(base, {...local, ...orphans}).deletes, isEmpty);
    });

    test('items of a list deleted locally are not orphans', () {
      final base = normalizedRecords(_ws());
      final ws = _ws()..taskLists.clear();
      final local = normalizedRecords(ws);
      expect(orphanListItems(base, local), isEmpty);
      expect(
        planRecordWrites(
          base,
          local,
        ).deletes.where((k) => k.startsWith('$kListItemsCol/task_')),
        hasLength(2),
      );
    });
  });
}
