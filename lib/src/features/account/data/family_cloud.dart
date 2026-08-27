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

/// Upper bound for any single cloud round-trip (Firestore write/read). Awaiting a Firestore write resolves only once the backend acks
/// it, so with offline persistence a dropped connection would otherwise hang
/// the UI forever. Bounding every await turns that into a recoverable error.
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
  CollectionReference<Map<String, dynamic>> _workspaceCol(String fid) =>
      _familyDocRef(fid).collection('workspace');

  Family _familyFromDoc(String fid, Map<String, dynamic> doc) {
    final fam = Family.fromJson({...doc, 'id': fid});
    fam.id = fid;
    fam.members = dedupeMembers(fam.members);
    _migrateLegacyMeIds(fam);
    return fam;
  }

  // requires a live Firestore backend.
  // ----------------------------------------------------------- boot
  /// Loads the signed-in user's families from Firestore. Returns true when the
  /// user already belongs to a family (or legacy state was migrated), false when
  /// brand new.
  ///
  /// Membership is read from the families' own `memberUids` — the same field the
  /// security rules treat as the source of truth — rather than the per-user
  /// `familyIds` mirror, which is written best-effort and could lag a create or
  /// join and strand an existing member on the onboarding gate (issue #128).
  Future<bool> cloudBoot(String meUid) async {
    // Cache-first: with offline persistence on, a warm boot is served
    // entirely from the local Firestore cache — zero network round-trips
    // before the first frame. The snapshot listeners bound straight after
    // (bindCloudSync) deliver the authoritative server state and reconcile
    // any drift. A fresh install, a fresh sign-in or a cache wiped by the
    // crash-loop breaker has nothing cached, and boot falls through to the
    // network path below.
    try {
      const cacheOnly = GetOptions(source: Source.cache);
      final cachedUserData = await _userDocRef(meUid)
          .get(cacheOnly)
          .then<Map<String, dynamic>?>((d) => d.data())
          .catchError((Object _) => null);
      final snap = await _familiesCol()
          .where('memberUids', arrayContains: meUid)
          .get(cacheOnly);
      final docs = <MapEntry<String, Map<String, dynamic>>>[
        for (final d in snap.docs) MapEntry(d.id, d.data()),
      ];
      if (docs.isNotEmpty) {
        await _fetchAllSections([
          for (final d in docs) d.key,
        ], source: Source.cache);
        _applyFamilyDocs(meUid, docs, cachedUserData);
        if (families.isNotEmpty) return true;
      }
    } catch (e) {
      debugPrint('[cloud] cache-first boot unavailable: $e');
    }

    // Network path. The user-doc read and the membership query are
    // independent — run them concurrently to save a round-trip.
    final userDataFuture = _userDocRef(meUid)
        .get()
        .then<Map<String, dynamic>?>((d) => d.data())
        .catchError((Object e) {
          debugPrint('[cloud] boot user-doc read failed: $e');
          return null;
        });
    Map<String, dynamic>? userData;
    try {
      final snap = await _familiesCol()
          .where('memberUids', arrayContains: meUid)
          .get()
          .timeout(kCloudOpTimeout);
      userData = await userDataFuture;
      final docs = <MapEntry<String, Map<String, dynamic>>>[
        for (final d in snap.docs) MapEntry(d.id, d.data()),
      ];
      if (docs.isNotEmpty) {
        await _fetchAllSections([for (final d in docs) d.key]);
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
      return false;
    }
  }

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
      for (final fid in ids) _familyDocRef(fid).get(),
    ]);
    final docs = <MapEntry<String, Map<String, dynamic>>>[
      for (final (i, s) in snaps.indexed)
        if (s.data() != null) MapEntry(ids[i], s.data()!),
    ];
    await _fetchAllSections([for (final d in docs) d.key]);
    _applyFamilyDocs(meUid, docs, userData);
  }

  /// Loads every family's workspace subcollection concurrently into
  /// [_wsSectionCache] (payloads keyed by section id, timestamps stripped).
  /// Families that predate the split simply have no section docs and fall
  /// back to their legacy single `workspace` map on apply.
  Future<void> _fetchAllSections(
    List<String> fids, {
    Source source = Source.serverAndCache,
  }) async {
    await Future.wait([
      for (final fid in fids)
        _workspaceCol(fid)
            .get(GetOptions(source: source))
            .timeout(kCloudOpTimeout)
            .then((snap) {
              _adoptSectionSnapshot(fid, snap);
            })
            .catchError((Object e) {
              debugPrint('[cloud] workspace sections read failed for $fid: $e');
            }),
    ]);
  }

  /// Caches a workspace-subcollection snapshot's payloads (and their digests,
  /// so the next persist skips sections the server already has).
  void _adoptSectionSnapshot(
    String fid,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final sections = <String, Map<String, dynamic>>{};
    final digests = <String, String>{};
    for (final d in snap.docs) {
      final payload = Map<String, dynamic>.from(d.data())
        ..remove('updatedAtMillis')
        ..remove('updatedAt');
      sections[d.id] = payload;
      digests[d.id] = sectionDigest(payload);
    }
    _wsSectionCache[fid] = sections;
    _wsSectionDigests[fid] = digests;
  }

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
      loadedFamilies.add(_familyFromDoc(entry.key, entry.value));
      // Prefer the split subcollection sections; families that haven't
      // migrated yet still carry the legacy single `workspace` map.
      loadedWorkspaces[entry.key] =
          workspaceFromSections(_wsSectionCache[entry.key] ?? const {}) ??
          workspaceFromDoc(entry.value);
      // Cloud sections never carry card photos (issue #234) — restore the
      // ones this device already had from local storage.
      mergeCardPhotos(
        loadedWorkspaces[entry.key]!.cards,
        workspaces[entry.key]?.cards ?? const [],
      );
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
      homeBoard = parseHomeBoard(userData['homeBoard']) ?? homeBoard;
    }
    _migrateLegacyMeIdsAll(meUid);
    // Heal families still carrying the legacy single-doc `workspace` blob NOW
    // instead of waiting for the user's first edit: with offline persistence
    // on, that multi-MB blob is re-read from the SQLite cache on every later
    // launch and can overflow Android's ~2MB CursorWindow — a fatal,
    // un-catchable crash before the first frame. Persisting the split
    // sections also deletes the blob from the meta doc (see
    // _persistFamilySections), fixing the family for every member's device.
    for (final entry in docs) {
      if (entry.value['workspace'] is! Map) continue;
      final fam = loadedFamilies.firstWhere((f) => f.id == entry.key);
      unawaited(
        _persistFamilySections(fam, loadedWorkspaces[entry.key]!).catchError(
          (Object e) => debugPrint(
            '[cloud] legacy blob migration failed for ${entry.key}: $e',
          ),
        ),
      );
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
      f.ownerUid ??= meUid;
      if (!f.memberUids.contains(meUid)) f.memberUids.add(meUid);
      if (f.username.trim().isEmpty) f.username = familySlug(f.name);
      // This is solely-owned local data this device already had before its
      // first cloud login, so its own row is unambiguously `'me'` even
      // though it predates uid tracking.
      _migrateLegacyMeIds(f, meUid);
    }
    await _persistAllFamilies(meUid);
    await _writeUserDoc(meUid);
    return true;
  }

  // ----------------------------------------------------------- streams
  Future<void> bindCloudSync(String meUid) async {
    await _cloudSub?.cancel();
    await _familySub?.cancel();
    await _wsSub?.cancel();
    try {
      _cloudSub = _userDocRef(meUid).snapshots().listen((snap) {
        final data = snap.data();
        if (data == null || data['familyIds'] is! List) return;
        if (_applyingCloudSnapshot) return;
        // Home board edits made on another device (issue #240). Compared as
        // JSON so the every-persist rewrite of the user doc doesn't loop.
        final remoteBoard = parseHomeBoard(data['homeBoard']);
        if (remoteBoard != null &&
            json.encode([for (final e in remoteBoard) e.toJson()]) !=
                json.encode([
                  for (final e in homeBoard ?? <BoardEntry>[]) e.toJson(),
                ])) {
          homeBoard = remoteBoard;
          if (mounted) update(() {});
        }
        final active = (data['activeFamilyId'] ?? familyId).toString();
        if (active != familyId && workspaces.containsKey(active)) {
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

  void _bindActiveFamily(String meUid) {
    final fid = familyId;
    _boundFamilyId = fid;
    _familySub?.cancel();
    _wsSub?.cancel();
    try {
      // Per-section workspace stream: with persistence re-enabled Firestore
      // only re-downloads the section docs that actually changed, so another
      // member's edit costs one small doc, not the whole family blob.
      //
      // "Did the server change?" is answered by comparing section DIGESTS
      // against what we last wrote/received — never by comparing this
      // device's wall clock against another device's timestamps, which
      // silently dropped edits from any family member whose clock ran a
      // little behind.
      _wsSub = _workspaceCol(fid).snapshots().listen((snap) {
        if (snap.metadata.hasPendingWrites) return; // our own local echo
        final known = _wsSectionDigests[fid] ?? const <String, String>{};
        final incoming = <String, Map<String, dynamic>>{};
        final incomingDigests = <String, String>{};
        var changed = false;
        for (final d in snap.docs) {
          final payload = Map<String, dynamic>.from(d.data())
            ..remove('updatedAtMillis')
            ..remove('updatedAt');
          incoming[d.id] = payload;
          final digest = sectionDigest(payload);
          incomingDigests[d.id] = digest;
          if (known[d.id] != digest) changed = true;
        }
        for (final id in known.keys) {
          if (id != '__meta' && !incoming.containsKey(id)) changed = true;
        }
        if (!changed) return; // our own echo, or nothing new
        // Section-level merge: a debounced local edit may not have been
        // persisted yet. For each section, keep the LOCAL version when it
        // differs from what we last synced (the pending persist will upload
        // it); adopt the server's version otherwise. Without this, a remote
        // snapshot landing inside the 2s debounce window rebuilt the whole
        // workspace from server state and silently discarded the local edit.
        final localWs = workspaces[fid];
        final local = localWs == null
            ? const <String, Map<String, dynamic>>{}
            : workspaceSections(localWs);
        final merged = <String, Map<String, dynamic>>{...incoming};
        local.forEach((id, payload) {
          final localDigest = sectionDigest(payload);
          if (localDigest != known[id] && localDigest != incomingDigests[id]) {
            merged[id] = payload; // locally dirty — keep ours
          }
        });
        final ws = workspaceFromSections(merged);
        if (ws == null) return;
        // Card photos never travel through the cloud (issue #234), so carry
        // this device's local photos over into the rebuilt workspace.
        mergeCardPhotos(ws.cards, localWs?.cards ?? const []);
        // The digest cache always tracks the SERVER's state, so the next
        // persist re-uploads exactly the locally-kept sections.
        final meta = (_wsSectionDigests[fid] ?? const {})['__meta'];
        _wsSectionCache[fid] = incoming;
        _wsSectionDigests[fid] = {...incomingDigests, '__meta': ?meta};
        _applyingCloudSnapshot = true;
        workspaces[fid] = ws;
        if (fid == familyId) _adoptActiveWorkspace();
        _applyingCloudSnapshot = false;
        if (mounted) {
          update(() {});
          _rescheduleReminders();
        }
      });
      _familySub = _familyDocRef(fid).snapshots().listen((snap) {
        final data = snap.data();
        if (data == null) return;
        final fam = _familyFromDoc(fid, data);
        // We're no longer a member of this family (we left it, or an owner
        // removed us). Drop it locally and fall back to the next family — or
        // the create/join gate when it was our last — instead of re-adopting
        // it. The shared doc lives on for everyone else, so without this guard
        // the active-family stream fires on our own leave-write and keeps
        // re-adding a family we just left (issue #133).
        if (!fam.memberUids.contains(meUid)) {
          final present = families.any((f) => f.id == fid);
          if (!present && fid != familyId) return;
          _applyingCloudSnapshot = true;
          families = families.where((f) => f.id != fid).toList();
          workspaces.remove(fid);
          if (fid == familyId) {
            familyId = families.isNotEmpty ? families.first.id : 'fam_main';
            _adoptActiveWorkspace();
          }
          _applyingCloudSnapshot = false;
          if (mounted) update(() {});
          return;
        }
        // Change detection by content digest over the meta fields we own —
        // not by comparing another device's timestamp to our clock.
        final metaDigest = metaDocDigest(data);
        final digests = _wsSectionDigests.putIfAbsent(fid, () => {});
        if (digests['__meta'] == metaDigest) return;
        _applyingCloudSnapshot = true;
        final idx = families.indexWhere((f) => f.id == fid);
        if (idx >= 0) {
          families[idx] = fam;
        } else {
          families = [...families, fam];
        }
        // The workspace itself streams from the subcollection listener above;
        // only a family that predates the split (no section docs yet) still
        // syncs its legacy single `workspace` map through the meta doc.
        if ((_wsSectionCache[fid] ?? const {}).isEmpty) {
          workspaces[fid] = workspaceFromDoc(data);
        }
        if (fid == familyId) _adoptActiveWorkspace();
        _migrateLegacyMeIdsAll(meUid);
        digests['__meta'] = metaDigest;
        _applyingCloudSnapshot = false;
        if (mounted) {
          update(() {});
          _rescheduleReminders();
        }
      });
    } catch (e) {
      debugPrint('[cloud] family stream failed: $e');
    }
  }

  // ----------------------------------------------------------- persist
  Future<void> cloudPersist(String meUid) async {
    if (_applyingCloudSnapshot) return;
    await _writeUserDoc(meUid);
    final f = curFamily();
    if (f != null) {
      if (!f.memberUids.contains(meUid)) f.memberUids.add(meUid);
      f.ownerUid ??= meUid;
      await _persistFamilySections(f, workspaces[f.id] ?? Workspace.empty());
    }
  }

  /// Writes [f]'s metadata doc and only the workspace section docs whose
  /// payload digest changed since they were last written or received — one
  /// small batched write per edit instead of re-uploading the whole family
  /// blob. Sections that vanished locally (a deleted year or removed imported
  /// calendar) are deleted from the subcollection.
  ///
  /// The digest/payload caches are updated only AFTER the commit succeeds:
  /// updating them optimistically meant a failed commit (offline past the
  /// queue, rules rejection) left the cache claiming the server already had
  /// the data, silently suppressing every retry until restart.
  Future<void> _persistFamilySections(Family f, Workspace ws) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final sections = workspaceSections(ws);
    final digests = _wsSectionDigests.putIfAbsent(f.id, () => {});
    final cache = _wsSectionCache.putIfAbsent(f.id, () => {});
    final batch = FirebaseFirestore.instance.batch();
    // Cache mutations staged here run only once the batch has committed.
    final staged = <void Function()>[];

    final metaDigest = metaDocDigest(familyMetaDoc(f));
    // Once the sections are written (below, same batch), the legacy single-doc
    // `workspace` blob is dead weight on the meta doc — and, at multi-MB, the
    // very thing that used to crash Android's offline cache. Drop it once per
    // session (a no-op when already gone).
    final clearLegacy = !_legacyBlobCleared.contains(f.id);
    if (digests['__meta'] != metaDigest || clearLegacy) {
      batch.set(_familyDocRef(f.id), {
        ...familyMetaDoc(f),
        if (clearLegacy) 'workspace': FieldValue.delete(),
      }, SetOptions(merge: true));
      staged.add(() {
        digests['__meta'] = metaDigest;
        _legacyBlobCleared.add(f.id);
      });
    }
    sections.forEach((id, payload) {
      final digest = sectionDigest(payload);
      if (digests[id] == digest) return;
      batch.set(_workspaceCol(f.id).doc(id), {
        ...payload,
        'updatedAtMillis': now,
      });
      staged.add(() {
        digests[id] = digest;
        cache[id] = payload;
      });
    });
    for (final stale in digests.keys.toList()) {
      if (stale == '__meta' || sections.containsKey(stale)) continue;
      batch.delete(_workspaceCol(f.id).doc(stale));
      staged.add(() {
        digests.remove(stale);
        cache.remove(stale);
      });
    }
    if (staged.isEmpty) return;
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('[cloud] persist commit failed for ${f.id}: $e');
      // Caches untouched — the next persist retries these exact sections.
      if (mounted) {
        showError('Could not sync your latest changes — will retry.');
      }
      return;
    }
    for (final apply in staged) {
      apply();
    }
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
      if (homeBoard != null)
        'homeBoard': homeBoard!.map((e) => e.toJson()).toList(),
      'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Persists the user-doc mirror (profile, `familyIds`, active family, view
  /// state) and AWAITS the backend ack, so a freshly created or joined family is
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

  Future<void> _persistAllFamilies(String meUid) async {
    await Future.wait([
      for (final f in families)
        _persistFamilySections(f, workspaces[f.id] ?? Workspace.empty()),
    ]);
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
        await _persistFamilySections(fam, ws);
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
          await _fetchAllSections([fid]);
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
      await _fetchAllSections([fid]);
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
    final ws =
        workspaceFromSections(_wsSectionCache[fid] ?? const {}) ??
        workspaceFromDoc(data);
    workspaces[fid] = ws;
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
      final sections = await _workspaceCol(fid).get().timeout(kCloudOpTimeout);
      final batch = FirebaseFirestore.instance.batch();
      for (final d in sections.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[cloud] section cleanup failed for $fid: $e');
    }
    await _familyDocRef(fid).delete();
    _wsSectionCache.remove(fid);
    _wsSectionDigests.remove(fid);
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
      await _writeUserDoc(meUid);
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
        await _persistFamilySections(
          fam,
          workspaces[fam.id] ?? Workspace.empty(),
        );
      }
      await _writeUserDoc(meUid);
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
    // through to it), so adopting only needs the legacy-`'me'` migration.
    _migrateLegacyMeReferencesInWorkspace(_activeWs);
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
