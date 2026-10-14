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

  test(
    'upgrade cancels old device reminders and never schedules new ones',
    () async {
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pluginChannel, (call) async {
            calls.add(call);
            if (call.method == 'initialize') return true;
            if (call.method == 'pendingNotificationRequests') {
              return [
                {
                  'id': 1,
                  'title': 'Old reminder',
                  'body': 'Old',
                  'payload': 'event:ev1:2099-01-10',
                },
                {
                  'id': 2,
                  'title': 'Push',
                  'body': 'Keep',
                  'payload': 'list:l1',
                },
              ];
            }
            return null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _timezoneChannel,
            (call) async => 'Europe/Amsterdam',
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_pluginChannel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_timezoneChannel, null);
      });

      await NotificationService.init();
      await NotificationService.instance.scheduleEventReminder(
        CalendarEvent(
          id: 'ev1',
          title: 'Lunch',
          date: '2099-01-10',
          color: const Color(0xff112233),
          reminder: 'none',
        ),
      );
      await NotificationService.instance.syncEventReminders(const []);
      expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
      final cancelled = calls.where((c) => c.method == 'cancel').toList();
      expect(cancelled, hasLength(1));
      expect((cancelled.single.arguments as Map)['id'], 1);
    },
  );
}
