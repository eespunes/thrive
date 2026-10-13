part of 'package:family_money_management_app/main.dart';

/// Firestore collection holding one document per signed-in user: their profile,
/// the families they belong to and lightweight per-user view state.
const String kUsersCollection = 'users';

/// Firestore collection holding one document per family. This is the shared
/// source of truth: its `memberUids` array is what security rules check, and
/// its `workspace` map is the budget shared by every member.
const String kFamiliesCollection = 'families';

/// Backend handle resolver: maps a family `username` to its `familyId`. This
/// collection holds NO secret material (the salted password hash lives only in
/// the members-only family doc as `joinHash`), so any signed-in user may read
/// it to resolve a handle when joining. Writes are restricted by security rules
/// to the owner of the referenced family.
const String kFamilyHandlesCollection = 'family_handles';

/// Local (no-Firebase) family registry, mirroring the design's
/// `localStorage['thrive.registry']`, so create/join works offline.
const String kRegistryKey = 'thrive.registry';

/// Stable per-device id used in place of a Firebase `uid` when running in
/// local/offline mode (see `myId`), so every member's own row always has a
/// real, globally-consistent id — never the ambiguous legacy `'me'` sentinel,
/// which used to collide whenever two real people's rows both carried it.
const String kLocalSelfUidKey = 'thrive.localSelfUid';

/// Per-DEVICE settings (reminders switch, device-calendar mirror, widget
/// privacy, active tab). Kept OUTSIDE the v4 blob — which cloud mode deletes
/// on every persist — so a cloud-backed device no longer loses them on every
/// boot. Never mirrored to the cloud user doc: they describe this device.
const String kDevicePrefsKey = 'thrive.deviceprefs.v1';

/// Upper bound for any single cloud round-trip (Firestore write/read). Awaiting a Firestore write resolves only once the backend acks
/// it, so a dropped connection would otherwise hang the UI forever (the SDK
/// keeps unacknowledged writes in memory). Bounding every await turns that
/// into a "Not saved" state that is retried.
const Duration kCloudOpTimeout = Duration(seconds: 12);

/// Salted SHA-256 of a family join password (legacy v1 scheme, and the local
/// registry's hash). Cloud joins are verified server-side by security rules,
/// which compare a client-supplied proof against the members-only `joinHash`.
String hashFamilyPassword(String password, String salt) {
  final digest = sha256.convert(utf8.encode('$salt::$password'));
  return digest.toString();
}

/// Iteration count for the v2 join-password hash. A single SHA-256 is
/// trivially brute-forceable offline if a hash ever leaks (backup, console
/// access); chaining the digest this many times makes each guess ~30k times
/// more expensive while still costing the client well under a second, and
/// only on the rare create/join flows.
const int kJoinHashIterations = 30000;

/// Minimum length for a NEW family join password (create / reset). A family's
/// `joinSalt` is readable by any signed-in user, so the password is the only
/// thing standing between a handle and a self-join; 4 characters was cheap to
/// brute-force (#364). Existing families keep their current password.
const int kMinFamilyPasswordLength = 8;

/// Error shown when a new family join password is shorter than
/// [kMinFamilyPasswordLength].
const String kFamilyPasswordTooShort =
    'Password must be at least $kMinFamilyPasswordLength characters';

/// v2 join-password hash: SHA-256 chained [kJoinHashIterations] times over a
/// RANDOM per-family salt (stored on the public handle doc as `joinSalt` —
/// salts need to be unique, not secret, and a joining client must be able to
/// read it before it can read the family doc). Families created before v2
/// have no `joinSalt` on their handle and keep verifying via the legacy
/// [hashFamilyPassword] with the derivable slug salt.
String hashFamilyPasswordV2(String password, String salt) {
  var digest = sha256.convert(utf8.encode('$salt::$password'));
  for (var i = 1; i < kJoinHashIterations; i++) {
    digest = sha256.convert(digest.bytes);
  }
  return digest.toString();
}

/// Legacy (v1) salt for families whose handle doc has no random `joinSalt`:
/// derivable from the public username slug so old families keep working.
String _cloudJoinSalt(String slug) => 'thrive-family::$slug';

/// Random hex salt for a newly created family's v2 `joinHash`.
String newJoinSalt() =>
    sha256.convert(utf8.encode('${uid()}::${uid()}')).toString();

/// The correct join proof for [password] given the [handle] doc it targets:
/// v2 (iterated hash over the handle's random `joinSalt`) when the salt is
/// present, else the legacy v1 slug-salted hash.
String joinProofFor(
  String password,
  String slug,
  Map<String, dynamic>? handle,
) {
  final salt = (handle?['joinSalt'] ?? '').toString();
  if (salt.isNotEmpty) return hashFamilyPasswordV2(password, salt);
  return hashFamilyPassword(password, _cloudJoinSalt(slug));
}

/// Builds a starter workspace populated from the bundled sample budget
/// (`assets/data/budget.json`) so a brand-new install isn't an empty shell.
/// Used by the first-launch sample seed.
Future<Workspace> buildSampleWorkspace() async {
  Map<String, dynamic> raw = {};
  try {
    final text = await rootBundle.loadString('assets/data/budget.json');
    raw = json.decode(text) as Map<String, dynamic>;
  } catch (_) {
    /* fall back to an unpopulated-but-default workspace below */
  }
  final cats = defaultCats();
  final yearMap = <String, MonthData>{};
  for (final mk in kMonthKeys) {
    final month = MonthData();
    for (final c in cats) {
      month.blocks[c.key] = [];
    }
    final m = raw[mk] as Map<String, dynamic>?;
    if (m != null) {
      // The sample budget keys income under 'income' and each expense block by
      // its category key. Income is now the income-direction block (issue #137),
      // so it loads through the same loop — its rows carry expected/actual/
      // received rather than amount/paid.
      for (final c in cats) {
        for (final it in (m[c.key] as List? ?? [])) {
          final map = Map<String, dynamic>.from(it as Map);
          if (c.isIncome) {
            final expected = parseNum(map['expected']);
            month.blocks[c.key]!.add(
              ExpenseItem(
                id: uid(),
                label: (map['label'] ?? '').toString(),
                marker: '',
                amount: expected != 0 ? expected : parseNum(map['actual']),
                paid: map['received'] == true,
                account: accForLabel(map['label']?.toString()),
                // The bundled sample already itemizes every month
                // individually (issue #185's default-on recurring is meant
                // for real user items going forward, not this static demo
                // data), so auto-propagation must stay off here or the
                // sample would duplicate itself across future months.
                recurring: false,
              ),
            );
          } else {
            month.blocks[c.key]!.add(
              ExpenseItem(
                id: uid(),
                label: (map['label'] ?? '').toString(),
                marker: markerShow(map['day'] ?? map['date']),
                amount: parseNum(map['amount']),
                paid: map['paid'] == true,
                account: accForLabel(map['label']?.toString()),
                until: map['until'],
                recurring: false,
              ),
            );
          }
        }
      }
    }
    yearMap[mk] = month;
  }
  // Sample spending limits so the cap feature is visible in the demo.
  yearMap['Juli']?.caps.addAll({
    'food': 850,
    'personal': 700,
    'additional': 1600,
  });
  yearMap['Juni']?.caps.addAll({'food': 800});
  return Workspace(
    accounts: defaultAccounts(),
    cats: cats,
    data: {2026: yearMap},
    // Unlike a genuinely new family (which starts with zero calendar
    // layers, see [Workspace]'s constructor), this bundled first-launch
    // sample is deliberately pre-populated demo content (issue #119) so a
    // brand-new install isn't an empty shell — seed the 3 legacy layers too
    // so the demo calendar data reads sensibly out of the box.
    calendarLayers: kDefaultCalendarLayers(),
  );
}

/// The server couldn't be reached (offline / timed out). There is no local
/// copy to fall back to, so callers show a "can't connect" state instead.
class CloudUnreachable implements Exception {
  const CloudUnreachable(this.cause);
  final Object cause;
  @override
  String toString() => 'CloudUnreachable($cause)';
}

/// How long a collection reloaded on opening a screen stays fresh: the
/// realtime listeners keep it current meanwhile, so tab-hopping doesn't
/// re-read (and pay for) every document each time.
const Duration kScreenReloadMinInterval = Duration(seconds: 15);

/// Cloud + local persistence for the families↔users relationship.
extension _ThriveFamilyCloud on _ThriveHomeState {
  // Cloud document refs + (de)serialization helpers are only exercised against
  // a live Firestore backend.
  // coverage:ignore-start
  // --------------------------------------------------------------- refs
  DocumentReference<Map<String, dynamic>> _userDocRef(String meUid) =>
      FirebaseFirestore.instance.collection(kUsersCollection).doc(meUid);

  DocumentReference<Map<String, dynamic>> _familyDocRef(String fid) =>
      FirebaseFirestore.instance.collection(kFamiliesCollection).doc(fid);

  DocumentReference<Map<String, dynamic>> _familyHandleRef(String slug) =>
      FirebaseFirestore.instance.collection(kFamilyHandlesCollection).doc(slug);

  // -------------------------------------------------------- (de)serialize
  // The pure serialization/digest layer lives in workspace_sections.dart,
  // where it is unit-tested without a widget tree or a live backend.
  /// Every record of family [fid] in the collections with id [col], at any
  /// depth (one collection-group query — see cloud_records.dart).
  Query<Map<String, dynamic>> _recordQuery(String fid, String col) =>
      FirebaseFirestore.instance
          .collectionGroup(col)
          .where(kFamilyIdField, isEqualTo: fid);

  DocumentReference<Map<String, dynamic>> _recordRef(String fid, String key) =>
      FirebaseFirestore.instance.doc('$kFamiliesCollection/$fid/$key');

  Family _familyFromDoc(String fid, Map<String, dynamic> doc) {
    final fam = Family.fromJson({...doc, 'id': fid});
    fam.id = fid;
    fam.members = dedupeMembers(fam.members);
    _migrateLegacyMeIds(fam);
    return fam;
  }

  // requires a live Firestore backend.
  // ----------------------------------------------------------- boot
  /// Loads the signed-in user's families from the SERVER (there is no
  /// local cache). Returns true when the user already belongs to a family
  /// (or legacy state was migrated), false when brand new.
  ///
  /// Throws [CloudUnreachable] when the server couldn't be reached at all:
  /// an offline launch must never be mistaken for "no family yet" (which
  /// would show the create/join gate to an existing member).
  ///
  /// Membership is read from the families' own `memberUids` — the same field the
  /// security rules treat as the source of truth — rather than the per-user
  /// `familyIds` mirror, which is written best-effort and could lag a create or
  /// join and strand an existing member on the onboarding gate (issue #128).
  ///
  /// Unsaved changes from a previous run ([PendingChanges]) are then set
  /// aside in the user's staging area, out of the family data
  /// ([_stagePendingChanges]).
  Future<bool> cloudBoot(String meUid) async {
    final ok = await _cloudBootLoad(meUid);
    if (ok) await _stagePendingChanges(meUid);
    return ok;
  }

  Future<bool> _cloudBootLoad(String meUid) async {
    const server = GetOptions(source: Source.server);
    // The user-doc read and the membership query are independent — run them
    // concurrently to save a round-trip.
    var userDocReached = true;
    final userDataFuture = _userDocRef(meUid)
        .get(server)
        .timeout(kCloudOpTimeout)
        .then<Map<String, dynamic>?>((d) => d.data())
        .catchError((Object e) {
          debugPrint('[cloud] boot user-doc read failed: $e');
          userDocReached = false;
          return null;
        });
    Map<String, dynamic>? userData;
    try {
      final snap = await _familiesCol()
          .where('memberUids', arrayContains: meUid)
          .get(server)
          .timeout(kCloudOpTimeout);
      userData = await userDataFuture;
      final docs = <MapEntry<String, Map<String, dynamic>>>[
        for (final d in snap.docs) MapEntry(d.id, d.data()),
      ];
      if (docs.isNotEmpty) {
        _noteKidStatuses(docs);
        await _fetchAllRecords([for (final d in docs) d.key]);
        _applyFamilyDocs(meUid, docs, userData);
        if (families.isNotEmpty) {
          // Repair the user-doc mirror so its `familyIds` reflects reality.
          unawaited(_writeUserDoc(meUid).catchError((_) {}));
          return true;
        }
      }
    } catch (e) {
      debugPrint('[cloud] boot membership query failed: $e');
      userData = await userDataFuture;
      if (!userDocReached && _isUnreachable(e)) throw CloudUnreachable(e);
    }
    // Fallbacks: the user-doc id list (e.g. if the query is unavailable), then
    // legacy single-blob migration for first-run upgrades.
    try {
      if (userData != null && (userData['familyIds'] is List)) {
        await _loadFamiliesFromCloud(meUid, userData);
        if (families.isNotEmpty) return true;
      }
      return await _migrateLegacyState(meUid);
    } catch (e) {
      debugPrint('[cloud] boot fallback failed: $e');
      if (_isUnreachable(e)) throw CloudUnreachable(e);
      return false;
    }
  }

  /// Whether [e] means "the server couldn't be reached" (offline, timed out)
  /// rather than a real answer such as permission-denied.
  bool _isUnreachable(Object e) =>
      e is TimeoutException ||
      (e is FirebaseException &&
          const {'unavailable', 'deadline-exceeded'}.contains(e.code));

  CollectionReference<Map<String, dynamic>> _familiesCol() =>
      FirebaseFirestore.instance.collection(kFamiliesCollection);

  Future<void> _loadFamiliesFromCloud(
    String meUid,
    Map<String, dynamic> userData,
  ) async {
    final ids = [for (final i in (userData['familyIds'] as List)) i.toString()];
    // All doc reads round-trip the network, so fetch every family in parallel
    // instead of paying one RTT per family.
    final snaps = await Future.wait([
      for (final fid in ids)
        _familyDocRef(
          fid,
        ).get(const GetOptions(source: Source.server)).timeout(kCloudOpTimeout),
    ]);
    final docs = <MapEntry<String, Map<String, dynamic>>>[
      for (final (i, s) in snaps.indexed)
        if (s.data() != null) MapEntry(ids[i], s.data()!),
    ];
    _noteKidStatuses(docs);
    await _fetchAllRecords([for (final d in docs) d.key]);
    _applyFamilyDocs(meUid, docs, userData);
  }

  /// Loads every record collection of every family in [fids] concurrently
  /// from the server into [_cloudBase] (full replace per collection). A
  /// collection whose read fails stays unloaded, so nothing is ever created
  /// or deleted there blind.
  Future<void> _fetchAllRecords(List<String> fids) async {
    await Future.wait([
      for (final fid in fids.where(_isKidFamily)) _fetchKidRecords(fid),
      for (final fid in fids.where((f) => !_isKidFamily(f)))
        for (final col in kRecordCollections)
          _recordQuery(fid, col)
              .get(const GetOptions(source: Source.server))
              .timeout(kCloudOpTimeout)
              .then((snap) {
                _ingestRecordSnapshot(fid, col, snap, full: true);
              })
              .catchError((Object e) {
                debugPrint('[cloud] $col read failed for $fid: $e');
              }),
    ]);
  }

  /// Folds a record-collection snapshot into the family's server state
  /// ([_cloudBase]) and marks the collection loaded. [full] replaces the
  /// collection wholesale (boot reads, a listener's first snapshot);
  /// otherwise only `docChanges` apply.
  void _ingestRecordSnapshot(
    String fid,
    String col,
    QuerySnapshot<Map<String, dynamic>> snap, {
    required bool full,
  }) {
    final base = _cloudBase.putIfAbsent(fid, () => {});
    final fromCache = snap.metadata.isFromCache;
    bool inCol(String k) => recordSource(k) == col;
    // An empty CACHE answer for a collection we already hold data for is a
    // cold/partial cache, not "everything was deleted" — wait for the server.
    if (full && fromCache && snap.docs.isEmpty && base.keys.any(inCol)) {
      return;
    }
    final versions = _cloudVersions.putIfAbsent(fid, () => {});
    final hadNotes = col == kNotesCol
        ? {
            for (final k in base.keys)
              if (inCol(k)) k,
          }
        : const <String>{};
    if (full) {
      base.removeWhere((k, _) => inCol(k));
      versions.removeWhere((k, _) => inCol(k));
    }
    final prefix = '$kFamiliesCollection/$fid/';
    final changes = full
        ? [for (final d in snap.docs) (d.reference.path, d.data())]
        : [
            for (final c in snap.docChanges)
              (
                c.doc.reference.path,
                c.type == DocumentChangeType.removed ? null : c.doc.data(),
              ),
          ];
    for (final (path, raw) in changes) {
      // The query filters on `familyId`; a doc filed under another family
      // is never this family's.
      if (!path.startsWith(prefix)) continue;
      final key = path.substring(prefix.length);
      final rec = raw == null ? null : normalizeRecord(key, raw);
      if (rec == null) {
        base.remove(key);
        versions.remove(key);
      } else {
        base[key] = rec;
        versions[key] = recordVersion(raw);
      }
    }
    // Notes deleted on the server: lines still filed under them (added while
    // the note was being deleted) are deleted too — see _localRecords.
    for (final k in hadNotes) {
      if (!base.containsKey(k)) _goneNotes.putIfAbsent(fid, () => {}).add(k);
    }
    // A cache answer only proves the collection's contents when it has docs
    // (an empty cache may simply never have synced it).
    if (!fromCache || snap.docs.isNotEmpty) {
      _cloudLoaded.putIfAbsent(fid, () => {}).add(col);
    }
  }

  /// Everything the server holds for [fid] as records: the current-format
  /// records, plus records still embedded in the legacy family-doc blob
  /// (current-format records win on a clash).
  Records _serverView(String fid) {
    final base = _cloudBase[fid] ?? const <String, Map<String, dynamic>>{};
    // The blob only counts for a family that never got record docs.
    final blob = base.isNotEmpty ? null : _legacyBlob[fid];
    if (blob == null) return base;
    return {...legacyRecords(const {}, blob: blob), ...base};
  }

  bool _hasLegacyData(String fid) => _legacyBlob[fid] != null;

  /// Builds [fid]'s workspace from the server state alone.
  Workspace _workspaceFromCloud(String fid) =>
      workspaceFromRecords(_serverView(fid));

  /// Applies a server-side change to [fid]: runs [mutate] (which updates the
  /// server state), then rebases this device's in-memory workspace onto it —
  /// records this device didn't touch take the server's version, records
  /// with a pending local edit keep it (merged per field where both sides
  /// changed). The workspace object is only swapped when something visible
  /// actually changed, so our own write echoing back is a no-op.
  void _onCloudChange(String fid, void Function() mutate) {
    final hadBase = _cloudBase.containsKey(fid);
    // A copy: [_serverView] may return the live `_cloudBase` map, which
    // [mutate] changes in place — `before` would then equal `after` and
    // every remote change would be ignored.
    final before = hadBase
        ? Map.of(_serverView(fid))
        : const <String, Map<String, dynamic>>{};
    mutate();
    final after = _serverView(fid);
    final localWs = workspaces[fid];
    Workspace next;
    var lostEdits = const <Map<String, dynamic>>[];
    var pendingDropped = false;
    if (!hadBase || localWs == null) {
      // Nothing of this family was loaded before: adopt the server wholesale
      // (a placeholder workspace's defaults must never win over real data).
      next = workspaceFromRecords(after);
    } else {
      final changed = <String>{
        for (final k in {...before.keys, ...after.keys})
          if (!jsonEquals(before[k], after[k])) k,
      };
      if (changed.isEmpty) return;
      final local = _localRecords(fid, localWs, before);
      final oldBase = {...before};
      final inflight = _inflightCreates[fid] ?? const <String, int>{};
      final keep = <String>{};
      final updating = _inflightUpdates[fid] ?? const <String, Map>{};
      for (final k in changed) {
        // Our own save of this record isn't acknowledged yet: the server
        // version we last saw is the base, so the change arriving now is
        // merged with our edit instead of replacing it (a reload or snapshot
        // racing the save must never drop it).
        final sentFrom = updating[k];
        if (sentFrom != null && local.containsKey(k)) {
          oldBase[k] = Map<String, dynamic>.from(sentFrom);
          continue;
        }
        // Our own unacknowledged create vanishing from the cache is the SDK
        // reverting a failed write, not a delete: keep the local copy (the
        // rollback makes the next persist retry it).
        if (inflight.containsKey(k) &&
            !after.containsKey(k) &&
            local.containsKey(k)) {
          keep.add(k);
          continue;
        }
        // A record this device never saw from the server (a placeholder
        // month, a doc another member created with the same id): rebase it
        // against the model defaults, so only fields we really edited win.
        if (!before.containsKey(k) && local.containsKey(k)) {
          // Kitchen settings are never created while unloaded, so a local
          // copy the server hadn't confirmed is a placeholder: theirs wins.
          oldBase[k] = k == kKitchenKey
              ? local[k]!
              : placeholderRecord(k, local[k]!);
        }
      }
      // Our unsaved edits of records another member deleted: dropped (a
      // deletion always wins — see rebaseRecords), and the user is told.
      lostEdits = [
        for (final k in changed)
          if (oldBase.containsKey(k) &&
              !after.containsKey(k) &&
              !keep.contains(k) &&
              local.containsKey(k) &&
              !jsonEquals(local[k], oldBase[k]))
            local[k]!,
      ];
      // Deleted on the server: our pending delete is done, our pending edit
      // is moot (a pending create stays — it's being sent).
      for (final k in changed) {
        if (after.containsKey(k)) continue;
        final c = _pending['$fid|$k'];
        if (c != null && !(c.op == PendingOp.save && c.serverRecord == null)) {
          _pending.remove(c.id);
          pendingDropped = true;
        }
      }
      final merged = rebaseRecords(
        oldBase: oldBase,
        newBase: after,
        local: local,
        changed: changed,
      );
      for (final k in keep) {
        merged[k] = local[k]!;
      }
      if (changed.every((k) => jsonEquals(merged[k], local[k]))) return;
      next = workspaceFromRecords(merged);
    }
    // Card photos never travel through the cloud (issue #234).
    mergeCardPhotos(next.cards, localWs?.cards ?? const []);
    _applyingCloudSnapshot = true;
    workspaces[fid] = next;
    if (fid == familyId) _adoptActiveWorkspace();
    _applyingCloudSnapshot = false;
    if (mounted) {
      update(() {});
      _rescheduleReminders();
    }
    if (pendingDropped) _pendingChanged();
    if (lostEdits.isNotEmpty) _notifyDeletedMeanwhile(lostEdits);
  }

  /// Tells the user their unsaved edits of [records] were dropped because
  /// another member deleted them.
  void _notifyDeletedMeanwhile(List<Map<String, dynamic>> records) {
    if (!mounted || records.isEmpty) return;
    final label = recordLabel(records.first);
    flash(
      records.length > 1
          ? '${records.length} items you were editing were deleted by '
                'another member'
          : label.isEmpty
          ? 'An item you were editing was deleted by another member'
          : '\u201C$label\u201D was deleted by another member',
    );
  }

  /// Record [key] of [fid] was deleted on the server while this device's
  /// edit ([rec]) was being saved: the deletion wins — drop it here too.
  void _dropDeletedRecord(String fid, String key, Map<String, dynamic> rec) {
    _cloudBase[fid]?.remove(key);
    _cloudVersions[fid]?.remove(key);
    if (_pending.remove('$fid|$key')) _pendingChanged();
    final ws = workspaces[fid];
    if (ws != null) {
      final local = _localRecords(fid, ws)..remove(key);
      final next = workspaceFromRecords(local);
      mergeCardPhotos(next.cards, ws.cards);
      _applyingCloudSnapshot = true;
      workspaces[fid] = next;
      if (fid == familyId) _adoptActiveWorkspace();
      _applyingCloudSnapshot = false;
      if (mounted) update(() {});
    }
    _notifyDeletedMeanwhile([rec]);
  }

  /// Meta-doc fields this app owns, normalized through the model.
  Map<String, dynamic> _metaOf(Family f) => familyMetaDoc(f)
    ..remove('updatedAtMillis')
    ..remove('updatedAt');

  Map<String, dynamic> _metaFromDoc(String fid, Map<String, dynamic> data) =>
      _metaOf(Family.fromJson({...data, 'id': fid})..id = fid);

  /// Marks [fid] as a family the server has nothing for yet (just created,
  /// or promoted from local storage): every record will be created.
  void _markFreshCloudFamily(String fid) {
    _cloudBase[fid] = {};
    _cloudLoaded[fid] = {...kRecordCollections};
    _legacyBlob.remove(fid);
  }

  /// One-time migration of [fid]'s pre-record data (the single-doc
  /// `workspace` blob on the family doc) into one document per item. Records are created from
  /// this device's current copy (so edits/deletes made meanwhile survive),
  /// and only once every create landed is the blob removed. Runs
  /// once all collections are loaded, so nothing already migrated (by
  /// another member) is overwritten. Idempotent; retried on failure.
  Future<void> _migrateLegacyData(String fid) async {
    // A kid can't read (or rewrite) most of the family's data.
    if (_isKidFamily(fid)) return;
    if (!_hasLegacyData(fid)) return;
    final loaded = _cloudLoaded[fid] ?? const <String>{};
    if (!kRecordCollections.every(loaded.contains)) return;
    if (!_legacyMigrating.add(fid)) return;
    try {
      final base = _cloudBase[fid]!;
      final view = _serverView(fid);
      final localWs = workspaces[fid];
      final local = localWs == null ? null : normalizedRecords(localWs);
      final now = DateTime.now().millisecondsSinceEpoch;
      final creates = <String, Map<String, dynamic>>{};
      for (final e in view.entries) {
        if (base.containsKey(e.key)) continue;
        if (local != null && !local.containsKey(e.key)) continue; // deleted
        creates[e.key] = local?[e.key] ?? e.value;
      }
      final ops = <void Function(WriteBatch)>[
        for (final e in creates.entries)
          (b) => b.set(
            _recordRef(fid, e.key),
            _createBody(fid, e.key, e.value, now),
            SetOptions(merge: true),
          ),
      ];
      final written = _commitInChunks(ops);
      // Optimistic, so edits made from now on become plain updates.
      for (final e in creates.entries) {
        base.putIfAbsent(e.key, () => e.value);
      }
      try {
        await written;
      } catch (e) {
        for (final k in creates.keys) {
          if (jsonEquals(base[k], creates[k])) base.remove(k);
        }
        rethrow;
      }

      await _familyDocRef(fid).update({'workspace': FieldValue.delete()});
      _legacyBlob.remove(fid);
      debugPrint(
        '[cloud] migrated ${creates.length} legacy record(s) for $fid',
      );
      // Pending local edits to migrated records can now be written.
      if (fid == familyId) _schedulePersist();
    } catch (e) {
      debugPrint('[cloud] legacy migration failed for $fid: $e');
    } finally {
      _legacyMigrating.remove(fid);
    }
  }

  /// Commits [ops] in batches below Firestore's 500-write limit. Every batch
  /// is issued immediately, in order; only the acks are awaited.
  Future<void> _commitInChunks(List<void Function(WriteBatch)> ops) {
    final commits = <Future<void>>[];
    for (var i = 0; i < ops.length; i += 450) {
      final batch = FirebaseFirestore.instance.batch();
      for (final op in ops.skip(i).take(450)) {
        op(batch);
      }
      commits.add(batch.commit());
    }
    return Future.wait(commits);
  }

  /// The merge-safe body for creating record [key] (see [createPayload]).
  /// Where the collection is known to lack the doc, container docs are
  /// written whole (a fresh family's kitchen settings, a new month's block
  /// order). Always tagged with the family (see [kFamilyIdField]).
  Map<String, dynamic> _createBody(
    String fid,
    String key,
    Map<String, dynamic> rec,
    int now,
  ) {
    final known = _cloudLoaded[fid]?.contains(recordSource(key)) ?? false;
    final body = key == kKitchenKey && known
        ? rec
        : createPayload(key, rec, includeBlocks: known);
    return {...body, kFamilyIdField: fid, ..._versionBump(now)};
  }

  /// Bookkeeping fields every record write carries: one more save
  /// ([kVersionField]), by whom and when.
  Map<String, dynamic> _versionBump(int now) => {
    kVersionField: FieldValue.increment(1),
    kUpdatedByField: myId,
    'updatedAtMillis': now,
  };

  /// Adopts a set of loaded family documents into local state, choosing the
  /// active family from [userData] (falling back to the first) and restoring the
  /// saved view state. Shared by every cloud boot path.
  void _applyFamilyDocs(
    String meUid,
    List<MapEntry<String, Map<String, dynamic>>> docs,
    Map<String, dynamic>? userData,
  ) {
    if (docs.isEmpty) return;
    final loadedFamilies = <Family>[];
    final loadedWorkspaces = <String, Workspace>{};
    for (final entry in docs) {
      final fid = entry.key;
      loadedFamilies.add(_familyFromDoc(fid, entry.value));
      _metaBase[fid] = _metaFromDoc(fid, entry.value);
      final blob = entry.value['workspace'];
      if (blob is Map) {
        _legacyBlob[fid] = Map<String, dynamic>.from(blob);
      } else {
        _legacyBlob.remove(fid);
      }
      final ws = _workspaceFromCloud(fid);
      loadedWorkspaces[fid] = ws;
      // Cloud records never carry card photos (issue #234) — restore the
      // ones this device already had from local storage.
      mergeCardPhotos(ws.cards, workspaces[fid]?.cards ?? const []);
    }

    var active = (userData?['activeFamilyId'] ?? '').toString();
    if (!loadedWorkspaces.containsKey(active)) active = loadedFamilies.first.id;

    families = loadedFamilies;
    workspaces = loadedWorkspaces;
    familyId = active;
    _adoptActiveWorkspace();
    if (userData != null) {
      year = (userData['year'] as num?)?.toInt() ?? year;
      monthIdx = ((userData['monthIdx'] as num?)?.toInt() ?? monthIdx).clamp(
        0,
        kMonthKeys.length - 1,
      );
      final rawScreen = (userData['screen'] ?? screen).toString();
      if (const {'overview', 'stats', 'settings'}.contains(rawScreen)) {
        screen = rawScreen;
      }
      layerFilter = _savedLayerFilter(userData['layerFilter']);
      navTabs = _savedNavTabs(userData['navTabs']) ?? navTabs;
      calFilter = _savedIdList(userData['calFilter']);
      calCatFilter = _savedIdList(userData['calCatFilter']);
      homeBoard = parseHomeBoard(userData['homeBoard']) ?? homeBoard;
    }
    _migrateLegacyMeIdsAll(meUid);
    // Move families still on the pre-record layout (legacy array docs or the
    // multi-MB single-doc blob, which can overflow Android's CursorWindow)
    // now, not on the first edit.
    for (final entry in docs) {
      unawaited(_migrateLegacyData(entry.key));
    }
  }

  /// Reads the deprecated `user_workspaces/{uid}` blob and promotes each family
  /// it held into a shared `families/{id}` document owned by this user.
  Future<bool> _migrateLegacyState(String meUid) async {
    final legacy = await _stateDocRef(meUid).get();
    final root = legacy.data();
    final state = root?['state'];
    if (state is! Map) return false;
    _restoreV4(Map<String, dynamic>.from(state));
    if (families.isEmpty) return false;
    for (final f in families) {
      _markFreshCloudFamily(f.id);
      f.ownerUid ??= meUid;
      if (!f.memberUids.contains(meUid)) f.memberUids.add(meUid);
      if (f.username.trim().isEmpty) f.username = familySlug(f.name);
      // This is solely-owned local data this device already had before its
      // first cloud login, so its own row is unambiguously `'me'` even
      // though it predates uid tracking.
      _migrateLegacyMeIds(f, meUid);
    }
    await _persistAllFamilies(meUid);
    await _recordMembership(meUid);
    return true;
  }

  // ----------------------------------------------------------- streams
  Future<void> bindCloudSync(String meUid) async {
    await _cloudSub?.cancel();
    await _familySub?.cancel();
    _cancelRecordSubs();
    try {
      _cloudSub = _userDocRef(meUid).snapshots().listen((snap) {
        final data = snap.data();
        if (data == null || data['familyIds'] is! List) return;
        if (_applyingCloudSnapshot) return;
        // Home board edits made on another device (issue #240). Compared as
        // JSON so the every-persist rewrite of the user doc doesn't loop.
        // Skip our own local echo (same guard as the workspace stream) so a
        // pending local write can't be re-adopted as if it were remote.
        final remoteBoard = snap.metadata.hasPendingWrites
            ? null
            : parseHomeBoard(data['homeBoard']);
        if (remoteBoard != null &&
            json.encode([for (final e in remoteBoard) e.toJson()]) !=
                json.encode([
                  for (final e in homeBoard ?? <BoardEntry>[]) e.toJson(),
                ])) {
          homeBoard = remoteBoard;
          if (mounted) update(() {});
        }
        // `activeFamilyId` is treated as per-device view state: every
        // device's persist rewrites it in the user doc, so adopting it from
        // every snapshot made two devices of one account parked on different
        // families switch each other back and forth on every edit. Boot
        // still seeds the initial active family from the user doc (see
        // _applyFamilyDocs); here it's only the fallback for a device whose
        // current active id is no longer valid (e.g. just evicted from it).
        final active = (data['activeFamilyId'] ?? familyId).toString();
        if (!workspaces.containsKey(familyId) &&
            active != familyId &&
            workspaces.containsKey(active)) {
          _applyingCloudSnapshot = true;
          familyId = active;
          _adoptActiveWorkspace();
          _applyingCloudSnapshot = false;
          if (mounted) update(() {});
        }
        // Only rebind when the active family actually changed. The user doc
        // is rewritten by every persist, so rebinding unconditionally here
        // used to tear down and recreate both family streams after every
        // debounced edit (each resubscription re-delivering the full
        // snapshot).
        if (_boundFamilyId != familyId) _bindActiveFamily(meUid);
      });
      _bindActiveFamily(meUid);
    } catch (e) {
      debugPrint('[cloud] bindCloudSync failed: $e');
    }
  }

  /// Removes a family this user no longer belongs to from local state and
  /// falls back to the next family — or the create/join gate when it was the
  /// last one. Shared by the snapshot-based membership check below and the
  /// stream `onError` handlers (an evicted device's reads are denied by the
  /// security rules, so eviction can arrive as a permission error too).
  void _dropFamilyLocally(String fid) {
    final present = families.any((f) => f.id == fid);
    if (!present && fid != familyId) return;
    _noteKidFamilyDropped(fid);
    _applyingCloudSnapshot = true;
    families = families.where((f) => f.id != fid).toList();
    workspaces.remove(fid);
    if (fid == familyId) {
      familyId = families.isNotEmpty ? families.first.id : 'fam_main';
      _adoptActiveWorkspace();
    }
    _applyingCloudSnapshot = false;
    if (mounted) update(() {});
  }

  /// Shared `onError` for both family streams. A stream error KILLS the
  /// subscription, so without this an evicted device (whose reads the rules
  /// now deny) kept stale data silently and every persist failed until
  /// restart. Permission-denied on the family doc means we're no longer a
  /// member — run the same cleanup as the snapshot-based membership check. A
  /// denied RECORD stream only drops the family once the family doc confirms
  /// it: deployed rules lagging the app's record layout deny those queries
  /// for every member, which must not read as "you were removed". Anything
  /// else is at least surfaced instead of dying unnoticed.
  void _onFamilyStreamError(String fid, String label, Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      // Possibly a kid restriction rather than a removal — re-check first.
      debugPrint('[cloud] $label stream denied for $fid — re-checking access');
      unawaited(_recheckAccessAfterDenied(fid, label, e));
      return;
    }
    _onFamilyStreamBroken(fid, label, e);
  }

  void _onFamilyStreamBroken(String fid, String label, Object e) {
    debugPrint('[cloud] $label stream failed for $fid: $e');
    // Re-subscribed when the app next comes to the foreground.
    _streamsBroken = true;
    if (mounted) _showSectionLoadSheet(label, uid: _firebaseUid());
  }

  /// A family stream broke: that part of the family's data stops updating.
  void _showSectionLoadSheet(String label, {String? uid}) {
    final what = switch (label) {
      kCalendarCol || kEventsCol || kLayersCol || kCategoriesCol => 'calendar',
      kFinanceCol ||
      kAccountsCol ||
      kBlocksCol ||
      kEntriesCol ||
      kCardsCol ||
      kImportsCol => 'budget',
      kNotesCol || kLinesCol => 'lists',
      kMealsCol || kDaysCol => 'meal plan',
      _ => 'family’s data',
    };
    _showStatusSheetOnce(
      tone: StatusTone.amber,
      title: 'Couldn’t load your $what',
      body:
          'The rest of Thrive works fine. Try again, or come back to it in a '
          'moment.',
      primary: 'Try again',
      onPrimary: () {
        if (uid == null || !_streamsBroken) return;
        _streamsBroken = false;
        unawaited(bindCloudSync(uid));
      },
      secondary: 'Go to Home',
      onSecondary: () => update(() => tab = 'home'),
    );
  }

  void _cancelRecordSubs() {
    for (final sub in _recordSubs) {
      sub.cancel();
    }
    _recordSubs.clear();
    _cancelKidLineSubs();
  }

  void _bindActiveFamily(String meUid) {
    final fid = familyId;
    _boundFamilyId = fid;
    _familySub?.cancel();
    _cancelRecordSubs();
    try {
      // One realtime listener per record collection. EVERY snapshot is
      // processed — including the local echo of our own pending writes,
      // which is simply a no-op after the rebase — so the in-memory
      // workspace always converges on what Firestore holds. Only the docs
      // that changed are applied (docChanges), and they are rebased onto
      // this device's pending edits instead of overwriting them.
      if (_isKidFamily(fid)) _bindKidRecordListeners(fid);
      for (final col in kRecordCollections) {
        if (_isKidFamily(fid)) break;
        var first = true;
        _recordSubs.add(
          _recordQuery(fid, col).snapshots().listen((snap) {
            final full = first;
            first = false;
            _onCloudChange(
              fid,
              () => _ingestRecordSnapshot(fid, col, snap, full: full),
            );
            unawaited(_migrateLegacyData(fid));
          }, onError: (Object e) => _onFamilyStreamError(fid, col, e)),
        );
      }
      _familySub = _familyDocRef(fid).snapshots().listen((snap) {
        final data = snap.data();
        if (data == null) return;
        // We're no longer a member of this family (we left it, or an owner
        // removed us). Drop it locally and fall back to the next family — or
        // the create/join gate when it was our last — instead of re-adopting
        // it (issue #133).
        final uids = data['memberUids'];
        if (uids is! List || !uids.contains(meUid)) {
          _dropFamilyLocally(fid);
          return;
        }
        // An admin made this login a kid (or lifted it): kid and full
        // members load through different queries, so reload.
        if (_noteKidStatus(fid, data)) {
          _metaBase[fid] = _metaFromDoc(fid, data);
          final idx = families.indexWhere((f) => f.id == fid);
          if (idx >= 0) families[idx] = _familyFromDoc(fid, data);
          _reloadFamilyAccess(fid);
          return;
        }
        final rawBlob = data['workspace'];
        final blob = rawBlob is Map ? Map<String, dynamic>.from(rawBlob) : null;
        if (!jsonEquals(blob, _legacyBlob[fid])) {
          _onCloudChange(fid, () {
            if (blob == null) {
              _legacyBlob.remove(fid);
            } else {
              _legacyBlob[fid] = blob;
            }
          });
          unawaited(_migrateLegacyData(fid));
        }
        // Meta fields: same three-way rebase as records, so a pending local
        // change (e.g. a rename) survives while another member's change to a
        // different field is adopted.
        final serverMeta = _metaFromDoc(fid, data);
        final oldMeta = _metaBase[fid];
        _metaBase[fid] = serverMeta;
        if (oldMeta != null && jsonEquals(oldMeta, serverMeta)) return;
        final idx = families.indexWhere((f) => f.id == fid);
        final merged = oldMeta == null || idx < 0
            ? serverMeta
            : Map<String, dynamic>.from(
                rebaseValue(oldMeta, serverMeta, _metaOf(families[idx])) as Map,
              );
        final fam = _familyFromDoc(fid, {
          ...data,
          ...merged,
          if (!merged.containsKey('picture')) 'picture': null,
        });
        _applyingCloudSnapshot = true;
        if (idx >= 0) {
          families[idx] = fam;
        } else {
          families = [...families, fam];
        }
        if (fid == familyId) _adoptActiveWorkspace();
        _migrateLegacyMeIdsAll(meUid);
        _applyingCloudSnapshot = false;
        if (mounted) {
          update(() {});
          _rescheduleReminders();
        }
      }, onError: (Object e) => _onFamilyStreamError(fid, 'family', e));
    } catch (e) {
      debugPrint('[cloud] family stream failed: $e');
    }
  }

  // ----------------------------------------------------------- persist
  /// Saves the active family's changes to the server and completes with
  /// whether every write was acknowledged (see [_persistFamily]).
  Future<bool> cloudPersist(String meUid) async {
    if (_applyingCloudSnapshot) return true;
    final f = curFamily();
    var ok = true;
    if (f != null) {
      if (!f.memberUids.contains(meUid)) f.memberUids.add(meUid);
      f.ownerUid ??= meUid;
      ok = await _persistFamily(f, workspaces[f.id] ?? Workspace.empty());
    }
    // Unsaved changes of other families (still retrying, or staged changes
    // just applied) are saved with the active one's.
    final others = {..._persistAlso, for (final c in _pending.all) c.familyId}
      ..remove(f?.id);
    for (final o in families.where((x) => others.contains(x.id))) {
      final ws = workspaces[o.id];
      if (ws == null) continue;
      if (await _persistFamily(o, ws)) {
        _persistAlso.remove(o.id);
      } else {
        ok = false;
      }
    }
    // Best-effort, bounded mirror write.
    await _recordMembership(meUid);
    return ok;
  }

  /// Writes to Firestore exactly what this device changed in [f] since the
  /// server state it last saw ([_cloudBase] / [_metaBase]): new records are
  /// created, changed records get FIELD-LEVEL, versioned updates (so another
  /// member's edit to a different field of the same item is never
  /// overwritten — see [_versionedUpdate]), and records deleted locally are
  /// deleted. Nothing this device didn't touch is ever written, so a stale
  /// device can't revert anyone's edits.
  ///
  /// The base is updated optimistically (a second persist racing this one
  /// won't re-send the same changes) and rolled back if a write is rejected
  /// or not acknowledged within [kCloudOpTimeout], so the next persist
  /// retries it. Completes with whether every write was acknowledged.
  Future<bool> _persistFamily(Family f, Workspace ws) async {
    final acks = <Future<void>>[];
    _persistFamilyMeta(f, acks);
    _persistFamilyRecords(f.id, ws, acks);
    if (acks.isEmpty) return true;
    final results = await Future.wait([
      for (final a in acks) a.then((_) => true, onError: (Object _) => false),
    ]);
    return results.every((r) => r);
  }

  void _persistFamilyMeta(Family f, List<Future<void>> acks) {
    final local = _metaOf(f);
    final base = _metaBase[f.id];
    if (base != null && jsonEquals(base, local)) return;
    final ref = _familyDocRef(f.id);
    final Future<void> write;
    if (base == null) {
      write = ref.set(familyMetaDoc(f), SetOptions(merge: true));
    } else {
      write = ref.update({
        for (final c in recordPatch(base, local))
          FieldPath(c.path): c.delete ? FieldValue.delete() : c.value,
        'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    _metaBase[f.id] = local;
    acks.add(
      write.timeout(kCloudOpTimeout).catchError((Object e) {
        debugPrint('[cloud] meta write failed for ${f.id}: $e');
        if (jsonEquals(_metaBase[f.id], local)) {
          if (base == null) {
            _metaBase.remove(f.id);
          } else {
            _metaBase[f.id] = base;
          }
        }
        throw e;
      }),
    );
  }

  void _persistFamilyRecords(
    String fid,
    Workspace ws,
    List<Future<void>> acks,
  ) {
    final base = _cloudBase[fid];
    // Nothing of this family has loaded: any write would be blind.
    if (base == null) return;
    final loaded = _cloudLoaded[fid] ?? const <String>{};
    final view = _serverView(fid);
    final local = _localRecords(fid, ws, view);
    _scopeKidWrites(fid, base, local);
    final legacyPending = _hasLegacyData(fid);
    final intents = _deleteIntents[fid] ?? <String>{};
    final gone = _goneNotes[fid] ?? const <String>{};
    bool deliberate(String k) =>
        intents.contains(k) ||
        (recordKind(k) == RecordKind.line &&
            (intents.contains(_noteKeyOfLine(k)) ||
                gone.contains(_noteKeyOfLine(k))));
    // Safety net: a placeholder `Workspace.empty()` (a family that hasn't
    // finished loading) must never be written over real data. Deleting the
    // family's last note / event is not that.
    if (recordsAreEmptyPlaceholder(local) &&
        (!kRecordCollections.every(loaded.contains) ||
            legacyPending ||
            base.keys.any((k) => !local.containsKey(k) && !deliberate(k)))) {
      debugPrint('[cloud] SKIPPED persist for $fid: workspace not loaded');
      return;
    }
    final plan = planRecordWrites(base, local);

    final now = DateTime.now().millisecondsSinceEpoch;
    final ops = <void Function(WriteBatch)>[];
    final rollbacks = <void Function()>[];
    final created = <String>[];
    // Unsaved-changes journal entries this batch settles once acknowledged.
    final sent = <(String, int)>[];
    plan.creates.forEach((key, rec) {
      // Records still held by legacy docs are created by the migration.
      if (legacyPending && view.containsKey(key)) return;
      // Container docs (settings, months, accounts, cards, ...) are
      // placeholders until their collection has loaded — never write those.
      // A note is only ever in memory because a member pinned it, so it's
      // written right away: its lines are, and a note doc that never reached
      // the durable write queue is lost on the next restart.
      final col = recordSource(key);
      if (kContainerCollections.contains(col) && !loaded.contains(col)) {
        return;
      }
      // Merge-safe even when the doc exists but hasn't reached this device
      // (see createPayload), so this never waits for the collection to load
      // — the create is sent to the server right away.
      final body = _createBody(fid, key, rec, now);
      ops.add(
        (b) => b.set(_recordRef(fid, key), body, SetOptions(merge: true)),
      );
      base[key] = rec;
      created.add(key);
      sent.add((key, _journal(fid, key, rec, null, now)));
      // By value: the local echo may already have replaced the object.
      rollbacks.add(() {
        if (jsonEquals(base[key], rec)) base.remove(key);
      });
    });
    // Undone (the record is back) — no longer a delete.
    intents.removeWhere(local.containsKey);
    // Lines left under a note another member deleted go with it.
    final unintended = unintendedDeletes(base, plan.deletes, {
      ...intents,
      ...gone,
    }, local: local);
    for (final key in plan.deletes) {
      if (unintended.containsKey(key)) continue;
      ops.add((b) => b.delete(_recordRef(fid, key)));
      final prev = base.remove(key)!;
      final intent = intents.remove(key);
      sent.add((key, _journal(fid, key, null, prev, now)));
      rollbacks.add(() {
        base.putIfAbsent(key, () => prev);
        if (intent) intents.add(key);
      });
    }
    // Spent (or moot: never reached the server) intents.
    intents.removeWhere((k) => !base.containsKey(k));
    if (unintended.isNotEmpty) _restoreGuardedRecords(fid, local, unintended);
    if (ops.isNotEmpty) {
      final inflight = _inflightCreates.putIfAbsent(fid, () => {});
      for (final k in created) {
        inflight[k] = (inflight[k] ?? 0) + 1;
      }
      void settle() {
        for (final k in created) {
          final n = (inflight[k] ?? 1) - 1;
          if (n <= 0) {
            inflight.remove(k);
          } else {
            inflight[k] = n;
          }
        }
      }

      acks.add(
        _commitInChunks(ops)
            .timeout(kCloudOpTimeout)
            .then(
              (_) {
                settle();
                _settleJournal(fid, sent);
              },
              onError: (Object e) {
                debugPrint('[cloud] record commit failed for $fid: $e');
                for (final r in rollbacks) {
                  r();
                }
                settle();
                throw e;
              },
            ),
      );
    }
    plan.updates.forEach((key, _) {
      final prev = base[key]!;
      final rec = local[key]!;
      base[key] = rec;
      final inflight = _inflightUpdates.putIfAbsent(fid, () => {});
      // The oldest unacknowledged version is what we last saw from the server.
      inflight.putIfAbsent(key, () => prev);
      final seq = _journal(fid, key, rec, prev, now);
      acks.add(
        _versionedUpdate(fid, key, prev, rec, now).then(
          (_) {
            inflight.remove(key);
            _settleJournal(fid, [(key, seq)]);
          },
          onError: (Object e) {
            debugPrint('[cloud] update of $key failed for $fid: $e');
            inflight.remove(key);
            if (jsonEquals(base[key], rec)) base[key] = prev;
            throw e;
          },
        ),
      );
    });
  }

  /// This device's records of [fid] ([ws]), plus lines the server holds
  /// whose note hasn't arrived yet (see [orphanListItems]) — except lines of
  /// a note that was deleted: those are deleted too.
  Records _localRecords(String fid, Workspace ws, [Records? view]) {
    final local = normalizedRecords(ws);
    final gone = _goneNotes[fid] ?? const <String>{};
    orphanListItems(view ?? _serverView(fid), local).forEach((k, v) {
      if (!gone.contains(_noteKeyOfLine(k))) local[k] = v;
    });
    return local;
  }

  /// Saves this device's edit of record [key] ([prev] → [rec]) inside a
  /// transaction against the version on the server right now:
  /// - nobody else saved since [prev] → only our changed fields are written;
  /// - someone else saved meanwhile → three-way merge (their changes to other
  ///   fields are kept); a field both changed keeps ours, and the user is
  ///   told and offered theirs ([_onSaveConflict]).
  /// The version goes up by exactly one. A record deleted meanwhile stays
  /// deleted: the edit is dropped ([_dropDeletedRecord]).
  Future<void> _versionedUpdate(
    String fid,
    String key,
    Map<String, dynamic> prev,
    Map<String, dynamic> rec,
    int now,
  ) async {
    final ref = _recordRef(fid, key);
    final result = await FirebaseFirestore.instance
        .runTransaction<
          ({
            bool missing,
            int version,
            Map<String, dynamic>? server,
            String? by,
            List<List<String>> conflicts,
          })
        >((tx) async {
          final snap = await tx.get(ref);
          final raw = snap.data();
          if (!snap.exists || raw == null) {
            return (
              missing: true,
              version: 0,
              server: null,
              by: null,
              conflicts: const <List<String>>[],
            );
          }
          final version = recordVersion(raw);
          final server = normalizeRecord(key, raw) ?? prev;
          final save = planVersionedSave(
            prev: prev,
            server: server,
            local: rec,
          );
          if (save.patch.isEmpty) {
            return (
              missing: false,
              version: version,
              server: server,
              by: raw[kUpdatedByField]?.toString(),
              conflicts: save.conflicts,
            );
          }
          tx.update(ref, {
            for (final c in save.patch)
              FieldPath(c.path): c.delete ? FieldValue.delete() : c.value,
            kVersionField: version + 1,
            kUpdatedByField: myId,
            'updatedAtMillis': now,
          });
          return (
            missing: false,
            version: version + 1,
            server: server,
            by: raw[kUpdatedByField]?.toString(),
            conflicts: save.conflicts,
          );
        }, timeout: kCloudOpTimeout);
    if (result.missing) {
      // Deleted by another member meanwhile: the deletion wins over our edit.
      _dropDeletedRecord(fid, key, rec);
      return;
    }
    _cloudVersions.putIfAbsent(fid, () => {})[key] = result.version;
    if (result.conflicts.isNotEmpty && result.server != null) {
      _onSaveConflict(
        fid,
        key,
        rec,
        result.server!,
        result.conflicts,
        result.by,
      );
    }
  }

  /// Someone else saved record [key] while this device was editing it and
  /// both changed the same field(s) ([paths]). Our version was saved; tell
  /// the user and offer to switch to theirs ([theirs] = what the server held
  /// before our save, written by member [by]).
  void _onSaveConflict(
    String fid,
    String key,
    Map<String, dynamic> mine,
    Map<String, dynamic> theirs,
    List<List<String>> paths,
    String? by,
  ) {
    if (!mounted) return;
    final who = _memberName(fid, by) ?? 'Someone else';
    final label = recordLabel(mine);
    final what = label.isEmpty ? 'this item' : '\u201C$label\u201D';
    if (_conflictDialogOpen) {
      flash('$who also changed $what — your version was saved');
      return;
    }
    _conflictDialogOpen = true;
    showDialog<bool>(
      context: context,
      barrierColor: const Color(0x80101828),
      builder: (ctx) => _SaveConflictDialog(
        who: who,
        what: what,
        onKeepMine: () => Navigator.of(ctx).pop(false),
        onUseTheirs: () => Navigator.of(ctx).pop(true),
      ),
    ).then((useTheirs) {
      _conflictDialogOpen = false;
      if (useTheirs == true) _useTheirVersion(fid, key, theirs, paths);
    });
  }

  /// Display name of member [id] (uid or member id) of family [fid].
  String? _memberName(String fid, String? id) {
    if (id == null || id.isEmpty) return null;
    if (id == myId) return 'You (on another device)';
    for (final f in families) {
      if (f.id != fid) continue;
      for (final m in f.members) {
        if (m.id == id || m.uid == id) return m.name;
      }
    }
    return null;
  }

  /// Replaces this device's value of the conflicting [paths] of record [key]
  /// with [theirs] and saves that.
  void _useTheirVersion(
    String fid,
    String key,
    Map<String, dynamic> theirs,
    List<List<String>> paths,
  ) {
    final ws = workspaces[fid];
    if (ws == null || !mounted) return;
    final local = _localRecords(fid, ws);
    final cur = local[key];
    if (cur == null) return;
    local[key] = takeTheirs(cur, theirs, paths);
    final next = workspaceFromRecords(local);
    mergeCardPhotos(next.cards, ws.cards);
    mutate(() {
      workspaces[fid] = next;
      if (fid == familyId) _adoptActiveWorkspace();
    });
  }

  /// Reloads the active family's record collections [cols] from the server
  /// (screen opened, app back in the foreground). Collections reloaded less
  /// than [kScreenReloadMinInterval] ago are skipped unless [force]. The
  /// result is rebased like any server change, so edits still being saved
  /// are kept; a reload that raced a save is dropped (the save's own echo
  /// brings the fresh state).
  Future<void> reloadFromServer({
    Iterable<String> cols = kRecordCollections,
    bool force = false,
  }) async {
    if (!_cloudBacked || !mounted) return;
    final fid = familyId;
    if (!_cloudBase.containsKey(fid)) return;
    // A kid's scoped listeners are the only reads the rules allow them.
    if (_isKidFamily(fid)) return;
    final now = DateTime.now();
    final due = [
      for (final c in cols)
        if (force ||
            now.difference(
                  _lastServerReload['$fid/$c'] ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                ) >=
                kScreenReloadMinInterval)
          c,
    ];
    if (due.isEmpty) return;
    for (final c in due) {
      _lastServerReload['$fid/$c'] = now;
    }
    final gen = _persistGeneration;
    await Future.wait([
      for (final col in due)
        _recordQuery(fid, col)
            .get(const GetOptions(source: Source.server))
            .timeout(kCloudOpTimeout)
            .then((snap) {
              if (!mounted || fid != familyId) return;
              if (gen != _persistGeneration || _persistRun != null) {
                _lastServerReload.remove('$fid/$col');
                return;
              }
              _onCloudChange(
                fid,
                () => _ingestRecordSnapshot(fid, col, snap, full: true),
              );
            })
            .catchError((Object e) {
              _lastServerReload.remove('$fid/$col');
              debugPrint('[cloud] reload of $col failed for $fid: $e');
            }),
    ]);
  }

  /// Puts list / event records the in-memory workspace lost — without the
  /// user deleting them — back into [fid]'s workspace, so the device shows
  /// (and keeps) what the server still holds instead of wiping it.
  void _restoreGuardedRecords(String fid, Records local, Records lost) {
    debugPrint(
      '[cloud] kept ${lost.length} record(s) for $fid that vanished '
      'locally without being deleted: ${lost.keys.take(5).join(', ')}',
    );
    final current = workspaces[fid];
    final next = workspaceFromRecords({...local, ...lost});
    mergeCardPhotos(next.cards, current?.cards ?? const []);
    workspaces[fid] = next;
    if (fid == familyId) _adoptActiveWorkspace();
    if (mounted) update(() {});
  }

  /// Records that the user deliberately unpinned list [listId] in the
  /// active family: its doc and lines may be deleted from the server on the
  /// next persist.
  void _markListDeleted(String listId) {
    _deleteIntents.putIfAbsent(familyId, () => {}).add(listMetaKey(listId));
  }

  /// Records that the user deliberately crossed off line [itemId] of list
  /// [listId] in the active family.
  void _markListItemDeleted(String listId, String itemId) {
    _deleteIntents
        .putIfAbsent(familyId, () => {})
        .add(listItemKey(listId, itemId));
  }

  // ------------------------------------------------ unsaved changes
  /// The device key of [uid]'s unsaved-changes journal.
  String _pendingKey(String uid) => '$kPendingChangesKey.$uid';

  /// Journals a write of [key] in [fid] ([rec]; null = delete) made from the
  /// server's [prev] (null = new record). Returns the send's sequence number.
  int _journal(
    String fid,
    String key,
    Map<String, dynamic>? rec,
    Map<String, dynamic>? prev,
    int now,
  ) {
    final seq = _pending.record(
      fid,
      key,
      record: rec,
      serverRecord: prev,
      now: now,
    );
    _pendingChanged();
    return seq;
  }

  /// Journals the active family's changes not sent yet (a save is waiting
  /// for the one in flight), so they survive the app being closed before
  /// they're sent. The waiting save journals them again as it sends them.
  void _journalWaitingChanges() {
    final fid = curFamily()?.id;
    if (fid == null || _applyingCloudSnapshot) return;
    final base = _cloudBase[fid];
    final ws = workspaces[fid];
    if (base == null || ws == null) return;
    final local = _localRecords(fid, ws);
    final plan = planRecordWrites(base, local);
    final intents = _deleteIntents[fid] ?? const <String>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    var any = false;
    void put(String k, Map<String, dynamic>? rec, Map<String, dynamic>? prev) {
      _pending.record(fid, k, record: rec, serverRecord: prev, now: now);
      any = true;
    }

    plan.creates.forEach((k, rec) => put(k, rec, null));
    plan.updates.forEach((k, _) => put(k, local[k], base[k]));
    for (final k in plan.deletes) {
      if (intents.contains(k)) put(k, null, base[k]);
    }
    if (any) _pendingChanged();
  }

  /// The server acknowledged the writes [sent] (key, sequence) of [fid].
  void _settleJournal(String fid, Iterable<(String, int)> sent) {
    var any = false;
    for (final (key, seq) in sent) {
      if (_pending.settle(fid, key, seq)) any = true;
    }
    if (any) _pendingChanged();
  }

  /// Saves the journal to its own device document and refreshes the review
  /// screen.
  void _pendingChanged() {
    pendingChangesTick.value++;
    final uid = _firebaseUid();
    if (uid == null) return;
    final key = _pendingKey(uid);
    final body = _pending.isEmpty ? null : json.encode(_pending.toJson(uid));
    unawaited(
      SharedPreferences.getInstance()
          .then((p) => body == null ? p.remove(key) : p.setString(key, body))
          .then(
            (_) {},
            onError: (Object e) {
              debugPrint('[cloud] saving unsaved changes failed: $e');
            },
          ),
    );
  }

  CollectionReference<Map<String, dynamic>> _unsavedRef(String uid) =>
      _userDocRef(uid).collection(kUnsavedChangesCollection);

  /// Moves [uid]'s unsaved changes from a previous run (the device journal)
  /// to their staging area in Firestore, out of the family data — nothing is
  /// written to the families until the user applies them (Settings →
  /// Unsaved changes). A set-aside change only ever leaves the staging area
  /// once the user reviewed it (applied or discarded); the only changes not
  /// set aside are those already in the family's data. Then loads every
  /// staged change.
  Future<void> _stagePendingChanges(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey(uid));
    var journal = PendingChanges();
    if (raw != null) {
      try {
        journal = PendingChanges.fromJson(json.decode(raw), uid);
      } catch (e) {
        debugPrint('[cloud] unreadable unsaved changes: $e');
      }
    }
    _pending = journal;
    final mine = {for (final f in families) f.id};
    for (final c in journal.all) {
      // Year / month folders are rebuilt from the items they hold.
      if (isContainerRecord(c.key)) journal.remove(c.id);
    }
    final toStage = <PendingChange>[];
    for (final fid in {for (final c in journal.all) c.familyId}) {
      // A family they've left: set aside as is (only discardable).
      if (!mine.contains(fid)) {
        toStage.addAll(journal.forFamily(fid));
        continue;
      }
      final ws = workspaces[fid];
      // Not loaded: kept on the device, set aside on the next start.
      if (ws == null || _cloudBase[fid] == null) continue;
      final r = applyPendingChanges(
        server: _serverView(fid),
        local: _localRecords(fid, ws),
        changes: journal.forFamily(fid),
      );
      // Already in the family's data: nothing to review.
      for (final c in r.settled) {
        journal.remove(c.id);
      }
      // Edits of items deleted meanwhile are set aside too, for review.
      toStage
        ..addAll(r.pending)
        ..addAll(r.lost);
    }
    if (toStage.isNotEmpty) {
      try {
        final col = _unsavedRef(uid);
        await _commitInChunks([
          for (final c in toStage) (b) => b.set(col.doc(c.docId), c.toJson()),
        ]).timeout(kCloudOpTimeout);
        for (final c in toStage) {
          journal.remove(c.id);
        }
        debugPrint('[cloud] set aside ${toStage.length} unsaved change(s)');
      } catch (e) {
        // Kept on the device; set aside on the next start.
        debugPrint('[cloud] setting aside unsaved changes failed: $e');
      }
    }
    _pendingChanged();
    await _loadStagedChanges(uid);
  }

  /// Loads [uid]'s staged changes. Nothing is ever removed here: only the
  /// user's review (apply / discard) clears a staged change.
  Future<void> _loadStagedChanges(String uid) async {
    try {
      final snap = await _unsavedRef(
        uid,
      ).get(const GetOptions(source: Source.server)).timeout(kCloudOpTimeout);
      final staged = PendingChanges();
      for (final d in snap.docs) {
        final c = PendingChange.fromJson(d.data());
        if (c != null && c.docId == d.id) staged.addStaged(c);
      }
      _staged = staged;
      pendingChangesTick.value++;
      if (!staged.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => promptUnsavedChanges(),
        );
      }
    } catch (e) {
      debugPrint('[cloud] loading unsaved changes failed: $e');
    }
  }

  /// Whether staged change [c] can be applied, or why not.
  StagedStatus stagedStatus(PendingChange c) {
    final fid = c.familyId;
    if (!families.any((f) => f.id == fid) ||
        workspaces[fid] == null ||
        _cloudBase[fid] == null) {
      return StagedStatus.familyGone;
    }
    if (c.op == PendingOp.delete) return StagedStatus.ready;
    final server = _serverView(fid);
    if (c.serverRecord != null) {
      return server.containsKey(c.key)
          ? StagedStatus.ready
          : StagedStatus.deletedMeanwhile;
    }
    if (recordKind(c.key) == RecordKind.line) {
      final note = _noteKeyOfLine(c.key);
      if (!server.containsKey(note) &&
          _staged['$fid|$note']?.op != PendingOp.save) {
        return StagedStatus.deletedMeanwhile;
      }
    }
    return StagedStatus.ready;
  }

  /// Applies the staged changes [ids] onto each family's CURRENT data (see
  /// [applyPendingChanges]: edits are merged field by field) and saves them;
  /// their staging docs are then deleted. A change to an item deleted
  /// meanwhile is dropped (the deletion wins); one for a family the user left
  /// stays set aside until discarded.
  Future<StagedApplyResult> applyStagedChanges(List<String> ids) async {
    final uid = _firebaseUid();
    if (uid == null) return const StagedApplyResult(signedOut: true);
    final byFamily = <String, List<PendingChange>>{};
    final wanted = {...ids};
    // An item of a new note that's set aside too brings its note along.
    for (final id in ids) {
      final c = _staged[id];
      if (c == null || recordKind(c.key) != RecordKind.line) continue;
      final note = _staged['${c.familyId}|${_noteKeyOfLine(c.key)}'];
      if (note != null && note.op == PendingOp.save) wanted.add(note.id);
    }
    final done = <PendingChange>[];
    final lost = <PendingChange>[];
    final sent = <PendingChange>[];
    for (final id in wanted) {
      final c = _staged[id];
      if (c == null) continue;
      switch (stagedStatus(c)) {
        case StagedStatus.ready:
          (byFamily[c.familyId] ??= []).add(c);
        case StagedStatus.deletedMeanwhile:
          // The deletion wins: applying it just clears it.
          lost.add(c);
        case StagedStatus.familyGone:
          break;
      }
    }
    for (final MapEntry(key: fid, value: changes) in byFamily.entries) {
      final ws = workspaces[fid];
      if (ws == null || _cloudBase[fid] == null) continue;
      final r = applyPendingChanges(
        server: _serverView(fid),
        local: _localRecords(fid, ws),
        changes: changes,
      );
      done.addAll(r.settled);
      lost.addAll(r.lost);
      if (r.pending.isEmpty) continue;
      sent.addAll(r.pending);
      _deleteIntents.putIfAbsent(fid, () => {}).addAll(r.deletes);
      final next = workspaceFromRecords(r.local);
      mergeCardPhotos(next.cards, ws.cards);
      workspaces[fid] = next;
      if (fid == familyId) {
        _adoptActiveWorkspace();
      } else {
        _persistAlso.add(fid);
      }
    }
    if (sent.isNotEmpty) {
      if (mounted) update(() {});
      _rescheduleReminders();
    }
    final ok = sent.isEmpty || await _persist();
    // Saved changes are now in the family's data (and, if the save failed,
    // in the device journal, retried like any other edit); changes to items
    // deleted meanwhile are dropped — the deletion wins.
    await _dropStaged(uid, [...done, ...lost, if (ok) ...sent]);
    return StagedApplyResult(
      applied: sent.length + done.length,
      gone: [for (final c in lost) pendingChangeLabel(c)],
      failed: !ok,
    );
  }

  /// Discards the staged changes [ids]: their staging docs are deleted; the
  /// family's data was never touched.
  Future<void> discardStagedChanges(List<String> ids) async {
    await _dropStaged(_firebaseUid(), [for (final id in ids) ?_staged[id]]);
  }

  Future<void> _dropStaged(String? uid, List<PendingChange> changes) async {
    if (changes.isEmpty) return;
    for (final c in changes) {
      _staged.remove(c.id);
    }
    pendingChangesTick.value++;
    if (uid == null) return;
    final col = _unsavedRef(uid);
    try {
      await _commitInChunks([
        for (final c in changes) (b) => b.delete(col.doc(c.docId)),
      ]).timeout(kCloudOpTimeout);
    } catch (e) {
      debugPrint('[cloud] deleting unsaved changes failed: $e');
    }
  }

  /// Discards the unsaved change [id]: the record goes back to the server's
  /// version (a new record is removed, a deleted one restored).
  void discardPendingChange(String id) => _discardPending([id]);

  /// Discards every unsaved change.
  void discardAllPendingChanges() =>
      _discardPending([for (final c in _pending.all) c.id]);

  void _discardPending(List<String> ids) {
    final byFamily = <String, List<PendingChange>>{};
    for (final id in ids) {
      final c = _pending[id];
      if (c != null) (byFamily[c.familyId] ??= []).add(c);
    }
    for (final MapEntry(key: fid, value: changes) in byFamily.entries) {
      final ws = workspaces[fid];
      final local = ws == null ? null : _localRecords(fid, ws);
      final base = _cloudBase[fid];
      final view = _serverView(fid);
      for (final c in changes) {
        _pending.remove(c.id);
        _deleteIntents[fid]?.remove(c.key);
        _inflightCreates[fid]?.remove(c.key);
        if (local == null) continue;
        // What the server holds now (else what it held when we changed it).
        final server = view[c.key] ?? c.serverRecord;
        if (server == null) {
          local.remove(c.key);
          // An optimistic create: the server never confirmed it.
          if (base != null && !view.containsKey(c.key)) base.remove(c.key);
        } else {
          local[c.key] = Map<String, dynamic>.from(jsonClone(server) as Map);
          if (base != null) base[c.key] = local[c.key]!;
        }
      }
      if (ws != null && local != null) {
        final next = workspaceFromRecords(local);
        mergeCardPhotos(next.cards, ws.cards);
        workspaces[fid] = next;
        if (fid == familyId) _adoptActiveWorkspace();
      }
    }
    _pendingChanged();
    if (mounted) update(() {});
    _rescheduleReminders();
    _schedulePersist();
  }

  /// Records that the user deleted event [eventId] in family [fid]: its
  /// doc(s) may be deleted from the server on the next persist.
  void _markEventDeleted(String fid, String eventId) {
    _deleteIntents
        .putIfAbsent(fid, () => {})
        .addAll(eventKeysById(_cloudBase[fid] ?? const {}, eventId));
  }

  Future<void> _writeUserDoc(String meUid) async {
    await _userDocRef(meUid).set({
      'profile': user?.toJson(),
      'familyIds': families.map((f) => f.id).toList(),
      'activeFamilyId': familyId,
      'year': year,
      'monthIdx': monthIdx,
      'screen': screen,
      'layerFilter': layerFilter,
      if (navTabs != null) 'navTabs': navTabs,
      'calFilter': calFilter,
      'calCatFilter': calCatFilter,
      if (homeBoard != null)
        'homeBoard': homeBoard!.map((e) => e.toJson()).toList(),
      'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Persists the user-doc mirror (profile, `familyIds`, active family, view
  /// state), bounded by [kCloudOpTimeout] and swallowing failures — the
  /// canonical way to await [_writeUserDoc] anywhere an unbounded hang would
  /// block a user-visible flow (its `set()` only acks from the backend, so
  /// offline it never resolves).
  /// Originally added so a freshly created or joined family is
  /// durably recorded in Firestore before we leave the flow. This closes the gap
  /// where an app closed right after create/join — before any edit triggered a
  /// persist — would lose its `familyIds` and bounce the user back to the
  /// onboarding gate on next launch (issue #128). Bounded by [kCloudOpTimeout]
  /// so a flaky connection can't strand the UI; the membership query in
  /// [cloudBoot] remains the backstop if this write still doesn't land.
  Future<void> _recordMembership(String meUid) async {
    try {
      await _writeUserDoc(meUid).timeout(kCloudOpTimeout);
    } catch (e) {
      debugPrint('[cloud] recordMembership failed: $e');
    }
  }

  /// Prepares every locally-held family for its first cloud persist (the
  /// local→cloud promotion in `_persist`): claims ownership/membership for
  /// [meUid], backfills usernames, rewrites any legacy literal `'me'` rows,
  /// and — crucially — remaps this device's local pseudo-uid to the Firebase
  /// [meUid] across member rows, memberUids and workspace references. The
  /// old promotion only ADDED [meUid] to `memberUids`, leaving the
  /// pseudo-uid self row behind as a ghost second member.
  void _promoteLocalFamiliesForCloud(String meUid) {
    final localId = _localSelfUidCache;
    for (final f in families) {
      // A family never read from the cloud is local-only: everything in it
      // is new to the server.
      if (!_metaBase.containsKey(f.id)) _markFreshCloudFamily(f.id);
      f.ownerUid ??= meUid;
      if (f.username.trim().isEmpty) f.username = familySlug(f.name);
      _migrateLegacyMeIds(f, meUid);
      if (localId != null && localId != meUid) {
        if (f.ownerUid == localId) f.ownerUid = meUid;
        for (final m in f.members) {
          if (m.id == localId) m.id = meUid;
          if (m.uid == localId) m.uid = meUid;
        }
        f.memberUids = {
          for (final u in f.memberUids) u == localId ? meUid : u,
        }.toList();
      }
      if (!f.memberUids.contains(meUid)) f.memberUids.add(meUid);
    }
    if (localId != null && localId != meUid) {
      for (final ws in workspaces.values) {
        _remapMemberIdInWorkspace(ws, localId, meUid);
      }
    }
  }

  /// Rewrites every workspace reference to member id [from] (attendees,
  /// creators, assignees, shopping adders) to [to] — the same reference set
  /// the legacy `'me'` migration covers.
  void _remapMemberIdInWorkspace(Workspace ws, String from, String to) {
    for (final ev in ws.events) {
      if (ev.attendees.contains(from)) {
        ev.attendees = [for (final a in ev.attendees) a == from ? to : a];
      }
      if (ev.createdBy == from) ev.createdBy = to;
    }
    for (final list in ws.taskLists) {
      for (final t in list.tasks) {
        if (t.assignee == from) t.assignee = to;
        if (t.createdBy == from) t.createdBy = to;
        if (t.completedBy == from) t.completedBy = to;
      }
    }
    for (final list in ws.shoppingLists) {
      for (final item in list.items) {
        if (item.addedBy == from) item.addedBy = to;
      }
    }
  }

  /// Completes with whether every family's writes were acknowledged.
  Future<bool> _persistAllFamilies(String meUid) async {
    final results = await Future.wait([
      for (final f in families)
        _persistFamily(f, workspaces[f.id] ?? Workspace.empty()),
    ]);
    return !results.contains(false);
  }

  // ----------------------------------------------------- create / join
  Future<String?> cloudCreateFamily({
    required String meUid,
    required String name,
    required String username,
    required String password,
    String? picture,
  }) async {
    final slug = familySlug(username);
    try {
      // Usernames are global handles. Reject one already claimed by another
      // family before writing anything. The handle doc is readable by any
      // signed-in user (it holds no secrets), so this lookup is allowed.
      final existingHandle = await _familyHandleRef(
        slug,
      ).get().timeout(kCloudOpTimeout);
      if (existingHandle.exists) {
        return 'That family username is taken';
      }

      final fid = 'fam_${uid()}';
      final me = FamilyMember(
        id: meUid,
        name: user?.name ?? '',
        email: user?.email ?? '',
        initials: user?.initials ?? '?',
        color: kMemberColors[0],
        uid: meUid,
        photo: user?.photo,
        role: 'owner',
        status: 'active',
      );
      final fam = Family(
        id: fid,
        name: name.trim(),
        username: slug,
        picture: picture,
        ownerUid: meUid,
        memberUids: [meUid],
        members: [me],
      );
      final ws = Workspace.empty();
      // The iterated, randomly-salted password hash (v2 — see
      // [hashFamilyPasswordV2]) lives on the family doc itself, which is
      // readable ONLY by members (see firestore.rules). A non-member joining
      // proves knowledge of the password by matching this `joinHash`; they can
      // never read it, which prevents offline brute-forcing. The plaintext is
      // NEVER persisted anywhere — only cached in memory for this session so
      // the "Invite someone" sheet can show what was just typed.
      final joinSalt = newJoinSalt();
      final joinHash = hashFamilyPasswordV2(password, joinSalt);
      _sessionFamilyPasswords[fid] = password;
      await _familyDocRef(fid)
          .set({...familyMetaDoc(fam), 'joinHash': joinHash, 'joinScheme': 2})
          .timeout(kCloudOpTimeout);
      try {
        // The random salt rides on the PUBLIC handle doc: a joining client
        // must derive its proof before it can read the family doc, and a salt
        // only needs to be unique — not secret — to do its job.
        await _familyHandleRef(slug)
            .set({'familyId': fid, 'ownerUid': meUid, 'joinSalt': joinSalt})
            .timeout(kCloudOpTimeout);
        _metaBase[fid] = _metaOf(fam);
        _markFreshCloudFamily(fid);
        if (!await _persistFamily(fam, ws)) {
          throw StateError('initial records write rejected');
        }
      } catch (e) {
        // Roll back both docs so we leave neither an unjoinable orphan family
        // (no resolvable handle) nor a dangling handle pointing at nothing
        // (the section write can fail after the handle already landed).
        await _familyHandleRef(slug).delete().catchError((_) {});
        await _familyDocRef(fid).delete().catchError((_) {});
        debugPrint('[cloud] createFamily handle/sections write failed: $e');
        return 'Could not create family right now';
      }
      workspaces[fid] = ws;
      update(() {
        families = [...families, fam];
        familyId = fid;
        _adoptActiveWorkspace();
        screen = 'overview';
        swipedId = null;
        collapsed = {};
      });
      // The family + handle now exist server-side, so creation has succeeded.
      // Durably record membership in the user doc before returning so a relaunch
      // finds this family instead of the onboarding gate (issue #128). We just
      // awaited online writes above, so this ack is fast; it's bounded anyway.
      await _recordMembership(meUid);
      await bindCloudSync(meUid);
      flash('Created ${fam.name}');
      return null;
    } on TimeoutException {
      return 'Could not create family right now';
    } catch (e) {
      debugPrint('[cloud] createFamily failed: $e');
      return 'Could not create family right now';
    }
  }

  Future<String?> cloudJoinFamily({
    required String meUid,
    required String username,
    required String password,
  }) async {
    final slug = familySlug(username);
    if (slug.isEmpty) return 'Enter a family username';
    try {
      // Resolve the public handle to find which family doc to write to. The
      // handle holds no secret material, so non-members may read it.
      final handleSnap = await _familyHandleRef(
        slug,
      ).get().timeout(kCloudOpTimeout);
      final handle = handleSnap.data();
      final fid = (handle?['familyId'] ?? '').toString();
      if (!handleSnap.exists || fid.isEmpty) {
        return 'No family found with that username';
      }
      if (families.any((f) => f.id == fid)) {
        return 'You\u2019re already in this family';
      }

      // We may already be a member server-side even though this device's local
      // list doesn't show it \u2014 e.g. the best-effort user-doc write never
      // reached the backend last time, or this account seeded the demo family.
      // Only members can read the family doc, so a successful read means we
      // already belong: adopt it WITHOUT appending a second membership row,
      // which is exactly what produced the repeated users in issue #125.
      try {
        final mineSnap = await _familyDocRef(
          fid,
        ).get().timeout(kCloudOpTimeout);
        final mineData = mineSnap.data();
        if (mineSnap.exists && mineData != null) {
          // A migrated family's meta doc no longer carries the legacy
          // `workspace` blob, so the sections MUST be fetched before adopting
          // — otherwise this path adopted an empty workspace, and an edit in
          // the following seconds could persist that emptiness over the
          // family's real shared data.
          _noteKidStatus(fid, mineData);
          await _fetchAllRecords([fid]);
          _adoptJoinedFamily(fid, mineData, meUid);
          await _recordMembership(meUid);
          await bindCloudSync(meUid);
          flash('Joined ${curFamily()?.name ?? 'family'}');
          return null;
        }
      } on FirebaseException catch (e) {
        // `permission-denied` just means we aren't a member yet \u2014 fall through
        // to the password-verified self-join below. Anything else is a real
        // failure we shouldn't paper over as a bad password.
        if (e.code != 'permission-denied') {
          debugPrint('[cloud] joinFamily pre-read failed: ${e.code}');
          return 'Could not join family right now';
        }
      }

      // Append ONLY our uid to `memberUids`. The password is verified
      // server-side by security rules: the write is rejected unless
      // `joinProof` matches the family's (unreadable) `joinHash`. The proof
      // scheme is picked from the handle doc: a random `joinSalt` there means
      // the iterated v2 hash, no salt means a legacy v1 family. Our display
      // row in `members` is appended in a SECOND write below, once we ARE a
      // member — the rules deliberately no longer let a joiner shape the
      // members array (a joiner could otherwise append themselves with an
      // impersonated identity or a fake 'owner' role before anyone knew them).
      final joinProof = joinProofFor(password, slug, handle);
      final me = FamilyMember(
        id: meUid,
        name: user?.name ?? '',
        email: user?.email ?? '',
        initials: user?.initials ?? '?',
        color: kMemberColors[families.length % kMemberColors.length],
        uid: meUid,
        photo: user?.photo,
        role: 'member',
        status: 'active',
      );
      try {
        await _familyDocRef(fid)
            .update({
              'memberUids': FieldValue.arrayUnion([meUid]),
              'joinProof': joinProof,
              'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .timeout(kCloudOpTimeout);
      } on FirebaseException catch (e) {
        // `permission-denied` is what the rules return for a wrong password.
        if (e.code == 'permission-denied') return 'Incorrect password';
        debugPrint('[cloud] joinFamily write failed: ${e.code}');
        return 'Could not join family right now';
      }

      // We are now a member: append our display row to `members` and drop the
      // transient `joinProof` so it isn't left lingering on the shared doc
      // (best-effort: it is only ever readable by members anyway, and
      // `dedupeMembers` repairs a missed row on next load).
      unawaited(
        _familyDocRef(fid)
            .update({
              'members': FieldValue.arrayUnion([me.toJson()]),
              'joinProof': FieldValue.delete(),
            })
            .catchError((_) {}),
      );

      final snap = await _familyDocRef(fid).get().timeout(kCloudOpTimeout);
      final data = snap.data();
      if (data == null) return 'Could not join family right now';
      await _fetchAllRecords([fid]);
      _adoptJoinedFamily(fid, data, meUid, selfRow: me);
      // Durably record membership before returning so a relaunch finds this
      // family rather than the onboarding gate (issue #128).
      await _recordMembership(meUid);
      await bindCloudSync(meUid);
      flash('Joined ${curFamily()?.name ?? 'family'}');
      return null;
    } on TimeoutException {
      return 'Could not join family right now';
    } catch (e) {
      debugPrint('[cloud] joinFamily failed: $e');
      return 'Could not join family right now';
    }
  }

  /// Loads a (just-joined or already-joined) family from its document into local
  /// state and makes it the active workspace. Replaces an existing local entry
  /// for the same family instead of appending, so adopting a family we already
  /// hold can't produce a duplicate (issue #125).
  void _adoptJoinedFamily(
    String fid,
    Map<String, dynamic> data,
    String meUid, {
    FamilyMember? selfRow,
  }) {
    final fam = _familyFromDoc(fid, data);
    // Our own display row is appended in a separate (best-effort, unawaited)
    // write right after the join lands, so the doc we just read may not carry
    // it yet — add it locally rather than showing a family we're missing from.
    if (selfRow != null && !fam.members.any((m) => m.uid == meUid)) {
      fam.members = [...fam.members, selfRow];
    }
    _metaBase[fid] = _metaFromDoc(fid, data);
    final blob = data['workspace'];
    if (blob is Map) {
      _legacyBlob[fid] = Map<String, dynamic>.from(blob);
    } else {
      _legacyBlob.remove(fid);
    }
    final ws = _workspaceFromCloud(fid);
    workspaces[fid] = ws;
    unawaited(_migrateLegacyData(fid));
    final alreadyLocal = families.any((f) => f.id == fid);
    update(() {
      families = alreadyLocal
          ? [for (final f in families) f.id == fid ? fam : f]
          : [...families, fam];
      familyId = fid;
      _adoptActiveWorkspace();
      screen = 'overview';
      swipedId = null;
      collapsed = {};
    });
  }

  /// Deletes a family's workspace section docs, then the meta doc itself.
  /// Deleting a Firestore document never deletes its subcollections, so
  /// without this the sections would linger as unreachable orphans.
  Future<void> _deleteFamilyDocs(String fid) async {
    try {
      final snaps = await Future.wait([
        for (final col in kRecordCollections)
          _recordQuery(fid, col).get().timeout(kCloudOpTimeout),
      ]);
      await _commitInChunks([
        for (final snap in snaps)
          for (final d in snap.docs) (b) => b.delete(d.reference),
      ]);
    } catch (e) {
      debugPrint('[cloud] record cleanup failed for $fid: $e');
    }
    await _familyDocRef(fid).delete();
    _cloudBase.remove(fid);
    _cloudLoaded.remove(fid);
    _legacyBlob.remove(fid);
    _metaBase.remove(fid);
  }

  /// Returns null on success, or a user-facing error message. The caller has
  /// already removed the family locally, so a silent cloud failure would make
  /// it resurrect from Firestore on next boot with no explanation.
  Future<String?> cloudDeleteFamily(String meUid, String fid) async {
    try {
      final snap = await _familyDocRef(fid).get();
      final data = snap.data();
      if (data != null && (data['ownerUid'] ?? '') == meUid) {
        // The owner also removes the public handle so a stale username can
        // never resolve to a missing family (previously done by a Function).
        final slug = (data['username'] ?? '').toString();
        if (slug.isNotEmpty) {
          await _familyHandleRef(slug).delete().catchError((_) {});
        }
        await _deleteFamilyDocs(fid);
      } else {
        await _familyDocRef(fid).update({
          'memberUids': FieldValue.arrayRemove([meUid]),
        });
      }
      await _recordMembership(meUid);
      return null;
    } catch (e) {
      debugPrint('[cloud] deleteFamily failed: $e');
      return 'Could not delete the family in the cloud — it may reappear. '
          'Check your connection and try again.';
    }
  }

  /// Persists a family the signed-in user is leaving (issue #133). [fam] has
  /// already had this user removed from `members`/`memberUids` and — when an
  /// owner is leaving — a remaining member promoted. If no members remain the
  /// family and its public handle are deleted; otherwise the handed-off document
  /// is written so the new owner + dropped membership are durable.
  /// Returns null on success, or a user-facing error message (see
  /// [cloudDeleteFamily] for why failures must surface).
  Future<String?> cloudLeaveFamily(String meUid, Family fam) async {
    try {
      if (fam.memberUids.isEmpty) {
        final slug = fam.username;
        if (slug.isNotEmpty) {
          await _familyHandleRef(slug).delete().catchError((_) {});
        }
        await _deleteFamilyDocs(fam.id);
      } else {
        final ok = await _persistFamily(
          fam,
          workspaces[fam.id] ?? Workspace.empty(),
        );
        if (!ok) throw StateError('leave write rejected');
      }
      await _recordMembership(meUid);
      return null;
    } catch (e) {
      debugPrint('[cloud] leaveFamily failed: $e');
      return 'Could not leave the family in the cloud — it may reappear. '
          'Check your connection and try again.';
    }
  }

  /// Detaches the signed-in user from every family — deleting any family they
  /// are the sole member of (and its public handle) and otherwise removing only
  /// their membership — then drops their user doc and Firebase auth account.
  Future<void> _deleteAccountCloud(String meUid) async {
    for (final f in [...families]) {
      try {
        final others = f.memberUids.where((u) => u != meUid).toList();
        if (others.isEmpty) {
          final slug = f.username;
          if (slug.isNotEmpty) {
            await _familyHandleRef(slug).delete().catchError((_) {});
          }
          await _deleteFamilyDocs(f.id);
        } else {
          await _familyDocRef(f.id).update({
            'memberUids': FieldValue.arrayRemove([meUid]),
          });
        }
      } catch (e) {
        debugPrint('[cloud] deleteAccount family ${f.id} failed: $e');
      }
    }
    try {
      final staged = await _unsavedRef(meUid).get().timeout(kCloudOpTimeout);
      await _commitInChunks([
        for (final d in staged.docs) (b) => b.delete(d.reference),
      ]);
    } catch (e) {
      debugPrint('[cloud] deleteAccount unsaved changes failed: $e');
    }
    await _userDocRef(meUid).delete().catchError((_) {});
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      // `requires-recent-login` can block deletion; the cloud data is already
      // detached, so the caller still signs the user out locally.
      debugPrint('[auth] account delete failed: ${e.code}');
    }
  }
  // coverage:ignore-end

  // -------------------------------------------------------- local mode
  /// Salt for the local registry's stored password hash.
  String _localJoinSalt(String slug) => 'thrive-local::$slug';

  /// Verifies [password] against a registry [entry]: hashed entries compare
  /// via [hashFamilyPassword]; entries written before hashing still hold the
  /// plaintext and compare directly (they're migrated on successful join).
  bool _localPasswordMatches(
    Map<String, dynamic> entry,
    String slug,
    String password,
  ) {
    final hash = entry['passHash'];
    if (hash is String && hash.isNotEmpty) {
      return hash == hashFamilyPassword(password, _localJoinSalt(slug));
    }
    return (entry['password'] ?? '') == password;
  }

  /// Loads the local family registry blob (no-Firebase / demo mode).
  Future<Map<String, dynamic>> loadRegistry() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kRegistryKey);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(json.decode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> saveRegistry(Map<String, dynamic> reg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kRegistryKey, json.encode(reg));
  }

  /// Returns (creating on first use) a stable id for this device's local,
  /// no-Firebase identity — this device's `myId` when not signed in via
  /// Firebase.
  Future<String> _localSelfUid() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(kLocalSelfUidKey);
    if (id == null || id.isEmpty) {
      id = uid();
      await prefs.setString(kLocalSelfUidKey, id);
    }
    return id;
  }

  /// Offline/local equivalent of leaving a family (issue #133): writes [fam]'s
  /// post-departure member list (this user removed, any new owner promoted) back
  /// to the registry so a later re-join sees the handed-off family. Drops the
  /// registry entry entirely when no members remain.
  Future<void> _leaveFamilyLocal(Family fam) async {
    final slug = fam.username;
    if (slug.isEmpty) return;
    final reg = await loadRegistry();
    if (fam.members.isEmpty) {
      reg.remove(slug);
    } else {
      final entry = reg[slug];
      if (entry is! Map) return;
      final map = Map<String, dynamic>.from(entry);
      map['members'] = fam.members.map((m) => m.toJson()).toList();
      reg[slug] = map;
    }
    await saveRegistry(reg);
  }

  /// Mirrors each locally-persisted family's live state (name, picture,
  /// members, workspace) into its registry entry on every local persist.
  /// The registry used to be written only at create/join time, so another
  /// local user joining later saw the shared workspace frozen at creation.
  /// Families without a registry entry (e.g. the seeded `fam_main`) are
  /// untouched.
  Future<void> _refreshLocalRegistry() async {
    if (families.isEmpty) return;
    final reg = await loadRegistry();
    if (reg.isEmpty) return;
    var changed = false;
    for (final f in families) {
      final entry = reg[f.username];
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      map['name'] = f.name;
      map['picture'] = f.picture;
      map['members'] = f.members.map((m) => m.toJson()).toList();
      map['workspace'] = (workspaces[f.id] ?? Workspace.empty()).toJson();
      reg[f.username] = map;
      changed = true;
    }
    if (changed) await saveRegistry(reg);
  }

  Future<String?> localCreateFamily({
    required String name,
    required String username,
    required String password,
    String? picture,
  }) async {
    final slug = familySlug(username);
    final reg = await loadRegistry();
    if (reg.containsKey(slug) || families.any((f) => f.username == slug)) {
      return 'That family username is taken';
    }
    final id = 'fam_${uid()}';
    final selfUid = await _localSelfUid();
    final me = FamilyMember(
      id: selfUid,
      name: user?.name ?? '',
      email: user?.email ?? '',
      initials: user?.initials ?? '?',
      color: kMemberColors[0],
      uid: selfUid,
      photo: user?.photo,
      role: 'owner',
      status: 'active',
    );
    final fam = Family(
      id: id,
      name: name.trim(),
      username: slug,
      picture: picture,
      members: [me],
    );
    final ws = Workspace.empty();
    workspaces[id] = ws;
    _sessionFamilyPasswords[id] = password;
    reg[slug] = {
      'username': slug,
      // Only a salted hash is persisted — SharedPreferences is plaintext on
      // disk, and users reuse personal passwords. The plaintext lives solely
      // in the in-memory session cache for the invite sheet.
      'passHash': hashFamilyPassword(password, _localJoinSalt(slug)),
      'name': fam.name,
      'picture': picture,
      'members': [me.toJson()],
      'workspace': ws.toJson(),
    };
    await saveRegistry(reg);
    update(() {
      families = [...families, fam];
      familyId = id;
      _adoptActiveWorkspace();
      screen = 'overview';
      swipedId = null;
      collapsed = {};
    });
    _persist();
    flash('Created ${fam.name}');
    return null;
  }

  Future<String?> localJoinFamily({
    required String username,
    required String password,
  }) async {
    final slug = familySlug(username);
    if (slug.isEmpty) return 'Enter a family username';
    final reg = await loadRegistry();
    final entry = reg[slug];
    if (entry == null) return 'No family found with that username';
    final map = Map<String, dynamic>.from(entry as Map);
    if (!_localPasswordMatches(map, slug, password)) {
      return 'Incorrect password';
    }
    // Migrate a legacy plaintext-password entry to the hashed form now that
    // the password has been proven.
    if (map.containsKey('password')) {
      map
        ..remove('password')
        ..['passHash'] = hashFamilyPassword(password, _localJoinSalt(slug));
    }
    if (families.any((f) => f.username == slug)) {
      return 'You\u2019re already in this family';
    }
    final id = 'fam_${uid()}';
    final selfUid = await _localSelfUid();
    final fetchedMembers = [
      for (final m in (map['members'] as List? ?? []))
        FamilyMember.fromJson(Map<String, dynamic>.from(m as Map)),
    ];
    // Rewrites any legacy `'me'`-tagged row (e.g. the family's original
    // local creator, from before this fix) to its own distinct id. None of
    // these can be us — we're not a member yet — so nothing is claimed as
    // [selfUid], preventing a collision with our own (already-distinct,
    // uid-based) row added below.
    _migrateLegacyMeIdsInList(fetchedMembers, selfUid, false);
    final me = FamilyMember(
      id: selfUid,
      name: user?.name ?? '',
      email: user?.email ?? '',
      initials: user?.initials ?? '?',
      color: kMemberColors[families.length % kMemberColors.length],
      uid: selfUid,
      photo: user?.photo,
      role: 'member',
      status: 'active',
    );
    final members = dedupeMembers([...fetchedMembers, me]);
    final fam = Family(
      id: id,
      name: (map['name'] ?? 'Family').toString(),
      username: slug,
      picture: map['picture']?.toString(),
      members: members,
    );
    final ws = (map['workspace'] is Map)
        ? Workspace.fromJson(Map<String, dynamic>.from(map['workspace'] as Map))
        : Workspace.empty();
    workspaces[id] = ws;
    map['members'] = fam.members.map((m) => m.toJson()).toList();
    reg[slug] = map;
    _sessionFamilyPasswords[id] = password;
    await saveRegistry(reg);
    update(() {
      families = [...families, fam];
      familyId = id;
      _adoptActiveWorkspace();
      screen = 'overview';
      swipedId = null;
      collapsed = {};
    });
    _persist();
    flash('Joined ${fam.name}');
    return null;
  }

  // --------------------------------------------------------- helpers
  /// Points the active accounts/cats/data at the current family's workspace,
  /// after migrating any legacy literal `'me'` still stored in this
  /// workspace's calendar/list/shopping data (see
  /// `_migrateLegacyMeReferencesInWorkspace`).
  void _adoptActiveWorkspace() {
    // `workspaces[familyId]` IS the active state (the state accessors read
    // through to it), so adopting only needs the legacy-`'me'` migration —
    // and regenerating the recurring copies the cloud never stores (see
    // [isDerivedSeriesCopy]): a workspace rebuilt from records lacks them.
    _migrateLegacyMeReferencesInWorkspace(_activeWs);
    _syncRecurringSeries();
  }

  /// One-time migration for workspace data (calendar events, tasks, shopping
  /// items) that still carries the legacy literal `'me'` sentinel instead of
  /// a real, stable member id (see `myId`). Before this fix, `'me'` in shared
  /// workspace data was a *relative* token meant to resolve to "whichever
  /// device is viewing" — but since the workspace is a single shared blob,
  /// this made an event/task genuinely assigned to one specific family
  /// member appear as "assigned to me" on every other member's device too.
  /// Rewriting any stray `'me'` here to this device's own real [myId]
  /// preserves the historic (if bugged) intent — data literally created as
  /// `'me'` was created by this device — while ensuring it never again
  /// resolves differently depending on who's looking.
  void _migrateLegacyMeReferencesInWorkspace(Workspace ws) {
    final id = myId;
    for (final ev in ws.events) {
      var changed = false;
      final attendees = [
        for (final a in ev.attendees)
          if (a == 'me')
            () {
              changed = true;
              return id;
            }()
          else
            a,
      ];
      if (changed) ev.attendees = attendees;
      if (ev.createdBy == 'me') ev.createdBy = id;
    }
    for (final list in ws.taskLists) {
      for (final t in list.tasks) {
        if (t.assignee == 'me') t.assignee = id;
        if (t.createdBy == 'me') t.createdBy = id;
        if (t.completedBy == 'me') t.completedBy = id;
      }
    }
    for (final list in ws.shoppingLists) {
      for (final item in list.items) {
        if (item.addedBy == 'me') item.addedBy = id;
      }
    }
  }

  /// One-time migration for family data that still carries the legacy
  /// `'me'` sentinel id (from before every member's own row always used its
  /// real, stable id — see `myId`). When [claim] is true (the default —
  /// used when reloading/migrating a family we're already in), the first
  /// stale `'me'` row is rewritten to [meId] permanently, since a literal
  /// `'me'` there could only ever have been written by whichever single
  /// device considered itself `'me'` at the time; any *additional* stale
  /// `'me'` row (e.g. legacy data from two different devices merged into
  /// the same doc/registry entry) is given a fresh, unique id instead —
  /// `'me'` must never resolve to more than one member, or their identities
  /// (and calendar events, tasks, etc.) merge. When [claim] is false (used
  /// right before *joining* a family, whose members can't yet include us),
  /// every stale `'me'` row is known to be a foreign member's, so all of
  /// them get a fresh id and none are claimed as [meId].
  void _migrateLegacyMeIds(Family f, [String? meId, bool claim = true]) =>
      _migrateLegacyMeIdsInList(f.members, meId, claim);

  void _migrateLegacyMeIdsInList(
    List<FamilyMember> members, [
    String? meId,
    bool claim = true,
  ]) {
    final id = meId ?? myId;
    var claimed = !claim;
    for (final m in members) {
      if (m.id != 'me') continue;
      if (!claimed) {
        m.id = id;
        m.uid ??= id;
        claimed = true;
      } else {
        m.id = uid();
      }
    }
  }

  /// Runs [_migrateLegacyMeIds] over every locally-held family.
  void _migrateLegacyMeIdsAll(String meId) {
    for (final f in families) {
      _migrateLegacyMeIds(f, meId);
    }
  }
}
