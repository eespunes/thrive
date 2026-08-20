part of 'package:family_money_management_app/main.dart';

/// Mirrors Thrive's editable calendar into Android's system Calendar Provider
/// so widgets such as Samsung Calendar can display Thrive events.
class DeviceCalendarSync {
  DeviceCalendarSync._();

  static final DeviceCalendarSync instance = DeviceCalendarSync._();
  static const MethodChannel _channel = MethodChannel(
    'cat.eespunes.thrive/device_calendar',
  );

  bool _running = false;
  List<Map<String, Object?>>? _queuedPayload;

  Future<void> syncEvents(Iterable<CalendarEvent> source) async {
    if (foundation.defaultTargetPlatform != foundation.TargetPlatform.android) {
      return;
    }
    final payload = _payloadFor(source).toList(growable: false);
    if (_running) {
      _queuedPayload = payload;
      return;
    }
    await _run(payload);
  }

  Future<void> _run(List<Map<String, Object?>> payload) async {
    _running = true;
    var next = payload;
    while (true) {
      try {
        await _channel.invokeMethod<void>('syncThriveCalendar', {
          'events': next,
        });
      } on MissingPluginException {
        break;
      } on PlatformException catch (e) {
        debugPrint('[device-calendar] sync failed: ${e.message ?? e.code}');
        break;
      }
      final queued = _queuedPayload;
      if (queued == null) break;
      _queuedPayload = null;
      next = queued;
    }
    _running = false;
  }

  Iterable<Map<String, Object?>> _payloadFor(
    Iterable<CalendarEvent> source,
  ) sync* {
    final today = todayIso();
    final rangeStart = _addDaysIso(today, -30);
    final rangeEnd = _addDaysIso(today, 395);

    for (final ev in source) {
      if (ev.kitchenOrigin) continue;
      if (ev.recur == 'none') {
        yield _eventPayload(
          ev,
          id: ev.id,
          date: ev.date,
          endDate: _nonRecurringSpanEnd(ev),
          done: ev.todo && ev.done,
        );
        continue;
      }

      for (final date in recurringEventDates(ev, rangeStart, rangeEnd)) {
        yield _eventPayload(
          ev,
          id: '${ev.id}@$date',
          date: date,
          endDate: date,
          done: ev.todo && ev.isDoneOn(date),
        );
      }
    }
  }

  Map<String, Object?> _eventPayload(
    CalendarEvent ev, {
    required String id,
    required String date,
    required String endDate,
    required bool done,
  }) {
    return {
      'id': id,
      'title': done ? 'Done: ${ev.title}' : ev.title,
      'allDay': ev.allDay,
      'date': date,
      'endDate': endDate,
      'start': ev.start,
      'end': ev.end,
      'location': ev.location,
      'notes': ev.notes,
    };
  }

  String _nonRecurringSpanEnd(CalendarEvent ev) =>
      ev.endDate.isNotEmpty && ev.endDate.compareTo(ev.date) > 0
      ? ev.endDate
      : ev.date;
}
