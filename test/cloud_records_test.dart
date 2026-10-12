import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
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

    test('one doc per budget entry, list line, meal day and event', () {
      final keys = normalizedRecords(_ws()).keys;
      expect(keys, contains('finance/main/months/2026-09/entries/rent'));
      expect(keys, contains('notes/tl1/lines/t1'));
      expect(keys, contains('notes/sl1/lines/s1'));
      expect(keys, contains('meals/2026/months/09/days/24'));
      expect(keys, contains('calendar/main/months/2026-09/events/ev1'));
      expect(keys, contains('finance/main/months/2026-09'));
      final month = normalizedRecords(_ws())['finance/main/months/2026-09']!;
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

    ExpenseItem gen(String id, {bool paid = false, bool exception = false}) =>
        ExpenseItem.fromJson({
          ..._item(id, paid: paid).toJson(),
          'generated': true,
          'seriesId': 's1',
          if (exception) 'exception': true,
        });

    // The series' explicit anchor lives in an earlier (closed) month.
    Workspace withAnchor(Workspace ws) {
      final anchor = ExpenseItem.fromJson({
        ..._item('a1').toJson(),
        'recurring': true,
        'seriesId': 's1',
      });
      ws.data[2026]!['August'] = MonthData(closed: true)
        ..blocks['home'] = [anchor];
      return ws;
    }

    test('untouched generated copies in open months are not stored', () {
      final ws = withAnchor(
        _ws(
          home: [
            gen('g1'),
            _item('rent'),
            gen('g2', paid: true),
            gen('g3', exception: true),
            _item('water'),
          ],
        ),
      );
      final recs = normalizedRecords(ws);
      expect(
        recs.containsKey('finance/main/months/2026-09/recurring/g1'),
        isFalse,
      );
      expect(
        recs.containsKey('finance/main/months/2026-09/recurring/g2'),
        isTrue,
      );
      expect(
        recs.containsKey('finance/main/months/2026-09/recurring/g3'),
        isTrue,
      );
      // `_order` counts stored items only.
      expect(recs['finance/main/months/2026-09/entries/rent']!['_order'], 0);
      expect(recs['finance/main/months/2026-09/recurring/g2']!['_order'], 1);
      expect(recs['finance/main/months/2026-09/recurring/g3']!['_order'], 2);
      expect(recs['finance/main/months/2026-09/entries/water']!['_order'], 3);
      // Adding/removing a derived copy never rewrites stored items.
      final without = normalizedRecords(
        withAnchor(
          _ws(
            home: [
              _item('rent'),
              gen('g2', paid: true),
              gen('g3', exception: true),
              _item('water'),
            ],
          ),
        ),
      );
      final plan = planRecordWrites(_server(recs), without);
      expect(plan.creates, isEmpty);
      expect(plan.updates, isEmpty);
      expect(plan.deletes, isEmpty);
    });

    test('generated copies in closed months stay stored', () {
      final ws = withAnchor(_ws(home: [gen('g1')]));
      ws.data[2026]!['September']!.closed = true;
      expect(
        normalizedRecords(
          ws,
        ).containsKey('finance/main/months/2026-09/recurring/g1'),
        isTrue,
      );
    });

    test('copies of a series without an explicit anchor stay stored', () {
      final ws = _ws(home: [gen('g1')]);
      expect(
        normalizedRecords(
          ws,
        ).containsKey('finance/main/months/2026-09/recurring/g1'),
        isTrue,
      );
      // ...as do copies in a different block than the anchor.
      final other = withAnchor(_ws());
      other.data[2026]!['September']!.blocks['food'] = [gen('g1')];
      expect(
        normalizedRecords(
          other,
        ).containsKey('finance/main/months/2026-09/recurring/g1'),
        isTrue,
      );
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
      expect(plan.updates.keys, ['notes/sl1/lines/s1']);
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
      expect(plan.updates.keys, ['finance/main/months/2026-09/entries/rent']);
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

    test('every record lives at a known path, in a loaded collection', () {
      for (final key in normalizedRecords(_ws()).keys) {
        expect(recordKind(key), isNot(RecordKind.unknown), reason: key);
        expect(kRecordCollections, contains(recordSource(key)), reason: key);
      }
    });
  });

  group('legacy migration', () {
    test('legacy section docs yield the same records as the new layout', () {
      final ws = _ws();
      final legacy = workspaceSections(ws)..remove('settings');
      final recs = legacyRecords(legacy);
      final expected = normalizedRecords(ws);
      for (final k in [
        'finance/main/months/2026-09/entries/rent',
        'notes/tl1/lines/t2',
        'notes/sl1/lines/s1',
        'meals/2026/months/09/days/24',
        'calendar/main/months/2026-09/events/ev1',
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
      final recs = normalizedRecords(_ws())..remove(kKitchenKey);
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
      const key = 'meals/2026/months/09/days/28';
      Map<String, dynamic> rec(DayPlan p) => normalizeRecord(key, p.toJson())!;
      final a = rec(DayPlan(dateIso: '2026-09-28', dinner: 'Pasta'));
      final b = rec(DayPlan(dateIso: '2026-09-28', lunch: 'Soup'));
      var doc = mergeSet(null, createPayload(key, a));
      doc = mergeSet(doc, createPayload(key, b));
      final out = normalizeRecord(key, doc)!;
      expect(out['dinner'], 'Pasta');
      expect(out['lunch'], 'Soup');
    });

    test('a generated occurrence created late never un-pays it', () {
      const key = 'finance/main/months/2026-09/recurring/g_rent_2026_8';
      Map<String, dynamic> rec(bool paid) => normalizeRecord(key, {
        ..._item('g_rent_2026_8', paid: paid).toJson(),
        'generated': true,
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
      const key = 'finance/main/months/2026-10';
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
          if (e.key != listMetaKey('tl1')) e.key: e.value,
      };
      final local = normalizedRecords(workspaceFromRecords(base));
      expect(
        local.keys.where((k) => k.startsWith('notes/tl1/lines/')),
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
        ).deletes.where((k) => k.startsWith('notes/tl1/lines/')),
        hasLength(2),
      );
    });
  });

  group('unintendedDeletes', () {
    Workspace shopWs(List<String> items) => Workspace.empty()
      ..shoppingLists = [
        ShoppingList(
          id: 'L',
          name: 'Groceries',
          items: [for (final i in items) ShopItem(id: i, name: i)],
        ),
      ];

    test('a list vanishing locally is never deleted from the server', () {
      final base = normalizedRecords(shopWs(['a', 'b', 'c']));
      final local = normalizedRecords(Workspace.empty());
      local.addAll(orphanListItems(base, local));
      final plan = planRecordWrites(base, local);
      expect(plan.deletes, contains(listMetaKey('L')));
      final lost = unintendedDeletes(base, plan.deletes, {});
      expect(lost.keys, containsAll(plan.deletes.where(isGuardedRecord)));
      expect(lost, hasLength(4));
      // Restoring them brings the whole list back.
      final healed = workspaceFromRecords({...local, ...lost});
      expect(healed.shoppingLists.single.items.map((i) => i.id), [
        'a',
        'b',
        'c',
      ]);
    });

    test('an unpinned list and all its lines may be deleted', () {
      final base = normalizedRecords(shopWs(['a', 'b']));
      final local = normalizedRecords(Workspace.empty());
      final plan = planRecordWrites(base, local);
      final lost = unintendedDeletes(base, plan.deletes, {listMetaKey('L')});
      expect(lost, isEmpty);
    });

    test('only the crossed-off line may be deleted', () {
      final base = normalizedRecords(shopWs(['a', 'b', 'c']));
      final local = normalizedRecords(shopWs(['c']));
      final plan = planRecordWrites(base, local);
      final lost = unintendedDeletes(base, plan.deletes, {
        listItemKey('L', 'a'),
      });
      expect(lost.keys, [listItemKey('L', 'b')]);
    });

    test('only lists, lines and events are guarded', () {
      expect(isGuardedRecord('calendar/main/recurring/e1'), isTrue);
      expect(isGuardedRecord('calendar/main/months/2026-10/events/e1'), isTrue);
      expect(isGuardedRecord('cards/x'), isFalse);
      expect(isGuardedRecord('finance/main/months/2026-10/entries/x'), isFalse);
      expect(isGuardedRecord(listMetaKey('T')), isTrue);
      expect(isGuardedRecord(listItemKey('T', 'l')), isTrue);
    });
  });

  group('event deletion', () {
    CalendarEvent ev(String id) => CalendarEvent(
      id: id,
      title: 'Event $id',
      date: '2026-10-07',
      color: const Color(0xff1684B4),
    );

    Workspace calWs(List<CalendarEvent> live) =>
        Workspace.empty()..events = live;

    String evKey(String id) => eventRecordKey(ev(id));

    test('one-off events live under their month, repeating ones apart', () {
      expect(evKey('a'), 'calendar/main/months/2026-10/events/a');
      expect(
        eventRecordKey(ev('r')..recur = 'weekly'),
        'calendar/main/recurring/r',
      );
      final recs = normalizedRecords(calWs([ev('a')]));
      expect(recs['calendar/main/months/2026-10'], <String, dynamic>{});
    });

    test('an event moved to another month is not an unintended delete', () {
      final base = normalizedRecords(calWs([ev('a')]));
      final moved = ev('a')..date = '2026-11-02';
      final local = normalizedRecords(calWs([moved]));
      final plan = planRecordWrites(base, local);
      expect(plan.deletes, contains(evKey('a')));
      expect(plan.creates.keys, contains(eventRecordKey(moved)));
      expect(unintendedDeletes(base, plan.deletes, {}, local: local), isEmpty);
      expect(unintendedDeletes(base, plan.deletes, {}), isNotEmpty);
    });

    test('a stale copy at an old path never duplicates an event', () {
      final a = normalizedRecords(calWs([ev('a')]));
      final moved = ev('a')..date = '2026-11-02';
      final b = normalizedRecords(calWs([moved]));
      final ws = workspaceFromRecords({...a, ...b});
      expect(ws.events.map((e) => e.id), ['a']);
    });

    test('an event vanishing locally is never deleted from the server', () {
      final base = normalizedRecords(calWs([ev('a'), ev('b')]));
      final local = normalizedRecords(calWs([ev('b')]));
      final plan = planRecordWrites(base, local);
      expect(plan.deletes, [evKey('a')]);
      final lost = unintendedDeletes(base, plan.deletes, {});
      expect(lost.keys, [evKey('a')]);
      final healed = workspaceFromRecords({...local, ...lost});
      expect(healed.events.map((e) => e.id), ['a', 'b']);
    });

    test('an event the user deleted is a plain delete', () {
      final base = normalizedRecords(calWs([ev('a'), ev('b')]));
      final local = normalizedRecords(calWs([ev('b')]));
      final plan = planRecordWrites(base, local);
      expect(plan.deletes, [evKey('a')]);
      expect(plan.updates, isEmpty);
      expect(unintendedDeletes(base, plan.deletes, {evKey('a')}), isEmpty);
    });

    test('legacy tombstones are dropped when read', () {
      final rec = normalizedRecords(calWs([ev('a')]))[evKey('a')]!;
      final dead = {
        ...rec,
        'deletion': {
          'by': 'A',
          'at': 1,
          'acks': {'A': 1},
        },
      };
      expect(normalizeRecord(evKey('a'), dead), isNull);
      final legacy = calWs([ev('live')]).toJson()
        ..['deletedEvents'] = [ev('gone').toJson()];
      final back = Workspace.fromJson(legacy);
      expect(back.events.map((e) => e.id), ['live']);
      expect(back.toJson().containsKey('deletedEvents'), isFalse);
    });

    test('a deletion arriving from the server wins over a local edit', () {
      final base = normalizedRecords(calWs([ev('a'), ev('b')]));
      final edited = ev('a')..title = 'Renamed';
      final local = normalizedRecords(calWs([edited, ev('b')]));
      final server = normalizedRecords(calWs([ev('b')]));
      final merged = rebaseRecords(
        oldBase: base,
        newBase: server,
        local: local,
        changed: [evKey('a')],
      );
      expect(merged.containsKey(evKey('a')), isFalse);
      expect(workspaceFromRecords(merged).events.map((e) => e.id), ['b']);
    });
  });

  group('note deletion', () {
    Workspace shopWs(List<String> items) => Workspace.empty()
      ..shoppingLists = [
        ShoppingList(
          id: 'L',
          name: 'Groceries',
          items: [for (final i in items) ShopItem(id: i, name: i)],
        ),
      ];
    final meta = listMetaKey('L');
    final lineA = listItemKey('L', 'a');
    final lineB = listItemKey('L', 'b');

    test('legacy note / line tombstones are dropped when read', () {
      final base = normalizedRecords(shopWs(['a']));
      Map<String, dynamic> dead(Map<String, dynamic> r) => {
        ...r,
        'deletion': {
          'by': 'u1',
          'at': 1,
          'acks': {'u1': 1},
        },
      };
      expect(normalizeRecord(meta, dead(base[meta]!)), isNull);
      expect(normalizeRecord(lineA, dead(base[lineA]!)), isNull);
    });

    test('deleting a note deletes its lines too', () {
      final base = normalizedRecords(shopWs(['a', 'b']));
      final plan = planRecordWrites(base, {});
      expect(plan.deletes, containsAll([meta, lineA, lineB]));
      // Only the note was deleted explicitly: its lines go with it.
      expect(unintendedDeletes(base, plan.deletes, {meta}), isEmpty);
    });

    test('lines of a note deleted elsewhere are not orphans to keep', () {
      final base = normalizedRecords(shopWs(['a']))..remove(meta);
      expect(orphanListItems(base, {}).keys, [lineA]);
    });

    test('a local edit of a line deleted remotely is dropped', () {
      final oldBase = normalizedRecords(shopWs(['a']));
      final newBase = {...oldBase}..remove(lineA);
      final edited = normalizedRecords(
        Workspace.empty()
          ..shoppingLists = [
            ShoppingList(
              id: 'L',
              name: 'Groceries',
              items: [ShopItem(id: 'a', name: 'Milk')],
            ),
          ],
      );
      final merged = rebaseRecords(
        oldBase: oldBase,
        newBase: newBase,
        local: edited,
        changed: [lineA],
      );
      expect(merged.containsKey(lineA), isFalse);
      expect(workspaceFromRecords(merged).shoppingLists.single.items, isEmpty);
    });
  });
}
