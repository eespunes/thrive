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
    if (f == null || f.members.isEmpty) return true;
    for (final m in f.members) {
      if (m.id == myId) return m.role == 'owner';
    }
    // The signed-in user has no member row in this family — never assume
    // ownership by default (#273): show the member (least-privilege) UI.
    return false;
  }

  /// A login-less member (e.g. a kid added by name): no auth uid, no email,
  /// and already active (invited rows are a separate state). Anyone in the
  /// family can manage them, since they can never sign in themselves.
  bool isLoginlessMember(FamilyMember m) =>
      m.uid == null && m.status != 'invited' && m.email.trim().isEmpty;

  /// Renders an avatar: a cropped photo, an emoji tile, else a colored
  /// initials tile.
  Widget avatarNode({
    String? photo,
    String? emoji,
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
        child = _initialsTile(initials, color, size, fs, emoji: emoji);
      }
    } else {
      child = _initialsTile(initials, color, size, fs, emoji: emoji);
    }
    return Opacity(
      opacity: opacity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(width: size, height: size, child: child),
      ),
    );
  }

  Widget _initialsTile(
    String initials,
    Color? color,
    double size,
    double fs, {
    String? emoji,
  }) {
    if (emoji != null && emoji.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        color: color ?? B.faint,
        child: Text(emoji, style: TextStyle(fontSize: size * 0.56)),
      );
    }
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
    for (final m in curFamily()?.members ?? const <FamilyMember>[]) {
      if (m.id == myId) {
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
    if (role == 'kid') {
      return (bg: B.amberSoft, fg: B.amberText, label: 'Kid');
    }
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
        families = [seedFamily('fam_main', u, myId)];
        familyId = 'fam_main';
        // The seeded sample budget (if any) already lives in
        // `workspaces['fam_main']`; `_activeWs` lazily creates an empty one
        // otherwise. The workspace is the single owner of the budget data —
        // there are no separate fields left to wire up.
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

  Future<void> signOut() async {
    // Drop any debounced persist BEFORE clearing state: the timer would
    // otherwise fire up to 2s after sign-out and write the previous
    // account's data back to local storage under the fresh session.
    final hadPendingPersist = _persistTimer?.isActive == true;
    _persistTimer?.cancel();
    // For cloud-backed users, flush that pending edit to Firestore first —
    // cancelling alone silently dropped the last ~2s of edits. Bounded by
    // [kCloudOpTimeout] so sign-out can't hang offline.
    if (hadPendingPersist && _cloudBacked && _firebaseUid() != null) {
      try {
        await _persist().timeout(kCloudOpTimeout);
      } catch (e) {
        debugPrint('[cloud] sign-out flush failed: $e');
      }
    }
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
    _wsSub?.cancel();
    _wsSub = null;
    _boundFamilyId = null;
    _wsSectionCache.clear();
    _wsSectionDigests.clear();
    _sessionFamilyPasswords.clear();
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
  /// Saves the profile name only (#274 — explicit Save, no per-keystroke
  /// writes) and mirrors it to the user's member row in every family.
  void saveProfileName(String name) {
    final u = user;
    if (u == null || name.trim().isEmpty) return;
    update(() {
      u
        ..name = name.trim()
        ..initials = initialsOf(name);
      _syncMe(u);
    });
    _persistUser();
    _persist();
    flash('Name saved — mirrored to your member rows');
  }

  /// Sets or removes the profile photo and mirrors it everywhere (#274).
  void saveProfilePhoto(String? photo) {
    final u = user;
    if (u == null) return;
    update(() {
      u.photo = (photo == null || photo.isEmpty) ? null : photo;
      _syncMe(u);
    });
    _persistUser();
    _persist();
    flash(
      u.photo == null
          ? 'Photo removed — back to initials'
          : 'Photo updated everywhere — hub, wall & member rows',
    );
  }

  /// Sets the user's identity colour and mirrors it to their member row in
  /// every family (#274). Callers guard against colours already taken in the
  /// current family — including the user's own picker.
  void saveProfileColor(Color color) {
    final u = user;
    if (u == null) return;
    update(() {
      u.color = color;
      _syncMe(u);
    });
    _persistUser();
    _persist();
    flash('Colour updated everywhere');
  }

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

  /// Propagates the user's identity onto the current user's own member row
  /// in every family.
  void _syncMe(AppUser u) {
    for (final f in families) {
      for (final m in f.members) {
        if (m.id == myId) {
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
    syncBlip();
    if (toast != null) flash(toast);
  }

  void renameFamily(String name) => _withCurFamily((f) => f.name = name);

  /// The first palette colour no member of [f] wears yet — colours are unique
  /// per family. Falls back to the length-modulo pick when all are taken.
  Color _freeMemberColor(Family f) {
    for (final c in kMemberColors) {
      if (!f.members.any((m) => m.color == c)) return c;
    }
    return kMemberColors[f.members.length % kMemberColors.length];
  }

  /// Invites someone by email only (#278): the invited row's name is derived
  /// from the address until they join and bring their own identity.
  void inviteMemberByEmail(String email) {
    final name = email.split('@').first.trim();
    inviteMember(name.isEmpty ? email : name, email);
  }

  void inviteMember(String name, String email) {
    final f = curFamily();
    if (f == null) return;
    final color = _freeMemberColor(f);
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
    }, 'Added as invited — remember to share the join details');
  }

  /// Adds a member with no email/login — e.g. a kid who won't sign in
  /// themselves. Gets its own local [FamilyMember.id] (generated by [uid()])
  /// so it's immediately usable as a task assignee / event attendee, but no
  /// Firebase Auth `uid` and no invite step, since it never signs in.
  void addMember(String name, {String? photo, String? emoji}) {
    final f = curFamily();
    if (f == null) return;
    final color = _freeMemberColor(f);
    _withCurFamily((f) {
      f.members.add(
        FamilyMember(
          id: uid(),
          name: name,
          email: '',
          initials: initialsOf(name),
          color: color,
          photo: photo,
          emoji: emoji,
          role: 'member',
          status: 'active',
        ),
      );
    }, '${name.split(' ').first} added');
  }

  /// Sweeps legacy "ghost" uids out of [f.memberUids]: the old removeMember
  /// deleted a member's display row but left their uid behind, so those users
  /// kept full access via the security rules and an owner leaving such a
  /// family could strand it ownerless (no heir row, yet memberUids non-empty
  /// so cloudLeaveFamily never deletes it). Only the RULES owner (matching
  /// `ownerUid`) may run this — non-owner memberUids writes are rejected
  /// wholesale, see removeMember.
  ///
  /// Caution: a joiner briefly has a uid in memberUids before their display
  /// row lands (cloudJoinFamily writes the row best-effort after the
  /// arrayUnion), so a sweep in that window would evict a real member. Only
  /// call this from the leave-family path, where a stranded ownerless family
  /// is the greater harm and the window is negligible.
  void _sweepGhostMemberUids(Family f) {
    final myUid = _firebaseUid();
    if (myUid == null || myUid != f.ownerUid) return;
    final rowUids = {
      for (final m in f.members)
        if (m.uid != null && m.uid!.isNotEmpty) m.uid!,
    };
    f.memberUids.removeWhere((u) => u != f.ownerUid && !rowUids.contains(u));
  }

  void removeMember(String id) {
    _withCurFamily((f) {
      // Also revoke the member's real access: security rules gate reads and
      // writes on `memberUids`, so deleting only the display row would leave
      // a removed (signed-in) member with full access to the family. Only the
      // owner may change `memberUids` arbitrarily per the rules, so a
      // non-owner's local removal must not touch it (the meta write would be
      // rejected wholesale and break sync). The rules key ownership off
      // `ownerUid`, not the display role, so gate on that — not amOwner().
      final myUid = _firebaseUid();
      final amRulesOwner = myUid == null ? amOwner() : myUid == f.ownerUid;
      for (final m in f.members) {
        if (m.id == id) {
          final memberUid = m.uid;
          if (amRulesOwner &&
              memberUid != null &&
              memberUid.isNotEmpty &&
              memberUid != f.ownerUid) {
            f.memberUids.remove(memberUid);
          }
          break;
        }
      }
      f.members.removeWhere((m) => m.id == id);
      // No ghost-uid sweep here: a freshly-joined member can briefly have a
      // uid without a display row and must not be evicted (see helper docs).
    }, 'Member removed');
  }

  void toggleMemberRole(String id) {
    if (!amOwner()) return;
    _withCurFamily((f) {
      for (final m in f.members) {
        if (m.id == id && m.id != myId) {
          m.role = m.role == 'owner' ? 'member' : 'owner';
        }
      }
    }, 'Role updated');
  }

  void editMember(
    String id,
    String name,
    String email, {
    String? photo,
    String? emoji,
    bool photoTouched = false,
    bool emojiTouched = false,
    bool? kid,
  }) {
    _withCurFamily((f) {
      for (final m in f.members) {
        if (m.id == id) {
          m
            ..name = name
            ..email = email
            ..initials = initialsOf(name);
          if (photoTouched) m.photo = photo;
          if (emojiTouched) m.emoji = emoji;
          // Kid profiles (issue #245): only flips between member/kid — an
          // owner can never be downgraded to a kid from here.
          if (kid != null && m.role != 'owner') {
            m.role = kid ? 'kid' : 'member';
          }
        }
      }
    }, 'Member updated');
  }

  Future<void> switchFamily(String id) async {
    if (id == familyId) return;
    // A debounced edit to the CURRENT family may still be pending; persist it
    // while `familyId` still points at that family, or the edit would only
    // ever reach local memory (cloudPersist persists the active family, so
    // after the switch the timer would persist the wrong one).
    if (_persistTimer?.isActive == true) {
      _persistTimer?.cancel();
      await _persist();
    }
    update(() {
      familyId = id;
      _adoptActiveWorkspace();
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

  /// The join password for [family], when it is still knowable. The plaintext
  /// is deliberately no longer persisted ANYWHERE — cloud families store only
  /// the salted `joinHash` and the local registry only a salted `passHash` —
  /// so this resolves from the in-memory session cache (populated when the
  /// password was typed during create/join this session), plus, for legacy
  /// local-registry entries written before hashing, the old plaintext field.
  /// Returns null otherwise; the invite sheet shows "Not set" and members
  /// share the password out-of-band or the owner sets a new one.
  Future<String?> fetchFamilyPassword(Family family) async {
    final cached = sessionFamilyPassword(family);
    if (cached != null) return cached;
    if (_firebaseUid() != null) return null;
    final reg = await loadRegistry();
    final entry = reg[family.username];
    if (entry is Map) {
      final pw = entry['password'];
      if (pw is String && pw.isNotEmpty) {
        _sessionFamilyPasswords[family.id] = pw;
        return pw;
      }
    }
    return null;
  }

  /// The join password for [family], but only if it was typed in this app
  /// session (during create or join) — never read back from storage, since
  /// cloud families only keep a salted hash server-side. Returns null
  /// otherwise (UI should show "Not set"). Prefer [fetchFamilyPassword] when
  /// the caller can await, since it also recovers local/demo passwords that
  /// were set in a previous session.
  String? sessionFamilyPassword(Family family) =>
      _sessionFamilyPasswords[family.id] ??
      _sessionFamilyPasswords[family.username];

  /// Whether [family] has a join password configured at all — regardless of
  /// whether the plaintext is still knowable this session. Cloud families
  /// carry a members-readable `joinHash` on their doc; local families a
  /// `passHash` (or a legacy plaintext `password`) in the registry.
  Future<bool> familyHasPassword(Family family) async {
    if (_firebaseUid() != null) {
      try {
        final snap = await _familyDocRef(
          family.id,
        ).get().timeout(kCloudOpTimeout);
        final hash = snap.data()?['joinHash'];
        return hash is String && hash.isNotEmpty;
      } catch (e) {
        debugPrint('[cloud] familyHasPassword failed: $e');
        return false;
      }
    }
    final entry = (await loadRegistry())[family.username];
    if (entry is! Map) return false;
    final hash = entry['passHash'] ?? entry['password'];
    return hash is String && hash.isNotEmpty;
  }

  /// Sets a new join password for the current family (#278). The old one
  /// stops working immediately; only the salted hash is persisted, and the
  /// plaintext is cached in memory so the invite sheet can show it this
  /// session ("known-this-session" state). Returns an error message or null.
  Future<String?> resetFamilyPassword(String password) async {
    final f = curFamily();
    if (f == null) return 'No family selected';
    if (password.length < 4) return 'Password must be at least 4 characters';
    final uid = _firebaseUid();
    // coverage:ignore-start
    if (uid != null) {
      try {
        final joinSalt = newJoinSalt();
        final joinHash = hashFamilyPasswordV2(password, joinSalt);
        await _familyDocRef(f.id)
            .update({'joinHash': joinHash, 'joinScheme': 2})
            .timeout(kCloudOpTimeout);
        await _familyHandleRef(
          f.username,
        ).update({'joinSalt': joinSalt}).timeout(kCloudOpTimeout);
      } catch (e) {
        debugPrint('[cloud] resetFamilyPassword failed: $e');
        return 'Could not update the password right now';
      }
    } else {
      // coverage:ignore-end
      final reg = await loadRegistry();
      final entry = reg[f.username];
      final map = entry is Map
          ? Map<String, dynamic>.from(entry)
          : <String, dynamic>{
              'username': f.username,
              'name': f.name,
              'members': [for (final m in f.members) m.toJson()],
            };
      map
        ..remove('password')
        ..['passHash'] = hashFamilyPassword(
          password,
          _localJoinSalt(f.username),
        );
      reg[f.username] = map;
      await saveRegistry(reg);
    }
    _sessionFamilyPasswords[f.id] = password;
    flash('Password set — visible this session only');
    return null;
  }

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
    final id = myId;
    for (final f in families) {
      final others = f.members.where((m) => m.id != id).toList();
      if (others.isEmpty) {
        reg.remove(f.username);
      } else {
        final entry = reg[f.username];
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          map['members'] = [
            for (final m in (map['members'] as List? ?? []))
              if (Map<String, dynamic>.from(m as Map)['id'] != id) m,
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
    final id = 'fam_${uid()}';
    final ws = Workspace.empty();
    workspaces[id] = ws;
    final u = user;
    final selfId = myId;
    final fam = Family(
      id: id,
      name: name,
      username: familySlug(name),
      ownerUid: _firebaseUid(),
      memberUids: _firebaseUid() != null ? [_firebaseUid()!] : <String>[],
      members: [
        FamilyMember(
          id: selfId,
          name: u?.name ?? '',
          email: u?.email ?? '',
          initials: u?.initials ?? '?',
          color: kMemberColors[0],
          uid: _firebaseUid() ?? selfId,
          photo: u?.photo,
          role: 'owner',
          status: 'active',
        ),
      ],
    );
    update(() {
      families = [...families, fam];
      familyId = id;
      _adoptActiveWorkspace();
      screen = 'overview';
      swipedId = null;
      collapsed = {};
    });
    _persist();
    flash('Created $name');
  }

  /// Members of [f] who could take over ownership: active account members
  /// (they have a login) other than the signed-in user (#279).
  List<FamilyMember> successorCandidates(Family f) => [
    for (final m in f.members)
      if (m.id != myId && m.status == 'active' && !isLoginlessMember(m)) m,
  ];

  /// Leaves family [id] (issue #133, reworked in #279): the signed-in user
  /// drops their own membership while the family stays intact for everyone
  /// else. An owner leaving hands the family to [successorId] — an explicit,
  /// atomic transfer (role + `ownerUid` together), never a silent random one;
  /// without any account-member candidate the family is deleted instead, so
  /// no family is ever left with zero owners. Leaving the last family lands
  /// the user back on the onboarding gate.
  void leaveFamily(String id, {String? successorId}) {
    Family? fam;
    for (final f in families) {
      if (f.id == id) {
        fam = f;
        break;
      }
    }
    if (fam == null) return;

    final selfId = myId;
    final iAmOwner = fam.members.any(
      (m) => m.id == selfId && m.role == 'owner',
    );

    // Legacy data: drop ghost uids (a member uid with no matching row, left by
    // the old removeMember) before deciding succession, so a family whose only
    // real member is the departing owner ends with an empty memberUids and is
    // deleted rather than stranded ownerless (owner-only, see the helper).
    _sweepGhostMemberUids(fam);
    if (iAmOwner) {
      final candidates = successorCandidates(fam);
      if (candidates.isEmpty) {
        // No account member can take over — the family goes with the owner.
        deleteFamily(id);
        return;
      }
      // Atomic ownership transfer: role AND owner uid flip together.
      final heir = candidates.firstWhere(
        (m) => m.id == successorId,
        orElse: () => candidates.first,
      );
      heir.role = 'owner';
      fam.ownerUid = heir.uid;
    }

    // Drop my own membership from the shared family record.
    fam.members.removeWhere((m) => m.id == selfId);
    final uid = _firebaseUid();
    // coverage:ignore-start
    if (uid != null) {
      fam.memberUids.remove(uid);
      // Surface a failed cloud leave: the family was already removed locally,
      // so a silent failure would resurrect it from Firestore on next boot
      // with no clue why.
      unawaited(
        cloudLeaveFamily(uid, fam).then((err) {
          if (err != null && mounted) showError(err);
        }),
      );
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
        _adoptActiveWorkspace();
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
    if (uid != null) {
      // Surface a failed cloud delete — otherwise the family resurrects from
      // Firestore on next boot after the UI already confirmed the deletion.
      unawaited(
        cloudDeleteFamily(uid, id).then((err) {
          if (err != null && mounted) showError(err);
        }),
      );
    }
    final remaining = families.where((f) => f.id != id).toList();
    workspaces.remove(id);
    update(() {
      families = remaining;
      if (id == familyId) {
        familyId = remaining.isNotEmpty ? remaining.first.id : 'fam_main';
        _adoptActiveWorkspace();
        collapsed = {};
      }
    });
    _persist();
    flash('Family deleted');
  }
}
