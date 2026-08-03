// Split into its own file (a fresh process per `flutter test` file) because
// `NotificationService.init()` is a no-op once its private static
// `_initialized` flag is set true by any other test in the same process.
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

  test('init() swallows a plugin initialize failure', () async {
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, (call) async {
          throw PlatformException(code: 'error');
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _timezoneChannel,
          (call) async => 'Europe/Amsterdam',
        );
    await NotificationService.init();
    // No thrown exception means the init() catch swallowed the failure and
    // `_initialized` stayed false.
  });
}
