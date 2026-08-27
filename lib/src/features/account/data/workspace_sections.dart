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
