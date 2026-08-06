part of 'package:family_money_management_app/main.dart';

/// Auth, profile and family mutations + avatar helpers, ported from the
/// design's `signInUser` / `saveProfile` / family methods.
/// Tracks whether the google_sign_in v7 singleton has been initialized.
bool _googleSignInInitialized = false;

/// OAuth 2.0 *Web* client id (client_type 3 in google-services.json). The
/// google_sign_in v7 plugin requires this as `serverClientId` on Android to
/// mint a Firebase-compatible id token — without it `authenticate()` throws
/// "serverClientId must be provided on Android". It is not a secret (it ships
/// in google-services.json) and is the same value across platforms.
const String _googleServerClientId =
    '825420918937-ni6ni1as5oa2sk00bs79ro71ge8ksj7i.apps.googleusercontent.com';

extension _ThriveAccountActions on _ThriveHomeState {
  // ----------------------------------------------------------- identity
  /// The current family, or null when signed out / none exist.
  Family? curFamily() {
    for (final f in families) {
      if (f.id == familyId) return f;
    }
    return families.isNotEmpty ? families.first : null;
  }

  /// True when the signed-in user owns the current family (or there is none).
  bool amOwner() {
    final f = curFamily();
    if (f == null) return true;
    for (final m in f.members) {
      if (m.id == 'me') return m.role == 'owner';
    }
    return true;
  }

  /// Renders an avatar: a cropped photo, else a colored initials tile.
  Widget avatarNode({
    String? photo,
    required String initials,
    Color? color,
    required double size,
    required double radius,
    double fs = 13,
    double opacity = 1,
  }) {
    Widget child;
    if (photo != null && photo.isNotEmpty) {
      try {
        child = Image.memory(
          base64Decode(photo),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      } catch (_) {
        child = _initialsTile(initials, color, size, fs);
      }
    } else {
      child = _initialsTile(initials, color, size, fs);
    }
    return Opacity(
      opacity: opacity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(width: size, height: size, child: child),
      ),
    );
  }

  Widget _initialsTile(String initials, Color? color, double size, double fs) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: color == null ? B.grad : null,
        color: color,
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          color: color == null ? Colors.white : contrastOn(color),
          fontWeight: FontWeight.w800,
          fontSize: fs,
        ),
      ),
    );
  }

  FamilyMember? _currentUserMember() {
    FamilyMember? me;
    final firebaseUid = _firebaseUid();
    for (final m in curFamily()?.members ?? const <FamilyMember>[]) {
      if (m.id == 'me' || (firebaseUid != null && m.uid == firebaseUid)) {
        me = m;
        break;
      }
    }
    return me;
  }

  ({String? photo, String initials, Color? color}) profileAvatarIdentity(
    AppUser u,
  ) {
    final me = _currentUserMember();
    return (
      photo: me?.photo ?? u.photo,
      initials: me?.initials ?? u.initials,
      color: me?.color ?? u.color,
    );
  }

  /// The signed-in user as an avatar identity.
  Widget _headerAvatar() {
    final u = user;
    if (u == null) {
      return Container(
        decoration: const BoxDecoration(gradient: B.grad),
        alignment: Alignment.center,
        child: logoMark(size: 18),
      );
    }
    final identity = profileAvatarIdentity(u);
    return avatarNode(
      photo: identity.photo,
      initials: identity.initials,
      color: identity.color,
      size: 34,
      radius: 11,
      fs: 13,
    );
  }

  /// Member role / status pill styling, mirrors `memberPill`.
  ({Color bg, Color fg, String label}) memberPill(String role, String status) {
    if (status == 'invited') {
      return (bg: B.amberSoft, fg: B.amberText, label: 'Invited');
    }
    if (role == 'owner') return (bg: B.soft, fg: B.deep, label: 'Owner');
    return (bg: B.faint, fg: B.soft2, label: 'Member');
  }

  // -------------------------------------------------------------- auth
  /// Signs a user in. Seeds a starter family on first sign-in, otherwise syncs
  /// the identity into existing families.
  void signInUser(AppUser u) {
    update(() {
      user = u;
      // In local/demo mode seed a starter family so the app is immediately
      // usable. In cloud mode we instead load the user's shared families (or
      // land on onboarding) — see the sign-in flows below.
      if (!_cloudBacked && families.isEmpty) {
        families = [seedFamily('fam_main', u)];
        familyId = 'fam_main';
        workspaces.putIfAbsent(
          'fam_main',
          () => Workspace(
            accounts: accounts,
            cats: cats,
            data: data,
            taskLists: taskLists,
            shoppingLists: shoppingLists,
          ),
        );
        final ws = workspaces['fam_main']!;
        accounts = ws.accounts;
        cats = ws.cats;
        data = ws.data;
        taskLists = ws.taskLists;
        shoppingLists = ws.shoppingLists;
      } else {
        // Cloud sign-in: the user's shared families are about to be fetched.
        // Mark them as resolving so the onboarding gate stays hidden until we
        // know whether they already belong to a family (#120).
        if (_cloudBacked) _resolvingFamilies = true;
        _syncMe(u);
      }
    });
    _persistUser();
    flash('Welcome, ${u.name.split(' ').first}');
  }

  // requires a live Firestore backend.
  // coverage:ignore-start
  /// After a successful Firebase sign-in, loads the shared families this user
  /// belongs to. Leaves `families` empty (→ onboarding) for brand-new users.
  Future<void> _loadCloudAfterSignIn() async {
    final uid = _firebaseUid();
    if (uid == null) return;
    try {
      await cloudBoot(uid);
      await bindCloudSync(uid);
    } finally {
      // Families are now resolved (loaded, migrated, or confirmed-none): let the
      // onboarding gate decide based on the real result (#120).
      _resolvingFamilies = false;
      if (mounted) update(() {});
    }
  }
  // coverage:ignore-end

  void signOut() {
    update(() {
      user = null;
      families = [];
      workspaces = {};
      familyId = 'fam_main';
      _resolvingFamilies = false;
    });
    _cloudSub?.cancel();
    _cloudSub = null;
    _familySub?.cancel();
    _familySub = null;
    if (firebaseAppsAvailable) {
      unawaited(GoogleSignIn.instance.signOut());
      unawaited(FirebaseAuth.instance.signOut());
    }
    _persistUser();
  }

  Future<String?> signInWithEmail({
    required String email,
    required String password,
    required bool register,
    String? name,
  }) async {
    if (!firebaseAppsAvailable) {
      final resolved = register
          ? (name ?? '').trim()
          : email
                .split('@')
                .first
                .replaceAll(RegExp(r'[._]+'), ' ')
                .split(' ')
                .map(
                  (w) =>
                      w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}',
                )
                .join(' ');
      signInUser(
        AppUser(
          name: resolved,
          email: email,
          initials: initialsOf(resolved),
          provider: 'email',
        ),
      );
      return null;
    }

    final typedName = (name ?? '').trim();
    try {
      UserCredential credential;
      if (register) {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (typedName.isNotEmpty) {
          await credential.user?.updateDisplayName(typedName);
        }
      } else {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      final current = credential.user;
      if (current == null) return 'Authentication failed';
      // On registration `displayName` is still stale right after the account is
      // created (updateDisplayName hasn't propagated to this User instance), so
      // prefer the name the user just typed. On a later login the stored
      // displayName is authoritative (issue #141).
      final resolvedName = register && typedName.isNotEmpty
          ? typedName
          : (current.displayName ?? '').trim().isNotEmpty
          ? current.displayName!.trim()
          : email
                .split('@')
                .first
                .replaceAll(RegExp(r'[._]+'), ' ')
                .split(' ')
                .map(
                  (w) =>
                      w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}',
                )
                .join(' ');
      signInUser(
        AppUser(
          name: resolvedName,
          email: current.email ?? email,
          initials: initialsOf(resolvedName),
          provider: 'email',
          photo: current.photoURL,
        ),
      );
      await _loadCloudAfterSignIn();
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Email is already in use';
        case 'invalid-email':
          return 'Enter a valid email';
        case 'weak-password':
          return 'Password is too weak';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Wrong email or password';
        default:
          return e.message ?? 'Could not sign in right now';
      }
    }
  }

  Future<String?> signInWithGoogle() async {
    if (!firebaseAppsAvailable) {
      signInUser(
        AppUser(
          name: 'Eva Janssen',
          email: 'eva.janssen@gmail.com',
          initials: 'EJ',
          provider: 'google',
        ),
      );
      return null;
    }
    try {
      debugPrint('[auth] Google sign-in started');
      final googleSignIn = GoogleSignIn.instance;
      if (!_googleSignInInitialized) {
        await googleSignIn.initialize(serverClientId: _googleServerClientId);
        _googleSignInInitialized = true;
      }
      if (!googleSignIn.supportsAuthenticate()) {
        debugPrint('[auth] Platform does not support interactive authenticate');
        return 'Google sign-in is not supported on this device';
      }
      final googleUser = await googleSignIn.authenticate();
      debugPrint('[auth] Google account selected: ${googleUser.email}');
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        debugPrint(
          '[auth] Missing Google idToken. Check Firebase Android SHA-1/SHA-256 '
          'and regenerate google-services.json.',
        );
        return 'Google sign-in failed (missing id token)';
      }
      debugPrint(
        '[auth] Google idToken acquired, exchanging for Firebase credential',
      );
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final current = userCredential.user;
      if (current == null) {
        debugPrint('[auth] Firebase sign-in returned null user');
        return 'Google sign-in failed';
      }
      debugPrint('[auth] Firebase sign-in success: uid=${current.uid}');

      final fallbackName = (current.email ?? 'User')
          .split('@')
          .first
          .replaceAll(RegExp(r'[._]+'), ' ')
          .split(' ')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
      final resolvedName = (current.displayName ?? '').trim().isNotEmpty
          ? current.displayName!.trim()
          : fallbackName;

      signInUser(
        AppUser(
          name: resolvedName,
          email: current.email ?? '',
          initials: initialsOf(resolvedName),
          provider: 'google',
          photo: current.photoURL,
        ),
      );
      await _loadCloudAfterSignIn();
      return null;
    } on GoogleSignInException catch (e) {
      debugPrint(
        '[auth] GoogleSignInException code=${e.code} description=${e.description}',
      );
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return 'Google sign-in cancelled';
      }
      return e.description ?? 'Google sign-in failed on device';
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'account-exists-with-different-credential':
          return 'This email is already linked to another sign-in method';
        case 'invalid-credential':
          return 'Google credential is invalid';
        case 'operation-not-allowed':
          return 'Google sign-in is disabled in Firebase Auth';
        default:
          return e.message ?? 'Could not sign in with Google right now';
      }
    } on PlatformException catch (e) {
      debugPrint(
        '[auth] PlatformException code=${e.code} message=${e.message}',
      );
      return e.message ?? 'Google sign-in failed on device';
    } catch (_) {
      debugPrint('[auth] Unknown error during Google sign-in');
      return 'Could not sign in with Google right now';
    }
  }

  // ----------------------------------------------------------- profile
  void saveProfile(String name, String? photo, Color? color) {
    final u = user;
    if (u == null) return;
    update(() {
      u
        ..name = name
        ..initials = initialsOf(name)
        ..photo = (photo == null || photo.isEmpty) ? null : photo
        ..color = color;
      _syncMe(u);
    });
    _persistUser();
    flash('Profile updated');
  }

  /// Propagates the user's identity onto the `me` member of every family.
  void _syncMe(AppUser u) {
    for (final f in families) {
      for (final m in f.members) {
        if (m.id == 'me') {
          m
            ..name = u.name
            ..email = u.email
            ..initials = u.initials
            ..photo = u.photo
            ..color = u.color ?? m.color;
        }
      }
    }
  }

  // ----------------------------------------------------------- families
  void _withCurFamily(void Function(Family f) fn, [String? toast]) {
    final f = curFamily();
    if (f == null) return;
    update(() => fn(f));
    _persist();
    if (toast != null) flash(toast);
  }

  void renameFamily(String name) => _withCurFamily((f) => f.name = name);

  void inviteMember(String name, String email) {
    final f = curFamily();
    if (f == null) return;
    final color = kMemberColors[f.members.length % kMemberColors.length];
    _withCurFamily((f) {
      f.members.add(
        FamilyMember(
          id: uid(),
          name: name,
          email: email,
          initials: initialsOf(name),
          color: color,
          role: 'member',
          status: 'invited',
        ),
      );
    }, 'Invite sent to ${name.split(' ').first}');
  }

  /// Adds a member with no email/login — e.g. a kid who won't sign in
  /// themselves. Gets its own local [FamilyMember.id] (generated by [uid()])
  /// so it's immediately usable as a task assignee / event attendee, but no
  /// Firebase Auth `uid` and no invite step, since it never signs in.
  void addMember(String name) {
    final f = curFamily();
    if (f == null) return;
    final color = kMemberColors[f.members.length % kMemberColors.length];
    _withCurFamily((f) {
      f.members.add(
        FamilyMember(
          id: uid(),
          name: name,
          email: '',
          initials: initialsOf(name),
          color: color,
          role: 'member',
          status: 'active',
        ),
      );
    }, '${name.split(' ').first} added');
  }

  void removeMember(String id) {
    _withCurFamily(
      (f) => f.members.removeWhere((m) => m.id == id),
      'Member removed',
    );
  }

  void toggleMemberRole(String id) {
    if (!amOwner()) return;
    _withCurFamily((f) {
      for (final m in f.members) {
        if (m.id == id && m.id != 'me') {
          m.role = m.role == 'owner' ? 'member' : 'owner';
        }
      }
    }, 'Role updated');
  }

  void editMember(String id, String name, String email) {
    _withCurFamily((f) {
      for (final m in f.members) {
        if (m.id == id) {
          m
            ..name = name
            ..email = email
            ..initials = initialsOf(name);
        }
      }
    }, 'Member updated');
  }

  void setMemberColor(String id, Color color) {
    if (!isCalendarIdentityColorAvailable(color, exceptMemberId: id)) {
      flash('That colour is already used');
      return;
    }
    _withCurFamily((f) {
      for (final m in f.members) {
        if (m.id == id) {
          m.color = color;
        }
      }
    }, 'Member colour updated');
  }

  void switchFamily(String id) {
    if (id == familyId) return;
    _syncWorkspaces();
    final target = workspaces[id] ?? Workspace.empty();
    workspaces[id] = target;
    update(() {
      familyId = id;
      accounts = target.accounts;
      cats = target.cats;
      data = target.data;
      taskLists = target.taskLists;
      shoppingLists = target.shoppingLists;
      events = target.events;
      eventCategories = target.eventCategories;
      importedCalendars = target.importedCalendars;
      weeklyPlan = target.weeklyPlan;
      screen = 'overview';
      swipedId = null;
      collapsed = {};
    });
    _rescheduleReminders();
    _persist();
    final uid = _firebaseUid();
    if (uid != null) _bindActiveFamily(uid);
    flash('Switched to ${curFamily()?.name ?? 'family'}');
  }

  /// Creates a family. With a `username`/`password` it provisions a *shared*
  /// family (cloud) or a registry-backed one (local/demo) that relatives can
  /// join. Without credentials it falls back to a quick private workspace.
  Future<String?> createFamily(
    String name, {
    String? username,
    String? password,
    String? picture,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return 'Enter a family name';
    if (username != null && password != null) {
      final slug = familySlug(username);
      if (!validFamilyUsername(slug)) {
        return 'Username: 3–24 letters, numbers, - or _';
      }
      if (password.length < 4) {
        return 'Password must be at least 4 characters';
      }
      final uid = _firebaseUid();
      // coverage:ignore-start
      if (uid != null) {
        final err = await cloudCreateFamily(
          meUid: uid,
          name: trimmedName,
          username: slug,
          password: password,
          picture: picture,
        );
        if (err == null) _cacheSessionFamilyPassword(slug, password);
        return err;
      }
      // coverage:ignore-end
      final err = await localCreateFamily(
        name: trimmedName,
        username: slug,
        password: password,
        picture: picture,
      );
      if (err == null) _cacheSessionFamilyPassword(slug, password);
      return err;
    }
    _createFamilyInMemory(trimmedName);
    return null;
  }

  /// Remembers [password] in memory for the family whose handle is [slug],
  /// once it's been resolved to a [Family.id] on the next families reload.
  /// Cached by username since the id isn't known until the family list is
  /// refreshed after create/join.
  void _cacheSessionFamilyPassword(String slug, String password) {
    for (final f in families) {
      if (f.username == slug) {
        _sessionFamilyPasswords[f.id] = password;
        return;
      }
    }
    // Not resolved yet (list not refreshed) — cache by username as a
    // fallback key too, so `sessionFamilyPassword` can still find it.
    _sessionFamilyPasswords[slug] = password;
  }

  /// The join password for [family], but only if it was typed in this app
  /// session (during create or join) — never read back from storage, since
  /// cloud families only keep a salted hash server-side. Returns null
  /// otherwise (UI should show "Not set").
  String? sessionFamilyPassword(Family family) =>
      _sessionFamilyPasswords[family.id] ??
      _sessionFamilyPasswords[family.username];

  /// True when [slug] is a valid handle that no family has claimed yet. Checks
  /// the families already loaded, then the cloud handle registry (signed-in) or
  /// the local registry (offline/demo). On an unknown/errored lookup it returns
  /// false so a taken handle is never offered as available.
  Future<bool> familyUsernameAvailable(String slug) async {
    if (!validFamilyUsername(slug)) return false;
    if (families.any((f) => f.username == slug)) return false;
    final uid = _firebaseUid();
    // coverage:ignore-start
    if (uid != null) {
      try {
        final snap = await _familyHandleRef(
          slug,
        ).get().timeout(kCloudOpTimeout);
        return !snap.exists;
      } catch (_) {
        return false;
      }
    }
    // coverage:ignore-end
    final reg = await loadRegistry();
    return !reg.containsKey(slug);
  }

  /// Suggests an available family handle derived from [name], appending a
  /// numeric suffix until a free one is found. Returns '' when [name] is too
  /// short to derive a valid handle or nothing is available.
  Future<String> suggestFamilyUsername(String name) async {
    final base = familySlug(name);
    if (!validFamilyUsername(base)) return '';
    if (await familyUsernameAvailable(base)) return base;
    for (var i = 2; i <= 99; i++) {
      final candidate = familySlug('$base-$i');
      if (!validFamilyUsername(candidate)) continue;
      if (await familyUsernameAvailable(candidate)) return candidate;
    }
    return '';
  }

  /// Permanently deletes the signed-in account (issue #116). Any family this
  /// user is the sole member of is deleted with the account; families with
  /// other members simply lose this user. The user is then signed out.
  Future<void> deleteUserAccount() async {
    final uid = _firebaseUid();
    // coverage:ignore-start
    if (uid != null) {
      await _deleteAccountCloud(uid);
    } else {
      // coverage:ignore-end
      await _deleteAccountLocal();
    }
    signOut();
    flash('Account deleted');
  }

  /// Offline/demo equivalent of account deletion: drops registry entries for any
  /// family this user is the sole member of and strips this user from the rest.
  Future<void> _deleteAccountLocal() async {
    final reg = await loadRegistry();
    for (final f in families) {
      final others = f.members.where((m) => m.id != 'me').toList();
      if (others.isEmpty) {
        reg.remove(f.username);
      } else {
        final entry = reg[f.username];
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          map['members'] = [
            for (final m in (map['members'] as List? ?? []))
              if (Map<String, dynamic>.from(m as Map)['id'] != 'me') m,
          ];
          reg[f.username] = map;
        }
      }
    }
    await saveRegistry(reg);
  }

  /// Joins an existing shared family by its username + password.
  Future<String?> joinFamily({
    required String username,
    required String password,
  }) async {
    final uid = _firebaseUid();
    // coverage:ignore-start
    if (uid != null) {
      final err = await cloudJoinFamily(
        meUid: uid,
        username: username,
        password: password,
      );
      if (err == null) {
        _cacheSessionFamilyPassword(familySlug(username), password);
      }
      return err;
    }
    // coverage:ignore-end
    final err = await localJoinFamily(username: username, password: password);
    if (err == null) {
      _cacheSessionFamilyPassword(familySlug(username), password);
    }
    return err;
  }

  void _createFamilyInMemory(String name) {
    _syncWorkspaces();
    final id = 'fam_${uid()}';
    final ws = Workspace.empty();
    workspaces[id] = ws;
    final u = user;
    final fam = Family(
      id: id,
      name: name,
      username: familySlug(name),
      ownerUid: _firebaseUid(),
      memberUids: _firebaseUid() != null ? [_firebaseUid()!] : <String>[],
      members: [
        FamilyMember(
          id: 'me',
          name: u?.name ?? '',
          email: u?.email ?? '',
          initials: u?.initials ?? '?',
          color: kMemberColors[0],
          uid: _firebaseUid(),
          photo: u?.photo,
          role: 'owner',
          status: 'active',
        ),
      ],
    );
    update(() {
      families = [...families, fam];
      familyId = id;
      accounts = ws.accounts;
      cats = ws.cats;
      data = ws.data;
      taskLists = ws.taskLists;
      shoppingLists = ws.shoppingLists;
      screen = 'overview';
      swipedId = null;
      collapsed = {};
    });
    _persist();
    flash('Created $name');
  }

  /// Leaves family [id]: the signed-in user drops their own membership while the
  /// family stays intact for everyone else (issue #133). An owner who leaves
  /// hands the family to a randomly chosen remaining member (preferring an
  /// already-active one); a regular member simply leaves. Leaving the last
  /// family lands the user back on the onboarding gate.
  void leaveFamily(String id) {
    Family? fam;
    for (final f in families) {
      if (f.id == id) {
        fam = f;
        break;
      }
    }
    if (fam == null) return;

    final iAmOwner = fam.members.any((m) => m.id == 'me' && m.role == 'owner');
    final others = fam.members.where((m) => m.id != 'me').toList();

    // An owner leaving must hand ownership off so the family keeps an owner.
    if (iAmOwner && others.isNotEmpty) {
      final active = others.where((m) => m.status == 'active').toList();
      final pool = active.isNotEmpty ? active : others;
      final heir = pool[math.Random().nextInt(pool.length)];
      heir.role = 'owner';
      fam.ownerUid = heir.uid;
    }

    // Drop my own membership from the shared family record.
    fam.members.removeWhere((m) => m.id == 'me');
    final uid = _firebaseUid();
    // coverage:ignore-start
    if (uid != null) {
      fam.memberUids.remove(uid);
      unawaited(cloudLeaveFamily(uid, fam));
    } else {
      // coverage:ignore-end
      unawaited(_leaveFamilyLocal(fam));
    }

    final leftName = fam.name;
    final remaining = families.where((f) => f.id != id).toList();
    workspaces.remove(id);
    update(() {
      families = remaining;
      if (id == familyId) {
        familyId = remaining.isNotEmpty ? remaining.first.id : 'fam_main';
        final t = workspaces[familyId] ?? Workspace.empty();
        workspaces[familyId] = t;
        accounts = t.accounts;
        cats = t.cats;
        data = t.data;
        collapsed = {};
      }
    });
    _persist();
    flash('Left $leftName');
  }

  /// Deletes family [id] for everyone (owner-only). Switches to the next family
  /// if one remains; deleting the last family lands the user back on the
  /// create/join onboarding gate.
  void deleteFamily(String id) {
    final uid = _firebaseUid();
    if (uid != null) unawaited(cloudDeleteFamily(uid, id));
    final remaining = families.where((f) => f.id != id).toList();
    workspaces.remove(id);
    update(() {
      families = remaining;
      if (id == familyId) {
        familyId = remaining.isNotEmpty ? remaining.first.id : 'fam_main';
        final t = workspaces[familyId] ?? Workspace.empty();
        workspaces[familyId] = t;
        accounts = t.accounts;
        cats = t.cats;
        data = t.data;
        collapsed = {};
      }
    });
    _persist();
    flash('Family deleted');
  }
}
