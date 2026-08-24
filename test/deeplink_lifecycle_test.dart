import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

void main() {
  tearDown(() => pendingNotificationDeepLink.value = null);

  testWidgets('task notification deep link opens the owning list', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);

    // Create a to-do list with one task.
    await tester.tap(find.byKey(const ValueKey('nav-lists')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Household');
    await tester.pump();
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Household'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Take out the bins');
    await tester.pump();
    await tester.tap(find.text('Add task').last);
    await tester.pumpAndSettle();

    final taskId = thriveDebug.taskLists.first.tasks.first.id;

    // Go elsewhere, then fire the notification deep link.
    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    pendingNotificationDeepLink.value = 'task:$taskId';
    await tester.pumpAndSettle();

    expect(pendingNotificationDeepLink.value, isNull);
    expect(thriveDebug.tab, 'lists');
    expect(find.text('Take out the bins'), findsOneWidget);
  });

  testWidgets('event notification deep link opens the event view', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);

    // Create an event via the calendar FAB editor.
    await tester.tap(find.byKey(const ValueKey('nav-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Team lunch');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    final ev = thriveDebug.events.single;

    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    pendingNotificationDeepLink.value = 'event:${ev.id}:${ev.date}';
    await tester.pumpAndSettle();

    expect(pendingNotificationDeepLink.value, isNull);
    expect(thriveDebug.tab, 'calendar');
    expect(find.text('Team lunch'), findsWidgets);
  });

  testWidgets('stale or malformed deep links are discarded', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);

    // Task id that no longer exists.
    pendingNotificationDeepLink.value = 'task:gone';
    await tester.pumpAndSettle();
    expect(pendingNotificationDeepLink.value, isNull);
    expect(thriveDebug.tab, 'home');

    // Event payload with an invalid date component.
    pendingNotificationDeepLink.value = 'event:whatever:not-a-date';
    await tester.pumpAndSettle();
    expect(pendingNotificationDeepLink.value, isNull);
    expect(thriveDebug.tab, 'home');
  });

  testWidgets('app lifecycle changes flush persists and refresh reminders', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);

    // Make an edit so a debounced persist is pending, then background the
    // app — the pause handler must flush it.
    await tester.tap(find.byKey(const ValueKey('nav-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Dentist');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // The persisted event survives a reboot (proves the flush happened).
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await rebootApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-calendar')));
    await tester.pumpAndSettle();
    expect(thriveDebug.events.where((e) => e.title == 'Dentist'), hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  });
}
