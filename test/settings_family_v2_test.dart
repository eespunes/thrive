import 'dart:convert';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'settings_v2_seed.dart';

/// Settings v2 phase 3 acceptance tests: the permission matrix (#273), the
/// profile page (#274), the family management page and its member-row states
/// (#275), the three invite password states (#278), the explicit leave /
/// successor flows (#279) and the hardened delete account (#280).
void main() {
  Future<void> openFamilyPage(WidgetTester tester) async {
    await openMoreHub(tester);
    await tapHubRow(tester, 'family', 'more-member-me');
  }

  void demoteMe() {
    thriveDebug.mutateState(() {
      thriveDebug.curFamily()!.members.firstWhere((m) => m.id == 'me').role =
          'member';
      thriveDebug.curFamily()!.members.firstWhere((m) => m.id == 'm2').role =
          'owner';
    });
  }

  group('#273 permission matrix', () {
    testWidgets('owner: rename, invite, role toggle, delete family all open', (
      tester,
    ) async {
      await pumpApp(tester, prefs: settingsV2Prefs());
      await openFamilyPage(tester);

      // Rename: editable field with explicit save on dirty.
      expect(find.byKey(const ValueKey('family-name-input')), findsOneWidget);
      // Invite & share enabled.
      expect(find.byKey(const ValueKey('family-invite-share')), findsOneWidget);
      // Delete family rendered for the owner.
      expect(find.byKey(const ValueKey('family-delete')), findsOneWidget);
      expect(find.byKey(const ValueKey('family-leave')), findsOneWidget);

      // Role toggle offered (unlocked) on another active account member.
      await tester.tap(find.byKey(const ValueKey('fam-member-m2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ma-role')), findsOneWidget);
      expect(find.byKey(const ValueKey('ma-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('ma-remove')), findsOneWidget);
      expect(find.text('🔒'), findsNothing);
    });

    testWidgets(
      'member: rename read-only, invite locked, actions show 🔒 rows, no '
      'delete-family — and no restart is needed after the role flip',
      (tester) async {
        await pumpApp(tester, prefs: settingsV2Prefs());
        await openFamilyPage(tester);
        expect(find.byKey(const ValueKey('family-name-input')), findsOneWidget);

        // Owner → member while the page stays open: no restart needed (#273).
        demoteMe();
        await tester.pumpAndSettle();

        // Rename is now read-only with the explanatory hint.
        expect(find.byKey(const ValueKey('family-name-input')), findsNothing);
        expect(
          find.text('Only the owner can rename the family.'),
          findsOneWidget,
        );
        // Delete family is an impossible affordance for members: not rendered.
        expect(find.byKey(const ValueKey('family-delete')), findsNothing);
        // Leave stays available.
        expect(find.byKey(const ValueKey('family-leave')), findsOneWidget);

        // Invite & share: shown disabled, tapping only hints.
        await tester.tap(find.byKey(const ValueKey('family-invite-share')));
        await tester.pumpAndSettle();
        expect(find.text('Only owners can invite members'), findsOneWidget);
        expect(find.byKey(const ValueKey('iv-copy-user')), findsNothing);

        // Another account member's actions: edit/role/remove locked with 🔒.
        await tester.tap(find.byKey(const ValueKey('fam-member-m2')));
        await tester.pumpAndSettle();
        expect(find.text('🔒'), findsNWidgets(3));
        await tester.tap(find.byKey(const ValueKey('ma-role')));
        await tester.pumpAndSettle();
        expect(find.text('Only owners can change roles'), findsOneWidget);
        expect(
          thriveDebug.curFamily()!.members.firstWhere((m) => m.id == 'm2').role,
          'owner',
        );
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Their OWN row stays editable...
        await tester.tap(find.byKey(const ValueKey('fam-member-me')));
        await tester.pumpAndSettle();
        expect(find.text('Edit your row'), findsOneWidget);
        // ...with no self-role-toggle and no self-remove rendered at all.
        expect(find.byKey(const ValueKey('ma-role')), findsNothing);
        expect(find.byKey(const ValueKey('ma-remove')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('ma-edit')));
        await tester.pumpAndSettle();
        expect(find.text('Edit member'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('studio-back')));
        await tester.pumpAndSettle();

        // Login-less members stay manageable by anyone.
        thriveDebug.addMember('Sam');
        await tester.pumpAndSettle();
        final sam = thriveDebug.curFamily()!.members.firstWhere(
          (m) => m.name == 'Sam',
        );
        await tester.tap(find.byKey(ValueKey('fam-member-${sam.id}')));
        await tester.pumpAndSettle();
        expect(find.text('🔒'), findsNothing);
        expect(find.byKey(const ValueKey('ma-edit')), findsOneWidget);
        expect(find.byKey(const ValueKey('ma-remove')), findsOneWidget);
      },
    );

    testWidgets('amOwner never defaults to true when my row is missing', (
      tester,
    ) async {
      await pumpApp(tester, prefs: settingsV2Prefs());
      expect(thriveDebug.amOwner(), isTrue);
      thriveDebug.mutateState(() {
        thriveDebug.curFamily()!.members.removeWhere((m) => m.id == 'me');
      });
      expect(thriveDebug.amOwner(), isFalse);
    });

    testWidgets('member: hub Invite & share row is greyed with a hint toast', (
      tester,
    ) async {
      await pumpApp(tester, prefs: settingsV2Prefs());
      demoteMe();
      await openMoreHub(tester);
      await tapHubRow(tester, 'family', 'more-invite');
      expect(find.text('Only owners can invite members'), findsOneWidget);
      expect(find.byKey(const ValueKey('iv-copy-user')), findsNothing);
    });
  });

  group('#275 member-row states', () {
    testWidgets('active, invited and login-less rows are visually distinct', (
      tester,
    ) async {
      await pumpApp(tester, prefs: settingsV2Prefs());
      thriveDebug.addMember('Sam', emoji: '🦊');
      await openFamilyPage(tester);

      // Active owner row.
      expect(find.text('Eva Janssen (you)'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);
      // Invited row: amber pill, cream background, dimmed avatar.
      expect(find.text('INVITED'), findsOneWidget);
      expect(find.text('Invited · hasn’t joined yet'), findsOneWidget);
      final invitedRow = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('fam-member-m3')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (invitedRow.decoration as BoxDecoration?)?.color,
        const Color(0xfffffdf5),
      );
      // Login-less row: emoji avatar + "no login" pill.
      expect(find.text('NO LOGIN'), findsOneWidget);
      expect(find.text('No login — managed by anyone'), findsOneWidget);
      expect(find.text('🦊'), findsWidgets);
    });

    testWidgets('@username row copies the handle', (tester) async {
      await pumpApp(tester, prefs: settingsV2Prefs());
      await openFamilyPage(tester);
      expect(find.text('@janssen'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('family-username-copy')));
      await tester.pumpAndSettle();
      expect(find.text('"@janssen" copied'), findsOneWidget);
    });
  });

  group('#278 invite password states', () {
    testWidgets('no password: amber warning, Set one → known this session', (
      tester,
    ) async {
      await pumpApp(tester, prefs: settingsV2Prefs());
      await openFamilyPage(tester);
      await tester.tap(find.byKey(const ValueKey('family-invite-share')));
      await tester.pumpAndSettle();

      // Exactly the "none" state renders.
      expect(find.byKey(const ValueKey('iv-pw-none')), findsOneWidget);
      expect(find.byKey(const ValueKey('iv-pw-hidden')), findsNothing);
      expect(find.byKey(const ValueKey('iv-pw-known')), findsNothing);

      // Reset flow enforces min 4: a short password stays disabled.
      await tester.tap(find.byKey(const ValueKey('iv-set-pw')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('rp-input')), 'abc');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('rp-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rp-input')), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('rp-input')), 'kitchen');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('rp-save')));
      await tester.pumpAndSettle();

      // Now known-this-session: masked, Reveal, Copy.
      expect(find.byKey(const ValueKey('iv-pw-known')), findsOneWidget);
      expect(find.byKey(const ValueKey('iv-pw-none')), findsNothing);
      expect(find.text('•••••••'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('iv-reveal')));
      await tester.pumpAndSettle();
      expect(find.text('kitchen'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('iv-reveal')));
      await tester.pumpAndSettle();
      expect(find.text('kitchen'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('iv-copy-pw')));
      await tester.pumpAndSettle();
      expect(find.text('Password copied'), findsOneWidget);
    });

    testWidgets('set-but-unknowable: hash-only copy with the reset flow', (
      tester,
    ) async {
      // Registry carries only a salted hash for this family → the plaintext
      // is unknowable in this session.
      await pumpApp(
        tester,
        prefs: {
          ...settingsV2Prefs(),
          'flutter.thrive.registry': json.encode({
            'janssen': {
              'username': 'janssen',
              'name': 'Janssen family',
              'passHash': 'deadbeef',
              'members': const <Object>[],
            },
          }),
        },
      );
      await openFamilyPage(tester);
      await tester.tap(find.byKey(const ValueKey('family-invite-share')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('iv-pw-hidden')), findsOneWidget);
      expect(find.byKey(const ValueKey('iv-pw-none')), findsNothing);
      expect(find.byKey(const ValueKey('iv-pw-known')), findsNothing);

      // Reset makes it known-this-session.
      await tester.tap(find.byKey(const ValueKey('iv-reset-pw')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('rp-input')), 'newpass');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('rp-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('iv-pw-known')), findsOneWidget);
    });

    testWidgets('invite by email and add login-less create the right rows', (
      tester,
    ) async {
      await pumpApp(tester, prefs: settingsV2Prefs());
      await openFamilyPage(tester);
      await tester.tap(find.byKey(const ValueKey('family-invite-share')));
      await tester.pumpAndSettle();

      // The honest no-email-is-sent note is on the sheet.
      expect(
        find.textContaining('Thrive doesn’t send an email yet'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('iv-email')),
        'tom@email.com',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('iv-add-email')));
      await tester.pumpAndSettle();
      final tom = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.email == 'tom@email.com',
      );
      expect(tom.status, 'invited');

      await tester.enterText(find.byKey(const ValueKey('iv-ll-name')), 'Sam');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('iv-add-ll')));
      await tester.pumpAndSettle();
      final sam = thriveDebug.curFamily()!.members.firstWhere(
        (m) => m.name == 'Sam',
      );
      expect(sam.status, 'active');
      expect(sam.uid, isNull);
      expect(sam.email, isEmpty);
    });
  });

  group('#279 leave / delete flows', () {
    testWidgets('owner leave: explicit successor picker, atomic transfer', (
      tester,
    ) async {
      await pumpApp(tester, prefs: settingsV2Prefs());
      // Add a second successor candidate so the radio has a real choice.
      thriveDebug.mutateState(() {
        thriveDebug.curFamily()!.members.add(
          FamilyMember(
            id: 'm4',
            name: 'Noor Janssen',
            email: 'noor@email.com',
            initials: 'NJ',
            color: kMemberColors[3],
            role: 'member',
            status: 'active',
          ),
        );
      });
      final fam = thriveDebug.curFamily()!;
      await openFamilyPage(tester);
      await tester.tap(find.byKey(const ValueKey('family-leave')));
      await tester.pumpAndSettle();

      // The picker lists only active account members — never the invited row.
      expect(find.byKey(const ValueKey('succ-m2')), findsOneWidget);
      expect(find.byKey(const ValueKey('succ-m4')), findsOneWidget);
      expect(find.byKey(const ValueKey('succ-m3')), findsNothing);

      // Pick the NON-default successor explicitly.
      await tester.tap(find.byKey(const ValueKey('succ-m4')));
      await tester.pumpAndSettle();
      expect(find.text('Leave — Noor becomes owner'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('owner-leave-confirm')));
      await tester.pumpAndSettle();

      // Atomic transfer: role AND owner uid moved together; I'm gone; the
      // family never has zero owners.
      final noor = fam.members.firstWhere((m) => m.id == 'm4');
      expect(noor.role, 'owner');
      expect(fam.ownerUid, noor.uid);
      expect(fam.members.any((m) => m.id == 'me'), isFalse);
      expect(fam.members.where((m) => m.role == 'owner'), isNotEmpty);
      // That was the last family → the onboarding gate returns.
      expect(find.text('One last step'), findsOneWidget);
    });

    testWidgets(
      'owner leave with no account-member candidate deletes the family',
      (tester) async {
        await pumpApp(tester, prefs: settingsV2Prefs());
        // Strip the other account members; keep only an invited + login-less.
        thriveDebug.mutateState(() {
          thriveDebug.curFamily()!.members.removeWhere((m) => m.id == 'm2');
        });
        thriveDebug.addMember('Sam');
        await openFamilyPage(tester);
        expect(
          find.text(
            'You’re the only account member — leaving deletes the family',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('family-leave')));
        await tester.pumpAndSettle();
        // Plain confirm (no picker) that states the deletion.
        expect(find.byKey(const ValueKey('succ-m3')), findsNothing);
        expect(find.textContaining('deleted for everyone'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
        await tester.pumpAndSettle();
        expect(thriveDebug.families, isEmpty);
        expect(find.text('One last step'), findsOneWidget);
      },
    );

    testWidgets('member leaving their last family routes to the gate', (
      tester,
    ) async {
      await pumpApp(tester, prefs: settingsV2Prefs());
      demoteMe();
      await openFamilyPage(tester);
      expect(
        find.text('This is your last family — you’ll go back to the start'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('family-leave')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This is your last family — you’ll land back at the '
          'create-or-join screen.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
      await tester.pumpAndSettle();
      expect(thriveDebug.families, isEmpty);
      expect(find.text('One last step'), findsOneWidget);
    });

    testWidgets('delete family confirm names the member count', (tester) async {
      await pumpApp(tester, prefs: settingsV2Prefs());
      await openFamilyPage(tester);
      await tester.tap(find.byKey(const ValueKey('family-delete')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Erases the calendar, budgets and wallet for all 3 members. '
          'This can’t be undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
      await tester.pumpAndSettle();
      expect(find.text('Family deleted'), findsOneWidget);
      expect(thriveDebug.families, isEmpty);
    });
  });

  group('#280 delete account', () {
    testWidgets('confirm computes the sole-member consequence copy', (
      tester,
    ) async {
      // A family where I'm the only account member → it's deleted with me.
      final prefs = settingsV2Prefs();
      await pumpApp(tester, prefs: prefs);
      thriveDebug.mutateState(() {
        thriveDebug.curFamily()!.members.removeWhere((m) => m.id != 'me');
      });
      await openMoreHub(tester);
      await tapHubRow(tester, 'account', 'more-delete-account');
      expect(
        find.text(
          'Deletes 1 family where you’re the only member. Then you’re '
          'signed out. This can’t be undone.',
        ),
        findsOneWidget,
      );
      // Wrong text keeps the button disarmed.
      await tester.enterText(find.byKey(const ValueKey('da-input')), 'nope');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('da-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Delete your account?'), findsOneWidget);
      // Typing DELETE arms it; the account is gone and the auth gate returns.
      await tester.enterText(find.byKey(const ValueKey('da-input')), 'DELETE');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('da-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });

  group('#274 profile page', () {
    testWidgets('families list carries the current badge and switch-on-tap', (
      tester,
    ) async {
      await pumpApp(tester, prefs: settingsV2Prefs());
      await thriveDebug.createFamily('Beach house');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      final beachId = thriveDebug.families
          .firstWhere((f) => f.name == 'Beach house')
          .id;
      // Current badge on the active family row.
      expect(find.text('Current'), findsOneWidget);
      expect(find.byKey(ValueKey('profile-family-$beachId')), findsOneWidget);
      // Switch on tap.
      await tester.tap(find.byKey(const ValueKey('profile-family-fam_main')));
      await tester.pumpAndSettle();
      expect(thriveDebug.familyId, 'fam_main');
      // Create / Join entry points are present.
      expect(find.byKey(const ValueKey('profile-new-family')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-join-family')), findsOneWidget);
    });
  });
}
