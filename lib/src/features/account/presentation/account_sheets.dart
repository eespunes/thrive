part of 'package:family_money_management_app/main.dart';

/// Create/join family bottom sheets and their entry points. The profile and
/// family-management sheets were replaced by real sub-pages in Settings v2
/// (#274/#275 — see `settings_family_screens.dart`).
extension _ThriveAccountSheets on _ThriveHomeState {
  void openNewFamilySheet() {
    _showSheet((ctx) => _NewFamilySheet(state: this));
  }

  void openJoinFamilySheet() {
    _showSheet((ctx) => _JoinFamilySheet(state: this));
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
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  String? _picture;
  bool _busy = false;
  final _picker = ImagePicker();

  // Username suggestion / availability state (issue #121). While the user hasn't
  // touched the username field we auto-fill it with an available suggestion
  // derived from the family name; once they edit it we validate it live instead.
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(
            context,
            'Create a family',
            'A fresh, separate workspace relatives can join',
          ),
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
          const SizedBox(height: 15),
          _sheetField(
            'Family name',
            _sheetInput(
              _name,
              key: const ValueKey('nf-name'),
              hint: 'e.g. The Janssens',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _usernameFocus.requestFocus(),
              onChanged: (v) {
                setState(s.dismissError);
                if (!_usernameEdited) _suggestUsername(v);
              },
            ),
          ),
          _sheetField(
            'Family username (optional)',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetInput(
                  _username,
                  key: const ValueKey('nf-username'),
                  hint: 'e.g. beach-house',
                  capitalization: TextCapitalization.none,
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
                    padding: const EdgeInsets.only(top: 6, left: 2),
                    child: Text(
                      _usernameNote!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _usernameNoteColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _sheetField(
            'Family password (optional)',
            _sheetInput(
              _password,
              key: const ValueKey('nf-password'),
              hint: 'At least 4 characters',
              obscure: true,
              focusNode: _passwordFocus,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (valid) _submit();
              },
              onChanged: (_) => setState(s.dismissError),
            ),
          ),
          _primaryBtn(
            _busy ? 'Creating…' : 'Create family',
            _submit,
            enabled: valid,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 13),
            child: Text(
              'Add a username & password so relatives can join this family.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: B.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================== join family sheet
class _JoinFamilySheet extends StatefulWidget {
  const _JoinFamilySheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_JoinFamilySheet> createState() => _JoinFamilySheetState();
}

class _JoinFamilySheetState extends State<_JoinFamilySheet> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;

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
    setState(() => _busy = false);
    s.showError(err);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _username.text.trim().isNotEmpty;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(context, 'Join a family', 'Enter shared credentials'),
          Container(
            padding: const EdgeInsets.all(14),
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
          _sheetField(
            'Family username',
            _sheetInput(
              _username,
              key: const ValueKey('jf-username'),
              hint: 'e.g. smith-home',
              capitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              onChanged: (_) => setState(s.dismissError),
            ),
          ),
          _sheetField(
            'Family password',
            _sheetInput(
              _password,
              key: const ValueKey('jf-password'),
              hint: 'Family password',
              obscure: true,
              focusNode: _passwordFocus,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (valid) _submit();
              },
              onChanged: (_) => setState(s.dismissError),
            ),
          ),
          _primaryBtn(
            _busy ? 'Joining…' : 'Join family',
            _submit,
            enabled: valid,
          ),
        ],
      ),
    );
  }
}
