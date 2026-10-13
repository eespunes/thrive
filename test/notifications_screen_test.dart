// Settings → Notifications (#473, #483, #484) and push deep links (#474),
// driven through the real app with the native notifications channel faked.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

const _native = MethodChannel('cat.eespunes.thrive/notifications');
const _plugin = MethodChannel('dexterous.com/flutter/local_notifications');

class _FakeMessaging implements PushMessaging {
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<RemoteNotif>.broadcast();
  final opened = StreamController<String>.broadcast();
  String? initial;

  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<void> deleteToken() async {}
  @override
  Stream<RemoteNotif> get onForeground => foreground.stream;
  @override
  Stream<String> get onOpened => opened.stream;
  @override
  Future<String?> initialLink() async => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var state = <String, Object?>{'enabled': true};
  final opened = <Map>[];

  setUp(() {
    state = {'enabled': true};
    opened.clear();
    messenger.setMockMethodCallHandler(_native, (call) async {
      if (call.method == 'open') {
        opened.add(call.arguments as Map);
        return null;
      }
      return state;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_native, null);
    messenger.setMockMethodCallHandler(_plugin, null);
    PushService.messaging = null;
    pendingNotificationDeepLink.value = null;
  });

  final list = find.descendant(
    of: find.byKey(const ValueKey('notif-list')),
    matching: find.byType(Scrollable),
  );

  Future<void> openPage(WidgetTester tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    openNotifs();
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(f, 80, scrollable: list);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('hub row opens the page; granted shows no permission card '
      '(1a)', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await openHubCard(tester, 'account', 'more-signout');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('hub-notifications')),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('hub-notifications')));
    await tester.pumpAndSettle();

    expect(find.text('What reaches you on this phone'), findsOneWidget);
    expect(find.text('FROM YOUR FAMILY'), findsOneWidget);
    expect(find.text('Paused on this phone'), findsNothing);
    expect(find.byKey(const ValueKey('notif-perm-turn-on')), findsNothing);
    // The Echo wall waits for the Alexa wall (#460).
    expect(find.byKey(const ValueKey('notif-row-wall')), findsNothing);
    for (final t in ['chores', 'lists', 'cal', 'money', 'family']) {
      expect(find.byKey(ValueKey('notif-row-$t')), findsOneWidget);
    }
    expect(find.text('Only my kids’ chores'), findsOneWidget);
    expect(
      find.text(
        'Sent when someone else changes something. Tap a type '
        'to choose whose updates.',
      ),
      findsOneWidget,
    );
    expect(find.text('Allowed'), findsOneWidget);
  });

  testWidgets('undecided (2a): Turn on asks, then the page refreshes', (
    tester,
  ) async {
    state = {'enabled': false, 'rationale': false, 'sdk': 34};
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    messenger.setMockMethodCallHandler(_plugin, (call) async {
      if (call.method == 'requestNotificationsPermission') {
        state = {'enabled': true};
        return true;
      }
      return null;
    });
    await openPage(tester);
    expect(find.text('Notifications are off for Thrive'), findsOneWidget);
    expect(find.text('Paused on this phone'), findsOneWidget);
    expect(
      find.textContaining('Your choices are saved to your account.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('notif-perm-turn-on')));
    await tester.pumpAndSettle();
    expect(thriveDebug.notifDevice.value.granted, isTrue);
    expect(find.text('Notifications are off for Thrive'), findsNothing);
  });

  testWidgets('denied (2c): Not now explains; Ask again asks', (tester) async {
    state = {'enabled': false, 'rationale': true, 'sdk': 34};
    await openPage(tester);
    expect(find.text('You chose “Don’t allow” last time'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notif-perm-not-now')));
    await tester.pump();
    expect(thriveDebug.toast, 'OK. You can turn them on here any time');
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.byKey(const ValueKey('notif-perm-ask-again')));
    await tester.pumpAndSettle();
    expect(thriveDebug.notifDevice.value.permission, NotifPermission.denied);
  });

  testWidgets('blocked (2d) opens Android settings; test needs permission', (
    tester,
  ) async {
    state = {'enabled': false, 'rationale': false, 'sdk': 30};
    await openPage(tester);
    expect(find.text('Notifications are blocked'), findsOneWidget);
    expect(find.text('Thrive checks again when you come back.'), findsOne);
    await tester.tap(find.byKey(const ValueKey('notif-perm-open-settings')));
    await tester.pumpAndSettle();
    expect(opened.single['what'], 'app');

    await tapKey(tester, 'notif-test');
    expect(thriveDebug.toast, 'Turn on notifications first');
  });

  testWidgets('a channel off in Android (2e) shows Fix and blocks the switch', (
    tester,
  ) async {
    state = {
      'enabled': true,
      'channels': {'family_lists': false},
    };
    await openPage(tester);
    expect(find.byKey(const ValueKey('notif-chan-off-lists')), findsOneWidget);
    expect(find.byKey(const ValueKey('notif-scope-lists')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('notif-type-lists')));
    await tester.pump();
    expect(thriveDebug.toast, 'Turn it on in Android settings first');
    await tester.tap(find.byKey(const ValueKey('notif-fix-lists')));
    await tester.pumpAndSettle();
    expect(opened.single, {'what': 'channel', 'channel': 'family_lists'});
  });

  testWidgets('exact alarms off (2f): Allow asks Android', (tester) async {
    state = {'enabled': true, 'exact': false};
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    messenger.setMockMethodCallHandler(_plugin, (call) async {
      if (call.method == 'requestExactAlarmsPermission') {
        state = {'enabled': true, 'exact': true};
        return true;
      }
      return null;
    });
    await openPage(tester);
    expect(find.text('Off · reminders can be a few minutes late'), findsOne);
    await tapKey(tester, 'notif-exact-allow');
    expect(thriveDebug.toast, 'Exact timing allowed');
    expect(find.text('Allowed'), findsOneWidget);
  });

  testWidgets('dark (2g) uses the Family Vault palette', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.futureDark = true;
    openNotifs();
    await tester.pumpAndSettle();
    final scaffold = tester.widget<Scaffold>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('notif-list')),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(scaffold.backgroundColor, const Color(0xff0b1016));
    await tester.tap(find.byKey(const ValueKey('notif-scope-chores')));
    await tester.pumpAndSettle();
    expect(find.text('WHOSE CHORES'), findsOneWidget);
  });

  testWidgets('type switches: off hides the scope; back on restores events', (
    tester,
  ) async {
    await openPage(tester);
    await tester.tap(find.byKey(const ValueKey('notif-type-family')));
    await tester.pumpAndSettle();
    expect(thriveDebug.notifPrefs.type('family').on, isFalse);
    expect(find.byKey(const ValueKey('notif-scope-family')), findsNothing);

    // An account with every event unticked arrives switched off.
    expect(
      thriveDebug.adoptNotifPrefs({
        'money': {
          'on': true,
          'events': {
            'added': false,
            'edited': false,
            'paid': false,
            'received': false,
          },
        },
      }),
      isTrue,
    );
    expect(thriveDebug.adoptNotifPrefs('bad'), isFalse);
    expect(thriveDebug.notifPrefs.type('money').on, isFalse);
    expect(thriveDebug.adoptNotifPrefs(thriveDebug.notifPrefs.toJson()), false);
    thriveDebug.mutateState(() {});
    await tester.pumpAndSettle();
    await tapKey(tester, 'notif-type-money');
    expect(thriveDebug.notifPrefs.type('money').eventsOn, 4);
    expect(find.text('All updates'), findsWidgets);

    await tapKey(tester, 'notif-test');
    expect(thriveDebug.toast, 'Test sent. Pull down to see it');
  });

  testWidgets('quiet hours: times cycle, days and the reminder pass-through', (
    tester,
  ) async {
    await openPage(tester);
    expect(find.text('21:30–07:00 · every day'), findsOneWidget);
    await tapKey(tester, 'notif-quiet-from');
    await tapKey(tester, 'notif-quiet-to');
    expect(find.text('22:00–07:30 · every day'), findsOneWidget);
    expect(find.textContaining('arrive as one summary at 07:30'), findsOne);
    await tapKey(tester, 'notif-day-5');
    await tapKey(tester, 'notif-day-6');
    expect(find.text('22:00–07:30 · weekdays'), findsOneWidget);
    await tapKey(tester, 'notif-day-0');
    expect(find.text('22:00–07:30 · 4 days'), findsOneWidget);

    // Reminders are let through by default: quiet hours don't touch them.
    expect(thriveDebug.reminderPlan().quiet, isNull);
    await tapKey(tester, 'notif-quiet-let');
    expect(thriveDebug.reminderPlan().quiet, isNotNull);

    for (var i = 0; i < kQuietFromTimes.length; i++) {
      await tapKey(tester, 'notif-quiet-from');
    }
    expect(thriveDebug.notifPrefs.quiet.from, '22:00');

    await tapKey(tester, 'notif-quiet');
    expect(find.text('Off · updates arrive any time'), findsOneWidget);
    expect(find.byKey(const ValueKey('notif-quiet-from')), findsNothing);

    // Choices follow the account: they survive a restart.
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await rebootApp(tester);
    expect(thriveDebug.notifPrefs.quiet.on, isFalse);
    expect(thriveDebug.notifPrefs.quiet.to, '07:30');
  });

  testWidgets('scope sheet: who, picked people and which events (§3)', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.addMember('Liv', emoji: '🦄');
    final liv = thriveDebug.curFamily()!.members.last;
    thriveDebug.mutateState(() => liv.role = 'kid');
    openNotifs();
    await tester.pumpAndSettle();

    expect(thriveDebug.notifScopeHint('chores', 'kids'), 'Liv');
    expect(thriveDebug.notifScopeHint('cal', 'mine'), contains('Liv'));
    expect(thriveDebug.notifScopeHint('lists', 'mine'), '0 lists');
    expect(thriveDebug.notifScopeHint('money', 'shared'), isNotEmpty);
    expect(thriveDebug.notifScopeHint('family', 'all'), '');

    await tester.tap(find.byKey(const ValueKey('notif-scope-chores')));
    await tester.pumpAndSettle();
    expect(find.text('WHOSE CHORES'), findsOneWidget);
    expect(find.text('TELL ME WHEN'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notif-opt-pick')));
    await tester.pumpAndSettle();
    expect(find.text('Me'), findsOneWidget);
    // Defaults pick the kids; un-pick Liv: no one left.
    await tester.tap(find.byKey(ValueKey('notif-pick-${liv.id}')));
    await tester.pumpAndSettle();
    expect(thriveDebug.notifScopeLabel('chores'), 'No one yet');
    await tester.tap(find.byKey(ValueKey('notif-pick-${liv.id}')));
    await tester.pumpAndSettle();
    expect(thriveDebug.notifScopeLabel('chores'), 'Liv');

    await tester.tap(find.byKey(const ValueKey('notif-ev-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notif-ev-reward')));
    await tester.pump();
    expect(thriveDebug.toast, 'Keep one, or turn Chores & rewards off');
    expect(thriveDebug.notifPrefs.type('chores').eventsOn, 1);
    await tester.tap(find.byKey(const ValueKey('notif-sheet-done')));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);

    // Event starts follow the Calendar scope (#485).
    final plan = thriveDebug.reminderPlan();
    final ev = CalendarEvent(
      id: 'e',
      title: 'Swim',
      date: '2099-01-01',
      color: Colors.teal,
      attendees: [liv.id],
    );
    expect(plan.startFor!(ev), isTrue);
    expect(plan.memberNames!(ev), 'Liv');
  });

  testWidgets('push links route to their screen (#474)', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.mutateState(
      () => thriveDebug.events.add(
        CalendarEvent(
          id: 'c1',
          title: 'Make bed',
          date: '2026-01-01',
          color: Colors.teal,
        ),
      ),
    );

    Future<void> fire(String link) async {
      pendingNotificationDeepLink.value = link;
      await tester.pumpAndSettle();
      expect(pendingNotificationDeepLink.value, isNull);
    }

    Future<void> back() async {
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();
    }

    await fire('chore:c1');
    expect(thriveDebug.tab, 'calendar');
    await back();

    await fire('money:2027-03-14');
    expect(thriveDebug.tab, 'finance');
    expect(thriveDebug.year, 2027);
    expect(thriveDebug.monthIdx, 2);
    await back();

    await fire('reward:nobody');
    expect(thriveDebug.tab, 'home');
    final me = thriveDebug.curFamily()!.members.first.id;
    await fire('reward:$me');
    await back();

    await fire('members');
    expect(thriveDebug.tab, 'more');
    await back();

    await fire('digest');
    expect(thriveDebug.tab, 'home');
    for (final stale in ['chore:gone', 'list:gone', 'money:nope', 'what']) {
      await fire(stale);
    }
    expect(thriveDebug.tab, 'home');
  });

  testWidgets('FCM: foreground pushes, taps and the launch link (#471)', (
    tester,
  ) async {
    final fake = _FakeMessaging()..initial = 'digest';
    PushService.messaging = fake;
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-finance')));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      fake.foreground.add(const RemoteNotif(title: 'Hi', body: 'b'));
      fake.refresh.add('t2');
      fake.opened.add('members');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(thriveDebug.tab, 'more');
    expect(thriveDebug.screen, isNotNull);
  });
}

void openNotifs() => thriveDebug.openNotificationsScreen();
