part of 'package:family_money_management_app/main.dart';

/// Calendar editor hook for the first notification permission prompt.
/// Cloud Functions schedules and sends event reminders.
abstract class NotificationScheduler {
  Future<void> scheduleEventReminder(CalendarEvent event);
  Future<void> cancelEventReminder(String eventId);
  Future<void> syncEventReminders(Iterable<CalendarEvent> events);
}

/// Displays FCM pushes while Thrive is open and handles notification taps.
/// It also clears reminders left by older app builds on upgrade.
class NotificationService implements NotificationScheduler {
  NotificationService._();

  /// Swappable in tests: `NotificationService.instance = _FakeScheduler();`.
  static NotificationScheduler instance = NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool? _notificationsGranted;
  static Future<bool>? _notificationPermissionRequest;

  static Future<void>? _initFuture;

  /// Idempotent: concurrent/repeat callers share one underlying init. Boot
  /// The startup path awaits this after the first frame.
  static Future<void> init() => _initFuture ??= _init();

  static Future<void> _init() async {
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
        settings: const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onTap,
        onDidReceiveBackgroundNotificationResponse:
            notificationActionInBackground,
      );
      _initialized = true;
      await _createChannels();
      // Clear notifications scheduled by older app builds before enabling
      // cloud reminders, avoiding a local/cloud duplicate on upgrade.
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.payload?.startsWith('event:') == true) {
          await _plugin.cancel(id: request.id);
        }
      }
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
      _setFallbackLocationFromOffset();
    }
  }

  /// Last-resort zone when [FlutterTimezone] fails: any database location
  /// whose current offset matches the OS clock. Leaving tz.local at the
  /// package default (UTC) would shift every reminder by the UTC offset.
  static void _setFallbackLocationFromOffset() {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (location.timeZone(now.millisecondsSinceEpoch).offset == offset) {
          tz.setLocalLocation(location);
          return;
        }
      }
    } catch (e) {
      debugPrint('[notifications] timezone fallback failed: $e');
    }
  }

  static void _onTap(NotificationResponse response) {
    if (response.notificationResponseType ==
            NotificationResponseType.selectedNotificationAction &&
        response.actionId != null &&
        response.actionId != kNotifOpenAction) {
      unawaited(runNotificationAction(response.actionId!, response.payload));
      return;
    }
    final payload = response.payload;
    if (payload == null) return;
    pendingNotificationDeepLink.value = linkOfPayload(payload);
  }

  /// Creates every Android channel up front (#471) so each one shows in
  /// Android settings and its on/off state can be read before the first
  /// notification arrives.
  static Future<void> _createChannels() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return;
      for (final c in kNotifChannels) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(c.id, c.name, importance: c.importance),
        );
      }
    } catch (e) {
      debugPrint('[notifications] channel setup failed: $e');
    }
  }

  // ------------------------------------------------------ device state (#483)

  static const MethodChannel _native = MethodChannel(
    'cat.eespunes.thrive/notifications',
  );

  /// How many times Thrive has shown the system permission prompt on this
  /// phone. Tells "never asked" (2a) from "blocked" (2d) — Android reports
  /// both as "disabled, no rationale".
  static const String kAskCountKey = 'notif_permission_asks';

  /// Pure mapping of the platform signals to the page's permission state.
  static NotifPermission classifyPermission({
    required bool enabled,
    required bool rationale,
    required int askCount,
    int sdk = 33,
  }) {
    if (enabled) return NotifPermission.granted;
    // Before Android 13 there's no runtime prompt: off means switched off in
    // Android settings.
    if (sdk < 33) return NotifPermission.blocked;
    if (rationale) return NotifPermission.denied;
    return askCount == 0 ? NotifPermission.undecided : NotifPermission.blocked;
  }

  static Future<int> _askCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(kAskCountKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _noteAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kAskCountKey, (prefs.getInt(kAskCountKey) ?? 0) + 1);
    } catch (_) {}
  }

  /// Reads the permission and every channel's on/off state.
  /// Called on every resume and whenever the page opens (§2). Platforms
  /// without the native channel (web, tests, iOS) report "granted".
  static Future<NotifDeviceState> readDeviceState() async {
    final asks = await _askCount();
    try {
      final raw = await _native.invokeMapMethod<String, Object?>('state', {
        'channels': [for (final c in kNotifChannels) c.id],
      });
      if (raw == null) return NotifDeviceState.granted();
      final channels = <String, bool>{};
      final rawChannels = raw['channels'];
      if (rawChannels is Map) {
        for (final e in rawChannels.entries) {
          channels[e.key.toString()] = e.value != false;
        }
      }
      final state = NotifDeviceState(
        permission: classifyPermission(
          enabled: raw['enabled'] == true,
          rationale: raw['rationale'] == true,
          askCount: asks,
          sdk: (raw['sdk'] as num?)?.toInt() ?? 33,
        ),
        channels: channels,
      );
      _notificationsGranted = state.permission == NotifPermission.granted;
      return state;
    } on MissingPluginException {
      return NotifDeviceState.granted();
    } catch (e) {
      debugPrint('[notifications] state read failed: $e');
      return NotifDeviceState.granted();
    }
  }

  /// Shows the Android 13 system prompt (2b). Only ever called from "Turn on
  /// notifications" / "Ask again" and the first reminder set on an event —
  /// never at app start.
  static Future<bool> askPermission() async {
    await _noteAsked();
    final granted = await _requestPermissionFromPlatform();
    _notificationsGranted = granted;
    return granted;
  }

  /// Opens a native settings screen: `app` (ACTION_APP_NOTIFICATION_SETTINGS),
  /// `channel` (ACTION_CHANNEL_NOTIFICATION_SETTINGS for [channel]) or
  /// The native notification settings page.
  static Future<void> openSystemSettings(String what, {String? channel}) async {
    try {
      await _native.invokeMethod<void>('open', {
        'what': what,
        'channel': ?channel,
      });
    } catch (e) {
      debugPrint('[notifications] open settings failed: $e');
    }
  }

  /// Displays a push that arrived while Thrive was open (or a data message
  /// with actions in the background), on its own channel with the server's
  /// tag so a later update replaces it (#471, §5).
  static Future<void> showRemote(RemoteNotif n) async {
    if (!_initialized) return;
    final spec = kNotifChannels.firstWhere(
      (c) => c.id == n.channel,
      orElse: () => kNotifChannels.first,
    );
    try {
      await _plugin.show(
        id: (n.tag.isEmpty ? n.title : n.tag).hashCode & 0x7fffffff,
        title: n.title,
        body: n.body,
        payload: n.encodedPayload(),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            spec.id,
            spec.name,
            importance: spec.importance,
            priority: spec.importance == Importance.high
                ? Priority.high
                : Priority.defaultPriority,
            tag: n.tag.isEmpty ? null : n.tag,
            groupKey: n.group,
            silent: spec.importance == Importance.low,
            actions: [
              for (final a in n.actions)
                AndroidNotificationAction(
                  a.id,
                  a.title,
                  showsUserInterface: a.id == kNotifOpenAction,
                  cancelNotification: true,
                ),
            ],
          ),
          iOS: DarwinNotificationDetails(threadIdentifier: n.group),
        ),
      );
    } catch (e) {
      debugPrint('[notifications] remote show failed: $e');
    }
  }

  // Event reminders are sent by Cloud Functions. These methods remain as the
  // calendar editor's notification-permission boundary; they never schedule
  // a notification on the phone.
  static ReminderPlan plan = const ReminderPlan();

  @override
  Future<void> scheduleEventReminder(CalendarEvent event) async {
    if (event.reminder != 'none' && plan.reminders) await _requestPermission();
  }

  @override
  Future<void> cancelEventReminder(String eventId) async {}

  @override
  Future<void> syncEventReminders(Iterable<CalendarEvent> events) async {}

  Future<bool> _requestPermission() async {
    final cached = _notificationsGranted;
    if (cached != null) return cached;
    final pending = _notificationPermissionRequest;
    if (pending != null) return pending;

    final request = _askOnce();
    _notificationPermissionRequest = request;
    final granted = await request;
    _notificationsGranted = granted;
    _notificationPermissionRequest = null;
    return granted;
  }

  /// The system prompt appears at most once from an event reminder: after
  /// that, "Ask again" on the page is the only way to show it.
  Future<bool> _askOnce() async {
    if (await _askCount() > 0) return false;
    return askPermission();
  }

  static Future<bool> _requestPermissionFromPlatform() async {
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
