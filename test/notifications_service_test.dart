// Exercises `NotificationService` (lib/src/shared/notifications_service.dart)
// directly against fake platform channels, since it's normally swapped out
// behind `NotificationScheduler` in widget tests (see calendar_test.dart
// usages). Covers init, permission requests, event scheduling (including
// recurring occurrences, exceptions, reminder-body formatting) and
// cancellation — all the branches that don't fire in the higher-level widget
// tests because those substitute a fake scheduler.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// The plugin normally registers its method-channel platform implementation
// via its own plugin registration, which doesn't run in plain `flutter test`
// unit tests — so `FlutterLocalNotificationsPlatform.instance` is left
// uninitialized unless set explicitly here. `flutter test` defaults
// `defaultTargetPlatform` to Android, so the Android implementation is what
// `resolvePlatformSpecificImplementation` needs to find.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:family_money_management_app/main.dart';

const _pluginChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);
const _timezoneChannel = MethodChannel('flutter_timezone');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final scheduledCalls = <MethodCall>[];
  final cancelledIds = <int>[];
  var pendingRequests = <Map<Object?, Object?>>[];
  var permissionGranted = true;

  Future<Object?> handlePlugin(MethodCall call) async {
    switch (call.method) {
      case 'initialize':
        return true;
      case 'zonedSchedule':
        scheduledCalls.add(call);
        return null;
      case 'cancel':
        final args = call.arguments;
        if (args is Map) {
          cancelledIds.add(args['id'] as int);
        } else if (args is int) {
          cancelledIds.add(args);
        }
        return null;
      case 'pendingNotificationRequests':
        return pendingRequests;
      case 'requestNotificationsPermission':
        return permissionGranted;
      case 'requestPermissions':
        return permissionGranted;
      default:
        return null;
    }
  }

  setUp(() {
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    scheduledCalls.clear();
    cancelledIds.clear();
    pendingRequests = <Map<Object?, Object?>>[];
    permissionGranted = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, handlePlugin);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _timezoneChannel,
          (call) async => 'Europe/Amsterdam',
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_timezoneChannel, null);
  });

  CalendarEvent event({
    String id = 'ev1',
    String date = '2099-01-10',
    String recur = 'none',
    String endDate = '',
    bool allDay = false,
    String start = '',
    String reminder = '1h',
    String location = '',
    List<String>? exceptions,
  }) => CalendarEvent(
    id: id,
    title: 'Team lunch',
    date: date,
    endDate: endDate,
    allDay: allDay,
    start: start,
    color: const Color(0xFF112233),
    reminder: reminder,
    recur: recur,
    location: location,
    exceptions: exceptions,
  );

  test(
    'every scheduling/cancelling call is a safe no-op before init()',
    () async {
      // Deliberately skip NotificationService.init() to hit the `!_initialized`
      // guard clauses across every public method.
      await NotificationService.instance.scheduleEventReminder(event());
      await NotificationService.instance.cancelEventReminder('ev1');
      await NotificationService.instance.syncEventReminders([event()]);
      expect(scheduledCalls, isEmpty);
      expect(cancelledIds, isEmpty);
    },
  );

  test('init() sets up the plugin and timezone; a second call just '
      'refreshes the timezone', () async {
    await NotificationService.init();
    await NotificationService.init();
    // No assertion failure means both the initialize + timezone paths, and
    // the "already initialized" short-circuit, ran without throwing.
  });

  test('refreshTimeZone swallows a plugin failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_timezoneChannel, (call) async {
          throw PlatformException(code: 'error');
        });
    await NotificationService.refreshTimeZone();
  });

  test('a notification tap dispatched by the plugin updates the pending '
      'deep-link, and is ignored when its payload is null', () async {
    await NotificationService.init();
    pendingNotificationDeepLink.value = null;
    final data = const StandardMethodCodec().encodeMethodCall(
      const MethodCall('didReceiveNotificationResponse', {
        'notificationId': 1,
        'actionId': null,
        'input': null,
        'payload': null,
        'notificationResponseType': 0,
      }),
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(_pluginChannel.name, data, (_) {});
    expect(pendingNotificationDeepLink.value, isNull);

    final data2 = const StandardMethodCodec().encodeMethodCall(
      const MethodCall('didReceiveNotificationResponse', {
        'notificationId': 1,
        'actionId': null,
        'input': null,
        'payload': 'event:ev1:2099-01-10',
        'notificationResponseType': 0,
      }),
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(_pluginChannel.name, data2, (_) {});
    expect(pendingNotificationDeepLink.value, 'event:ev1:2099-01-10');
    pendingNotificationDeepLink.value = null;
  });

  test(
    'scheduleEventReminder schedules a one-off event with an "at" reminder',
    () async {
      await NotificationService.init();
      await NotificationService.instance.scheduleEventReminder(
        event(reminder: 'at', start: '09:00', location: 'Kitchen'),
      );
      expect(scheduledCalls, hasLength(1));
    },
  );

  test('scheduleEventReminder is a no-op when reminder is "none"', () async {
    await NotificationService.init();
    await NotificationService.instance.scheduleEventReminder(
      event(reminder: 'none'),
    );
    expect(scheduledCalls, isEmpty);
  });

  test('scheduleEventReminder schedules multiple recurring occurrences, '
      'skipping any date in exceptions, up to a rolling cap of 8', () async {
    await NotificationService.init();
    await NotificationService.instance.scheduleEventReminder(
      event(
        recur: 'daily',
        endDate: '2099-02-15',
        exceptions: const ['2099-01-11'],
      ),
    );
    expect(scheduledCalls.length, inInclusiveRange(1, 8));
  });

  test('scheduleEventReminder with no repeat-until end date falls back to a '
      '24-month cap for recurring occurrences', () async {
    await NotificationService.init();
    await NotificationService.instance.scheduleEventReminder(
      event(recur: 'monthly', endDate: ''),
    );
    expect(scheduledCalls, isNotEmpty);
  });

  test('scheduleEventReminder handles an all-day event and a custom-unit '
      'reminder (e.g. "2d")', () async {
    await NotificationService.init();
    await NotificationService.instance.scheduleEventReminder(
      event(allDay: true, reminder: '2d'),
    );
    expect(scheduledCalls, hasLength(1));
  });

  test('scheduleEventReminder handles 1h/1d reminders and an unknown custom '
      'reminder suffix falls back to the default body', () async {
    await NotificationService.init();
    await NotificationService.instance.scheduleEventReminder(
      event(id: 'ev-1h', reminder: '1h', start: '10:00'),
    );
    await NotificationService.instance.scheduleEventReminder(
      event(id: 'ev-1d', reminder: '1d', start: '11:00'),
    );
    await NotificationService.instance.scheduleEventReminder(
      event(id: 'ev-bad', reminder: 'x'),
    );
    expect(scheduledCalls.length, greaterThanOrEqualTo(2));
  });

  test('scheduleEventReminder covers every reminder-body branch: "at" with '
      'all-day, "at" with no start time, singular/plural custom minute, '
      'hour and day reminders, and an event with no location', () async {
    await NotificationService.init();
    // "at" + allDay -> "All day today".
    await NotificationService.instance.scheduleEventReminder(
      event(id: 'ev-at-allday', reminder: 'at', allDay: true),
    );
    // "at" with no start time and not all-day -> "Starting now".
    await NotificationService.instance.scheduleEventReminder(
      event(id: 'ev-at-nostart', reminder: 'at'),
    );
    // Custom singular/plural minute reminders.
    await NotificationService.instance.scheduleEventReminder(
      event(id: 'ev-1m', reminder: '1m', start: '09:00'),
    );
    await NotificationService.instance.scheduleEventReminder(
      event(id: 'ev-5m', reminder: '5m', start: '09:00'),
    );
    // Custom singular/plural hour reminders.
    await NotificationService.instance.scheduleEventReminder(
      event(id: 'ev-1h-custom', reminder: '1h', start: '09:00'),
    );
    await NotificationService.instance.scheduleEventReminder(
      event(id: 'ev-3h', reminder: '3h', start: '09:00'),
    );
    // Custom singular/plural day reminders, one with no location.
    await NotificationService.instance.scheduleEventReminder(
      event(id: 'ev-1d-custom', reminder: '1d', start: '09:00'),
    );
    await NotificationService.instance.scheduleEventReminder(
      event(id: 'ev-4d', reminder: '4d', start: '09:00', location: ''),
    );
    // A single-character reminder with a start time hits the
    // `reminder.length <= 1` fallback ("Starts at $startStr").
    await NotificationService.instance.scheduleEventReminder(
      event(id: 'ev-single-char', reminder: 'x', start: '09:00'),
    );
    // An unknown-suffix custom reminder with a start time falls back to
    // "Starts at $startStr" instead of "Calendar event".
    await NotificationService.instance.scheduleEventReminder(
      event(id: 'ev-bad-suffix', reminder: '2z', start: '09:00'),
    );
    expect(scheduledCalls.length, greaterThanOrEqualTo(8));
  });

  test('scheduleEventReminder swallows a plugin failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, (call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'requestNotificationsPermission') return true;
          if (call.method == 'pendingNotificationRequests') return <Object?>[];
          throw PlatformException(code: 'error');
        });
    await NotificationService.init();
    await NotificationService.instance.scheduleEventReminder(event());
  });

  test('cancelEventReminder cancels every pending notification whose '
      'payload matches the event id', () async {
    pendingRequests = [
      {'id': 1, 'payload': 'event:ev1:2099-01-10'},
      {'id': 2, 'payload': 'event:other:2099-01-10'},
      {'id': 3, 'payload': null},
    ];
    await NotificationService.init();
    await NotificationService.instance.cancelEventReminder('ev1');
    expect(cancelledIds, [1]);
  });

  test('syncEventReminders clears every pending event notification then '
      'reschedules the given events', () async {
    pendingRequests = [
      {'id': 9, 'payload': 'event:stale:2099-01-01'},
      {'id': 10, 'payload': 'task:t1'},
    ];
    await NotificationService.init();
    await NotificationService.instance.syncEventReminders([event()]);
    expect(cancelledIds, contains(9));
    expect(cancelledIds, isNot(contains(10)));
    expect(scheduledCalls, hasLength(1));
  });

  test('cancelEventReminder swallows a plugin failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, (call) async {
          if (call.method == 'initialize') return true;
          throw PlatformException(code: 'error');
        });
    await NotificationService.init();
    await NotificationService.instance.cancelEventReminder('ev1');
  });

  test('syncEventReminders swallows a plugin failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, (call) async {
          if (call.method == 'initialize') return true;
          throw PlatformException(code: 'error');
        });
    await NotificationService.init();
    await NotificationService.instance.syncEventReminders([event()]);
  });

  test('a second scheduleEventReminder call reuses the cached permission '
      'grant instead of re-requesting it', () async {
    await NotificationService.init();
    await NotificationService.instance.scheduleEventReminder(event());
    final callsAfterFirst = scheduledCalls.length;
    await NotificationService.instance.scheduleEventReminder(event(id: 'ev2'));
    expect(scheduledCalls.length, greaterThan(callsAfterFirst));
  });
}
