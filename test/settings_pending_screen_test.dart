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

  testWidgets('offline: shows the offline strip; Save now tries again', (
    tester,
  ) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    final ev = CalendarEvent(
      id: 'offline-2',
      title: 'Vet',
      date: todayIso(),
      color: const Color(0xff1684B4),
    );
    thriveDebug.mutateState(() => thriveDebug.events.add(ev));
    thriveDebug.pendingChanges.record(
      thriveDebug.familyId,
      eventRecordKey(ev),
      record: ev.toJson(),
      serverRecord: null,
      now: DateTime.now().millisecondsSinceEpoch,
    );
    thriveDebug.pendingChangesChanged();
    thriveDebug.netOffline.value = true;
    await tester.pumpAndSettle();

    await openPending(tester);
    expect(find.text('Vet'), findsOneWidget);
    expect(
      find.text('You’re offline — changes are kept on this phone'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('pending-retry')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      thriveDebug.toast,
      anyOf('All changes saved', 'Couldn’t save yet — will keep trying'),
    );
    thriveDebug.netOffline.value = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
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
    expect(find.text('Discard this change?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('discard-confirm')));
    await tester.pumpAndSettle();
    expect(thriveDebug.toast, 'Change discarded');
    expect(thriveDebug.toastTone, ToastTone.neutral);

    expect(find.byKey(const ValueKey('pending-empty')), findsOneWidget);
    expect(thriveDebug.pendingChanges.isEmpty, isTrue);
    // A discarded create is removed again.
    expect(thriveDebug.events.any((e) => e.id == 'offline-1'), isFalse);
  });

  testWidgets('lists a set-aside change apart from the data and discards it', (
    tester,
  ) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    final ev = CalendarEvent(
      id: 'staged-1',
      title: 'Plumber',
      date: todayIso(),
      color: const Color(0xff1684B4),
    );
    final fid = thriveDebug.familyId;
    final key = eventRecordKey(ev);
    final change = PendingChange(
      familyId: fid,
      key: key,
      op: PendingOp.save,
      at: DateTime.now().millisecondsSinceEpoch,
      record: ev.toJson(),
    );
    thriveDebug.stagedChanges.addStaged(change);
    thriveDebug.pendingChangesChanged();
    await tester.pumpAndSettle();

    await openPending(tester);
    expect(find.byKey(ValueKey('staged-${change.id}')), findsOneWidget);
    expect(find.text('Plumber'), findsOneWidget);
    expect(find.byKey(const ValueKey('pending-retry')), findsNothing);
    // Set aside: not in the family's data.
    expect(thriveDebug.events.any((e) => e.id == 'staged-1'), isFalse);

    // "Keep it" leaves it set aside.
    await tester.tap(find.byKey(ValueKey('staged-discard-${change.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discard-cancel')));
    await tester.pumpAndSettle();
    expect(thriveDebug.stagedChanges.isEmpty, isFalse);

    await tester.tap(find.byKey(ValueKey('staged-discard-${change.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discard-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pending-empty')), findsOneWidget);
    expect(thriveDebug.stagedChanges.isEmpty, isTrue);
    expect(thriveDebug.events.any((e) => e.id == 'staged-1'), isFalse);
  });

  testWidgets('offers once to review set-aside changes', (tester) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    final change = PendingChange(
      familyId: thriveDebug.familyId,
      key: 'notes/n1',
      op: PendingOp.save,
      at: DateTime.now().millisecondsSinceEpoch,
      record: {'id': 'n1', 'name': 'Pharmacy'},
    );
    thriveDebug.stagedChanges.addStaged(change);
    thriveDebug.promptUnsavedChanges();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unsaved-changes-dialog')), findsOne);
    expect(find.text('1 change wasn’t saved'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('unsaved-review')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('staged-${change.id}')), findsOneWidget);

    // Only once per session.
    thriveDebug.promptUnsavedChanges();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unsaved-changes-dialog')), findsNothing);
  });

  testWidgets('the More row shows how many changes are unsaved', (
    tester,
  ) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    await openMoreHub(tester);
    await openHubCard(tester, 'account', 'hub-pending');
    final pill = find.byKey(const ValueKey('hub-pending-pill'));
    await tester.scrollUntilVisible(
      pill,
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: pill, matching: find.text('All saved')),
      findsOneWidget,
    );
    thriveDebug.stagedChanges.addStaged(
      PendingChange(
        familyId: thriveDebug.familyId,
        key: 'notes/n1',
        op: PendingOp.save,
        at: DateTime.now().millisecondsSinceEpoch,
        record: {'id': 'n1', 'name': 'Pharmacy'},
      ),
    );
    thriveDebug.pendingChangesChanged();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: pill, matching: find.text('1 unsaved')),
      findsOneWidget,
    );
  });

  testWidgets('a long set-aside list is filtered by verb, grouped by type, '
      'and discarded all at once', (tester) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    final fid = thriveDebug.familyId;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 6; i++) {
      thriveDebug.stagedChanges.addStaged(
        PendingChange(
          familyId: fid,
          key: 'notes/n$i',
          op: PendingOp.save,
          at: now - i,
          record: {'id': 'n$i', 'name': 'Note $i'},
        ),
      );
    }
    for (var i = 0; i < 4; i++) {
      final ev = CalendarEvent(
        id: 'e$i',
        title: 'Event $i',
        date: todayIso(),
        color: const Color(0xff1684B4),
      );
      thriveDebug.stagedChanges.addStaged(
        PendingChange(
          familyId: fid,
          key: eventRecordKey(ev),
          op: PendingOp.delete,
          at: now - 10 - i,
          serverRecord: {'id': 'e$i', 'title': 'Event $i'},
        ),
      );
    }
    thriveDebug.pendingChangesChanged();
    await tester.pumpAndSettle();
    await openPending(tester);

    expect(find.text('NOTES'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('staged-filter-Deleted')));
    await tester.pumpAndSettle();
    expect(find.text('NOTES'), findsNothing);
    expect(find.text('EVENTS'), findsOneWidget);
    expect(find.text('Event 0'), findsOneWidget);
    expect(find.text('Note 0'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('staged-discard-all')));
    await tester.pumpAndSettle();
    expect(find.text('Discard 10 set-aside changes?'), findsOneWidget);
    expect(find.text('6 notes'), findsOneWidget);
    expect(find.text('4 events'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('discard-confirm')));
    await tester.pumpAndSettle();
    expect(thriveDebug.stagedChanges.isEmpty, isTrue);
    expect(thriveDebug.toast, '10 changes discarded');
    expect(find.byKey(const ValueKey('pending-empty')), findsOneWidget);
  });
}
