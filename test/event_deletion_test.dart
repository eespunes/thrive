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

  for (final recur in ['none', 'weekly']) {
    testWidgets('saving an event another member deleted meanwhile (recur: '
        '$recur) keeps it deleted', (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      final ev = _add('edited', recur: recur);
      ev.date = todayIso();
      await tester.pumpAndSettle();
      thriveDebug.openEvent(ev, todayIso());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Renamed');
      await tester.pump();

      // Another member's deletion lands while the editor is open.
      thriveDebug.mutateState(() {
        thriveDebug.events.removeWhere((e) => e.id == ev.id);
        thriveDebug.deletedEvents.add(
          ev..deletion = EventDeletion(by: 'B', at: 1, acks: {'B': 1}),
        );
      });
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();
      if (recur != 'none') {
        await tester.tap(find.byKey(const ValueKey('recur-edit-all')));
        await tester.pumpAndSettle();
      }

      expect(thriveDebug.events.where((e) => e.id == ev.id), isEmpty);
      expect(thriveDebug.events.where((e) => e.title == 'Renamed'), isEmpty);
    });
  }
}
