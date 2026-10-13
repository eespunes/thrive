import 'dart:convert';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'settings_v2_seed.dart';

/// Kid accounts (`Kid Accounts.dc.html`): Flow A (an admin marks a member as
/// a kid) and Flow B (an admin gives a login-less kid profile a login), in
/// local/demo mode where the callables run against the local family.
Map<String, Object> _kidPrefs({
  Map<String, Object?> login = const {},
  bool meAdmin = true,
}) {
  final prefs = settingsV2Prefs();
  final key = 'flutter.$kStorageKeyV4';
  final data = json.decode(prefs[key]! as String) as Map<String, dynamic>;
  final fam = (data['families'] as List).first as Map<String, dynamic>;
  (fam['members'] as List).add(
    FamilyMember(
      id: 'k1',
      name: 'Liv Janssen',
      email: '',
      initials: 'LJ',
      color: kMemberColors[5],
      role: 'kid',
    ).toJson()..addAll(login),
  );
  if (!meAdmin) {
    final members = (fam['members'] as List).cast<Map<String, dynamic>>();
    members[0]['role'] = 'member';
    members[1]['role'] = 'owner';
  }
  return {...prefs, key: json.encode(data)};
}

/// The signed-in user ('me') is a kid with an admin-made email login; Erik
/// ('m2') owns the family and made the change.
Map<String, Object> _meKidPrefs({String? accessTo = 'kid'}) {
  final prefs = settingsV2Prefs();
  final key = 'flutter.$kStorageKeyV4';
  final data = json.decode(prefs[key]! as String) as Map<String, dynamic>;
  final fam = (data['families'] as List).first as Map<String, dynamic>;
  final members = (fam['members'] as List).cast<Map<String, dynamic>>();
  members[0]
    ..['role'] = 'kid'
    ..['loginMethod'] = 'email'
    ..['loginEmail'] = 'eva.kid@gmail.com'
    ..['managed'] = true
    ..['accessChange'] = accessTo == null
        ? null
        : {'to': accessTo, 'by': 'Erik', 'byId': 'm2', 'at': 1700000000000};
  members[1]['role'] = 'owner';
  return {...prefs, key: json.encode(data)};
}

Future<void> _openStudio(
  WidgetTester tester,
  String memberId, {
  Map<String, Object>? prefs,
}) async {
  await pumpApp(tester, prefs: prefs ?? _kidPrefs(), landOnDefaultTab: true);
  await openMoreHub(tester);
  await tapHubRow(tester, 'planning', 'more-memcolors');
  await tester.tap(find.byKey(ValueKey('memcolors-row-$memberId')));
  await tester.pumpAndSettle();
}

FamilyMember _member(String id) =>
    thriveDebug.curFamily()!.members.firstWhere((m) => m.id == id);

void main() {
  group('helpers', () {
    test('password strength: under 10 characters is weak', () {
      expect(passwordStrength(''), PasswordStrength.weak);
      expect(passwordStrength('short1'), PasswordStrength.weak);
      expect(passwordStrength('longer-password'), isNot(PasswordStrength.weak));
    });

    test('generated passwords are word-word-word-NN and strong enough', () {
      for (var i = 0; i < 20; i++) {
        final p = generateKidPassword();
        expect(p, matches(RegExp(r'^[a-z]+-[a-z]+-[a-z]+-\d\d$')));
        expect(p.length, greaterThanOrEqualTo(kKidPasswordMinLength));
        expect(passwordStrength(p), isNot(PasswordStrength.weak));
      }
    });

    test('callable errors: offline codes and a readable toString', () {
      for (final c in ['unavailable', 'deadline-exceeded', 'internal']) {
        expect(KidLoginError(c).offline, isTrue, reason: c);
      }
      const e = KidLoginError('already-exists', reason: 'member');
      expect(e.offline, isFalse);
      expect(e.toString(), 'KidLoginError(already-exists, member)');
    });

    test('last sign-in: never, today with time, else a short date', () {
      expect(kidLastSignIn(null), 'Never');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 9, 5);
      expect(kidLastSignIn(today.millisecondsSinceEpoch), 'Today, 09:05');
      final old = DateTime(2024, 10, 12).millisecondsSinceEpoch;
      expect(kidLastSignIn(old), kidShortDate(old));
      expect(kidLastSignIn(old), contains('Oct'));
    });

    test('login email validation', () {
      expect(isValidLoginEmail('liv@gmail.com'), isTrue);
      expect(isValidLoginEmail('liv@'), isFalse);
      expect(isValidLoginEmail('liv gmail.com'), isFalse);
    });

    test('member row subtitle and pill', () {
      final kid = FamilyMember(
        id: 'k',
        name: 'Liv',
        email: '',
        initials: 'L',
        color: kMemberColors[0],
        role: 'kid',
      );
      expect(memberRowSubtitle(kid, loginless: true), 'Kid · no login');
      expect(memberRowPill(false, kid), isNull);
      kid
        ..loginMethod = 'email'
        ..managed = true
        ..uid = 'u1';
      expect(
        memberRowSubtitle(kid, loginless: false),
        'Kid · own login (Email, managed by admins)',
      );
      expect(memberRowPill(false, kid)?.label, 'Managed');
      kid
        ..loginMethod = 'google'
        ..managed = false
        ..uid = null;
      expect(memberRowSubtitle(kid, loginless: false), contains('pending'));
      expect(memberRowPill(false, kid)?.label, 'Pending');
    });
  });

  testWidgets('Flow B: give a kid an email login, hand it off, remove it', (
    tester,
  ) async {
    await _openStudio(tester, 'k1');
    expect(find.byKey(const ValueKey('kid-login-none')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('kid-give-login')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kid-method-email')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('kid-email')),
      'liv.janssen@gmail.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('kid-password')),
      'tiger-maple-river-42',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('kid-create-login')));
    await tester.pumpAndSettle();

    // The handoff screen shows the new sign-in details.
    expect(find.text('Login created'), findsOneWidget);
    expect(find.byKey(const ValueKey('kid-handoff-email')), findsOneWidget);
    expect(_member('k1').loginMethod, 'email');
    expect(_member('k1').managed, isTrue);
    expect(_member('k1').loginEmail, 'liv.janssen@gmail.com');

    // Leaving before saving the password asks first.
    await tester.tap(find.byKey(const ValueKey('kid-handoff-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kid-handoff-stay')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('kid-handoff-stay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kid-handoff-copy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kid-handoff-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kid-handoff-stay')), findsNothing);
    expect(find.byKey(const ValueKey('kid-login-managed')), findsOneWidget);

    // Remove the login: back to a profile without one.
    await tester.ensureVisible(find.byKey(const ValueKey('kid-remove-login')));
    await tester.tap(find.byKey(const ValueKey('kid-remove-login')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kid-remove-go')));
    await tester.pumpAndSettle();
    expect(_member('k1').loginMethod, isNull);
    expect(_member('k1').uid, isNull);
    expect(find.byKey(const ValueKey('kid-login-none')), findsOneWidget);
  });

  testWidgets('Flow B: a weak password blocks creating the login', (
    tester,
  ) async {
    await _openStudio(tester, 'k1');
    await tester.tap(find.byKey(const ValueKey('kid-give-login')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kid-method-email')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('kid-email')),
      'liv.janssen@gmail.com',
    );
    await tester.enterText(find.byKey(const ValueKey('kid-password')), 'abc');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('kid-create-login')));
    await tester.pumpAndSettle();
    expect(find.text('Login created'), findsNothing);
    expect(_member('k1').loginMethod, isNull);
  });

  testWidgets('Flow B: linking a Google account leaves the login pending', (
    tester,
  ) async {
    await _openStudio(tester, 'k1');
    await tester.tap(find.byKey(const ValueKey('kid-give-login')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kid-method-google')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('kid-email')),
      'liv.janssen@gmail.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('kid-google-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kid-google-link')));
    await tester.pumpAndSettle();

    expect(_member('k1').loginMethod, 'google');
    expect(_member('k1').loginPending, isTrue);
    expect(find.byKey(const ValueKey('kid-login-pending')), findsOneWidget);

    // Cancelling the link reverts to no login.
    await tester.ensureVisible(find.byKey(const ValueKey('kid-cancel-link')));
    await tester.tap(find.byKey(const ValueKey('kid-cancel-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel link').last);
    await tester.pumpAndSettle();
    expect(_member('k1').loginMethod, isNull);
  });

  testWidgets('only the owner sees the Admin toggle, and it grants admin', (
    tester,
  ) async {
    await _openStudio(tester, 'm2');
    expect(find.byKey(const ValueKey('member-admin-toggle')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('member-admin-toggle')));
    await tester.pumpAndSettle();
    expect(thriveDebug.curFamily()!.adminUids, contains('m2'));

    // An admin can't be made a kid by flipping the toggle off-guard: it
    // asks the owner to confirm, and the member stops being an admin.
    await tester.tap(find.byKey(const ValueKey('member-kid-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kid-access-confirm')));
    await tester.pumpAndSettle();
    expect(_member('m2').role, 'kid');
    expect(thriveDebug.curFamily()!.adminUids, isNot(contains('m2')));
  });

  testWidgets('kid profiles without a login have no Admin toggle', (
    tester,
  ) async {
    await _openStudio(tester, 'k1');
    expect(find.byKey(const ValueKey('member-admin-toggle')), findsNothing);
    expect(find.byKey(const ValueKey('member-kid-toggle')), findsOneWidget);
  });

  testWidgets('a kid sees the access notice once, then the managed note', (
    tester,
  ) async {
    await pumpApp(tester, prefs: _meKidPrefs(), landOnDefaultTab: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kid-access-notice')), findsOneWidget);
    expect(
      find.text('Erik changed your account to a kid account'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('kid-access-notice-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kid-access-notice')), findsNothing);

    // Rebuilds don't bring it back.
    await openMoreHub(tester);
    expect(find.byKey(const ValueKey('kid-access-notice')), findsNothing);

    await openHubCard(tester, 'account', 'more-managed-notice');
    expect(find.byKey(const ValueKey('more-managed-notice')), findsOneWidget);
  });

  group('kid gates', () {
    Future<void> boot(WidgetTester tester) async {
      await pumpApp(
        tester,
        prefs: _meKidPrefs(accessTo: null),
        landOnDefaultTab: true,
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('welcome → first run (next/back) → calendar, once', (
      tester,
    ) async {
      await boot(tester);
      await tester.runAsync(() => thriveDebug.maybeKidWelcome('me'));
      await tester.pumpAndSettle();
      expect(thriveDebug.kidGate.value?.kind, KidGateKind.welcome);
      expect(find.text('Welcome, Eva!'), findsOneWidget);
      expect(find.text('You’re in the Janssen family.'), findsOneWidget);

      await tapKey(tester, 'kid-welcome-go');
      expect(find.byKey(const ValueKey('kid-firstrun-0')), findsOneWidget);
      await tapKey(tester, 'kid-firstrun-next');
      expect(find.byKey(const ValueKey('kid-firstrun-1')), findsOneWidget);
      await tapKey(tester, 'kid-firstrun-back');
      expect(find.byKey(const ValueKey('kid-firstrun-0')), findsOneWidget);
      await tapKey(tester, 'kid-firstrun-next');
      await tapKey(tester, 'kid-firstrun-next');
      expect(find.text('Read-only'), findsOneWidget);
      await tapKey(tester, 'kid-firstrun-done');
      expect(thriveDebug.kidGate.value, isNull);

      // Only once per login (tests have no Firebase uid: it keys on myId).
      await tester.runAsync(() => thriveDebug.maybeKidWelcome('me'));
      expect(thriveDebug.kidGate.value, isNull);
    });

    testWidgets('first run: skip, and the 3-up layout on wide screens', (
      tester,
    ) async {
      await boot(tester);
      thriveDebug.kidGate.value = const KidGate(KidGateKind.firstRun);
      await tester.pumpAndSettle();
      await tapKey(tester, 'kid-firstrun-skip');
      expect(thriveDebug.kidGate.value, isNull);

      tester.view.physicalSize = const Size(2000, 3000);
      thriveDebug.kidGate.value = const KidGate(KidGateKind.firstRun);
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(ValueKey('kid-firstrun-$i')), findsOneWidget);
      }
      await tapKey(tester, 'kid-firstrun-done');
      expect(thriveDebug.kidGate.value, isNull);
    });

    testWidgets('signing in, signed out and not-linked screens', (
      tester,
    ) async {
      await boot(tester);
      thriveDebug.kidGate.value = const KidGate(KidGateKind.signingIn);
      await tester.pump();
      expect(find.text('Signing you in…'), findsOneWidget);

      thriveDebug.kidGate.value = const KidGate(KidGateKind.signedOut);
      await tester.pumpAndSettle();
      expect(
        find.text('You were signed out by a family admin'),
        findsOneWidget,
      );
      await tapKey(tester, 'kid-gate-ok');
      expect(thriveDebug.kidGate.value, isNull);

      thriveDebug.kidGate.value = const KidGate(
        KidGateKind.notLinked,
        email: 'liv@gmail.com',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('liv@gmail.com isn’t linked'), findsOneWidget);
      await tapKey(tester, 'kid-gate-join');
      expect(thriveDebug.kidGate.value, isNull);

      thriveDebug.kidGate.value = const KidGate(KidGateKind.notLinked);
      await tester.pumpAndSettle();
      expect(find.textContaining('This account isn’t linked'), findsOneWidget);
      await tapKey(tester, 'kid-gate-other-google');
      expect(thriveDebug.kidGate.value, isNull);
    });

    testWidgets('a managed kid whose family is dropped sees "removed", '
        'then is signed out', (tester) async {
      await boot(tester);
      thriveDebug.noteKidFamilyDropped('fam_main', 'me');
      await tester.pumpAndSettle();
      final g = thriveDebug.kidGate.value!;
      expect(g.kind, KidGateKind.removed);
      expect(g.signOutOnClose, isTrue);
      expect(
        find.text('Your login was removed by a family admin'),
        findsOneWidget,
      );
      expect(find.textContaining('Ask Erik'), findsOneWidget);
      await tapKey(tester, 'kid-gate-ok');
      expect(thriveDebug.kidGate.value, isNull);
      expect(find.byKey(const ValueKey('more-managed-notice')), findsNothing);
    });

    testWidgets('a kid made a full member again sees the reverse notice', (
      tester,
    ) async {
      await pumpApp(
        tester,
        prefs: _meKidPrefs(accessTo: 'full'),
        landOnDefaultTab: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('Erik made you a full member'), findsOneWidget);
      expect(find.text('You can use all of Thrive again.'), findsOneWidget);
      await tapKey(tester, 'kid-access-notice-ok');
      expect(find.byKey(const ValueKey('kid-access-notice')), findsNothing);
    });
  });

  group('login card', () {
    const emailLogin = {
      'uid': 'local-k1',
      'loginMethod': 'email',
      'loginEmail': 'liv@gmail.com',
      'managed': true,
    };
    Future<void> tapKey(WidgetTester tester, String key) async {
      final f = find.byKey(ValueKey(key));
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    testWidgets('reset password: weak blocked, then the reset handoff', (
      tester,
    ) async {
      await _openStudio(tester, 'k1', prefs: _kidPrefs(login: emailLogin));
      expect(find.byKey(const ValueKey('kid-login-managed')), findsOneWidget);
      await tapKey(tester, 'kid-reset-password');
      expect(find.text('Reset Liv’s password'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('kid-password')), 'ab');
      await tapKey(tester, 'kid-reset-go');
      expect(find.text(kKidWeakPassword), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('kid-password')),
        'tiger-maple-river-42',
      );
      await tester.pump();
      await tapKey(tester, 'kid-reset-go');
      expect(_member('k1').signedOutAt, isNotNull);
      expect(find.byKey(const ValueKey('kid-handoff-email')), findsOneWidget);

      await tapKey(tester, 'kid-handoff-reveal');
      expect(find.text('tiger-maple-river-42'), findsOneWidget);
      await tapKey(tester, 'kid-handoff-card');
      expect(find.byKey(const ValueKey('kid-login-card')), findsOneWidget);
      await tapKey(tester, 'kid-login-card-copy');
      await tapKey(tester, 'kid-handoff-done');
      expect(find.byKey(const ValueKey('kid-handoff-email')), findsNothing);
    });

    testWidgets('leaving the handoff unsaved needs confirming', (tester) async {
      await _openStudio(tester, 'k1', prefs: _kidPrefs(login: emailLogin));
      await tapKey(tester, 'kid-reset-password');
      await tester.enterText(
        find.byKey(const ValueKey('kid-password')),
        'tiger-maple-river-42',
      );
      await tester.pump();
      await tapKey(tester, 'kid-reset-go');
      await tapKey(tester, 'kid-handoff-done');
      await tapKey(tester, 'kid-handoff-leave');
      expect(find.byKey(const ValueKey('kid-handoff-email')), findsNothing);
      expect(find.byKey(const ValueKey('kid-reset-password')), findsOneWidget);
    });

    testWidgets('change email: invalid, taken by a member, then saved', (
      tester,
    ) async {
      await _openStudio(tester, 'k1', prefs: _kidPrefs(login: emailLogin));
      await tapKey(tester, 'kid-change-email');
      await tester.enterText(find.byKey(const ValueKey('kid-new-email')), 'x@');
      await tapKey(tester, 'kid-change-email-go');
      expect(
        find.text('Enter a valid email, like name@example.com.'),
        findsOneWidget,
      );
      final erik = _member('m2').email;
      await tester.enterText(find.byKey(const ValueKey('kid-new-email')), erik);
      await tapKey(tester, 'kid-change-email-go');
      expect(_member('k1').loginEmail, 'liv@gmail.com');
      await tester.enterText(
        find.byKey(const ValueKey('kid-new-email')),
        'Liv.New@Gmail.com',
      );
      await tapKey(tester, 'kid-change-email-go');
      expect(_member('k1').loginEmail, 'liv.new@gmail.com');
    });

    testWidgets('sign out everywhere', (tester) async {
      await _openStudio(tester, 'k1', prefs: _kidPrefs(login: emailLogin));
      await tapKey(tester, 'kid-signout');
      expect(find.text('Sign Liv out everywhere?'), findsOneWidget);
      await tapKey(tester, 'kid-signout-go');
      expect(_member('k1').signedOutAt, isNotNull);
      expect(_member('k1').loginMethod, 'email');
    });

    testWidgets('a pending Google link: copy steps, change account', (
      tester,
    ) async {
      await _openStudio(
        tester,
        'k1',
        prefs: _kidPrefs(
          login: {'loginMethod': 'google', 'loginEmail': 'liv@gmail.com'},
        ),
      );
      expect(find.byKey(const ValueKey('kid-login-pending')), findsOneWidget);
      await tapKey(tester, 'kid-copy-steps');
      await tapKey(tester, 'kid-change-google');
      await tester.enterText(
        find.byKey(const ValueKey('kid-email')),
        'liv.two@gmail.com',
      );
      await tester.pump();
      await tapKey(tester, 'kid-google-continue');
      await tapKey(tester, 'kid-google-link');
      expect(_member('k1').loginEmail, 'liv.two@gmail.com');
    });

    testWidgets('an active Google login can switch account', (tester) async {
      await _openStudio(
        tester,
        'k1',
        prefs: _kidPrefs(
          login: {
            'uid': 'g-k1',
            'loginMethod': 'google',
            'loginEmail': 'liv@gmail.com',
          },
        ),
      );
      expect(find.byKey(const ValueKey('kid-reset-password')), findsNothing);
      await tapKey(tester, 'kid-change-google');
      expect(find.byKey(const ValueKey('kid-email')), findsOneWidget);
    });

    testWidgets('creating a login with a member’s email fails clearly', (
      tester,
    ) async {
      await _openStudio(tester, 'k1');
      await tapKey(tester, 'kid-give-login');
      await tapKey(tester, 'kid-method-email');
      await tester.enterText(
        find.byKey(const ValueKey('kid-email')),
        _member('m2').email,
      );
      await tapKey(tester, 'kid-password-generate');
      await tapKey(tester, 'kid-create-login');
      expect(_member('k1').loginMethod, isNull);
      expect(find.textContaining('Erik'), findsWidgets);
    });

    testWidgets('non-admins only see the method', (tester) async {
      await _openStudio(
        tester,
        'k1',
        prefs: _kidPrefs(login: emailLogin, meAdmin: false),
      );
      expect(find.text('Only admins can see and change this.'), findsOneWidget);
      expect(find.byKey(const ValueKey('kid-reset-password')), findsNothing);
    });

    testWidgets('non-admins can’t give a login', (tester) async {
      await _openStudio(tester, 'k1', prefs: _kidPrefs(meAdmin: false));
      expect(find.text('Only admins can give Liv a login.'), findsOneWidget);
      expect(find.byKey(const ValueKey('kid-give-login')), findsNothing);
    });
  });

  testWidgets('on wide screens the login sheets are dialogs', (tester) async {
    await _openStudio(
      tester,
      'k1',
      prefs: _kidPrefs(
        login: {
          'uid': 'local-k1',
          'loginMethod': 'email',
          'loginEmail': 'liv@gmail.com',
          'managed': true,
        },
      ),
    );
    tester.view.physicalSize = const Size(2000, 3000);
    await tester.pumpAndSettle();
    final f = find.byKey(const ValueKey('kid-signout'));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('kid-signout-go')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(_member('k1').signedOutAt, isNotNull);
  });
}
