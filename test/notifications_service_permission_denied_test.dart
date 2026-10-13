// Split into its own file (a fresh process per `flutter test` file) because
// `NotificationService`'s cached `_notificationsGranted` flag is a private
// static with no test-visible reset hook — caching a denial here would leak
// into every other test in `notifications_service_test.dart`.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_money_management_app/main.dart';

const _pluginChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);
const _timezoneChannel = MethodChannel('flutter_timezone');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a denied prompt is asked once and never blocks the reminder', () async {
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    SharedPreferences.setMockInitialValues({});
    final scheduledCalls = <MethodCall>[];
    var asks = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, (call) async {
          switch (call.method) {
            case 'initialize':
              return true;
            case 'zonedSchedule':
              scheduledCalls.add(call);
              return null;
            case 'requestNotificationsPermission':
              asks++;
              return false;
            default:
              return null;
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _timezoneChannel,
          (call) async => 'Europe/Amsterdam',
        );

    await NotificationService.init();
    final ev = CalendarEvent(
      id: 'ev1',
      title: 'Team lunch',
      date: '2099-01-10',
      color: const Color(0xFF112233),
    );
    await NotificationService.instance.scheduleEventReminder(ev);
    await NotificationService.instance.scheduleEventReminder(ev);
    // Asked once; a refusal never blocks saving: Android stays silent
    // until notifications are allowed, then the reminder rings (#483).
    expect(asks, 1);
    expect(scheduledCalls, isNotEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(NotificationService.kAskCountKey), 1);
  });
}
