part of 'package:family_money_management_app/main.dart';

/// Member colours sub-screen + member studio (#276, `Settings v2.dc.html`):
/// active members list (avatar, name, role) → full-screen member editor with
/// name, photo/emoji/initials badge, optional email for login-less members,
/// and colour dots that enforce family-wide uniqueness (✓ current, dimmed ×
/// taken). No delete here — member removal lives in the family flows.
extension _ThriveMembersScreen on _ThriveHomeState {
  void openMemberColoursScreen() {
    pushSettingsPage<void>((_) => _MemberColoursScreen(state: this));
  }

  /// Saves a member-studio edit in one go: identity fields plus colour, and
  /// mirrors the change onto the signed-in user when editing yourself so the
  /// hero/profile stay in sync everywhere.
  void saveMemberStudio(
    String id, {
    required String name,
    required String email,
    required Color color,
    String? photo,
    String? emoji,
    bool? kid,
  }) {
    _withCurFamily((f) {
      for (final m in f.members) {
        if (m.id != id) continue;
        m
          ..name = name.trim()
          ..email = email.trim()
          ..initials = initialsOf(name)
          ..color = color
          ..photo = photo
          ..emoji = emoji;
        // Kid profiles (#245): flips member↔kid only — an owner can never be
        // downgraded to a kid, and only owners may change roles (never their
        // own row, so a kid can't unlock itself).
        if (kid != null && m.role != 'owner' && m.id != myId && amOwner()) {
          m.role = kid ? 'kid' : 'member';
        }
      }
    }, 'Member saved — updated everywhere');
    if (id == myId && user != null) {
      final u = user!;
      update(() {
        u
          ..name = name.trim()
          ..initials = initialsOf(name)
          ..photo = photo
          ..color = color;
      });
      unawaited(_persistUser());
    }
  }
}

/// The members-list subtitle for [m] (`Kid Accounts.dc.html` screen 1).
String memberRowSubtitle(FamilyMember m, {required bool loginless}) {
  if (m.role == 'owner') return 'Owner';
  if (m.role == 'kid') {
    if (m.loginPending) return 'Kid · login pending (Google)';
    if (m.loginMethod == 'email') {
      return 'Kid · own login (Email, managed by admins)';
    }
    if (m.loginMethod == 'google') return 'Kid · own login (Google)';
    return loginless ? 'Kid · no login' : 'Kid · own login';
  }
  return loginless ? 'No login — managed by anyone' : 'Member';
}

/// The row pill: Pending (amber) › Managed (grey) › Admin (teal).
({String label, KidTone tone})? memberRowPill(bool admin, FamilyMember m) {
  if (m.role == 'kid' && m.loginPending) {
    return (label: 'Pending', tone: KidTone.amber);
  }
  if (m.role == 'kid' && m.managed) {
    return (label: 'Managed', tone: KidTone.grey);
  }
  if (admin) return (label: 'Admin', tone: KidTone.teal);
  return null;
}

class _MemberColoursScreen extends StatelessWidget {
  const _MemberColoursScreen({required this.state});
  final _ThriveHomeState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ValueListenableBuilder<bool>(
      valueListenable: s.netOffline,
      builder: (context, offline, _) => ValueListenableBuilder<int>(
        valueListenable: s._rev,
        builder: (context, _, _) {
          final f = s.curFamily();
          final members = (f?.members ?? const <FamilyMember>[])
              .where((m) => m.status == 'active')
              .toList();
          final admin = s.amAdmin();
          final anyManaged = members.any((m) => m.role == 'kid' && m.managed);
          return SettingsSubScreen(
            sync: s.syncStatus,
            offline: s.netOffline,
            onOfflineTap: s.openPendingChangesScreen,
            title: 'Family members',
            subtitle: f == null
                ? 'Each person’s identity colour'
                : '${f.name} · ${members.length} '
                      '${members.length == 1 ? 'person' : 'people'}',
            intro: 'Tap someone to edit their badge, colour and access.',
            footnote: anyManaged
                ? 'Managed: an admin created this login and controls the '
                      'password.'
                : 'Changing a colour updates it everywhere at once — '
                      'calendar, lists and widgets.',
            onToast: s.flash,
            children: [
              if (!admin)
                kidNotice(
                  'Only admins can change access and logins. Ask '
                  '${s.adminNames()}.',
                  key: const ValueKey('members-readonly'),
                  tone: KidTone.grey,
                  icon: 'lock',
                  margin: const EdgeInsets.only(bottom: 8),
                )
              else if (offline && s._cloudBacked)
                kidNotice(
                  'Offline. Access and login changes need a connection.',
                  key: const ValueKey('members-offline'),
                  tone: KidTone.amber,
                  icon: 'wifi',
                  margin: const EdgeInsets.only(bottom: 8),
                ),
              for (final m in members)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _memberRow(s, f!, m),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _memberRow(_ThriveHomeState s, Family f, FamilyMember m) {
    final pill = memberRowPill(s.memberIsAdmin(f, m), m);
    return Stack(
      children: [
        SettingsListRow(
          rowKey: ValueKey('memcolors-row-${m.id}'),
          leading: s.avatarNode(
            photo: m.photo,
            emoji: m.emoji,
            initials: m.initials,
            color: m.color,
            size: 34,
            radius: 17,
            fs: 13,
          ),
          label: m.id == s.myId ? '${m.name} (you)' : m.name,
          sub: memberRowSubtitle(m, loginless: s.isLoginlessMember(m)),
          onTap: () => s.pushSettingsPage<void>(
            (_) => _MemberStudio(state: s, memberId: m.id),
          ),
        ),
        if (pill != null)
          Positioned(
            right: 34,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Center(
                child: kidPill(
                  pill.label,
                  tone: pill.tone,
                  key: ValueKey('memcolors-pill-${m.id}'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Full-screen member editor (badge studio): photo / free emoji / initials
/// badge, name, optional email, colour dots, plus the kid-accounts cards —
/// Access (Kid toggle, owner-only Admin toggle), Sign-in (own accounts) and
/// Login (kid profiles).
class _MemberStudio extends StatefulWidget {
  const _MemberStudio({required this.state, required this.memberId});
  final _ThriveHomeState state;
  final String memberId;

  @override
  State<_MemberStudio> createState() => _MemberStudioState();
}

class _MemberStudioState extends State<_MemberStudio> {
  late String _name;
  late final TextEditingController _email;
  String? _photo;
  String? _emoji;
  late Color _color;
  String? _accessError;
  bool _adminBusy = false;

  _ThriveHomeState get s => widget.state;

  FamilyMember? get _member => s._kidRowById(widget.memberId);

  @override
  void initState() {
    super.initState();
    final m = _member;
    _name = m?.name ?? '';
    _email = TextEditingController(text: m?.email ?? '');
    _photo = m?.photo;
    _emoji = m?.emoji;
    _color = m?.color ?? kMemberColors.first;
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _save() {
    s.saveMemberStudio(
      widget.memberId,
      name: _name,
      email: _email.text,
      color: _color,
      photo: _photo,
      emoji: _emoji,
    );
    Navigator.of(context).maybePop();
  }

  /// Why the Kid toggle is locked for [m], or null when it can change.
  String? _kidLockReason(Family f, FamilyMember m) {
    final first = firstNameOf(m.name);
    if (m.role == 'owner' ||
        (f.ownerUid != null && m.uid != null && f.ownerUid == m.uid)) {
      return '$first owns this family. The owner can’t be a kid account.';
    }
    final targetAdmin = s.memberIsAdmin(f, m);
    if (m.role != 'kid' && targetAdmin) {
      final otherAdmins = f.members.where(
        (o) => o.id != m.id && o.status == 'active' && s.memberIsAdmin(f, o),
      );
      if (otherAdmins.isEmpty) {
        return m.id == s.myId
            ? 'You’re the last admin. Make someone else an admin before '
                  'turning this on.'
            : '$first is the last admin. Make someone else an admin first.';
      }
      if (!s.amOwner()) {
        return '$first is an admin. Only the owner can make an admin a kid '
            'account.';
      }
    }
    if (s.netOffline.value && s._cloudBacked && !s.isLoginlessMember(m)) {
      return 'You’re offline. Access changes need a connection.';
    }
    return null;
  }

  Future<void> _toggleKid(FamilyMember m) async {
    final toKid = m.role != 'kid';
    // The confirm sheet shows its own busy state while the change saves.
    setState(() => _accessError = null);
    final err = await _showKidAccessConfirm(context, s, m, toKid);
    if (!mounted) return;
    setState(() => _accessError = err);
  }

  Widget _accessCard(Family f, FamilyMember m) {
    final first = firstNameOf(m.name);
    final kid = m.role == 'kid';
    final reason = _kidLockReason(f, m);
    final ownRow = !s.isLoginlessMember(m);
    final canAdmin =
        s.amOwner() &&
        m.role != 'owner' &&
        !kid &&
        ownRow &&
        s._loginIdOf(m) != null;
    final isAdmin = s.memberIsAdmin(f, m);
    return studioCard(
      title: 'Access',
      children: [
        kidToggleRow(
          key: const ValueKey('member-kid-toggle'),
          label: 'Kid',
          sub: kid
              ? '$first only sees their own events and lists, and the meal '
                    'plan read-only.'
              : 'Turn on to limit $first to their own events and lists, plus '
                    'a read-only meal plan.',
          value: kid,
          disabledReason: reason,
          onChanged: () => _toggleKid(m),
        ),
        if (canAdmin)
          kidToggleRow(
            key: const ValueKey('member-admin-toggle'),
            label: 'Admin',
            sub: 'Can change access and logins for everyone in the family.',
            value: isAdmin,
            busyText: _adminBusy ? 'Updating $first’s admin rights…' : null,
            disabledReason: s.netOffline.value && s._cloudBacked
                ? 'You’re offline. Admin changes need a connection.'
                : null,
            onChanged: () async {
              setState(() {
                _adminBusy = true;
                _accessError = null;
              });
              final err = await s.setAdmin(m.id, !isAdmin);
              if (!mounted) return;
              setState(() {
                _adminBusy = false;
                _accessError = err;
              });
            },
          ),
        if (_accessError != null)
          kidNotice(
            _accessError!,
            key: const ValueKey('member-access-error'),
            tone: KidTone.red,
            icon: 'x',
          ),
        Text(
          kid && m.kidSetAt != null
              ? 'Kid since ${kidShortDate(m.kidSetAt)}, set by '
                    '${m.kidSetBy ?? 'an admin'}. Only admins see this setting.'
              : 'Only admins see this setting.',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: B.muted,
          ),
        ),
      ],
    );
  }

  Widget _signInCard(FamilyMember m) {
    final first = firstNameOf(m.name);
    final me = m.id == s.myId;
    final email = m.email.trim();
    return studioCard(
      title: 'Sign-in',
      children: [
        if (me && s.user != null)
          studioInfoRow(
            'Method',
            value: s.user!.provider == 'google'
                ? 'Google account'
                : 'Email & password',
          ),
        if (email.isNotEmpty) studioInfoRow('Account', value: email),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            me
                ? 'This is your own account.'
                : 'This is $first’s own account. Only $first can change the '
                      'email or password.',
            key: const ValueKey('member-signin-note'),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: B.muted,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) {
        final f = s.curFamily();
        final m = _member;
        final admin = s.amAdmin();
        final loginless = m != null && s.isLoginlessMember(m);
        final flowB = m != null && m.loginMethod != null;
        final kidProfile = m != null && m.role == 'kid' && (loginless || flowB);
        // Members without a login of their own (login-less or a pending
        // invite) keep an editable contact email; a real login shows its
        // sign-in details instead.
        final emailEditable =
            m == null || (m.uid == null && !flowB && m.id != s.myId);
        return BadgeStudioScaffold(
          title: 'Edit member',
          subtitle: 'Badge, name & identity colour',
          accent: _color,
          saveLabel: 'Save member',
          saveEnabled: _name.trim().isNotEmpty,
          isDirty:
              m == null ||
              _name != m.name ||
              _email.text != m.email ||
              _photo != m.photo ||
              _emoji != m.emoji ||
              _color != m.color,
          onSave: _save,
          children: [
            BadgeStage(
              color: _color,
              name: _name,
              onName: (v) => setState(() => _name = v),
              emoji: _emoji,
              picture: _photo,
              fallbackGlyph: initialsOf(_name),
              namePlaceholder: 'Name…',
              onEmoji: (g) => setState(() {
                _emoji = g;
                _photo = null;
              }),
              onPickPhoto: () async {
                final p = await s.pickBadgePhoto();
                if (p != null && mounted) {
                  setState(() {
                    _photo = p;
                    _emoji = null;
                  });
                }
              },
              onToast: s.flash,
            ),
            if (emailEditable)
              studioTextField(
                key: const ValueKey('member-email'),
                controller: _email,
                hint: 'Email (optional — for members without a login)',
              ),
            if (f != null && m != null && admin) _accessCard(f, m),
            if (m != null && !emailEditable && !flowB) _signInCard(m),
            if (kidProfile) _KidLoginCard(state: s, memberId: m.id),
            _ColorPickerPanel(
              selected: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
          ],
        );
      },
    );
  }
}
