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
  /// Signs a user in (dummy — no backend). Seeds a starter family on first
  /// sign-in, otherwise syncs the identity into existing families.
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
    _persist();
    flash('Welcome, ${u.name.split(' ').first}');
  }

  void signOut() {
    update(() => user = null);
    _persistUser();
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
    _persist();
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
