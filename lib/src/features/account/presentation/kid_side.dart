part of 'package:family_money_management_app/main.dart';

/// Kid accounts, kid side (`Kid Accounts.dc.html` screens 5 and 14–16):
/// the one-time access-change notice, "Signing you in…" while a linked
/// Google account is claimed, the welcome + first-run cards, and the
/// full-screen errors (Google not linked, login removed, signed out by an
/// admin).

enum KidGateKind { signingIn, welcome, firstRun, notLinked, removed, signedOut }

class KidGate {
  const KidGate(
    this.kind, {
    this.name = '',
    this.familyName = '',
    this.admins = 'a family admin',
    this.email = '',
    this.signOutOnClose = false,
  });
  final KidGateKind kind;
  final String name;
  final String familyName;
  final String admins;
  final String email;

  /// Close the screen by signing out (a managed login that no longer works).
  final bool signOutOnClose;
}

String _kidPrefKey(String what, String id) => 'kid_${what}_$id';

extension _ThriveKidSide on _ThriveHomeState {
  FamilyMember? get _myRow =>
      curFamily()?.members.where((m) => m.id == myId).firstOrNull;

  String _familyDisplayName(String name) {
    final n = name.trim();
    if (n.isEmpty) return 'your family';
    return n.toLowerCase().endsWith('family') ? 'the $n' : 'the $n family';
  }

  /// After the sign-in cloud load: claim a Google link an admin made, show
  /// the kid welcome once, or the "login removed" notice.
  Future<void> _kidAfterSignIn() async {
    final uid = _firebaseUid();
    if (uid == null) return;
    // coverage:ignore-start
    if (families.isEmpty && user?.provider == 'google') {
      kidGate.value = const KidGate(KidGateKind.signingIn);
      final fid = await claimKidLink();
      if (fid != null) {
        try {
          await cloudBoot(uid);
        } catch (e) {
          debugPrint('[kids] reload after claim failed: $e');
        }
      }
      kidGate.value = null;
    }
    if (families.isEmpty) {
      await _kidCheckRemovedLogin(uid);
      return;
    }
    await _maybeKidWelcome(uid);
    // coverage:ignore-end
  }

  /// Shows the welcome once per login, for logins an admin made.
  Future<void> _maybeKidWelcome(String uid) async {
    final me = _myRow;
    if (!amIKidProfile() || me == null || me.loginMethod == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kidPrefKey('welcome', uid)) ?? false) return;
    kidGate.value = KidGate(
      KidGateKind.welcome,
      name: firstNameOf(me.name),
      familyName: curFamily()?.name ?? '',
    );
  }

  /// A Google kid whose login an admin removed while they were away.
  // coverage:ignore-start
  Future<void> _kidCheckRemovedLogin(String uid) async {
    try {
      final snap = await _userDocRef(uid).get().timeout(kCloudOpTimeout);
      final removed = snap.data()?['removedLogin'];
      if (removed is! Map) return;
      kidGate.value = KidGate(
        KidGateKind.removed,
        familyName: (removed['familyName'] ?? '').toString(),
      );
      await _userDocRef(
        uid,
      ).update({'removedLogin': FieldValue.delete()}).timeout(kCloudOpTimeout);
    } catch (e) {
      debugPrint('[kids] removed-login check failed: $e');
    }
  }
  // coverage:ignore-end

  /// Called before a family is dropped: a kid losing it means an admin
  /// removed their login.
  void _noteKidFamilyDropped(String fid) {
    if (!_kidMemberIdByFid.containsKey(fid)) return;
    final f = families.where((x) => x.id == fid).firstOrNull;
    final me = f?.members.where((m) => m.id == myId).firstOrNull;
    kidGate.value = KidGate(
      KidGateKind.removed,
      familyName: f?.name ?? '',
      admins: f == null ? 'a family admin' : adminNames(f),
      signOutOnClose: me?.managed ?? false,
    );
  }

  /// Per-frame kid checks once the shell is up: signed out by an admin, and
  /// the one-time access-change notice.
  void _kidShellChecks() {
    if (kidGate.value != null || user == null) return;
    final me = _myRow;
    if (me == null) return;
    // coverage:ignore-start
    if (_cloudBacked && me.signedOutAt != null) {
      final signedIn = FirebaseAuth
          .instance
          .currentUser
          ?.metadata
          .lastSignInTime
          ?.millisecondsSinceEpoch;
      if (signedIn != null && me.signedOutAt! > signedIn) {
        kidGate.value = KidGate(
          KidGateKind.signedOut,
          familyName: curFamily()?.name ?? '',
        );
        unawaited(Future<void>.microtask(signOut));
        return;
      }
    }
    // coverage:ignore-end
    final change = me.accessChange;
    if (change == null || change['byId'] == myId) return;
    final at = change['at'];
    if (at is! num || _accessNoticeShownAt == at.toInt()) return;
    _accessNoticeShownAt = at.toInt();
    unawaited(_maybeShowAccessNotice(me, change));
  }

  Future<void> _maybeShowAccessNotice(
    FamilyMember me,
    Map<String, dynamic> change,
  ) async {
    final key = _kidPrefKey('access', '${_firebaseUid() ?? myId}_$familyId');
    final at = (change['at'] as num).toInt();
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getInt(key) ?? 0) >= at) return;
    await prefs.setInt(key, at);
    if (!mounted) return;
    final ctx = context;
    if (!ctx.mounted) return;
    await _showAccessNoticeSheet(
      ctx,
      toKid: change['to'] == 'kid',
      by: (change['by'] ?? 'An admin').toString(),
    );
  }

  Future<void> _showAccessNoticeSheet(
    BuildContext context, {
    required bool toKid,
    required String by,
  }) {
    Widget item(String icon, String title, String sub, {bool off = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: off ? context.tc.faint : context.tc.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: ic(
                    icon,
                    size: 15,
                    sw: 2.2,
                    color: off ? context.tc.muted : context.tc.deep,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: off ? context.tc.muted : context.tc.ink,
                        decoration: off ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: context.tc.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    return showKidSheet<void>(
      context,
      builder: (ctx, _) => Column(
        key: const ValueKey('kid-access-notice'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kidSheetTitle(
            toKid
                ? '$by changed your account to a kid account'
                : '$by made you a full member',
            toKid
                ? 'Here’s what you can use now.'
                : 'You can use all of Thrive again.',
          ),
          if (toKid) ...[
            item('cal', 'Calendar', 'Events you’re in or made'),
            item('list', 'Lists', 'Lists you made'),
            item(
              'cup',
              'Meal plan',
              'See what’s cooking. Grown-ups make changes.',
            ),
            const SizedBox(height: 6),
            kidNotice(
              'Money, discount cards, the kitchen wall and family settings '
              'are hidden now. Questions? Ask $by.',
              tone: KidTone.grey,
              icon: 'lock',
              margin: const EdgeInsets.only(bottom: 12),
            ),
          ] else ...[
            item('wallet', 'Money', 'Budgets and accounts'),
            item('card', 'Discount cards', 'The family Wallet'),
            item('display', 'Kitchen wall', 'Everyone’s events and lists'),
            item('cup', 'Meal plan', 'Plan and edit meals'),
            const SizedBox(height: 12),
          ],
          kidButton(
            key: const ValueKey('kid-access-notice-ok'),
            label: toKid ? 'Got it' : 'Take a look',
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  /// Advances / closes the current kid screen.
  Future<void> _kidGateNext() async {
    final g = kidGate.value;
    if (g == null) return;
    switch (g.kind) {
      case KidGateKind.welcome:
        kidGate.value = KidGate(
          KidGateKind.firstRun,
          name: g.name,
          familyName: g.familyName,
        );
      case KidGateKind.firstRun:
        kidGate.value = null;
        final uid = _firebaseUid() ?? myId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kidPrefKey('welcome', uid), true);
        if (mounted) goTab('calendar');
      case KidGateKind.removed:
        kidGate.value = null;
        if (g.signOutOnClose && user != null) await signOut();
      case KidGateKind.notLinked:
      case KidGateKind.signedOut:
      case KidGateKind.signingIn:
        kidGate.value = null;
    }
  }
}

/// The full-screen kid gate (signing in, welcome, first run, errors).
class _KidGateScreen extends StatefulWidget {
  const _KidGateScreen({super.key, required this.state, required this.gate});
  final _ThriveHomeState state;
  final KidGate gate;

  @override
  State<_KidGateScreen> createState() => _KidGateScreenState();
}

class _KidGateScreenState extends State<_KidGateScreen> {
  int _page = 0;

  _ThriveHomeState get s => widget.state;
  KidGate get g => widget.gate;

  Widget _tile(String icon, {KidTone tone = KidTone.teal}) {
    final c = _kidToneColors(tone);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(child: ic(icon, size: 28, sw: 2, color: c.fg)),
    );
  }

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(
      t,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -.5,
        color: context.tc.ink,
      ),
    ),
  );

  Widget _body(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      t,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.tc.muted,
        height: 1.4,
      ),
    ),
  );

  Widget _frame(List<Widget> children, List<Widget> buttons) {
    return Material(
      color: context.tc.page,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: children,
                        ),
                      ),
                    ),
                  ),
                  ...buttons,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcome() {
    final me = s._myRow;
    final fam = s._familyDisplayName(g.familyName);
    final lists = s.visibleTaskLists.length + s.visibleShoppingLists.length;
    final events = s.events.where(s.childSeesEvent).length;
    Widget stat(String n, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: context.tc.surface,
          border: Border.all(color: context.tc.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              n,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.tc.ink,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: context.tc.muted,
              ),
            ),
          ],
        ),
      ),
    );
    return _frame(
      [
        if (me != null)
          s.avatarNode(
            photo: me.photo,
            emoji: me.emoji,
            initials: me.initials,
            color: me.color,
            size: 84,
            radius: 42,
            fs: 30,
          ),
        _title('Welcome, ${g.name}!'),
        _body('You’re in $fam.'),
        const SizedBox(height: 18),
        studioSectionLabel('Waiting for you'),
        Row(
          children: [
            stat('$events', events == 1 ? 'event' : 'events'),
            stat('$lists', lists == 1 ? 'list' : 'lists'),
          ],
        ),
      ],
      [
        kidButton(
          key: const ValueKey('kid-welcome-go'),
          label: 'Let’s go',
          onTap: s._kidGateNext,
        ),
      ],
    );
  }

  static const _firstRun = [
    (
      'cal',
      'Your calendar',
      'Everything you’re in, plus events you add yourself.',
      false,
    ),
    (
      'list',
      'Your lists',
      'Homework, birthday wishes, packing for camp. Make a list for '
          'anything.',
      false,
    ),
    (
      'cup',
      'What’s for dinner',
      'See the family meal plan for the week. Grown-ups make the changes.',
      true,
    ),
  ];

  Widget _firstRunPage() {
    final wide = _kidWide(context);
    Widget card(int i) {
      final (icon, title, body, ro) = _firstRun[i];
      return Container(
        key: ValueKey('kid-firstrun-$i'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.tc.surface,
          border: Border.all(color: context.tc.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tile(icon),
            _title(title),
            _body(body),
            if (ro) ...[
              const SizedBox(height: 8),
              kidPill('Read-only', tone: KidTone.amber),
            ],
          ],
        ),
      );
    }

    if (wide) {
      return Material(
        color: context.tc.page,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: card(i),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 320,
                      child: kidButton(
                        key: const ValueKey('kid-firstrun-done'),
                        label: 'Start using Thrive',
                        onTap: s._kidGateNext,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final last = _page == _firstRun.length - 1;
    return _frame(
      [
        card(_page),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _firstRun.length; i++)
              Container(
                width: i == _page ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _page ? context.tc.primary : context.tc.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
      [
        kidButton(
          key: ValueKey(last ? 'kid-firstrun-done' : 'kid-firstrun-next'),
          label: last ? 'Start using Thrive' : 'Next',
          onTap: last ? s._kidGateNext : () => setState(() => _page++),
        ),
        if (_page > 0 || !last)
          GestureDetector(
            key: ValueKey(
              _page == 0 ? 'kid-firstrun-skip' : 'kid-firstrun-back',
            ),
            behavior: HitTestBehavior.opaque,
            onTap: _page == 0 ? s._kidGateNext : () => setState(() => _page--),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 2),
              child: Text(
                _page == 0 ? 'Skip' : 'Back',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: context.tc.soft2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fam = s._familyDisplayName(g.familyName);
    switch (g.kind) {
      case KidGateKind.signingIn:
        return _frame([
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: context.tc.primary,
            ),
          ),
          _title('Signing you in…'),
          _body('Finding your profile in your family.'),
        ], const []);
      case KidGateKind.welcome:
        return _welcome();
      case KidGateKind.firstRun:
        return _firstRunPage();
      case KidGateKind.notLinked:
        return _frame(
          [
            _tile('lock', tone: KidTone.amber),
            _title('This Google account isn’t linked'),
            _body(
              '${g.email.isEmpty ? 'This account' : g.email} isn’t linked to '
              'a kid profile in any family.',
            ),
            _body(
              'Want to use this account? Ask a parent to link it in '
              'Thrive.',
            ),
          ],
          [
            kidButton(
              key: const ValueKey('kid-gate-other-google'),
              label: 'Use another Google account',
              onTap: () async {
                await s._kidGateNext();
                s.signOut();
              },
            ),
            const SizedBox(height: 8),
            kidButton(
              key: const ValueKey('kid-gate-join'),
              label: 'Join a family instead',
              secondary: true,
              onTap: s._kidGateNext,
            ),
          ],
        );
      case KidGateKind.removed:
        return _frame(
          [
            _tile('lock', tone: KidTone.red),
            _title('Your login was removed by a family admin'),
            _body(
              'Your profile and stars are still in $fam. Ask ${g.admins} if '
              'you want to sign in again.',
            ),
          ],
          [
            kidButton(
              key: const ValueKey('kid-gate-ok'),
              label: 'OK',
              onTap: s._kidGateNext,
            ),
          ],
        );
      case KidGateKind.signedOut:
        return _frame(
          [
            _tile('unlock', tone: KidTone.amber),
            _title('You were signed out by a family admin'),
            _body(
              'This happened on all your devices. Sign in again with your '
              'email and password.',
            ),
          ],
          [
            kidButton(
              key: const ValueKey('kid-gate-ok'),
              label: 'OK',
              onTap: s._kidGateNext,
            ),
          ],
        );
    }
  }
}
