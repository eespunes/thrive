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

/// Splits [ws] into per-item documents for the `workspace` subcollection: a
/// settings doc, one doc per discount card (`card_<id>`), per task/shopping list
/// (`list_task_<id>`/`list_shop_<id>`), per budget month (`budget_<year>_<month>`),
/// per imported calendar (`import_<id>`), plus the weekly plan. Fine-grained docs
/// keep each write/download small AND let two members edit different items
/// without overwriting each other's whole-array doc (the concurrent-edit
/// data-loss bug). Each stays far below Firestore's 1 MB limit (the old single
/// workspace doc also overflowed Android's ~2 MB CursorWindow).
///
/// [includeEvents] controls whether per-year `events_<year>` docs are emitted.
/// LOCAL persistence keeps events in these section docs (single device, no
/// concurrent-write conflict). The CLOUD path passes `false` and instead stores
/// each event as its own doc under `families/{fid}/events/{eventId}` (see
/// `_persistFamilyEvents` / [diffEventDocs]) so two members editing different
/// events can't overwrite each other's whole-array section doc.
Map<String, Map<String, dynamic>> workspaceSections(
  Workspace ws, {
  bool includeEvents = true,
}) => {
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
  // Per-year event docs — emitted for LOCAL persistence only. The cloud path
  // passes includeEvents:false and stores events per-doc (see the doc comment
  // above and _persistFamilyEvents). Legacy cloud events_*/events docs are read
  // once by [workspaceFromSections] to seed the per-event migration.
  if (includeEvents)
    for (final entry in eventsByYear(ws.events).entries)
      'events_${entry.key}': {
        'events': entry.value.map((e) => e.toJson()).toList(),
      },
  // One doc per discount card (`card_<id>`) instead of a single `cards` doc
  // holding the whole array, so two members editing DIFFERENT cards can't
  // overwrite each other. Card photos are local-only (issue #234) — the synced
  // payload never carries them, so they stay on the family's devices.
  for (final c in ws.cards) 'card_${c.id}': c.toJson(includePhoto: false),
  // One doc per task/shopping list. taskLists and shoppingLists are separate id
  // spaces, so distinct prefixes keep their docs from colliding.
  for (final l in ws.taskLists) 'list_task_${l.id}': l.toJson(),
  for (final l in ws.shoppingLists) 'list_shop_${l.id}': l.toJson(),
  'weekly': {
    'weeklyPlan': {
      for (final e in ws.weeklyPlan.entries) e.key: e.value.toJson(),
    },
  },
  // One doc per budget month (`budget_<year>_<month>`) instead of one
  // `budget_<year>` doc holding every month, so editing different months no
  // longer conflicts. Month names carry no underscore (kMonthKeys), so the id
  // splits cleanly back into year + month on read.
  for (final entry in ws.data.entries)
    for (final m in entry.value.entries)
      'budget_${entry.key}_${m.key}': m.value.toJson(),
  for (final (i, cal) in ws.importedCalendars.indexed)
    'import_${cal.id}': {'calendar': cal.toJson(), 'order': i},
};

/// Section ids that hold actual family DATA (events, budgets, lists, cards,
/// imported calendars, weekly plan) as opposed to the lightweight `settings`
/// doc or the `__meta` marker. Used by the empty-workspace safety net.
bool isWorkspaceContentSection(String id) => id != '__meta' && id != 'settings';

/// True when [sections] carries at least one content section that actually
/// holds data. NOTE the subtlety this guards: [workspaceSections] always emits
/// a `weekly` key (an empty container) even for an empty workspace, so mere
/// key-presence is not proof of data — an empty workspace would look
/// "content-bearing" and defeat the wipe guard. We instead diff each content
/// section against the same section built from [Workspace.empty]: a doc is real
/// content only if it's absent from that template (e.g. `card_*`, `list_*`,
/// `events_2026`, `budget_2026_*`, `import_*`) or its payload differs.
bool _workspaceHasRealContent(Map<String, Map<String, dynamic>> sections) {
  final empty = workspaceSections(Workspace.empty());
  return sections.entries.any(
    (e) =>
        isWorkspaceContentSection(e.key) &&
        (!empty.containsKey(e.key) ||
            sectionDigest(empty[e.key]!) != sectionDigest(e.value)),
  );
}

/// The safety net that stops an empty/unloaded workspace from wiping a family.
///
/// Several persist callers substitute a `Workspace.empty()` when a family's
/// subcollection hasn't finished loading on this device. That empty workspace
/// carries no real data, so a persist would DELETE the server's
/// `card_*`/`list_*`/`budget_*`/`import_*` docs (stale-section sweep) —
/// destroying data that merely failed to load. (This is exactly how a legacy
/// family's 91-event `events` doc was lost.)
///
/// Returns true when the persist must be ABORTED: [producedSections] holds no
/// real content, yet the server does. [serverDigests] is the last-known
/// per-section digest map (`id -> sectionDigest(payload)`); a server section is
/// real content when it has no counterpart in an empty workspace (`events_*`,
/// `budget_*`, `import_*`) or its digest differs from the empty template's — so
/// this catches both the delete and the overwrite paths. When the local
/// workspace carries any real data — including the last edit of a genuine
/// clear-everything — it persists normally.
bool emptyWorkspacePersistWouldWipe(
  Map<String, Map<String, dynamic>> producedSections,
  Map<String, String> serverDigests,
) {
  if (_workspaceHasRealContent(producedSections)) return false;
  final emptyDigests = {
    for (final e in workspaceSections(Workspace.empty()).entries)
      e.key: sectionDigest(e.value),
  };
  return serverDigests.entries.any(
    (e) => isWorkspaceContentSection(e.key) && e.value != emptyDigests[e.key],
  );
}

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
  j['weeklyPlan'] = sections['weekly']?['weeklyPlan'] ?? {};

  // Cards, lists and budget were split from single-array docs (`cards`,
  // `lists`, `budget_<year>`) into per-item docs (`card_<id>`,
  // `list_task_<id>`/`list_shop_<id>`, `budget_<year>_<month>`). Read BOTH
  // shapes and let the newer per-item doc win on an id/key clash so a family
  // mid-migration (both forms briefly present) neither drops nor duplicates.
  final cardsById = <String, dynamic>{};
  final taskListsById = <String, dynamic>{};
  final shopListsById = <String, dynamic>{};
  final data = <String, Map<String, dynamic>>{};
  final imports = <Map<String, dynamic>>[];
  void takeById(Map<String, dynamic> byId, Object? item) {
    if (item is Map) {
      final id = item['id']?.toString() ?? '';
      if (id.isNotEmpty) byId[id] = item;
    }
  }

  // Legacy coarse docs first; the per-item loop below overrides on clash.
  for (final c in sections['cards']?['cards'] as List? ?? const []) {
    takeById(cardsById, c);
  }
  for (final l in sections['lists']?['taskLists'] as List? ?? const []) {
    takeById(taskListsById, l);
  }
  for (final l in sections['lists']?['shoppingLists'] as List? ?? const []) {
    takeById(shopListsById, l);
  }
  for (final id in sections.keys.toList()..sort()) {
    final map = sections[id]!;
    if (id.startsWith('card_')) {
      takeById(cardsById, map);
    } else if (id.startsWith('list_task_')) {
      takeById(taskListsById, map);
    } else if (id.startsWith('list_shop_')) {
      takeById(shopListsById, map);
    } else if (id.startsWith('budget_')) {
      final rest = id.substring('budget_'.length);
      final sep = rest.indexOf('_');
      if (sep < 0) {
        // Legacy `budget_<year>` doc holding a months map.
        final months = map['months'];
        if (months is Map) {
          final year = data.putIfAbsent(rest, () => {});
          months.forEach((mk, mv) => year.putIfAbsent(mk.toString(), () => mv));
        }
      } else {
        // Per-month `budget_<year>_<month>` doc — wins over the legacy month.
        data.putIfAbsent(
          rest.substring(0, sep),
          () => {},
        )[rest.substring(sep + 1)] = map;
      }
    } else if (id.startsWith('import_') && map['calendar'] is Map) {
      imports.add({
        ...Map<String, dynamic>.from(map['calendar'] as Map),
        '_order': (map['order'] as num?)?.toInt() ?? imports.length,
      });
    }
  }
  j['cards'] = cardsById.values.toList();
  j['taskLists'] = taskListsById.values.toList();
  j['shoppingLists'] = shopListsById.values.toList();
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

/// Digest of a single calendar event's synced payload — the per-event analogue
/// of [sectionDigest]. Used to skip unchanged event docs on persist and to
/// detect which events another member changed.
String eventDocDigest(CalendarEvent e) => sectionDigest(e.toJson());

/// Diffs the in-memory [local] events against the per-event digests we last
/// synced to the server ([serverDigests]: eventId -> [eventDocDigest]), the
/// per-document analogue of the section write-loop + stale sweep in
/// `_persistFamilySections`. Because each result touches only its own
/// `families/{fid}/events/{eventId}` doc, two members editing different events
/// never overwrite each other.
///
/// - `writes`: events whose digest differs from `serverDigests` (new or edited).
/// - `deletes`: ids present in `serverDigests` but no longer in `local`.
///
/// Duplicate local ids are collapsed (last wins) so a doc is written once.
({List<CalendarEvent> writes, List<String> deletes}) diffEventDocs(
  List<CalendarEvent> local,
  Map<String, String> serverDigests,
) {
  final localById = {for (final e in local) e.id: e};
  final writes = <CalendarEvent>[];
  localById.forEach((id, e) {
    if (serverDigests[id] != eventDocDigest(e)) writes.add(e);
  });
  final deletes = [
    for (final id in serverDigests.keys)
      if (!localById.containsKey(id)) id,
  ];
  return (writes: writes, deletes: deletes);
}

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
/// Merges one budget month (a `{blocks, caps, closed, …}` map) present both
/// locally and remotely: month-level fields (caps, closed, snapshots) keep the
/// local version, and each `blocks` expense list is unioned by item id; block
/// categories only present remotely are added. Falls back to [local] wholesale
/// on any unexpected shape.
Map<String, dynamic> _mergeBudgetMonth(
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) {
  final localBlocks = local['blocks'];
  final remoteBlocks = remote['blocks'];
  if (localBlocks is! Map || remoteBlocks is! Map) return local;
  final blocks = <String, dynamic>{
    for (final e in localBlocks.entries) e.key.toString(): e.value,
  };
  remoteBlocks.forEach((bk, remoteList) {
    final key = bk.toString();
    blocks[key] = blocks.containsKey(key)
        ? (_unionById(blocks[key], remoteList) ?? blocks[key])
        : remoteList;
  });
  return {...local, 'blocks': blocks};
}

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
    out[mk] = _mergeBudgetMonth(
      Map<String, dynamic>.from(localMonthRaw),
      Map<String, dynamic>.from(remoteMonthRaw),
    );
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
  // A per-card `card_<id>` doc holds a single card — no sub-items to union, so
  // dirty-local-wins (the pending persist re-uploads our edit); two members
  // editing the SAME card is last-write-wins, the accepted shallow trade-off.
  if (id.startsWith('card_')) return local;
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
    return {...local, 'taskLists': ?tasks, 'shoppingLists': ?shopping};
  }
  // Per-list docs: union the inner items by id so concurrent additions to the
  // SAME list survive; list-level fields (name, colour) keep the local version.
  if (id.startsWith('list_task_')) {
    return _mergeListContainer('tasks', local, remote);
  }
  if (id.startsWith('list_shop_')) {
    return _mergeListContainer('items', local, remote);
  }
  if (id.startsWith('budget_')) {
    // Legacy `budget_<year>` doc carries a `months` map; a per-month
    // `budget_<year>_<month>` doc carries `blocks` directly.
    final localMonths = local['months'];
    final remoteMonths = remote['months'];
    if (localMonths is Map && remoteMonths is Map) {
      return {
        ...local,
        'months': _mergeBudgetMonths(
          Map<String, dynamic>.from(localMonths),
          Map<String, dynamic>.from(remoteMonths),
        ),
      };
    }
    return _mergeBudgetMonth(local, remote);
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
