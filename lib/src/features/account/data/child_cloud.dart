part of 'package:family_money_management_app/main.dart';

/// Cloud loading/saving for kid accounts. The family doc's admin-managed
/// `kidUids` map (`{uid: kid member id}`) tells the security rules which
/// logins are kids; for those the rules deny the family-wide reads, so this
/// loads exactly what a kid may see through scoped queries (each one
/// provable by the rules — see firestore.rules):
/// - `settings`, `calendar`, `layers`, `categories`: everything;
/// - `events`, `recurring`: `attendees array-contains <kid member id>` plus
///   `createdBy == <uid>` (the finance `recurring` docs never match);
/// - `meals`, `days`: everything (the meal plan, read-only);
/// - `notes`: `createdBy == <uid>`, and each own note's `lines`;
/// - nothing else (money, cards, imports, month containers).
/// Writes are filtered to the same scope before they leave the device.
/// The kid member id [uid] maps to in a family doc's `kidUids`, or null.
String? kidMemberIdFromDoc(Map<String, dynamic>? data, String? uid) {
  final map = data?['kidUids'];
  final id = uid != null && map is Map ? map[uid]?.toString() : null;
  return id == null || id.isEmpty ? null : id;
}

/// The scoped query tags a kid loads [col] through; empty when the
/// collection is off-limits (`lines` load per own note instead).
List<String> kidQueryTags(String col) => switch (col) {
  kSettingsCol ||
  kCalendarCol ||
  kLayersCol ||
  kCategoriesCol ||
  kMealsCol ||
  kDaysCol => const ['all'],
  kEventsCol || kRecurringCol => const ['attending', 'created'],
  kNotesCol => const ['created'],
  _ => const [],
};

/// Whether a kid collection [col] holds nothing at all.
bool kidOffLimits(String col) => col != kLinesCol && kidQueryTags(col).isEmpty;

/// The note keys in [base] (a kid's base only holds their own notes).
Set<String> kidNoteKeys(Records? base) => {
  for (final k in (base ?? const <String, Map<String, dynamic>>{}).keys)
    if (recordKind(k) == RecordKind.note) k,
};

/// Whether every source feeding [col] has answered at least once.
/// [scoped] is `col → tag → keys` for one family.
bool kidColLoaded(
  String col, {
  required Map<String, Map<String, Set<String>>> scoped,
  required Set<String> loaded,
  required Records base,
}) {
  final tags = scoped[col] ?? const <String, Set<String>>{};
  if (col == kLinesCol) {
    if (!loaded.contains(kNotesCol)) return false;
    return kidNoteKeys(base).every((n) => tags.containsKey('note:$n'));
  }
  return tags.length >= kidQueryTags(col).length;
}

/// Folds one kid-scoped source's docs ([changes]: doc path → raw, null =
/// removed) into [base]. [full] replaces what this [tag] delivered before;
/// a doc only leaves the base once no tag of the collection holds it any
/// more. Marks [col] (and `lines`) loaded once every source answered.
void ingestKidScoped({
  required String fid,
  required String col,
  required String tag,
  required List<(String, Map<String, dynamic>?)> changes,
  required bool full,
  bool fromCache = false,
  required Records base,
  required Map<String, int> versions,
  required Map<String, Map<String, Set<String>>> scoped,
  required Set<String> loaded,
}) {
  final tags = scoped.putIfAbsent(col, () => {});
  final mine = tags.putIfAbsent(tag, () => <String>{});
  // An empty cache answer for a source we hold data for is a cold cache,
  // not "everything was deleted" — wait for the server.
  if (full && fromCache && changes.isEmpty && mine.isNotEmpty) return;
  bool heldElsewhere(String key) =>
      tags.entries.any((e) => e.key != tag && e.value.contains(key));
  void drop(String key) {
    mine.remove(key);
    if (!heldElsewhere(key)) {
      base.remove(key);
      versions.remove(key);
    }
  }

  final prefix = '$kFamiliesCollection/$fid/';
  final seen = <String>{};
  for (final (path, raw) in changes) {
    if (!path.startsWith(prefix)) continue;
    final key = path.substring(prefix.length);
    if (raw == null) {
      drop(key);
      continue;
    }
    seen.add(key);
    mine.add(key);
    final rec = normalizeRecord(key, raw);
    if (rec == null) {
      base.remove(key);
      versions.remove(key);
    } else {
      base[key] = rec;
      versions[key] = recordVersion(raw);
    }
  }
  if (full) {
    for (final key in mine.difference(seen).toList()) {
      drop(key);
    }
  }
  if (col == kNotesCol) {
    // A note that left the kid's scope takes its lines with it.
    final notes = kidNoteKeys(base);
    final lineTags = scoped[kLinesCol];
    if (lineTags != null) {
      for (final t in lineTags.keys.toList()) {
        if (notes.contains(t.substring(5))) continue;
        for (final k in lineTags.remove(t)!) {
          base.remove(k);
          versions.remove(k);
        }
      }
    }
  }
  bool done(String c) =>
      kidColLoaded(c, scoped: scoped, loaded: loaded, base: base);
  if (done(col)) loaded.add(col);
  if (done(kLinesCol)) loaded.add(kLinesCol);
}

/// Whether a kid ([uid], member [kidId]) may write [rec] at [key] —
/// mirrors firestore.rules. [view] resolves a line's parent note.
bool kidMayWriteRecord(
  String key,
  Map<String, dynamic> rec,
  Records view, {
  required String uid,
  required String kidId,
}) {
  switch (recordKind(key)) {
    case RecordKind.event || RecordKind.recurringEvent:
      final attendees = rec['attendees'];
      return rec['createdBy'] == uid ||
          (attendees is List && attendees.contains(kidId));
    case RecordKind.note:
      return rec['createdBy'] == uid;
    case RecordKind.line:
      final note = key.split('/').take(2).join('/');
      return view[note]?['createdBy'] == uid;
    default:
      return false;
  }
}

/// Restricts [local] so a kid's persist only plans writes the rules accept:
/// anything out of scope is pinned to the server's version in [base].
void scopeKidRecords(
  Records base,
  Records local, {
  required String uid,
  required String kidId,
}) {
  final view = {...base, ...local};
  bool may(String key, Map<String, dynamic>? r) =>
      r == null || kidMayWriteRecord(key, r, view, uid: uid, kidId: kidId);
  for (final key in {...local.keys, ...base.keys}) {
    final b = base[key];
    if (may(key, local[key]) && may(key, b)) continue;
    if (b == null) {
      local.remove(key);
    } else {
      local[key] = b;
    }
  }
}

// Cloud-sync glue and Firestore I/O: runs only against a live Firebase
// project (no emulator in widget tests). The scoping logic it delegates to is
// the pure functions above, unit-tested in test/kid_scoping_test.dart.
// coverage:ignore-start
extension _ThriveChildCloud on _ThriveHomeState {
  /// Records whether the signed-in login is a kid in [fid] per its family
  /// doc [data]. Returns true when that status changed.
  bool _noteKidStatus(String fid, Map<String, dynamic>? data) {
    if (data == null) return false;
    final id = kidMemberIdFromDoc(data, _firebaseUid());
    final before = _kidMemberIdByFid[fid];
    if (id == null) {
      _kidMemberIdByFid.remove(fid);
    } else {
      _kidMemberIdByFid[fid] = id;
    }
    return before != _kidMemberIdByFid[fid];
  }

  void _noteKidStatuses(Iterable<MapEntry<String, Map<String, dynamic>>> docs) {
    for (final d in docs) {
      _noteKidStatus(d.key, d.value);
    }
  }

  bool _isKidFamily(String fid) => _kidMemberIdByFid.containsKey(fid);

  void _ingestScoped(
    String fid,
    String col,
    String tag,
    List<(String, Map<String, dynamic>?)> changes, {
    required bool full,
    bool fromCache = false,
  }) => ingestKidScoped(
    fid: fid,
    col: col,
    tag: tag,
    changes: changes,
    full: full,
    fromCache: fromCache,
    base: _cloudBase.putIfAbsent(fid, () => {}),
    versions: _cloudVersions.putIfAbsent(fid, () => {}),
    scoped: _scopedIds.putIfAbsent(fid, () => {}),
    loaded: _cloudLoaded.putIfAbsent(fid, () => {}),
  );

  bool _kidColLoaded(String fid, String col) => kidColLoaded(
    col,
    scoped: _scopedIds[fid] ?? const {},
    loaded: _cloudLoaded[fid] ?? const {},
    base: _cloudBase[fid] ?? const {},
  );

  /// An off-limits collection: nothing of it is held, and it counts as
  /// loaded so the rest of the sync engine isn't held back by it.
  void _markKidOffLimits(String fid, String col) {
    final base = _cloudBase.putIfAbsent(fid, () => {});
    base.removeWhere((k, _) => recordSource(k) == col);
    _cloudLoaded.putIfAbsent(fid, () => {}).add(col);
  }

  /// Restricts [local] to what the rules let this kid write in [fid].
  void _scopeKidWrites(String fid, Records base, Records local) {
    final kidId = _kidMemberIdByFid[fid];
    final uid = _firebaseUid();
    if (kidId == null) return;
    if (uid == null) {
      local
        ..clear()
        ..addAll(base);
      return;
    }
    scopeKidRecords(base, local, uid: uid, kidId: kidId);
  }

  /// The kid-scoped queries for [col] as `(tag, query)`.
  List<(String, Query<Map<String, dynamic>>)> _kidQueries(
    String fid,
    String col,
  ) {
    final kidId = _kidMemberIdByFid[fid];
    final uid = _firebaseUid();
    if (kidId == null || uid == null) return const [];
    final q = _recordQuery(fid, col);
    return [
      for (final tag in kidQueryTags(col))
        (
          tag,
          switch (tag) {
            'attending' => q.where('attendees', arrayContains: kidId),
            'created' => q.where('createdBy', isEqualTo: uid),
            _ => q,
          },
        ),
    ];
  }

  /// The lines of own note [noteKey] (one plain collection query: the rules
  /// check the note's `createdBy`).
  Query<Map<String, dynamic>> _kidLinesQuery(String fid, String noteKey) =>
      FirebaseFirestore.instance.collection(
        '$kFamiliesCollection/$fid/$noteKey/$kLinesCol',
      );

  Set<String> _kidNoteKeys(String fid) => kidNoteKeys(_cloudBase[fid]);
  List<(String, Map<String, dynamic>?)> _snapChanges(
    QuerySnapshot<Map<String, dynamic>> snap, {
    required bool full,
  }) => full
      ? [for (final d in snap.docs) (d.reference.path, d.data())]
      : [
          for (final c in snap.docChanges)
            (
              c.doc.reference.path,
              c.type == DocumentChangeType.removed ? null : c.doc.data(),
            ),
        ];

  /// One-shot load of a kid family's records (boot / join / reload).
  Future<void> _fetchKidRecords(String fid) async {
    _scopedIds.remove(fid);
    _cloudBase[fid] = {};
    _cloudVersions.remove(fid);
    _cloudLoaded.remove(fid);
    Future<void> read(String col, String tag, Query<Map<String, dynamic>> q) =>
        q
            .get(const GetOptions(source: Source.server))
            .timeout(kCloudOpTimeout)
            .then((snap) {
              _ingestScoped(
                fid,
                col,
                tag,
                _snapChanges(snap, full: true),
                full: true,
              );
            })
            .catchError((Object e) {
              debugPrint('[cloud] kid $col/$tag read failed for $fid: $e');
            });
    await Future.wait([
      for (final col in kRecordCollections)
        if (kidOffLimits(col))
          Future.sync(() => _markKidOffLimits(fid, col))
        else
          for (final (tag, q) in _kidQueries(fid, col)) read(col, tag, q),
    ]);
    await Future.wait([
      for (final n in _kidNoteKeys(fid))
        read(kLinesCol, 'note:$n', _kidLinesQuery(fid, n)),
    ]);
    if (_kidColLoaded(fid, kLinesCol)) {
      _cloudLoaded.putIfAbsent(fid, () => {}).add(kLinesCol);
    }
  }

  /// Realtime listeners for a kid family (the scoped twin of the
  /// per-collection listeners in `_bindActiveFamily`).
  void _bindKidRecordListeners(String fid) {
    _scopedIds.remove(fid);
    _cancelKidLineSubs();
    for (final col in kRecordCollections) {
      if (kidOffLimits(col)) {
        _onCloudChange(fid, () => _markKidOffLimits(fid, col));
        continue;
      }
      for (final (tag, q) in _kidQueries(fid, col)) {
        _recordSubs.add(_listenKid(fid, col, tag, q));
      }
    }
  }

  StreamSubscription<Object?> _listenKid(
    String fid,
    String col,
    String tag,
    Query<Map<String, dynamic>> q,
  ) {
    var first = true;
    return q.snapshots().listen((snap) {
      final full = first;
      first = false;
      _onCloudChange(
        fid,
        () => _ingestScoped(
          fid,
          col,
          tag,
          _snapChanges(snap, full: full),
          full: full,
          fromCache: snap.metadata.isFromCache,
        ),
      );
      if (col == kNotesCol) _syncKidLineListeners(fid);
    }, onError: (Object e) => _onFamilyStreamError(fid, '$col/$tag', e));
  }

  /// Keeps exactly one lines listener per own note of [fid].
  void _syncKidLineListeners(String fid) {
    if (fid != _boundFamilyId) return;
    final notes = _kidNoteKeys(fid);
    for (final n in _kidLineSubs.keys.toList()) {
      if (!notes.contains(n)) _kidLineSubs.remove(n)?.cancel();
    }
    for (final n in notes) {
      _kidLineSubs.putIfAbsent(
        n,
        () => _listenKid(fid, kLinesCol, 'note:$n', _kidLinesQuery(fid, n)),
      );
    }
    if (_kidColLoaded(fid, kLinesCol)) {
      _cloudLoaded.putIfAbsent(fid, () => {}).add(kLinesCol);
    }
  }

  void _cancelKidLineSubs() {
    for (final s in _kidLineSubs.values) {
      s.cancel();
    }
    _kidLineSubs.clear();
  }

  /// Forgets everything loaded for [fid] and rebinds its listeners — used
  /// when the login's kid status flips, since kid and full members load
  /// through different queries.
  void _reloadFamilyAccess(String fid) {
    _cloudBase.remove(fid);
    _cloudLoaded.remove(fid);
    _cloudVersions.remove(fid);
    _scopedIds.remove(fid);
    final meUid = _firebaseUid();
    if (meUid != null && fid == familyId) {
      _boundFamilyId = null;
      scheduleMicrotask(() {
        if (mounted) _bindActiveFamily(meUid);
      });
    }
    if (mounted) update(() {});
  }

  /// A permission-denied stream may mean an admin just made this login a
  /// kid (its full listeners lost access), not that we left the family.
  /// Re-reads the family doc: still a member with a changed kid status →
  /// reload with the right queries; otherwise drop the family as before.
  Future<void> _recheckAccessAfterDenied(String fid) async {
    if (!_accessRechecks.add(fid)) return;
    try {
      final meUid = _firebaseUid();
      final snap = await _familyDocRef(
        fid,
      ).get(const GetOptions(source: Source.server)).timeout(kCloudOpTimeout);
      final data = snap.data();
      final uids = data?['memberUids'];
      if (meUid == null || uids is! List || !uids.contains(meUid)) {
        _dropFamilyLocally(fid);
        return;
      }
      if (!_noteKidStatus(fid, data)) {
        // Same access as before: a listener raced the change; rebind once.
        _reloadFamilyAccess(fid);
        return;
      }
      _reloadFamilyAccess(fid);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') _dropFamilyLocally(fid);
    } catch (e) {
      debugPrint('[cloud] access re-check failed for $fid: $e');
    } finally {
      _accessRechecks.remove(fid);
    }
  }
  // coverage:ignore-end
}
