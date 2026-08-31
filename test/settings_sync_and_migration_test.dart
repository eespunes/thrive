import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'settings_v2_seed.dart';

/// #283 sync/offline indicator + #284 migration & regression pass.
void main() {
  group('#283 sync pill', () {
    testWidgets('a sub-page mutation blips Saving… → Saved ✓ → gone', (
      tester,
    ) async {
      await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
      await openMoreHub(tester);
      await tapHubRow(tester, 'planning', 'more-callayers');
      expect(find.byKey(const ValueKey('sync-pill')), findsNothing);

      // Toggle a layer's visibility — a real queued write.
      await tester.tap(find.byKey(const ValueKey('layers-toggle-appt')));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Saved ✓'), findsOneWidget);

      // Clears 1800ms after settling.
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.byKey(const ValueKey('sync-pill')), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('offline: banner + "Queued — offline" pill, back online '
        'clears the banner', (tester) async {
      await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
      await openMoreHub(tester);
      await tapHubRow(tester, 'planning', 'more-callayers');
      expect(find.byKey(const ValueKey('offline-banner')), findsNothing);

      // Simulate a failed cloud commit (writes queue in the local store).
      thriveDebug.netOffline.value = true;
      await tester.pump();
      expect(find.byKey(const ValueKey('offline-banner')), findsOneWidget);
      expect(
        find.text('Offline — changes queue and sync when you’re back'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('layers-toggle-appt')));
      await tester.pump();
      expect(find.text('Queued — offline'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      // Still queued after the settle tick — never a false "Saved ✓".
      expect(find.text('Queued — offline'), findsOneWidget);
      expect(find.text('Saved ✓'), findsNothing);

      // Reconnect: the banner goes, the next blip saves normally.
      thriveDebug.netOffline.value = false;
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.byKey(const ValueKey('offline-banner')), findsNothing);
      await tester.pumpAndSettle();
    });
  });

  group('#284 member studio kid toggle (#245)', () {
    testWidgets('owner flips a member to a kid profile and back', (
      tester,
    ) async {
      await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
      await openMoreHub(tester);
      await tapHubRow(tester, 'planning', 'more-memcolors');
      await tester.tap(find.byKey(const ValueKey('memcolors-row-m2')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('member-kid-toggle')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();
      FamilyMember erik() =>
          thriveDebug.curFamily()!.members.firstWhere((m) => m.id == 'm2');
      expect(erik().role, 'kid');
      // The member list explains the role.
      expect(find.text('Kid'), findsOneWidget);

      // And back to a full member.
      await tester.tap(find.byKey(const ValueKey('memcolors-row-m2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member-kid-toggle')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();
      expect(erik().role, 'member');
    });

    testWidgets('no kid toggle on your own row (a kid can’t unlock itself)', (
      tester,
    ) async {
      await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
      await openMoreHub(tester);
      await tapHubRow(tester, 'planning', 'more-memcolors');
      await tester.tap(find.byKey(const ValueKey('memcolors-row-me')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('member-kid-toggle')), findsNothing);
    });
  });

  group('#284 role mutation hardened at the API level', () {
    testWidgets('toggleMemberRole: owner-only, never self', (tester) async {
      await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
      final f = thriveDebug.curFamily()!;
      FamilyMember member(String id) => f.members.firstWhere((m) => m.id == id);

      // Never self: the owner can't demote their own row.
      thriveDebug.toggleMemberRole('me');
      expect(member('me').role, 'owner');

      // Owner-only: as a plain member the call is a no-op, even against
      // another member.
      member('me').role = 'member';
      member('m2').role = 'owner';
      thriveDebug.toggleMemberRole('m2');
      expect(member('m2').role, 'owner');
      thriveDebug.toggleMemberRole('m3');
      expect(member('m3').role, 'member');
      await tester.pumpAndSettle();
    });

    testWidgets('saveMemberStudio ignores kid flips from non-owners and on '
        'owner rows', (tester) async {
      await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
      final f = thriveDebug.curFamily()!;
      FamilyMember member(String id) => f.members.firstWhere((m) => m.id == id);

      // Non-owner viewer: the kid flip is dropped, plain edits still apply.
      member('me').role = 'member';
      member('m2').role = 'owner';
      thriveDebug.saveMemberStudio(
        'm3',
        name: 'Lisa Janssen',
        email: 'lisa.j@icloud.com',
        color: member('m3').color,
        kid: true,
      );
      expect(member('m3').role, 'member');

      // An owner row can never become a kid.
      member('me').role = 'owner';
      member('m2').role = 'member';
      thriveDebug.saveMemberStudio(
        'me',
        name: 'Eva Janssen',
        email: 'eva.janssen@gmail.com',
        color: member('me').color,
        kid: true,
      );
      expect(member('me').role, 'owner');
      await tester.pumpAndSettle();
    });
  });

  group('#284 join page', () {
    testWidgets('wrong password shows the inline error box', (tester) async {
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
      await tester.enterText(
        find.byKey(const ValueKey('jf-password')),
        'wrong',
      );
      await tester.pump();
      await tester.tap(find.text('Join family'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('jf-error')), findsOneWidget);

      // Typing again clears the error.
      await tester.enterText(find.byKey(const ValueKey('jf-password')), 'd');
      await tester.pump();
      expect(find.byKey(const ValueKey('jf-error')), findsNothing);
    });
  });

  group('#284 non-functional: long names & many members', () {
    testWidgets('8 members with van-der-Berg-length names render without '
        'layout breaks on hub, family page and member colours', (tester) async {
      await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
      final f = thriveDebug.curFamily()!;
      for (var i = 0; i < 6; i++) {
        f.members.add(
          FamilyMember(
            id: 'big$i',
            name: 'Sophie-Alexandra van der Berg-Janssen the ${i + 1}th',
            email: 'sophie.alexandra.vdberg$i@familie-janssen.example.nl',
            initials: 'SB',
            color: kMemberColors[(i + 3) % kMemberColors.length],
            role: 'member',
          ),
        );
      }
      expect(f.members.length, greaterThanOrEqualTo(8));

      await openMoreHub(tester); // hub family card lists every member
      await tapHubRow(tester, 'family', 'more-member-me'); // family page
      expect(
        find.text('Sophie-Alexandra van der Berg-Janssen the 1th'),
        findsWidgets,
      );
      await tester.tap(find.byKey(const ValueKey('studio-back')));
      await tester.pumpAndSettle();
      await tapHubRow(tester, 'planning', 'more-memcolors');
      await tester.pumpAndSettle();
      // No overflow exceptions anywhere on the way here.
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });
  });
}
