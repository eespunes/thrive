part of 'package:family_money_management_app/main.dart';

/// Local time of day a task due-date reminder fires on the due date.
const int kTaskReminderHour = 9;

/// Minimal surface `list_actions.dart` schedules/cancels task reminders
/// through, so tests can substitute a fake instead of hitting the real
/// `flutter_local_notifications` platform channel (#154).
abstract class NotificationScheduler {
  Future<void> scheduleTaskReminder(ListTask task);
  Future<void> cancelTaskReminder(String taskId);
  Future<void> scheduleEventReminder(CalendarEvent event);
  Future<void> cancelEventReminder(String eventId);
  Future<void> syncEventReminders(Iterable<CalendarEvent> events);
}

/// Local notifications for task due dates and calendar event reminders.
/// Wraps every plugin call in try/catch: a missing platform channel (tests,
/// unsupported platform) or denied permission never blocks saving user data.
class NotificationService implements NotificationScheduler {
  NotificationService._();

  /// Swappable in tests: `NotificationService.instance = _FakeScheduler();`.
  static NotificationScheduler instance = NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

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

  /// Stable notification id derived from the task's string id.
  int _notificationId(String taskId) => taskId.hashCode & 0x7fffffff;

  int _eventNotificationId(String eventId, String date) =>
      _notificationId('event:$eventId:$date');

  @override
  Future<void> scheduleTaskReminder(ListTask task) async {
    if (!_initialized) return;
    final due = task.due;
    if (due == null || due.isEmpty) return;
    final date = DateTime.tryParse(due);
    if (date == null) return;
    try {
      final granted = await _requestPermission();
      if (!granted) return;
      final when = tz.TZDateTime.local(
        date.year,
        date.month,
        date.day,
        kTaskReminderHour,
      );
      if (when.isBefore(tz.TZDateTime.now(tz.local))) return;
      await _plugin.zonedSchedule(
        _notificationId(task.id),
        'Task due today',
        task.title,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Task reminders',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'task:${task.id}',
      );
    } catch (e) {
      debugPrint('[notifications] schedule failed: $e');
    }
  }

  @override
  Future<void> cancelTaskReminder(String taskId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_notificationId(taskId));
    } catch (e) {
      debugPrint('[notifications] cancel failed: $e');
    }
  }

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
      var occurrenceDate = event.date;
      var scheduled = 0;

      // Keep a small rolling set for recurring events. App boot/resume rebuilds
      // the set, avoiding unbounded pending notifications on iOS and Android.
      for (var guard = 0; guard < 5000 && scheduled < 8; guard++) {
        if (!event.exceptions.contains(occurrenceDate)) {
          final when = _eventReminderTime(event, occurrenceDate);
          if (when != null && when.isAfter(now)) {
            await _plugin.zonedSchedule(
              _eventNotificationId(event.id, occurrenceDate),
              event.title,
              event.location.isEmpty ? 'Calendar event' : event.location,
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
        if (event.recur == 'none') break;
        occurrenceDate = switch (event.recur) {
          'daily' => _addDaysIso(occurrenceDate, 1),
          'weekly' => _addDaysIso(occurrenceDate, 7),
          'monthly' => _addMonthsIso(occurrenceDate, 1),
          'yearly' => _addMonthsIso(occurrenceDate, 12),
          _ => occurrenceDate,
        };
        if (occurrenceDate == event.date && event.recur != 'none') break;
      }
    } catch (e) {
      debugPrint('[notifications] event schedule failed: $e');
    }
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
