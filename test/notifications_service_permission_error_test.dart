// Split into its own file (a fresh process per `flutter test` file) so the
// permission-request exception here doesn't cache a stale
// `_notificationsGranted` value that would leak into other test files.
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

  test('_requestPermissionFromPlatform swallows a permission-request failure '
      'and treats it as denied', () async {
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    final scheduledCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, (call) async {
          switch (call.method) {
            case 'initialize':
              return true;
            case 'zonedSchedule':
              scheduledCalls.add(call);
              return null;
            case 'requestNotificationsPermission':
              throw PlatformException(code: 'error');
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
    expect(scheduledCalls, isEmpty);
  });
}
