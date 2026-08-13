import 'dart:convert';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A signed-in user blob so the auth gate is bypassed in tests. The mock
/// SharedPreferences store prefixes keys with `flutter.`.
final Map<String, Object> _signedInUser = {
  'flutter.thrive.user': json.encode({
    'name': 'Eva Janssen',
    'email': 'eva.janssen@gmail.com',
    'initials': 'EJ',
    'provider': 'google',
  }),
  // Pins this device's local (no-Firebase) self id — normally a random
  // generated id (see `kLocalSelfUidKey`/`myId`) — to the stable, readable
  // literal `'me'`, so existing tests can keep asserting against a fixed id
  // for "the signed-in user" instead of a fresh random one every run.
  'flutter.$kLocalSelfUidKey': 'me',
};

/// A local family registry pre-seeded with a joinable family
/// ("vanderberg" / "demo") that already has two members. The app's built-in
/// demo family was removed (issue #132), so tests that exercise the join flow
/// seed their own joinable family through the registry prefs blob.
Map<String, Object> joinableFamilyPrefs() {
  final reg = {
    'vanderberg': {
      'username': 'vanderberg',
      'password': 'demo',
      'name': 'van der Berg family',
      'picture': null,
      'members': [
        FamilyMember(
          id: 'owner_demo',
          name: 'Sophie van der Berg',
          email: 'sophie@vanderberg.nl',
          initials: 'SB',
          color: kMemberColors[2],
          role: 'owner',
          status: 'active',
        ).toJson(),
        FamilyMember(
          id: 'm_demo2',
          name: 'Tom van der Berg',
          email: 'tom@vanderberg.nl',
          initials: 'TB',
          color: kMemberColors[3],
          role: 'member',
          status: 'active',
        ).toJson(),
      ],
      'workspace': Workspace.empty().toJson(),
    },
  };
  return {'flutter.thrive.registry': json.encode(reg)};
}

/// Boots the app with a clean prefs store (seeds from the bundled asset) and
/// pumps until the async boot completes. Uses a tall surface so the whole
/// overview list builds (no lazy off-screen rows).
///
/// By default a user is seeded so the app lands on the budget screens. Pass
/// `signedIn: false` to exercise the auth gate.
///
/// The app's real default landing tab is Home (issue #149), but almost every
/// existing test assumes it lands directly on the Finance/Overview screen —
/// so by default this helper navigates to the Finance tab right after boot,
/// once the 5-tab shell is actually showing (it's a no-op behind the auth/
/// onboarding gates). Pass `landOnDefaultTab: true` to see the real Home
/// landing instead (used by navigation-specific tests).
Future<void> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  bool signedIn = true,
  bool landOnDefaultTab = false,
}) async {
  tester.view.physicalSize = const Size(1080, 6400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  dismissAppError();
  addTearDown(dismissAppError);
  PackageInfo.setMockInitialValues(
    appName: 'Thrive',
    packageName: 'com.thrive.app',
    version: '2.7.1',
    buildNumber: '46',
    buildSignature: '',
  );
  SharedPreferences.setMockInitialValues({
    if (signedIn) ..._signedInUser,
    ...prefs,
  });
  await tester.runAsync(() async {
    await tester.pumpWidget(const ThriveApp());
    // Let the SharedPreferences + rootBundle asset futures resolve.
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
  await tester.pump();
  await tester.pumpAndSettle(const Duration(milliseconds: 100));

  if (!landOnDefaultTab) {
    final financeTab = find.byKey(const ValueKey('nav-finance'));
    if (financeTab.evaluate().isNotEmpty) {
      await tester.tap(financeTab);
      await tester.pumpAndSettle();
    }
  }
}

/// Boots a fresh ThriveApp WITHOUT clearing the mock prefs store, so the app
/// takes the `_restore` path from previously-persisted state. Call after a
/// prior pumpApp + interaction in the same test.
Future<void> rebootApp(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const ThriveApp());
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
  await tester.pump();
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

/// Navigates to a Finance sub-screen (overview | stats), or to Finance
/// settings via the More hub (settings). `settings` moved out of the Finance
/// switcher and behind More → Finance settings when the 5-tab nav shipped
/// (issue #149); `overview`/`stats` still live in the Finance tab's own
/// switcher.
Future<void> goToTab(WidgetTester tester, String tab) async {
  if (tab == 'settings') {
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('more-finsettings')));
    await tester.pumpAndSettle();
    return;
  }
  if (find.byKey(ValueKey('tab-$tab')).evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('nav-finance')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(ValueKey('tab-$tab')));
  await tester.pumpAndSettle();
}

/// First income row label present in the June seed.
String firstIncomeLabel(WidgetTester tester) {
  for (final l in ['SALARY', 'TOESLAGEN', 'VORIGE MAAND']) {
    if (find.text(l).evaluate().isNotEmpty) return l;
  }
  return 'SALARY';
}

/// Returns a finder positioned over the first expense row so a drag gesture can
/// trigger swipe-to-delete. Returns null if no such row is on screen.
Finder? swipeRows(WidgetTester tester) {
  for (final l in ['RENT', 'WATER', 'GROCERIES', 'New cost']) {
    final f = find.text(l);
    if (f.evaluate().isNotEmpty) return f.first;
  }
  return null;
}
