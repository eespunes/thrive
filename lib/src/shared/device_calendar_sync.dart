part of 'package:family_money_management_app/main.dart';

/// Mirrors Thrive's editable calendar into Android's system Calendar Provider
/// so widgets such as Samsung Calendar can display Thrive events.
class DeviceCalendarSync {
  DeviceCalendarSync._();

  static final DeviceCalendarSync instance = DeviceCalendarSync._();
  static const MethodChannel _channel = MethodChannel(
    'cat.eespunes.thrive/device_calendar',
  );
  static const Duration _debounceDelay = Duration(seconds: 2);

  bool _running = false;
  final ValueNotifier<bool> saving = ValueNotifier<bool>(false);
  Timer? _debounceTimer;
  String? _lastSyncedDigest;
  String? _runningDigest;
  String? _queuedDigest;
  List<Map<String, Object?>>? _queuedPayload;
  List<CalendarEvent>? _pendingEvents;

  void cancelPending() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingEvents = null;
    _queuedPayload = null;
    _queuedDigest = null;
    _updateSaving();
  }

  /// Cheap on the caller's hot path: only snapshots the events and
  /// starts/extends the debounce timer. The expensive payload build
  /// (recurrence expansion) and digest comparison happen once, inside the
  /// debounced [_flushQueued].
  void syncEvents(Iterable<CalendarEvent> source) {
    if (foundation.defaultTargetPlatform != foundation.TargetPlatform.android) {
      return;
    }
    _pendingEvents = List<CalendarEvent>.of(source, growable: false);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, _flushQueued);
    _updateSaving();
  }

  void _flushQueued() {
    _debounceTimer = null;
    final source = _pendingEvents;
    _pendingEvents = null;
    if (source != null) {
      final payload = _payloadFor(source).toList(growable: false);
      _queuedDigest = _digestFor(payload);
      _queuedPayload = payload;
    }
    final payload = _queuedPayload;
    final digest = _queuedDigest;
    _queuedPayload = null;
    _queuedDigest = null;
    if (payload == null || digest == null || digest == _lastSyncedDigest) {
      _updateSaving();
      return;
    }
    if (_running) {
      if (digest == _runningDigest) return;
      _queuedPayload = payload;
      _queuedDigest = digest;
      _updateSaving();
      return;
    }
    unawaited(_run(payload, digest));
    _updateSaving();
  }

  Future<void> _run(List<Map<String, Object?>> payload, String digest) async {
    _running = true;
    var next = payload;
    var nextDigest = digest;
    while (true) {
      _runningDigest = nextDigest;
      try {
        await _channel.invokeMethod<void>('syncThriveCalendar', {
          'events': next,
        });
        _lastSyncedDigest = nextDigest;
      } on MissingPluginException {
        break;
      } on PlatformException catch (e) {
        debugPrint('[device-calendar] sync failed: ${e.message ?? e.code}');
        break;
      }
      final queued = _queuedPayload;
      final queuedDigest = _queuedDigest;
      if (queued == null || queuedDigest == null) break;
      _queuedPayload = null;
      _queuedDigest = null;
      if (queuedDigest == _lastSyncedDigest) break;
      next = queued;
      nextDigest = queuedDigest;
    }
    _running = false;
    _runningDigest = null;
    if (_queuedPayload != null && _debounceTimer == null) {
      _flushQueued();
    }
    _updateSaving();
  }

  String _digestFor(List<Map<String, Object?>> payload) =>
      sha1.convert(utf8.encode(json.encode(payload))).toString();

  void _updateSaving() {
    final next =
        _running ||
        _debounceTimer != null ||
        _pendingEvents != null ||
        _queuedPayload != null;
    if (saving.value != next) saving.value = next;
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
