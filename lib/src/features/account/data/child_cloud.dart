part of 'package:family_money_management_app/main.dart';

/// Cloud loading/saving for child users. The family doc's owner-managed
/// `kidEmails` map tells the security rules which logins are kids; for those
/// the rules deny whole-collection reads, so this loads exactly what a kid
/// may see through scoped queries (each one provable by the rules):
/// - `workspace`: the `settings` doc + docs `createdBy == <uid>` (own lists)
/// - `events`:    `attendees array-contains <kid member id>` + own creations
/// - `listItems`: `_listOwner == <uid>` (items on own lists)
/// - `weekly`:    everything (read-only)
/// - `budgetItems`: nothing.
/// Writes are filtered to the same scope before they leave the device.
extension _ThriveChildCloud on _ThriveHomeState {
  String _authEmail() {
    if (!firebaseAppsAvailable) return '';
    return FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
  }

  /// Records whether the signed-in login is a kid in [fid] per its family
  /// doc [data]. Returns true when that status changed.
  bool _noteKidStatus(String fid, Map<String, dynamic>? data) {
    if (data == null) return false;
    final email = _authEmail();
    final map = data['kidEmails'];
    final id = email.isNotEmpty && map is Map ? map[email]?.toString() : null;
    final before = _kidMemberIdByFid[fid];
    if (id == null) {
      _kidMemberIdByFid.remove(fid);
    } else {
      _kidMemberIdByFid[fid] = id;
    }
    return before != id;
  }

  void _noteKidStatuses(Iterable<MapEntry<String, Map<String, dynamic>>> docs) {
    for (final d in docs) {
      _noteKidStatus(d.key, d.value);
    }
  }

  bool _isKidFamily(String fid) => _kidMemberIdByFid.containsKey(fid);

  /// The kid-scoped queries for [col] as `(tag, query)`; empty when the
  /// collection is off-limits.
  List<(String, Query<Map<String, dynamic>>)> _kidQueries(
    String fid,
    String col,
  ) {
    final kidId = _kidMemberIdByFid[fid];
    final uid = _firebaseUid();
    if (kidId == null || uid == null) return const [];
    final c = _recordCol(fid, col);
    switch (col) {
      case kWorkspaceCol:
        return [('lists', c.where('createdBy', isEqualTo: uid))];
      case kEventsCol:
        return [
          ('attending', c.where('attendees', arrayContains: kidId)),
          ('created', c.where('createdBy', isEqualTo: uid)),
        ];
      case kListItemsCol:
        return [('mine', c.where('_listOwner', isEqualTo: uid))];
      case kWeeklyCol:
        return [('all', c)];
      default:
        return const [];
    }
  }

  /// How many sources feed [col] for a kid (the settings doc included).
  int _kidSourceCount(String fid, String col) =>
      _kidQueries(fid, col).length + (col == kWorkspaceCol ? 1 : 0);

  /// Folds one kid-scoped source's docs into the base. [full] replaces what
  /// this [tag] delivered before; a doc only leaves the base once no tag of
  /// the collection holds it any more.
  void _ingestScoped(
    String fid,
    String col,
    String tag,
    List<(String, Map<String, dynamic>?)> changes, {
    required bool full,
    bool fromCache = false,
  }) {
    final base = _cloudBase.putIfAbsent(fid, () => {});
    final tags = _scopedIds
        .putIfAbsent(fid, () => {})
        .putIfAbsent(col, () => {});
    final mine = tags.putIfAbsent(tag, () => <String>{});
    // An empty cache answer for a source we hold data for is a cold cache,
    // not "everything was deleted" — wait for the server.
    if (full && fromCache && changes.isEmpty && mine.isNotEmpty) return;
    bool heldElsewhere(String id) =>
        tags.entries.any((e) => e.key != tag && e.value.contains(id));
    void drop(String id) {
      mine.remove(id);
      if (!heldElsewhere(id)) base.remove(recordKey(col, id));
    }

    final seen = <String>{};
    for (final (id, raw) in changes) {
      if (raw == null) {
        drop(id);
        continue;
      }
      seen.add(id);
      mine.add(id);
      final key = recordKey(col, id);
      final rec = normalizeRecord(key, raw);
      if (rec == null) {
        base.remove(key);
      } else {
        base[key] = rec;
      }
    }
    if (full) {
      for (final id in mine.difference(seen).toList()) {
        drop(id);
      }
    }
    if (tags.length >= _kidSourceCount(fid, col)) {
      _cloudLoaded.putIfAbsent(fid, () => {}).add(col);
    }
  }

  /// An off-limits collection: nothing of it is held, and it counts as
  /// loaded so the rest of the sync engine isn't held back by it.
  void _markKidOffLimits(String fid, String col) {
    _cloudBase
        .putIfAbsent(fid, () => {})
        .removeWhere((k, _) => k.startsWith('$col/'));
    _cloudLoaded.putIfAbsent(fid, () => {}).add(col);
  }

  /// One-shot load of a kid family's records (boot / join).
  Future<void> _fetchKidRecords(String fid, Source source) async {
    _scopedIds.remove(fid);
    _cloudBase[fid] = {};
    _cloudLoaded.remove(fid);
    _legacyDocs.remove(fid);
    final futures = <Future<void>>[];
    for (final col in kRecordCollections) {
      if (_kidSourceCount(fid, col) == 0) {
        _markKidOffLimits(fid, col);
        continue;
      }
      for (final (tag, q) in _kidQueries(fid, col)) {
        futures.add(
          q
              .get(GetOptions(source: source))
              .timeout(kCloudOpTimeout)
              .then((snap) {
                _ingestScoped(fid, col, tag, [
                  for (final d in snap.docs) (d.id, d.data()),
                ], full: true);
              })
              .catchError((Object e) {
                debugPrint('[cloud] kid $col/$tag read failed for $fid: $e');
              }),
        );
      }
      if (col == kWorkspaceCol) {
        futures.add(
          _recordCol(fid, col)
              .doc('settings')
              .get(GetOptions(source: source))
              .timeout(kCloudOpTimeout)
              .then((d) {
                _ingestScoped(fid, col, 'settings', [
                  ('settings', d.data()),
                ], full: true);
              })
              .catchError((Object e) {
                debugPrint('[cloud] kid settings read failed for $fid: $e');
              }),
        );
      }
    }
    await Future.wait(futures);
  }

  /// Realtime listeners for a kid family (the scoped twin of the
  /// per-collection listeners in `_bindActiveFamily`).
  void _bindKidRecordListeners(String fid) {
    _scopedIds.remove(fid);
    for (final col in kRecordCollections) {
      if (_kidSourceCount(fid, col) == 0) {
        _onCloudChange(fid, () => _markKidOffLimits(fid, col));
        continue;
      }
      for (final (tag, q) in _kidQueries(fid, col)) {
        var first = true;
        _recordSubs.add(
          q.snapshots().listen((snap) {
            final full = first;
            first = false;
            final changes = full
                ? [for (final d in snap.docs) (d.id, d.data())]
                : [
                    for (final c in snap.docChanges)
                      (
                        c.doc.id,
                        c.type == DocumentChangeType.removed
                            ? null
                            : c.doc.data(),
                      ),
                  ];
            _onCloudChange(
              fid,
              () => _ingestScoped(
                fid,
                col,
                tag,
                changes,
                full: full,
                fromCache: snap.metadata.isFromCache,
              ),
            );
          }, onError: (Object e) => _onFamilyStreamError(fid, col, e)),
        );
      }
      if (col == kWorkspaceCol) {
        _recordSubs.add(
          _recordCol(fid, col).doc('settings').snapshots().listen((d) {
            _onCloudChange(
              fid,
              () => _ingestScoped(fid, col, 'settings', [
                ('settings', d.data()),
              ], full: true),
            );
          }, onError: (Object e) => _onFamilyStreamError(fid, 'settings', e)),
        );
      }
    }
  }

  /// Whether a kid may write [rec] at [key] — mirrors firestore.rules.
  bool _kidMayWrite(String fid, String key, Map<String, dynamic> rec) {
    final kidId = _kidMemberIdByFid[fid];
    final uid = _firebaseUid();
    if (kidId == null || uid == null) return false;
    final (col, id) = splitRecordKey(key);
    switch (col) {
      case kEventsCol:
        final attendees = rec['attendees'];
        final createdBy = rec['createdBy'];
        return createdBy == uid ||
            createdBy == kidId ||
            (attendees is List && attendees.contains(kidId));
      case kWorkspaceCol:
        return RegExp(r'^list_(task|shop)_.+').hasMatch(id) &&
            rec['createdBy'] == uid;
      case kListItemsCol:
        return rec['_listOwner'] == uid;
      default:
        return false;
    }
  }

  /// Restricts [local] so a kid's persist only plans writes the rules
  /// accept: anything out of scope is pinned to the server's version.
  void _scopeKidWrites(String fid, Records base, Records local) {
    if (!_isKidFamily(fid)) return;
    for (final key in {...local.keys, ...base.keys}) {
      final l = local[key];
      final b = base[key];
      final ok =
          (l == null || _kidMayWrite(fid, key, l)) &&
          (b == null || _kidMayWrite(fid, key, b));
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
    _scopedIds.remove(fid);
    _legacyDocs.remove(fid);
    final meUid = _firebaseUid();
    if (meUid != null && fid == familyId) {
      scheduleMicrotask(() {
        if (mounted) _bindActiveFamily(meUid);
      });
    }
    if (mounted) update(() {});
  }

  /// A permission-denied stream may mean the owner just made this login a
  /// kid (its full listeners lost access), not that we left the family.
  /// Re-reads the family doc: still a member → reload with the right
  /// queries; otherwise drop the family as before.
  Future<void> _recheckAccessAfterDenied(String fid) async {
    if (!_accessRechecks.add(fid)) return;
    try {
      final meUid = _firebaseUid();
      final snap = await _familyDocRef(fid).get().timeout(kCloudOpTimeout);
      final data = snap.data();
      final uids = data?['memberUids'];
      if (meUid == null || uids is! List || !uids.contains(meUid)) {
        _dropFamilyLocally(fid);
        return;
      }
      // Same access as before: the denial wasn't about kid scoping.
      if (!_noteKidStatus(fid, data)) {
        _dropFamilyLocally(fid);
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
