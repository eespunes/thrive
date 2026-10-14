part of 'package:family_money_management_app/main.dart';

/// The Settings v2 hub (#272, `Settings v2.dc.html`): a gradient hero
/// (avatar · name · provider · family switcher pills) with four expanding
/// cards — Planning, Money, Family, Account — whose closed state shows a
/// live summary and whose rows carry their current value on the right.
extension _ThriveMoreScreen on _ThriveHomeState {
  Widget _buildMore() {
    return Stack(
      children: [
        if (!_headerScrolled)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: context.tc.grad),
            ),
          ),
        ListView(
          padding: const EdgeInsets.only(bottom: 14),
          children: [
            const SizedBox(height: 14),
            // Cards tuck into the hero's gradient, per the design's -14px pull.
            Transform.translate(
              offset: const Offset(0, -14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sections that aren't on this person's bar live here, one
                    // tap away (#365) — nothing becomes unreachable by unpicking
                    // it. The card disappears when the bar holds everything.
                    if (navMoreSections.isNotEmpty) ...[
                      _hubSectionsCard(),
                      const SizedBox(height: 10),
                    ],
                    _hubPlanningCard(),
                    const SizedBox(height: 10),
                    // Kid profiles never see money or discount cards.
                    if (!isChildUser) ...[
                      _hubMoneyCard(),
                      const SizedBox(height: 10),
                    ],
                    _hubFamilyCard(),
                    const SizedBox(height: 10),
                    _hubAccountCard(),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _appVersion.isEmpty
                            ? 'Thrive · English (UK)'
                            : 'Thrive $_appVersion · English (UK)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: context.tc.muted,
                        ),
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
  }

  // --------------------------------------------------------------- cards

  /// The unpicked sections, plus the way back into the tab editor.
  Widget _hubSectionsCard() {
    final hidden = navMoreSections;
    return _hubCard(
      id: 'sections',
      icon: 'grid',
      title: 'Sections',
      summary: hidden.length == 1
          ? '1 section not on your bar'
          : '${hidden.length} sections not on your bar',
      hint: 'Long-press the bar to change which three it holds.',
      rows: [
        for (final key in hidden)
          _hubRow(
            key: 'more-section-$key',
            label: navSectionMeta(key).$1,
            onTap: () => goTab(key),
          ),
        _hubRow(
          key: 'more-tabbar',
          label: 'Tab bar',
          sub: 'Pick the $kNavPickCount sections your bar holds',
          val: 'Edit',
          onTap: openNavTabEditor,
        ),
      ],
    );
  }

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
    final child = isChildUser;
    return _hubCard(
      id: 'planning',
      icon: 'moon',
      title: 'Planning',
      summary: child
          ? '$layersOn of ${calendarLayers.length} layers on'
          : '$layersOn of ${calendarLayers.length} layers on · '
                'wall ${kitchenEnabled ? 'on' : 'off'}',
      hint: child
          ? 'The meal plan is read-only on a kid profile.'
          : (kitchenEnabled
                ? 'Per-member: photo tile toggle + reward stars (0–5).'
                : null),
      rows: [
        _hubRow(
          key: 'more-weekly',
          label: 'Weekly plan',
          val: '$planned of 7 planned',
          onTap: openWeeklyPlanScreen,
        ),
        if (!child) ...[
          _hubRow(
            key: 'more-calmanage',
            label: 'Categories',
            val: '$catCount badge${catCount == 1 ? '' : 's'}',
            onTap: openCategoriesScreen,
          ),
          _hubRow(
            key: 'more-memcolors',
            label: 'Member colours',
            sub: 'Each person’s identity colour',
            val: '$activeMembers member${activeMembers == 1 ? '' : 's'}',
            onTap: openMemberColoursScreen,
          ),
          _hubRow(
            key: 'more-calimports',
            label: 'Imported calendars',
            val: impCount == 0
                ? 'None yet'
                : (failing > 0 ? '$failing failing' : 'All synced'),
            warnVal: failing > 0,
            goodVal: impCount > 0 && failing == 0,
            onTap: openImportedCalendarsScreen,
          ),
        ],
        _hubRow(
          key: 'more-callayers',
          label: 'Calendar layers',
          sub: 'Appointments, to-dos & content',
          val: '$layersOn of ${calendarLayers.length} on',
          onTap: openCalendarLayersScreen,
        ),
        if (!child)
          _hubRow(
            key: 'more-kitchen-settings',
            label: 'Kitchen wall',
            sub: 'The shared tablet screen',
            val: kitchenEnabled ? '$visible of ${layers.length} layers' : 'Off',
            warnVal: !kitchenEnabled,
            onTap: openKitchenWallScreen,
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
          onTap: openWalletSubScreen,
        ),
        _hubRow(
          key: 'more-widget-privacy',
          label: 'Hide amounts on phone widgets',
          sub: 'Home-screen widgets show •••• instead',
          tog: widgetHideAmounts,
          onTog: toggleWidgetHideAmounts,
        ),
        // The Accounts row keeps the historical 'more-finsettings' key so
        // existing flows keep working.
        _hubRow(
          key: 'more-finsettings',
          label: 'Accounts',
          sub: 'Who pays from where',
          val: '${accounts.length} account${accounts.length == 1 ? '' : 's'}',
          onTap: openAccountsScreen,
        ),
        _hubRow(
          key: 'more-blocks',
          label: 'Budget blocks',
          sub: 'The columns of the monthly budget',
          val: '${cats.length} block${cats.length == 1 ? '' : 's'}',
          onTap: openBudgetBlocksScreen,
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
      hint: isChildUser
          ? 'Only family admins can change family settings.'
          : (owner ? null : 'Only owners can manage members.'),
      rows: [
        // The member list lives directly on the card (#330): avatar, role and
        // status per row. Tapping opens the family management page (#275).
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
            bg: m.status == 'invited'
                ? context.tc.pick(const Color(0xfffffdf5), context.tc.amberSoft)
                : null,
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
            onTap: openFamilyScreen,
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
    final me = curFamily()?.members.where((m) => m.id == myId).firstOrNull;
    // A login an admin gave this kid profile (Flow B): admins own it, so no
    // password reset or account deletion from here.
    final adminLogin = isChildUser && me?.loginMethod != null;
    final managed = adminLogin && (me?.managed ?? false);
    return _hubCard(
      id: 'account',
      icon: 'gear',
      title: 'Account',
      summary: '${_hubProviderLabel()} · ${u?.email ?? 'not signed in'}',
      rows: [
        if (managed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: kidNotice(
              '${adminNames()} can change your email or password.',
              key: const ValueKey('more-managed-notice'),
              title: 'Managed by your family admins',
              margin: EdgeInsets.zero,
            ),
          ),
        ValueListenableBuilder<int>(
          valueListenable: pendingChangesTick,
          builder: (context, _, _) {
            final n = unsavedChangeCount;
            final waiting = n > 0;
            final ink = waiting ? context.tc.amberText : context.tc.greenText;
            return _hubRow(
              key: 'hub-pending',
              label: 'Unsaved changes',
              sub: 'Review what hasn’t reached Thrive',
              lead: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: waiting ? context.tc.amberSoft : context.tc.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: unsavedChangesGlyph(
                  waiting ? context.tc.amberText : context.tc.deep,
                ),
              ),
              trail: Container(
                key: const ValueKey('hub-pending-pill'),
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: waiting ? context.tc.amberSoft : context.tc.greenSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: waiting
                        ? context.tc.amberLine
                        : context.tc.greenLine,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: ink,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      waiting ? '$n unsaved' : 'All saved',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: openPendingChangesScreen,
            );
          },
        ),
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
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, mode, _) => _hubRow(
            key: 'hub-appearance',
            label: 'Appearance',
            sub: 'This device only',
            val: themeModeLabel(mode),
            onTap: () => setThemeMode(
              ThemeMode.values[(mode.index + 1) % ThemeMode.values.length],
            ),
          ),
        ),
        _hubRow(
          key: 'hub-future-language',
          label: 'Language',
          pill: 'future',
          val: 'English (UK)',
          noChev: true,
          onTap: () => flash('Only English (UK) for now'),
        ),
        if (!adminLogin)
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
          sub: adminLogin
              ? 'You can sign in again any time'
              : (isChildUser
                    ? 'You stay in your family. Nothing is deleted.'
                    : 'You stay in your families — nothing is deleted'),
          danger: true,
          bg: context.tc.pick(const Color(0xfffef7f7), context.tc.redSoft),
          noChev: true,
          onTap: signOut,
        ),
        if (!adminLogin)
          _hubRow(
            key: 'more-delete-account',
            label: 'Delete account',
            sub: _deleteAccountConsequence(),
            danger: true,
            bg: context.tc.redSoft,
            noChev: true,
            onTap: openDeleteAccountSheet,
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
  Widget _hubHero({bool scrolled = false}) {
    final u = user;
    final identity = u == null ? null : profileAvatarIdentity(u);
    return Container(
      decoration: BoxDecoration(
        gradient: scrolled ? null : context.tc.grad,
        color: scrolled ? context.tc.surface : null,
      ),
      padding: const EdgeInsets.only(bottom: 24),
      child: AppHeader(
        hero: !scrolled,
        scrolled: scrolled,
        leading: AppHeaderLeading.photo,
        leadingKey: const ValueKey('more-profile'),
        onLeadingPressed: openProfileScreen,
        leadingWidget: KeyedSubtree(
          key: const ValueKey('profile-avatar'),
          child: avatarNode(
            photo: identity?.photo,
            initials: identity?.initials ?? '?',
            color: identity?.color,
            size: 40,
            radius: 12,
            fs: 15,
          ),
        ),
        title: u?.name ?? 'You',
        subtitle: '${_hubProviderLabel()} · ${u?.email ?? ''}',
        statusChip: netOffline.value ? _offlineHeaderChip() : null,
        actions: [
          AppHeaderAction(
            icon: 'bell',
            tooltip: 'Notifications',
            onPressed: () => flash('No new notifications'),
          ),
        ],
        toolbar: Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final fam in families) _hubFamilyPill(fam, scrolled: scrolled),
            _hubCreateOrJoinPill(scrolled: scrolled),
          ],
        ),
      ),
    );
  }

  Widget _hubFamilyPill(Family fam, {bool scrolled = false}) {
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
          color: current
              ? (scrolled ? context.tc.soft : Colors.white)
              : (scrolled
                    ? context.tc.faint
                    : Colors.white.withValues(alpha: .18)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${fam.name} · $n',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: current
                ? context.tc.deep
                : (scrolled ? context.tc.text : Colors.white),
          ),
        ),
      ),
    );
  }

  /// "＋ Create or join a family" entry alongside the switcher pills.
  Widget _hubCreateOrJoinPill({bool scrolled = false}) {
    return GestureDetector(
      key: const ValueKey('hub-fam-add'),
      onTap: openCreateOrJoinSheet,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: scrolled
              ? context.tc.faint
              : Colors.white.withValues(alpha: .12),
          border: Border.all(
            color: scrolled
                ? context.tc.line
                : Colors.white.withValues(alpha: .5),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '＋ Create or join a family',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: scrolled ? context.tc.text : Colors.white,
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
        color: context.tc.surface,
        border: Border.all(color: context.tc.line),
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
                      color: context.tc.soft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: ic(
                        icon,
                        size: 16,
                        sw: 2.2,
                        color: context.tc.primary,
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
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.tc.ink,
                          ),
                        ),
                        Text(
                          summary,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: context.tc.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.rotate(
                    angle: open ? math.pi : 0,
                    child: ic(
                      'down',
                      size: 15,
                      sw: 2.2,
                      color: context.tc.muted,
                    ),
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
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: context.tc.muted,
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
    Widget? lead,
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
            color: bg ?? context.tc.page,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 12)],
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
                        color: danger ? context.tc.red : context.tc.ink,
                      ),
                    ),
                    if (sub != null && sub.isNotEmpty)
                      Text(
                        sub,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: context.tc.pick(
                            const Color(0xff8a96a8),
                            context.tc.placeholder,
                          ),
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
                        ? context.tc.soft
                        : (pillKind == 'invited'
                              ? context.tc.amberSoft
                              : context.tc.pick(
                                  const Color(0xfff5f3ff),
                                  const Color(0xff241a3d),
                                )),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    pill.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                      color: pillKind == 'owner'
                          ? context.tc.deep
                          : (pillKind == 'invited'
                                ? context.tc.amberText
                                : context.tc.pick(
                                    const Color(0xff7c3aed),
                                    const Color(0xffc4b5fd),
                                  )),
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
                        ? context.tc.amberSoft
                        : (goodVal
                              ? context.tc.greenSoft
                              : context.tc.pick(
                                  const Color(0xffe8ecf2),
                                  context.tc.line,
                                )),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    val,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: warnVal
                          ? context.tc.amberText
                          : (goodVal ? context.tc.greenText : context.tc.soft2),
                    ),
                  ),
                ),
              ],
              if (onTap != null && !noChev && tog == null) ...[
                const SizedBox(width: 4),
                ic(
                  'cright',
                  size: 14,
                  sw: 2.2,
                  color: context.tc.pick(
                    const Color(0xffc2cad6),
                    context.tc.toggleOff,
                  ),
                ),
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
            color: on
                ? context.tc.primary
                : context.tc.pick(
                    const Color(0xffcfd6df),
                    context.tc.toggleOff,
                  ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- sheets
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
              openCreateFamilyScreen();
            },
          ),
          const SizedBox(height: 7),
          _sheetOptionRow(
            key: 'hub-join-family',
            title: 'Join a family',
            sub: 'With their username & password',
            onTap: () {
              Navigator.of(ctx).pop();
              openJoinFamilyScreen();
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
          color: context.tc.pick(const Color(0xfff8fafc), context.tc.rowOpen),
          border: Border.all(color: context.tc.line),
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.tc.ink,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: context.tc.pick(
                        const Color(0xff8a96a8),
                        context.tc.placeholder,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ic(
              'cright',
              size: 14,
              sw: 2.2,
              color: context.tc.pick(
                const Color(0xffc2cad6),
                context.tc.toggleOff,
              ),
            ),
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
                color: context.tc.primary,
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
