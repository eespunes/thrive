part of 'package:family_money_management_app/main.dart';

/// Create / join family as full sub-pages (#284, `Settings v2.dc.html`
/// `vCreate`/`vJoin`): the design renders them as pushed screens with live
/// @username availability (and a "use @suggestion" chip when taken), not
/// bottom sheets. The profile and family-management sheets were replaced by
/// real sub-pages earlier in Settings v2 (#274/#275).
extension _ThriveAccountSheets on _ThriveHomeState {
  void openCreateFamilyScreen() {
    pushSettingsPage<void>((_) => _CreateFamilyScreen(state: this));
  }

  void openJoinFamilyScreen() {
    pushSettingsPage<void>((_) => _JoinFamilyScreen(state: this));
  }
}

/// Shared chrome for the create/join pages: back header + scrolling white
/// form card, per the design's sub-page layout.
class _FamilyFormPage extends StatelessWidget {
  const _FamilyFormPage({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      body: SafeArea(
        child: Column(
          children: [
            studioBackHeader(
              title: title,
              subtitle: subtitle,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: B.line),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The teal full-width action button at the bottom of both form cards.
Widget _familyFormButton(
  String label,
  VoidCallback onTap, {
  bool enabled = true,
}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: enabled ? onTap : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 13),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? B.primary : const Color(0xffe2e8f0),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: enabled ? Colors.white : B.muted,
        ),
      ),
    ),
  );
}

// ======================================================= create family page
class _CreateFamilyScreen extends StatefulWidget {
  const _CreateFamilyScreen({required this.state});
  final _ThriveHomeState state;

  @override
  State<_CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<_CreateFamilyScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  String? _picture;
  bool _busy = false;
  final _picker = ImagePicker();

  // Username suggestion / availability state (issue #121). While the user
  // hasn't touched the username field we auto-fill it with an available
  // suggestion derived from the family name; once they edit it we validate
  // it live instead — when taken, a "use @suggestion" chip offers the next
  // free handle (#284, design `cfTaken`).
  bool _usernameEdited = false;
  Timer? _usernameDebounce;
  int _usernameCheckSeq = 0;
  String? _usernameNote;
  Color _usernameNoteColor = B.muted;
  String? _takenSuggestion;

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
      setState(() {
        _usernameNote = null;
        _takenSuggestion = null;
      });
      return;
    }
    _usernameDebounce = Timer(const Duration(milliseconds: 350), () async {
      final suggestion = await s.suggestFamilyUsername(name);
      if (!mounted || seq != _usernameCheckSeq || _usernameEdited) return;
      setState(() {
        _username.text = suggestion;
        _takenSuggestion = null;
        if (suggestion.isEmpty) {
          _usernameNote = null;
        } else {
          _usernameNote = 'Suggested · available';
          _usernameNoteColor = B.green;
        }
      });
    });
  }

  /// Validates a user-typed handle and notifies whether it is free to claim;
  /// when taken, fetches a free alternative for the "use @…" chip.
  void _checkUsername(String value) {
    _usernameDebounce?.cancel();
    final slug = familySlug(value);
    if (slug.isEmpty) {
      setState(() {
        _usernameNote = null;
        _takenSuggestion = null;
      });
      return;
    }
    if (!validFamilyUsername(slug)) {
      setState(() {
        _usernameNote = '3–24 letters, numbers, - or _';
        _usernameNoteColor = B.red;
        _takenSuggestion = null;
      });
      return;
    }
    setState(() {
      _usernameNote = 'Checking availability…';
      _usernameNoteColor = B.muted;
      _takenSuggestion = null;
    });
    final seq = ++_usernameCheckSeq;
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      final available = await s.familyUsernameAvailable(slug);
      String? alt;
      if (!available) {
        // Derive the chip's free handle from the typed slug (not the family
        // name), so "use @beach-house-2" reads as a fix for what they typed.
        alt = await s.suggestFamilyUsername(slug.replaceAll('-', ' '));
      }
      if (!mounted || seq != _usernameCheckSeq) return;
      setState(() {
        _usernameNote = available
            ? '@$slug is available ✓'
            : '“@$slug” is taken';
        _usernameNoteColor = available ? B.green : B.red;
        _takenSuggestion = (!available && (alt?.isNotEmpty ?? false))
            ? alt
            : null;
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
    return _FamilyFormPage(
      title: 'Create a family',
      subtitle: 'A fresh, separate workspace relatives can join',
      children: [
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
        const SizedBox(height: 14),
        studioTextField(
          key: const ValueKey('nf-name'),
          controller: _name,
          hint: 'Family name — e.g. The Janssens',
          capitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _usernameFocus.requestFocus(),
          onChanged: (v) {
            setState(s.dismissError);
            if (!_usernameEdited) _suggestUsername(v);
          },
        ),
        studioTextField(
          key: const ValueKey('nf-username'),
          controller: _username,
          hint: 'Username (how people find you)',
          margin: const EdgeInsets.only(bottom: 5),
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
            padding: const EdgeInsets.only(bottom: 5, left: 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 7,
              runSpacing: 5,
              children: [
                Text(
                  _usernameNote!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _usernameNoteColor,
                  ),
                ),
                if (_takenSuggestion != null)
                  GestureDetector(
                    key: const ValueKey('nf-use-suggestion'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final alt = _takenSuggestion!;
                      setState(() {
                        _username.text = alt;
                        _usernameNote = '@$alt is available ✓';
                        _usernameNoteColor = B.green;
                        _takenSuggestion = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: B.soft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'use @$_takenSuggestion',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: B.deep,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 5),
        studioTextField(
          key: const ValueKey('nf-password'),
          controller: _password,
          hint: 'Password (optional, min 4 characters)',
          obscure: true,
          margin: const EdgeInsets.only(bottom: 5),
          focusNode: _passwordFocus,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (_name.text.trim().isNotEmpty) _submit();
          },
          onChanged: (_) => setState(s.dismissError),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 11, left: 2),
          child: Text(
            'Add a username & password so relatives can join this family.',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: B.muted,
            ),
          ),
        ),
        _familyFormButton(
          _busy ? 'Creating…' : 'Create family',
          _submit,
          enabled: valid,
        ),
      ],
    );
  }
}

// ========================================================= join family page
class _JoinFamilyScreen extends StatefulWidget {
  const _JoinFamilyScreen({required this.state});
  final _ThriveHomeState state;

  @override
  State<_JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<_JoinFamilyScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  String? _error;

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
    // Inline error box per the design (`jfError`) — wrong username, wrong
    // password and already-a-member all land here.
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final valid = _username.text.trim().isNotEmpty;
    return _FamilyFormPage(
      title: 'Join a family',
      subtitle: 'With their username & password',
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 13),
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
        studioTextField(
          key: const ValueKey('jf-username'),
          controller: _username,
          hint: 'Family username — e.g. smith-home',
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          onChanged: (_) => setState(() => _error = null),
        ),
        studioTextField(
          key: const ValueKey('jf-password'),
          controller: _password,
          hint: 'Password (if they set one)',
          obscure: true,
          margin: const EdgeInsets.only(bottom: 5),
          focusNode: _passwordFocus,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (_username.text.trim().isNotEmpty) _submit();
          },
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_error != null)
          Container(
            key: const ValueKey('jf-error'),
            margin: const EdgeInsets.only(top: 5, bottom: 5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: B.redSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: B.red,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _familyFormButton(
          _busy ? 'Joining…' : 'Join family',
          _submit,
          enabled: valid,
        ),
      ],
    );
  }
}
