import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

CalendarEvent _add(String id, {String recur = 'none'}) {
  final ev = CalendarEvent(
    id: id,
    title: 'Event $id',
    date: '2026-10-07',
    color: const Color(0xff1684B4),
    recur: recur,
  );
  thriveDebug.mutateState(() => thriveDebug.events.add(ev));
  return ev;
}

void main() {
  testWidgets('deleting an event (local mode) removes it for good', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    final ev = _add('one-off');
    await tester.pumpAndSettle();
    final before = thriveDebug.events.length;

    thriveDebug.deleteEvent(ev.id, 'all');
    await tester.pumpAndSettle();

    expect(thriveDebug.events.any((e) => e.id == ev.id), isFalse);
    expect(thriveDebug.events.length, before - 1);
    // Only member of a local family: acknowledged by everyone at once.
    expect(thriveDebug.deletedEvents, isEmpty);

    await tester.pump(const Duration(seconds: 2));
    await rebootApp(tester);
    expect(thriveDebug.events.any((e) => e.id == ev.id), isFalse);
  });

  testWidgets('removing one occurrence keeps the series', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    final ev = _add('weekly', recur: 'weekly');
    await tester.pumpAndSettle();

    thriveDebug.deleteEvent(ev.id, 'one', ev.date);
    await tester.pumpAndSettle();

    expect(thriveDebug.events.any((e) => e.id == ev.id), isTrue);
    expect(thriveDebug.deletedEvents, isEmpty);
  });
}
