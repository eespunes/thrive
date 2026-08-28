part of 'package:family_money_management_app/main.dart';

/// Settings v2 phase 3 (`Settings v2.dc.html`): the profile page (#274), the
/// family-management page with member action sheets (#275), the three-state
/// invite & share sheet (#278), the explicit leave/delete-family flows with
/// the successor picker (#279), the hardened typed-DELETE account deletion
/// (#280) — all rendered permission-aware (#273: show disabled, don't hide,
/// except impossible affordances like self-demote).
extension _ThriveFamilyScreens on _ThriveHomeState {
  // ------------------------------------------------------- permissions #273
  /// The signed-in user's own member row in the current family, if any.
  FamilyMember? myMemberRow() {
    for (final m in curFamily()?.members ?? const <FamilyMember>[]) {
      if (m.id == myId) return m;
    }
    return null;
  }

  bool canRenameFamily() => amOwner();
  bool canInviteMembers() => amOwner();

  /// Edit is allowed for yourself, for login-less members (anyone manages
  /// them), and for owners.
  bool canEditMemberRow(FamilyMember m) =>
      m.id == myId || isLoginlessMember(m) || amOwner();

  /// Owners remove anyone but themselves; login-less members are removable
  /// by any member on their behalf.
  bool canRemoveMemberRow(FamilyMember m) =>
      m.id != myId && (amOwner() || isLoginlessMember(m));

  /// Role changes are owner-only, never on yourself (no self-demote
  /// affordance), and only for active account members.
  bool canToggleRoleOf(FamilyMember m) =>
      amOwner() &&
      m.id != myId &&
      m.status == 'active' &&
      !isLoginlessMember(m);

  bool canRevokeInvite(FamilyMember m) => amOwner() && m.status == 'invited';

  // ------------------------------------------------------------ navigation
  void openProfileScreen() {
    if (user == null) return;
    pushSettingsPage<void>((_) => _ProfileScreen(state: this));
  }

  void openFamilyScreen() {
    pushSettingsPage<void>((_) => _FamilyScreen(state: this));
  }

  void openInviteSheet() {
    if (!canInviteMembers()) {
      flash('Only owners can invite members');
      return;
    }
    _showSheet((ctx) => _InviteSheet(state: this));
  }

  void openDeleteAccountSheet() {
    _showSheet((ctx) => _DeleteAccountSheet(state: this));
  }

  // ------------------------------------------------------ member actions
  /// Bottom sheet of per-member actions (#275): edit / revoke invite / role
  /// change / remove — disallowed ones render locked (🔒 + hint toast);
  /// impossible ones (self-demote, self-remove) don't render at all.
  Future<void> showMemberActionsSheet(String memberId) {
    return _showSheet((ctx) {
      final f = curFamily();
      final m = (f?.members ?? const <FamilyMember>[])
          .where((x) => x.id == memberId)
          .firstOrNull;
      if (f == null || m == null) return const SizedBox.shrink();
      final self = m.id == myId;
      final loginless = isLoginlessMember(m);
      final invited = m.status == 'invited';
      final sub = loginless
          ? 'Login-less member — anyone can manage them'
          : invited
          ? 'Invited — hasn’t joined yet'
          : (m.role == 'owner' ? 'Owner of ${f.name}' : 'Member');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(ctx, m.name, sub),
          _memberActionRow(
            key: 'ma-edit',
            label: 'Edit ${self ? 'your row' : m.name}',
            sub: 'Name, colour, ${loginless ? 'emoji' : 'photo'}',
            locked: !canEditMemberRow(m),
            lockedHint: 'Only owners can manage members',
            onTap: () {
              Navigator.of(ctx).pop();
              pushSettingsPage<void>(
                (_) => _MemberStudio(state: this, memberId: m.id),
              );
            },
          ),
          if (invited)
            _memberActionRow(
              key: 'ma-revoke',
              label: 'Revoke invite',
              sub:
                  'Removes the pending row — they can still join with the '
                  'username',
              danger: true,
              locked: !canRevokeInvite(m),
              lockedHint: 'Only owners can revoke invites',
              onTap: () {
                Navigator.of(ctx).pop();
                showCountingConfirmSheet(
                  context,
                  title: 'Revoke ${m.name}’s invite?',
                  message:
                      'Their pending row is removed. They could still join '
                      'with the join details.',
                  confirmLabel: 'Revoke invite',
                  onConfirm: () => removeMember(m.id),
                );
              },
            ),
          if (!self && !invited && !loginless)
            _memberActionRow(
              key: 'ma-role',
              label: m.role == 'owner' ? 'Demote to member' : 'Make owner',
              sub: m.role == 'owner'
                  ? 'They lose management rights'
                  : 'They’ll manage members & settings too',
              locked: !canToggleRoleOf(m),
              lockedHint: 'Only owners can change roles',
              onTap: () {
                Navigator.of(ctx).pop();
                toggleMemberRole(m.id);
              },
            ),
          if (!self && !invited)
            _memberActionRow(
              key: 'ma-remove',
              label: 'Remove from family',
              sub: loginless
                  ? 'Their items stay on the calendar'
                  : 'They lose access to everything here',
              danger: true,
              locked: !canRemoveMemberRow(m),
              lockedHint: 'Only owners can remove members',
              onTap: () {
                Navigator.of(ctx).pop();
                showCountingConfirmSheet(
                  context,
                  title: 'Remove ${m.name}?',
                  message: loginless
                      ? 'Their calendar items stay; the member row is deleted.'
                      : 'They lose access to ${f.name} immediately. Their '
                            'past items stay.',
                  confirmLabel: 'Remove ${m.name.split(' ').first}',
                  onConfirm: () => removeMember(m.id),
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      );
    });
  }

  Widget _memberActionRow({
    required String key,
    required String label,
    required String sub,
    required VoidCallback onTap,
    bool danger = false,
    bool locked = false,
    String lockedHint = 'Only owners can manage members',
  }) {
    return GestureDetector(
      key: ValueKey(key),
      behavior: HitTestBehavior.opaque,
      onTap: locked ? () => flash(lockedHint) : onTap,
      child: Opacity(
        opacity: locked ? .55 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: danger ? const Color(0xfffef7f7) : const Color(0xfff8fafc),
            border: Border.all(color: danger ? B.redLine : B.line),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: danger ? B.red : B.ink,
                      ),
                    ),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff8a96a8),
                      ),
                    ),
                  ],
                ),
              ),
              if (locked) const Text('🔒', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ shared bits

Widget _famCard({required List<Widget> children, Color? borderColor}) =>
    Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor ?? B.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

Widget _smallPillButton(
  String label,
  VoidCallback onTap, {
  Key? key,
  bool primary = false,
  bool disabled = false,
}) {
  return GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 40),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: disabled
            ? const Color(0xfff4f6f9)
            : (primary ? B.soft : Colors.white),
        border: Border.all(
          color: disabled ? B.line : (primary ? B.primary : B.line),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: disabled
              ? const Color(0xffa8b3c2)
              : (primary ? B.deep : B.text),
        ),
      ),
    ),
  );
}

/// A name field with an explicit Save button that only appears when dirty
/// (#274/#275 — replaces save-every-keystroke). Also commits on focus loss.
class _ExplicitSaveField extends StatefulWidget {
  const _ExplicitSaveField({
    required this.fieldKey,
    required this.saveKey,
    required this.value,
    required this.onSave,
    this.hint = '',
  });

  final String fieldKey;
  final String saveKey;
  final String value;
  final ValueChanged<String> onSave;
  final String hint;

  @override
  State<_ExplicitSaveField> createState() => _ExplicitSaveFieldState();
}

class _ExplicitSaveFieldState extends State<_ExplicitSaveField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  bool get _dirty =>
      _c.text.trim().isNotEmpty && _c.text.trim() != widget.value;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // Commit on blur so a tap-away never loses the edit.
      if (!_focus.hasFocus && _dirty) _save();
    });
  }

  @override
  void didUpdateWidget(_ExplicitSaveField old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && !_focus.hasFocus) {
      _c.text = widget.value;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() => widget.onSave(_c.text.trim());

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xfff4f6f9),
              border: Border.all(color: B.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              key: ValueKey(widget.fieldKey),
              controller: _c,
              focusNode: _focus,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_dirty) _save();
              },
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                hintText: widget.hint,
                hintStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: B.muted,
                ),
              ),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: B.ink,
              ),
            ),
          ),
        ),
        if (_dirty) ...[
          const SizedBox(width: 8),
          GestureDetector(
            key: ValueKey(widget.saveKey),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(_save),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: B.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================ profile #274
class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen({required this.state});
  final _ThriveHomeState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) {
        final u = s.user;
        if (u == null) return const SizedBox.shrink();
        final identity = s.profileAvatarIdentity(u);
        final f = s.curFamily();
        final myRow = s.myMemberRow();
        final hasPhoto = (identity.photo ?? '').isNotEmpty;
        return SettingsSubScreen(
          title: 'Profile',
          subtitle: 'One identity, mirrored everywhere',
          onToast: s.flash,
          children: [
            // ------------------------------------------------ photo card
            _famCard(
              children: [
                Row(
                  children: [
                    s.avatarNode(
                      photo: identity.photo,
                      initials: identity.initials,
                      color: identity.color,
                      size: 64,
                      radius: 32,
                      fs: 20,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _smallPillButton(
                            hasPhoto ? 'Change photo' : 'Add a photo',
                            () async {
                              final p = await s.pickBadgePhoto();
                              if (p != null) s.saveProfilePhoto(p);
                            },
                            key: const ValueKey('profile-photo-btn'),
                          ),
                          if (hasPhoto)
                            GestureDetector(
                              key: const ValueKey('profile-photo-remove'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => s.saveProfilePhoto(null),
                              child: const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text(
                                  'Remove photo',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: B.red,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // ------------------------------------- name / email / colour
            _famCard(
              children: [
                studioSectionLabel('Name'),
                _ExplicitSaveField(
                  fieldKey: 'profile-name-input',
                  saveKey: 'profile-name-save',
                  value: u.name,
                  hint: 'Your name',
                  onSave: s.saveProfileName,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: B.faint)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          u.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: B.soft2,
                          ),
                        ),
                      ),
                      Container(
                        key: const ValueKey('profile-provider-pill'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: B.faint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          u.provider == 'google' ? 'Google' : 'Email',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: B.soft2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: B.faint)),
                  ),
                  child: BadgeColorRow(
                    label: 'Your colour',
                    selected: identity.color ?? Colors.transparent,
                    // The self-colour guard includes YOUR OWN picker (#274):
                    // colours worn by anyone else in the family stay locked.
                    taken: s.memberColorsTaken(myRow?.id ?? myIdSentinel),
                    onPick: s.saveProfileColor,
                    onToast: s.flash,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Greyed colours are taken by someone in '
                    '${f?.name ?? 'your family'} — colours stay unique per '
                    'family.',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: B.muted,
                    ),
                  ),
                ),
              ],
            ),
            // ------------------------------------------------- families
            _famCard(
              children: [
                studioSectionLabel('Your families'),
                for (final fam in s.families)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SettingsListRow(
                      rowKey: ValueKey('profile-family-${fam.id}'),
                      leading: famAvatar(
                        picture: fam.picture,
                        size: 34,
                        radius: 11,
                      ),
                      label: fam.name,
                      sub:
                          '@${fam.username} · ${fam.members.length} '
                          'member${fam.members.length == 1 ? '' : 's'}',
                      value: fam.id == s.familyId ? 'Current' : null,
                      goodVal: true,
                      noChev: fam.id == s.familyId,
                      onTap: () => unawaited(s.switchFamily(fam.id)),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _smallPillButton(
                        'Create a family',
                        s.openNewFamilySheet,
                        key: const ValueKey('profile-new-family'),
                        primary: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _smallPillButton(
                        'Join a family',
                        s.openJoinFamilySheet,
                        key: const ValueKey('profile-join-family'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Sentinel member id that can never match a real row, so the taken-colours
/// helper excludes nobody when the user has no member row in this family.
const String myIdSentinel = '__no-member-row__';

// ====================================================== family mgmt #275
class _FamilyScreen extends StatelessWidget {
  const _FamilyScreen({required this.state});
  final _ThriveHomeState state;

  void _confirmLeave(BuildContext context) {
    final s = state;
    final f = s.curFamily();
    if (f == null) return;
    final owner = s.amOwner();
    final candidates = s.successorCandidates(f);
    if (owner && candidates.isNotEmpty) {
      // Owner leave: explicit successor picker — never a silent transfer.
      s._showSheet(
        (ctx) => _OwnerLeaveSheet(
          state: s,
          familyId: f.id,
          onLeft: () => Navigator.of(context).maybePop(),
        ),
      );
      return;
    }
    final last = s.families.length == 1;
    final message = owner
        ? 'You’re the only account member, so the family and its data are '
              'deleted for everyone.'
        : (last
              ? 'This is your last family — you’ll land back at the '
                    'create-or-join screen.'
              : 'Your items stay; you can be invited back anytime.');
    showCountingConfirmSheet(
      context,
      title: 'Leave ${f.name}?',
      message: message,
      confirmLabel: 'Leave family',
      onConfirm: () {
        s.leaveFamily(f.id);
        Navigator.of(context).maybePop();
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    final s = state;
    final f = s.curFamily();
    if (f == null) return;
    final n = f.members.length;
    showCountingConfirmSheet(
      context,
      title: 'Delete ${f.name}?',
      message:
          'Erases the calendar, budgets and wallet for all $n '
          'member${n == 1 ? '' : 's'}. This can’t be undone.',
      confirmLabel: 'Delete family for everyone',
      onConfirm: () {
        s.deleteFamily(f.id);
        Navigator.of(context).maybePop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) {
        final f = s.curFamily();
        if (f == null) return const SizedBox.shrink();
        final owner = s.canRenameFamily();
        final canInvite = s.canInviteMembers();
        return SettingsSubScreen(
          title: f.name,
          subtitle:
              '${f.members.length} member${f.members.length == 1 ? '' : 's'}',
          onToast: s.flash,
          children: [
            // -------------------------------------- name + @username card
            _famCard(
              children: [
                if (owner)
                  _ExplicitSaveField(
                    fieldKey: 'family-name-input',
                    saveKey: 'family-name-save',
                    value: f.name,
                    hint: 'Family name',
                    onSave: (v) {
                      s.renameFamily(v);
                      s.flash('Family renamed');
                    },
                  )
                else ...[
                  Text(
                    f.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
                    ),
                  ),
                  const Text(
                    'Only the owner can rename the family.',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: B.muted,
                    ),
                  ),
                ],
                if (f.username.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.only(top: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: B.faint)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '@${f.username}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: B.primary,
                            ),
                          ),
                        ),
                        _smallPillButton('Copy', () {
                          Clipboard.setData(ClipboardData(text: f.username));
                          s.flash('"@${f.username}" copied');
                        }, key: const ValueKey('family-username-copy')),
                      ],
                    ),
                  ),
              ],
            ),
            // ------------------------------------------------ members card
            _famCard(
              children: [
                studioSectionLabel('Members · ${f.members.length}'),
                for (final m in f.members) _memberRow(s, m),
                if (!s.amOwner())
                  const Padding(
                    padding: EdgeInsets.fromLTRB(2, 4, 2, 8),
                    child: Text(
                      'Only owners can manage members — tap a row to see '
                      'your options.',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: B.muted,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _smallPillButton(
                        'Invite & share',
                        canInvite
                            ? s.openInviteSheet
                            : () => s.flash('Only owners can invite members'),
                        key: const ValueKey('family-invite-share'),
                        primary: canInvite,
                        disabled: !canInvite,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _smallPillButton(
                        'Add without login',
                        canInvite
                            ? s.openInviteSheet
                            : () => s.flash(
                                'Only owners can add members — you can edit '
                                'existing login-less members',
                              ),
                        key: const ValueKey('family-add-loginless'),
                        disabled: !canInvite,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // ------------------------------------------------ danger zone
            _famCard(
              borderColor: B.redLine,
              children: [
                GestureDetector(
                  key: const ValueKey('family-leave'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _confirmLeave(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Leave this family',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: B.red,
                          ),
                        ),
                        Text(
                          _leaveSub(s, f),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: B.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (s.amOwner())
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.only(top: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xfffee2e2))),
                    ),
                    child: GestureDetector(
                      key: const ValueKey('family-delete'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _confirmDelete(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delete family',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: B.red,
                            ),
                          ),
                          Text(
                            'Deletes everything for all ${f.members.length} '
                            'members — can’t be undone',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: B.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _leaveSub(_ThriveHomeState s, Family f) {
    if (s.amOwner()) {
      return s.successorCandidates(f).isNotEmpty
          ? 'You’re the owner — pick who takes over'
          : 'You’re the only account member — leaving deletes the family';
    }
    return s.families.length == 1
        ? 'This is your last family — you’ll go back to the start'
        : 'You can be invited back anytime';
  }

  /// A member row in one of three visual states (#275): active, invited
  /// (dimmed avatar, amber pill, cream row) or login-less (emoji avatar,
  /// "no login" pill).
  Widget _memberRow(_ThriveHomeState s, FamilyMember m) {
    final self = m.id == s.myId;
    final invited = m.status == 'invited';
    final loginless = s.isLoginlessMember(m);
    final sub = loginless
        ? 'No login — managed by anyone'
        : invited
        ? 'Invited · hasn’t joined yet'
        : (m.email.isNotEmpty ? m.email : 'Active member');
    final pill = m.role == 'owner'
        ? 'OWNER'
        : invited
        ? 'INVITED'
        : (loginless ? 'NO LOGIN' : null);
    final pillBg = m.role == 'owner'
        ? B.soft
        : invited
        ? B.amberSoft
        : B.faint;
    final pillFg = m.role == 'owner'
        ? B.deep
        : invited
        ? B.amberText
        : B.soft2;
    return GestureDetector(
      key: ValueKey('fam-member-${m.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(s.showMemberActionsSheet(m.id)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: invited ? const Color(0xfffffdf5) : B.page,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            s.avatarNode(
              photo: m.photo,
              emoji: m.emoji,
              initials: m.initials,
              color: m.color,
              size: 34,
              radius: 17,
              fs: 12,
              opacity: invited ? .55 : 1,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    self ? '${m.name} (you)' : m.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
                    ),
                  ),
                  Text(
                    sub,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff8a96a8),
                    ),
                  ),
                ],
              ),
            ),
            if (pill != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pill,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                    color: pillFg,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            ic('cright', size: 14, sw: 2.2, color: const Color(0xffc2cad6)),
          ],
        ),
      ),
    );
  }
}

// =================================================== owner-leave sheet #279
class _OwnerLeaveSheet extends StatefulWidget {
  const _OwnerLeaveSheet({
    required this.state,
    required this.familyId,
    this.onLeft,
  });
  final _ThriveHomeState state;
  final String familyId;
  final VoidCallback? onLeft;

  @override
  State<_OwnerLeaveSheet> createState() => _OwnerLeaveSheetState();
}

class _OwnerLeaveSheetState extends State<_OwnerLeaveSheet> {
  String? _successor;

  @override
  void initState() {
    super.initState();
    final f = widget.state.curFamily();
    if (f != null) {
      _successor = widget.state.successorCandidates(f).firstOrNull?.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final f = s.curFamily();
    if (f == null) return const SizedBox.shrink();
    final candidates = s.successorCandidates(f);
    final succ = candidates.where((m) => m.id == _successor).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHead(
          context,
          'Leave ${f.name}?',
          'You’re the owner. Choose who takes over before you go — this is '
              'explicit now, not silent.',
        ),
        for (final m in candidates)
          GestureDetector(
            key: ValueKey('succ-${m.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _successor = m.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: m.id == _successor ? B.soft : Colors.white,
                border: Border.all(
                  color: m.id == _successor ? B.primary : B.line,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  s.avatarNode(
                    photo: m.photo,
                    emoji: m.emoji,
                    initials: m.initials,
                    color: m.color,
                    size: 32,
                    radius: 16,
                    fs: 12,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      m.name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: B.ink,
                      ),
                    ),
                  ),
                  Text(
                    m.id == _successor ? '●' : '○',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: m.id == _successor
                          ? B.primary
                          : const Color(0xffcbd5e1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        GestureDetector(
          key: const ValueKey('owner-leave-confirm'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.of(context).pop();
            s.leaveFamily(widget.familyId, successorId: _successor);
            widget.onLeft?.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: B.red,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              'Leave — ${succ?.name.split(' ').first ?? '…'} becomes owner',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(12, 14, 12, 4),
            child: Text(
              'Cancel',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
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

// ======================================================= invite sheet #278
class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  bool _reveal = false;
  String? _pw;
  bool _hasPw = false;
  bool _loaded = false;
  final _email = TextEditingController();
  final _llName = TextEditingController();

  _ThriveHomeState get s => widget.state;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPassword());
  }

  @override
  void dispose() {
    _email.dispose();
    _llName.dispose();
    super.dispose();
  }

  Future<void> _loadPassword() async {
    final f = s.curFamily();
    if (f == null) return;
    final pw = await s.fetchFamilyPassword(f);
    final hasPw = pw != null || await s.familyHasPassword(f);
    if (!mounted) return;
    setState(() {
      _pw = pw;
      _hasPw = hasPw;
      _loaded = true;
    });
  }

  Future<void> _openResetSheet() async {
    await s._showSheet((ctx) => _ResetFamilyPasswordSheet(state: s));
    // Re-resolve: a successful reset makes the password known-this-session.
    await _loadPassword();
  }

  @override
  Widget build(BuildContext context) {
    final f = s.curFamily();
    if (f == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(
            context,
            'Invite to ${f.name}',
            'Three ways in — pick what fits.',
          ),
          // ------------------------------------------- join-details card
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xfff4f6f9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '@${f.username}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: B.primary,
                        ),
                      ),
                    ),
                    _smallPillButton('Copy', () {
                      Clipboard.setData(ClipboardData(text: f.username));
                      s.flash('"@${f.username}" copied');
                    }, key: const ValueKey('iv-copy-user')),
                  ],
                ),
                const SizedBox(height: 9),
                if (!_loaded)
                  const Text(
                    'Loading…',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: B.soft2,
                    ),
                  )
                else
                  _passwordArea(),
              ],
            ),
          ),
          // ------------------------------------------- invite by email
          studioSectionLabel('Invite by email'),
          Row(
            children: [
              Expanded(
                child: studioTextField(
                  key: const ValueKey('iv-email'),
                  controller: _email,
                  hint: 'their@email.com',
                  margin: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                key: const ValueKey('iv-add-email'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final em = _email.text.trim();
                  if (em.isEmpty) {
                    s.flash('Type their email first');
                    return;
                  }
                  s.inviteMemberByEmail(em);
                  setState(_email.clear);
                },
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: B.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 6, 2, 12),
            child: Text(
              'Honest note: this only adds them as "invited" — Thrive '
              'doesn’t send an email yet. Share the join details yourself.',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: B.amberText,
              ),
            ),
          ),
          // -------------------------------------------- add login-less
          studioSectionLabel('Add someone without a login'),
          Row(
            children: [
              Expanded(
                child: studioTextField(
                  key: const ValueKey('iv-ll-name'),
                  controller: _llName,
                  hint: 'Name (e.g. a child)',
                  margin: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                key: const ValueKey('iv-add-ll'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final nm = _llName.text.trim();
                  if (nm.isEmpty) {
                    s.flash('Type a name first');
                    return;
                  }
                  s.addMember(nm);
                  setState(_llName.clear);
                },
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: B.soft,
                    border: Border.all(color: B.primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: B.deep,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 6, 2, 14),
            child: Text(
              'They appear everywhere but never sign in — anyone can '
              'manage them.',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: B.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Exactly one of the three password states renders (#278): none,
  /// set-but-unknowable, or known-this-session.
  Widget _passwordArea() {
    final pw = _pw;
    if (pw != null && pw.isNotEmpty) {
      // Known this session: masked with Reveal/Hide + Copy.
      return Row(
        key: const ValueKey('iv-pw-known'),
        children: [
          Expanded(
            child: Text(
              _reveal ? pw : '•' * pw.length,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: B.ink,
              ),
            ),
          ),
          _smallPillButton(
            _reveal ? 'Hide' : 'Reveal',
            () => setState(() => _reveal = !_reveal),
            key: const ValueKey('iv-reveal'),
          ),
          const SizedBox(width: 8),
          _smallPillButton('Copy', () {
            Clipboard.setData(ClipboardData(text: pw));
            s.flash('Password copied');
          }, key: const ValueKey('iv-copy-pw')),
        ],
      );
    }
    if (_hasPw) {
      // Set, but only the salted hash survives — it can't be shown.
      return Container(
        key: const ValueKey('iv-pw-hidden'),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xffeef1f6),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            const Text(
              'A password is set, but Thrive only stores it scrambled — it '
              'can’t be shown. Share it directly, or',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xff475569),
              ),
            ),
            GestureDetector(
              key: const ValueKey('iv-reset-pw'),
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_openResetSheet()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: B.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'reset it',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    // None set: amber warning + Set one.
    return Container(
      key: const ValueKey('iv-pw-none'),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: B.amberSoft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          const Text(
            'No password — anyone with the username can join.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: B.amberText,
            ),
          ),
          GestureDetector(
            key: const ValueKey('iv-set-pw'),
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(_openResetSheet()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: B.amberText,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Set one',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================= reset join password (#278)
class _ResetFamilyPasswordSheet extends StatefulWidget {
  const _ResetFamilyPasswordSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_ResetFamilyPasswordSheet> createState() =>
      _ResetFamilyPasswordSheetState();
}

class _ResetFamilyPasswordSheetState extends State<_ResetFamilyPasswordSheet> {
  final _pw = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  bool get _ok => _pw.text.length >= 4;

  Future<void> _save() async {
    if (!_ok || _busy) return;
    setState(() => _busy = true);
    final err = await widget.state.resetFamilyPassword(_pw.text);
    if (!mounted) return;
    if (err != null) {
      setState(() => _busy = false);
      widget.state.showError(err);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHead(
          context,
          'Set a new join password',
          'The old one stops working the moment you save. Passwords are '
              'stored scrambled — only you’ll know this one.',
        ),
        studioTextField(
          key: const ValueKey('rp-input'),
          controller: _pw,
          hint: 'New password (min 4 characters)',
          onChanged: (_) => setState(() {}),
        ),
        GestureDetector(
          key: const ValueKey('rp-save'),
          behavior: HitTestBehavior.opaque,
          onTap: _save,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _ok ? B.primary : const Color(0xffe2e8f0),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              _busy ? 'Saving…' : 'Save password',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: _ok ? Colors.white : const Color(0xff94a0b0),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ====================================================== delete account #280
class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _ok => _typed.text.trim().toUpperCase() == 'DELETE';

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHead(
          context,
          'Delete your account?',
          '${s._deleteAccountConsequence()} Then you’re signed out. This '
              'can’t be undone.',
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xfffef2f2),
            border: Border.all(color: B.redLine),
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 10),
          child: TextField(
            key: const ValueKey('da-input'),
            controller: _typed,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 12,
              ),
              hintText: 'Type "DELETE" to confirm',
              hintStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: B.muted,
              ),
            ),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: B.ink,
            ),
          ),
        ),
        GestureDetector(
          key: const ValueKey('da-confirm'),
          behavior: HitTestBehavior.opaque,
          onTap: _ok
              ? () {
                  Navigator.of(context).pop();
                  unawaited(s.deleteUserAccount());
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _ok ? B.red : const Color(0xfffee2e2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              'Delete my account',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: _ok ? Colors.white : const Color(0xfff0a1a1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
