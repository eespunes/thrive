import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// dd-MM-yyyy, matching the event editor's date field display.
String _display(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.year.toString().padLeft(4, '0')}';

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-calendar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
  await tester.pumpAndSettle();
  expect(find.text('New event'), findsOneWidget);
}

/// A day later in today's month than today (falls back to an earlier day at
/// month end) — always tappable in the material date-picker's initial month.
DateTime _otherDayThisMonth() {
  final now = DateTime.now();
  return now.day < 28
      ? DateTime(now.year, now.month, now.day + 1)
      : DateTime(now.year, now.month, now.day - 1);
}

Future<void> _pickDialogDay(WidgetTester tester, int day) async {
  await tester.tap(
    find
        .descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('$day'),
        )
        .last,
  );
  await tester.pump();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _openTray(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key), warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('event editor start/end time pickers set the time fields', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await _openEditor(tester);
    await _openTray(tester, const ValueKey('ticket-when'));

    // Start time — confirming the picker keeps a valid HH:mm and (for a new
    // event) recomputes the default end time.
    await tester.tap(find.byKey(const ValueKey('event-time-start')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsNothing);

    // End time — confirming marks the end as manually set.
    await tester.tap(find.byKey(const ValueKey('event-time-end')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Cancelling leaves the fields untouched.
    await tester.tap(find.byKey(const ValueKey('event-time-end')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsNothing);
  });

  testWidgets(
    'event editor date + multi-day end-date pickers update the fields',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await _openEditor(tester);
      await _openTray(tester, const ValueKey('ticket-when'));

      final today = DateTime.now();

      // Plain confirm keeps today's date.
      await tester.tap(find.text(_display(today)).first);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(_display(today)), findsOneWidget);

      // Multi-day reveals the end-date field; pick an end date.
      await tester.tap(find.text('Multi-day'));
      await tester.pumpAndSettle();
      expect(find.text('ENDS'), findsOneWidget);
      await tester.tap(find.text(_display(today)).last);
      await tester.pumpAndSettle();
      final other = _otherDayThisMonth();
      await _pickDialogDay(tester, other.day);
      if (other.isAfter(today)) {
        expect(find.text(_display(other)), findsOneWidget);

        // Moving the start date past the end date clamps the end date.
        await tester.tap(find.text(_display(today)).first);
        await tester.pumpAndSettle();
        await _pickDialogDay(tester, other.day);
        expect(find.text(_display(other)), findsNWidgets(2));
      }
    },
  );

  testWidgets('repeat end-date picker sets and clamps REPEAT ENDS', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await _openEditor(tester);

    final today = DateTime.now();
    await _openTray(tester, const ValueKey('ticket-badge-repeat'));
    await tester.tap(find.byKey(const ValueKey('ticket-again-yes')));
    await tester.pumpAndSettle();
    expect(find.text('REPEAT ENDS'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('event-repeat-end-date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // The repeat-ends field now shows today's date.
    expect(find.text(_display(today)), findsOneWidget);

    final other = _otherDayThisMonth();
    if (other.isAfter(today)) {
      // Moving the start date (When tray) past the repeat end clamps it.
      await _openTray(tester, const ValueKey('ticket-when'));
      await tester.tap(find.text(_display(today)).first);
      await tester.pumpAndSettle();
      await _pickDialogDay(tester, other.day);
      await _openTray(tester, const ValueKey('ticket-badge-repeat'));
      expect(find.text(_display(other)), findsOneWidget);
    }
  });
}
