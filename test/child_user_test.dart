import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Kid accounts: a login restricted to kid access. They only see
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

  group('kid account data', () {
    test('admins and kid logins round-trip on the family', () {
      final f = Family(
        id: 'f',
        name: 'F',
        members: [],
        ownerUid: 'o',
        adminUids: ['a'],
        kidUids: {'k-uid': 'k1'},
      );
      final back = Family.fromJson(f.toJson());
      expect(back.adminUids, ['a']);
      expect(back.kidUids, {'k-uid': 'k1'});
      final plain = Family(id: 'f', name: 'F', members: []).toJson();
      expect(plain, isNot(contains('adminUids')));
      expect(plain, isNot(contains('kidUids')));
    });

    test('the owner and listed admins are admins, kids never are', () {
      final f = Family(
        id: 'f',
        name: 'F',
        members: [],
        ownerUid: 'o',
        adminUids: ['a', 'k-uid'],
        kidUids: {'k-uid': 'k1'},
      );
      expect(f.isAdminUid('o'), isTrue);
      expect(f.isAdminUid('a'), isTrue);
      expect(f.isAdminUid('m'), isFalse);
      expect(f.isAdminUid('k-uid'), isFalse);
      expect(f.isAdminUid(null), isFalse);
    });

    test('member login fields round-trip and default to none', () {
      final m = FamilyMember(
        id: 'k1',
        name: 'Liv',
        email: '',
        initials: 'L',
        color: const Color(0xff0E9A8D),
        role: 'kid',
        uid: 'k-uid',
        loginMethod: 'email',
        loginEmail: 'eva+liv@janssen.nl',
        managed: true,
        linkedBy: 'Eva',
        linkedAt: 1,
        kidSetBy: 'Eva',
        kidSetAt: 2,
        accessChange: {'to': 'kid', 'by': 'Eva', 'byId': 'o', 'at': 3},
        signedOutAt: 4,
      );
      final back = FamilyMember.fromJson(m.toJson());
      expect(back.loginMethod, 'email');
      expect(back.loginEmail, 'eva+liv@janssen.nl');
      expect(back.managed, isTrue);
      expect(back.linkedBy, 'Eva');
      expect(back.linkedAt, 1);
      expect(back.kidSetBy, 'Eva');
      expect(back.kidSetAt, 2);
      expect(back.accessChange?['to'], 'kid');
      expect(back.signedOutAt, 4);
      expect(back.copy().toJson(), m.toJson());
      expect(back.hasLogin, isTrue);
      expect(back.loginPending, isFalse);

      final plain = FamilyMember(
        id: 'x',
        name: 'X',
        email: '',
        initials: 'X',
        color: const Color(0xff0E9A8D),
      ).toJson();
      for (final k in ['loginMethod', 'managed', 'accessChange']) {
        expect(plain, isNot(contains(k)));
      }
    });

    test('a linked Google account without a uid is pending', () {
      final m = FamilyMember(
        id: 'k2',
        name: 'Daan',
        email: '',
        initials: 'D',
        color: const Color(0xff0E9A8D),
        role: 'kid',
        loginMethod: 'google',
        loginEmail: 'daan@gmail.com',
      );
      expect(m.loginPending, isTrue);
      expect(m.hasLogin, isFalse);
    });

    test('list lines live under their note (scoped by the note owner)', () {
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
      final note = recs.entries.firstWhere(
        (e) => recordKind(e.key) == RecordKind.note,
      );
      expect(note.value['createdBy'], 'kid-uid');
      final line = recs.keys.firstWhere(
        (k) => recordKind(k) == RecordKind.line,
      );
      expect(line.startsWith('${note.key}/$kLinesCol/'), isTrue);
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
