part of 'package:family_money_management_app/main.dart';

/// Minimal surface `thrive_home.dart` schedules/cancels calendar event
/// reminders through, so tests can substitute a fake instead of hitting the
/// real `flutter_local_notifications` platform channel (#154).
abstract class NotificationScheduler {
  Future<void> scheduleEventReminder(CalendarEvent event);
  Future<void> cancelEventReminder(String eventId);
  Future<void> syncEventReminders(Iterable<CalendarEvent> events);
}

/// Local notifications for calendar event reminders. Wraps every plugin call
/// in try/catch: a missing platform channel (tests, unsupported platform) or
/// denied permission never blocks saving user data.
class NotificationService implements NotificationScheduler {
  NotificationService._();

  /// Swappable in tests: `NotificationService.instance = _FakeScheduler();`.
  static NotificationScheduler instance = NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool? _notificationsGranted;
  static Future<bool>? _notificationPermissionRequest;

  static Future<void> init() async {
    if (_initialized) {
      await refreshTimeZone();
      return;
    }
    try {
      tz.initializeTimeZones();
      await refreshTimeZone();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onTap,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('[notifications] init failed: $e');
    }
  }

  /// Refreshes the timezone from the OS so reminders follow both daylight
  /// saving transitions and timezone changes made while the app was closed.
  static Future<void> refreshTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('[notifications] timezone detection failed: $e');
    }
  }

  static void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    pendingNotificationDeepLink.value = payload;
  }

  /// Stable notification id derived from a string key.
  int _notificationId(String key) => key.hashCode & 0x7fffffff;

  int _eventNotificationId(String eventId, String date) =>
      _notificationId('event:$eventId:$date');

  @override
  Future<void> scheduleEventReminder(CalendarEvent event) async {
    if (!_initialized) return;
    await cancelEventReminder(event.id);
    await _scheduleEventOccurrences(event);
  }

  Future<void> _scheduleEventOccurrences(CalendarEvent event) async {
    if (event.reminder == 'none') return;

    try {
      final granted = await _requestPermission();
      if (!granted) return;
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = 0;
      final occurrenceDates = event.recur == 'none'
          ? [event.date]
          : recurringEventDates(
              event,
              event.date,
              event.endDate.isNotEmpty
                  ? event.endDate
                  : _addMonthsIso(event.date, 24),
              maxOccurrences: 5000,
            );

      // Keep a small rolling set for recurring events. App boot/resume rebuilds
      // the set, avoiding unbounded pending notifications on iOS and Android.
      for (final occurrenceDate in occurrenceDates) {
        if (scheduled >= 8) break;
        if (!event.exceptions.contains(occurrenceDate)) {
          final when = _eventReminderTime(event, occurrenceDate);
          if (when != null && when.isAfter(now)) {
            await _plugin.zonedSchedule(
              _eventNotificationId(event.id, occurrenceDate),
              event.title,
              _eventNotificationBody(event),
              when,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'event_reminders',
                  'Event reminders',
                  importance: Importance.high,
                  priority: Priority.high,
                ),
                iOS: DarwinNotificationDetails(),
              ),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              payload: 'event:${event.id}:$occurrenceDate',
            );
            scheduled++;
          }
        }
      }
    } catch (e) {
      debugPrint('[notifications] event schedule failed: $e');
    }
  }

  /// Builds a human-readable notification body describing when the event
  /// starts and, optionally, where. Examples:
  /// "Starts in 1 hour · 14:30" / "Starting at 09:00 – Conference room A" /
  /// "Starts tomorrow · 10:00 – Office".
  String _eventNotificationBody(CalendarEvent event) {
    final startStr = (!event.allDay && event.start.isNotEmpty)
        ? event.start
        : null;
    final reminder = event.reminder;

    String timeText;
    if (reminder == 'at') {
      if (event.allDay) {
        timeText = 'All day today';
      } else if (startStr != null) {
        timeText = 'Starting at $startStr';
      } else {
        timeText = 'Starting now';
      }
    } else if (reminder == '1h') {
      timeText = startStr != null
          ? 'Starts in 1 hour · $startStr'
          : 'Starts in 1 hour';
    } else if (reminder == '1d') {
      timeText = startStr != null
          ? 'Starts tomorrow · $startStr'
          : 'Starts tomorrow';
    } else {
      // Custom format: Xm, Xh, Xd — strip the unit suffix then parse the
      // numeric prefix. An empty or non-numeric prefix falls to the fallback.
      if (reminder.length <= 1) {
        timeText = startStr != null ? 'Starts at $startStr' : 'Calendar event';
      } else {
        final suffix = reminder[reminder.length - 1];
        final amount = int.tryParse(reminder.substring(0, reminder.length - 1));
        if (amount != null && suffix == 'm') {
          final label = amount == 1
              ? 'Starts in 1 minute'
              : 'Starts in $amount minutes';
          timeText = startStr != null ? '$label · $startStr' : label;
        } else if (amount != null && suffix == 'h') {
          final label = amount == 1
              ? 'Starts in 1 hour'
              : 'Starts in $amount hours';
          timeText = startStr != null ? '$label · $startStr' : label;
        } else if (amount != null && suffix == 'd') {
          final label = amount == 1
              ? 'Starts tomorrow'
              : 'Starts in $amount days';
          timeText = startStr != null ? '$label · $startStr' : label;
        } else {
          timeText = startStr != null
              ? 'Starts at $startStr'
              : 'Calendar event';
        }
      }
    }

    if (event.location.isNotEmpty) {
      return '$timeText – ${event.location}';
    }
    return timeText;
  }

  tz.TZDateTime? _eventReminderTime(CalendarEvent event, String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return null;
    var hour = 9;
    var minute = 0;
    if (!event.allDay && event.start.isNotEmpty) {
      final parts = event.start.split(':');
      if (parts.length == 2) {
        hour = int.tryParse(parts[0]) ?? hour;
        minute = int.tryParse(parts[1]) ?? minute;
      }
    }
    var when = tz.TZDateTime.local(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    final reminder = event.reminder;
    if (reminder != 'at') {
      final amount = int.tryParse(
        reminder.substring(0, reminder.length > 1 ? reminder.length - 1 : 0),
      );
      if (amount != null && reminder.endsWith('m')) {
        when = when.subtract(Duration(minutes: amount));
      } else if (amount != null && reminder.endsWith('h')) {
        when = when.subtract(Duration(hours: amount));
      } else if (amount != null && reminder.endsWith('d')) {
        when = when.subtract(Duration(days: amount));
      }
    }
    return when;
  }

  @override
  Future<void> cancelEventReminder(String eventId) async {
    if (!_initialized) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final notification in pending) {
        if (notification.payload?.startsWith('event:$eventId:') == true) {
          await _plugin.cancel(notification.id);
        }
      }
    } catch (e) {
      debugPrint('[notifications] event cancel failed: $e');
    }
  }

  @override
  Future<void> syncEventReminders(Iterable<CalendarEvent> events) async {
    if (!_initialized) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final notification in pending) {
        if (notification.payload?.startsWith('event:') == true) {
          await _plugin.cancel(notification.id);
        }
      }
      for (final event in events) {
        await _scheduleEventOccurrences(event);
      }
    } catch (e) {
      debugPrint('[notifications] event sync failed: $e');
    }
  }

  Future<bool> _requestPermission() async {
    final cached = _notificationsGranted;
    if (cached != null) return cached;
    final pending = _notificationPermissionRequest;
    if (pending != null) return pending;

    final request = _requestPermissionFromPlatform();
    _notificationPermissionRequest = request;
    final granted = await request;
    _notificationsGranted = granted;
    _notificationPermissionRequest = null;
    return granted;
  }

  Future<bool> _requestPermissionFromPlatform() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('[notifications] permission request failed: $e');
      return false;
    }
  }
}

/// Set by [NotificationService._onTap] when a notification is tapped;
/// consumed once by the app shell to deep-link into the relevant screen —
/// handles both a foreground tap and a cold-start launch from a notification.
final ValueNotifier<String?> pendingNotificationDeepLink =
    ValueNotifier<String?>(null);
