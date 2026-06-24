part of 'package:family_money_management_app/main.dart';

/// Auth, profile and family mutations + avatar helpers, ported from the
/// design's `signInUser` / `saveProfile` / family methods.
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
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: fs,
        ),
      ),
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
    return avatarNode(
      photo: u.photo,
      initials: u.initials,
      color: u.color,
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
      if (families.isEmpty) {
        families = [seedFamily('fam_main', u)];
        familyId = 'fam_main';
        workspaces.putIfAbsent(
          'fam_main',
          () => Workspace(accounts: accounts, cats: cats, data: data),
        );
        final ws = workspaces['fam_main']!;
        accounts = ws.accounts;
        cats = ws.cats;
        data = ws.data;
      } else {
        _syncMe(u);
      }
    });
    _persistUser();
    flash('Welcome, ${u.name.split(' ').first}');
  }

  void signOut() {
    update(() => user = null);
    _cloudSub?.cancel();
    _cloudSub = null;
    if (Firebase.apps.isNotEmpty) {
      unawaited(GoogleSignIn().signOut());
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
    if (Firebase.apps.isEmpty) {
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

    try {
      UserCredential credential;
      if (register) {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final displayName = (name ?? '').trim();
        if (displayName.isNotEmpty) {
          await credential.user?.updateDisplayName(displayName);
        }
      } else {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      final current = credential.user;
      if (current == null) return 'Authentication failed';
      final resolvedName = (current.displayName ?? '').trim().isNotEmpty
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
      await _bindCloudSync();
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
    if (Firebase.apps.isEmpty) {
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
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        debugPrint('[auth] Google sign-in cancelled by user');
        return 'Google sign-in cancelled';
      }
      debugPrint('[auth] Google account selected: ${googleUser.email}');
      final googleAuth = await googleUser.authentication;
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
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: idToken,
      );
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
      await _bindCloudSync();
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[auth] FirebaseAuthException code=${e.code} message=${e.message}',
      );
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
      screen = 'overview';
      swipedId = null;
      collapsed = {};
    });
    _persist();
    flash('Switched to ${curFamily()?.name ?? 'family'}');
  }

  void createFamily(String name) {
    _syncWorkspaces();
    final id = 'fam_${uid()}';
    final ws = Workspace.empty();
    workspaces[id] = ws;
    final u = user;
    final fam = Family(
      id: id,
      name: name,
      members: [
        FamilyMember(
          id: 'me',
          name: u?.name ?? '',
          email: u?.email ?? '',
          initials: u?.initials ?? '?',
          color: kMemberColors[0],
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
      screen = 'overview';
      swipedId = null;
      collapsed = {};
    });
    _persist();
    flash('Created $name');
  }

  void deleteFamily(String id) {
    if (families.length <= 1) return;
    final remaining = families.where((f) => f.id != id).toList();
    workspaces.remove(id);
    update(() {
      families = remaining;
      if (id == familyId) {
        familyId = remaining.first.id;
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
