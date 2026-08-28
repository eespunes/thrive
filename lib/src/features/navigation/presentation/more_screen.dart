part of 'package:family_money_management_app/main.dart';

/// The Settings v2 hub (#272, `Settings v2.dc.html`): a gradient hero
/// (avatar · name · provider · family switcher pills) with four expanding
/// cards — Planning, Money, Family, Account — whose closed state shows a
/// live summary and whose rows carry their current value on the right.
extension _ThriveMoreScreen on _ThriveHomeState {
  Widget _buildMore() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 14),
      children: [
        _hubHero(),
        // Cards tuck into the hero's gradient, per the design's -14px pull.
        Transform.translate(
          offset: const Offset(0, -14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _hubPlanningCard(),
                const SizedBox(height: 10),
                _hubMoneyCard(),
                const SizedBox(height: 10),
                _hubFamilyCard(),
                const SizedBox(height: 10),
                _hubAccountCard(),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _appVersion.isEmpty
                        ? 'Thrive · English (UK)'
                        : 'Thrive $_appVersion · English (UK)',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: B.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- cards

  Widget _hubPlanningCard() {
    final layers = _kitchenWallLayers(this);
    final visible = layers
        .where((l) => kitchenLayerFilter.contains(l.id))
        .length;
    final start = _weekStart();
    var planned = 0;
    for (var i = 0; i < 7; i++) {
      final d = weeklyPlan[_iso(start.add(Duration(days: i)))];
      if (d != null && !d.isEmpty) planned++;
    }
    final catCount = eventCategories.length;
    final impCount = importedCalendars.length;
    final failing = importedCalendars
        .where((c) => failedImportIds.contains(c.id))
        .length;
    final activeMembers = (curFamily()?.members ?? const <FamilyMember>[])
        .where((m) => m.status == 'active')
        .length;
    final layersOn = calendarLayers
        .where((l) => layerFilter.contains(l.id))
        .length;
    return _hubCard(
      id: 'planning',
      icon: 'moon',
      title: 'Planning',
      summary:
          '$layersOn of ${calendarLayers.length} layers on · '
          'wall ${kitchenEnabled ? 'on' : 'off'}',
      hint: kitchenEnabled
          ? 'Per-member: photo tile toggle + reward stars (0–5).'
          : null,
      rows: [
        _hubRow(
          key: 'more-weekly',
          label: 'Weekly plan',
          val: '$planned of 7 planned',
          onTap: openWeeklyPlanSheet,
        ),
        _hubRow(
          key: 'more-calmanage',
          label: 'Categories',
          val: '$catCount badge${catCount == 1 ? '' : 's'}',
          onTap: () => openCalendarManageSheet(mode: _CalManageMode.categories),
        ),
        _hubRow(
          key: 'more-memcolors',
          label: 'Member colours',
          sub: 'Each person’s identity colour',
          val: '$activeMembers member${activeMembers == 1 ? '' : 's'}',
          // The dedicated member-colours sub-screen lands in a later phase;
          // until then the family sheet is where colours are edited.
          onTap: openFamilySheet,
        ),
        _hubRow(
          key: 'more-calimports',
          label: 'Imported calendars',
          val: impCount == 0
              ? 'None yet'
              : (failing > 0 ? '$failing failing' : 'All synced'),
          warnVal: failing > 0,
          goodVal: impCount > 0 && failing == 0,
          onTap: () => openCalendarManageSheet(mode: _CalManageMode.imports),
        ),
        _hubRow(
          key: 'more-callayers',
          label: 'Calendar layers',
          sub: 'Appointments, to-dos & content',
          val: '$layersOn of ${calendarLayers.length} on',
          onTap: () => openCalendarManageSheet(mode: _CalManageMode.layers),
        ),
        _hubRow(
          key: 'more-kitchen-settings',
          label: 'Kitchen wall',
          sub: 'The shared tablet screen',
          val: kitchenEnabled ? '$visible of ${layers.length} layers' : 'Off',
          warnVal: !kitchenEnabled,
          onTap: openKitchenWallSettings,
        ),
      ],
    );
  }

  Widget _hubMoneyCard() {
    final n = cards.length;
    return _hubCard(
      id: 'money',
      icon: 'card',
      title: 'Money',
      summary: n == 0
          ? 'No discount cards yet'
          : '$n discount card${n == 1 ? '' : 's'}',
      rows: [
        _hubRow(
          key: 'more-wallet',
          label: 'Discount cards',
          val: n == 0 ? 'None yet' : '$n card${n == 1 ? '' : 's'}',
          onTap: openWalletScreen,
        ),
        _hubRow(
          key: 'more-widget-privacy',
          label: 'Hide amounts on phone widgets',
          sub: 'Home-screen widgets show •••• instead',
          tog: widgetHideAmounts,
          onTog: toggleWidgetHideAmounts,
        ),
        // Both money rows still land on the old Finance settings sheet until
        // the dedicated Accounts / Budget blocks sub-screens ship (#324
        // follow-ups). The Accounts row keeps the historical
        // 'more-finsettings' key so existing flows keep working.
        _hubRow(
          key: 'more-finsettings',
          label: 'Accounts',
          sub: 'Who pays from where',
          val: '${accounts.length} account${accounts.length == 1 ? '' : 's'}',
          onTap: openFinanceSettingsSheet,
        ),
        _hubRow(
          key: 'more-blocks',
          label: 'Budget blocks',
          sub: 'The columns of the monthly budget',
          val: '${cats.length} block${cats.length == 1 ? '' : 's'}',
          onTap: openFinanceSettingsSheet,
        ),
      ],
    );
  }

  Widget _hubFamilyCard() {
    final f = curFamily();
    final members = f?.members ?? const <FamilyMember>[];
    final owner = amOwner();
    final ownerName = members
        .where((m) => m.role == 'owner')
        .firstOrNull
        ?.name
        .split(' ')
        .first;
    return _hubCard(
      id: 'family',
      icon: 'users',
      title: 'Family',
      summary:
          '${members.length} member${members.length == 1 ? '' : 's'} · '
          '${owner ? 'you own this family' : 'owned by ${ownerName ?? '?'}'}',
      hint: owner ? null : 'Only owners can manage members.',
      rows: [
        // The member list lives directly on the card (#330): avatar, role and
        // status per row. Tapping opens the family sheet, where the member
        // actions live until the dedicated actions sheet ships.
        for (final m in members)
          _hubRow(
            key: 'more-member-${m.id}',
            label: m.id == myId ? '${m.name} (you)' : m.name,
            sub: m.status == 'invited'
                ? 'Invited · hasn’t joined yet'
                : (m.email.isNotEmpty ? m.email : 'Active member'),
            pill: m.role == 'owner'
                ? 'owner'
                : (m.status == 'invited' ? 'invited' : null),
            pillKind: m.role == 'owner' ? 'owner' : 'invited',
            bg: m.status == 'invited' ? const Color(0xfffffdf5) : null,
            trail: avatarNode(
              photo: m.photo,
              emoji: m.emoji,
              initials: m.initials,
              color: m.color,
              size: 26,
              radius: 13,
              fs: 10,
              opacity: m.status == 'invited' ? .55 : 1,
            ),
            onTap: openFamilySheet,
          ),
        _hubRow(
          key: 'more-invite',
          label: 'Invite & share',
          sub: (f?.username.isNotEmpty ?? false)
              ? '@${f!.username}'
              : 'Share your join details',
          disabled: !owner,
          disHint: 'Only owners can invite members',
          onTap: openInviteSheet,
        ),
      ],
    );
  }

  Widget _hubAccountCard() {
    final u = user;
    return _hubCard(
      id: 'account',
      icon: 'gear',
      title: 'Account',
      summary: '${_hubProviderLabel()} · ${u?.email ?? 'not signed in'}',
      rows: [
        _hubRow(
          key: 'hub-notifications',
          label: 'Notifications',
          sub: 'Event reminders on this phone',
          tog: notificationsEnabled,
          onTog: toggleNotificationsEnabled,
        ),
        _hubRow(
          key: 'hub-calsync',
          label: 'Sync with device calendar',
          sub: 'Android · mirrors events into the system calendar',
          tog: deviceCalendarSyncEnabled,
          onTog: toggleDeviceCalendarSync,
        ),
        _hubRow(
          key: 'hub-future-dark',
          label: 'Dark mode',
          pill: 'future',
          tog: futureDark,
          onTog: () => update(() => futureDark = !futureDark),
        ),
        _hubRow(
          key: 'hub-future-language',
          label: 'Language',
          pill: 'future',
          val: 'English (UK)',
          noChev: true,
          onTap: () => flash('Only English (UK) for now'),
        ),
        _hubRow(
          key: 'hub-resetpw',
          label: 'Reset password',
          sub: u?.provider == 'google'
              ? 'You sign in with Google — no password here'
              : 'We’ll email you a reset link',
          disabled: u?.provider == 'google',
          disHint: 'You sign in with Google — there’s no password to reset',
          onTap: openResetPasswordSheet,
        ),
        _hubRow(
          key: 'more-signout',
          label: 'Sign out',
          sub: 'You stay in your families — nothing is deleted',
          danger: true,
          bg: const Color(0xfffef7f7),
          noChev: true,
          onTap: signOut,
        ),
        _hubRow(
          key: 'more-delete-account',
          label: 'Delete account',
          sub: _deleteAccountConsequence(),
          danger: true,
          bg: B.redSoft,
          noChev: true,
          onTap: () => askDelete(
            'your account',
            '${_deleteAccountConsequence()} Then you’re signed out. '
                'This can’t be undone.',
            () => unawaited(deleteUserAccount()),
          ),
        ),
      ],
    );
  }

  String _hubProviderLabel() => user?.provider == 'google' ? 'Google' : 'Email';

  /// The honest one-liner under "Delete account": how many families are
  /// deleted with you vs merely lose you (mirrors the design's
  /// `deleteAcctSub()`).
  String _deleteAccountConsequence() {
    var sole = 0, shared = 0;
    for (final f in families) {
      final others = f.members.where(
        (m) =>
            m.id != myId &&
            m.status == 'active' &&
            (m.uid != null || m.email.isNotEmpty),
      );
      others.isEmpty ? sole++ : shared++;
    }
    final bits = <String>[
      if (sole > 0)
        'deletes $sole famil${sole > 1 ? 'ies' : 'y'} where you’re the '
            'only member',
      if (shared > 0)
        'removes you from $shared shared famil${shared > 1 ? 'ies' : 'y'}',
    ];
    if (bits.isEmpty) return 'Deletes your data.';
    final s = bits.join(' and ');
    return '${s[0].toUpperCase()}${s.substring(1)}.';
  }

  // ---------------------------------------------------------------- hero

  /// Gradient hero: avatar + name/email + provider pill (tap → profile) and
  /// the family switcher pills. Mirrors the design's hub hero.
  Widget _hubHero() {
    final u = user;
    return Container(
      decoration: const BoxDecoration(gradient: B.grad),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            key: const ValueKey('more-profile'),
            onTap: openProfileSheet,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: .22),
                    border: Border.all(
                      color: u?.color ?? Colors.white,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatarNode(
                    photo: u?.photo,
                    initials: u?.initials ?? '?',
                    color: u?.color,
                    size: 44,
                    radius: 14,
                    fs: 15,
                  ),
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
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.3,
                          color: Colors.white,
                        ),
                      ),
                      if ((u?.email ?? '').isNotEmpty)
                        Text(
                          u!.email,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: .85),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _hubProviderLabel(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ic(
                  'cright',
                  size: 16,
                  sw: 2.2,
                  color: Colors.white.withValues(alpha: .7),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final fam in families) _hubFamilyPill(fam),
                _hubCreateOrJoinPill(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hubFamilyPill(Family fam) {
    final current = fam.id == familyId;
    final n = fam.members.length;
    return GestureDetector(
      key: ValueKey('hub-fam-${fam.id}'),
      onTap: () {
        if (!current) unawaited(switchFamily(fam.id));
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 160, minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: current ? Colors.white : Colors.white.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${fam.name} · $n',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: current ? B.deep : Colors.white,
          ),
        ),
      ),
    );
  }

  /// "＋ Create or join a family" entry alongside the switcher pills.
  Widget _hubCreateOrJoinPill() {
    return GestureDetector(
      key: const ValueKey('hub-fam-add'),
      onTap: openCreateOrJoinSheet,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12),
          border: Border.all(color: Colors.white.withValues(alpha: .5)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          '＋ Create or join a family',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- card + rows

  /// An expanding hub card: header with icon tile, title, live summary and a
  /// chevron; one card open at a time (`hubOpenCard`).
  Widget _hubCard({
    required String id,
    required String icon,
    required String title,
    required String summary,
    required List<Widget> rows,
    String? hint,
  }) {
    final open = hubOpenCard == id;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: cardShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            key: ValueKey('hub-card-$id'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              update(() => hubOpenCard = open ? null : id);
              if (!open) {
                logAnalyticsEvent('settings_card_opened', {'card': id});
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: B.soft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: ic(icon, size: 16, sw: 2.2, color: B.primary),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: B.ink,
                          ),
                        ),
                        Text(
                          summary,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: B.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.rotate(
                    angle: open ? math.pi : 0,
                    child: ic('down', size: 15, sw: 2.2, color: B.muted),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    rows[i],
                  ],
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Text(
                        hint,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: B.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// A hub card row, mirroring the design's `row()`: grey rounded row with
  /// label/sub, a right-side value pill, an optional FUTURE pill, chevron,
  /// and an optional trailing toggle.
  Widget _hubRow({
    required String key,
    required String label,
    String? sub,
    String? val,
    bool goodVal = false,
    bool warnVal = false,
    String? pill,
    String pillKind = 'future',
    VoidCallback? onTap,
    bool danger = false,
    Color? bg,
    bool noChev = false,
    bool? tog,
    VoidCallback? onTog,
    bool disabled = false,
    String? disHint,
    Widget? trail,
  }) {
    final row = GestureDetector(
      key: ValueKey(key),
      behavior: HitTestBehavior.opaque,
      // Toggle rows flip on a tap anywhere in the row, not just the track.
      onTap: disabled
          ? () => flash(disHint ?? 'Only owners can change this')
          : (onTap ?? onTog),
      child: Opacity(
        opacity: disabled ? .5 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg ?? B.page,
            borderRadius: BorderRadius.circular(12),
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
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: danger ? B.red : B.ink,
                      ),
                    ),
                    if (sub != null && sub.isNotEmpty)
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: pillKind == 'owner'
                        ? B.soft
                        : (pillKind == 'invited'
                              ? B.amberSoft
                              : const Color(0xfff5f3ff)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    pill.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                      color: pillKind == 'owner'
                          ? B.deep
                          : (pillKind == 'invited'
                                ? B.amberText
                                : const Color(0xff7c3aed)),
                    ),
                  ),
                ),
              ],
              if (trail != null) ...[const SizedBox(width: 6), trail],
              if (val != null && val.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: warnVal
                        ? B.amberSoft
                        : (goodVal ? B.greenSoft : const Color(0xffe8ecf2)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    val,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: warnVal
                          ? B.amberText
                          : (goodVal ? B.greenText : B.soft2),
                    ),
                  ),
                ),
              ],
              if (onTap != null && !noChev && tog == null) ...[
                const SizedBox(width: 4),
                ic('cright', size: 14, sw: 2.2, color: const Color(0xffc2cad6)),
              ],
            ],
          ),
        ),
      ),
    );
    if (tog == null) return row;
    return Row(
      children: [
        Expanded(child: row),
        const SizedBox(width: 8),
        _hubToggle(tog, disabled ? null : onTog),
      ],
    );
  }

  /// The design's small track toggle (42×25, teal when on).
  Widget _hubToggle(bool on, VoidCallback? onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 42,
          height: 25,
          padding: const EdgeInsets.all(2.5),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: on ? B.primary : const Color(0xffcfd6df),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
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

  /// "Create or join a family" chooser behind the hero's ＋ pill (#330).
  void openCreateOrJoinSheet() {
    _showSheet(
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(
            ctx,
            'Create or join a family',
            'One account, all your families',
          ),
          _sheetOptionRow(
            key: 'hub-create-family',
            title: 'Create a family',
            sub: 'You’ll be the owner',
            onTap: () {
              Navigator.of(ctx).pop();
              openNewFamilySheet();
            },
          ),
          const SizedBox(height: 7),
          _sheetOptionRow(
            key: 'hub-join-family',
            title: 'Join a family',
            sub: 'With their username & password',
            onTap: () {
              Navigator.of(ctx).pop();
              openJoinFamilySheet();
            },
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _sheetOptionRow({
    required String key,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: ValueKey(key),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xfff8fafc),
          border: Border.all(color: B.line),
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
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
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
            ic('cright', size: 14, sw: 2.2, color: const Color(0xffc2cad6)),
          ],
        ),
      ),
    );
  }

  /// Reset password sheet (#330): a small confirm that emails the signed-in
  /// address a reset link (email-provider accounts only).
  void openResetPasswordSheet() {
    _showSheet(
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(
            ctx,
            'Reset password',
            'We’ll email ${user?.email ?? 'you'} a reset link. '
                'Your current password keeps working until you set a new one.',
          ),
          GestureDetector(
            key: const ValueKey('resetpw-send'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(ctx).pop();
              unawaited(sendPasswordReset());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: B.primary,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Text(
                'Send reset link',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  /// Sends the Firebase password-reset email for the signed-in address.
  /// Local/demo mode (no Firebase app) just explains itself in a toast.
  Future<void> sendPasswordReset() async {
    final email = user?.email ?? '';
    if (email.isEmpty) {
      flash('No email on this account');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      flash('Reset link sent to $email');
    } catch (e) {
      debugPrint('[account] password reset failed: $e');
      flash('Couldn’t send the link — try again later');
    }
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
