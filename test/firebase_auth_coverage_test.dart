// ignore_for_file: depend_on_referenced_packages, unnecessary_import, prefer_final_fields, unused_element_parameter, unnecessary_underscores
import 'package:family_money_management_app/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_auth_platform_interface/src/platform_interface/platform_interface_multi_factor.dart';
import 'package:firebase_auth_platform_interface/src/method_channel/method_channel_firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

import 'helpers.dart';

class _NoopMultiFactor extends MultiFactorPlatform {
  _NoopMultiFactor(super.auth);
}

class _FakeUser extends UserPlatform {
  _FakeUser({
    required FirebaseAuthPlatform auth,
    required MultiFactorPlatform multiFactor,
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
  }) : _uid = uid,
       _email = email,
       _displayName = displayName,
       _photoUrl = photoUrl,
       super(
         auth,
         multiFactor,
         InternalUserDetails(
           userInfo: InternalUserInfo(
             uid: uid,
             email: email,
             displayName: displayName,
             photoUrl: photoUrl,
             phoneNumber: null,
             isAnonymous: false,
             isEmailVerified: true,
             providerId: 'google.com',
             tenantId: null,
             refreshToken: null,
             creationTimestamp: 0,
             lastSignInTimestamp: 0,
           ),
           providerData: const [],
         ),
       );

  final String _uid;
  String _email;
  String? _displayName;
  String? _photoUrl;

  @override
  String get uid => _uid;

  @override
  String? get email => _email;

  @override
  String? get displayName => _displayName;

  @override
  String? get photoURL => _photoUrl;

  int deleteCalls = 0;
  int verificationEmails = 0;

  @override
  Future<void> delete() async => deleteCalls += 1;

  @override
  Future<void> sendEmailVerification(
    ActionCodeSettings? actionCodeSettings,
  ) async => verificationEmails += 1;

  @override
  Future<void> updateProfile(Map<String, String?> profile) async {
    _displayName = profile['displayName'] ?? _displayName;
    _photoUrl = profile['photoURL'] ?? _photoUrl;
  }
}

class _FakeUserCredential extends UserCredentialPlatform {
  _FakeUserCredential({required super.auth, required super.user});
}

class _FakeFirebaseAuthPlatform extends FirebaseAuthPlatform {
  _FakeFirebaseAuthPlatform({required FirebaseApp app})
    : super(appInstance: app);

  UserCredentialPlatform Function(String email, String password)? onCreateUser;
  UserCredentialPlatform Function(String email, String password)? onSignInEmail;
  UserCredentialPlatform Function(AuthCredential credential)?
  onSignInCredential;
  int signOutCalls = 0;
  int createUserCalls = 0;
  int signInEmailCalls = 0;
  int signInCredentialCalls = 0;
  UserPlatform? _currentUser;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) {
    if (currentUser != null) {
      final info = currentUser.userInfo;
      _currentUser = _FakeUser(
        auth: this,
        multiFactor: _NoopMultiFactor(this),
        uid: info.uid,
        email: info.email ?? '',
        displayName: info.displayName,
        photoUrl: info.photoUrl,
      );
    }
    return this;
  }

  @override
  UserPlatform? get currentUser => _currentUser;

  @override
  set currentUser(UserPlatform? userPlatform) {
    _currentUser = userPlatform;
  }

  @override
  Future<UserCredentialPlatform> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    createUserCalls += 1;
    final handler = onCreateUser;
    if (handler == null) {
      throw UnimplementedError('createUserWithEmailAndPassword not stubbed');
    }
    return handler(email, password);
  }

  @override
  Future<UserCredentialPlatform> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    signInEmailCalls += 1;
    final handler = onSignInEmail;
    if (handler == null) {
      throw UnimplementedError('signInWithEmailAndPassword not stubbed');
    }
    return handler(email, password);
  }

  @override
  Future<UserCredentialPlatform> signInWithCredential(
    AuthCredential credential,
  ) async {
    signInCredentialCalls += 1;
    final handler = onSignInCredential;
    if (handler == null) {
      throw UnimplementedError('signInWithCredential not stubbed');
    }
    return handler(credential);
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}

// FirebaseAuth.instance caches the first platform delegate it sees for the
// app, so every test drives the same fake, reset to a clean state.
_FakeFirebaseAuthPlatform? _authFake;
_FakeFirebaseAuthPlatform _sharedAuth() {
  final auth = _authFake ??= _FakeFirebaseAuthPlatform(app: Firebase.app());
  auth
    ..onCreateUser = null
    ..onSignInEmail = null
    ..onSignInCredential = null
    ..signOutCalls = 0
    ..createUserCalls = 0
    ..signInEmailCalls = 0
    ..signInCredentialCalls = 0
    ..currentUser = null;
  return auth;
}

class _FakeGoogleSignInPlatform extends GoogleSignInPlatform {
  _FakeGoogleSignInPlatform({
    this.authResult,
    this.idToken,
    this.authError,
    this.supportsAuth = true,
  });

  final GoogleSignInUserData? authResult;
  final String? idToken;
  final Object? authError;
  final bool supportsAuth;
  int signOutCalls = 0;

  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) => null;

  @override
  bool supportsAuthenticate() => supportsAuth;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    if (authError != null) throw authError!;
    final user = authResult;
    if (user == null) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
    }
    return AuthenticationResults(
      user: user,
      authenticationTokens: AuthenticationTokenData(idToken: idToken),
    );
  }

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<void> signOut(SignOutParams params) async {
    signOutCalls += 1;
  }

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  setUp(() {
    app.firebaseAppsAvailableOverride = () => true;
  });

  tearDown(() async {
    app.firebaseAppsAvailableOverride = null;
    app.allowlistCheckOverride = null;
    FirebaseAuthPlatform.instance = MethodChannelFirebaseAuth.instance;
    GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform();
  });

  testWidgets('firebase-backed email sign in uses auth and display name', (
    tester,
  ) async {
    await Firebase.initializeApp();
    final auth = _sharedAuth();
    auth.onCreateUser = (email, password) {
      final user = _FakeUser(
        auth: auth,
        multiFactor: _NoopMultiFactor(auth),
        uid: 'uid-create',
        email: email,
      );
      return _FakeUserCredential(auth: auth, user: user);
    };
    auth.onSignInEmail = (email, password) {
      final user = _FakeUser(
        auth: auth,
        multiFactor: _NoopMultiFactor(auth),
        uid: 'uid-signin',
        email: email,
      );
      return _FakeUserCredential(auth: auth, user: user);
    };
    FirebaseAuthPlatform.instance = auth;
    GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform();

    await pumpApp(tester, signedIn: false);
    expect(app.firebaseAppsAvailable, isTrue);

    expect(
      await app.thriveDebug.signInWithEmail(
        email: 'ada@example.com',
        password: 'secret1',
        register: true,
        name: 'Ada Lovelace',
      ),
      isNull,
    );
    expect(auth.createUserCalls, 1);
    expect(app.thriveDebug.user?.name, 'Ada Lovelace');

    expect(
      await app.thriveDebug.signInWithEmail(
        email: 'jane.doe@example.com',
        password: 'secret1',
        register: false,
      ),
      isNull,
    );
    expect(auth.signInEmailCalls, 1);
    expect(app.thriveDebug.user?.name, 'Jane Doe');

    app.thriveDebug.signOut();
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
    auth.onCreateUser = (_, __) => throw FirebaseAuthException(
      code: 'email-already-in-use',
      message: 'used',
    );
    final createResult = await app.thriveDebug.signInWithEmail(
      email: 'used@example.com',
      password: 'secret1',
      register: true,
    );
    expect(auth.createUserCalls, 2);
    expect(createResult, 'Email is already in use');

    auth.onSignInEmail = (_, __) =>
        throw FirebaseAuthException(code: 'invalid-email', message: 'bad');
    final invalidEmailResult = await app.thriveDebug.signInWithEmail(
      email: 'bad',
      password: 'secret1',
      register: false,
    );
    expect(auth.signInEmailCalls, 2);
    expect(invalidEmailResult, 'Enter a valid email');

    auth.onCreateUser = (_, __) =>
        throw FirebaseAuthException(code: 'weak-password', message: 'weak');
    final weakPasswordResult = await app.thriveDebug.signInWithEmail(
      email: 'weak@example.com',
      password: '123',
      register: true,
    );
    expect(auth.createUserCalls, 3);
    expect(weakPasswordResult, 'Password is too weak');

    auth.onSignInEmail = (_, __) =>
        throw FirebaseAuthException(code: 'wrong-password', message: 'wrong');
    final wrongPasswordResult = await app.thriveDebug.signInWithEmail(
      email: 'wrong@example.com',
      password: 'bad',
      register: false,
    );
    expect(auth.signInEmailCalls, 3);
    expect(wrongPasswordResult, 'Wrong email or password');

    auth.onSignInCredential = (credential) {
      final user = _FakeUser(
        auth: auth,
        multiFactor: _NoopMultiFactor(auth),
        uid: 'uid-google',
        email: 'eva@example.com',
        displayName: 'Eva Google',
        photoUrl: 'https://example.com/photo.png',
      );
      return _FakeUserCredential(auth: auth, user: user);
    };
    GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform(
      authResult: GoogleSignInUserData(
        email: 'eva@example.com',
        id: 'google-id',
        displayName: 'Eva G',
        photoUrl: 'https://example.com/photo.png',
      ),
      idToken: 'google-id-token',
    );
    final googleSuccessResult = await app.thriveDebug.signInWithGoogle();
    expect(auth.signInCredentialCalls, 1);
    expect(googleSuccessResult, isNull);
    expect(app.thriveDebug.user?.name, 'Eva Google');

    auth.currentUser = _FakeUser(
      auth: auth,
      multiFactor: _NoopMultiFactor(auth),
      uid: 'uid-cloud',
      email: 'cloud@example.com',
      displayName: 'Cloud User',
    );
    app.thriveDebug.setApplyingCloudSnapshot(true);
    app.thriveDebug.saveProfile('Cloud User', null, Colors.green);
    app.thriveDebug.renameFamily('Cloud Family');
    app.thriveDebug.createFamily('Cloud Split');
    await tester.pumpAndSettle();
    app.thriveDebug.setApplyingCloudSnapshot(false);

    GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform();
    final googleCancelledResult = await app.thriveDebug.signInWithGoogle();
    expect(googleCancelledResult, 'Google sign-in cancelled');

    GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform(
      authResult: GoogleSignInUserData(
        email: 'missing@example.com',
        id: 'missing-id',
        displayName: 'Missing Token',
      ),
    );
    final missingTokenResult = await app.thriveDebug.signInWithGoogle();
    expect(missingTokenResult, 'Google sign-in failed (missing id token)');

    auth.onSignInCredential = (_) => throw FirebaseAuthException(
      code: 'operation-not-allowed',
      message: 'disabled',
    );
    GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform(
      authResult: GoogleSignInUserData(
        email: 'error@example.com',
        id: 'error-id',
        displayName: 'Error',
      ),
      idToken: 'error-token',
    );
    final operationNotAllowedResult = await app.thriveDebug.signInWithGoogle();
    expect(
      operationNotAllowedResult,
      'Google sign-in is disabled in Firebase Auth',
    );

    GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform(
      authError: const GoogleSignInException(
        code: GoogleSignInExceptionCode.interrupted,
      ),
    );
    final platformFailureResult = await app.thriveDebug.signInWithGoogle();
    expect(platformFailureResult, 'Google sign-in failed on device');

    GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform(
      supportsAuth: false,
    );
    final unsupportedResult = await app.thriveDebug.signInWithGoogle();
    expect(unsupportedResult, 'Google sign-in is not supported on this device');
  });

  testWidgets('sign-in turns away accounts that are not on the allowlist', (
    tester,
  ) async {
    await Firebase.initializeApp();
    final auth = _sharedAuth();
    late _FakeUser lastUser;
    UserCredentialPlatform credentialFor(String email) {
      lastUser = _FakeUser(
        auth: auth,
        multiFactor: _NoopMultiFactor(auth),
        uid: 'uid-$email',
        email: email,
      );
      return _FakeUserCredential(auth: auth, user: lastUser);
    }

    auth.onCreateUser = (email, _) => credentialFor(email);
    auth.onSignInEmail = (email, _) => credentialFor(email);
    auth.onSignInCredential = (_) => credentialFor('kid@example.com');
    FirebaseAuthPlatform.instance = auth;
    GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform();

    var status = app.AllowlistStatus.notInvited;
    final checked = <String?>[];
    app.allowlistCheckOverride = (user) async {
      checked.add(user.email);
      return status;
    };

    await pumpApp(tester, signedIn: false);

    // A brand-new uninvited account is deleted again and signed out.
    expect(
      await app.thriveDebug.signInWithEmail(
        email: 'stranger@example.com',
        password: 'secret1',
        register: true,
        name: 'Stranger',
      ),
      app.kNotInvitedMessage,
    );
    expect(lastUser.deleteCalls, 1);
    expect(auth.signOutCalls, 1);
    expect(app.thriveDebug.user, isNull);

    // An existing account that's not invited is only signed out.
    expect(
      await app.thriveDebug.signInWithEmail(
        email: 'old@example.com',
        password: 'secret1',
        register: false,
      ),
      app.kNotInvitedMessage,
    );
    expect(lastUser.deleteCalls, 0);
    expect(auth.signOutCalls, 2);

    // An unverified email gets a verification link instead.
    status = app.AllowlistStatus.unverified;
    expect(
      await app.thriveDebug.signInWithEmail(
        email: 'new@example.com',
        password: 'secret1',
        register: true,
      ),
      app.verifyEmailMessage('new@example.com'),
    );
    expect(lastUser.verificationEmails, 1);
    expect(lastUser.deleteCalls, 0);
    expect(app.thriveDebug.user, isNull);

    // Google sign-in goes through the same gate.
    status = app.AllowlistStatus.notInvited;
    GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform(
      authResult: GoogleSignInUserData(email: 'kid@example.com', id: 'kid'),
      idToken: 'kid-token',
    );
    expect(await app.thriveDebug.signInWithGoogle(), app.kNotInvitedMessage);
    expect(app.thriveDebug.user, isNull);

    // Allowed, or a check that couldn't run, signs in as usual.
    for (final ok in [
      app.AllowlistStatus.allowed,
      app.AllowlistStatus.unknown,
    ]) {
      status = ok;
      expect(
        await app.thriveDebug.signInWithEmail(
          email: 'mum@example.com',
          password: 'secret1',
          register: false,
        ),
        isNull,
      );
      expect(app.thriveDebug.user?.email, 'mum@example.com');
      app.thriveDebug.signOut();
      await tester.pumpAndSettle();
    }
    expect(checked, [
      'stranger@example.com',
      'old@example.com',
      'new@example.com',
      'kid@example.com',
      'mum@example.com',
      'mum@example.com',
    ]);
  });

  test('allowlist messages', () {
    expect(app.kNotInvitedMessage, contains('isn\u2019t invited'));
    expect(
      app.verifyEmailMessage('a@b.co'),
      'We sent a link to a@b.co. Verify your email, then sign in again.',
    );
  });
}
