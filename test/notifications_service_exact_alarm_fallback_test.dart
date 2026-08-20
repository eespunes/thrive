// Split into its own file so NotificationService's private exact-alarm cache
// starts fresh for this fallback case.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:family_money_management_app/main.dart';

const _pluginChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);
const _timezoneChannel = MethodChannel('flutter_timezone');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('event reminders fall back to inexact alarms when exact access is not '
      'available', () async {
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    final scheduledCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, (call) async {
          switch (call.method) {
            case 'initialize':
              return true;
            case 'pendingNotificationRequests':
              return <Object?>[];
            case 'requestNotificationsPermission':
              return true;
            case 'canScheduleExactNotifications':
              return false;
            case 'requestExactAlarmsPermission':
              return false;
            case 'zonedSchedule':
              scheduledCalls.add(call);
              return null;
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
    await NotificationService.instance.scheduleEventReminder(
      CalendarEvent(
        id: 'ev1',
        title: 'Team lunch',
        date: '2099-01-10',
        color: const Color(0xFF112233),
      ),
    );

    expect(scheduledCalls, hasLength(1));
    final args = scheduledCalls.single.arguments as Map;
    final platformSpecifics = args['platformSpecifics'] as Map;
    expect(platformSpecifics['scheduleMode'], 'inexactAllowWhileIdle');
  });
}
