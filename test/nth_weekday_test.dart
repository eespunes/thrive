import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// #262 — nth-weekday monthly repeats: data model round-trip and the
// occurrence expansion, including "last X" in short months.

CalendarEvent _ev({int nth = 1, int weekday = 1, String date = '2026-09-01'}) =>
    CalendarEvent(
      id: 'e1',
      title: 'First Monday',
      date: date,
      allDay: true,
      color: const Color(0xff1684B4),
      recur: 'monthly',
      monthlyMode: 'nthWeekday',
      monthlyNth: nth,
      monthlyWeekday: weekday,
      reminder: 'none',
    );

void main() {
  test('serialisation omits the fields at their defaults', () {
    final plain = CalendarEvent(
      id: 'p',
      title: 'Plain',
      date: '2026-09-01',
      color: const Color(0xff1684B4),
      recur: 'monthly',
    );
    final j = plain.toJson();
    expect(j.containsKey('monthlyMode'), isFalse);
    expect(j.containsKey('monthlyNth'), isFalse);
    expect(j.containsKey('monthlyWeekday'), isFalse);
    // Old payloads round-trip unchanged.
    final back = CalendarEvent.fromJson(j);
    expect(back.monthlyMode, 'date');
    expect(back.monthlyNth, 1);
  });

  test('round-trips nth-weekday fields and clamps garbage', () {
    final back = CalendarEvent.fromJson(_ev(nth: 5, weekday: 7).toJson());
    expect(back.monthlyMode, 'nthWeekday');
    expect(back.monthlyNth, 5);
    expect(back.monthlyWeekday, 7);
    final bad = CalendarEvent.fromJson({
      'id': 'b',
      'title': 'B',
      'date': '2026-01-01',
      'monthlyMode': 'wat',
      'monthlyNth': 99,
      'monthlyWeekday': 0,
    });
    expect(bad.monthlyMode, 'date');
    expect(bad.monthlyNth, 5);
    expect(bad.monthlyWeekday, 1);
  });

  test('nthWeekdayDateIso: first/second/last, incl. short months', () {
    // September 2026: first Monday is the 7th (the 1st is a Tuesday).
    expect(nthWeekdayDateIso(2026, 9, 1, 1), '2026-09-07');
    expect(nthWeekdayDateIso(2026, 9, 2, 1), '2026-09-14');
    // Last Monday of September 2026 is the 28th.
    expect(nthWeekdayDateIso(2026, 9, 5, 1), '2026-09-28');
    // February 2026 (28 days): last Saturday is the 28th, last Sunday the 22nd.
    expect(nthWeekdayDateIso(2026, 2, 5, 6), '2026-02-28');
    expect(nthWeekdayDateIso(2026, 2, 5, 7), '2026-02-22');
  });

  test('every first Monday lands on the correct day across months', () {
    final dates = recurringEventDates(_ev(), '2026-09-01', '2026-12-31');
    expect(dates, ['2026-09-07', '2026-10-05', '2026-11-02', '2026-12-07']);
  });

  test('last-Friday series survives short months and respects endDate', () {
    final ev = _ev(nth: 5, weekday: 5, date: '2026-01-01')
      ..endDate = '2026-04-30';
    final dates = recurringEventDates(ev, '2026-01-01', '2026-12-31');
    expect(dates, ['2026-01-30', '2026-02-27', '2026-03-27', '2026-04-24']);
  });

  test('first occurrence skips a pattern date before the event date', () {
    // Event saved on Sep 10 as "first Monday": Sep's first Monday (the 7th)
    // is already past, so the series starts in October.
    final dates = recurringEventDates(
      _ev(date: '2026-09-10'),
      '2026-09-01',
      '2026-11-30',
    );
    expect(dates, ['2026-10-05', '2026-11-02']);
  });

  test('exceptions remove single occurrences', () {
    final ev = _ev()..exceptions.add('2026-10-05');
    final dates = recurringEventDates(ev, '2026-09-01', '2026-11-30');
    expect(dates, ['2026-09-07', '2026-11-02']);
  });
}
