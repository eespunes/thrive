part of 'package:family_money_management_app/main.dart';

/// Renders a family avatar: a cropped picture, else a branded tile.
Widget famAvatar({
  String? picture,
  required double size,
  required double radius,
}) {
  Widget child;
  if (picture != null && picture.isNotEmpty) {
    try {
      child = Image.memory(
        base64Decode(picture),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } catch (_) {
      child = _famAvatarFallback(size);
    }
  } else {
    child = _famAvatarFallback(size);
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(width: size, height: size, child: child),
  );
}

Widget _famAvatarFallback(double size) => Container(
  width: size,
  height: size,
  alignment: Alignment.center,
  decoration: const BoxDecoration(gradient: B.grad),
  child: ic('users', size: size * 0.42, sw: 2.2, color: Colors.white),
);

/// One-last-step gate: a signed-in user with no family creates or joins one.
class _OnboardingScreen extends StatefulWidget {
  const _OnboardingScreen({required this.state});
  final _ThriveHomeState state;

  @override
  State<_OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<_OnboardingScreen> {
  bool _create = true;
  bool _busy = false;
  String? _picture;
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _joinUser = TextEditingController();
  final _joinPw = TextEditingController();
  final _picker = ImagePicker();

  // Username suggestion / availability state (issue #121).
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
    _joinUser.dispose();
    _joinPw.dispose();
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
    s.dismissError();
    setState(() => _busy = true);
    final err = _create
        ? await s.createFamily(
            _name.text,
            username: _username.text,
            password: _password.text,
            picture: _picture,
          )
        : await s.joinFamily(username: _joinUser.text, password: _joinPw.text);
    if (!mounted) return;
    setState(() => _busy = false);
    s.showError(err);
  }

  @override
  Widget build(BuildContext context) {
    final u = s.user;
    return Material(
      color: B.page,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // hero
              Container(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                decoration: const BoxDecoration(
                  gradient: B.grad,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        s.avatarNode(
                          photo: u?.photo,
                          initials: u?.initials ?? '?',
                          color: u?.color,
                          size: 38,
                          radius: 12,
                          fs: 14,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Signed in as',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                u?.name ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          key: const ValueKey('onboard-signout'),
                          onTap: s.signOut,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .35),
                              ),
                            ),
                            child: const Text(
                              'Sign out',
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
                    const SizedBox(height: 16),
                    const Text(
                      'One last step',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Create a family workspace, or join one a relative '
                      'already set up.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _tabs(),
                    const SizedBox(height: 20),
                    if (_create) _createForm() else _joinForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs() {
    Widget tab(String label, bool active, VoidCallback onTap, Key key) {
      return Expanded(
        child: GestureDetector(
          key: key,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .12),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: active ? B.deep : B.soft2,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xffeaedf2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          tab('Create a family', _create, () {
            setState(() => _create = true);
            s.dismissError();
          }, const ValueKey('onboard-tab-create')),
          tab('Join a family', !_create, () {
            setState(() => _create = false);
            s.dismissError();
          }, const ValueKey('onboard-tab-join')),
        ],
      ),
    );
  }

  Widget _createForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              famAvatar(picture: _picture, size: 76, radius: 22),
              const SizedBox(height: 11),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    key: const ValueKey('onboard-photo'),
                    onTap: _pickPhoto,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
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
                            _picture != null
                                ? 'Change photo'
                                : 'Add photo (optional)',
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
                  if (_picture != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _picture = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: B.line),
                        ),
                        child: ic('trash', size: 13, sw: 2.2, color: B.soft2),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _field(
          'Family name',
          _name,
          'e.g. The Janssens',
          onChanged: (v) {
            if (!_usernameEdited) _suggestUsername(v);
          },
        ),
        _field(
          'Family username',
          _username,
          'e.g. janssen-home',
          onChanged: (v) {
            _usernameEdited = v.trim().isNotEmpty;
            if (_usernameEdited) {
              _checkUsername(v);
            } else {
              _suggestUsername(_name.text);
            }
          },
          note: _usernameNote,
          noteColor: _usernameNoteColor,
        ),
        _field(
          'Family password',
          _password,
          'At least 4 characters',
          obscure: true,
        ),
        _primaryBtn(_busy ? 'Creating…' : 'Create family', _submit),
        const Padding(
          padding: EdgeInsets.only(top: 13),
          child: Text(
            'Members join with this username & password. You can change them '
            'later.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: B.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _joinForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
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
                  'Ask the family owner for the username & password they chose.',
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
        _field('Family username', _joinUser, 'e.g. vanderberg'),
        _field('Family password', _joinPw, 'Family password', obscure: true),
        _primaryBtn(_busy ? 'Joining…' : 'Join family', _submit),
        const Padding(
          padding: EdgeInsets.only(top: 13),
          child: Text.rich(
            TextSpan(
              text: 'Demo: try ',
              children: [
                TextSpan(
                  text: 'vanderberg',
                  style: TextStyle(color: B.deep),
                ),
                TextSpan(text: ' / '),
                TextSpan(
                  text: 'demo',
                  style: TextStyle(color: B.deep),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: B.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController c,
    String hint, {
    bool obscure = false,
    ValueChanged<String>? onChanged,
    String? note,
    Color noteColor = B.muted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: B.soft2,
              ),
            ),
          ),
          TextField(
            controller: c,
            obscureText: obscure,
            onChanged: (v) {
              s.dismissError();
              onChanged?.call(v);
            },
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: B.ink,
            ),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: B.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: B.primary),
              ),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Text(
                note,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: noteColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
