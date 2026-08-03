// Split into its own file (a fresh process) so overriding
// `debugDefaultTargetPlatformOverride` to iOS here doesn't affect the
// Android-targeted assumptions the other notification test files rely on.
import 'package:flutter/foundation.dart';
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

  test('on iOS, _requestPermissionFromPlatform calls requestPermissions '
      'instead of the Android channel method', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    FlutterLocalNotificationsPlatform.instance =
        IOSFlutterLocalNotificationsPlugin();
    final scheduledCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, (call) async {
          switch (call.method) {
            case 'initialize':
              return true;
            case 'zonedSchedule':
              scheduledCalls.add(call);
              return null;
            case 'requestPermissions':
              return true;
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
        id: 'ev-ios',
        title: 'Team lunch',
        date: '2099-01-10',
        color: const Color(0xFF112233),
      ),
    );
    expect(scheduledCalls, hasLength(1));
  });
}
