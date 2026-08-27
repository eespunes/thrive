part of 'package:family_money_management_app/main.dart';

/// Profile + family bottom sheets and their entry points, ported from the
/// design's sheetProfile / sheetFamily / sheetNewFamily.
extension _ThriveAccountSheets on _ThriveHomeState {
  void openProfileSheet() {
    if (user == null) return;
    _showSheet((ctx) => _ProfileSheet(state: this));
  }

  void openFamilySheet() {
    _showSheet((ctx) => _FamilySheet(state: this));
  }

  void openNewFamilySheet() {
    _showSheet((ctx) => _NewFamilySheet(state: this));
  }

  void openJoinFamilySheet() {
    _showSheet((ctx) => _JoinFamilySheet(state: this));
  }
}

/// Small "add" action row used inside cards (mirrors `addRow()`).
Widget _addRow(String label, VoidCallback onTap, {Key? key}) {
  return GestureDetector(
    key: key,
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: B.faint)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ic('plus', size: 15, sw: 2.5, color: B.primary),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: B.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================ profile sheet
class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  bool _edit = false;
  late TextEditingController _name;
  String? _photo;
  Color? _color;
  bool _photoTouched = false;
  bool _colorTouched = false;
  final _picker = ImagePicker();

  _ThriveHomeState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: s.user?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _enterEdit() {
    final u = s.user!;
    final identity = s.profileAvatarIdentity(u);
    setState(() {
      _edit = true;
      _name.text = u.name;
      _photo = identity.photo;
      _color = identity.color;
      _photoTouched = false;
      _colorTouched = false;
    });
  }

  // coverage:ignore-start
  Future<void> _pickPhoto() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = base64Encode(bytes);
        _color = null;
        _photoTouched = true;
        _colorTouched = true;
      });
    } catch (_) {
      s.showError('Could not load image');
    }
  }
  // coverage:ignore-end

  @override
  Widget build(BuildContext context) {
    final u = s.user;
    if (u == null) return const SizedBox.shrink();
    return SingleChildScrollView(child: _edit ? _buildEdit(u) : _buildView(u));
  }

  // ----------------------------------------------------------- view mode
  Widget _buildView(AppUser u) {
    final prov = u.provider == 'google';
    final identity = s.profileAvatarIdentity(u);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHead(context, 'Your profile', u.email),
        // identity card
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: B.soft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                key: const ValueKey('profile-view-avatar'),
                child: s.avatarNode(
                  photo: identity.photo,
                  initials: identity.initials,
                  color: identity.color,
                  size: 54,
                  radius: 16,
                  fs: 19,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      u.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: B.ink,
                      ),
                    ),
                    Text(
                      u.email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: B.soft2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: B.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (prov)
                            _googleLogo(size: 12)
                          else
                            ic('wallet', size: 12, sw: 2.4, color: B.primary),
                          const SizedBox(width: 5),
                          Text(
                            prov ? 'Google account' : 'Email account',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: B.deep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                key: const ValueKey('profile-edit'),
                onTap: _enterEdit,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ic('edit', size: 16, sw: 2.2, color: B.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        // families
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 4, 2, 8),
          child: Text(
            'YOUR FAMILIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
              color: B.muted,
            ),
          ),
        ),
        ...s.families.map(_familyRow),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                key: const ValueKey('profile-new-family'),
                onTap: () {
                  Navigator.of(context).pop();
                  s.openNewFamilySheet();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: B.soft,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: B.greenLine),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ic('plus', size: 15, sw: 2.5, color: B.deep),
                      const SizedBox(width: 7),
                      const Text(
                        'Create',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: B.deep,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: GestureDetector(
                key: const ValueKey('profile-join-family'),
                onTap: () {
                  Navigator.of(context).pop();
                  s.openJoinFamilySheet();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: B.line),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ic('users', size: 15, sw: 2.2, color: B.text),
                      const SizedBox(width: 7),
                      const Text(
                        'Join',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: B.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // sign out
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: GestureDetector(
            key: const ValueKey('profile-signout'),
            onTap: () {
              Navigator.of(context).pop();
              s.signOut();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: B.redSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: B.redLine),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ic('back', size: 16, sw: 2.4, color: B.red),
                  const SizedBox(width: 8),
                  const Text(
                    'Sign out',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: B.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _familyRow(Family f) {
    final cur = f.id == s.familyId;
    final mc = f.members.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        key: ValueKey('profile-family-${f.id}'),
        onTap: () {
          Navigator.of(context).pop();
          s.switchFamily(f.id);
          s.openFamilySheet();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cur ? B.soft : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cur ? B.greenLine : B.line),
          ),
          child: Row(
            children: [
              famAvatar(picture: f.picture, size: 34, radius: 11),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: B.ink,
                      ),
                    ),
                    Text(
                      '$mc member${mc == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: B.soft2,
                      ),
                    ),
                  ],
                ),
              ),
              if (cur)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: B.greenLine),
                  ),
                  child: const Text(
                    'CURRENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: B.deep,
                    ),
                  ),
                )
              else
                ic('cright', size: 16, sw: 2.2, color: B.muted),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- edit mode
  Widget _buildEdit(AppUser u) {
    final photo = _photoTouched ? _photo : u.photo;
    final color = _colorTouched ? _color : u.color;
    final valid = _name.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHead(context, 'Edit profile', 'Update your name & picture'),
        Center(
          child: s.avatarNode(
            photo: photo,
            initials: initialsOf(_name.text),
            color: color,
            size: 84,
            radius: 26,
            fs: 30,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              key: const ValueKey('profile-upload'),
              onTap: _pickPhoto,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: B.soft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ic('edit', size: 15, sw: 2.2, color: B.deep),
                    const SizedBox(width: 7),
                    const Text(
                      'Upload photo',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: B.deep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (photo != null && photo.isNotEmpty) ...[
              const SizedBox(width: 9),
              GestureDetector(
                onTap: () => setState(() {
                  _photo = null;
                  _photoTouched = true;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: B.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ic('trash', size: 14, sw: 2.2, color: B.soft2),
                      const SizedBox(width: 6),
                      const Text(
                        'Remove',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: B.soft2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (photo == null || photo.isEmpty) ...[
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'OR PICK A COLOR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: B.muted,
              ),
            ),
          ),
          const SizedBox(height: 9),
          GestureDetector(
            onTap: () => setState(() {
              _color = null;
              _colorTouched = true;
            }),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: B.grad,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: color == null ? B.ink : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 11),
          _ColorPickerPanel(
            selected: color ?? kMemberColors.first,
            onChanged: (col) => setState(() {
              _color = col;
              _colorTouched = true;
            }),
          ),
        ],
        const SizedBox(height: 16),
        _sheetField(
          'Display name',
          _sheetInput(
            _name,
            hint: 'Your name',
            onChanged: (_) => setState(() {}),
          ),
        ),
        _primaryBtn('Save profile', () {
          s.saveProfile(_name.text.trim(), photo, color);
          setState(() => _edit = false);
        }, enabled: valid),
        GestureDetector(
          onTap: () => setState(() => _edit = false),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(0, 13, 0, 2),
            child: Text(
              'Cancel',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: B.soft2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================= family sheet
class _FamilySheet extends StatefulWidget {
  const _FamilySheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_FamilySheet> createState() => _FamilySheetState();
}

class _FamilySheetState extends State<_FamilySheet> {
  bool _invite = false;
  bool _addNoEmail = false;
  late TextEditingController _rename;
  final _iName = TextEditingController();
  final _iEmail = TextEditingController();
  final _aName = TextEditingController();
  final _iEmailFocus = FocusNode();

  // Avatar picture/emoji for the "add member" form
  // (login-less members, e.g. kids, can't set their own profile picture).
  String? _aPhoto;
  String? _aEmoji;

  _ThriveHomeState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _rename = TextEditingController(text: s.curFamily()?.name ?? '');
  }

  @override
  void dispose() {
    _rename.dispose();
    _iName.dispose();
    _iEmail.dispose();
    _aName.dispose();
    _iEmailFocus.dispose();
    super.dispose();
  }

  bool _validEmail(String v) => _kEmailRe.hasMatch(v.trim());

  @override
  Widget build(BuildContext context) {
    final f = s.curFamily();
    if (f == null) return const SizedBox.shrink();
    final owner = s.amOwner();
    final mc = f.members.length;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(
            context,
            f.name,
            '$mc member${mc == 1 ? '' : 's'} · separate budget',
          ),
          if (s.families.length > 1) _switcher(f),
          if (owner)
            _sheetField(
              'Family name',
              _sheetInput(
                _rename,
                hint: 'Family name',
                onChanged: (v) => s.renameFamily(v),
              ),
            ),
          _membersCard(f, owner),
          if (_invite) _inviteCard(),
          if (_addNoEmail) _addMemberCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 10),
            child: owner
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ic('cleft', size: 13, sw: 2.4, color: B.muted),
                      const SizedBox(width: 5),
                      const Flexible(
                        child: Text(
                          'Tap a member to edit · swipe to remove',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: B.muted,
                          ),
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Only owners can manage members',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: B.muted,
                    ),
                  ),
          ),
          if (!owner || f.members.where((m) => m.id != s.myId).isNotEmpty)
            _leaveButton(f),
          // The owner can always delete a family, even their last one (it then
          // drops them back to the create/join gate).
          if (owner) _deleteButton(),
        ],
      ),
    );
  }

  /// Drops the signed-in user's own membership. An owner hands the family to a
  /// remaining member; a regular member just leaves (issue #133). Shown above
  /// the delete button when an owner sees both.
  Widget _leaveButton(Family f) {
    final owner = s.amOwner();
    final message = owner
        ? 'You’ll hand this family to another member and lose access to '
              'its workspace.'
        : 'You’ll lose access to the ${f.name} workspace. The family stays '
              'for everyone else.';
    return GestureDetector(
      key: const ValueKey('family-leave'),
      onTap: () {
        final fam = s.curFamily();
        if (fam == null) return;
        s.askDelete(fam.name, message, () {
          s.leaveFamily(fam.id);
          if (mounted) Navigator.of(context).maybePop();
        }, confirmLabel: 'Leave');
      },
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: B.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ic('back', size: 15, sw: 2.2, color: B.deep),
            const SizedBox(width: 7),
            const Text(
              'Leave this family',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: B.deep,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deleteButton() {
    return GestureDetector(
      key: const ValueKey('family-delete'),
      onTap: () {
        final fam = s.curFamily();
        if (fam == null) return;
        s.askDelete(
          fam.name,
          'This family and its entire budget workspace will be '
          'permanently removed.',
          () {
            s.deleteFamily(fam.id);
            if (mounted) Navigator.of(context).maybePop();
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: B.redLine),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ic('trash', size: 15, sw: 2.2, color: B.red),
            const SizedBox(width: 7),
            const Text(
              'Delete this family',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: B.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switcher(Family cur) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final x in s.families)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  key: ValueKey('family-chip-${x.id}'),
                  onTap: () {
                    s.switchFamily(x.id);
                    setState(() {
                      _invite = false;
                      _rename.text = s.curFamily()?.name ?? '';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: x.id == cur.id ? B.primary : Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: x.id == cur.id ? B.primary : B.line,
                      ),
                    ),
                    child: Text(
                      x.name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: x.id == cur.id ? Colors.white : B.text,
                      ),
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                s.openNewFamilySheet();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: B.line, style: BorderStyle.solid),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ic('plus', size: 14, sw: 2.4, color: B.primary),
                    const SizedBox(width: 5),
                    const Text(
                      'New',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: B.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _membersCard(Family f, bool owner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: B.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'MEMBERS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                      color: B.soft2,
                    ),
                  ),
                ),
                Text(
                  '${f.members.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: B.muted,
                  ),
                ),
              ],
            ),
          ),
          ...f.members.map((m) => _memberRow(f, m, owner)),
          if (!_invite && !_addNoEmail && owner) ...[
            _addRow(
              'Invite member',
              () => setState(() {
                _invite = true;
                _iName.clear();
                _iEmail.clear();
              }),
              key: const ValueKey('family-invite'),
            ),
            _addRow(
              'Add family member',
              () => setState(() {
                _addNoEmail = true;
                _aName.clear();
                _aPhoto = null;
                _aEmoji = null;
              }),
              key: const ValueKey('family-add-member'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _memberRow(Family f, FamilyMember m, bool owner) {
    final isMe = m.id == s.myId;
    // Members with no login (uid == null, added via "Add family member")
    // can't edit their own name/avatar, so anyone in the family — not just
    // the owner — should be able to on their behalf.
    final isLoginLess = m.uid == null && m.status != 'invited';
    final editableByOwner =
        owner &&
        !isMe &&
        (m.uid == null || m.status == 'invited' || m.email.trim().isEmpty);
    final pill = s.memberPill(m.role, m.status);
    final canEdit = isMe || editableByOwner || isLoginLess;
    // Anyone can remove a login-less member on their behalf (they can't
    // remove themselves), same reasoning as editing them above.
    final canRemove = !isMe && (owner || isLoginLess);
    final inner = GestureDetector(
      key: ValueKey('member-edit-${m.id}'),
      onTap: canEdit
          ? () => _openMemberEditSheet(m, canEditAvatar: !isMe && m.uid == null)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: B.faint)),
        ),
        child: Row(
          children: [
            s.avatarNode(
              photo: m.photo,
              emoji: m.emoji,
              initials: m.initials,
              color: m.color,
              size: 38,
              radius: 12,
              fs: 13,
              opacity: m.status == 'invited' ? .55 : 1,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          m.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: B.ink,
                          ),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: B.soft,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: B.deep,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    m.email.isNotEmpty ? m.email : 'No login',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: B.soft2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              key: ValueKey('member-pill-${m.id}'),
              onTap: (owner && !isMe)
                  ? () {
                      s.toggleMemberRole(m.id);
                      setState(() {});
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: pill.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pill.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: pill.fg,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!canRemove) return inner;
    return _SwipeRow(
      key: ValueKey('member-${m.id}'),
      open: s.swipedId == 'member-${m.id}',
      onOpenChanged: (open) =>
          s.update(() => s.swipedId = open ? 'member-${m.id}' : null),
      onDelete: () => s.askDelete(
        m.name,
        'This person will lose access to the ${f.name} workspace.',
        () {
          s.removeMember(m.id);
          setState(() {});
        },
      ),
      child: inner,
    );
  }

  Future<void> _openMemberEditSheet(
    FamilyMember member, {
    required bool canEditAvatar,
  }) async {
    await s._showSheet(
      (context) => _MemberEditSheet(
        state: s,
        member: member,
        canEditAvatar: canEditAvatar,
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _inviteCard() {
    final valid = _iName.text.trim().isNotEmpty && _validEmail(_iEmail.text);
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: B.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: B.greenLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Invite a family member',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: B.ink,
              ),
            ),
          ),
          _sheetField(
            'Name',
            _sheetInput(
              _iName,
              hint: 'Lisa Janssen',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _iEmailFocus.requestFocus(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          _sheetField(
            'Email',
            _sheetInput(
              _iEmail,
              hint: 'lisa@email.com',
              focusNode: _iEmailFocus,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (valid) {
                  s.inviteMember(_iName.text.trim(), _iEmail.text.trim());
                  setState(() => _invite = false);
                }
              },
              onChanged: (_) => setState(() {}),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _invite = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: B.line),
                    ),
                    child: const Text(
                      'Cancel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: B.text,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('invite-send'),
                  onTap: valid
                      ? () {
                          s.inviteMember(
                            _iName.text.trim(),
                            _iEmail.text.trim(),
                          );
                          setState(() => _invite = false);
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: valid ? B.primary : const Color(0xffcbd3dc),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Send invite',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A member with no email/login — e.g. a kid — added straight in as
  /// `status: 'active'`, skipping the invite step entirely.
  Widget _addMemberCard() {
    final valid = _aName.text.trim().isNotEmpty;
    void submit() {
      s.addMember(_aName.text.trim(), photo: _aPhoto, emoji: _aEmoji);
      setState(() => _addNoEmail = false);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: B.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: B.greenLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Add a family member',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: B.ink,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              "For kids or anyone who won't sign in themselves — no email "
              'needed.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: B.soft2,
              ),
            ),
          ),
          Center(
            child: _GlyphPicker(
              emoji: _aEmoji,
              picture: _aPhoto,
              onChanged: ({emoji, picture}) => setState(() {
                _aEmoji = emoji;
                _aPhoto = picture;
              }),
            ),
          ),
          const SizedBox(height: 12),
          _sheetField(
            'Name',
            _sheetInput(
              _aName,
              hint: 'e.g. Emma',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (valid) submit();
              },
              onChanged: (_) => setState(() {}),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _addNoEmail = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: B.line),
                    ),
                    child: const Text(
                      'Cancel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: B.text,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('add-member-save'),
                  onTap: valid ? submit : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: valid ? B.primary : const Color(0xffcbd3dc),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Add member',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberEditSheet extends StatefulWidget {
  const _MemberEditSheet({
    required this.state,
    required this.member,
    required this.canEditAvatar,
  });

  final _ThriveHomeState state;
  final FamilyMember member;
  final bool canEditAvatar;

  @override
  State<_MemberEditSheet> createState() => _MemberEditSheetState();
}

class _MemberEditSheetState extends State<_MemberEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _emailFocus = FocusNode();
  String? _photo;
  String? _emoji;
  bool _kid = false;

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_email.text.trim().isEmpty || _kEmailRe.hasMatch(_email.text.trim()));

  @override
  void initState() {
    super.initState();
    final member = widget.member;
    _name = TextEditingController(text: member.name);
    _email = TextEditingController(text: member.email);
    _photo = member.photo;
    _emoji = member.emoji;
    _kid = member.role == 'kid';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _save() {
    if (!_valid) return;
    widget.state.editMember(
      widget.member.id,
      _name.text.trim(),
      _email.text.trim(),
      photo: _photo,
      emoji: _emoji,
      photoTouched: widget.canEditAvatar,
      emojiTouched: widget.canEditAvatar,
      kid: widget.member.role == 'owner' ? null : _kid,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetHead(context, 'Edit member'),
          if (widget.canEditAvatar)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: _GlyphPicker(
                  emoji: _emoji,
                  picture: _photo,
                  onChanged: ({emoji, picture}) => setState(() {
                    _emoji = emoji;
                    _photo = picture;
                  }),
                ),
              ),
            ),
          _sheetField(
            'Name',
            _sheetInput(
              _name,
              hint: 'Name',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _emailFocus.requestFocus(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          _sheetField(
            'Email',
            _sheetInput(
              _email,
              hint: 'email (optional — leave blank for no login)',
              focusNode: _emailFocus,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (widget.member.role != 'owner')
            _sheetField(
              '',
              _toggleRow(
                'Kid profile',
                _kid,
                () => setState(() => _kid = !_kid),
                subtitle:
                    'Their Home only offers the kid-safe widgets — no money',
                activeColor: B.primary,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: B.line),
                    ),
                    child: const Text(
                      'Cancel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: B.text,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('member-save'),
                  onTap: _valid ? _save : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: _valid ? B.primary : const Color(0xffcbd3dc),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Save',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ========================================================= new family sheet
class _NewFamilySheet extends StatefulWidget {
  const _NewFamilySheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_NewFamilySheet> createState() => _NewFamilySheetState();
}

class _NewFamilySheetState extends State<_NewFamilySheet> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  String? _picture;
  bool _busy = false;
  final _picker = ImagePicker();

  // Username suggestion / availability state (issue #121). While the user hasn't
  // touched the username field we auto-fill it with an available suggestion
  // derived from the family name; once they edit it we validate it live instead.
  bool _usernameEdited = false;
  Timer? _usernameDebounce;
  int _usernameCheckSeq = 0;
  String? _usernameNote;
  Color _usernameNoteColor = B.muted;

  _ThriveHomeState get s => widget.state;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _name.dispose();
    _username.dispose();
    _password.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Fills the username field with an available suggestion derived from the
  /// family [name], unless the user has already typed their own handle.
  void _suggestUsername(String name) {
    _usernameDebounce?.cancel();
    final base = familySlug(name);
    final seq = ++_usernameCheckSeq;
    if (!validFamilyUsername(base)) {
      if (_username.text.isNotEmpty) _username.clear();
      setState(() => _usernameNote = null);
      return;
    }
    _usernameDebounce = Timer(const Duration(milliseconds: 350), () async {
      final suggestion = await s.suggestFamilyUsername(name);
      if (!mounted || seq != _usernameCheckSeq || _usernameEdited) return;
      setState(() {
        _username.text = suggestion;
        if (suggestion.isEmpty) {
          _usernameNote = null;
        } else {
          _usernameNote = 'Suggested · available';
          _usernameNoteColor = B.green;
        }
      });
    });
  }

  /// Validates a user-typed handle and notifies whether it is free to claim.
  void _checkUsername(String value) {
    _usernameDebounce?.cancel();
    final slug = familySlug(value);
    if (slug.isEmpty) {
      setState(() => _usernameNote = null);
      return;
    }
    if (!validFamilyUsername(slug)) {
      setState(() {
        _usernameNote = '3–24 letters, numbers, - or _';
        _usernameNoteColor = B.red;
      });
      return;
    }
    setState(() {
      _usernameNote = 'Checking availability…';
      _usernameNoteColor = B.muted;
    });
    final seq = ++_usernameCheckSeq;
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      final available = await s.familyUsernameAvailable(slug);
      if (!mounted || seq != _usernameCheckSeq) return;
      setState(() {
        _usernameNote = available ? 'Available' : 'That username is taken';
        _usernameNoteColor = available ? B.green : B.red;
      });
    });
  }

  // coverage:ignore-start
  Future<void> _pickPhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _picture = base64Encode(bytes));
    } catch (_) {
      s.showError('Could not load image');
    }
  }
  // coverage:ignore-end

  Future<void> _submit() async {
    if (_busy) return;
    final hasCreds = _username.text.trim().isNotEmpty;
    if (hasCreds && _password.text.length < 4) {
      s.showError('Password must be at least 4 characters');
      return;
    }
    s.dismissError();
    setState(() => _busy = true);
    final err = await s.createFamily(
      _name.text,
      username: hasCreds ? _username.text : null,
      password: hasCreds ? _password.text : null,
      picture: _picture,
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = false);
    s.showError(err);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.text.trim().isNotEmpty;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(
            context,
            'Create a family',
            'A fresh, separate workspace relatives can join',
          ),
          Center(
            child: Column(
              children: [
                famAvatar(picture: _picture, size: 66, radius: 20),
                const SizedBox(height: 10),
                GestureDetector(
                  key: const ValueKey('new-family-photo'),
                  onTap: _pickPhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: B.soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ic('edit', size: 14, sw: 2.2, color: B.deep),
                        const SizedBox(width: 6),
                        Text(
                          _picture != null ? 'Change' : 'Add photo',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: B.deep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _sheetField(
            'Family name',
            _sheetInput(
              _name,
              hint: 'e.g. The Janssens',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _usernameFocus.requestFocus(),
              onChanged: (v) {
                setState(s.dismissError);
                if (!_usernameEdited) _suggestUsername(v);
              },
            ),
          ),
          _sheetField(
            'Family username (optional)',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetInput(
                  _username,
                  hint: 'e.g. beach-house',
                  focusNode: _usernameFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                  onChanged: (v) {
                    _usernameEdited = v.trim().isNotEmpty;
                    setState(s.dismissError);
                    if (_usernameEdited) {
                      _checkUsername(v);
                    } else {
                      _suggestUsername(_name.text);
                    }
                  },
                ),
                if (_usernameNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 2),
                    child: Text(
                      _usernameNote!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _usernameNoteColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _sheetField(
            'Family password (optional)',
            _sheetInput(
              _password,
              hint: 'At least 4 characters',
              obscure: true,
              focusNode: _passwordFocus,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (valid) _submit();
              },
              onChanged: (_) => setState(s.dismissError),
            ),
          ),
          _primaryBtn(
            _busy ? 'Creating…' : 'Create family',
            _submit,
            enabled: valid,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 13),
            child: Text(
              'Add a username & password so relatives can join this family.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: B.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================== join family sheet
class _JoinFamilySheet extends StatefulWidget {
  const _JoinFamilySheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_JoinFamilySheet> createState() => _JoinFamilySheetState();
}

class _JoinFamilySheetState extends State<_JoinFamilySheet> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;

  _ThriveHomeState get s => widget.state;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    s.dismissError();
    setState(() => _busy = true);
    final err = await s.joinFamily(
      username: _username.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = false);
    s.showError(err);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _username.text.trim().isNotEmpty;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(context, 'Join a family', 'Enter shared credentials'),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: B.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: B.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: ic('users', size: 16, sw: 2.2, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'Ask the owner for the family username & password.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: B.soft2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _sheetField(
            'Family username',
            _sheetInput(
              _username,
              hint: 'e.g. smith-home',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              onChanged: (_) => setState(s.dismissError),
            ),
          ),
          _sheetField(
            'Family password',
            _sheetInput(
              _password,
              hint: 'Family password',
              obscure: true,
              focusNode: _passwordFocus,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (valid) _submit();
              },
              onChanged: (_) => setState(s.dismissError),
            ),
          ),
          _primaryBtn(
            _busy ? 'Joining…' : 'Join family',
            _submit,
            enabled: valid,
          ),
        ],
      ),
    );
  }
}
