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
/// `localStorage['thrive.registry']`, so demo create/join works offline.
const String kRegistryKey = 'thrive.registry';

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
    'members': f.members.map(_externalizeMember).toList(),
    'workspace': ws.toJson(),
    'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Serializes a member for shared storage. The local `'me'` sentinel id is
  /// replaced with the member's stable uid so multiple users sharing a family
  /// don't all collide on `id == 'me'`.
  Map<String, dynamic> _externalizeMember(FamilyMember m) {
    final json = m.toJson();
    if (m.id == 'me' && (m.uid ?? '').isNotEmpty) {
      json['id'] = m.uid;
    }
    return json;
  }

  Family _familyFromDoc(String fid, Map<String, dynamic> doc) {
    final fam = Family.fromJson({...doc, 'id': fid});
    fam.id = fid;
    return fam;
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
  /// user already had cloud state (or it was migrated), false when brand new.
  Future<bool> cloudBoot(String meUid) async {
    try {
      final userSnap = await _userDocRef(meUid).get();
      final userData = userSnap.data();
      if (userData != null && (userData['familyIds'] is List)) {
        await _loadFamiliesFromCloud(meUid, userData);
        return families.isNotEmpty;
      }
      return await _migrateLegacyState(meUid);
    } catch (e) {
      debugPrint('[cloud] boot failed: $e');
      return false;
    }
  }

  Future<void> _loadFamiliesFromCloud(
    String meUid,
    Map<String, dynamic> userData,
  ) async {
    final ids = [for (final i in (userData['familyIds'] as List)) i.toString()];
    final loadedFamilies = <Family>[];
    final loadedWorkspaces = <String, Workspace>{};
    for (final fid in ids) {
      final snap = await _familyDocRef(fid).get();
      final data = snap.data();
      if (data == null) continue;
      loadedFamilies.add(_familyFromDoc(fid, data));
      loadedWorkspaces[fid] = _workspaceFromDoc(data);
    }
    if (loadedFamilies.isEmpty) return;

    var active = (userData['activeFamilyId'] ?? '').toString();
    if (!loadedWorkspaces.containsKey(active)) active = loadedFamilies.first.id;

    families = loadedFamilies;
    workspaces = loadedWorkspaces;
    familyId = active;
    _adoptActiveWorkspace();
    year = (userData['year'] as num?)?.toInt() ?? year;
    monthIdx = ((userData['monthIdx'] as num?)?.toInt() ?? monthIdx).clamp(
      0,
      kMonthKeys.length - 1,
    );
    final rawScreen = (userData['screen'] ?? screen).toString();
    if (const {'overview', 'stats', 'settings'}.contains(rawScreen)) {
      screen = rawScreen;
    }
    _localizeMe(meUid);
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
      _localizeMeIn(f, meUid);
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
        final remoteMillis = (data['updatedAtMillis'] as num?)?.toInt() ?? 0;
        if (remoteMillis <= _lastSyncedAtMillis) return;
        _applyingCloudSnapshot = true;
        final fam = _familyFromDoc(fid, data);
        final ws = _workspaceFromDoc(data);
        final idx = families.indexWhere((f) => f.id == fid);
        if (idx >= 0) {
          families[idx] = fam;
        } else {
          families = [...families, fam];
        }
        workspaces[fid] = ws;
        if (fid == familyId) _adoptActiveWorkspace();
        _localizeMe(meUid);
        _lastSyncedAtMillis = remoteMillis;
        _applyingCloudSnapshot = false;
        if (mounted) update(() {});
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
      'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
        id: 'me',
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
      // Commit the family doc, then publish its public handle. Bounded: awaiting
      // a Firestore write only resolves once the backend acks it, so an
      // offline/flaky connection surfaces an error instead of stranding the
      // user on "Creating…".
      await _familyDocRef(fid)
          .set({..._familyToDoc(fam, ws), 'joinHash': joinHash})
          .timeout(kCloudOpTimeout);
      try {
        await _familyHandleRef(slug)
            .set({'familyId': fid, 'ownerUid': meUid})
            .timeout(kCloudOpTimeout);
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
      // Recording membership in the user doc is durable via offline persistence
      // and must NOT block the UI — awaiting it could hang on a dropped
      // connection and strand the user on the spinner.
      unawaited(_writeUserDoc(meUid).catchError((_) {}));
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
        await _familyDocRef(fid).update({
          'memberUids': FieldValue.arrayUnion([meUid]),
          'members': FieldValue.arrayUnion([_externalizeMember(me)]),
          'joinProof': joinProof,
          'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': FieldValue.serverTimestamp(),
        }).timeout(kCloudOpTimeout);
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
      final fam = _familyFromDoc(fid, data);
      final ws = _workspaceFromDoc(data);
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
      _localizeMeIn(fam, meUid);
      // Best-effort: durable via offline persistence, must not block the UI.
      unawaited(_writeUserDoc(meUid).catchError((_) {}));
      await bindCloudSync(meUid);
      flash('Joined ${fam.name}');
      return null;
    } on TimeoutException {
      return 'Could not join family right now';
    } catch (e) {
      debugPrint('[cloud] joinFamily failed: $e');
      return 'Could not join family right now';
    }
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

  /// Seeds the design's demo family (`vanderberg` / `demo`) so the join flow is
  /// discoverable offline.
  Future<void> ensureDemoFamily() async {
    final reg = await loadRegistry();
    if (reg.containsKey('vanderberg')) return;
    final ws = Workspace.empty();
    reg['vanderberg'] = {
      'username': 'vanderberg',
      'password': 'demo',
      'name': 'van der Berg family',
      'picture': null,
      'members': [
        FamilyMember(
          id: 'owner_demo',
          name: 'Sophie van der Berg',
          email: 'sophie@vanderberg.nl',
          initials: 'SB',
          color: kMemberColors[2],
          role: 'owner',
          status: 'active',
        ).toJson(),
        FamilyMember(
          id: 'm_demo2',
          name: 'Tom van der Berg',
          email: 'tom@vanderberg.nl',
          initials: 'TB',
          color: kMemberColors[3],
          role: 'member',
          status: 'active',
        ).toJson(),
      ],
      'workspace': ws.toJson(),
    };
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
    final me = FamilyMember(
      id: 'me',
      name: user?.name ?? '',
      email: user?.email ?? '',
      initials: user?.initials ?? '?',
      color: kMemberColors[0],
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
    final me = FamilyMember(
      id: 'me',
      name: user?.name ?? '',
      email: user?.email ?? '',
      initials: user?.initials ?? '?',
      color: kMemberColors[families.length % kMemberColors.length],
      photo: user?.photo,
      role: 'member',
      status: 'active',
    );
    final members = [
      for (final m in (map['members'] as List? ?? []))
        FamilyMember.fromJson(Map<String, dynamic>.from(m as Map)),
      me,
    ];
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
    map['members'] = members.map((m) => m.toJson()).toList();
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
  /// Points the active accounts/cats/data at the current family's workspace.
  void _adoptActiveWorkspace() {
    final ws = workspaces[familyId] ?? Workspace.empty();
    workspaces[familyId] = ws;
    accounts = ws.accounts;
    cats = ws.cats;
    data = ws.data;
  }

  /// Tags the `me` member of every family with the signed-in uid so security
  /// rules and `isMe` checks line up after a cloud load.
  // coverage:ignore-start
  void _localizeMe(String meUid) {
    for (final f in families) {
      _localizeMeIn(f, meUid);
    }
  }

  void _localizeMeIn(Family f, String meUid) {
    for (final m in f.members) {
      if (m.uid == meUid || m.id == 'me') {
        m.uid = meUid;
        m.id = 'me';
      }
    }
  }

  // coverage:ignore-end
}
