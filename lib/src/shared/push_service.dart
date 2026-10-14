part of 'package:family_money_management_app/main.dart';

/// Android notification permission as the Notifications page shows it (§2).
enum NotifPermission {
  /// 1a: allowed.
  granted,

  /// 2a: never asked on this phone.
  undecided,

  /// 2c: "Don't allow" once; Android may ask one more time.
  denied,

  /// 2d: blocked; only Android settings can turn it back on.
  blocked,
}

/// Everything the page reads from the phone on open and on every resume.
class NotifDeviceState {
  const NotifDeviceState({required this.permission, this.channels = const {}});

  factory NotifDeviceState.granted() =>
      const NotifDeviceState(permission: NotifPermission.granted);

  final NotifPermission permission;

  /// Channel id → enabled. A channel missing from the map counts as on.
  final Map<String, bool> channels;

  bool get granted => permission == NotifPermission.granted;
  bool channelOn(String id) => channels[id] != false;
}

/// An Android notification channel (§5).
class NotifChannelSpec {
  const NotifChannelSpec(this.id, this.name, this.importance);
  final String id;
  final String name;
  final Importance importance;
}

const String kEventStartChannel = 'event_start';

/// Every channel Thrive posts on, created at startup (#471).
const List<NotifChannelSpec> kNotifChannels = [
  NotifChannelSpec(
    'family_chores',
    'Chores & rewards',
    Importance.defaultImportance,
  ),
  NotifChannelSpec(
    'family_lists',
    'Lists & shopping',
    Importance.defaultImportance,
  ),
  NotifChannelSpec(
    'family_calendar',
    'Calendar changes',
    Importance.defaultImportance,
  ),
  NotifChannelSpec('family_money', 'Money', Importance.defaultImportance),
  NotifChannelSpec('family_members', 'Family', Importance.defaultImportance),
  NotifChannelSpec('family_wall', 'Echo wall activity', Importance.low),
  NotifChannelSpec(
    'family_digest',
    'Quiet hours summary',
    Importance.defaultImportance,
  ),
  NotifChannelSpec(kEventStartChannel, 'Event starts', Importance.high),
  NotifChannelSpec('event_reminders', 'Event reminders', Importance.high),
];

/// The Echo wall type ships with the Alexa wall (#460); until then the page
/// hides it (#472).
const bool kEchoWallLive = false;

/// Compatibility interface for the reminder toggle and editor permission prompt.
class ReminderPlan {
  const ReminderPlan({
    this.reminders = true,
    this.startFor,
    this.memberNames,
    this.quiet,
    this.key = '',
  });

  /// The "Event reminders" switch: the reminders set on events.
  final bool reminders;

  /// Whether an event gets an event-start notification (Calendar scope +
  /// "Event starts" ticked).
  final bool Function(CalendarEvent)? startFor;

  /// "Liv" / "Liv and Leo" for the event-start title.
  final String Function(CalendarEvent)? memberNames;

  /// Quiet hours; null when off or when reminders are let through.
  final NotifQuietPrefs? quiet;

  /// Changes whenever the plan does, so a resync isn't skipped as a no-op.
  final String key;

  /// Legacy plan helper retained for the calendar editor interface.
  bool allowsAt(DateTime when) => !(quiet?.covers(when) ?? false);
}

/// The "Open" action id: opens the app like a tap.
const String kNotifOpenAction = 'open';

/// A notification action button.
class RemoteAction {
  const RemoteAction(this.id, this.title);
  final String id;
  final String title;
}

/// A push as the client displays it (foreground, or a data-only message
/// with actions in the background).
class RemoteNotif {
  const RemoteNotif({
    required this.title,
    required this.body,
    this.link = '',
    this.channel = 'family_members',
    this.tag = '',
    this.group,
    this.actions = const [],
    this.approve,
  });

  final String title;
  final String body;
  final String link;
  final String channel;
  final String tag;
  final String? group;
  final List<RemoteAction> actions;

  /// Arguments for the `approveReward` callable behind "Approve".
  final Map<String, dynamic>? approve;

  /// Parses FCM `data` (all strings), falling back to the `notification`
  /// block's title/body.
  static RemoteNotif? fromData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    final t = (data['title'] ?? title ?? '').toString();
    if (t.isEmpty) return null;
    final actions = <RemoteAction>[];
    try {
      final raw = data['actions'];
      final list = raw is String ? json.decode(raw) : raw;
      if (list is List) {
        for (final a in list) {
          if (a is Map && a['id'] != null) {
            actions.add(
              RemoteAction(a['id'].toString(), (a['title'] ?? '').toString()),
            );
          }
        }
      }
    } catch (_) {}
    Map<String, dynamic>? approve;
    try {
      final raw = data['approve'];
      final m = raw is String ? json.decode(raw) : raw;
      if (m is Map) approve = Map<String, dynamic>.from(m);
    } catch (_) {}
    final group = data['group']?.toString();
    return RemoteNotif(
      title: t,
      body: (data['body'] ?? body ?? '').toString(),
      link: (data['link'] ?? '').toString(),
      channel: (data['channel'] ?? 'family_members').toString(),
      tag: (data['tag'] ?? '').toString(),
      group: group == null || group.isEmpty ? null : group,
      actions: actions,
      approve: approve,
    );
  }

  /// The local notification payload: the bare link, or JSON when an action
  /// needs its arguments.
  String encodedPayload() =>
      approve == null ? link : json.encode({'link': link, 'approve': approve});
}

/// The deep link inside a notification payload (bare or JSON-wrapped).
String linkOfPayload(String payload) {
  if (!payload.startsWith('{')) return payload;
  try {
    final m = json.decode(payload);
    if (m is Map) return (m['link'] ?? '').toString();
  } catch (_) {}
  return '';
}

/// Swappable callable invoker so tests can capture "Approve" without
/// Firebase.
typedef NotifCallable =
    Future<void> Function(String name, Map<String, dynamic> args);

NotifCallable notifCallable = _firebaseCallable;

// Needs a live Firebase backend.
// coverage:ignore-start
Future<void> _firebaseCallable(String name, Map<String, dynamic> args) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  await FirebaseFunctions.instanceFor(
    region: kKidFunctionsRegion,
  ).httpsCallable(name).call<Object?>(args).timeout(kCloudOpTimeout);
}
// coverage:ignore-end

/// Runs a notification action without opening the app (#474). "Approve"
/// calls `approveReward` with the arguments the server put in the payload.
Future<void> runNotificationAction(String actionId, String? payload) async {
  if (actionId != 'approve' || payload == null) return;
  try {
    final m = json.decode(payload);
    if (m is! Map || m['approve'] is! Map) return;
    await notifCallable(
      'approveReward',
      Map<String, dynamic>.from(m['approve'] as Map),
    );
  } catch (e) {
    debugPrint('[notifications] action $actionId failed: $e');
  }
}

/// Action taps while the app isn't running land here, in a background
/// isolate.
// coverage:ignore-start
@pragma('vm:entry-point')
void notificationActionInBackground(NotificationResponse response) {
  final id = response.actionId;
  if (id == null || id == kNotifOpenAction) return;
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(runNotificationAction(id, response.payload));
}

/// FCM data-only messages (the ones with actions) arriving while Thrive is
/// in the background or closed: shown locally so the buttons work.
/// Messages with a `notification` block are shown by the system.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  if (message.notification != null) return;
  final n = RemoteNotif.fromData(message.data);
  if (n == null) return;
  await NotificationService.init();
  await NotificationService.showRemote(n);
}
// coverage:ignore-end

/// The device doc written at `families/{fid}/members/{uid}/devices/{token}`
/// (#471): what the server needs to target and filter this phone.
Map<String, dynamic> pushDeviceDoc({
  required String token,
  required String platform,
  required String timezone,
  required NotifDeviceState state,
  bool remindersEnabled = true,
}) => {
  'platform': platform,
  'token': token,
  'timezone': timezone,
  'enabled': state.granted,
  'remindersEnabled': remindersEnabled,
  'channelState': {
    for (final c in kNotifChannels)
      c.id: state.granted && state.channelOn(c.id),
  },
};

/// The FCM surface the app uses, swappable in tests. `null` (web, tests,
/// no Firebase) means push is unavailable.
abstract class PushMessaging {
  Future<String?> token();
  Stream<String> get onTokenRefresh;
  Future<void> deleteToken();
  Stream<RemoteNotif> get onForeground;
  Stream<String> get onOpened;
  Future<String?> initialLink();
}

class PushService {
  static PushMessaging? messaging;
}

// Needs the Firebase Messaging platform plugin.
// coverage:ignore-start
class FirebasePushMessaging implements PushMessaging {
  FirebaseMessaging get _m => FirebaseMessaging.instance;

  @override
  Future<String?> token() => _m.getToken();

  @override
  Stream<String> get onTokenRefresh => _m.onTokenRefresh;

  @override
  Future<void> deleteToken() => _m.deleteToken();

  @override
  Stream<RemoteNotif> get onForeground => FirebaseMessaging.onMessage
      .map(
        (m) => RemoteNotif.fromData(
          m.data,
          title: m.notification?.title,
          body: m.notification?.body,
        ),
      )
      .where((n) => n != null)
      .cast<RemoteNotif>();

  @override
  Stream<String> get onOpened => FirebaseMessaging.onMessageOpenedApp.map(
    (m) => (m.data['link'] ?? '').toString(),
  );

  @override
  Future<String?> initialLink() async {
    final m = await _m.getInitialMessage();
    return m?.data['link']?.toString();
  }
}
// coverage:ignore-end
