part of 'package:family_money_management_app/main.dart';

/// Pure (de)serialization layer between the in-memory models and the
/// Firestore family documents. Everything here is a plain function of its
/// inputs — no widget state, no I/O — so the persistence core is unit-tested
/// (see test/workspace_sections_test.dart) instead of living untestably
/// inside the app shell.

/// Family metadata document — everything EXCEPT the workspace, which lives
/// in the `workspace` subcollection (one doc per section) so a budget edit
/// no longer rewrites — and re-downloads, on every member's device — the
/// whole multi-MB family blob.
// FieldValue.serverTimestamp() needs the Firestore platform plumbing, so this
// builder is only exercised against a live backend.
// coverage:ignore-start
Map<String, dynamic> familyMetaDoc(Family f) => {
  'name': f.name,
  'username': f.username,
  if (f.picture != null) 'picture': f.picture,
  'ownerUid': f.ownerUid,
  'memberUids': f.memberUids,
  'members': f.members.map((m) => m.toJson()).toList(),
  'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
  'updatedAt': FieldValue.serverTimestamp(),
};
// coverage:ignore-end

/// Buckets events by their anchor date's year ("2026"). Recurring series
/// live in their start year regardless of how far they expand; malformed
/// dates land in a shared "0000" bucket rather than being dropped.
Map<String, List<CalendarEvent>> eventsByYear(List<CalendarEvent> events) {
  final out = <String, List<CalendarEvent>>{};
  for (final e in events) {
    final year = e.date.length >= 4 ? e.date.substring(0, 4) : '0000';
    (out[year] ??= []).add(e);
  }
  return out;
}

/// Splits [ws] into per-section documents for the `workspace` subcollection:
/// one settings doc, one doc per budget year, one per **events year**, one
/// per imported calendar (the largest, most independently-changing pieces),
/// plus lists and the weekly plan. Each stays far below Firestore's 1 MB doc
/// limit — a single all-events doc used to overflow it at ~3,000 events —
/// so offline persistence can stay enabled (the old single workspace doc
/// also overflowed Android's ~2 MB CursorWindow) and every edit only
/// uploads its own section.
Map<String, Map<String, dynamic>> workspaceSections(Workspace ws) => {
  'settings': {
    'accounts': ws.accounts.map((a) => a.toJson()).toList(),
    'cats': ws.cats.map((c) => c.toJson()).toList(),
    'eventCategories': ws.eventCategories.map((c) => c.toJson()).toList(),
    'calendarLayers': ws.calendarLayers.map((l) => l.toJson()).toList(),
    if (ws.starsMap.isNotEmpty) 'starsMap': ws.starsMap,
    'kitchenEnabled': ws.kitchenEnabled,
    if (ws.picMembers.isNotEmpty) 'picMembers': ws.picMembers,
    'kitchenLayerFilter': ws.kitchenLayerFilter,
  },
  for (final entry in eventsByYear(ws.events).entries)
    'events_${entry.key}': {
      'events': entry.value.map((e) => e.toJson()).toList(),
    },
  // Card photos are local-only (issue #234) — the synced payload never
  // carries them, so they stay on the devices of the family.
  'cards': {
    'cards': ws.cards.map((c) => c.toJson(includePhoto: false)).toList(),
  },
  'lists': {
    'taskLists': ws.taskLists.map((l) => l.toJson()).toList(),
    'shoppingLists': ws.shoppingLists.map((l) => l.toJson()).toList(),
  },
  'weekly': {
    'weeklyPlan': {
      for (final e in ws.weeklyPlan.entries) e.key: e.value.toJson(),
    },
  },
  for (final entry in ws.data.entries)
    'budget_${entry.key}': {
      'months': {for (final m in entry.value.entries) m.key: m.value.toJson()},
    },
  for (final (i, cal) in ws.importedCalendars.indexed)
    'import_${cal.id}': {'calendar': cal.toJson(), 'order': i},
};

/// Rebuilds a [Workspace] from its subcollection section docs. Returns null
/// when [sections] is empty (family not yet migrated off the legacy single
/// `workspace` map — the caller falls back to [workspaceFromDoc]).
Workspace? workspaceFromSections(Map<String, Map<String, dynamic>> sections) {
  if (sections.isEmpty) return null;
  final j = <String, dynamic>{...?sections['settings']};
  // Per-year `events_<year>` docs, keeping any legacy all-events doc from a
  // family that hasn't been rewritten since the year split. A mixed-version
  // family can briefly carry both, so entries are de-duped by id with the
  // sharded (newer-format) docs winning.
  final eventsById = <String, dynamic>{};
  var eventSeq = 0;
  void takeEvents(List? list) {
    for (final e in list ?? const []) {
      final id = e is Map ? (e['id']?.toString() ?? 'seq${eventSeq++}') : '';
      if (id.isNotEmpty) eventsById[id] = e;
    }
  }

  takeEvents(sections['events']?['events'] as List?);
  for (final id in sections.keys.toList()..sort()) {
    if (id.startsWith('events_')) takeEvents(sections[id]?['events'] as List?);
  }
  j['events'] = eventsById.values.toList();
  j['taskLists'] = sections['lists']?['taskLists'] ?? [];
  j['shoppingLists'] = sections['lists']?['shoppingLists'] ?? [];
  j['weeklyPlan'] = sections['weekly']?['weeklyPlan'] ?? {};
  j['cards'] = sections['cards']?['cards'] ?? [];
  final data = <String, dynamic>{};
  final imports = <Map<String, dynamic>>[];
  sections.forEach((id, map) {
    if (id.startsWith('budget_')) {
      data[id.substring('budget_'.length)] = map['months'] ?? {};
    } else if (id.startsWith('import_') && map['calendar'] is Map) {
      imports.add({
        ...Map<String, dynamic>.from(map['calendar'] as Map),
        '_order': (map['order'] as num?)?.toInt() ?? imports.length,
      });
    }
  });
  imports.sort((a, b) => (a['_order'] as int).compareTo(b['_order'] as int));
  j['data'] = data;
  j['importedCalendars'] = imports;
  // The settings section always carries `calendarLayers`/`kitchenLayerFilter`
  // keys, so [Workspace.fromJson]'s legacy-backfill never misfires here.
  return Workspace.fromJson(j);
}

/// Section-payload digest used to skip unchanged docs on persist. Computed
/// over the payload only (never the update timestamps), so an identical
/// section written twice digests identically.
String sectionDigest(Map<String, dynamic> payload) =>
    sha256.convert(utf8.encode(json.encode(payload))).toString();

/// Digest over the meta-doc fields the client owns (never the timestamps or
/// join-credential extras like `joinHash`), so a locally built meta doc and
/// an incoming snapshot digest comparably.
String metaDocDigest(Map<String, dynamic> doc) => sectionDigest({
  'name': doc['name'],
  'username': doc['username'],
  'picture': doc['picture'],
  'ownerUid': doc['ownerUid'],
  'memberUids': doc['memberUids'],
  'members': doc['members'],
});

// ------------------------------------------------------- dirty-section merge

/// Decodes [raw] as a list of id-keyed item maps, or null when the shape
/// doesn't match (any non-map entry or missing/empty id) — the caller then
/// falls back to keeping the local payload wholesale.
List<Map<String, dynamic>>? _asIdItemList(Object? raw) {
  if (raw is! List) return null;
  final out = <Map<String, dynamic>>[];
  for (final e in raw) {
    if (e is! Map || (e['id']?.toString() ?? '').isEmpty) return null;
    out.add(Map<String, dynamic>.from(e));
  }
  return out;
}

/// Union of two id-keyed item lists, local-preferring: local items keep their
/// order and content (this device may hold unsaved edits to them); remote-only
/// items are appended in remote order (they are another member's concurrent
/// additions — the lost-update case this merge exists for). Items present
/// only locally are kept too: they are either local additions not yet pushed,
/// or remote deletions — resurrecting a remote-deleted item is the deliberate
/// trade-off versus losing another member's addition. When [combine] is given
/// it merges an item present on both sides (used for nested lists).
/// Returns null when either side's shape is unexpected.
List<Map<String, dynamic>>? _unionById(
  Object? localRaw,
  Object? remoteRaw, {
  Map<String, dynamic> Function(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  )?
  combine,
}) {
  final local = _asIdItemList(localRaw);
  final remote = _asIdItemList(remoteRaw);
  if (local == null || remote == null) return null;
  final localIds = {for (final e in local) e['id'].toString()};
  final remoteById = {for (final e in remote) e['id'].toString(): e};
  return [
    for (final e in local)
      combine != null && remoteById.containsKey(e['id'].toString())
          ? combine(e, remoteById[e['id'].toString()]!)
          : e,
    for (final e in remote)
      if (!localIds.contains(e['id'].toString())) e,
  ];
}

/// Merges one nested list container (a task/shopping list) present both
/// locally and remotely: local list fields win, the inner [itemsKey] items
/// are unioned by id (local versions win, remote-only items appended).
Map<String, dynamic> _mergeListContainer(
  String itemsKey,
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) => {
  ...local,
  itemsKey: _unionById(local[itemsKey], remote[itemsKey]) ?? local[itemsKey],
};

/// Merges a budget `months` map (month key → MonthData json) at item level:
/// months only remote are added; months on both sides keep local fields
/// (caps, closed, open, snapshots) but union each `blocks` expense list by
/// id; block keys only remote are added. Falls back to [local] wholesale on
/// any unexpected shape.
Map<String, dynamic> _mergeBudgetMonths(
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) {
  final out = <String, dynamic>{...local};
  remote.forEach((mk, remoteMonthRaw) {
    final localMonthRaw = local[mk];
    if (localMonthRaw == null) {
      out[mk] = remoteMonthRaw; // month another member just created
      return;
    }
    if (localMonthRaw is! Map || remoteMonthRaw is! Map) return; // keep local
    final localMonth = Map<String, dynamic>.from(localMonthRaw);
    final localBlocks = localMonth['blocks'];
    final remoteBlocks = remoteMonthRaw['blocks'];
    if (localBlocks is! Map || remoteBlocks is! Map) return; // keep local
    final blocks = <String, dynamic>{
      for (final e in localBlocks.entries) e.key.toString(): e.value,
    };
    remoteBlocks.forEach((bk, remoteList) {
      final key = bk.toString();
      if (!blocks.containsKey(key)) {
        blocks[key] = remoteList;
      } else {
        blocks[key] = _unionById(blocks[key], remoteList) ?? blocks[key];
      }
    });
    out[mk] = {...localMonth, 'blocks': blocks};
  });
  return out;
}

/// Item-level merge of a locally-dirty section [local] with the server's
/// concurrent version [remote] (see `_bindActiveFamily`'s snapshot merge).
/// Wholesale keeping the dirty local payload — the previous behavior — made
/// the next persist overwrite and permanently delete anything another family
/// member added to the same section concurrently. For sections whose payload
/// is a list of id-keyed items (events, cards, task/shopping lists, budget
/// month blocks) this unions by item id: LOCAL versions win for items on both
/// sides, remote-only items are ADDED, local-only items are KEPT (accepting
/// that a remotely-deleted item may resurrect — losing a deletion is the
/// deliberately chosen lesser evil versus losing an addition). Non-list
/// payloads (`settings`, `weekly`, imports) and anything whose runtime shape
/// doesn't match expectations keep the existing dirty-local-wins behavior.
Map<String, dynamic> mergeDirtySection(
  String id,
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) {
  if (id == 'events' || id.startsWith('events_')) {
    final events = _unionById(local['events'], remote['events']);
    if (events == null) return local;
    return {...local, 'events': events};
  }
  if (id == 'cards') {
    final cards = _unionById(local['cards'], remote['cards']);
    if (cards == null) return local;
    return {...local, 'cards': cards};
  }
  if (id == 'lists') {
    final tasks = _unionById(
      local['taskLists'],
      remote['taskLists'],
      combine: (l, r) => _mergeListContainer('tasks', l, r),
    );
    final shopping = _unionById(
      local['shoppingLists'],
      remote['shoppingLists'],
      combine: (l, r) => _mergeListContainer('items', l, r),
    );
    if (tasks == null && shopping == null) return local;
    return {
      ...local,
      'taskLists': ?tasks,
      'shoppingLists': ?shopping,
    };
  }
  if (id.startsWith('budget_')) {
    final localMonths = local['months'];
    final remoteMonths = remote['months'];
    if (localMonths is! Map || remoteMonths is! Map) return local;
    return {
      ...local,
      'months': _mergeBudgetMonths(
        Map<String, dynamic>.from(localMonths),
        Map<String, dynamic>.from(remoteMonths),
      ),
    };
  }
  return local; // settings / weekly / imports: dirty-local-wins as before
}

/// Legacy single-doc workspace: families that predate the subcollection split
/// still carry the whole workspace as one map on the meta doc.
Workspace workspaceFromDoc(Map<String, dynamic> doc) {
  final raw = doc['workspace'];
  if (raw is Map) {
    return Workspace.fromJson(Map<String, dynamic>.from(raw));
  }
  return Workspace.empty();
}

/// Collapses members that share the same Firebase `uid` down to a single
/// entry (preferring the owner row) so a person who ended up appended more
/// than once no longer shows up repeatedly (issue #125). Invited members have
/// no uid yet and are always preserved as-is. Loading through this also
/// repairs already-corrupted family docs: the de-duped list is what the owner
/// later persists back, cleaning the shared document.
List<FamilyMember> dedupeMembers(List<FamilyMember> members) {
  final indexByUid = <String, int>{};
  final out = <FamilyMember>[];
  for (final m in members) {
    final uid = m.uid ?? '';
    if (uid.isEmpty) {
      out.add(m);
      continue;
    }
    final at = indexByUid[uid];
    if (at == null) {
      indexByUid[uid] = out.length;
      out.add(m);
    } else if (m.role == 'owner' && out[at].role != 'owner') {
      out[at] = m;
    }
  }
  return out;
}
