part of 'package:family_money_management_app/main.dart';

/// The redesigned "More" hub: a profile card plus grouped, hairline-divided
/// setting rows, ported from the design's updated `renderMore()` /
/// `moreRow()` / `moreGroup()` / `moreProfileCard()` / `sheetInvite()`.
extension _ThriveMoreScreen on _ThriveHomeState {
  Widget _buildMore() {
    final f = curFamily();
    final memberIds = <String>[
      for (final m in f?.members ?? const <FamilyMember>[]) m.id,
    ];
    final catCount = eventCategories.length;
    final impCount = importedCalendars.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        _moreProfileCard(),
        const SizedBox(height: 18),
        _moreSecLabel('Planning'),
        _moreGroup([
          _moreRow(
            key: 'more-weekly',
            icon: 'moon',
            title: 'Weekly plan',
            sub: 'Meals & notes for the week',
            onTap: openWeeklyPlanSheet,
            trail: _moreMeta(_weekRangeIso(_iso(_weekStart()))),
          ),
          _moreRow(
            key: 'more-calmanage',
            icon: 'cal',
            title: 'Categories',
            sub: 'Colours, icons & member colours',
            onTap: () =>
                openCalendarManageSheet(mode: _CalManageMode.categories),
            trail: _moreMeta('$catCount categor${catCount == 1 ? 'y' : 'ies'}'),
          ),
          _moreRow(
            key: 'more-calimports',
            icon: 'download',
            title: 'Imported calendars',
            sub: 'Feeds & sync',
            onTap: () => openCalendarManageSheet(mode: _CalManageMode.imports),
            trail: _moreMeta('$impCount calendar${impCount == 1 ? '' : 's'}'),
          ),
          _moreRow(
            key: 'more-callayers',
            icon: 'filter',
            title: 'Calendar layers',
            sub: 'Appointments, to-dos & content',
            onTap: () => openCalendarManageSheet(mode: _CalManageMode.layers),
          ),
          _moreRow(
            key: 'more-kitchen-settings',
            icon: 'gear',
            title: 'Kitchen wall settings',
            sub: 'Layers & picture mode',
            onTap: openKitchenWallSettings,
          ),
        ]),
        const SizedBox(height: 18),
        _moreSecLabel('Money'),
        _moreGroup([
          _moreRow(
            key: 'more-wallet',
            icon: 'card',
            title: 'Discount cards',
            sub: 'Scan one, use it at the till',
            onTap: openWalletScreen,
            trail: cards.isEmpty
                ? null
                : _moreMeta(
                    '${cards.length} card${cards.length == 1 ? '' : 's'}',
                  ),
          ),
          _moreRow(
            key: 'more-widget-privacy',
            icon: 'eyeoff',
            title: 'Hide amounts on phone widgets',
            sub: 'Home-screen widgets show •••• instead',
            onTap: toggleWidgetHideAmounts,
            trail: _moreMeta(widgetHideAmounts ? 'On' : 'Off'),
            noChev: true,
          ),
          _moreRow(
            key: 'more-finsettings',
            icon: 'gear',
            title: 'Finance settings',
            sub: 'Accounts, blocks & tools',
            onTap: openFinanceSettingsSheet,
          ),
        ]),
        const SizedBox(height: 18),
        _moreSecLabel('Family'),
        _moreGroup([
          _moreRow(
            key: 'more-family',
            icon: 'users',
            title: 'Members & roles',
            sub: 'Manage who can see and edit',
            onTap: openFamilySheet,
            trail: memberIds.isEmpty ? null : _mStack(memberIds),
          ),
          _moreRow(
            key: 'more-invite',
            icon: 'plus',
            title: 'Invite someone',
            sub: 'Share your join details',
            onTap: openInviteSheet,
          ),
        ]),
        const SizedBox(height: 18),
        _moreSecLabel('Account'),
        _moreGroup([
          _moreRow(
            key: 'more-signout',
            icon: 'back',
            title: 'Sign out',
            sub: 'You stay in your families',
            onTap: signOut,
            danger: true,
            noChev: true,
          ),
        ]),
        const SizedBox(height: 18),
        Center(
          child: Text(
            _appVersion.isEmpty ? 'Thrive' : 'Thrive · v$_appVersion',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: B.muted,
            ),
          ),
        ),
      ],
    );
  }

  /// Avatar + name/email + chevron, opens the profile sheet. Mirrors
  /// `moreProfileCard()`; replaces the old separate "Your profile" row.
  Widget _moreProfileCard() {
    final u = user;
    return GestureDetector(
      key: const ValueKey('more-profile'),
      onTap: openProfileSheet,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: B.line),
          borderRadius: BorderRadius.circular(16),
          boxShadow: cardShadow(),
        ),
        child: Row(
          children: [
            avatarNode(
              photo: u?.photo,
              initials: u?.initials ?? '?',
              color: u?.color,
              size: 44,
              radius: 14,
              fs: 15,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    u?.name ?? 'You',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
                    ),
                  ),
                  if ((u?.email ?? '').isNotEmpty)
                    Text(
                      u!.email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: B.soft2,
                      ),
                    ),
                ],
              ),
            ),
            ic('cright', size: 17, sw: 2.2, color: B.muted),
          ],
        ),
      ),
    );
  }

  /// Uppercase muted section label, mirrors `secLabel()`.
  Widget _moreSecLabel(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        t.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
          color: B.muted,
        ),
      ),
    );
  }

  /// Small pill: muted text on a faint background. Mirrors `moreMeta()`.
  Widget _moreMeta(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: B.faint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: B.soft2,
        ),
      ),
    );
  }

  /// Overlapping avatar stack (up to 4, then a "+N" bubble). Mirrors
  /// `mStack()`.
  Widget _mStack(List<String> ids, {double size = 24}) {
    final f = curFamily();
    if (f == null) return const SizedBox.shrink();
    final shown = ids.take(4).toList();
    final overflow = ids.length - shown.length;
    return SizedBox(
      height: size,
      width:
          size +
          (shown.length - 1) * size * .68 +
          (overflow > 0 ? size * .68 : 0),
      child: Stack(
        children: [
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * size * .68,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: () {
                  final m = f.members.where((x) => x.id == shown[i]);
                  if (m.isEmpty) return const SizedBox.shrink();
                  final mem = m.first;
                  return avatarNode(
                    photo: mem.photo,
                    emoji: mem.emoji,
                    initials: mem.initials,
                    color: mem.color,
                    size: size,
                    radius: size / 2,
                    fs: size * .4,
                  );
                }(),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: shown.length * size * .68,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: B.faint,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    fontSize: size * .38,
                    fontWeight: FontWeight.w800,
                    color: B.soft2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A single grouped-list row: icon tile, title/subtitle, optional trailing
  /// widget, chevron. Mirrors `moreRow()`.
  Widget _moreRow({
    required String key,
    required String icon,
    required String title,
    required String sub,
    required VoidCallback onTap,
    Widget? trail,
    bool danger = false,
    bool noChev = false,
  }) {
    return GestureDetector(
      key: ValueKey(key),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: danger ? B.redSoft : B.soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: ic(
                  icon,
                  size: 18,
                  sw: 2.1,
                  color: danger ? B.red : B.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: danger ? B.red : B.ink,
                    ),
                  ),
                  Text(
                    sub,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: B.soft2,
                    ),
                  ),
                ],
              ),
            ),
            if (trail != null) ...[const SizedBox(width: 8), trail],
            if (!noChev) ...[
              const SizedBox(width: 6),
              ic('cright', size: 17, sw: 2.2, color: B.muted),
            ],
          ],
        ),
      ),
    );
  }

  /// White rounded container with hairline dividers between rows. Mirrors
  /// `moreGroup()`.
  Widget _moreGroup(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            Container(
              decoration: i == 0
                  ? null
                  : const BoxDecoration(
                      border: Border(top: BorderSide(color: B.faint)),
                    ),
              child: rows[i],
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- sheets
  void openWeeklyPlanSheet() {
    _showSheet(
      (ctx) => ValueListenableBuilder<int>(
        valueListenable: _rev,
        builder: (context, _, _) => _sheetEmbed(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sheetHead(ctx, 'Weekly plan', 'Meals & notes for the week'),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _weekSubHeader(),
              ),
            ],
          ),
          _buildWeeklyPlan(embed: true),
        ),
      ),
    );
  }

  void openFinanceSettingsSheet() {
    _showSheet(
      (ctx) => ValueListenableBuilder<int>(
        valueListenable: _rev,
        builder: (context, _, _) => _sheetEmbed(
          _sheetHead(ctx, 'Finance settings', 'Accounts, blocks & tools'),
          _buildSettings(embed: true),
        ),
      ),
    );
  }

  /// Wraps sheet-embedded tab content: keeps the sheet's own header/side
  /// padding but lets the embedded body (which already carries its own
  /// internal padding, or intentionally has none) render without doubling up
  /// or overflowing horizontally. Mirrors `sheetEmbed()`.
  Widget _sheetEmbed(Widget head, Widget body) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * .78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          Expanded(child: ClipRect(child: body)),
        ],
      ),
    );
  }

  void openInviteSheet() {
    _showSheet((ctx) => _InviteSheet(state: this));
  }
}

/// "Invite someone" sheet: family join details (username + optional
/// password, masked with a reveal toggle) so anyone can join by entering
/// them. Mirrors the design's `sheetInvite()`.
class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  bool _showPw = false;
  String? _pw;
  bool _hasPw = false;
  bool _pwLoaded = false;

  _ThriveHomeState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _loadPassword();
  }

  Future<void> _loadPassword() async {
    final f = s.curFamily();
    if (f == null) return;
    final pw = await s.fetchFamilyPassword(f);
    // The plaintext is only known in the session that typed it (it is never
    // persisted); a password can still be SET without being displayable.
    final hasPw = pw != null || await s.familyHasPassword(f);
    if (!mounted) return;
    setState(() {
      _pw = pw;
      _hasPw = hasPw;
      _pwLoaded = true;
    });
  }

  void _copy(String label, String value) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    s.flash('$label copied');
  }

  @override
  Widget build(BuildContext context) {
    final f = s.curFamily();
    if (f == null) return const SizedBox.shrink();
    final pw = _pw;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(context, 'Invite someone', 'Share your join details'),
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: B.soft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: B.greenLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JOIN DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                    color: B.deep,
                  ),
                ),
                const SizedBox(height: 10),
                _credRow(
                  'Family username',
                  f.username,
                  onCopy: () => _copy('Username', f.username),
                ),
                const SizedBox(height: 8),
                if (pw != null && pw.isNotEmpty)
                  _credRow(
                    'Family password',
                    _showPw ? pw : '•' * pw.length,
                    icon: _showPw ? 'eyeoff' : 'eye',
                    iconKey: const ValueKey('invite-password-toggle'),
                    onIcon: () => setState(() => _showPw = !_showPw),
                    onCopy: () => _copy('Password', pw),
                  )
                else if (!_pwLoaded)
                  const Text(
                    'Loading…',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: B.soft2,
                    ),
                  )
                else
                  Text(
                    _hasPw
                        ? 'Password is set, but only shown in the session '
                              'that typed it — share it directly.'
                        : 'Not set — anyone with the username can join.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: B.soft2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _credRow(
    String label,
    String value, {
    String? icon,
    VoidCallback? onIcon,
    required VoidCallback onCopy,
    Key? iconKey,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: B.line),
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
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: B.muted,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: B.ink,
                  ),
                ),
              ],
            ),
          ),
          if (icon != null)
            GestureDetector(
              key: iconKey,
              onTap: onIcon,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ic(icon, size: 16, sw: 2.1, color: B.deep),
              ),
            ),
          GestureDetector(
            onTap: onCopy,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: ic('copy', size: 15, sw: 2.2, color: B.deep),
            ),
          ),
        ],
      ),
    );
  }
}
