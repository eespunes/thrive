import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Child users: a kid profile converted into a signed-in user. They only see
// their own events and lists, a read-only meal plan, and never money,
// discount cards or the kitchen wall.

void _seedFamilyData() {
  final today = todayIso();
  final me = thriveDebug.myId;
  thriveDebug.mutateState(() {
    thriveDebug.events
      ..add(
        CalendarEvent(
          id: 'ev-mine',
          title: 'Football practice',
          date: today,
          allDay: true,
          color: const Color(0xff1684B4),
          reminder: 'none',
          attendees: [me],
        ),
      )
      ..add(
        CalendarEvent(
          id: 'ev-other',
          title: 'Parents evening',
          date: today,
          allDay: true,
          color: const Color(0xff1684B4),
          reminder: 'none',
          attendees: ['m2'],
          createdBy: 'm2',
        ),
      );
    thriveDebug.taskLists
      ..add(
        TaskList(
          id: 'tl-mine',
          name: 'My homework',
          color: const Color(0xff0E9A8D),
          createdBy: me,
        ),
      )
      ..add(
        TaskList(
          id: 'tl-other',
          name: 'House chores',
          color: const Color(0xff0E9A8D),
          createdBy: 'm2',
        ),
      );
    thriveDebug.shoppingLists.add(
      ShoppingList(id: 'sl-other', name: 'Groceries', createdBy: 'm2'),
    );
  });
}

void _makeMeKid() {
  thriveDebug.mutateState(() {
    thriveDebug.curFamily()!.members.first.role = 'kid';
  });
}

void main() {
  group('claimableKidRow', () {
    FamilyMember row(
      String id, {
      String role = 'kid',
      String? uid,
      String email = '',
    }) => FamilyMember(
      id: id,
      name: id,
      email: email,
      initials: 'X',
      color: const Color(0xff0E9A8D),
      role: role,
      uid: uid,
    );

    test('claims a login-less kid row with the matching email', () {
      final members = [
        row('owner', role: 'owner', uid: 'u1', email: 'mum@x.com'),
        row('kid1', email: 'Nora@X.com '),
      ];
      expect(claimableKidRow(members, 'nora@x.com')?.id, 'kid1');
    });

    test('never claims members, owners or kids that already have a login', () {
      final members = [
        row('m', role: 'member', email: 'a@x.com'),
        row('o', role: 'owner', email: 'b@x.com'),
        row('k', uid: 'taken', email: 'c@x.com'),
      ];
      expect(claimableKidRow(members, 'a@x.com'), isNull);
      expect(claimableKidRow(members, 'b@x.com'), isNull);
      expect(claimableKidRow(members, 'c@x.com'), isNull);
      expect(claimableKidRow(members, ''), isNull);
    });
  });

  test('lists round-trip their creator', () {
    final t = TaskList.fromJson(
      TaskList(
        id: 'a',
        name: 'A',
        color: const Color(0xff000000),
        createdBy: 'k',
      ).toJson(),
    );
    final s = ShoppingList.fromJson(
      ShoppingList(id: 'b', name: 'B', createdBy: 'k').toJson(),
    );
    expect(t.createdBy, 'k');
    expect(s.createdBy, 'k');
  });

  group('server-side kid scoping data', () {
    test('kidEmails lists kid profiles with an email, lowercased', () {
      FamilyMember m(String id, String role, String email) => FamilyMember(
        id: id,
        name: id,
        email: email,
        initials: 'X',
        color: const Color(0xff0E9A8D),
        role: role,
      );
      expect(
        deriveKidEmails([
          m('o', 'owner', 'mum@x.com'),
          m('k1', 'kid', ' Nora@X.com'),
          m('k2', 'kid', ''),
          m('p', 'member', 'dad@x.com'),
        ]),
        {'nora@x.com': 'k1'},
      );
    });

    test('kidEmails round-trips on the family', () {
      final f = Family(
        id: 'f',
        name: 'F',
        members: [],
        kidEmails: {'nora@x.com': 'k1'},
      );
      expect(Family.fromJson(f.toJson()).kidEmails, {'nora@x.com': 'k1'});
      expect(
        Family(id: 'f', name: 'F', members: []).toJson(),
        isNot(contains('kidEmails')),
      );
    });

    test('list items carry their list owner for the rules', () {
      final ws = Workspace.empty()
        ..taskLists = [
          TaskList(
            id: 'l1',
            name: 'Homework',
            color: const Color(0xff0E9A8D),
            createdBy: 'kid-uid',
            tasks: [ListTask(id: 't1', title: 'Maths')],
          ),
        ];
      final recs = normalizedRecords(ws);
      final item = recs.entries
          .firstWhere((e) => e.key.startsWith('$kListItemsCol/'))
          .value;
      expect(item['_listOwner'], 'kid-uid');
      // The marker is internal: it never leaks back into the model.
      final back = workspaceFromRecords(recs);
      expect(back.taskLists.single.createdBy, 'kid-uid');
      expect(
        back.taskLists.single.tasks.single.toJson(),
        isNot(contains('_listOwner')),
      );
    });
  });

  testWidgets('a regular member still sees everything', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    _seedFamilyData();
    await tester.pumpAndSettle();
    expect(thriveDebug.isChildUser, isFalse);
    final ids = thriveDebug
        .eventOccurrences(todayIso(), todayIso())
        .map((o) => o.ev.id);
    expect(ids, containsAll(['ev-mine', 'ev-other']));
    expect(thriveDebug.visibleTaskLists.map((l) => l.id), contains('tl-other'));
    expect(thriveDebug.navPickedTabs, contains('finance'));
  });

  testWidgets('a child user only sees their own events and lists', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    _seedFamilyData();
    _makeMeKid();
    await tester.pumpAndSettle();
    expect(thriveDebug.isChildUser, isTrue);

    final ids = thriveDebug
        .eventOccurrences(todayIso(), todayIso())
        .map((o) => o.ev.id)
        .toList();
    expect(ids, contains('ev-mine'));
    expect(ids, isNot(contains('ev-other')));

    expect(thriveDebug.visibleTaskLists.map((l) => l.id), ['tl-mine']);
    expect(thriveDebug.visibleShoppingLists, isEmpty);

    // A list they create is theirs and stays visible.
    thriveDebug.saveTaskList('Reading log', const Color(0xff0E9A8D));
    await tester.pumpAndSettle();
    expect(
      thriveDebug.visibleTaskLists.map((l) => l.name),
      contains('Reading log'),
    );

    // Phone widgets carry neither other people's events nor money.
    final payload = thriveDebug.phoneWidgetPayload();
    final todayEvents = (payload['today'] as Map)['events'] as List;
    expect(
      todayEvents.map((e) => (e as Map)['id']),
      isNot(contains('ev-other')),
    );
    expect(payload['card'], isNull);
    expect((payload['money'] as Map)['bills'], isEmpty);
  });

  testWidgets('a child user has no finance tab, kitchen or discount cards', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    _makeMeKid();
    await tester.pumpAndSettle();

    expect(thriveDebug.navPickedTabs, ['calendar', 'lists', 'weekly']);
    expect(find.byKey(const ValueKey('nav-finance')), findsNothing);
    expect(find.byKey(const ValueKey('nav-weekly')), findsOneWidget);

    thriveDebug.goTab('finance');
    await tester.pumpAndSettle();
    expect(thriveDebug.tab, isNot('finance'));

    thriveDebug.openWalletScreen();
    await tester.pumpAndSettle();
    expect(thriveDebug.toast, contains('Discount cards'));

    await tester.tap(find.byKey(const ValueKey('nav-calendar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cal-view-kitchen')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hub-card-money')), findsNothing);
  });

  testWidgets('the meal plan is read-only for a child user', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    _makeMeKid();
    await tester.pumpAndSettle();
    final today = todayIso();
    thriveDebug.setMeal(today, 'dinner', 'Pizza');
    await tester.pumpAndSettle();
    expect(thriveDebug.weeklyPlan[today]?.dinner, isNot('Pizza'));
    expect(thriveDebug.toast, contains('read-only'));
  });
}
