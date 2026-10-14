part of 'package:family_money_management_app/main.dart';

/// Settings → Notifications (#473, #483, #484; `Settings Notifications.dc.html`
/// §1–§3 and `NotificationsPhone.dc.html`): the permission card, the six
/// family-update types with their scope sheets, quiet hours and the
/// on-this-phone reminders.
extension _ThriveNotificationsScreen on _ThriveHomeState {
  void openNotificationsScreen() {
    unawaited(refreshNotifDevice());
    pushSettingsPage<void>(
      (_) => _NotificationsScreen(state: this, dark: context.tc.isDark),
    );
  }

  /// Hub value: what reaches this phone right now.
  String get notificationsHubValue => notifDevice.value.granted ? 'On' : 'Off';

  /// Type switch. A channel switched off in Android settings has to be
  /// fixed there first (2e).
  void toggleNotifType(String id) {
    final spec = notifTypeSpec(id);
    if (!notifDevice.value.channelOn(spec.channel)) {
      flash('Turn it on in Android settings first');
      return;
    }
    editNotifPrefs((p) {
      final t = p.type(id);
      t.on = !t.on;
      // Back on with nothing ticked would stay silent: restore the events.
      if (t.on && t.eventsOn == 0) {
        for (final e in spec.events) {
          t.events[e.key] = true;
        }
      }
    });
  }

  void setNotifScope(String id, String scope) =>
      editNotifPrefs((p) => p.type(id).scope = scope);

  void toggleNotifPick(String id, String memberId) => editNotifPrefs((p) {
    final t = p.type(id);
    t.pick = t.pick.contains(memberId)
        ? t.pick.where((m) => m != memberId).toList()
        : [...t.pick, memberId];
  });

  /// "Tell me when" checkbox; at least one stays ticked (§3).
  void toggleNotifEvent(String id, String key) {
    final t = notifPrefs.type(id);
    if (t.events[key] == true && t.eventsOn == 1) {
      flash('Keep one, or turn ${notifTypeSpec(id).label} off');
      return;
    }
    editNotifPrefs((p) {
      final e = p.type(id).events;
      e[key] = !(e[key] ?? false);
    });
  }

  void toggleQuietHours() => editNotifPrefs((p) => p.quiet.on = !p.quiet.on);

  void cycleQuietFrom() => editNotifPrefs((p) {
    final i = kQuietFromTimes.indexOf(p.quiet.from);
    p.quiet.from = kQuietFromTimes[(i + 1) % kQuietFromTimes.length];
  });

  void cycleQuietUntil() => editNotifPrefs((p) {
    final i = kQuietUntilTimes.indexOf(p.quiet.to);
    p.quiet.to = kQuietUntilTimes[(i + 1) % kQuietUntilTimes.length];
  });

  void toggleQuietDay(int i) =>
      editNotifPrefs((p) => p.quiet.days[i] = !p.quiet.days[i]);

  void toggleQuietLetReminders() =>
      editNotifPrefs((p) => p.quiet.letReminders = !p.quiet.letReminders);

  Future<void> sendTestNotification() async {
    if (!notifDevice.value.granted) {
      flash('Turn on notifications first');
      return;
    }
    final familyId = curFamily()?.id;
    if (familyId == null) return;
    try {
      await notifCallable('sendTestPush', {'familyId': familyId});
      flash('Test sent. Pull down to see it');
    } catch (_) {
      flash('Test could not be sent');
    }
  }

  /// The family types this user can get: kid accounts don't get Lists
  /// (#472) and the Echo wall waits for the Alexa wall (#460).
  List<NotifTypeSpec> get visibleNotifTypes => [
    for (final t in kNotifTypes)
      if (!(t.id == 'wall' && !kEchoWallLive) &&
          !(t.id == 'lists' && isChildUser))
        t,
  ];

  /// The grey hint under a scope option ("Liv and Leo", "3 lists", …).
  String notifScopeHint(String type, String scope) {
    final kids = notifKidMembers.map((m) => m.name).toList();
    switch ('$type/$scope') {
      case 'chores/kids' || 'money/kids' || 'wall/kids':
        return joinNames(kids);
      case 'cal/mine':
        final self = _memberById(notifSelfMemberId)?.name;
        return [?self, ...kids].join(', ');
      case 'lists/mine':
        final mine = _homeCurrentUserMemberIds();
        final n =
            taskLists
                .where(
                  (l) =>
                      mine.contains(l.createdBy) ||
                      l.tasks.any((t) => mine.contains(t.assignee)),
                )
                .length +
            shoppingLists.where((l) => mine.contains(l.createdBy)).length;
        return n == 1 ? '1 list' : '$n lists';
      case 'money/shared':
        return accounts.map((a) => a.name).join(', ');
    }
    return '';
  }

  /// The scope line's label: the option, or the picked people.
  String notifScopeLabel(String type) {
    final t = notifPrefs.type(type);
    if (t.scope == 'pick') {
      final names = [
        for (final m in notifMembers)
          if (t.pick.contains(m.id)) m.name,
      ];
      return names.isEmpty ? 'No one yet' : names.join(', ');
    }
    final spec = notifTypeSpec(type);
    return spec.scopes
        .firstWhere((o) => o.id == t.scope, orElse: () => spec.scopes.first)
        .label;
  }

  void openNotifScopeSheet(String type, {bool dark = false}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: (dark ? _NotifPalette.dark : _NotifPalette.light).ov,
      builder: (_) => _NotifScopeSheet(state: this, type: type, dark: dark),
    );
  }
}

/// The page's light/dark tokens (`NotificationsPhone.dc.html` `TH`). The
/// dark set is the Family Vault palette (2g, epic #426).
class _NotifPalette {
  const _NotifPalette({
    required this.bg,
    required this.row,
    required this.cd,
    required this.ln,
    required this.tk,
    required this.ink,
    required this.tx,
    required this.s2,
    required this.mu,
    required this.dp,
    required this.sf,
    required this.btn,
    required this.btnT,
    required this.red,
    required this.redS,
    required this.redL,
    required this.ambS,
    required this.ambT,
    required this.grnS,
    required this.grnT,
    required this.ov,
  });

  final Color bg, row, cd, ln, tk, ink, tx, s2, mu, dp, sf, btn, btnT;
  final Color red, redS, redL, ambS, ambT, grnS, grnT, ov;

  static const light = _NotifPalette(
    bg: Color(0xfff8fafc),
    row: Color(0xfff1f4f8),
    cd: Color(0xffffffff),
    ln: Color(0xffe7eaf0),
    tk: Color(0xffe8ecf2),
    ink: Color(0xff0f172a),
    tx: Color(0xff334155),
    s2: Color(0xff5b6676),
    mu: Color(0xff94a0b0),
    dp: Color(0xff0b7f74),
    sf: Color(0xffe4f4f1),
    btn: Color(0xff0b7f74),
    btnT: Color(0xffffffff),
    red: Color(0xffc42121),
    redS: Color(0xfffef2f2),
    redL: Color(0xfffecaca),
    ambS: Color(0xfffffbeb),
    ambT: Color(0xffb45309),
    grnS: Color(0xffe7f7ef),
    grnT: Color(0xff0b7a52),
    ov: Color(0x73101828),
  );

  static const dark = _NotifPalette(
    bg: Color(0xff0b1016),
    row: Color(0xff202b38),
    cd: Color(0xff141b24),
    ln: Color(0xff243040),
    tk: Color(0xff1f2a37),
    ink: Color(0xffeef2f7),
    tx: Color(0xffc7d0db),
    s2: Color(0xff9ba7b6),
    mu: Color(0xff6b788a),
    dp: Color(0xff62dacb),
    sf: Color(0xff10302d),
    btn: Color(0xff2cc2b1),
    btnT: Color(0xff04211d),
    red: Color(0xfff87171),
    redS: Color(0xff2b1417),
    redL: Color(0xff5c2428),
    ambS: Color(0xff2a2111),
    ambT: Color(0xfffcd34d),
    grnS: Color(0xff0f2b21),
    grnT: Color(0xff6ee7b7),
    ov: Color(0x9e000000),
  );
}

TextStyle _nt(double size, FontWeight w, Color c, {double? ls, double? h}) =>
    TextStyle(
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: ls,
      height: h,
    );

/// 42×25 switch in a 48×44 hit area (§1).
Widget _notifSwitch({
  required Key key,
  required bool on,
  required VoidCallback onTap,
  required _NotifPalette p,
  required String label,
}) => Semantics(
  label: label,
  toggled: on,
  button: true,
  child: GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      width: 48,
      height: 44,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 42,
          height: 25,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: on ? p.btn : p.mu,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
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
    ),
  ),
);

Widget _notifButton({
  required Key key,
  required String label,
  required VoidCallback onTap,
  required Color bg,
  required Color fg,
  Color? border,
}) => Semantics(
  button: true,
  label: label,
  excludeSemantics: true,
  child: GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Text(label, style: _nt(14, FontWeight.w800, fg)),
    ),
  ),
);

Widget _notifPill(String text, Color bg, Color fg, {double size = 10.5}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: _nt(size, FontWeight.w800, fg)),
    );

Widget _notifSectionLabel(String text, _NotifPalette p, {Widget? trailing}) =>
    Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(text, style: _nt(11, FontWeight.w800, p.s2, ls: .4)),
          ),
          ?trailing,
        ],
      ),
    );

Widget _notifNote(String text, _NotifPalette p, {bool center = false}) =>
    Padding(
      padding: EdgeInsets.fromLTRB(2, center ? 10 : 8, 2, 0),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: _nt(11, FontWeight.w600, p.s2, h: 1.45),
      ),
    );

class _NotificationsScreen extends StatelessWidget {
  const _NotificationsScreen({required this.state, this.dark = false});
  final _ThriveHomeState state;

  /// Dark variant (1b/2g); switches with app-wide dark mode (epic #426).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final p = dark ? _NotifPalette.dark : _NotifPalette.light;
    return ListenableBuilder(
      listenable: Listenable.merge([s._rev, s.notifDevice]),
      builder: (context, _) {
        final dev = s.notifDevice.value;
        final prefs = s.notifPrefs;
        return Scaffold(
          backgroundColor: p.bg,
          body: SafeArea(
            child: Column(
              children: [
                _header(context, p),
                Expanded(
                  child: ListView(
                    key: const ValueKey('notif-list'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    children: [
                      ..._permissionCard(dev, p),
                      _notifSectionLabel(
                        'FROM YOUR FAMILY',
                        p,
                        trailing: dev.granted
                            ? null
                            : _notifPill('Paused on this phone', p.tk, p.s2),
                      ),
                      for (final t in s.visibleNotifTypes) ...[
                        _typeRow(context, t, prefs, dev, p),
                        const SizedBox(height: 6),
                      ],
                      _notifNote(
                        dev.granted
                            ? 'Sent when someone else changes something. Tap '
                                  'a type to choose whose updates.'
                            : 'Your choices are saved to your account. They '
                                  'start on this phone once notifications '
                                  'are on.',
                        p,
                      ),
                      _notifSectionLabel('QUIET HOURS', p),
                      _quietCard(prefs.quiet, p),
                      if (prefs.quiet.on)
                        _notifNote(
                          'Family updates wait, then arrive as one summary '
                          'at ${prefs.quiet.to}. Android’s Do Not Disturb '
                          'still applies on top.',
                          p,
                        ),
                      _notifSectionLabel('ON THIS PHONE', p),
                      ..._phoneRows(dev, p),
                      const SizedBox(height: 20),
                      _notifButton(
                        key: const ValueKey('notif-test'),
                        label: 'Send a test notification',
                        onTap: () => unawaited(s.sendTestNotification()),
                        bg: p.cd,
                        fg: p.dp,
                        border: p.ln,
                      ),
                      _notifNote(
                        'You’re never notified about changes you made '
                        'yourself. These choices follow your account. '
                        'Android permission is set per phone.',
                        p,
                        center: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, _NotifPalette p) => Padding(
    padding: const EdgeInsets.fromLTRB(13, 8, 16, 12),
    child: Row(
      children: [
        Semantics(
          button: true,
          label: 'Back',
          child: GestureDetector(
            key: const ValueKey('studio-back'),
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: p.cd,
                    border: Border.all(color: p.ln),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: ic('cleft', size: 16, sw: 2.4, color: p.tx),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Notifications',
                style: _nt(17, FontWeight.w800, p.ink, ls: -.4),
              ),
              Text(
                'What reaches you on this phone',
                style: _nt(11, FontWeight.w600, p.s2),
              ),
            ],
          ),
        ),
        ListenableBuilder(
          listenable: Listenable.merge([state.syncStatus, state.netOffline]),
          builder: (context, _) {
            final status =
                state.syncStatus.value ??
                (state.netOffline.value ? SettingsSyncStatus.queued : null);
            return statusChipSwitcher(
              status == null
                  ? KeyedSubtree(
                      key: const ValueKey('notif-synced'),
                      child: _notifPill('Synced', p.grnS, p.grnT),
                    )
                  : settingsSyncPill(status),
            );
          },
        ),
      ],
    ),
  );

  Widget _card(_NotifPalette p, List<Widget> children) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: p.cd,
      border: Border.all(color: p.ln),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    ),
  );

  Widget _cardHead(
    _NotifPalette p, {
    required Widget icon,
    required Color iconBg,
    required String title,
    required String body,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: icon,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _nt(15, FontWeight.w800, p.ink, ls: -.2)),
            const SizedBox(height: 4),
            Text(body, style: _nt(12, FontWeight.w600, p.s2, h: 1.45)),
          ],
        ),
      ),
    ],
  );

  /// 2a / 2c / 2d.
  List<Widget> _permissionCard(NotifDeviceState dev, _NotifPalette p) {
    final s = state;
    switch (dev.permission) {
      case NotifPermission.granted:
        return const [];
      case NotifPermission.undecided:
        return [
          _card(p, [
            _cardHead(
              p,
              icon: ic('bell', size: 18, color: p.dp),
              iconBg: p.sf,
              title: 'Notifications are off for Thrive',
              body:
                  'Turn them on to hear when chores are done, the shopping '
                  'list changes or plans move. You pick what below.',
            ),
            _notifButton(
              key: const ValueKey('notif-perm-turn-on'),
              label: 'Turn on notifications',
              onTap: () => unawaited(s.askNotifPermission()),
              bg: p.btn,
              fg: p.btnT,
            ),
          ]),
        ];
      case NotifPermission.denied:
        return [
          _card(p, [
            _cardHead(
              p,
              icon: Text('!', style: _nt(18, FontWeight.w800, p.ambT)),
              iconBg: p.ambS,
              title: 'You chose “Don’t allow” last time',
              body:
                  'Android lets Thrive ask one more time. Without it, family '
                  'updates and your event reminders stay silent on this '
                  'phone.',
            ),
            Row(
              children: [
                Expanded(
                  child: _notifButton(
                    key: const ValueKey('notif-perm-not-now'),
                    label: 'Not now',
                    onTap: () =>
                        s.flash('OK. You can turn them on here any time'),
                    bg: p.row,
                    fg: p.tx,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _notifButton(
                    key: const ValueKey('notif-perm-ask-again'),
                    label: 'Ask again',
                    onTap: () => unawaited(s.askNotifPermission()),
                    bg: p.btn,
                    fg: p.btnT,
                  ),
                ),
              ],
            ),
          ]),
        ];
      case NotifPermission.blocked:
        const steps = [
          'Tap Open Android settings',
          'Tap Notifications',
          'Turn on “All Thrive notifications”',
        ];
        return [
          _card(p, [
            _cardHead(
              p,
              icon: ic('bell', size: 18, color: p.red),
              iconBg: p.redS,
              title: 'Notifications are blocked',
              body:
                  'Android won’t show the question again, so this needs a '
                  'quick trip to Android settings. Your choices below are '
                  'saved and start working straight away.',
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: p.row,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.cd,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: _nt(11.5, FontWeight.w800, p.dp),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              steps[i],
                              style: _nt(12.5, FontWeight.w700, p.tx),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _notifButton(
              key: const ValueKey('notif-perm-open-settings'),
              label: 'Open Android settings',
              onTap: () =>
                  unawaited(NotificationService.openSystemSettings('app')),
              bg: p.btn,
              fg: p.btnT,
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              child: Text(
                'Thrive checks again when you come back.',
                textAlign: TextAlign.center,
                style: _nt(11.5, FontWeight.w600, p.s2),
              ),
            ),
          ]),
        ];
    }
  }

  static const Map<String, String> _typeIcons = {
    'chores': 'check',
    'lists': 'cart',
    'cal': 'cal',
    'money': 'wallet',
    'wall': 'display',
    'family': 'users',
  };

  Widget _typeRow(
    BuildContext context,
    NotifTypeSpec t,
    NotifPrefs prefs,
    NotifDeviceState dev,
    _NotifPalette p,
  ) {
    final s = state;
    final v = prefs.type(t.id);
    final chOff = !dev.channelOn(t.channel);
    final on = v.on && !chOff;
    final lit = on && dev.granted;
    final op = dev.granted ? 1.0 : .6;
    final evLabel = v.eventsOn == t.events.length
        ? 'All updates'
        : '${v.eventsOn} of ${t.events.length}';
    return Container(
      key: ValueKey('notif-row-${t.id}'),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: p.row,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: lit ? p.sf : p.tk,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: ic(
                    _typeIcons[t.id]!,
                    size: 17,
                    color: lit ? p.dp : p.s2,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Opacity(
                    opacity: op,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.label, style: _nt(13, FontWeight.w800, p.ink)),
                        Text(
                          t.sub,
                          style: _nt(11, FontWeight.w600, p.s2, h: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
                _notifSwitch(
                  key: ValueKey('notif-type-${t.id}'),
                  on: on,
                  onTap: () => s.toggleNotifType(t.id),
                  p: p,
                  label: t.label,
                ),
              ],
            ),
          ),
          if (on)
            Semantics(
              button: true,
              label: 'Choose ${t.label}',
              child: GestureDetector(
                key: ValueKey('notif-scope-${t.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => s.openNotifScopeSheet(t.id, dark: dark),
                child: Opacity(
                  opacity: op,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    margin: const EdgeInsets.fromLTRB(32, 0, 4, 4),
                    padding: const EdgeInsets.fromLTRB(12, 0, 10, 0),
                    decoration: BoxDecoration(
                      color: p.cd,
                      border: Border.all(color: p.ln),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.notifScopeLabel(t.id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _nt(12, FontWeight.w800, p.tx),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(evLabel, style: _nt(11, FontWeight.w700, p.s2)),
                        const SizedBox(width: 8),
                        ic('cright', size: 14, sw: 2.4, color: p.mu),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (chOff)
            Container(
              key: ValueKey('notif-chan-off-${t.id}'),
              constraints: const BoxConstraints(minHeight: 44),
              margin: const EdgeInsets.fromLTRB(32, 0, 4, 4),
              padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
              decoration: BoxDecoration(
                color: p.redS,
                border: Border.all(color: p.redL),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Turned off in Android settings',
                      style: _nt(11.5, FontWeight.w700, p.red, h: 1.35),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Fix in Android settings',
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: ValueKey('notif-fix-${t.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => unawaited(
                        NotificationService.openSystemSettings(
                          'channel',
                          channel: t.channel,
                        ),
                      ),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 40),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        child: Text(
                          'Fix',
                          style: _nt(12, FontWeight.w800, p.red),
                        ),
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

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Widget _timeBox(
    Key key,
    String label,
    String time,
    String aria,
    VoidCallback onTap,
    _NotifPalette p,
  ) => Semantics(
    button: true,
    label: aria,
    child: GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: p.cd,
          border: Border.all(color: p.ln),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: _nt(10.5, FontWeight.w800, p.s2, ls: .3)),
            Text(
              time,
              style: _nt(
                19,
                FontWeight.w800,
                p.ink,
                ls: -.3,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _quietCard(NotifQuietPrefs q, _NotifPalette p) {
    final s = state;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: p.row,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiet hours',
                        style: _nt(13, FontWeight.w800, p.ink),
                      ),
                      Text(
                        q.summary,
                        key: const ValueKey('notif-quiet-sub'),
                        style: _nt(11, FontWeight.w600, p.s2),
                      ),
                    ],
                  ),
                ),
                _notifSwitch(
                  key: const ValueKey('notif-quiet'),
                  on: q.on,
                  onTap: s.toggleQuietHours,
                  p: p,
                  label: 'Quiet hours',
                ),
              ],
            ),
          ),
          if (q.on)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _timeBox(
                          const ValueKey('notif-quiet-from'),
                          'FROM',
                          q.from,
                          'Quiet from',
                          s.cycleQuietFrom,
                          p,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _timeBox(
                          const ValueKey('notif-quiet-to'),
                          'UNTIL',
                          q.to,
                          'Quiet until',
                          s.cycleQuietUntil,
                          p,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Semantics(
                          button: true,
                          selected: q.days[i],
                          label: _dayNames[i],
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: ValueKey('notif-day-$i'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => s.toggleQuietDay(i),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: q.days[i] ? p.sf : p.cd,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: q.days[i] ? p.dp : p.ln,
                                    ),
                                  ),
                                  child: Text(
                                    _dayLetters[i],
                                    style: _nt(
                                      12,
                                      FontWeight.w800,
                                      q.days[i] ? p.dp : p.s2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: p.ln)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Let my event reminders through',
                                style: _nt(12.5, FontWeight.w800, p.ink),
                              ),
                              Text(
                                'Reminders you set still ring',
                                style: _nt(11, FontWeight.w600, p.s2),
                              ),
                            ],
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(4, 0),
                          child: _notifSwitch(
                            key: const ValueKey('notif-quiet-let'),
                            on: q.letReminders,
                            onTap: s.toggleQuietLetReminders,
                            p: p,
                            label: 'Let event reminders through',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _phoneRow(
    _NotifPalette p, {
    required String title,
    required String sub,
    required Widget trailing,
    double opacity = 1,
    EdgeInsets padding = const EdgeInsets.fromLTRB(12, 8, 4, 8),
  }) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    padding: padding,
    decoration: BoxDecoration(
      color: p.row,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Opacity(
            opacity: opacity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _nt(13, FontWeight.w800, p.ink)),
                Text(sub, style: _nt(11, FontWeight.w600, p.s2)),
              ],
            ),
          ),
        ),
        trailing,
      ],
    ),
  );

  List<Widget> _phoneRows(NotifDeviceState dev, _NotifPalette p) {
    final s = state;
    return [
      _phoneRow(
        p,
        title: 'Event reminders',
        sub: 'The reminders you set on events. Sent through the cloud.',
        opacity: dev.granted ? 1 : .6,
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        trailing: _notifSwitch(
          key: const ValueKey('notif-reminders'),
          on: s.notificationsEnabled,
          onTap: s.toggleNotificationsEnabled,
          p: p,
          label: 'Event reminders',
        ),
      ),
      const SizedBox(height: 6),
      _phoneRow(
        p,
        title: 'New events remind me',
        sub: 'Can be changed per event',
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _notifPill('1 hour before', p.tk, p.s2, size: 11),
            const SizedBox(width: 10),
            ic('cright', size: 14, sw: 2.4, color: p.mu),
          ],
        ),
      ),
      const SizedBox(height: 6),
    ];
  }
}

/// "Whose updates" sheet (§3): who, the picked people, and which events.
class _NotifScopeSheet extends StatelessWidget {
  const _NotifScopeSheet({
    required this.state,
    required this.type,
    this.dark = false,
  });
  final _ThriveHomeState state;
  final String type;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final p = dark ? _NotifPalette.dark : _NotifPalette.light;
    final spec = notifTypeSpec(type);
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) {
        final v = s.notifPrefs.type(type);
        final selfId = s.notifSelfMemberId;
        // Kid accounts follow their own items only (#472): no "who" choice.
        final showWho = !s.isChildUser;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .92,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: p.cd,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.fromLTRB(0, 2, 0, 8),
                        decoration: BoxDecoration(
                          color: p.mu.withValues(alpha: .5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      spec.label,
                      style: _nt(17, FontWeight.w800, p.ink, ls: -.3),
                    ),
                    if (showWho) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
                        child: Text(
                          spec.whoTitle,
                          style: _nt(11, FontWeight.w800, p.s2, ls: .4),
                        ),
                      ),
                      for (final o in spec.scopes) ...[
                        _option(o, v.scope == o.id, p),
                        const SizedBox(height: 6),
                      ],
                      if (v.scope == 'pick')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 2, 0, 0),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final m in s.notifMembers)
                                _memberChip(
                                  m,
                                  m.id == selfId ? 'Me' : m.name,
                                  v.pick.contains(m.id),
                                  p,
                                ),
                            ],
                          ),
                        ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 16, 2, 6),
                      child: Text(
                        'TELL ME WHEN',
                        style: _nt(11, FontWeight.w800, p.s2, ls: .4),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ColoredBox(
                        color: p.row,
                        child: Column(
                          children: [
                            for (var i = 0; i < spec.events.length; i++)
                              _eventRow(
                                spec.events[i],
                                v.events[spec.events[i].key] == true,
                                i > 0,
                                p,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _notifButton(
                      key: const ValueKey('notif-sheet-done'),
                      label: 'Done',
                      onTap: () => Navigator.of(context).pop(),
                      bg: p.btn,
                      fg: p.btnT,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _option(NotifScopeSpec o, bool on, _NotifPalette p) {
    final hint = state.notifScopeHint(type, o.id);
    return Semantics(
      button: true,
      selected: on,
      label: o.label,
      child: GestureDetector(
        key: ValueKey('notif-opt-${o.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => state.setNotifScope(type, o.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? p.sf : p.row,
            border: Border.all(
              color: on ? p.dp : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: on ? p.dp : p.mu, width: 2),
                ),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? p.dp : Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.label, style: _nt(13, FontWeight.w800, p.ink)),
                    if (hint.isNotEmpty)
                      Text(hint, style: _nt(11, FontWeight.w600, p.s2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberChip(FamilyMember m, String name, bool on, _NotifPalette p) =>
      Semantics(
        button: true,
        selected: on,
        label: name,
        excludeSemantics: true,
        child: GestureDetector(
          key: ValueKey('notif-pick-${m.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => state.toggleNotifPick(type, m.id),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
            decoration: BoxDecoration(
              color: on ? p.sf : p.row,
              border: Border.all(
                color: on ? p.dp : Colors.transparent,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: on ? 1 : .45,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: m.color,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      m.initials,
                      style: _nt(10.5, FontWeight.w800, Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(name, style: _nt(12.5, FontWeight.w800, on ? p.dp : p.tx)),
              ],
            ),
          ),
        ),
      );

  Widget _eventRow(NotifEventSpec e, bool on, bool divider, _NotifPalette p) =>
      Semantics(
        button: true,
        checked: on,
        label: e.label,
        child: GestureDetector(
          key: ValueKey('notif-ev-${e.key}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => state.toggleNotifEvent(type, e.key),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: divider ? p.ln : Colors.transparent),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? p.btn : Colors.transparent,
                    border: Border.all(color: on ? p.btn : p.mu, width: 2),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: on
                      ? ic('check', size: 13, sw: 3, color: p.btnT)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(e.label, style: _nt(13, FontWeight.w700, p.ink)),
                ),
                if (e.hint.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      e.hint,
                      textAlign: TextAlign.right,
                      style: _nt(11, FontWeight.w600, p.s2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}
