import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('auth gate', () {
    testWidgets('shows the login screen when signed out', (tester) async {
      await pumpApp(tester, signedIn: false);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('Google sign-in (dummy) enters the app', (tester) async {
      await pumpApp(tester, signedIn: false);
      await tester.tap(find.byKey(const ValueKey('auth-google')));
      await tester.pump(); // start busy
      await tester.pump(const Duration(milliseconds: 800)); // resolve delay
      await tester.pumpAndSettle();
      // Sign-in lands on the new Home tab (issue #149); navigate to Finance.
      await tester.tap(find.byKey(const ValueKey('nav-finance')));
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('email validation rejects bad input', (tester) async {
      await pumpApp(tester, signedIn: false);
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'eva@email.com',
      );
      await tester.enterText(find.byKey(const ValueKey('auth-pw')), '12');
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('Password must be at least 4 characters'),
        findsOneWidget,
      );
    });

    testWidgets('register flow requires a name then signs in', (tester) async {
      await pumpApp(tester, signedIn: false);
      await tester.tap(find.byKey(const ValueKey('auth-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);

      // No name yet.
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'tom@email.com',
      );
      await tester.enterText(find.byKey(const ValueKey('auth-pw')), 'secret');
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your name'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('auth-name')),
        'Tom Bakker',
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      // Sign-in lands on the new Home tab (issue #149); navigate to Finance.
      await tester.tap(find.byKey(const ValueKey('nav-finance')));
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('keyboard Enter advances email to password (#142)', (
      tester,
    ) async {
      await pumpApp(tester, signedIn: false);
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'eva@email.com',
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      final pw = tester.widget<TextField>(
        find.byKey(const ValueKey('auth-pw')),
      );
      expect(pw.focusNode?.hasFocus, isTrue);
    });

    testWidgets('keyboard Enter on password submits the form (#142)', (
      tester,
    ) async {
      await pumpApp(tester, signedIn: false);
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'eva@email.com',
      );
      await tester.enterText(find.byKey(const ValueKey('auth-pw')), 'secret');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      // Sign-in lands on the new Home tab (issue #149); navigate to Finance.
      await tester.tap(find.byKey(const ValueKey('nav-finance')));
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsOneWidget);
    });
  });

  group('profile', () {
    testWidgets('opens profile and edits the display name', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      expect(find.text('Your profile'), findsOneWidget);
      expect(find.text('Janssen family'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profile-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Edit profile'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Eva Smit');
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profile updated'), findsOneWidget);
    });

    testWidgets('profile colour picker exposes more colors', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Colors'), findsOneWidget);
      await tester.tap(find.text('Colors'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AnimatedContainer).last);
      await tester.pump();
    });

    testWidgets('sign out returns to the auth screen', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-signout')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('family management', () {
    Future<void> openFamily(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-family-fam_main')));
      await tester.pumpAndSettle();
    }

    testWidgets('opens the family sheet with members', (tester) async {
      await pumpApp(tester);
      await openFamily(tester);
      expect(find.text('YOU'), findsOneWidget);
      expect(find.text('Erik Janssen'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
    });

    testWidgets('invites a new member', (tester) async {
      await pumpApp(tester);
      await openFamily(tester);
      await tester.tap(find.byKey(const ValueKey('family-invite')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Lisa Janssen');
      await tester.enterText(find.byType(TextField).at(2), 'lisa@email.com');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('invite-send')));
      await tester.pumpAndSettle();
      // Invite card closed and the new (invited) member is listed.
      expect(find.text('Send invite'), findsNothing);
      expect(find.text('Lisa Janssen'), findsWidgets);
      expect(find.text('Invited'), findsOneWidget);
    });

    testWidgets('creates a separate family workspace', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-new-family')));
      await tester.pumpAndSettle();
      expect(find.text('Create a family'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Beach house');
      await tester.pump();
      await tester.tap(find.text('Create family'));
      await tester.pumpAndSettle();
      // Sheet closed; reopening the profile lists the new family.
      expect(find.text('Create a family'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      expect(find.text('Beach house'), findsWidgets);
    });
  });

  group('family actions', () {
    Future<void> openFamily(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-family-fam_main')));
      await tester.pumpAndSettle();
    }

    Future<void> inviteLisa(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('family-invite')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Lisa Janssen');
      await tester.enterText(find.byType(TextField).at(2), 'lisa@email.com');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('invite-send')));
      await tester.pumpAndSettle();
    }

    Finder keyStartsWith(String prefix, {String? not}) {
      return find.byWidgetPredicate((w) {
        final k = w.key;
        if (k is! ValueKey) return false;
        final v = '${k.value}';
        return v.startsWith(prefix) && v != not;
      });
    }

    testWidgets('owner renames the family', (tester) async {
      await pumpApp(tester);
      await openFamily(tester);
      await tester.enterText(find.byType(TextField).first, 'The Smiths');
      await tester.pump();
      expect(find.text('The Smiths'), findsWidgets);
    });

    testWidgets('owner edits an invited member', (tester) async {
      await pumpApp(tester);
      await openFamily(tester);
      await inviteLisa(tester);
      await tester.tap(find.text('Lisa Janssen').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'lisab@email.com');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('member-save')));
      await tester.pumpAndSettle();
      expect(find.text('Member updated'), findsOneWidget);
    });

    testWidgets('owner toggles role and removes a member', (tester) async {
      await pumpApp(tester);
      await openFamily(tester);
      await inviteLisa(tester);

      await tester.tap(find.text('Invited'));
      await tester.pumpAndSettle();
      expect(find.text('Role updated'), findsOneWidget);

      await tester.tap(keyStartsWith('member-remove-').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Member removed'), findsOneWidget);
    });

    testWidgets('switches to and deletes another family', (tester) async {
      await pumpApp(tester);

      // Create a second family.
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-new-family')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Beach house');
      await tester.pump();
      await tester.tap(find.text('Create family'));
      await tester.pumpAndSettle();

      // Open the original family sheet, then switch via the chip switcher.
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-family-fam_main')));
      await tester.pumpAndSettle();
      await tester.tap(
        keyStartsWith('family-chip-', not: 'family-chip-fam_main'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Switched to Beach house'), findsOneWidget);

      // Delete the now-current family.
      await tester.tap(find.byKey(const ValueKey('family-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Family deleted'), findsOneWidget);
    });

    testWidgets('cancels a member edit', (tester) async {
      await pumpApp(tester);
      await openFamily(tester);
      await inviteLisa(tester);
      await tester.tap(find.text('Lisa Janssen').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('member-save')), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('member-save')), findsNothing);
    });

    testWidgets('owner adds a member with no email (e.g. a kid)', (
      tester,
    ) async {
      await pumpApp(tester);
      await openFamily(tester);

      await tester.tap(find.byKey(const ValueKey('family-add-member')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Emma Bakker');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('add-member-save')));
      await tester.pumpAndSettle();

      expect(find.text('Emma added'), findsOneWidget);
      expect(find.text('Emma Bakker'), findsOneWidget);
      expect(find.text('No login'), findsOneWidget);
      expect(find.text('Member'), findsWidgets);

      final added = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.name == 'Emma Bakker',
      );
      expect(added.uid, isNull);
      expect(added.id, isNotEmpty);
      expect(added.status, 'active');
    });

    testWidgets('owner edits a login-less member\'s name, emoji and picture', (
      tester,
    ) async {
      await pumpApp(tester);
      await openFamily(tester);

      await tester.tap(find.byKey(const ValueKey('family-add-member')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Emma Bakker');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('add-member-save')));
      await tester.pumpAndSettle();

      final added = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.name == 'Emma Bakker',
      );

      // Tap the row to enter inline edit mode.
      await tester.tap(find.text('Emma Bakker'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('glyph-pick-emoji')), findsOneWidget);

      // Pick an emoji through the in-app picker (issue precedent from
      // family_emoji_features_test.dart: hop to the Smileys tab and tap
      // the first emoji since Recents starts empty).
      await tester.tap(find.byKey(const ValueKey('glyph-pick-emoji')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Tab).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('😀').first);
      await tester.pumpAndSettle();

      // Change the name too.
      await tester.enterText(find.text('Emma Bakker'), 'Emma B.');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('member-save')));
      await tester.pumpAndSettle();

      final updated = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.id == added.id,
      );
      expect(updated.name, 'Emma B.');
      expect(updated.emoji, '😀');
      expect(updated.photo, isNull);
      expect(find.text('😀'), findsWidgets);
    });

    testWidgets('a non-owner member can edit and remove a login-less member', (
      tester,
    ) async {
      await pumpApp(tester);
      await openFamily(tester);

      await tester.tap(find.byKey(const ValueKey('family-add-member')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Emma Bakker');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('add-member-save')));
      await tester.pumpAndSettle();

      // Demote 'me' to a plain member.
      final me = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.id == 'me',
      );
      me.role = 'member';
      expect(thriveDebug.amOwner(), isFalse);

      // A non-owner can still open the inline edit for a login-less member...
      await tester.tap(find.text('Emma Bakker'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('member-save')), findsOneWidget);
      await tester.enterText(find.text('Emma Bakker'), 'Emma B.');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('member-save')));
      await tester.pumpAndSettle();
      expect(
        thriveDebug
            .curFamily()!
            .members
            .firstWhere((m) => m.name == 'Emma B.')
            .name,
        'Emma B.',
      );

      // ...and remove them too.
      final emmaId = thriveDebug
          .curFamily()!
          .members
          .firstWhere((m) => m.name == 'Emma B.')
          .id;
      await tester.tap(find.byKey(ValueKey('member-remove-$emmaId')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Member removed'), findsOneWidget);
      expect(
        thriveDebug.curFamily()!.members.any((m) => m.name == 'Emma B.'),
        isFalse,
      );
    });

    testWidgets('a login-less member can be given an emoji avatar', (
      tester,
    ) async {
      await pumpApp(tester);
      await openFamily(tester);

      thriveDebug.addMember('Kid One', emoji: '🦄');
      final added = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.name == 'Kid One',
      );
      expect(added.emoji, '🦄');
      expect(added.photo, isNull);

      thriveDebug.editMember(
        added.id,
        'Kid One',
        '',
        emoji: '🐼',
        emojiTouched: true,
      );
      final updated = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.id == added.id,
      );
      expect(updated.emoji, '🐼');

      // Without the touched flag, an existing emoji/photo is left alone.
      thriveDebug.editMember(added.id, 'Kid One', '');
      final untouched = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.id == added.id,
      );
      expect(untouched.emoji, '🐼');
    });

    testWidgets(
      'a local family password survives a reboot (session cache lost)',
      (tester) async {
        await pumpApp(tester);

        final err = await thriveDebug.createFamily(
          'Bakker family',
          username: 'bakkerfam',
          password: 'sunshine',
        );
        expect(err, isNull);
        await tester.pumpAndSettle();

        // Immediately after creation the password is served from the
        // in-memory session cache.
        final fam = thriveDebug.curFamily()!;
        expect(await thriveDebug.fetchFamilyPassword(fam), 'sunshine');

        // Simulate a fresh app session: the in-memory cache is gone, but the
        // password must still be recoverable from the on-device registry in
        // local/demo mode.
        await rebootApp(tester);
        final famAfterReboot = thriveDebug.curFamily()!;
        expect(
          await thriveDebug.fetchFamilyPassword(famAfterReboot),
          'sunshine',
        );

        // Also verify the "Invite someone" sheet itself now shows it.
        await tester.tap(find.byKey(const ValueKey('nav-more')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('more-invite')));
        await tester.pumpAndSettle();
        expect(find.text('•' * 'sunshine'.length), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('invite-password-toggle')));
        await tester.pumpAndSettle();
        expect(find.text('sunshine'), findsOneWidget);
      },
    );

    testWidgets('a non-owner member can reveal the family password', (
      tester,
    ) async {
      await pumpApp(tester);

      final err = await thriveDebug.createFamily(
        'Bakker family',
        username: 'bakkerfam2',
        password: 'sunshine2',
      );
      expect(err, isNull);
      await tester.pumpAndSettle();

      // Demote 'me' to a plain member.
      final me = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.id == 'me',
      );
      me.role = 'member';
      expect(thriveDebug.amOwner(), isFalse);

      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('more-invite')));
      await tester.pumpAndSettle();
      expect(find.text('•' * 'sunshine2'.length), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('invite-password-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('sunshine2'), findsOneWidget);
    });
  });
}
