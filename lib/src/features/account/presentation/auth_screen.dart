part of 'package:family_money_management_app/main.dart';

final RegExp _kEmailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// The Google "G" mark, rendered from the design's multi-color SVG.
Widget _googleLogo({double size = 19}) {
  const svg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">'
      '<path fill="#FFC107" d="M43.611 20.083H42V20H24v8h11.303c-1.649 4.657-6.08 8-11.303 8-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 12.955 4 4 12.955 4 24s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z"/>'
      '<path fill="#FF3D00" d="M6.306 14.691l6.571 4.819C14.655 15.108 18.961 12 24 12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 16.318 4 9.656 8.337 6.306 14.691z"/>'
      '<path fill="#4CAF50" d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238C29.211 35.091 26.715 36 24 36c-5.202 0-9.619-3.317-11.283-7.946l-6.522 5.025C9.505 39.556 16.227 44 24 44z"/>'
      '<path fill="#1976D2" d="M43.611 20.083H42V20H24v8h11.303c-.792 2.237-2.231 4.166-4.087 5.571.001-.001.002-.001.003-.002l6.19 5.238C36.971 39.205 44 34 44 24c0-1.341-.138-2.65-.389-3.917z"/>'
      '</svg>';
  return SvgPicture.string(svg, width: size, height: size);
}

/// Full-screen login / registration gate.
class _AuthScreen extends StatefulWidget {
  const _AuthScreen({required this.state});
  final _ThriveHomeState state;

  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> {
  bool _register = false;
  bool _busy = false;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _emailFocus = FocusNode();
  final _pwFocus = FocusNode();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    _emailFocus.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  Future<void> _googleAuth() async {
    setState(() => _busy = true);
    widget.state.dismissError();
    final err = await widget.state.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    widget.state.showError(err);
  }

  Future<void> _emailAuth() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (_register && name.isEmpty) {
      return widget.state.showError('Enter your name');
    }
    if (!_kEmailRe.hasMatch(email)) {
      return widget.state.showError('Enter a valid email');
    }
    if (_pw.text.length < 4) {
      return widget.state.showError('Password must be at least 4 characters');
    }
    widget.state.dismissError();
    setState(() => _busy = true);
    final err = await widget.state.signInWithEmail(
      email: email,
      password: _pw.text,
      register: _register,
      name: name,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    widget.state.showError(err);
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    bool obscure = false,
    TextInputType? type,
    Key? key,
    FocusNode? focusNode,
    TextInputAction action = TextInputAction.done,
    VoidCallback? onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
            key: key,
            controller: ctrl,
            focusNode: focusNode,
            obscureText: obscure,
            keyboardType: type,
            textInputAction: action,
            onChanged: (_) {
              widget.state.dismissError();
            },
            onSubmitted: (_) => (onSubmitted ?? _emailAuth)(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: B.ink,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: B.muted,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              filled: true,
              fillColor: Colors.white,
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reg = _register;
    return Material(
      color: B.page,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // brand hero / login banner
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
              child: Container(
                decoration: const BoxDecoration(gradient: B.grad),
                child: Stack(
                  children: [
                    // soft radial highlight in the top-right corner
                    Positioned(
                      top: -52,
                      right: -36,
                      child: Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: .10),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 64, 26, 34),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .18),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/logos/thrive-unicolor.png',
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 13),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FAMILY FINANCE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.6,
                                      color: Colors.white.withValues(
                                        alpha: .82,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Thrive',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Every euro, every account — in sync for the '
                            'whole family.',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              letterSpacing: -.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // form
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    reg ? 'Create your account' : 'Welcome back',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                      color: B.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reg
                        ? 'Set up your family workspace in seconds.'
                        : 'Sign in to your family workspace.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: B.soft2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Google button (requires additional provider setup).
                  GestureDetector(
                    key: const ValueKey('auth-google'),
                    onTap: _busy ? null : _googleAuth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: B.line),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _googleLogo(size: 19),
                          const SizedBox(width: 10),
                          const Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: B.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // OR divider
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Divider(color: B.line, height: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: const Text(
                            'OR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .5,
                              color: B.muted,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: B.line, height: 1),
                        ),
                      ],
                    ),
                  ),
                  if (reg)
                    _field(
                      'Full name',
                      _name,
                      'Eva Janssen',
                      key: const ValueKey('auth-name'),
                      action: TextInputAction.next,
                      onSubmitted: () => _emailFocus.requestFocus(),
                    ),
                  _field(
                    'Email',
                    _email,
                    'you@email.com',
                    type: TextInputType.emailAddress,
                    key: const ValueKey('auth-email'),
                    focusNode: _emailFocus,
                    action: TextInputAction.next,
                    onSubmitted: () => _pwFocus.requestFocus(),
                  ),
                  _field(
                    'Password',
                    _pw,
                    '••••••••',
                    obscure: true,
                    key: const ValueKey('auth-pw'),
                    focusNode: _pwFocus,
                    action: TextInputAction.done,
                    onSubmitted: _emailAuth,
                  ),
                  GestureDetector(
                    key: const ValueKey('auth-submit'),
                    onTap: _busy ? null : _emailAuth,
                    child: Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: B.primary.withValues(alpha: _busy ? .7 : 1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _busy
                            ? 'Please wait…'
                            : (reg ? 'Create account' : 'Sign in'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: GestureDetector(
                      key: const ValueKey('auth-toggle'),
                      onTap: () {
                        setState(() => _register = !_register);
                        widget.state.dismissError();
                      },
                      child: Text.rich(
                        TextSpan(
                          text: reg
                              ? 'Already have an account? '
                              : 'New to Thrive? ',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: B.soft2,
                          ),
                          children: [
                            TextSpan(
                              text: reg ? 'Sign in' : 'Create one',
                              style: const TextStyle(
                                color: B.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Email auth syncs across devices when Firebase is configured',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: B.muted,
                      ),
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
