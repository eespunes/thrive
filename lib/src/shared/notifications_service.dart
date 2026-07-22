part of 'package:family_money_management_app/main.dart';

/// Local time of day a task due-date reminder fires on the due date.
const int kTaskReminderHour = 9;

/// Minimal surface `list_actions.dart` schedules/cancels task reminders
/// through, so tests can substitute a fake instead of hitting the real
/// `flutter_local_notifications` platform channel (#154).
abstract class NotificationScheduler {
  Future<void> scheduleTaskReminder(ListTask task);
  Future<void> cancelTaskReminder(String taskId);
}

/// Local notifications for task due dates (#154, local-only scope — event
/// reminders follow once Calendar/#153 exists). Wraps every plugin call in
/// try/catch: a missing platform channel (tests, unsupported platform) or a
/// denied permission should never crash task creation, just silently skip
/// the reminder.
class NotificationService implements NotificationScheduler {
  NotificationService._();

  /// Swappable in tests: `NotificationService.instance = _FakeScheduler();`.
  static NotificationScheduler instance = NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
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

  static void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    pendingNotificationDeepLink.value = payload;
  }

  /// Stable notification id derived from the task's string id.
  int _notificationId(String taskId) => taskId.hashCode & 0x7fffffff;

  @override
  Future<void> scheduleTaskReminder(ListTask task) async {
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
    try {
      await _plugin.cancel(_notificationId(taskId));
    } catch (e) {
      debugPrint('[notifications] cancel failed: $e');
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
