import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

const MethodChannel _channel = MethodChannel(
  'cat.eespunes.thrive/device_calendar',
);

CalendarEvent _ev(
  String id,
  String title, {
  String endDate = '',
  String recur = 'none',
}) {
  return CalendarEvent(
    id: id,
    title: title,
    date: '2026-06-10',
    endDate: endDate,
    start: '09:00',
    end: '10:00',
    color: Colors.blue,
    recur: recur,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    DeviceCalendarSync.instance.cancelPending();
  });

  testWidgets('debounced sync pushes the payload over the platform channel', (
    tester,
  ) async {
    final calls = <List<Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add((call.arguments as Map)['events'] as List<Object?>);
          return null;
        });

    final sync = DeviceCalendarSync.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // Multi-day span exercises the endDate>date branch of the payload.
    sync.syncEvents([_ev('e1', 'Trip', endDate: '2026-06-12')]);
    expect(sync.saving.value, isTrue);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(calls, hasLength(1));
    final first = calls.single.single! as Map;
    expect(first['title'], 'Trip');
    expect(first['endDate'], '2026-06-12');
    expect(sync.saving.value, isFalse);

    // Same digest again — skipped without a second channel call.
    sync.syncEvents([_ev('e1', 'Trip', endDate: '2026-06-12')]);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(calls, hasLength(1));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a sync queued while one is running is flushed afterwards', (
    tester,
  ) async {
    final completers = <Completer<void>>[];
    final titles = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) {
          final events = (call.arguments as Map)['events'] as List<Object?>;
          titles.add((events.single! as Map)['title'] as String);
          final c = Completer<void>();
          completers.add(c);
          return c.future;
        });

    final sync = DeviceCalendarSync.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    sync.syncEvents([_ev('e2', 'First')]);
    await tester.pump(const Duration(seconds: 3));
    expect(titles, ['First']);

    // Queue a different payload while the channel call is still in flight.
    sync.syncEvents([_ev('e2', 'Second')]);
    await tester.pump(const Duration(seconds: 3));
    expect(sync.saving.value, isTrue);

    completers[0].complete();
    await tester.pump();
    await tester.pump();
    expect(titles, ['First', 'Second']);
    completers[1].complete();
    await tester.pump();
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
    expect(sync.saving.value, isFalse);
  });

  testWidgets('a PlatformException from the channel is swallowed', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          throw PlatformException(code: 'boom', message: 'nope');
        });

    final sync = DeviceCalendarSync.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    sync.syncEvents([_ev('e3', 'Broken')]);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(sync.saving.value, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}
