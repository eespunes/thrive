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
      expect(find.text('Password must be at least 4 characters'), findsOneWidget);
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
      await tester.tap(find.text('Create family'));
      await tester.pumpAndSettle();
      // Sheet closed; reopening the profile lists the new family.
      expect(find.text('Create a family'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      expect(find.text('Beach house'), findsWidgets);
    });
  });
}
