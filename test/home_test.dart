import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

Map<String, Object> homeEventPrefs() {
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
        role: 'owner',
      ),
    ],
  );
  final category = EventCategory(
    id: 'family',
    name: 'Family',
    color: const Color(0xff0f9d6a),
    icon: 'star',
  );
  final workspace = Workspace.empty()
    ..events = [
      CalendarEvent(
        id: 'upcoming',
        title: 'Family dinner',
        date: todayIso(),
        color: const Color(0xffe11d48),
        category: category.id,
        reminder: 'none',
      ),
    ]
    ..eventCategories = [category];
  return {
    'flutter.$kStorageKeyV4': json.encode({
      'year': 2026,
      'monthIdx': 6,
      'screen': 'overview',
      'tab': 'home',
      'familyId': family.id,
      'families': [family.toJson()],
      'workspaces': {family.id: workspace.toJson()},
    }),
  };
}

void main() {
  testWidgets('upcoming event shows its chosen category visual', (
    tester,
  ) async {
    await pumpApp(tester, prefs: homeEventPrefs(), landOnDefaultTab: true);

    final visual = find.byKey(const ValueKey('home-event-visual-upcoming'));
    expect(find.text('Family dinner'), findsOneWidget);
    expect(visual, findsOneWidget);
    expect(
      find.descendant(of: visual, matching: find.byType(SvgPicture)),
      findsOneWidget,
    );
  });

  testWidgets('Home dashboard shows a greeting and empty states with no data', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    expect(find.text('Hi, Eva'), findsOneWidget);
    expect(find.text('Nothing scheduled — enjoy the calm.'), findsOneWidget);
    expect(find.text('All caught up. Nice work!'), findsOneWidget);
    expect(find.text('No lists yet'), findsOneWidget);
    expect(find.text('Not planned'), findsOneWidget);
    expect(find.textContaining('PROJECTED BALANCE'), findsOneWidget);
  });

  testWidgets('a task created in Lists shows up in Tasks due soon', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);

    await tester.tap(find.byKey(const ValueKey('nav-lists')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Household');
    await tester.pump();
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Household'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Take out the bins');
    await tester.pump();
    await tester.tap(find.text('Add task').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('Take out the bins'), findsOneWidget);
    expect(find.textContaining('Household'), findsOneWidget);

    // Tapping the task row navigates straight into its list's detail.
    await tester.tap(find.text('Take out the bins'));
    await tester.pumpAndSettle();
    expect(find.text('Household'), findsOneWidget);
    expect(find.text('Add task'), findsOneWidget);
  });

  testWidgets(
    'a shopping list created in Lists shows up in the Shopping glance',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);

      await tester.tap(find.byKey(const ValueKey('nav-lists')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shopping'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Supermarket');
      await tester.pump();
      await tester.tap(find.text('Create list'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav-home')));
      await tester.pumpAndSettle();
      expect(find.text('Supermarket'), findsOneWidget);
    },
  );

  testWidgets('tapping the projected balance card opens the Finance tab', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.textContaining('PROJECTED BALANCE'));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
  });
}
