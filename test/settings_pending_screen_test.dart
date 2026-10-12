import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'settings_v2_seed.dart';

/// Settings → Unsaved changes.
void main() {
  Future<void> openPending(WidgetTester tester) async {
    await openMoreHub(tester);
    await tapHubRow(tester, 'account', 'hub-pending');
  }

  testWidgets('shows "All changes saved" when nothing is pending', (
    tester,
  ) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    await openPending(tester);
    expect(find.byKey(const ValueKey('pending-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('pending-retry')), findsNothing);
  });

  testWidgets('lists an unsaved change and discards it', (tester) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    final ev = CalendarEvent(
      id: 'offline-1',
      title: 'Dentist',
      date: todayIso(),
      color: const Color(0xff1684B4),
    );
    thriveDebug.mutateState(() => thriveDebug.events.add(ev));
    final key = eventRecordKey(ev);
    final fid = thriveDebug.familyId;
    thriveDebug.pendingChanges.record(
      fid,
      key,
      record: ev.toJson(),
      serverRecord: null,
      now: DateTime.now().millisecondsSinceEpoch,
    );
    thriveDebug.pendingChangesChanged();
    await tester.pumpAndSettle();

    await openPending(tester);
    final row = find.byKey(ValueKey('pending-$fid|$key'));
    expect(row, findsOneWidget);
    expect(find.text('Dentist'), findsOneWidget);
    expect(find.textContaining('Added event'), findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pending-empty')), findsOneWidget);
    expect(thriveDebug.pendingChanges.isEmpty, isTrue);
    // A discarded create is removed again.
    expect(thriveDebug.events.any((e) => e.id == 'offline-1'), isFalse);
  });
}
