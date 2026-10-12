import 'dart:convert';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'settings_v2_seed.dart';

/// Kid accounts (`Kid Accounts.dc.html`): Flow A (an admin marks a member as
/// a kid) and Flow B (an admin gives a login-less kid profile a login), in
/// local/demo mode where the callables run against the local family.
Map<String, Object> _kidPrefs() {
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
    ).toJson(),
  );
  return {...prefs, key: json.encode(data)};
}

/// The signed-in user ('me') is a kid with an admin-made email login; Erik
/// ('m2') owns the family and made the change.
Map<String, Object> _meKidPrefs() {
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
    ..['accessChange'] = {
      'to': 'kid',
      'by': 'Erik',
      'byId': 'm2',
      'at': 1700000000000,
    };
  members[1]['role'] = 'owner';
  return {...prefs, key: json.encode(data)};
}

Future<void> _openStudio(WidgetTester tester, String memberId) async {
  await pumpApp(tester, prefs: _kidPrefs(), landOnDefaultTab: true);
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
}
