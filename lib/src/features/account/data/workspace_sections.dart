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
/// This layout is now used only by LOCAL (no-Firebase) persistence; the cloud
/// stores one document per item (see cloud_records.dart). [includeEvents]
/// controls whether per-year `events_<year>` docs are emitted.
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
    for (final entry in eventsByYear([
      ...ws.events,
      ...ws.deletedEvents,
    ]).entries)
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

/// Rebuilds a [Workspace] from its section docs (local storage, and legacy
/// cloud docs during migration). Returns null when [sections] is empty.
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
String sectionDigest(Map<String, dynamic> payload) => sha256
    .convert(utf8.encode(json.encode(_canonicalJson(payload))))
    .toString();

/// [v] with every map's keys sorted, so digests never depend on key order.
Object? _canonicalJson(Object? v) {
  if (v is Map) {
    final keys = [for (final k in v.keys) '$k']..sort();
    return {for (final k in keys) k: _canonicalJson(v[k])};
  }
  if (v is List) return [for (final e in v) _canonicalJson(e)];
  return v;
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
