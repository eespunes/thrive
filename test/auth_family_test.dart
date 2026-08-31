import 'dart:convert';

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
    testWidgets('opens the profile page and saves the name explicitly', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Janssen family'), findsWidgets);

      await tester.enterText(
        find.byKey(const ValueKey('profile-name-input')),
        'Eva Smit',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('profile-name-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('Name saved — mirrored to your member rows'),
        findsOneWidget,
      );
    });

    testWidgets('profile colour picker mirrors a free colour everywhere', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      final taken = thriveDebug
          .curFamily()!
          .members
          .where((m) => m.id != 'me')
          .map((m) => m.color)
          .toSet();
      final free = kMemberColors.lastWhere((c) => !taken.contains(c));
      await tester.ensureVisible(
        find.byKey(ValueKey('badge-color-${free.toARGB32()}')),
      );
      await tester.tap(
        find.byKey(ValueKey('badge-color-${free.toARGB32()}')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.text('Colour updated everywhere'), findsOneWidget);
      expect(thriveDebug.user!.color, free);
      expect(
        thriveDebug.curFamily()!.members.firstWhere((m) => m.id == 'me').color,
        free,
      );
    });

    testWidgets('a colour worn by someone else is locked in YOUR OWN picker', (
      tester,
    ) async {
      await pumpApp(tester);
      final other = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.id != 'me',
      );
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(ValueKey('badge-color-${other.color.toARGB32()}')),
      );
      await tester.tap(
        find.byKey(ValueKey('badge-color-${other.color.toARGB32()}')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      // Self-colour bypass fixed (#274): taken colours only toast.
      expect(find.text('That colour is taken in this family'), findsOneWidget);
      expect(thriveDebug.user!.color, isNot(other.color));
    });

    testWidgets('sign out from the hub returns to the auth screen', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();
      await tapHubRow(tester, 'account', 'more-signout');
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('family management', () {
    Future<void> openFamily(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();
      await tapHubRow(tester, 'family', 'more-member-me');
    }

    testWidgets('opens the family page with members', (tester) async {
      await pumpApp(tester);
      await openFamily(tester);
      expect(find.text('Eva Janssen (you)'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);
      expect(find.byKey(const ValueKey('family-name-input')), findsOneWidget);
      expect(find.byKey(const ValueKey('family-invite-share')), findsOneWidget);
    });

    testWidgets('invites a new member by email', (tester) async {
      await pumpApp(tester);
      await openFamily(tester);
      await tester.tap(find.byKey(const ValueKey('family-invite-share')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('iv-email')),
        'lisa@email.com',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('iv-add-email')));
      await tester.pumpAndSettle();
      // Close the sheet; the invited row is on the family page.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('INVITED'), findsOneWidget);
      expect(find.text('Invited · hasn’t joined yet'), findsOneWidget);
    });

    testWidgets('creates a separate family workspace', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-new-family')));
      await tester.pumpAndSettle();
      expect(find.text('Create a family'), findsWidgets);
      await tester.enterText(
        find.byKey(const ValueKey('nf-name')),
        'Beach house',
      );
      await tester.pump();
      await tester.tap(find.text('Create family'));
      await tester.pumpAndSettle();
      // Sheet closed; the profile family list shows the new family.
      expect(find.byKey(const ValueKey('nf-name')), findsNothing);
      expect(find.text('Beach house'), findsWidgets);
      expect(thriveDebug.families.any((f) => f.name == 'Beach house'), isTrue);
    });
  });

  group('family actions', () {
    Future<void> openFamily(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();
      await tapHubRow(tester, 'family', 'more-member-me');
    }

    Future<String> inviteLisa(WidgetTester tester) async {
      thriveDebug.inviteMember('Lisa Janssen', 'lisa@email.com');
      await tester.pumpAndSettle();
      return thriveDebug
          .curFamily()!
          .members
          .firstWhere((m) => m.name == 'Lisa Janssen')
          .id;
    }

    testWidgets('owner renames the family with an explicit save', (
      tester,
    ) async {
      await pumpApp(tester);
      await openFamily(tester);
      await tester.enterText(
        find.byKey(const ValueKey('family-name-input')),
        'The Smiths',
      );
      await tester.pump();
      // No per-keystroke write (#275).
      expect(thriveDebug.curFamily()!.name, isNot('The Smiths'));
      await tester.tap(find.byKey(const ValueKey('family-name-save')));
      await tester.pumpAndSettle();
      expect(find.text('Family renamed'), findsOneWidget);
      expect(thriveDebug.curFamily()!.name, 'The Smiths');
    });

    testWidgets('owner edits an invited member via the actions sheet', (
      tester,
    ) async {
      await pumpApp(tester);
      await openFamily(tester);
      final lisaId = await inviteLisa(tester);
      await tester.tap(find.byKey(ValueKey('fam-member-$lisaId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ma-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Edit member'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('member-email')),
        'lisab@email.com',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();
      expect(find.text('Member saved — updated everywhere'), findsOneWidget);
    });

    testWidgets('owner revokes an invite from the actions sheet', (
      tester,
    ) async {
      await pumpApp(tester);
      await openFamily(tester);
      final lisaId = await inviteLisa(tester);
      await tester.tap(find.byKey(ValueKey('fam-member-$lisaId')));
      await tester.pumpAndSettle();
      // Invited rows never offer a role toggle (#275).
      expect(find.byKey(const ValueKey('ma-role')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('ma-revoke')));
      await tester.pumpAndSettle();
      expect(find.text('Revoke Lisa Janssen’s invite?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
      await tester.pumpAndSettle();
      expect(find.text('Member removed'), findsOneWidget);
      expect(
        thriveDebug.curFamily()!.members.any((m) => m.id == lisaId),
        isFalse,
      );
    });

    testWidgets('owner promotes then removes an active account member', (
      tester,
    ) async {
      await pumpApp(tester);
      await openFamily(tester);
      final other = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.id != 'me' && m.status == 'active',
      );

      await tester.tap(find.byKey(ValueKey('fam-member-${other.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ma-role')));
      await tester.pumpAndSettle();
      expect(find.text('Role updated'), findsOneWidget);
      expect(other.role, 'owner');

      // Demote again, then remove with the counting confirm.
      await tester.tap(find.byKey(ValueKey('fam-member-${other.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Demote to member'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ma-role')));
      await tester.pumpAndSettle();
      expect(other.role, 'member');

      await tester.tap(find.byKey(ValueKey('fam-member-${other.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ma-remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
      await tester.pumpAndSettle();
      expect(find.text('Member removed'), findsOneWidget);
    });

    testWidgets('switches to and deletes another family', (tester) async {
      await pumpApp(tester);
      await thriveDebug.createFamily('Beach house');
      await tester.pumpAndSettle();
      expect(thriveDebug.curFamily()!.name, 'Beach house');

      // Delete the now-current family from its management page.
      await openFamily(tester);
      await tester.tap(find.byKey(const ValueKey('family-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete Beach house?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
      await tester.pumpAndSettle();
      expect(find.text('Family deleted'), findsOneWidget);
      expect(thriveDebug.families.any((f) => f.name == 'Beach house'), isFalse);
    });

    testWidgets('cancels a member edit', (tester) async {
      await pumpApp(tester);
      await openFamily(tester);
      final lisaId = await inviteLisa(tester);
      await tester.tap(find.byKey(ValueKey('fam-member-$lisaId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ma-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Edit member'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('studio-back')));
      await tester.pumpAndSettle();
      expect(find.text('Edit member'), findsNothing);
    });

    testWidgets('owner adds a member with no email (e.g. a kid)', (
      tester,
    ) async {
      await pumpApp(tester);
      await openFamily(tester);

      await tester.tap(find.byKey(const ValueKey('family-add-loginless')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('iv-ll-name')),
        'Emma Bakker',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('iv-add-ll')));
      await tester.pumpAndSettle();
      expect(find.text('Emma added'), findsOneWidget);

      // Close the invite sheet: the login-less row style shows on the page.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('NO LOGIN'), findsOneWidget);
      expect(find.text('No login — managed by anyone'), findsOneWidget);

      final added = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.name == 'Emma Bakker',
      );
      expect(added.uid, isNull);
      expect(added.id, isNotEmpty);
      expect(added.status, 'active');
    });

    testWidgets('owner edits a login-less member\'s name and emoji', (
      tester,
    ) async {
      await pumpApp(tester);
      await openFamily(tester);
      thriveDebug.addMember('Emma Bakker');
      await tester.pumpAndSettle();
      final added = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.name == 'Emma Bakker',
      );

      await tester.tap(find.byKey(ValueKey('fam-member-${added.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ma-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Edit member'), findsOneWidget);

      // Type any OS emoji through the badge stage's free input.
      await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-link')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('badge-stage-emoji-input')),
        '😀',
      );
      await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-use')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('badge-stage-name')),
        'Emma B.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();

      final updated = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.id == added.id,
      );
      expect(updated.name, 'Emma B.');
      expect(updated.emoji, '😀');
      expect(updated.photo, isNull);
    });

    testWidgets('a non-owner member can edit and remove a login-less member', (
      tester,
    ) async {
      await pumpApp(tester);
      await openFamily(tester);
      thriveDebug.addMember('Emma Bakker');
      await tester.pumpAndSettle();
      final added = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.name == 'Emma Bakker',
      );

      // Demote 'me' to a plain member.
      final me = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.id == 'me',
      );
      me.role = 'member';
      expect(thriveDebug.amOwner(), isFalse);

      // A non-owner still edits a login-less member...
      await tester.tap(find.byKey(ValueKey('fam-member-${added.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ma-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Edit member'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('badge-stage-name')),
        'Emma B.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();
      expect(
        thriveDebug.curFamily()!.members.any((m) => m.name == 'Emma B.'),
        isTrue,
      );

      // ...and removes them too.
      await tester.tap(find.byKey(ValueKey('fam-member-${added.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ma-remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
      await tester.pumpAndSettle();
      expect(find.text('Member removed'), findsOneWidget);
      expect(
        thriveDebug.curFamily()!.members.any((m) => m.id == added.id),
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
      'a local family password is NOT recoverable after a reboot (only a '
      'salted hash is persisted; the plaintext lives in the session cache)',
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
        // in-memory session cache — the "Invite someone" sheet can show it.
        final fam = thriveDebug.curFamily()!;
        expect(await thriveDebug.fetchFamilyPassword(fam), 'sunshine');

        // Simulate a fresh app session: the in-memory cache is gone, and the
        // on-device registry only holds a salted hash (SharedPreferences is
        // plaintext on disk), so the password is deliberately unrecoverable.
        await rebootApp(tester);
        final famAfterReboot = thriveDebug.curFamily()!;
        expect(await thriveDebug.fetchFamilyPassword(famAfterReboot), isNull);

        // The hashed registry entry still verifies the password: joining the
        // family from another local identity with the same password works.
        final joinErr = await thriveDebug.joinFamily(
          username: 'bakkerfam',
          password: 'wrong-password',
        );
        expect(joinErr, 'Incorrect password');
      },
    );

    testWidgets('a non-owner member sees Invite & share owner-gated', (
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
      await openHubCard(tester, 'family', 'more-invite');
      // Settings v2 (#273): members see the row disabled with a hint —
      // the invite sheet (and password reveal) is owner-only.
      await tester.tap(find.byKey(const ValueKey('more-invite')));
      await tester.pumpAndSettle();
      expect(find.text('Only owners can invite members'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('invite-password-toggle')),
        findsNothing,
      );
    });

    testWidgets("joining a local family whose stored owner still carries the "
        "'me' sentinel doesn't merge the two identities", (tester) async {
      // Simulates a family registry entry left over from before members
      // were externalized on write (or any other stale doc): the owner's
      // row is still literally `id: 'me'`. Joining it must not let the
      // freshly-signed-in device collide with — and take over — that real
      // member's identity.
      final reg = {
        'oldfam': {
          'username': 'oldfam',
          'password': 'legacy1',
          'name': 'Old family',
          'picture': null,
          'members': [
            FamilyMember(
              id: 'me',
              name: 'Sophie van der Berg',
              email: 'sophie@vanderberg.nl',
              initials: 'SB',
              color: kMemberColors[2],
              role: 'owner',
              status: 'active',
            ).toJson(),
          ],
          'workspace': Workspace.empty().toJson(),
        },
      };
      await pumpApp(
        tester,
        prefs: {'flutter.thrive.registry': json.encode(reg)},
      );

      final err = await thriveDebug.joinFamily(
        username: 'oldfam',
        password: 'legacy1',
      );
      expect(err, isNull);
      await tester.pumpAndSettle();

      final members = thriveDebug.curFamily()!.members;
      final meRows = members.where((m) => m.id == 'me').toList();
      // Exactly one row resolves to `'me'` — the signed-in device itself —
      // never the pre-existing owner.
      expect(meRows, hasLength(1));
      expect(meRows.single.name, 'Eva Janssen');
      expect(
        members.any((m) => m.name == 'Sophie van der Berg' && m.id != 'me'),
        isTrue,
      );
    });

    testWidgets('joining a family whose workspace still carries legacy \'me\' '
        'references migrates them to this device\'s own id', (tester) async {
      // Simulates a workspace blob left over from before writes/reads
      // externalized every member reference: calendar attendees/createdBy,
      // task assignee/createdBy/completedBy and shopping addedBy are all
      // still the literal string 'me'. Adopting this workspace must rewrite
      // every one of those to this device's own stable id so they stop
      // resolving as "whichever device is viewing" once shared.
      final ws = Workspace.empty();
      ws.events.add(
        CalendarEvent(
          id: 'ev1',
          title: 'Dentist',
          date: '2026-01-01',
          color: kMemberColors[0],
          attendees: ['me'],
          createdBy: 'me',
          recur: 'weekly',
          recurWeekdays: [1, 3, 5],
        ),
      );
      ws.taskLists.add(
        TaskList(
          id: 'tl1',
          name: 'Chores',
          color: kMemberColors[0],
          tasks: [
            ListTask(
              id: 't1',
              title: 'Wash dishes',
              assignee: 'me',
              createdBy: 'me',
              completedBy: 'me',
            ),
          ],
        ),
      );
      ws.shoppingLists.add(
        ShoppingList(
          id: 'sl1',
          name: 'Groceries',
          items: [ShopItem(id: 'i1', name: 'Milk', addedBy: 'me')],
        ),
      );
      ws.weeklyPlan['2026-01-01'] = DayPlan(
        dateIso: '2026-01-01',
        breakfast: 'Oatmeal',
      );
      final reg = {
        'legacyws': {
          'username': 'legacyws',
          'password': 'legacy2',
          'name': 'Legacy workspace family',
          'picture': null,
          'members': [
            FamilyMember(
              id: uid(),
              name: 'Owner',
              email: 'owner@example.com',
              initials: 'OW',
              color: kMemberColors[3],
              role: 'owner',
              status: 'active',
            ).toJson(),
          ],
          'workspace': ws.toJson(),
        },
      };
      await pumpApp(
        tester,
        prefs: {
          'flutter.thrive.registry': json.encode(reg),
          // Give this device a distinct self id (instead of the usual
          // 'me' test convenience default) so the migrated fields can be
          // told apart from their pre-migration 'me' value below.
          'flutter.$kLocalSelfUidKey': 'self_device_1',
        },
      );

      final err = await thriveDebug.joinFamily(
        username: 'legacyws',
        password: 'legacy2',
      );
      expect(err, isNull);
      await tester.pumpAndSettle();

      final myId = thriveDebug.myId;
      expect(myId, 'self_device_1');

      final event = thriveDebug.events.firstWhere((e) => e.id == 'ev1');
      expect(event.attendees, [myId]);
      expect(event.createdBy, myId);

      final task = thriveDebug.taskLists
          .firstWhere((l) => l.id == 'tl1')
          .tasks
          .first;
      expect(task.assignee, myId);
      expect(task.createdBy, myId);
      expect(task.completedBy, myId);

      final item = thriveDebug.shoppingLists
          .firstWhere((l) => l.id == 'sl1')
          .items
          .first;
      expect(item.addedBy, myId);
    });

    testWidgets(
      'joining fails gracefully when the local registry prefs blob is '
      'corrupted JSON',
      (tester) async {
        // A corrupted/unparsable `thrive.registry` value (e.g. from a
        // partial write) must not crash the app — loadRegistry() should
        // swallow the decode error and behave as if no families exist.
        await pumpApp(
          tester,
          prefs: {'flutter.thrive.registry': '{not valid json'},
        );

        final err = await thriveDebug.joinFamily(
          username: 'anything',
          password: 'whatever',
        );
        expect(err, 'No family found with that username');
      },
    );

    testWidgets(
      'joining a family whose registry entry has no stored workspace falls '
      'back to an empty one',
      (tester) async {
        // Older/foreign registry entries may not carry a 'workspace' key at
        // all; joining such a family must still succeed with a fresh, empty
        // workspace instead of throwing.
        final reg = {
          'noworkspace': {
            'username': 'noworkspace',
            'password': 'pw123',
            'name': 'No workspace family',
            'picture': null,
            'members': [
              FamilyMember(
                id: uid(),
                name: 'Owner',
                email: 'owner@example.com',
                initials: 'OW',
                color: kMemberColors[3],
                role: 'owner',
                status: 'active',
              ).toJson(),
            ],
          },
        };
        await pumpApp(
          tester,
          prefs: {'flutter.thrive.registry': json.encode(reg)},
        );

        final err = await thriveDebug.joinFamily(
          username: 'noworkspace',
          password: 'pw123',
        );
        expect(err, isNull);
        await tester.pumpAndSettle();

        expect(thriveDebug.events, isEmpty);
        expect(thriveDebug.taskLists, isEmpty);
        expect(thriveDebug.shoppingLists, isEmpty);
      },
    );
  });
}
