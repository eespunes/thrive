import 'dart:convert';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('app header uses the current member profile picture', (
    tester,
  ) async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
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
          color: kMemberColors.first,
          photo: png,
          role: 'owner',
        ),
      ],
    );
    await pumpApp(
      tester,
      prefs: {
        'flutter.$kStorageKeyV4': json.encode({
          'year': 2026,
          'monthIdx': 6,
          'screen': 'overview',
          'tab': 'home',
          'familyId': family.id,
          'families': [family.toJson()],
          'workspaces': {family.id: Workspace.empty().toJson()},
        }),
      },
      landOnDefaultTab: true,
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-avatar')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );

    // The profile page (#274) shows the same photo in its identity card.
    await tester.tap(find.byKey(const ValueKey('profile-avatar')));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-photo-btn')), findsOneWidget);
    expect(find.text('Change photo'), findsOneWidget);
  });

  testWidgets('accounts & blocks sub-screens render from the Money card', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToTab(tester, 'settings');
    // Accounts sub-screen (#328).
    expect(find.text('Accounts'), findsWidgets);
    expect(find.text("Eva's account"), findsOneWidget);
    expect(find.text('Short · Eva'), findsOneWidget);
    expect(find.byKey(const ValueKey('list-add-input')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-back')));
    await tester.pumpAndSettle();
    // Budget blocks sub-screen (#329).
    await tapHubRow(tester, 'money', 'more-blocks');
    expect(find.text('Budget blocks'), findsWidgets);
    expect(find.byKey(const ValueKey('blocks-warn-toggle')), findsOneWidget);
    expect(find.text('Warn near block limits'), findsOneWidget);
  });

  testWidgets('add a new account opens its studio and saves', (tester) async {
    await pumpApp(tester);
    await goToTab(tester, 'settings');
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'Travel fund',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    // Add-then-open: the studio opens on the freshly created account.
    expect(find.text('Edit account'), findsOneWidget);
    expect(find.text('Travel fund'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('acc-short')), 'TR');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(find.text('Travel fund'), findsOneWidget);
    expect(find.text('Short · TR'), findsOneWidget);
  });

  testWidgets('edit an existing account requires the short label', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToTab(tester, 'settings');
    await tester.tap(find.byKey(const ValueKey('accounts-row-eva')));
    await tester.pumpAndSettle();
    expect(find.text('Edit account'), findsOneWidget);
    // Clearing the required short label greys the save button out.
    await tester.enterText(find.byKey(const ValueKey('acc-short')), '');
    await tester.pump();
    var box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey('studio-save')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect((box.decoration as BoxDecoration?)?.color, const Color(0xffe2e8f0));
    await tester.enterText(find.byKey(const ValueKey('acc-short')), 'EV');
    await tester.pump(const Duration(milliseconds: 200));
    box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey('studio-save')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      (box.decoration as BoxDecoration?)?.color,
      isNot(const Color(0xffe2e8f0)),
    );
  });

  testWidgets('add a block with this-month-only + end dates via the studio', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToTab(tester, 'blocks');
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'Kids',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    expect(find.text('Edit block'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('block-applies-month')));
    await tester.pump();
    // The amber this-month-only note appears.
    expect(find.textContaining('Only appears in'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('block-enddate')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(find.text('Kids'), findsOneWidget);
    // Amber "this month only" value + end dates on the row.
    expect(find.textContaining('only · end dates'), findsOneWidget);
  });

  testWidgets('receives direction hides limit, end date and savings', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToTab(tester, 'blocks');
    await tester.tap(find.byKey(const ValueKey('blocks-row-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('block-limit')), findsOneWidget);
    expect(find.byKey(const ValueKey('block-enddate')), findsOneWidget);
    expect(find.byKey(const ValueKey('block-savings')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('block-dir-in')));
    await tester.pump();
    expect(find.byKey(const ValueKey('block-limit')), findsNothing);
    expect(find.byKey(const ValueKey('block-enddate')), findsNothing);
    expect(find.byKey(const ValueKey('block-savings')), findsNothing);
  });

  testWidgets('delete account confirms then signs out', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tapHubRow(tester, 'account', 'more-delete-account');
    // The hardened confirm (#280) requires typing DELETE before the button
    // arms; the untyped button is a no-op.
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('da-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('da-input')), 'delete');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('da-confirm')));
    await tester.pumpAndSettle();
    // Deleting the account signs the user out, landing on the auth gate.
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('delete account leaves a shared family for its other members', (
    tester,
  ) async {
    await pumpApp(tester, prefs: joinableFamilyPrefs());
    // Join the demo family, which already has other members.
    await tester.tap(find.byKey(const ValueKey('profile-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-join-family')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('jf-username')),
      'vanderberg',
    );
    await tester.enterText(find.byKey(const ValueKey('jf-password')), 'demo');
    await tester.tap(find.text('Join family'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-back')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tapHubRow(tester, 'account', 'more-delete-account');
    // The confirm names the real consequence for a shared family.
    expect(
      find.textContaining(
        'Removes you from 2 shared families. Then you’re signed out.',
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const ValueKey('da-input')), 'DELETE');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('da-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
