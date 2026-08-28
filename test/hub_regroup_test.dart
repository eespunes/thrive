import 'dart:convert';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Seeds a deterministic family + workspace so the hub's live values (#330)
/// can be asserted as exact strings.
Map<String, Object> seededHubPrefs() {
  final family = Family(
    id: 'fam_main',
    name: 'Janssen family',
    username: 'janssen',
    members: [
      FamilyMember(
        id: 'me',
        name: 'Eva Janssen',
        email: 'eva.janssen@gmail.com',
        initials: 'EJ',
        color: kMemberColors[0],
        role: 'owner',
      ),
      FamilyMember(
        id: 'm2',
        name: 'Erik Janssen',
        email: 'erik.janssen@outlook.com',
        initials: 'EJ',
        color: kMemberColors[1],
        role: 'member',
      ),
      FamilyMember(
        id: 'm3',
        name: 'Lisa Janssen',
        email: 'lisa.j@icloud.com',
        initials: 'LJ',
        color: kMemberColors[2],
        role: 'member',
        status: 'invited',
      ),
    ],
  );
  final ws = Workspace.empty()
    ..accounts = defaultAccounts()
    ..cats = defaultCats();
  ws.calendarLayers.addAll(kDefaultCalendarLayers());
  ws.eventCategories.addAll([
    EventCategory(
      id: 'ec1',
      name: 'Family',
      color: const Color(0xff7c3aed),
      icon: 'users',
    ),
    EventCategory(
      id: 'ec2',
      name: 'Work',
      color: const Color(0xff1684B4),
      icon: 'briefcase',
    ),
  ]);
  ws.importedCalendars.add(
    ImportedCalendar(
      id: 'imp1',
      name: 'School holidays NL',
      provider: 'ics',
      color: const Color(0xffd97706),
    ),
  );
  ws.cards.add(
    DiscountCard(
      id: 'k1',
      name: 'Albert Heijn',
      number: '2620 1234 5678',
      color: const Color(0xff0f9d6a),
    ),
  );
  return {
    'flutter.$kStorageKeyV4': json.encode({
      'year': 2026,
      'monthIdx': 6,
      'screen': 'overview',
      'tab': 'home',
      'familyId': family.id,
      'families': [family.toJson()],
      'workspaces': {family.id: ws.toJson()},
    }),
  };
}

Future<void> openMore(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-more')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hub hero: family pill carries the member count and the '
      'create-or-join entry opens both flows', (tester) async {
    await pumpApp(tester, prefs: seededHubPrefs(), landOnDefaultTab: true);
    await openMore(tester);

    expect(find.text('Janssen family · 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('hub-fam-add')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hub-fam-add')));
    await tester.pumpAndSettle();
    expect(find.text('Create or join a family'), findsWidgets);
    expect(find.byKey(const ValueKey('hub-create-family')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hub-join-family')));
    await tester.pumpAndSettle();
    expect(find.text('Join family'), findsWidgets);

    // Back out of the pushed join page (#284) and take the create branch.
    await tester.tap(find.byKey(const ValueKey('studio-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hub-fam-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hub-create-family')));
    await tester.pumpAndSettle();
    expect(find.text('Create family'), findsWidgets);
  });

  testWidgets('Planning card: live value strings for seeded data', (
    tester,
  ) async {
    await pumpApp(tester, prefs: seededHubPrefs(), landOnDefaultTab: true);
    await openMore(tester);
    await openHubCard(tester, 'planning', 'more-weekly');

    expect(find.text('0 of 7 planned'), findsOneWidget);
    expect(find.text('2 badges'), findsOneWidget);
    expect(find.text('Member colours'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget); // active only, not invited
    expect(find.text('All synced'), findsOneWidget);
    expect(find.text('3 of 3 on'), findsOneWidget);
    expect(find.text('3 of 3 layers'), findsOneWidget); // kitchen wall on
  });

  testWidgets('Planning card: a failing import flips the value amber', (
    tester,
  ) async {
    await pumpApp(tester, prefs: seededHubPrefs(), landOnDefaultTab: true);
    await openMore(tester);
    await openHubCard(tester, 'planning', 'more-weekly');
    expect(find.text('All synced'), findsOneWidget);

    thriveDebug.markImportFailed('imp1');
    await tester.pumpAndSettle();
    expect(find.text('All synced'), findsNothing);
    expect(find.text('1 failing'), findsOneWidget);
    expect(thriveDebug.failedImportIds, {'imp1'});
  });

  testWidgets('Money card: discount cards, accounts and budget blocks show '
      'live counts', (tester) async {
    await pumpApp(tester, prefs: seededHubPrefs(), landOnDefaultTab: true);
    await openMore(tester);
    await openHubCard(tester, 'money', 'more-wallet');

    expect(find.text('1 discount card'), findsOneWidget); // card subtitle
    expect(find.text('1 card'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('3 accounts'), findsOneWidget);
    expect(find.text('Budget blocks'), findsOneWidget);
    expect(find.text('${defaultCats().length} blocks'), findsOneWidget);

    // Budget blocks opens the Settings v2 sub-screen (#329).
    await tester.tap(find.byKey(const ValueKey('more-blocks')));
    await tester.pumpAndSettle();
    expect(find.text('Budget blocks'), findsWidgets);
    expect(find.byKey(const ValueKey('blocks-warn-toggle')), findsOneWidget);
  });

  testWidgets('Family card lists members with role, status and avatar', (
    tester,
  ) async {
    await pumpApp(tester, prefs: seededHubPrefs(), landOnDefaultTab: true);
    await openMore(tester);
    await openHubCard(tester, 'family', 'more-member-me');

    expect(find.text('Eva Janssen (you)'), findsOneWidget);
    expect(find.text('OWNER'), findsOneWidget);
    expect(find.text('erik.janssen@outlook.com'), findsOneWidget);
    expect(find.text('Lisa Janssen'), findsOneWidget);
    expect(find.text('INVITED'), findsOneWidget);
    expect(find.text('Invited · hasn’t joined yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('more-invite')), findsOneWidget);
  });

  testWidgets('Account card: reset password sheet sends (or explains) and '
      'FUTURE rows stay pill-ed', (tester) async {
    // An email-provider user gets the real reset row.
    await pumpApp(
      tester,
      prefs: {
        ...seededHubPrefs(),
        'flutter.thrive.user': json.encode({
          'name': 'Eva Janssen',
          'email': 'eva.janssen@gmail.com',
          'initials': 'EJ',
          'provider': 'email',
        }),
      },
      landOnDefaultTab: true,
    );
    await openMore(tester);
    await openHubCard(tester, 'account', 'hub-resetpw');

    expect(find.text('FUTURE'), findsNWidgets(2)); // dark mode + language
    expect(find.text('We’ll email you a reset link'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hub-resetpw')));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('resetpw-send')));
    await tester.pumpAndSettle();
    // No Firebase in tests → the honest failure toast.
    expect(
      find.text('Couldn’t send the link — try again later'),
      findsOneWidget,
    );
  });

  testWidgets('Account card: Google users see reset password disabled', (
    tester,
  ) async {
    await pumpApp(tester, prefs: seededHubPrefs(), landOnDefaultTab: true);
    await openMore(tester);
    await openHubCard(tester, 'account', 'hub-resetpw');

    expect(
      find.text('You sign in with Google — no password here'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('hub-resetpw')));
    await tester.pumpAndSettle();
    expect(
      find.text('You sign in with Google — there’s no password to reset'),
      findsOneWidget,
    );
  });

  testWidgets('Invite & share opens the join-details sheet with copyable '
      'username', (tester) async {
    await pumpApp(tester, prefs: seededHubPrefs(), landOnDefaultTab: true);
    await openMore(tester);
    await tapHubRow(tester, 'family', 'more-invite');
    // The Settings v2 invite sheet (#278): copyable @username and, for a
    // local family with no password, the amber "anyone can join" state.
    expect(find.textContaining('Invite to'), findsOneWidget);
    expect(find.text('@janssen'), findsWidgets);
    expect(find.byKey(const ValueKey('iv-pw-none')), findsOneWidget);
    expect(find.byKey(const ValueKey('iv-copy-user')), findsOneWidget);
  });
}
