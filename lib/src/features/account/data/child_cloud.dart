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
extension _ThriveChildCloud on _ThriveHomeState {
  /// Records whether the signed-in login is a kid in [fid] per its family
  /// doc [data]. Returns true when that status changed.
  bool _noteKidStatus(String fid, Map<String, dynamic>? data) {
    if (data == null) return false;
    final uid = _firebaseUid();
    final map = data['kidUids'];
    final id = uid != null && map is Map ? map[uid]?.toString() : null;
    final before = _kidMemberIdByFid[fid];
    if (id == null || id.isEmpty) {
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

  /// The kid-scoped queries for [col] as `(tag, query)`; empty when the
  /// collection is off-limits (or, for `lines`, loaded per note instead).
  List<(String, Query<Map<String, dynamic>>)> _kidQueries(
    String fid,
    String col,
  ) {
    final kidId = _kidMemberIdByFid[fid];
    final uid = _firebaseUid();
    if (kidId == null || uid == null) return const [];
    final q = _recordQuery(fid, col);
    switch (col) {
      case kSettingsCol ||
          kCalendarCol ||
          kLayersCol ||
          kCategoriesCol ||
          kMealsCol ||
          kDaysCol:
        return [('all', q)];
      case kEventsCol || kRecurringCol:
        return [
          ('attending', q.where('attendees', arrayContains: kidId)),
          ('created', q.where('createdBy', isEqualTo: uid)),
        ];
      case kNotesCol:
        return [('created', q.where('createdBy', isEqualTo: uid))];
      default:
        return const [];
    }
  }

  /// The lines of own note [noteKey] (one plain collection query: the rules
  /// check the note's `createdBy`).
  Query<Map<String, dynamic>> _kidLinesQuery(String fid, String noteKey) =>
      FirebaseFirestore.instance.collection(
        '$kFamiliesCollection/$fid/$noteKey/$kLinesCol',
      );

  /// The note keys a kid's base holds for [fid] (their own notes).
  Set<String> _kidNoteKeys(String fid) => {
    for (final k in (_cloudBase[fid] ?? const <String, Map>{}).keys)
      if (recordKind(k) == RecordKind.note) k,
  };

  /// Whether every source feeding [col] has answered at least once.
  bool _kidColLoaded(String fid, String col) {
    final tags = _scopedIds[fid]?[col] ?? const <String, Set<String>>{};
    if (col == kLinesCol) {
      final loaded = _cloudLoaded[fid] ?? const <String>{};
      if (!loaded.contains(kNotesCol)) return false;
      return _kidNoteKeys(fid).every((n) => tags.containsKey('note:$n'));
    }
    return tags.length >= _kidQueries(fid, col).length;
  }

  /// Folds one kid-scoped source's docs ([changes]: doc path → raw, null =
  /// removed) into the base. [full] replaces what this [tag] delivered
  /// before; a doc only leaves the base once no tag of the collection
  /// holds it any more.
  void _ingestScoped(
    String fid,
    String col,
    String tag,
    List<(String, Map<String, dynamic>?)> changes, {
    required bool full,
    bool fromCache = false,
  }) {
    final base = _cloudBase.putIfAbsent(fid, () => {});
    final versions = _cloudVersions.putIfAbsent(fid, () => {});
    final tags = _scopedIds
        .putIfAbsent(fid, () => {})
        .putIfAbsent(col, () => {});
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
      final notes = _kidNoteKeys(fid);
      final lineTags = _scopedIds[fid]?[kLinesCol];
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
    final loaded = _cloudLoaded.putIfAbsent(fid, () => {});
    if (_kidColLoaded(fid, col)) loaded.add(col);
    if (_kidColLoaded(fid, kLinesCol)) loaded.add(kLinesCol);
  }

  /// An off-limits collection: nothing of it is held, and it counts as
  /// loaded so the rest of the sync engine isn't held back by it.
  void _markKidOffLimits(String fid, String col) {
    final base = _cloudBase.putIfAbsent(fid, () => {});
    base.removeWhere((k, _) => recordSource(k) == col);
    _cloudLoaded.putIfAbsent(fid, () => {}).add(col);
  }

  bool _kidOffLimits(String fid, String col) =>
      col != kLinesCol && _kidQueries(fid, col).isEmpty;

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
        if (_kidOffLimits(fid, col))
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
      if (_kidOffLimits(fid, col)) {
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

  /// Whether a kid may write [rec] at [key] — mirrors firestore.rules.
  bool _kidMayWrite(
    String fid,
    String key,
    Map<String, dynamic> rec,
    Records view,
  ) {
    final kidId = _kidMemberIdByFid[fid];
    final uid = _firebaseUid();
    if (kidId == null || uid == null) return false;
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

  /// Restricts [local] so a kid's persist only plans writes the rules
  /// accept: anything out of scope is pinned to the server's version.
  void _scopeKidWrites(String fid, Records base, Records local) {
    if (!_isKidFamily(fid)) return;
    final view = {...base, ...local};
    for (final key in {...local.keys, ...base.keys}) {
      final l = local[key];
      final b = base[key];
      final ok =
          (l == null || _kidMayWrite(fid, key, l, view)) &&
          (b == null || _kidMayWrite(fid, key, b, view));
      if (ok) continue;
      if (b == null) {
        local.remove(key);
      } else {
        local[key] = b;
      }
    }
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
}
