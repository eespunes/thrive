import 'dart:convert';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'settings_v2_seed.dart';

/// Boots the app as a signed-in user that has no family yet, which lands on the
/// onboarding gate (create / join a family).
Future<void> pumpOnboarding(WidgetTester tester) async {
  final payload = json.encode({
    'year': 2026,
    'monthIdx': 5,
    'screen': 'overview',
    'familyId': 'none',
    'families': <dynamic>[],
    'workspaces': <String, dynamic>{},
  });
  await pumpApp(
    tester,
    prefs: {'flutter.thrive.v4': payload, ...joinableFamilyPrefs()},
  );
}

void main() {
  test('hashFamilyPassword is deterministic and salted', () {
    final a = hashFamilyPassword('secret', 'salt1');
    final b = hashFamilyPassword('secret', 'salt1');
    final c = hashFamilyPassword('secret', 'salt2');
    expect(a, equals(b));
    expect(a, isNot(equals(c)));
    expect(a.length, equals(64));
  });

  group('onboarding gate', () {
    testWidgets('shows when a signed-in user has no family', (tester) async {
      await pumpOnboarding(tester);
      expect(find.text('One last step'), findsOneWidget);
      expect(find.text('Create a family'), findsWidgets);
      expect(find.text('Join a family'), findsWidgets);
    });

    testWidgets('create flow validates name, username and password', (
      tester,
    ) async {
      await pumpOnboarding(tester);

      // Empty name.
      await tester.tap(find.text('Create family'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a family name'), findsOneWidget);

      // Bad username (too short).
      await tester.enterText(find.byType(TextField).at(0), 'The Smiths');
      await tester.enterText(find.byType(TextField).at(1), 'ab');
      await tester.enterText(find.byType(TextField).at(2), 'secret');
      await tester.tap(find.text('Create family'));
      await tester.pumpAndSettle();
      expect(
        find.text('Username: 3–24 letters, numbers, - or _'),
        findsOneWidget,
      );

      // Short password.
      await tester.enterText(find.byType(TextField).at(1), 'smith-home');
      await tester.enterText(find.byType(TextField).at(2), '12');
      await tester.tap(find.text('Create family'));
      await tester.pumpAndSettle();
      expect(
        find.text('Password must be at least 4 characters'),
        findsOneWidget,
      );
    });

    testWidgets('creating a family dismisses onboarding', (tester) async {
      await pumpOnboarding(tester);
      await tester.enterText(find.byType(TextField).at(0), 'The Smiths');
      await tester.enterText(find.byType(TextField).at(1), 'smith-home');
      await tester.enterText(find.byType(TextField).at(2), 'secret');
      await tester.tap(find.text('Create family'));
      await tester.pumpAndSettle();

      expect(find.text('One last step'), findsNothing);
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets(
      'suggests a username from the family name and flags a bad handle',
      (tester) async {
        await pumpOnboarding(tester);

        // Typing a family name suggests an available username.
        await tester.enterText(find.byType(TextField).at(0), 'The Janssens');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        final username = tester.widget<TextField>(find.byType(TextField).at(1));
        expect(username.controller!.text, 'the-janssens');
        expect(find.text('Suggested · available'), findsOneWidget);

        // Manually editing the username to something invalid shows the hint.
        await tester.enterText(find.byType(TextField).at(1), 'a');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('3–24 letters, numbers, - or _'), findsOneWidget);

        // Clearing the username back to empty re-suggests from the name.
        await tester.enterText(find.byType(TextField).at(1), '');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('Suggested · available'), findsOneWidget);
      },
    );

    testWidgets('flags a taken username on the onboarding create form', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Beach House');
      await tester.enterText(find.byType(TextField).at(1), 'vanderberg');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('That username is taken'), findsOneWidget);
    });

    testWidgets(
      'create form fields chain focus via the keyboard submit action',
      (tester) async {
        await pumpOnboarding(tester);

        await tester.enterText(find.byType(TextField).at(0), 'The Smiths');
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();
        var username = tester.widget<TextField>(find.byType(TextField).at(1));
        expect(username.focusNode?.hasFocus, isTrue);

        await tester.enterText(find.byType(TextField).at(1), 'smith-home');
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();
        var password = tester.widget<TextField>(find.byType(TextField).at(2));
        expect(password.focusNode?.hasFocus, isTrue);
      },
    );

    testWidgets('join form fields chain focus via the keyboard submit action', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await tester.tap(find.byKey(const ValueKey('onboard-tab-join')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'vanderberg');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      var password = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(password.focusNode?.hasFocus, isTrue);

      await tester.enterText(find.byType(TextField).at(1), 'demo');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('One last step'), findsNothing);
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('join flow validates input', (tester) async {
      await pumpOnboarding(tester);
      await tester.tap(find.byKey(const ValueKey('onboard-tab-join')));
      await tester.pumpAndSettle();

      // Empty username.
      await tester.tap(find.text('Join family'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a family username'), findsOneWidget);

      // Unknown family.
      await tester.enterText(find.byType(TextField).at(0), 'nope');
      await tester.enterText(find.byType(TextField).at(1), 'whatever');
      await tester.tap(find.text('Join family'));
      await tester.pumpAndSettle();
      expect(find.text('No family found with that username'), findsOneWidget);

      // Known family, wrong password.
      await tester.enterText(find.byType(TextField).at(0), 'vanderberg');
      await tester.enterText(find.byType(TextField).at(1), 'wrong');
      await tester.tap(find.text('Join family'));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect password'), findsOneWidget);

      // Toggle back to the create tab.
      await tester.tap(find.byKey(const ValueKey('onboard-tab-create')));
      await tester.pumpAndSettle();
      expect(find.text('Add photo (optional)'), findsOneWidget);
    });

    testWidgets('joining the demo family dismisses onboarding', (tester) async {
      await pumpOnboarding(tester);
      await tester.tap(find.byKey(const ValueKey('onboard-tab-join')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'vanderberg');
      await tester.enterText(find.byType(TextField).at(1), 'demo');
      await tester.tap(find.text('Join family'));
      await tester.pumpAndSettle();

      expect(find.text('One last step'), findsNothing);
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('sign out from onboarding returns to the auth gate', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await tester.tap(find.byKey(const ValueKey('onboard-signout')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('family create/join sheets', () {
    testWidgets('new family sheet creates a credentialed family', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-new-family')));
      await tester.pumpAndSettle();
      expect(find.text('Create a family'), findsWidgets);

      await tester.enterText(
        find.byKey(const ValueKey('nf-name')),
        'Beach House',
      );
      await tester.enterText(
        find.byKey(const ValueKey('nf-username')),
        'beach-house',
      );
      await tester.enterText(
        find.byKey(const ValueKey('nf-password')),
        'sandy',
      );
      await tester.tap(find.text('Create family'));
      await tester.pumpAndSettle();

      // Sheet closed and the new family is active.
      expect(find.text('Created Beach House'), findsOneWidget);
    });

    testWidgets('new family sheet rejects a short password', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-new-family')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('nf-name')),
        'Beach House',
      );
      await tester.enterText(
        find.byKey(const ValueKey('nf-username')),
        'beach-house',
      );
      await tester.enterText(find.byKey(const ValueKey('nf-password')), '12');
      await tester.tap(find.text('Create family'));
      await tester.pumpAndSettle();
      expect(
        find.text('Password must be at least 4 characters'),
        findsOneWidget,
      );
    });

    testWidgets('join family sheet joins the demo family', (tester) async {
      await pumpApp(tester, prefs: joinableFamilyPrefs());
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-join-family')));
      await tester.pumpAndSettle();
      expect(find.text('Join a family'), findsWidgets);

      await tester.enterText(
        find.byKey(const ValueKey('jf-username')),
        'vanderberg',
      );
      await tester.enterText(find.byKey(const ValueKey('jf-password')), 'demo');
      await tester.tap(find.text('Join family'));
      await tester.pumpAndSettle();
      expect(find.text('Joined van der Berg family'), findsOneWidget);
    });

    testWidgets('new family sheet suggests a username from the name', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-new-family')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('nf-name')),
        'The Janssens',
      );
      // Let the debounce + availability lookup resolve.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final username = tester.widget<TextField>(
        find.byKey(const ValueKey('nf-username')),
      );
      expect(username.controller!.text, 'the-janssens');
      expect(find.text('Suggested · available'), findsOneWidget);
    });

    testWidgets('new family sheet flags a taken username', (tester) async {
      await pumpApp(tester);
      // Create a family that claims the "beach-house" handle.
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-new-family')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nf-name')),
        'Beach House',
      );
      await tester.enterText(
        find.byKey(const ValueKey('nf-username')),
        'beach-house',
      );
      await tester.enterText(
        find.byKey(const ValueKey('nf-password')),
        'sandy',
      );
      await tester.tap(find.text('Create family'));
      await tester.pumpAndSettle();

      // Reopen the sheet and reuse the same handle (back out of the pushed
      // profile page first).
      await tester.tap(find.byKey(const ValueKey('studio-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-new-family')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nf-username')),
        'beach-house',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('“@beach-house” is taken'), findsOneWidget);
      // Design #284: a "use @…" chip offers the next free handle; tapping
      // it claims the suggestion.
      final chip = find.byKey(const ValueKey('nf-use-suggestion'));
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      final username = tester.widget<TextField>(
        find.byKey(const ValueKey('nf-username')),
      );
      expect(username.controller!.text, isNot('beach-house'));
      expect(username.controller!.text, startsWith('beach-house'));
      expect(find.textContaining('is available ✓'), findsOneWidget);
    });

    testWidgets('family credentials card copies the username', (tester) async {
      await pumpApp(tester);
      // Create a credentialed family first so the cred card renders.
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-new-family')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nf-name')),
        'Beach House',
      );
      await tester.enterText(
        find.byKey(const ValueKey('nf-username')),
        'beach-house',
      );
      await tester.enterText(
        find.byKey(const ValueKey('nf-password')),
        'sandy',
      );
      await tester.tap(find.text('Create family'));
      await tester.pumpAndSettle();

      // Open the family management page (#275) and copy the @username.
      await tester.tap(find.byKey(const ValueKey('studio-back')));
      await tester.pumpAndSettle();
      await openMoreHub(tester);
      await tapHubRow(tester, 'family', 'more-member-me');
      await tester.tap(find.byKey(const ValueKey('family-username-copy')));
      await tester.pumpAndSettle();
      expect(find.text('"@beach-house" copied'), findsOneWidget);
    });
  });
}
