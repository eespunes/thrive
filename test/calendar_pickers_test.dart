import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// "Wed 22 Jul", matching the event editor's date read-backs.
String _pretty(DateTime d) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}

Finder _inKey(String key, String text) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

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

/// Brings one of the event editor's sections on screen, unfolding it when
/// it is an Options row.
Future<void> _openTray(WidgetTester tester, Key key) =>
    openEventCard(tester, key);

/// Scopes a text match to one editor section (the footer summary repeats
/// times and dates, so a bare find.text can match twice).
Finder _inCard(String card, String text) => find.descendant(
  of: find.byKey(ValueKey('event-card-$card')),
  matching: find.text(text),
);

void main() {
  testWidgets('event editor start/end time pickers set the time fields', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await _openEditor(tester);
    await _openTray(tester, const ValueKey('event-card-when'));

    // Start time — the custom dialog types-to-overwrite: entering digits
    // replaces the selected value, no deleting needed, and two hour digits
    // hop to the minute field.
    await tester.tap(find.byKey(const ValueKey('event-time-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('time-input-hour')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('time-input-hour')), '14');
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('time-input-minute')),
      '30',
    );
    await tester.tap(find.byKey(const ValueKey('time-input-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('time-input-hour')), findsNothing);
    expect(_inCard('when', '14:30'), findsOneWidget);
    // Start auto-set the end +1h (new event, end untouched).
    expect(_inCard('when', '15:30'), findsOneWidget);

    // End time — out-of-range input clamps, confirming marks the end as
    // manually set.
    await tester.tap(find.byKey(const ValueKey('event-time-end')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('time-input-hour')), '25');
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('time-input-minute')),
      '75',
    );
    await tester.tap(find.byKey(const ValueKey('time-input-ok')));
    await tester.pumpAndSettle();
    expect(_inCard('when', '23:59'), findsOneWidget);

    // Cancelling leaves the fields untouched.
    await tester.tap(find.byKey(const ValueKey('event-time-end')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('time-input-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('time-input-hour')), findsNothing);
    expect(_inCard('when', '23:59'), findsOneWidget);
  });

  testWidgets(
    'event editor date + multi-day end-date pickers update the fields',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await _openEditor(tester);
      await _openTray(tester, const ValueKey('event-card-when'));

      final today = DateTime.now();

      // A new event starts today; a plain confirm in the picker keeps it.
      await _tapKey(tester, 'event-date');
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.textContaining('${_pretty(today)} · '), findsOneWidget);

      // Multi-day reveals the last-day button; pick an end date.
      await _tapKey(tester, 'event-multi-day');
      expect(_inKey('event-end-date', _pretty(today)), findsOneWidget);
      await _tapKey(tester, 'event-end-date');
      final other = _otherDayThisMonth();
      await _pickDialogDay(tester, other.day);
      if (other.isAfter(today)) {
        expect(_inKey('event-end-date', _pretty(other)), findsOneWidget);

        // Moving the start date keeps the span, so the end moves with it.
        final span = other
            .difference(DateTime(today.year, today.month, today.day))
            .inDays;
        await _tapKey(tester, 'event-date');
        await _pickDialogDay(tester, other.day);
        expect(
          _inKey(
            'event-end-date',
            _pretty(DateTime(other.year, other.month, other.day + span)),
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('repeat end-date picker sets and clamps the stop date', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await _openEditor(tester);

    final today = DateTime.now();
    await _openTray(tester, const ValueKey('event-card-repeat'));
    await _tapKey(tester, 'ticket-cad-weekly');
    expect(find.text('Stops repeating'), findsOneWidget);
    expect(_inKey('event-repeat-end-date', 'Never'), findsOneWidget);

    await _tapKey(tester, 'event-repeat-end-date');
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // The stop date now shows today's date.
    expect(_inKey('event-repeat-end-date', _pretty(today)), findsOneWidget);

    final other = _otherDayThisMonth();
    if (other.isAfter(today)) {
      // Moving the start date past the repeat end clamps it.
      await _openTray(tester, const ValueKey('event-card-when'));
      await _tapKey(tester, 'event-date');
      await _pickDialogDay(tester, other.day);
      await _openTray(tester, const ValueKey('event-card-repeat'));
      expect(_inKey('event-repeat-end-date', _pretty(other)), findsOneWidget);
    }

    // "Never stop" clears it again.
    await _tapKey(tester, 'event-repeat-never');
    expect(_inKey('event-repeat-end-date', 'Never'), findsOneWidget);
  });
}
