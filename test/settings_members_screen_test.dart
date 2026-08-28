import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'settings_v2_seed.dart';

/// Member colours sub-screen + member studio (#276).
void main() {
  Future<void> openMembers(WidgetTester tester) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    await openMoreHub(tester);
    await tapHubRow(tester, 'planning', 'more-memcolors');
  }

  testWidgets('lists only ACTIVE members with role subtitles', (tester) async {
    await openMembers(tester);
    expect(find.text('Member colours'), findsWidgets);
    expect(find.byKey(const ValueKey('memcolors-row-me')), findsOneWidget);
    expect(find.text('Eva Janssen (you)'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.byKey(const ValueKey('memcolors-row-m2')), findsOneWidget);
    // Lisa is invited → not listed here.
    expect(find.byKey(const ValueKey('memcolors-row-m3')), findsNothing);
    expect(find.textContaining('unique per family'), findsOneWidget);
    // No delete anywhere on this flow.
    expect(find.byKey(const ValueKey('studio-delete')), findsNothing);
  });

  testWidgets('taken colours are dimmed and explain themselves', (
    tester,
  ) async {
    await openMembers(tester);
    await tester.tap(find.byKey(const ValueKey('memcolors-row-m2')));
    await tester.pumpAndSettle();
    expect(find.text('Edit member'), findsOneWidget);
    // Eva's + Lisa's colours are taken for Erik.
    final takenDot = find.byKey(
      ValueKey('badge-color-${kMemberColors[0].toARGB32()}'),
    );
    await tester.tap(takenDot);
    await tester.pump();
    expect(find.text('That colour is taken in this family'), findsOneWidget);
    // Erik keeps his own colour.
    final erik = thriveDebug.families.first.members.firstWhere(
      (m) => m.id == 'm2',
    );
    expect(erik.color, kMemberColors[1]);
  });

  testWidgets('picking a free colour + name + email saves everywhere', (
    tester,
  ) async {
    await openMembers(tester);
    await tester.tap(find.byKey(const ValueKey('memcolors-row-m2')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('badge-stage-name')),
      'Erik J.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('member-email')),
      'erik@home.nl',
    );
    final freeColor = kMemberColors[4];
    await tester.tap(
      find.byKey(ValueKey('badge-color-${freeColor.toARGB32()}')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(find.text('Member saved — updated everywhere'), findsOneWidget);
    final erik = thriveDebug.families.first.members.firstWhere(
      (m) => m.id == 'm2',
    );
    expect(erik.name, 'Erik J.');
    expect(erik.email, 'erik@home.nl');
    expect(erik.color, freeColor);
    expect(erik.initials, 'EJ');
    // The list reflects it immediately.
    expect(find.text('Erik J.'), findsOneWidget);
  });

  testWidgets('a free emoji becomes the badge for login-less members', (
    tester,
  ) async {
    await openMembers(tester);
    await tester.tap(find.byKey(const ValueKey('memcolors-row-m2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-link')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('badge-stage-emoji-input')),
      '🦊',
    );
    await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-use')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    final erik = thriveDebug.families.first.members.firstWhere(
      (m) => m.id == 'm2',
    );
    expect(erik.emoji, '🦊');
    expect(erik.photo, isNull);
  });

  testWidgets('editing yourself mirrors onto the signed-in user', (
    tester,
  ) async {
    await openMembers(tester);
    await tester.tap(find.byKey(const ValueKey('memcolors-row-me')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('badge-stage-name')),
      'Eva J.',
    );
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(thriveDebug.user!.name, 'Eva J.');
    await tester.tap(find.byKey(const ValueKey('studio-back')));
    await tester.pumpAndSettle();
    // The hub hero shows the new name too.
    expect(find.text('Eva J.'), findsWidgets);
  });
}
