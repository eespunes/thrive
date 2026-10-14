part of 'package:family_money_management_app/main.dart';

/// Kid accounts, admin side (`Kid Accounts.dc.html` screens 3–4 and 6–13):
/// access confirm sheets, login method sheet, email & password setup, the
/// one-time credentials handoff, Google setup, and the admin-managed login
/// card with its actions.

// ------------------------------------------------------ 3–4 access confirm

/// Confirms a Kid on/off change (applies on confirm, not on Save member).
/// Resolves to the user-facing error, or null when it saved / was cancelled.
Future<String?> _showKidAccessConfirm(
  BuildContext context,
  _ThriveHomeState s,
  FamilyMember m,
  bool toKid,
) async {
  final first = firstNameOf(m.name);
  String? error;
  var busy = false;
  await showKidSheet<void>(
    context,
    builder: (ctx, setSheet) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (toKid) ...[
          kidSheetTitle(
            'Make $first a kid account?',
            '$first keeps their account and everything they made. Their '
                'access gets smaller right away.',
          ),
          kidConsequenceList('$first will lose', const [
            'Money tab',
            'Discount cards',
            'Kitchen wall',
            'Family settings',
            'Other people’s events and lists',
            'Editing the meal plan',
          ], kind: ConsequenceKind.lose),
          kidConsequenceList('$first keeps', const [
            'Events they’re in or created',
            'Lists they created',
            'The meal plan, read-only',
          ]),
          if (m.hasLogin || !s._cloudBacked)
            kidNotice(
              '$first sees a notice next time they open Thrive. You can '
              'undo this any time.',
              margin: const EdgeInsets.only(bottom: 12),
            ),
        ] else ...[
          kidSheetTitle(
            'Make $first a full member?',
            '$first gets the same access as other members. $first won’t '
                'become an admin.',
          ),
          kidConsequenceList('$first gets', const [
            'Money tab',
            'Discount cards',
            'Kitchen wall',
            'Everyone’s events and lists',
            'Editing the meal plan',
          ], kind: ConsequenceKind.gets),
          if (m.hasLogin || !s._cloudBacked)
            kidNotice(
              '$first sees a notice next time they open Thrive.',
              margin: const EdgeInsets.only(bottom: 12),
            ),
        ],
        kidButton(
          key: const ValueKey('kid-access-confirm'),
          label: toKid ? 'Make kid account' : 'Make full member',
          busyLabel: toKid ? 'Making kid account…' : 'Making full member…',
          busy: busy,
          onTap: () async {
            setSheet(() => busy = true);
            error = await s.setKidAccess(m.id, toKid);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
        ),
        if (!busy) kidCancelLink(ctx),
      ],
    ),
    dismissible: true,
  );
  return error;
}

// -------------------------------------------------------- 7 method sheet

/// "How will Liv sign in?" → `'email'` or `'google'` (null when cancelled).
Future<String?> showLoginMethodSheet(BuildContext context, FamilyMember m) {
  final first = firstNameOf(m.name);
  Widget option({
    required String id,
    required String title,
    required String text,
    required String tag,
    required Widget icon,
    required BuildContext ctx,
  }) => GestureDetector(
    key: ValueKey('kid-method-$id'),
    behavior: HitTestBehavior.opaque,
    onTap: () => Navigator.of(ctx).pop(id),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.tc.surface,
        border: Border.all(color: context.tc.line, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.tc.soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: icon),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.tc.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.tc.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                kidPill(tag, tone: KidTone.teal),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return showKidSheet<String>(
    context,
    builder: (ctx, _) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        kidSheetTitle(
          'How will $first sign in?',
          'You can switch methods later.',
        ),
        option(
          id: 'email',
          ctx: ctx,
          title: 'Email & password',
          text:
              'You create and manage $first’s login. Good for younger kids '
              'without their own email.',
          tag: 'Managed by admins',
          icon: ic('lock', size: 17, sw: 2.2, color: context.tc.deep),
        ),
        option(
          id: 'google',
          ctx: ctx,
          title: 'Google account',
          text: '$first signs in with their own Google account.',
          tag: 'Needs a Google account',
          icon: _googleLogo(size: 18),
        ),
        kidCancelLink(ctx),
      ],
    ),
  );
}

// ----------------------------------------------------------- error copy

/// Maps a callable error to the email field's inline error (null → show the
/// generic connection notice instead).
String? kidEmailError(KidLoginError e, String first, {bool google = false}) {
  if (e.code == 'invalid-argument' && e.reason == 'email') {
    return google
        ? 'Enter a valid email, like name@gmail.com.'
        : 'Enter a valid email, like name@example.com.';
  }
  if (e.code == 'already-exists' && e.reason == 'member') {
    final other = firstNameOf(e.memberName ?? '');
    final who = other.isEmpty ? 'Someone in your family' : other;
    return google
        ? 'This Google account is already linked to $who.'
        : '$who already signs in with this email. Use a different one.';
  }
  if (e.code == 'already-exists') {
    return google
        ? 'This Google account already uses Thrive. Use another one, or have '
              '$first join the family with it and turn on Kid.'
        : 'This email already has a Thrive account. Use another one, or ask '
              'its owner to join your family with it.';
  }
  return null;
}

const String kKidWeakPassword =
    'Too weak. Use 10 or more characters, or tap Generate.';

/// The page chrome shared by the setup screens (back header + scroll body
/// + pinned primary button).
class _KidSetupPage extends StatelessWidget {
  const _KidSetupPage({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.footer,
    this.onBack,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget footer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tc.pick(
        const Color(0xfff8fafc),
        context.tc.rowOpen,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                AppHeader(
                  title: title,
                  subtitle: subtitle,
                  leading: AppHeaderLeading.back,
                  leadingKey: const ValueKey('studio-back'),
                  onLeadingPressed:
                      onBack ?? () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: children,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: footer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _kidMemberHeader(_ThriveHomeState s, FamilyMember m, String sub) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: ThriveColors.current.surface,
      border: Border.all(color: ThriveColors.current.line),
      borderRadius: BorderRadius.circular(14),
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
          fs: 13,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ThriveColors.current.ink,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: ThriveColors.current.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _kidEmailInput(
  TextEditingController c,
  String hint, {
  Key key = const ValueKey('kid-email'),
  bool error = false,
  VoidCallback? onChanged,
}) => Container(
  decoration: BoxDecoration(
    color: ThriveColors.current.page,
    border: Border.all(
      color: error ? ThriveColors.current.red : ThriveColors.current.line,
    ),
    borderRadius: BorderRadius.circular(12),
  ),
  child: TextField(
    key: key,
    controller: c,
    keyboardType: TextInputType.emailAddress,
    autocorrect: false,
    onChanged: (_) => onChanged?.call(),
    style: TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: ThriveColors.current.ink,
    ),
    decoration: InputDecoration(
      isDense: true,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: ThriveColors.current.muted,
      ),
    ),
  ),
);

// --------------------------------------------------- 8 email & password

class _KidEmailSetupScreen extends StatefulWidget {
  const _KidEmailSetupScreen({required this.state, required this.memberId});
  final _ThriveHomeState state;
  final String memberId;

  @override
  State<_KidEmailSetupScreen> createState() => _KidEmailSetupScreenState();
}

class _KidEmailSetupScreenState extends State<_KidEmailSetupScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  String? _emailErr;
  String? _pwErr;
  bool _failed = false;
  bool _busy = false;

  _ThriveHomeState get s => widget.state;
  FamilyMember? get _m => s._kidRowById(widget.memberId);

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final m = _m;
    if (m == null) return;
    final first = firstNameOf(m.name);
    final email = _email.text.trim().toLowerCase();
    setState(() {
      _failed = false;
      _emailErr = isValidLoginEmail(email)
          ? null
          : 'Enter a valid email, like name@example.com.';
      _pwErr = _pw.text.length < kKidPasswordMinLength
          ? kKidWeakPassword
          : null;
    });
    if (_emailErr != null || _pwErr != null) return;
    setState(() => _busy = true);
    try {
      await s.kidCall('kidCreateEmailLogin', {
        'memberId': m.id,
        'email': email,
        'password': _pw.text,
      });
      if (!mounted) return;
      final pw = _pw.text;
      _pw.clear();
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _KidHandoffScreen(
            state: s,
            memberId: m.id,
            email: email,
            password: pw,
          ),
        ),
      );
    } on KidLoginError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.code == 'invalid-argument' && e.reason == 'password') {
          _pwErr = kKidWeakPassword;
        } else {
          _emailErr = kidEmailError(e, first);
          _failed = _emailErr == null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    if (m == null) return const SizedBox.shrink();
    final first = firstNameOf(m.name);
    final ok = _email.text.trim().isNotEmpty && _pw.text.isNotEmpty && !_busy;
    return _KidSetupPage(
      title: 'Email & password',
      subtitle: 'Login for $first',
      footer: kidButton(
        key: const ValueKey('kid-create-login'),
        label: 'Create login',
        busyLabel: 'Creating login…',
        busy: _busy,
        onTap: ok ? _create : null,
      ),
      children: [
        _kidMemberHeader(s, m, 'Kid · no login'),
        kidField(
          label: 'Email',
          field: _kidEmailInput(
            _email,
            'e.g. ${_aliasHint(s, first)}',
            error: _emailErr != null,
            onChanged: () => setState(() => _emailErr = null),
          ),
          helper:
              'Any address you control works, like a parent’s alias. Thrive '
              'won’t email it.',
          error: _emailErr,
        ),
        KidPasswordField(
          controller: _pw,
          error: _pwErr,
          onChanged: () => setState(() => _pwErr = null),
        ),
        if (_failed)
          kidNotice(
            'Couldn’t create the login. Check your connection and try again.',
            key: const ValueKey('kid-create-failed'),
            tone: KidTone.red,
            icon: 'x',
          ),
        kidNotice('Only admins can change this.', tone: KidTone.grey),
      ],
    );
  }
}

/// "eva+liv@janssen.nl" — the signed-in admin's address with a +alias.
String _aliasHint(_ThriveHomeState s, String first) {
  final mine = (s.user?.email ?? '').trim();
  final at = mine.indexOf('@');
  final tag = first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (at <= 0 || tag.isEmpty) return 'name@example.com';
  return '${mine.substring(0, at)}+$tag${mine.substring(at)}';
}

// ------------------------------------------------------ 9 handoff

class _KidHandoffScreen extends StatefulWidget {
  const _KidHandoffScreen({
    required this.state,
    required this.memberId,
    required this.email,
    required this.password,
    this.reset = false,
  });
  final _ThriveHomeState state;
  final String memberId;
  final String email;
  final String password;
  final bool reset;

  @override
  State<_KidHandoffScreen> createState() => _KidHandoffScreenState();
}

class _KidHandoffScreenState extends State<_KidHandoffScreen> {
  bool _revealed = false;
  bool _saved = false;

  _ThriveHomeState get s => widget.state;

  String get _first => firstNameOf(s._kidRowById(widget.memberId)?.name ?? '');

  String get _familyName => s.curFamily()?.name ?? 'your family';

  String _details() =>
      'Thrive sign-in for $_first\n'
      'Email: ${widget.email}\n'
      'Password: ${widget.password}\n\n'
      '1. Open Thrive\n'
      '2. Enter the email and password, then tap Sign in\n'
      '3. Done. $_first lands straight in the $_familyName, no joining '
      'needed';

  void _copy() {
    Clipboard.setData(ClipboardData(text: _details()));
    setState(() => _saved = true);
    s.flash('Email and password copied');
  }

  Future<bool> _confirmLeave() async {
    if (_saved) return true;
    var leave = false;
    await showKidSheet<void>(
      context,
      builder: (ctx, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kidSheetTitle(
            'Leave without saving $_first’s password?',
            'You won’t see this password again. If it gets lost, reset it '
                'in $_first’s profile.',
          ),
          kidButton(
            key: const ValueKey('kid-handoff-stay'),
            label: 'Stay here',
            onTap: () => Navigator.of(ctx).pop(),
          ),
          const SizedBox(height: 8),
          kidButton(
            key: const ValueKey('kid-handoff-leave'),
            label: 'Leave anyway',
            danger: true,
            onTap: () {
              leave = true;
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
    return leave;
  }

  Future<void> _done() async {
    if (await _confirmLeave() && mounted) {
      _saved = true;
      Navigator.of(context).pop();
    }
  }

  void _loginCard() {
    final payload = 'Thrive sign-in\nEmail: ${widget.email}';
    showKidSheet<void>(
      context,
      builder: (ctx, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kidSheetTitle(
            'Login card',
            'Print it or save it as a PDF for $_first.',
          ),
          Container(
            key: const ValueKey('kid-login-card'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.tc.surface,
              border: Border.all(color: context.tc.line, width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bw.BarcodeWidget(
                  barcode: bc.Barcode.qrCode(),
                  data: payload,
                  width: 92,
                  height: 92,
                  drawText: false,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_first · Thrive',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.tc.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      studioInfoRow('Email', value: widget.email),
                      studioInfoRow('Password', value: widget.password),
                      const SizedBox(height: 4),
                      Text(
                        'Open Thrive, enter these details and tap Sign in. '
                        'Keep this card somewhere safe.',
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
          ),
          const SizedBox(height: 12),
          kidButton(
            key: const ValueKey('kid-login-card-copy'),
            label: 'Copy',
            onTap: () {
              _copy();
              Navigator.of(ctx).pop();
            },
          ),
          kidCancelLink(ctx, label: 'Close'),
        ],
      ),
    );
  }

  Widget _credRow(String label, String value, {Key? key, Widget? trailing}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      decoration: BoxDecoration(
        color: context.tc.page,
        border: Border.all(color: context.tc.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                studioSectionLabel(label, padding: EdgeInsets.zero),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.tc.ink,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = _first;
    final pw = _revealed ? widget.password : '•' * widget.password.length;
    final body = <Widget>[
      Text(
        widget.reset ? 'New password for $first' : '$first can now sign in',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -.4,
          color: context.tc.ink,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 3, bottom: 12),
        child: Text(
          widget.reset
              ? '$first was signed out on all devices. Give $first the new '
                    'password.'
              : 'Give $first these details. No joining or family password '
                    'needed.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.tc.muted,
          ),
        ),
      ),
      _credRow('Email', widget.email, key: const ValueKey('kid-handoff-email')),
      _credRow(
        'Password',
        pw,
        key: const ValueKey('kid-handoff-password'),
        trailing: GestureDetector(
          key: const ValueKey('kid-handoff-reveal'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _revealed = !_revealed),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ic(
              _revealed ? 'eyeoff' : 'eye',
              size: 17,
              sw: 2.2,
              color: context.tc.soft2,
            ),
          ),
        ),
      ),
      kidNotice(
        'This password is shown only once. When you leave this screen, it’s '
        'hidden for good. You can reset it any time.',
        tone: KidTone.amber,
        icon: 'eye',
      ),
      Row(
        children: [
          Expanded(
            child: kidButton(
              key: const ValueKey('kid-handoff-copy'),
              label: 'Copy',
              secondary: true,
              onTap: _copy,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: kidButton(
              // No share sheet plugin yet: Share copies the same details.
              key: const ValueKey('kid-handoff-share'),
              label: 'Share',
              secondary: true,
              onTap: _copy,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: kidButton(
              key: const ValueKey('kid-handoff-card'),
              label: 'Login card',
              secondary: true,
              onTap: _loginCard,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      studioCard(
        title: 'On $first’s device',
        children: [
          for (final (i, step) in [
            'Open Thrive',
            'Enter the email and password, then tap Sign in',
            'Done. $first lands straight in the $_familyName, no joining '
                'needed',
          ].indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.tc.soft,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: context.tc.deep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.tc.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ];
    return PopScope(
      canPop: _saved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          setState(() => _saved = true);
          Navigator.of(context).pop();
        }
      },
      child: _KidSetupPage(
        title: widget.reset ? 'New password' : 'Login created',
        subtitle: first,
        onBack: _done,
        footer: kidButton(
          key: const ValueKey('kid-handoff-done'),
          label: 'Done',
          onTap: _done,
        ),
        children: body,
      ),
    );
  }
}

// -------------------------------------------------------- 10 Google setup

class _KidGoogleSetupScreen extends StatefulWidget {
  const _KidGoogleSetupScreen({
    required this.state,
    required this.memberId,
    this.replace = false,
  });
  final _ThriveHomeState state;
  final String memberId;

  /// Changing an active Google login: the old one is removed first.
  final bool replace;

  @override
  State<_KidGoogleSetupScreen> createState() => _KidGoogleSetupScreenState();
}

class _KidGoogleSetupScreenState extends State<_KidGoogleSetupScreen> {
  final _email = TextEditingController();
  String? _err;
  bool _failed = false;

  _ThriveHomeState get s => widget.state;
  FamilyMember? get _m => s._kidRowById(widget.memberId);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final m = _m;
    if (m == null) return;
    final first = firstNameOf(m.name);
    final email = _email.text.trim().toLowerCase();
    if (!isValidLoginEmail(email)) {
      setState(() => _err = 'Enter a valid email, like name@gmail.com.');
      return;
    }
    var busy = false;
    String? result;
    await showKidSheet<void>(
      context,
      builder: (ctx, setSheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kidSheetTitle(
            'Link this Google account?',
            'When $first taps Continue with Google with this account, '
                'they’ll be signed in as $first.',
          ),
          studioInfoRow('Google account', value: email),
          const SizedBox(height: 6),
          kidConsequenceList('Stays with $first', const [
            'Same profile, colour and kid access',
            'Everything assigned to them',
            'No family username or password needed',
          ]),
          kidButton(
            key: const ValueKey('kid-google-link'),
            label: 'Link Google account',
            busyLabel: 'Linking…',
            busy: busy,
            onTap: () async {
              setSheet(() => busy = true);
              try {
                final cur = s._kidRowById(m.id);
                if (widget.replace && cur != null && cur.hasLogin) {
                  await s.kidCall('kidRemoveLogin', {'memberId': m.id});
                }
                await s.kidCall('kidLinkGoogle', {
                  'memberId': m.id,
                  'email': email,
                });
                result = 'ok';
              } on KidLoginError catch (e) {
                result = kidEmailError(e, first, google: true) ?? 'failed';
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
          if (!busy)
            kidCancelLink(
              ctx,
              label: 'Edit email',
              key: const ValueKey('kid-google-edit'),
            ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    if (result == 'ok') {
      s.flash('Google account linked. Waiting for $first to sign in.');
      Navigator.of(context).pop();
    } else if (result == 'failed') {
      setState(() => _failed = true);
    } else {
      setState(() => _err = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    if (m == null) return const SizedBox.shrink();
    final first = firstNameOf(m.name);
    final fam = s.curFamily()?.name ?? 'your family';
    return _KidSetupPage(
      title: 'Google account',
      subtitle: 'Login for $first',
      footer: kidButton(
        key: const ValueKey('kid-google-continue'),
        label: 'Continue',
        onTap: _email.text.trim().isEmpty ? null : _continue,
      ),
      children: [
        _kidMemberHeader(s, m, 'Kid · no login'),
        kidField(
          label: '$first’s Google account',
          field: _kidEmailInput(
            _email,
            'name@gmail.com',
            error: _err != null,
            onChanged: () => setState(() {
              _err = null;
              _failed = false;
            }),
          ),
          helper:
              'Must be the exact Google account $first uses on their phone '
              'or tablet.',
          error: _err,
        ),
        kidNotice(
          'When $first taps Continue with Google, they go straight into the '
          '$fam. No family username or password needed.',
        ),
        if (_failed)
          kidNotice(
            'Couldn’t link the Google account. Check your connection and try '
            'again.',
            key: const ValueKey('kid-google-failed'),
            tone: KidTone.red,
            icon: 'x',
          ),
      ],
    );
  }
}

// ------------------------------------------------- 6 + 11 login card

/// The Login card in Member Studio for a kid profile: no login → "Give X a
/// login"; a pending Google link; an active Google login; or an admin-managed
/// email & password login with its actions.
class _KidLoginCard extends StatefulWidget {
  const _KidLoginCard({required this.state, required this.memberId});
  final _ThriveHomeState state;
  final String memberId;

  @override
  State<_KidLoginCard> createState() => _KidLoginCardState();
}

class _KidLoginCardState extends State<_KidLoginCard> {
  bool _loading = false;
  int? _lastSignIn;
  String? _loadedFor;

  _ThriveHomeState get s => widget.state;
  FamilyMember? get _m => s._kidRowById(widget.memberId);

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant _KidLoginCard old) {
    super.didUpdateWidget(old);
    _maybeLoad();
  }

  void _maybeLoad() {
    final m = _m;
    if (m == null || !m.hasLogin || m.loginMethod == null || !s.amAdmin()) {
      return;
    }
    if (_loadedFor == m.uid) return;
    _loadedFor = m.uid;
    _loading = true;
    s
        .kidCall('kidLoginDetails', {'memberId': m.id})
        .then((r) {
          if (!mounted) return;
          final v = r['lastSignInMillis'];
          setState(() {
            _lastSignIn = v is num ? v.toInt() : null;
            _loading = false;
          });
        })
        .catchError((Object _) {
          if (mounted) setState(() => _loading = false);
          return null;
        });
  }

  Future<void> _start() async {
    final m = _m;
    if (m == null) return;
    final method = await showLoginMethodSheet(context, m);
    if (!mounted || method == null) return;
    await s.pushSettingsPage<void>(
      (_) => method == 'email'
          ? _KidEmailSetupScreen(state: s, memberId: m.id)
          : _KidGoogleSetupScreen(state: s, memberId: m.id),
    );
    if (mounted) setState(() {});
  }

  /// Runs a confirm sheet whose primary button calls [call]; flashes
  /// [toast] on success and a generic error otherwise.
  Future<void> _confirm({
    required String title,
    required String body,
    required String button,
    required String busyLabel,
    required Future<void> Function() call,
    required String toast,
    List<Widget> extra = const [],
    bool danger = true,
    String key = 'kid-action-confirm',
  }) async {
    var busy = false;
    String? err;
    await showKidSheet<void>(
      context,
      builder: (ctx, setSheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kidSheetTitle(title, body),
          ...extra,
          if (err != null) kidNotice(err!, tone: KidTone.red, icon: 'x'),
          kidButton(
            key: ValueKey(key),
            label: button,
            busyLabel: busyLabel,
            busy: busy,
            danger: danger,
            onTap: () async {
              setSheet(() {
                busy = true;
                err = null;
              });
              try {
                await call();
                if (ctx.mounted) Navigator.of(ctx).pop();
                s.flash(toast);
              } on KidLoginError catch (_) {
                setSheet(() {
                  busy = false;
                  err =
                      'Couldn’t finish that. Check your connection and try '
                      'again.';
                });
              }
            },
          ),
          if (!busy) kidCancelLink(ctx),
        ],
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _reset(FamilyMember m) async {
    final first = firstNameOf(m.name);
    final pw = TextEditingController();
    var busy = false;
    String? pwErr;
    String? failed;
    String? done;
    await showKidSheet<void>(
      context,
      builder: (ctx, setSheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kidSheetTitle(
            'Reset $first’s password',
            '$first is signed out on all devices and signs in with the new '
                'password.',
          ),
          KidPasswordField(
            controller: pw,
            label: 'New password',
            error: pwErr,
            onChanged: () => setSheet(() => pwErr = null),
          ),
          if (failed != null) kidNotice(failed!, tone: KidTone.red, icon: 'x'),
          kidButton(
            key: const ValueKey('kid-reset-go'),
            label: 'Reset password',
            busyLabel: 'Resetting…',
            busy: busy,
            onTap: () async {
              if (pw.text.length < kKidPasswordMinLength) {
                setSheet(() => pwErr = kKidWeakPassword);
                return;
              }
              setSheet(() {
                busy = true;
                failed = null;
              });
              try {
                await s.kidCall('kidResetPassword', {
                  'memberId': m.id,
                  'password': pw.text,
                });
                done = pw.text;
                if (ctx.mounted) Navigator.of(ctx).pop();
              } on KidLoginError catch (e) {
                setSheet(() {
                  busy = false;
                  if (e.reason == 'password') {
                    pwErr = kKidWeakPassword;
                  } else {
                    failed =
                        'Couldn’t reset the password. Check your connection '
                        'and try again.';
                  }
                });
              }
            },
          ),
          if (!busy) kidCancelLink(ctx),
        ],
      ),
    );
    // No dispose: the sheet still reads [pw] while it animates closed.
    if (!mounted || done == null) return;
    await s.pushSettingsPage<void>(
      (_) => _KidHandoffScreen(
        state: s,
        memberId: m.id,
        email: m.loginEmail ?? '',
        password: done!,
        reset: true,
      ),
    );
  }

  Future<void> _changeEmail(FamilyMember m) async {
    final first = firstNameOf(m.name);
    final c = TextEditingController();
    var busy = false;
    String? err;
    var changed = false;
    await showKidSheet<void>(
      context,
      builder: (ctx, setSheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kidSheetTitle(
            'Change $first’s email',
            '$first signs in with the new email from now on. The password '
                'stays the same.',
          ),
          kidField(
            label: 'New email',
            field: _kidEmailInput(
              c,
              m.loginEmail ?? 'name@example.com',
              key: const ValueKey('kid-new-email'),
              error: err != null,
              onChanged: () => setSheet(() => err = null),
            ),
            helper: 'Only admins can change this.',
            error: err,
          ),
          kidButton(
            key: const ValueKey('kid-change-email-go'),
            label: 'Save email',
            busyLabel: 'Saving…',
            busy: busy,
            onTap: () async {
              final email = c.text.trim().toLowerCase();
              if (!isValidLoginEmail(email)) {
                setSheet(
                  () => err = 'Enter a valid email, like name@example.com.',
                );
                return;
              }
              setSheet(() => busy = true);
              try {
                await s.kidCall('kidChangeEmail', {
                  'memberId': m.id,
                  'email': email,
                });
                changed = true;
                if (ctx.mounted) Navigator.of(ctx).pop();
              } on KidLoginError catch (e) {
                setSheet(() {
                  busy = false;
                  err =
                      kidEmailError(e, first) ??
                      'Couldn’t change the email. Check your connection and '
                          'try again.';
                });
              }
            },
          ),
          if (!busy) kidCancelLink(ctx),
        ],
      ),
    );
    // No dispose: the sheet still reads [c] while it animates closed.
    if (changed) {
      s.flash('$first’s email changed');
      if (mounted) setState(() {});
    }
  }

  String _signInSteps(FamilyMember m) {
    final first = firstNameOf(m.name);
    final fam = s.curFamily()?.name ?? 'your family';
    return 'Thrive sign-in for $first\n'
        '1. Open Thrive\n'
        '2. Tap Continue with Google and pick ${m.loginEmail}\n'
        '3. Done. $first lands straight in the $fam, no joining needed';
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    if (m == null) return const SizedBox.shrink();
    final first = firstNameOf(m.name);
    final admin = s.amAdmin();
    final offline = s.netOffline.value && s._cloudBacked;
    final keepItems = ['Profile, colour and kid access'];

    // No login yet.
    if (m.loginMethod == null) {
      return studioCard(
        title: 'Login',
        children: [
          Text(
            admin
                ? '$first doesn’t have a login yet. Give $first one to use '
                      'Thrive on their own phone or tablet.'
                : '$first doesn’t have a login yet.',
            key: const ValueKey('kid-login-none'),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: context.tc.text,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          if (!admin)
            kidNotice(
              'Only admins can give $first a login.',
              tone: KidTone.grey,
              icon: 'lock',
            )
          else ...[
            if (offline)
              kidNotice(
                'You’re offline. Logins can only be set up online.',
                tone: KidTone.amber,
                icon: 'wifi',
              ),
            kidButton(
              key: const ValueKey('kid-give-login'),
              label: 'Give $first a login',
              onTap: offline ? null : _start,
            ),
          ],
        ],
      );
    }

    if (!admin) {
      return studioCard(
        title: 'Login',
        children: [
          studioInfoRow(
            'Method',
            value: m.loginMethod == 'google'
                ? 'Google account'
                : 'Email & password',
          ),
          kidNotice(
            'Only admins can see and change this.',
            tone: KidTone.grey,
            icon: 'lock',
          ),
        ],
      );
    }

    final action = offline ? null : true;
    if (m.loginPending) {
      return studioCard(
        title: 'Login',
        children: [
          studioInfoRow('Method', value: 'Google account'),
          studioInfoRow('Google account', value: m.loginEmail ?? ''),
          studioInfoRow(
            'Status',
            trailing: kidPill(
              'Pending',
              tone: KidTone.amber,
              key: const ValueKey('kid-login-pending'),
            ),
          ),
          if (m.linkedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(
                'Linked ${kidShortDate(m.linkedAt)} by ${m.linkedBy ?? 'an admin'}.',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: context.tc.muted,
                ),
              ),
            ),
          kidNotice(
            'When $first taps Continue with Google, they go straight into '
            'the ${s.curFamily()?.name ?? 'family'}. No family username or '
            'password needed.',
          ),
          kidActionRow(
            key: const ValueKey('kid-copy-steps'),
            label: 'Copy sign-in steps',
            sub: 'Send them to $first',
            icon: 'copy',
            onTap: () {
              Clipboard.setData(ClipboardData(text: _signInSteps(m)));
              s.flash('Sign-in steps copied');
            },
          ),
          kidActionRow(
            key: const ValueKey('kid-change-google'),
            label: 'Change Google account',
            icon: 'edit',
            onTap: action == null
                ? null
                : () => s.pushSettingsPage<void>(
                    (_) => _KidGoogleSetupScreen(state: s, memberId: m.id),
                  ),
          ),
          kidActionRow(
            key: const ValueKey('kid-cancel-link'),
            label: 'Cancel link',
            sub: '$first goes back to a profile without a login',
            icon: 'x',
            danger: true,
            onTap: action == null
                ? null
                : () => _confirm(
                    title: 'Cancel $first’s Google link?',
                    body: '$first goes back to a profile without a login.',
                    button: 'Cancel link',
                    busyLabel: 'Cancelling…',
                    toast: '$first’s Google link was cancelled',
                    call: () => s.kidCall('kidRemoveLogin', {'memberId': m.id}),
                  ),
          ),
        ],
      );
    }

    final google = m.loginMethod == 'google';
    Future<void> removeSheet() => _confirm(
      title: 'Remove $first’s login?',
      body: '$first goes back to a profile without a login.',
      button: 'Remove login',
      busyLabel: 'Removing…',
      toast: '$first’s login was removed',
      key: 'kid-remove-go',
      extra: [
        kidConsequenceList('$first keeps', keepItems),
        kidNotice(
          '$first is signed out on every device right away.',
          tone: KidTone.amber,
          margin: const EdgeInsets.only(bottom: 12),
        ),
      ],
      call: () => s.kidCall('kidRemoveLogin', {'memberId': m.id}),
    );
    Future<void> signOutSheet() => _confirm(
      title: 'Sign $first out everywhere?',
      body:
          '$first is signed out on every phone, tablet and browser. The '
          'login stays the same, so $first can sign in again.',
      button: 'Sign out everywhere',
      busyLabel: 'Signing out…',
      toast: '$first is signed out on all devices',
      key: 'kid-signout-go',
      call: () => s.kidCall('kidSignOutEverywhere', {'memberId': m.id}),
    );
    return studioCard(
      title: 'Login',
      children: [
        if (_loading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Loading login details…',
              key: ValueKey('kid-login-loading'),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.tc.muted,
              ),
            ),
          ),
        studioInfoRow(
          'Method',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                google ? 'Google account' : 'Email & password',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: context.tc.ink,
                ),
              ),
              if (m.managed) ...[
                const SizedBox(width: 6),
                kidPill('Managed', key: const ValueKey('kid-login-managed')),
              ],
            ],
          ),
        ),
        studioInfoRow(google ? 'Google account' : 'Email', value: m.loginEmail),
        if (!_loading)
          studioInfoRow('Last sign-in', value: kidLastSignIn(_lastSignIn)),
        if (offline)
          kidNotice(
            'You’re offline. Login changes need a connection.',
            tone: KidTone.amber,
            icon: 'wifi',
          ),
        const SizedBox(height: 4),
        if (!google) ...[
          kidActionRow(
            key: const ValueKey('kid-reset-password'),
            label: 'Reset password',
            icon: 'lock',
            onTap: action == null ? null : () => _reset(m),
          ),
          kidActionRow(
            key: const ValueKey('kid-change-email'),
            label: 'Change email',
            icon: 'edit',
            onTap: action == null ? null : () => _changeEmail(m),
          ),
        ],
        kidActionRow(
          key: const ValueKey('kid-signout'),
          label: 'Sign out of all devices',
          sub: 'Signs $first out everywhere',
          icon: 'unlock',
          onTap: action == null ? null : signOutSheet,
        ),
        if (google)
          kidActionRow(
            key: const ValueKey('kid-change-google'),
            label: 'Change Google account',
            icon: 'edit',
            onTap: action == null
                ? null
                : () => s.pushSettingsPage<void>(
                    (_) => _KidGoogleSetupScreen(
                      state: s,
                      memberId: m.id,
                      replace: true,
                    ),
                  ),
          ),
        kidActionRow(
          key: const ValueKey('kid-remove-login'),
          label: 'Remove login',
          sub: '$first goes back to a profile without a login',
          icon: 'trash',
          danger: true,
          onTap: action == null ? null : removeSheet,
        ),
        Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Only admins can see and change this.',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: context.tc.muted,
            ),
          ),
        ),
      ],
    );
  }
}
