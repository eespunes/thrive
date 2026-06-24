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
    setState(() {
      _edit = true;
      _name.text = u.name;
      _photo = u.photo;
      _color = u.color;
      _photoTouched = false;
      _colorTouched = false;
    });
  }

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
      s.flash('Could not load image');
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = s.user;
    if (u == null) return const SizedBox.shrink();
    return SingleChildScrollView(child: _edit ? _buildEdit(u) : _buildView(u));
  }

  // ----------------------------------------------------------- view mode
  Widget _buildView(AppUser u) {
    final prov = u.provider == 'google';
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
              s.avatarNode(
                photo: u.photo,
                initials: u.initials,
                color: u.color,
                size: 54,
                radius: 16,
                fs: 19,
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
        _addRow('Create new family', () {
          Navigator.of(context).pop();
          s.openNewFamilySheet();
        }, key: const ValueKey('profile-new-family')),
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: cur ? B.primary : B.faint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: ic(
                    'users',
                    size: 16,
                    sw: 2.2,
                    color: cur ? Colors.white : B.soft2,
                  ),
                ),
              ),
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
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final col in <Color?>[null, ...kMemberColors])
                GestureDetector(
                  onTap: () => setState(() {
                    _color = col;
                    _colorTouched = true;
                  }),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: col == null ? B.grad : null,
                      color: col,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: (color == col || (col == null && color == null))
                            ? B.ink
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
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
  String? _editId; // member being edited inline
  bool _invite = false;
  late TextEditingController _rename;
  final _mName = TextEditingController();
  final _mEmail = TextEditingController();
  final _iName = TextEditingController();
  final _iEmail = TextEditingController();

  _ThriveHomeState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _rename = TextEditingController(text: s.curFamily()?.name ?? '');
  }

  @override
  void dispose() {
    _rename.dispose();
    _mName.dispose();
    _mEmail.dispose();
    _iName.dispose();
    _iEmail.dispose();
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
                          'Tap a member to edit · remove with the trash icon',
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
          if (owner && s.families.length > 1)
            GestureDetector(
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
                margin: const EdgeInsets.only(top: 4),
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
            ),
        ],
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
                      _editId = null;
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
          if (!_invite && owner)
            _addRow(
              'Invite member',
              () => setState(() {
                _invite = true;
                _iName.clear();
                _iEmail.clear();
              }),
              key: const ValueKey('family-invite'),
            ),
        ],
      ),
    );
  }

  Widget _memberRow(Family f, FamilyMember m, bool owner) {
    final isMe = m.id == 'me';
    if (_editId == m.id) {
      final valid = _mName.text.trim().isNotEmpty && _validEmail(_mEmail.text);
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: const BoxDecoration(
          color: B.soft,
          border: Border(top: BorderSide(color: B.faint)),
        ),
        child: Column(
          children: [
            _sheetField(
              'Name',
              _sheetInput(
                _mName,
                hint: 'Name',
                onChanged: (_) => setState(() {}),
              ),
            ),
            _sheetField(
              'Email',
              _sheetInput(
                _mEmail,
                hint: 'email',
                onChanged: (_) => setState(() {}),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _editId = null),
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
                    onTap: valid
                        ? () {
                            s.editMember(
                              m.id,
                              _mName.text.trim(),
                              _mEmail.text.trim(),
                            );
                            setState(() => _editId = null);
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: valid ? B.primary : const Color(0xffcbd3dc),
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

    final pill = s.memberPill(m.role, m.status);
    final canEdit = owner || isMe;
    final canRemove = owner && !isMe;
    return GestureDetector(
      key: ValueKey('member-${m.id}'),
      onTap: canEdit
          ? () => setState(() {
              _editId = m.id;
              _mName.text = m.name;
              _mEmail.text = m.email;
            })
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
                    m.email,
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
            if (canRemove) ...[
              const SizedBox(width: 8),
              GestureDetector(
                key: ValueKey('member-remove-${m.id}'),
                onTap: () => s.askDelete(
                  m.name,
                  'This person will lose access to the ${f.name} workspace.',
                  () {
                    s.removeMember(m.id);
                    setState(() {});
                  },
                ),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: B.faint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: ic('trash', size: 15, sw: 2.2, color: B.red),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
              onChanged: (_) => setState(() {}),
            ),
          ),
          _sheetField(
            'Email',
            _sheetInput(
              _iEmail,
              hint: 'lisa@email.com',
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

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
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
            'A fresh, separate budget workspace',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                    'Each family keeps its own accounts, budget blocks and '
                    'months. You’ll be the owner.',
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
            'Family name',
            _sheetInput(
              _name,
              hint: 'e.g. Beach house, Parents…',
              onChanged: (_) => setState(() {}),
            ),
          ),
          _primaryBtn('Create family', () {
            widget.state.createFamily(_name.text.trim());
            Navigator.of(context).pop();
          }, enabled: valid),
        ],
      ),
    );
  }
}
