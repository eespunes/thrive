// Push notifications on the device (#469): permission state, channels,
// remote display, "Approve" actions and event-start scheduling, all against
// fake platform channels.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_money_management_app/main.dart';

const _pluginChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);
const _timezoneChannel = MethodChannel('flutter_timezone');
const _nativeChannel = MethodChannel('cat.eespunes.thrive/notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];
  var failShow = false;

  Future<Object?> handlePlugin(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'initialize':
        return true;
      case 'show':
        if (failShow) throw PlatformException(code: 'x');
        return null;
      case 'pendingNotificationRequests':
        return <Map<Object?, Object?>>[];
      case 'requestNotificationsPermission':
        return true;
      default:
        return null;
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    calls.clear();
    failShow = false;
    messenger.setMockMethodCallHandler(_pluginChannel, handlePlugin);
    messenger.setMockMethodCallHandler(
      _timezoneChannel,
      (call) async => 'Europe/Amsterdam',
    );
    await NotificationService.init();
    calls.clear();
  });

  tearDown(() {
    NotificationService.plan = const ReminderPlan();
    messenger.setMockMethodCallHandler(_pluginChannel, null);
    messenger.setMockMethodCallHandler(_timezoneChannel, null);
    messenger.setMockMethodCallHandler(_nativeChannel, null);
    notifCallable = (_, _) async {};
  });

  Map<Object?, Object?> specifics(MethodCall c) =>
      (c.arguments as Map)['platformSpecifics'] as Map<Object?, Object?>;

  group('classifyPermission (#483)', () {
    test('maps the platform signals to the four page states', () {
      expect(
        NotificationService.classifyPermission(
          enabled: true,
          rationale: false,
          askCount: 3,
        ),
        NotifPermission.granted,
      );
      expect(
        NotificationService.classifyPermission(
          enabled: false,
          rationale: false,
          askCount: 0,
        ),
        NotifPermission.undecided,
      );
      expect(
        NotificationService.classifyPermission(
          enabled: false,
          rationale: true,
          askCount: 1,
        ),
        NotifPermission.denied,
      );
      expect(
        NotificationService.classifyPermission(
          enabled: false,
          rationale: false,
          askCount: 2,
        ),
        NotifPermission.blocked,
      );
      expect(
        NotificationService.classifyPermission(
          enabled: false,
          rationale: false,
          askCount: 0,
          sdk: 30,
        ),
        NotifPermission.blocked,
      );
    });
  });

  group('readDeviceState', () {
    test('reads permission and channels', () async {
      Object? args;
      messenger.setMockMethodCallHandler(_nativeChannel, (call) async {
        args = call.arguments;
        return {
          'enabled': false,
          'rationale': true,
          'sdk': 34,
          'channels': {'family_lists': false, 'family_chores': true},
        };
      });
      final s = await NotificationService.readDeviceState();
      expect(s.permission, NotifPermission.denied);
      expect(s.granted, isFalse);
      expect(s.channelOn('family_lists'), isFalse);
      expect(s.channelOn('family_chores'), isTrue);
      expect(s.channelOn('unknown'), isTrue);
      expect((args as Map)['channels'], contains('event_start'));
    });

    test('asked before and no rationale reads as blocked', () async {
      SharedPreferences.setMockInitialValues({
        NotificationService.kAskCountKey: 1,
      });
      messenger.setMockMethodCallHandler(
        _nativeChannel,
        (call) async => {'enabled': false, 'rationale': false, 'sdk': 33},
      );
      final s = await NotificationService.readDeviceState();
      expect(s.permission, NotifPermission.blocked);
    });

    test('no native side, a null reply or an error read as granted', () async {
      expect((await NotificationService.readDeviceState()).granted, isTrue);
      messenger.setMockMethodCallHandler(_nativeChannel, (call) async => null);
      expect((await NotificationService.readDeviceState()).granted, isTrue);
      messenger.setMockMethodCallHandler(
        _nativeChannel,
        (call) async => throw PlatformException(code: 'x'),
      );
      expect((await NotificationService.readDeviceState()).granted, isTrue);
    });
  });

  test('askPermission counts every prompt shown', () async {
    expect(await NotificationService.askPermission(), isTrue);
    await NotificationService.askPermission();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(NotificationService.kAskCountKey), 2);
    expect(
      calls.where((c) => c.method == 'requestNotificationsPermission'),
      hasLength(2),
    );
  });

  test(
    'openSystemSettings passes what and channel; errors are swallowed',
    () async {
      final opened = <Object?>[];
      messenger.setMockMethodCallHandler(_nativeChannel, (call) async {
        opened.add(call.arguments);
        return null;
      });
      await NotificationService.openSystemSettings(
        'channel',
        channel: 'family_lists',
      );
      await NotificationService.openSystemSettings('app');
      expect(opened, [
        {'what': 'channel', 'channel': 'family_lists'},
        {'what': 'app'},
      ]);
      messenger.setMockMethodCallHandler(
        _nativeChannel,
        (call) async => throw PlatformException(code: 'x'),
      );
    },
  );

  group('showRemote (#471, #474)', () {
    test('uses the push channel, tag, group and action buttons', () async {
      final n = RemoteNotif.fromData({
        'title': 'Liv wants their reward',
        'body': 'Movie night · 20 ★',
        'link': 'reward:liv',
        'channel': 'family_chores',
        'tag': 'reward:liv',
        'group': 'chores',
        'actions':
            '[{"id":"approve","title":"Approve"},'
            '{"id":"open","title":"Open"}]',
        'approve': '{"familyId":"f1","memberId":"liv","claimId":"c1"}',
      })!;
      await NotificationService.showRemote(n);
      final show = calls.singleWhere((c) => c.method == 'show');
      final args = show.arguments as Map;
      expect(args['title'], 'Liv wants their reward');
      final p = specifics(show);
      expect(p['channelId'], 'family_chores');
      expect(p['tag'], 'reward:liv');
      expect(p['groupKey'], 'chores');
      final actions = (p['actions'] as List).cast<Map>();
      expect(actions.map((a) => a['id']), ['approve', 'open']);
      expect(actions.last['showsUserInterface'], isTrue);
      expect(actions.first['showsUserInterface'], isFalse);
      expect(linkOfPayload(args['payload'] as String), 'reward:liv');
    });

    test('unknown channels fall back; wall pushes are silent; failures are '
        'swallowed', () async {
      await NotificationService.showRemote(
        const RemoteNotif(title: 'A', body: 'b', channel: 'nope'),
      );
      await NotificationService.showRemote(
        const RemoteNotif(title: 'B', body: 'b', channel: 'family_wall'),
      );
      final shows = calls.where((c) => c.method == 'show').toList();
      expect(specifics(shows[0])['channelId'], kNotifChannels.first.id);
      expect(specifics(shows[1])['silent'], isTrue);
      failShow = true;
      await NotificationService.showRemote(
        const RemoteNotif(title: 'C', body: 'c'),
      );
    });
  });

  group('notification actions (#474)', () {
    Future<void> respond(String? actionId, String payload) async {
      final data = const StandardMethodCodec().encodeMethodCall(
        MethodCall('didReceiveNotificationResponse', {
          'notificationId': 1,
          'actionId': actionId,
          'input': null,
          'payload': payload,
          'notificationResponseType': actionId == null ? 0 : 1,
        }),
      );
      await messenger.handlePlatformMessage(_pluginChannel.name, data, (_) {});
    }

    test('"Approve" calls approveReward without opening the app', () async {
      final got = <String, Map<String, dynamic>>{};
      notifCallable = (name, args) async => got[name] = args;
      pendingNotificationDeepLink.value = null;
      const n = RemoteNotif(
        title: 't',
        body: 'b',
        link: 'reward:liv',
        approve: {'familyId': 'f1', 'memberId': 'liv', 'claimId': 'c1'},
      );
      await respond('approve', n.encodedPayload());
      await Future<void>.delayed(Duration.zero);
      expect(got['approveReward'], {
        'familyId': 'f1',
        'memberId': 'liv',
        'claimId': 'c1',
      });
      expect(pendingNotificationDeepLink.value, isNull);

      // "Open" and plain taps follow the link.
      await respond('open', n.encodedPayload());
      expect(pendingNotificationDeepLink.value, 'reward:liv');
      pendingNotificationDeepLink.value = null;
      await respond(null, 'list:l1');
      expect(pendingNotificationDeepLink.value, 'list:l1');
      pendingNotificationDeepLink.value = null;
    });

    test('runNotificationAction ignores bad payloads and failures', () async {
      var n = 0;
      notifCallable = (_, _) async => n++;
      await runNotificationAction('approve', null);
      await runNotificationAction('approve', 'list:l1');
      await runNotificationAction('approve', '{"link":"x"}');
      await runNotificationAction('snooze', '{"approve":{}}');
      expect(n, 0);
      notifCallable = (_, _) async => throw StateError('offline');
      await runNotificationAction('approve', '{"approve":{"a":1}}');
    });
  });

  group('RemoteNotif and payloads', () {
    test('parses data and falls back to the notification block', () {
      expect(RemoteNotif.fromData({}), isNull);
      final n = RemoteNotif.fromData(
        {'actions': 'not json', 'approve': '[1]', 'group': ''},
        title: 'T',
        body: 'B',
      )!;
      expect(n.title, 'T');
      expect(n.body, 'B');
      expect(n.channel, 'family_members');
      expect(n.actions, isEmpty);
      expect(n.approve, isNull);
      expect(n.group, isNull);
      expect(n.encodedPayload(), '');
      final m = RemoteNotif.fromData({
        'title': 'x',
        'actions': [
          {'id': 'open'},
          {'title': 'no id'},
        ],
        'approve': {'a': 1},
      })!;
      expect(m.actions.single.id, 'open');
      expect(m.actions.single.title, '');
      expect(json.decode(m.encodedPayload()), {
        'link': '',
        'approve': {'a': 1},
      });
    });

    test('linkOfPayload reads bare and wrapped links', () {
      expect(linkOfPayload('chore:e1'), 'chore:e1');
      expect(linkOfPayload('{"link":"money:2026-05-01"}'), 'money:2026-05-01');
      expect(linkOfPayload('{"nolink":1}'), '');
      expect(linkOfPayload('{broken'), '');
      expect(linkOfPayload('{"link":null}'), '');
    });

    test('pushDeviceDoc carries the token, zone and channel state', () {
      final doc = pushDeviceDoc(
        token: 'tok',
        platform: 'android',
        timezone: 'Europe/Madrid',
        state: const NotifDeviceState(
          permission: NotifPermission.granted,
          channels: {'family_lists': false},
        ),
      );
      expect(doc['token'], 'tok');
      expect(doc['enabled'], isTrue);
      final ch = doc['channelState'] as Map;
      expect(ch['family_lists'], isFalse);
      expect(ch['family_chores'], isTrue);
      final off = pushDeviceDoc(
        token: 'tok',
        platform: 'android',
        timezone: 'UTC',
        state: const NotifDeviceState(permission: NotifPermission.blocked),
      );
      expect(off['enabled'], isFalse);
      expect((off['channelState'] as Map).values.toSet(), {false});
    });
  });
}
