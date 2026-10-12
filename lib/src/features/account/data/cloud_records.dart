part of 'package:family_money_management_app/main.dart';

/// Pure record layer behind the Firestore sync engine (`family_cloud.dart`).
///
/// Firestore is treated as the family's DATABASE: every piece of shared data
/// is a small document ("record"), the server's version is always adopted,
/// and a device only ever writes the individual fields IT changed. That makes
/// a stale device harmless — it can't push its old copy of anything it didn't
/// touch — which is what lost a member's edits under the old whole-array
/// sections (a partner's phone with an old month re-uploaded it wholesale).
///
/// Layout under `families/{fid}` (collection → one doc per ...):
/// - `workspace/settings`            accounts, categories, layers, kitchen
/// - `workspace/budget_<y>_<month>`  budget month fields (caps, closed, ...)
/// - `workspace/list_task_<id>` / `list_shop_<id>`  list name/colour/emoji
/// - `workspace/card_<id>`           discount card (photo never synced)
/// - `workspace/import_<id>`         imported (ICS) calendar
/// - `budgetItems/<y>_<month>_<id>`  budget entry (+ `_year/_month/_block/_order`)
/// - `listItems/<kind>_<list>_<id>`  task / shopping item (+ `_list/_kind/_order`)
/// - `weekly/<date>`                 weekly-plan day
/// - `events/<id>`                   calendar event
///
/// Every record also carries a version, `_v` ([kVersionField], +1 per save,
/// enforced by firestore.rules) and who saved it last, `_by`. Edits are
/// saved in a transaction against the current version, so a concurrent edit
/// by someone else is merged (different fields) or reported (same field —
/// see [planVersionedSave]). Neither is part of the record's content.
///
/// A record key is `<collection>/<docId>`. Everything here is a plain function
/// of its inputs (unit-tested in test/cloud_records_test.dart).

const String kWorkspaceCol = 'workspace';
const String kEventsCol = 'events';
const String kBudgetItemsCol = 'budgetItems';
const String kListItemsCol = 'listItems';
const String kWeeklyCol = 'weekly';

/// Every per-family collection holding workspace records.
const List<String> kRecordCollections = [
  kWorkspaceCol,
  kEventsCol,
  kBudgetItemsCol,
  kListItemsCol,
  kWeeklyCol,
];

/// The record collections a top-level tab shows, reloaded from the server
/// when that tab is opened (Home and More summarize everything).
List<String> tabCollections(String tab) => switch (tab) {
  'finance' => const [kWorkspaceCol, kBudgetItemsCol],
  'calendar' => const [kWorkspaceCol, kEventsCol],
  'lists' => const [kWorkspaceCol, kListItemsCol],
  'weekly' => const [kWorkspaceCol, kWeeklyCol],
  _ => kRecordCollections,
};

/// Top-level keys that only the pre-record (whole-array) workspace docs carry.
/// Their presence marks a doc as legacy; firestore.rules rejects writes that
/// would (re)introduce them, so an out-of-date app can't push stale arrays.
const List<String> kLegacyWorkspaceKeys = [
  'blocks',
  'income',
  'tasks',
  'items',
  'months',
  'cards',
  'taskLists',
  'shoppingLists',
  'weeklyPlan',
  'events',
];

typedef Records = Map<String, Map<String, dynamic>>;

/// Per-document save counter. Every write bumps it by exactly one (enforced
/// by firestore.rules), so a device knows which version of a record it last
/// saw and whether its own save landed. Never part of the record payload.
const String kVersionField = '_v';

/// Member id (uid) of whoever saved the document last.
const String kUpdatedByField = '_by';

/// The [kVersionField] of raw document [raw] (0 when it never had one).
int recordVersion(Map? raw) => _int(raw?[kVersionField]) ?? 0;

String recordKey(String col, String docId) => '$col/$docId';

(String col, String docId) splitRecordKey(String key) {
  final i = key.indexOf('/');
  return (key.substring(0, i), key.substring(i + 1));
}

/// A Firestore-legal document id derived from [raw] (no `/`, not `.`/`..`).
String safeDocId(String raw) {
  final s = raw.replaceAll('/', '_');
  if (s.isEmpty || s == '.' || s == '..') return '_$s';
  return s;
}

// ------------------------------------------------------------ build records

Map<String, dynamic> _settingsPayload(Workspace ws) => {
  'accounts': ws.accounts.map((a) => a.toJson()).toList(),
  'cats': ws.cats.map((c) => c.toJson()).toList(),
  'eventCategories': ws.eventCategories.map((c) => c.toJson()).toList(),
  'calendarLayers': ws.calendarLayers.map((l) => l.toJson()).toList(),
  if (ws.starsMap.isNotEmpty) 'starsMap': ws.starsMap,
  'kitchenEnabled': ws.kitchenEnabled,
  if (ws.picMembers.isNotEmpty) 'picMembers': ws.picMembers,
  'kitchenLayerFilter': ws.kitchenLayerFilter,
};

Map<String, dynamic> _monthPayload(MonthData m) => {
  ...m.toJson()..remove('blocks'),
  '_blocks': m.blocks.keys.toList(),
};

/// Splits [ws] into its records (not yet normalized — see [normalizedRecords]).
Records workspaceRecords(Workspace ws) {
  final out = <String, Map<String, dynamic>>{};
  out[recordKey(kWorkspaceCol, 'settings')] = _settingsPayload(ws);
  for (final y in ws.data.entries) {
    for (final m in y.value.entries) {
      out[recordKey(kWorkspaceCol, 'budget_${y.key}_${m.key}')] = _monthPayload(
        m.value,
      );
      for (final b in m.value.blocks.entries) {
        for (final (i, it) in b.value.indexed) {
          var id = safeDocId('${y.key}_${m.key}_${it.id}');
          // Ids are unique in practice; never let a duplicate collapse two
          // entries into one doc.
          while (out.containsKey(recordKey(kBudgetItemsCol, id))) {
            id = '$id~';
          }
          out[recordKey(kBudgetItemsCol, id)] = {
            ...it.toJson(),
            '_year': y.key,
            '_month': m.key,
            '_block': b.key,
            '_order': i,
          };
        }
      }
    }
  }
  void listItems(String kind, String listId, List<Map<String, dynamic>> xs) {
    for (final (i, x) in xs.indexed) {
      var id = safeDocId('${kind}_${listId}_${x['id']}');
      while (out.containsKey(recordKey(kListItemsCol, id))) {
        id = '$id~';
      }
      out[recordKey(kListItemsCol, id)] = {
        ...x,
        '_kind': kind,
        '_list': listId,
        '_order': i,
      };
    }
  }

  for (final (i, l) in ws.taskLists.indexed) {
    out[recordKey(kWorkspaceCol, 'list_task_${l.id}')] = {
      ...l.toJson()..remove('tasks'),
      '_order': i,
    };
    listItems('task', l.id, [for (final t in l.tasks) t.toJson()]);
  }
  for (final (i, l) in ws.shoppingLists.indexed) {
    out[recordKey(kWorkspaceCol, 'list_shop_${l.id}')] = {
      ...l.toJson()..remove('items'),
      '_order': i,
    };
    listItems('shop', l.id, [for (final it in l.items) it.toJson()]);
  }
  // Card photos are local-only (issue #234) and never synced.
  for (final (i, c) in ws.cards.indexed) {
    out[recordKey(kWorkspaceCol, 'card_${c.id}')] = {
      ...c.toJson(includePhoto: false),
      '_order': i,
    };
  }
  for (final (i, cal) in ws.importedCalendars.indexed) {
    out[recordKey(kWorkspaceCol, 'import_${cal.id}')] = {
      'calendar': cal.toJson(),
      'order': i,
    };
  }
  for (final e in ws.weeklyPlan.entries) {
    out[recordKey(kWeeklyCol, safeDocId(e.key))] = {
      ...e.value.toJson(),
      '_key': e.key,
    };
  }
  // Tombstones are event docs too (with a `deletion` marker). A deletion
  // wins should an id ever be in both lists (edited while being deleted).
  for (final e in [...ws.events, ...ws.deletedEvents]) {
    out[eventRecordKey(e.id)] = e.toJson();
  }
  return out;
}

// ---------------------------------------------------------------- normalize

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

/// Canonical form of one record, as the models would re-emit it, or null when
/// [raw] isn't a current-format record (legacy/unknown docs). Both sides of
/// every comparison go through this, so serialization details (key order,
/// int-vs-double, defaults a model fills in) never read as a change.
Map<String, dynamic>? normalizeRecord(String key, Map raw) {
  final rec = _normalizeRecord(key, raw);
  // A deleted note / line keeps its deletion marker (see planListDeletions).
  final d = raw['deletion'];
  if (rec != null && d is Map && isListRecord(key)) {
    rec['deletion'] = EventDeletion.fromJson(
      Map<String, dynamic>.from(d),
    ).toJson();
  }
  return rec;
}

Map<String, dynamic>? _normalizeRecord(String key, Map raw) {
  final (col, id) = splitRecordKey(key);
  final j = Map<String, dynamic>.from(raw)
    ..remove('updatedAtMillis')
    ..remove('updatedAt')
    ..remove(kVersionField)
    ..remove(kUpdatedByField);
  switch (col) {
    case kEventsCol:
      return CalendarEvent.fromJson(j).toJson();
    case kBudgetItemsCol:
      final y = _int(j['_year']);
      final m = j['_month']?.toString();
      final b = j['_block']?.toString();
      if (y == null || m == null || b == null) return null;
      return {
        ...ExpenseItem.fromJson(j).toJson(),
        '_year': y,
        '_month': m,
        '_block': b,
        '_order': _int(j['_order']) ?? 0,
      };
    case kListItemsCol:
      final kind = j['_kind']?.toString();
      final list = j['_list']?.toString();
      if (list == null || (kind != 'task' && kind != 'shop')) return null;
      return {
        ...(kind == 'task'
            ? ListTask.fromJson(j).toJson()
            : ShopItem.fromJson(j).toJson()),
        '_kind': kind,
        '_list': list,
        '_order': _int(j['_order']) ?? 0,
      };
    case kWeeklyCol:
      return {...DayPlan.fromJson(j).toJson(), '_key': j['_key'] ?? id};
    case kWorkspaceCol:
      if (id == 'settings') {
        return _settingsPayload(Workspace.fromJson({...j, 'data': const {}}));
      }
      if (id.startsWith('budget_')) {
        final rest = id.substring('budget_'.length);
        if (!rest.contains('_')) return null; // legacy `budget_<year>`
        final blocks = j.remove('blocks');
        j.remove('income');
        final month = MonthData.fromJson(j);
        return {
          ..._monthPayload(month),
          '_blocks': j['_blocks'] is List
              ? [for (final k in j['_blocks'] as List) k.toString()]
              : blocks is Map
              ? [for (final k in blocks.keys) k.toString()]
              : const <String>[],
        };
      }
      if (id.startsWith('list_task_')) {
        return {
          ...TaskList.fromJson({...j, 'tasks': const []}).toJson()
            ..remove('tasks'),
          '_order': ?_int(j['_order']),
        };
      }
      if (id.startsWith('list_shop_')) {
        return {
          ...ShoppingList.fromJson({...j, 'items': const []}).toJson()
            ..remove('items'),
          '_order': ?_int(j['_order']),
        };
      }
      if (id.startsWith('card_')) {
        return {
          ...DiscountCard.fromJson(j).toJson(includePhoto: false),
          '_order': ?_int(j['_order']),
        };
      }
      if (id.startsWith('import_') && j['calendar'] is Map) {
        return {
          'calendar': ImportedCalendar.fromJson(
            Map<String, dynamic>.from(j['calendar'] as Map),
          ).toJson(),
          'order': _int(j['order']) ?? 0,
        };
      }
      return null;
  }
  return null;
}

/// [workspaceRecords] of [ws], every record normalized.
Records normalizedRecords(Workspace ws) => {
  for (final e in workspaceRecords(ws).entries)
    e.key: normalizeRecord(e.key, e.value) ?? e.value,
};

// ------------------------------------------------------- records → workspace

int _byOrder(Map<String, dynamic> a, Map<String, dynamic> b, String k) {
  final c = (_int(a[k]) ?? 1 << 30).compareTo(_int(b[k]) ?? 1 << 30);
  return c != 0 ? c : '${a['id']}'.compareTo('${b['id']}');
}

Map<String, dynamic> _stripInternal(Map<String, dynamic> m) => {
  for (final e in m.entries)
    if (!e.key.startsWith('_')) e.key: e.value,
};

/// Reassembles a [Workspace] from [records] (keys as in [workspaceRecords]).
/// Unknown keys are ignored; items whose month is missing still load (the
/// month is created); items whose list is missing can't be represented —
/// see [orphanListItems].
Workspace workspaceFromRecords(Records records) {
  final j = <String, dynamic>{
    ...?records[recordKey(kWorkspaceCol, 'settings')],
  };
  final months = <int, Map<String, Map<String, dynamic>>>{};
  final itemsByMonth = <String, List<Map<String, dynamic>>>{};
  final taskLists = <Map<String, dynamic>>[];
  final shopLists = <Map<String, dynamic>>[];
  final listItems = <String, List<Map<String, dynamic>>>{};
  final cards = <Map<String, dynamic>>[];
  final imports = <Map<String, dynamic>>[];
  final weekly = <String, dynamic>{};
  final events = <Map<String, dynamic>>[];

  for (final key in records.keys.toList()..sort()) {
    final r = records[key]!;
    // Deleted notes / lines stay on the server until every member acked;
    // they're never shown.
    if (isListTombstone(key, r)) continue;
    final (col, id) = splitRecordKey(key);
    switch (col) {
      case kEventsCol:
        events.add(r);
      case kBudgetItemsCol:
        final y = _int(r['_year']);
        if (y == null) continue;
        (itemsByMonth['$y|${r['_month']}'] ??= []).add(r);
        months
            .putIfAbsent(y, () => {})
            .putIfAbsent('${r['_month']}', () => <String, dynamic>{});
      case kListItemsCol:
        (listItems['${r['_kind']}|${r['_list']}'] ??= []).add(r);
      case kWeeklyCol:
        weekly['${r['_key'] ?? id}'] = _stripInternal(r);
      case kWorkspaceCol:
        if (id.startsWith('budget_')) {
          final rest = id.substring('budget_'.length);
          final sep = rest.indexOf('_');
          final y = sep < 0 ? null : int.tryParse(rest.substring(0, sep));
          if (y == null) continue;
          months.putIfAbsent(y, () => {})[rest.substring(sep + 1)] = r;
        } else if (id.startsWith('list_task_')) {
          taskLists.add(r);
        } else if (id.startsWith('list_shop_')) {
          shopLists.add(r);
        } else if (id.startsWith('card_')) {
          cards.add(r);
        } else if (id.startsWith('import_') && r['calendar'] is Map) {
          imports.add(r);
        }
    }
  }

  final data = <String, dynamic>{};
  for (final y in months.keys.toList()..sort()) {
    final ym = <String, dynamic>{};
    final keys = months[y]!.keys.toList()
      ..sort((a, b) {
        final ia = kMonthKeys.indexOf(a), ib = kMonthKeys.indexOf(b);
        return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
      });
    for (final mk in keys) {
      final meta = months[y]![mk]!;
      final blocks = <String, List<Map<String, dynamic>>>{
        for (final k in (meta['_blocks'] as List? ?? const [])) '$k': [],
      };
      final items = (itemsByMonth['$y|$mk'] ?? [])
        ..sort((a, b) => _byOrder(a, b, '_order'));
      for (final it in items) {
        (blocks['${it['_block']}'] ??= []).add(_stripInternal(it));
      }
      ym[mk] = {..._stripInternal(meta), 'blocks': blocks};
    }
    data['$y'] = ym;
  }
  j['data'] = data;

  List<Map<String, dynamic>> lists(
    List<Map<String, dynamic>> metas,
    String kind,
    String itemsKey,
  ) {
    metas.sort((a, b) => _byOrder(a, b, '_order'));
    return [
      for (final l in metas)
        {
          ..._stripInternal(l),
          itemsKey: [
            for (final it
                in (listItems['$kind|${l['id']}'] ?? [])
                  ..sort((a, b) => _byOrder(a, b, '_order')))
              _stripInternal(it),
          ],
        },
    ];
  }

  j['taskLists'] = lists(taskLists, 'task', 'tasks');
  j['shoppingLists'] = lists(shopLists, 'shop', 'items');
  cards.sort((a, b) => _byOrder(a, b, '_order'));
  j['cards'] = [for (final c in cards) _stripInternal(c)];
  imports.sort((a, b) => _byOrder(a, b, 'order'));
  j['importedCalendars'] = [for (final c in imports) c['calendar']];
  j['weeklyPlan'] = weekly;
  j['events'] = events;
  return Workspace.fromJson(j);
}

// --------------------------------------------------------- legacy documents

/// True when workspace doc [id] is (or still embeds) the pre-record format:
/// a whole-array doc (`events*`, `lists`, `cards`, `weekly`, `budget_<year>`)
/// or a current id still carrying an embedded array (`blocks`, `tasks`, ...).
bool isLegacyWorkspaceDoc(String id, Map raw) {
  if (id == 'events' || id.startsWith('events_')) return true;
  if (id == 'lists' || id == 'cards' || id == 'weekly') return true;
  if (id.startsWith('budget_') &&
      !id.substring('budget_'.length).contains('_')) {
    return true;
  }
  return id != 'settings' && kLegacyWorkspaceKeys.any(raw.containsKey);
}

/// Whether legacy doc [id] is dropped whole on migration (vs. only having its
/// legacy array fields removed because its id is reused by a current record).
bool legacyDocIsWholeDoc(String id) =>
    id == 'events' ||
    id.startsWith('events_') ||
    id == 'lists' ||
    id == 'cards' ||
    id == 'weekly' ||
    (id.startsWith('budget_') && !id.substring('budget_'.length).contains('_'));

/// Normalized records embedded in legacy workspace docs [legacyDocs] (docId →
/// raw) and/or a legacy family-doc `workspace` [blob]. The settings record is
/// only taken from the blob (legacy section docs never carried settings).
Records legacyRecords(Map<String, Map> legacyDocs, {Map? blob}) {
  final out = <String, Map<String, dynamic>>{};
  if (blob != null) {
    out.addAll(
      normalizedRecords(Workspace.fromJson(Map<String, dynamic>.from(blob))),
    );
  }
  if (legacyDocs.isNotEmpty) {
    final ws = workspaceFromSections({
      for (final e in legacyDocs.entries)
        e.key: Map<String, dynamic>.from(e.value),
    });
    if (ws != null) {
      final recs = normalizedRecords(ws)
        ..remove(recordKey(kWorkspaceCol, 'settings'));
      out.addAll(recs);
    }
  }
  return out;
}

// ------------------------------------------------------------ deep equality

/// Structural JSON equality: map key order is irrelevant and numbers compare
/// by value (`900 == 900.0`).
bool jsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is num && b is num) return a == b;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !jsonEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

// ------------------------------------------------------------- patch/rebase

/// Marker for "field absent" in [rebaseValue].
const Object kAbsent = _Absent();

class _Absent {
  const _Absent();
}

/// One field-level write: [path] segments into the doc, and the new value, or
/// [delete] for a removed field.
class FieldChange {
  const FieldChange(this.path, this.value, {this.delete = false});
  final List<String> path;
  final Object? value;
  final bool delete;
}

/// The field-level changes turning [base] into [local]. Nested maps recurse
/// (so e.g. two members setting caps of different categories both land);
/// lists and scalars are replaced whole.
List<FieldChange> recordPatch(
  Map base,
  Map local, [
  List<String> prefix = const [],
]) {
  final out = <FieldChange>[];
  for (final k in {...base.keys, ...local.keys}) {
    final path = [...prefix, '$k'];
    final hasB = base.containsKey(k), hasL = local.containsKey(k);
    if (hasB && hasL && jsonEquals(base[k], local[k])) continue;
    if (!hasL) {
      out.add(FieldChange(path, null, delete: true));
    } else if (hasB && base[k] is Map && local[k] is Map) {
      out.addAll(recordPatch(base[k] as Map, local[k] as Map, path));
    } else {
      out.add(FieldChange(path, local[k]));
    }
  }
  return out;
}

/// Three-way merge of one value: [o] = last server version this device had,
/// [n] = the server's new version, [l] = this device's current value (any of
/// them may be [kAbsent]).
///
/// - Untouched locally (`l == o`) → the server wins, always.
/// - Server unchanged (`n == o`) → our pending local edit stays.
/// - Both changed → merged per map key where possible (different fields both
///   survive); a genuine same-field conflict keeps the local pending edit,
///   which the next persist writes (last-writer-wins on that one field).
Object? rebaseValue(Object? o, Object? n, Object? l) {
  if (jsonEquals(l, o)) return n;
  if (jsonEquals(n, o)) return l;
  if (o is Map && n is Map && l is Map) {
    final out = <String, dynamic>{};
    for (final k in {...o.keys, ...n.keys, ...l.keys}) {
      final v = rebaseValue(
        o.containsKey(k) ? o[k] : kAbsent,
        n.containsKey(k) ? n[k] : kAbsent,
        l.containsKey(k) ? l[k] : kAbsent,
      );
      if (!identical(v, kAbsent)) out['$k'] = v;
    }
    return out;
  }
  return l;
}

/// Rebases this device's [local] records onto a server change: for every key
/// in [changed], [oldBase] → [newBase] is applied unless this device has its
/// own pending edit of that record (see [rebaseValue]). Keys not in [changed]
/// keep their local value. Returns the merged record set.
Records rebaseRecords({
  required Records oldBase,
  required Records newBase,
  required Records local,
  required Iterable<String> changed,
}) {
  final out = <String, Map<String, dynamic>>{...local};
  for (final k in changed) {
    final v = rebaseValue(
      oldBase[k] ?? kAbsent,
      newBase[k] ?? kAbsent,
      local[k] ?? kAbsent,
    );
    if (identical(v, kAbsent)) {
      out.remove(k);
    } else {
      out[k] = Map<String, dynamic>.from(v as Map);
    }
  }
  return out;
}

/// Field paths that BOTH this device and someone else changed, to different
/// values, since [o] (the version this device last saw): [n] is the server's
/// current version, [l] this device's. Mirrors [rebaseValue]'s merge — maps
/// recurse, so edits to different fields never conflict.
List<List<String>> conflictPaths(
  Object? o,
  Object? n,
  Object? l, [
  List<String> prefix = const [],
]) {
  if (jsonEquals(l, o) || jsonEquals(n, o) || jsonEquals(n, l)) return [];
  if (o is Map && n is Map && l is Map) {
    return [
      for (final k in {...o.keys, ...n.keys, ...l.keys})
        ...conflictPaths(
          o.containsKey(k) ? o[k] : kAbsent,
          n.containsKey(k) ? n[k] : kAbsent,
          l.containsKey(k) ? l[k] : kAbsent,
          [...prefix, '$k'],
        ),
    ];
  }
  return [prefix];
}

/// What a versioned save of one record must write, given [prev] (the
/// version this device last saw), [server] (what the server holds right
/// now, read inside the save's transaction) and [local] (this device's
/// copy): the three-way [merged] record, the field-level [patch] taking
/// [server] to it, and the [conflicts] — fields both sides changed, where
/// this device's value wins (the caller tells the user and offers theirs).
({
  Map<String, dynamic> merged,
  List<FieldChange> patch,
  List<List<String>> conflicts,
})
planVersionedSave({
  required Map<String, dynamic> prev,
  required Map<String, dynamic> server,
  required Map<String, dynamic> local,
}) {
  final merged = Map<String, dynamic>.from(
    rebaseValue(prev, server, local) as Map,
  );
  return (
    merged: merged,
    patch: recordPatch(server, merged),
    conflicts: conflictPaths(prev, server, local),
  );
}

/// [rec] with the value at every path in [paths] taken from [theirs] (or
/// removed where [theirs] lacks it) — "use their version" of a conflict.
Map<String, dynamic> takeTheirs(
  Map<String, dynamic> rec,
  Map<String, dynamic> theirs,
  List<List<String>> paths,
) {
  final out = json.decode(json.encode(rec)) as Map<String, dynamic>;
  for (final path in paths) {
    if (path.isEmpty) return Map<String, dynamic>.from(theirs);
    Map? dst = out;
    Object? src = theirs;
    for (final seg in path.take(path.length - 1)) {
      src = src is Map ? src[seg] : null;
      final next = dst?[seg];
      if (next is! Map) {
        dst = null;
        break;
      }
      dst = next;
    }
    if (dst == null) continue;
    final last = path.last;
    if (src is Map && src.containsKey(last)) {
      dst[last] = src[last];
    } else {
      dst.remove(last);
    }
  }
  return out;
}

/// A human label for record [rec] (event title, budget entry label, note or
/// line name), or '' when it has none.
String recordLabel(Map<String, dynamic> rec) {
  for (final k in const ['title', 'label', 'name']) {
    final v = rec[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

/// List items in [view] whose list is in neither [view] nor [local] — e.g. the
/// items arrived before their list doc. [workspaceFromRecords] can't place
/// them, so callers add these back to the local record set: they must never
/// look "deleted locally" (and be deleted from the server), and must reappear
/// once their list arrives.
Records orphanListItems(Records view, Records local) => {
  for (final e in view.entries)
    if (splitRecordKey(e.key).$1 == kListItemsCol &&
        e.value['deletion'] == null &&
        !local.containsKey(e.key) &&
        !view.containsKey(_listKeyOf(e.value)) &&
        !local.containsKey(_listKeyOf(e.value)))
      e.key: e.value,
};

String _listKeyOf(Map<String, dynamic> item) =>
    listMetaKey('${item['_kind']}', '${item['_list']}');

/// Record key of a list's container doc ([kind] is `task` or `shop`).
String listMetaKey(String kind, String listId) =>
    recordKey(kWorkspaceCol, 'list_${kind}_$listId');

/// Record key of one list line (as built by [workspaceRecords]).
String listItemKey(String kind, String listId, String itemId) =>
    recordKey(kListItemsCol, safeDocId('${kind}_${listId}_$itemId'));

/// Record key of calendar event [eventId] (as built by [workspaceRecords]).
String eventRecordKey(String eventId) =>
    recordKey(kEventsCol, safeDocId(eventId));

/// Whether [key] is a note (task / shopping list) or one of its lines.
bool isListRecord(String key) {
  final (col, id) = splitRecordKey(key);
  return col == kListItemsCol ||
      (col == kWorkspaceCol && id.startsWith('list_'));
}

/// Whether [rec] at [key] is a deleted note / line awaiting every member's
/// acknowledgement (hidden everywhere — see [planListDeletions]).
bool isListTombstone(String key, Map<String, dynamic>? rec) =>
    rec != null && rec['deletion'] is Map && isListRecord(key);

/// Like a deleted [CalendarEvent], a deleted note or line isn't removed from
/// the server right away: the deleting device marks it (`deletion: {by, at,
/// acks}`), every member's device hides it and acknowledges it, and the
/// last acknowledgement deletes it. Given the server [base] and the
/// note/line keys this device ([me]) explicitly deleted ([deletes]), this
/// plans:
/// - [tombstone]: records to mark deleted — [deletes], plus any live line
///   of a deleted note (a line added while the note was being deleted: the
///   deletion wins);
/// - [ack]: deleted records [me] hasn't acknowledged yet, with [me] added;
/// - [purge]: deleted records every one of [members] has acknowledged
///   (counting [me]) — delete these from the server. With no known members
///   [me] is the only one.
({Records tombstone, Records ack, List<String> purge}) planListDeletions({
  required Records base,
  required Iterable<String> deletes,
  required String me,
  required Iterable<String> members,
  required int now,
}) {
  final required = {...members};
  if (required.isEmpty) required.add(me);
  Map<String, dynamic> marked(Map<String, dynamic> rec) => {
    ...rec,
    'deletion': {
      'by': me,
      'at': now,
      'acks': {me: now},
    },
  };
  final tombstone = <String, Map<String, dynamic>>{
    for (final k in deletes)
      if (isListRecord(k) && base[k] != null && !isListTombstone(k, base[k]))
        k: marked(base[k]!),
  };
  base.forEach((k, rec) {
    if (splitRecordKey(k).$1 != kListItemsCol ||
        isListTombstone(k, rec) ||
        tombstone.containsKey(k)) {
      return;
    }
    final listKey = _listKeyOf(rec);
    if (tombstone.containsKey(listKey) ||
        isListTombstone(listKey, base[listKey])) {
      tombstone[k] = marked(rec);
    }
  });
  final ack = <String, Map<String, dynamic>>{};
  base.forEach((k, rec) {
    if (!isListTombstone(k, rec)) return;
    final acks = (rec['deletion'] as Map)['acks'];
    if (acks is Map && acks.containsKey(me)) return;
    final d = Map<String, dynamic>.from(rec['deletion'] as Map);
    ack[k] = {
      ...rec,
      'deletion': {
        ...d,
        'acks': {...?(acks as Map?), me: now},
      },
    };
  });
  final purge = <String>[];
  for (final e in [...tombstone.entries, ...ack.entries]) {
    final acks = (e.value['deletion'] as Map)['acks'] as Map;
    if (required.every(acks.containsKey)) purge.add(e.key);
  }
  base.forEach((k, rec) {
    if (!isListTombstone(k, rec) || ack.containsKey(k)) return;
    final acks = (rec['deletion'] as Map)['acks'];
    if (acks is Map && required.every(acks.containsKey)) purge.add(k);
  });
  for (final k in purge) {
    tombstone.remove(k);
    ack.remove(k);
  }
  return (tombstone: tombstone, ack: ack, purge: purge);
}

/// Lists, their lines and calendar events are only ever deleted from the
/// server when this device explicitly asked for it (see [unintendedDeletes]):
/// the user unpinned the note / crossed off the line, or every member
/// acknowledged an event's deletion ([planEventTombstones]).
bool isGuardedRecord(String key) =>
    isListRecord(key) || splitRecordKey(key).$1 == kEventsCol;

/// The subset of [deletes] (keys in [base]) that would remove a guarded
/// record ([isGuardedRecord]) nobody deleted: one whose key — or, for a list
/// line, whose list — isn't in [intents]. A list or an event vanishing from
/// the in-memory workspace for any other reason (a stale copy, a reverted
/// write, a rebase gone wrong) must never wipe it for the whole family;
/// callers skip these deletes and restore the records locally instead.
Records unintendedDeletes(
  Records base,
  Iterable<String> deletes,
  Set<String> intents,
) {
  bool intended(String key) {
    var k = key;
    while (k.endsWith('~')) {
      k = k.substring(0, k.length - 1);
    }
    if (intents.contains(key) || intents.contains(k)) return true;
    final rec = base[key];
    return splitRecordKey(key).$1 == kListItemsCol &&
        rec != null &&
        intents.contains(_listKeyOf(rec));
  }

  return {
    for (final k in deletes)
      if (isGuardedRecord(k) && base[k] != null && !intended(k)) k: base[k]!,
  };
}

/// Fields that identify where a record lives; always written on create.
const Set<String> _kIdentityKeys = {
  'id',
  '_year',
  '_month',
  '_block',
  '_kind',
  '_list',
  '_key',
};

/// The record this device would hold at [key] had it never seen the server's
/// doc: the model defaults for [local]'s identity (ordering fields are taken
/// from [local] — order is never treated as an edit). A record absent from
/// the base is rebased against this, so only fields this device really
/// changed can override what another member already wrote.
Map<String, dynamic> placeholderRecord(String key, Map<String, dynamic> local) {
  final settingsKey = recordKey(kWorkspaceCol, 'settings');
  if (key == settingsKey) {
    return normalizedRecords(Workspace.empty())[settingsKey]!;
  }
  Map<String, dynamic> d;
  try {
    d = {
      ...?normalizeRecord(key, {
        for (final k in _kIdentityKeys)
          if (local.containsKey(k)) k: local[k],
      }),
    };
  } catch (_) {
    d = {};
  }
  for (final k in const ['_order', '_blocks']) {
    if (local.containsKey(k)) {
      d[k] = local[k];
    } else {
      d.remove(k);
    }
  }
  return d;
}

/// The doc body for CREATING [local] at [key] with `SetOptions(merge: true)`:
/// identity + ordering fields and every field that differs from
/// [placeholderRecord]. Doc ids can be shared across devices (a weekly day,
/// a budget month, a generated recurring item), so a create may land on a
/// doc another member already wrote; this writes only what this device
/// actually set and leaves their other fields intact. Reading it back yields
/// [local] again (missing fields are exactly the model defaults).
Map<String, dynamic> createPayload(
  String key,
  Map<String, dynamic> local, {
  bool includeBlocks = false,
}) {
  final ph = placeholderRecord(key, local);
  return {
    for (final e in local.entries)
      if (_kIdentityKeys.contains(e.key) ||
          e.key == '_order' ||
          (e.key == '_blocks' && includeBlocks) ||
          (e.key != '_blocks' &&
              (!ph.containsKey(e.key) || !jsonEquals(ph[e.key], e.value))))
        e.key: e.value,
  };
}

/// The writes that take the server from [base] to [local]: creates (full
/// doc), field-level updates and deletes — ONLY for records this device
/// changed. A record absent from [base] is never deleted, so data that hasn't
/// loaded can't be wiped by omission.
({
  Records creates,
  Map<String, List<FieldChange>> updates,
  List<String> deletes,
})
planRecordWrites(Records base, Records local) {
  final creates = <String, Map<String, dynamic>>{};
  final updates = <String, List<FieldChange>>{};
  final deletes = <String>[];
  local.forEach((k, l) {
    final b = base[k];
    if (b == null) {
      creates[k] = l;
    } else {
      final p = recordPatch(b, l);
      if (p.isNotEmpty) updates[k] = p;
    }
  });
  for (final k in base.keys) {
    if (!local.containsKey(k)) deletes.add(k);
  }
  return (creates: creates, updates: updates, deletes: deletes);
}

/// True when [local] holds no family data at all (only the settings record,
/// equal to an empty workspace's) — i.e. a placeholder `Workspace.empty()`
/// for a family that hasn't loaded. Persisting that must never delete.
bool recordsAreEmptyPlaceholder(Records local) {
  final empty = normalizedRecords(Workspace.empty());
  return local.keys.every(
    (k) => empty.containsKey(k) && jsonEquals(empty[k], local[k]),
  );
}
