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

/// Salted SHA-256 of a family join password, used only by the offline/demo
/// local registry. Cloud joins are verified server-side by a Cloud Function;
/// the client never sees or compares a cloud family's password hash.
String hashFamilyPassword(String password, String salt) {
  final digest = sha256.convert(utf8.encode('$salt::$password'));
  return digest.toString();
}

/// Salt used to derive a cloud family's `joinHash`. The salt must be derivable
/// by any joining client (which cannot read the family doc yet), so we use the
/// family's own username slug. This is verified server-side by security rules,
/// never on the client.
String _cloudJoinSalt(String slug) => 'thrive-family::$slug';

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

  // ------------------------------------------------------- (de)serialize
  Map<String, dynamic> _familyToDoc(Family f, Workspace ws) => {
    'name': f.name,
    'username': f.username,
    if (f.picture != null) 'picture': f.picture,
    'ownerUid': f.ownerUid,
    'memberUids': f.memberUids,
    'members': f.members.map((m) => m.toJson()).toList(),
    'workspace': ws.toJson(),
    'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Family _familyFromDoc(String fid, Map<String, dynamic> doc) {
    final fam = Family.fromJson({...doc, 'id': fid});
    fam.id = fid;
    fam.members = _dedupeMembers(fam.members);
    _migrateLegacyMeIds(fam);
    final joinPassword = doc['joinPassword'];
    if (joinPassword is String && joinPassword.isNotEmpty) {
      _sessionFamilyPasswords[fid] = joinPassword;
    }
    return fam;
  }

  /// Collapses members that share the same Firebase `uid` down to a single
  /// entry (preferring the owner row) so a person who ended up appended more
  /// than once no longer shows up repeatedly (issue #125). Invited members have
  /// no uid yet and are always preserved as-is. Loading through this also
  /// repairs already-corrupted family docs: the de-duped list is what the owner
  /// later persists back, cleaning the shared document.
  List<FamilyMember> _dedupeMembers(List<FamilyMember> members) {
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

  Workspace _workspaceFromDoc(Map<String, dynamic> doc) {
    final raw = doc['workspace'];
    if (raw is Map) {
      return Workspace.fromJson(Map<String, dynamic>.from(raw));
    }
    return Workspace.empty();
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
    Map<String, dynamic>? userData;
    try {
      userData = (await _userDocRef(meUid).get()).data();
    } catch (e) {
      debugPrint('[cloud] boot user-doc read failed: $e');
    }
    try {
      final snap = await _familiesCol()
          .where('memberUids', arrayContains: meUid)
          .get()
          .timeout(kCloudOpTimeout);
      final docs = <MapEntry<String, Map<String, dynamic>>>[
        for (final d in snap.docs) MapEntry(d.id, d.data()),
      ];
      if (docs.isNotEmpty) {
        _applyFamilyDocs(meUid, docs, userData);
        if (families.isNotEmpty) {
          // Repair the user-doc mirror so its `familyIds` reflects reality.
          unawaited(_writeUserDoc(meUid).catchError((_) {}));
          return true;
        }
      }
    } catch (e) {
      debugPrint('[cloud] boot membership query failed: $e');
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
    final docs = <MapEntry<String, Map<String, dynamic>>>[];
    for (final fid in ids) {
      final data = (await _familyDocRef(fid).get()).data();
      if (data != null) docs.add(MapEntry(fid, data));
    }
    _applyFamilyDocs(meUid, docs, userData);
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
      loadedWorkspaces[entry.key] = _workspaceFromDoc(entry.value);
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
    }
    _migrateLegacyMeIdsAll(meUid);
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
    try {
      _cloudSub = _userDocRef(meUid).snapshots().listen((snap) {
        final data = snap.data();
        if (data == null || data['familyIds'] is! List) return;
        if (_applyingCloudSnapshot) return;
        final active = (data['activeFamilyId'] ?? familyId).toString();
        if (active != familyId && workspaces.containsKey(active)) {
          _applyingCloudSnapshot = true;
          familyId = active;
          _adoptActiveWorkspace();
          _applyingCloudSnapshot = false;
          if (mounted) update(() {});
        }
        _bindActiveFamily(meUid);
      });
      _bindActiveFamily(meUid);
    } catch (e) {
      debugPrint('[cloud] bindCloudSync failed: $e');
    }
  }

  void _bindActiveFamily(String meUid) {
    final fid = familyId;
    _familySub?.cancel();
    try {
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
        final remoteMillis = (data['updatedAtMillis'] as num?)?.toInt() ?? 0;
        if (remoteMillis <= _lastSyncedAtMillis) return;
        _applyingCloudSnapshot = true;
        final ws = _workspaceFromDoc(data);
        final idx = families.indexWhere((f) => f.id == fid);
        if (idx >= 0) {
          families[idx] = fam;
        } else {
          families = [...families, fam];
        }
        workspaces[fid] = ws;
        if (fid == familyId) _adoptActiveWorkspace();
        _migrateLegacyMeIdsAll(meUid);
        _lastSyncedAtMillis = remoteMillis;
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
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastSyncedAtMillis = now;
    await _writeUserDoc(meUid);
    final f = curFamily();
    if (f != null) {
      _syncWorkspaces();
      if (!f.memberUids.contains(meUid)) f.memberUids.add(meUid);
      f.ownerUid ??= meUid;
      await _familyDocRef(f.id).set(
        _familyToDoc(f, workspaces[f.id] ?? Workspace.empty()),
        SetOptions(merge: true),
      );
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
    for (final f in families) {
      final ws = workspaces[f.id] ?? Workspace.empty();
      await _familyDocRef(
        f.id,
      ).set(_familyToDoc(f, ws), SetOptions(merge: true));
    }
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
      // The salted password hash lives on the family doc itself, which is
      // readable ONLY by members (see firestore.rules). A non-member joining
      // proves knowledge of the password by matching this `joinHash`; they can
      // never read it, which prevents offline brute-forcing.
      final joinHash = hashFamilyPassword(password, _cloudJoinSalt(slug));
      // The plaintext also lives here (as `joinPassword`) so any member can
      // view/share it later — e.g. from the "Invite someone" sheet. This is
      // safe: the field is on the same members-only doc as everything else
      // (see firestore.rules `allow read: if isMember()`), so it's exactly as
      // protected as the rest of the family's shared data.
      await _familyDocRef(fid)
          .set({
            ..._familyToDoc(fam, ws),
            'joinHash': joinHash,
            'joinPassword': password,
          })
          .timeout(kCloudOpTimeout);
      try {
        await _familyHandleRef(
          slug,
        ).set({'familyId': fid, 'ownerUid': meUid}).timeout(kCloudOpTimeout);
      } catch (e) {
        // Roll back the family doc so we don't leave an unjoinable orphan with
        // no resolvable handle.
        await _familyDocRef(fid).delete().catchError((_) {});
        debugPrint('[cloud] createFamily handle write failed: $e');
        return 'Could not create family right now';
      }
      _syncWorkspaces();
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

      // Build our membership entry and append it. The password is verified
      // server-side by security rules: the write is rejected unless `joinProof`
      // matches the family's (unreadable) `joinHash`. We never read the hash.
      final joinProof = hashFamilyPassword(password, _cloudJoinSalt(slug));
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
              'members': FieldValue.arrayUnion([me.toJson()]),
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

      // We are now a member, so we may read the family doc. Drop the transient
      // `joinProof` we wrote so it isn't left lingering on the shared doc
      // (best-effort: it is only ever readable by members anyway).
      unawaited(
        _familyDocRef(
          fid,
        ).update({'joinProof': FieldValue.delete()}).catchError((_) {}),
      );

      final snap = await _familyDocRef(fid).get().timeout(kCloudOpTimeout);
      final data = snap.data();
      if (data == null) return 'Could not join family right now';
      _adoptJoinedFamily(fid, data, meUid);
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
  void _adoptJoinedFamily(String fid, Map<String, dynamic> data, String meUid) {
    final fam = _familyFromDoc(fid, data);
    final ws = _workspaceFromDoc(data);
    _syncWorkspaces();
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

  Future<void> cloudDeleteFamily(String meUid, String fid) async {
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
        await _familyDocRef(fid).delete();
      } else {
        await _familyDocRef(fid).update({
          'memberUids': FieldValue.arrayRemove([meUid]),
        });
      }
      await _writeUserDoc(meUid);
    } catch (e) {
      debugPrint('[cloud] deleteFamily failed: $e');
    }
  }

  /// Persists a family the signed-in user is leaving (issue #133). [fam] has
  /// already had this user removed from `members`/`memberUids` and — when an
  /// owner is leaving — a remaining member promoted. If no members remain the
  /// family and its public handle are deleted; otherwise the handed-off document
  /// is written so the new owner + dropped membership are durable.
  Future<void> cloudLeaveFamily(String meUid, Family fam) async {
    try {
      if (fam.memberUids.isEmpty) {
        final slug = fam.username;
        if (slug.isNotEmpty) {
          await _familyHandleRef(slug).delete().catchError((_) {});
        }
        await _familyDocRef(fam.id).delete();
      } else {
        final ws = workspaces[fam.id] ?? Workspace.empty();
        await _familyDocRef(
          fam.id,
        ).set(_familyToDoc(fam, ws), SetOptions(merge: true));
      }
      await _writeUserDoc(meUid);
    } catch (e) {
      debugPrint('[cloud] leaveFamily failed: $e');
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
          await _familyDocRef(f.id).delete();
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
    _syncWorkspaces();
    workspaces[id] = ws;
    reg[slug] = {
      'username': slug,
      'password': password,
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
    if ((map['password'] ?? '') != password) return 'Incorrect password';
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
    final members = _dedupeMembers([...fetchedMembers, me]);
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
    _syncWorkspaces();
    workspaces[id] = ws;
    map['members'] = fam.members.map((m) => m.toJson()).toList();
    reg[slug] = map;
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
    final ws = workspaces[familyId] ?? Workspace.empty();
    _migrateLegacyMeReferencesInWorkspace(ws);
    workspaces[familyId] = ws;
    accounts = ws.accounts;
    cats = ws.cats;
    data = ws.data;
    taskLists = ws.taskLists;
    shoppingLists = ws.shoppingLists;
    events = ws.events;
    eventCategories = ws.eventCategories;
    importedCalendars = ws.importedCalendars;
    weeklyPlan = ws.weeklyPlan;
    calendarLayers = ws.calendarLayers;
    starsMap = ws.starsMap;
    kitchenEnabled = ws.kitchenEnabled;
    picMembers = ws.picMembers;
    kitchenLayerFilter = ws.kitchenLayerFilter;
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
