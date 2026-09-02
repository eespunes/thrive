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

class _MemberColoursScreen extends StatelessWidget {
  const _MemberColoursScreen({required this.state});
  final _ThriveHomeState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) {
        final members = (s.curFamily()?.members ?? const <FamilyMember>[])
            .where((m) => m.status == 'active')
            .toList();
        return SettingsSubScreen(
          sync: s.syncStatus,
          offline: s.netOffline,
          title: 'Member colours',
          subtitle: 'Each person’s identity colour',
          intro:
              'Each member’s identity colour — used on avatars, events and '
              'lists. Tap a member to edit.',
          footnote:
              'Changing a colour updates it everywhere at once — calendar, '
              'lists and widgets.',
          onToast: s.flash,
          children: [
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SettingsListRow(
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
                  sub: m.role == 'owner'
                      ? 'Owner'
                      : (m.role == 'kid'
                            ? 'Kid'
                            : (m.uid == null && m.email.isEmpty
                                  ? 'No login — managed by anyone'
                                  : 'Member')),
                  onTap: () => s.pushSettingsPage<void>(
                    (_) => _MemberStudio(state: s, memberId: m.id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Full-screen member editor (badge studio): photo / free emoji / initials
/// badge, name, optional email, and unique-per-family colour dots.
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
  late bool _kid;

  _ThriveHomeState get s => widget.state;

  FamilyMember? get _member =>
      (s.curFamily()?.members ?? const <FamilyMember>[])
          .where((m) => m.id == widget.memberId)
          .firstOrNull;

  @override
  void initState() {
    super.initState();
    final m = _member;
    _name = m?.name ?? '';
    _email = TextEditingController(text: m?.email ?? '');
    _photo = m?.photo;
    _emoji = m?.emoji;
    _color = m?.color ?? kMemberColors.first;
    _kid = m?.role == 'kid';
  }

  /// The kid toggle shows only where a role change is even possible: the
  /// viewer is an owner, and the row is neither an owner nor themselves.
  bool get _canToggleKid {
    final m = _member;
    return m != null && m.role != 'owner' && m.id != s.myId && s.amOwner();
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
      kid: _canToggleKid ? _kid : null,
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return BadgeStudioScaffold(
      title: 'Edit member',
      subtitle: 'Badge, name & identity colour',
      accent: _color,
      saveLabel: 'Save member',
      saveEnabled: _name.trim().isNotEmpty,
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
        studioTextField(
          key: const ValueKey('member-email'),
          controller: _email,
          hint: 'Email (optional — for members without a login)',
        ),
        // Kid profiles (#245): the toggle moved here when the old member
        // edit sheet was retired.
        if (_canToggleKid)
          studioToggleRow(
            key: const ValueKey('member-kid-toggle'),
            label: 'Kid profile',
            sub: 'Home shows only kid-safe widgets for them',
            value: _kid,
            onChanged: () => setState(() => _kid = !_kid),
          ),
        _ColorPickerPanel(
          selected: _color,
          onChanged: (c) => setState(() => _color = c),
        ),
      ],
    );
  }
}
