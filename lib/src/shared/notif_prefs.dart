part of 'package:family_money_management_app/main.dart';

/// One "Tell me when" checkbox of a notification type (#473).
class NotifEventSpec {
  const NotifEventSpec(this.key, this.label, [this.hint = '']);
  final String key;
  final String label;
  final String hint;
}

/// One "Whose updates" radio option of a notification type (#473). The hint
/// line (e.g. "Liv and Leo") depends on the family, so it's computed by the
/// page, not stored here.
class NotifScopeSpec {
  const NotifScopeSpec(this.id, this.label);
  final String id;
  final String label;
}

/// A family-update notification type as designed in
/// `Settings Notifications.dc.html` §1/§3.
class NotifTypeSpec {
  const NotifTypeSpec({
    required this.id,
    required this.channel,
    required this.label,
    required this.sub,
    required this.whoTitle,
    required this.scopes,
    required this.events,
  });
  final String id;

  /// The Android notification channel the server posts this type on.
  final String channel;
  final String label;
  final String sub;
  final String whoTitle;
  final List<NotifScopeSpec> scopes;
  final List<NotifEventSpec> events;
}

/// The six family-update types, in page order.
const List<NotifTypeSpec> kNotifTypes = [
  NotifTypeSpec(
    id: 'chores',
    channel: 'family_chores',
    label: 'Chores & rewards',
    sub: 'Chores done, rewards claimed',
    whoTitle: 'WHOSE CHORES',
    scopes: [
      NotifScopeSpec('all', 'Everyone’s chores'),
      NotifScopeSpec('kids', 'Only my kids’ chores'),
      NotifScopeSpec('me', 'Only my own chores'),
      NotifScopeSpec('pick', 'Choose people'),
    ],
    events: [
      NotifEventSpec('done', 'Chore done', 'Grouped per child'),
      NotifEventSpec('reward', 'Reward claimed'),
      NotifEventSpec('stars', 'Stars earned', 'Off: shown in the chore update'),
    ],
  ),
  NotifTypeSpec(
    id: 'lists',
    channel: 'family_lists',
    label: 'Lists & shopping',
    sub: 'Items added or ticked off, a list finished',
    whoTitle: 'WHICH LISTS',
    scopes: [
      NotifScopeSpec('all', 'All family lists'),
      NotifScopeSpec('shop', 'Only the shopping list'),
      NotifScopeSpec('mine', 'Lists I’m part of'),
    ],
    events: [
      NotifEventSpec('added', 'Items added', 'Bundled for 10 min'),
      NotifEventSpec('ticked', 'Item ticked off'),
      NotifEventSpec('finished', 'List finished', '“Shopping is done”'),
    ],
  ),
  NotifTypeSpec(
    id: 'cal',
    channel: 'family_calendar',
    label: 'Calendar changes',
    sub: 'Events added, moved or cancelled by others',
    whoTitle: 'WHOSE EVENTS',
    scopes: [
      NotifScopeSpec('all', 'Everyone’s events'),
      NotifScopeSpec('mine', 'Events with me or my kids'),
      NotifScopeSpec('me', 'Only events I’m in'),
      NotifScopeSpec('pick', 'Choose people'),
    ],
    events: [
      NotifEventSpec('start', 'Event starts', 'At start time · works offline'),
      NotifEventSpec('added', 'New event'),
      NotifEventSpec('changed', 'Time or place changed', 'Shows old → new'),
      NotifEventSpec('cancelled', 'Cancelled', 'Always alerts'),
    ],
  ),
  NotifTypeSpec(
    id: 'money',
    channel: 'family_money',
    label: 'Money',
    sub: 'Expenses and income added or edited, paid out, received',
    whoTitle: 'WHICH ACCOUNTS',
    scopes: [
      NotifScopeSpec('all', 'All family accounts'),
      NotifScopeSpec('shared', 'Shared accounts only'),
      NotifScopeSpec('kids', 'My kids’ accounts'),
      NotifScopeSpec('pick', 'Choose people'),
    ],
    events: [
      NotifEventSpec('added', 'Added by someone else', 'Expense or income'),
      NotifEventSpec('edited', 'Edited or deleted', 'Shows old → new'),
      NotifEventSpec('paid', 'Paid out', 'On the due date'),
      NotifEventSpec('received', 'Received', 'On the expected date'),
    ],
  ),
  NotifTypeSpec(
    id: 'wall',
    channel: 'family_wall',
    label: 'Echo wall activity',
    sub: 'Chores ticked and stars given on the kitchen Echo',
    whoTitle: 'WHOSE ACTIVITY',
    scopes: [
      NotifScopeSpec('all', 'Everyone on the wall'),
      NotifScopeSpec('kids', 'Only my kids'),
      NotifScopeSpec('pick', 'Choose people'),
    ],
    events: [
      NotifEventSpec('ticked', 'Chore ticked on the wall', 'Silent'),
      NotifEventSpec('stars', 'Stars given on the wall', 'Silent'),
    ],
  ),
  NotifTypeSpec(
    id: 'family',
    channel: 'family_members',
    label: 'Family',
    sub: 'Someone joins or leaves, or their role changes',
    whoTitle: 'WHO',
    scopes: [NotifScopeSpec('all', 'Whole family')],
    events: [
      NotifEventSpec('joined', 'Someone joined'),
      NotifEventSpec('left', 'Someone left or was removed'),
      NotifEventSpec('role', 'Role changed', 'Parent ↔ kid'),
    ],
  ),
];

NotifTypeSpec notifTypeSpec(String id) =>
    kNotifTypes.firstWhere((t) => t.id == id);

/// Quiet-hours "From" choices (§1): 20:00–23:00 in 30-minute steps.
const List<String> kQuietFromTimes = [
  '20:00',
  '20:30',
  '21:00',
  '21:30',
  '22:00',
  '22:30',
  '23:00',
];

/// Quiet-hours "Until" choices (§1): 06:00–08:00 in 30-minute steps.
const List<String> kQuietUntilTimes = [
  '06:00',
  '06:30',
  '07:00',
  '07:30',
  '08:00',
];

/// A type's settings: master switch, whose updates, and which events.
class NotifTypePrefs {
  NotifTypePrefs({
    required this.on,
    required this.scope,
    List<String>? pick,
    required Map<String, bool> events,
  }) : pick = pick ?? <String>[],
       events = Map<String, bool>.of(events);

  bool on;
  String scope;
  List<String> pick;
  Map<String, bool> events;

  int get eventsOn => events.values.where((v) => v).length;

  NotifTypePrefs copy() =>
      NotifTypePrefs(on: on, scope: scope, pick: [...pick], events: events);

  Map<String, dynamic> toJson() => {
    'on': on,
    'scope': scope,
    'pick': pick,
    'events': events,
  };
}

/// Quiet hours (#484): family updates wait and arrive as one summary at
/// [to]. [days] are Mon..Sun and mark the evening a window starts on.
class NotifQuietPrefs {
  NotifQuietPrefs({
    this.on = true,
    this.from = '21:30',
    this.to = '07:00',
    List<bool>? days,
    this.letReminders = true,
  }) : days = days ?? List<bool>.filled(7, true);

  bool on;
  String from;
  String to;
  List<bool> days;
  bool letReminders;

  NotifQuietPrefs copy() => NotifQuietPrefs(
    on: on,
    from: from,
    to: to,
    days: [...days],
    letReminders: letReminders,
  );

  Map<String, dynamic> toJson() => {
    'on': on,
    'from': from,
    'to': to,
    'days': days,
    'letReminders': letReminders,
  };

  static int? _minutes(String hhmm) {
    final p = hhmm.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  /// Whether [t] (local wall time) falls inside a quiet window. A window
  /// runs from [from] on a ticked day until [to] the next morning (or the
  /// same day when [from] is earlier than [to]).
  bool covers(DateTime t) {
    if (!on) return false;
    final f = _minutes(from);
    final u = _minutes(to);
    if (f == null || u == null || f == u) return false;
    final now = t.hour * 60 + t.minute;
    final day = t.weekday - 1;
    if (f < u) return days[day] && now >= f && now < u;
    if (now >= f) return days[day];
    if (now < u) return days[(day + 6) % 7];
    return false;
  }

  /// "21:30–07:00 · every day" / "… · weekdays" / "… · N days", or
  /// "Off · updates arrive any time".
  String get summary {
    if (!on) return 'Off · updates arrive any time';
    final n = days.where((d) => d).length;
    final which = n == 7
        ? 'every day'
        : n == 5 && !days[5] && !days[6]
        ? 'weekdays'
        : '$n days';
    return '$from–$to · $which';
  }
}

/// The signed-in user's notification choices (#473). Stored on the user doc
/// (`users/{uid}.notifPrefs`, owner-only) so they follow the account across
/// phones; the server reads the same shape to decide who gets each push.
class NotifPrefs {
  NotifPrefs({required this.types, required this.quiet});

  final Map<String, NotifTypePrefs> types;
  final NotifQuietPrefs quiet;

  NotifTypePrefs type(String id) => types[id]!;

  /// Design defaults (§3). Kid accounts follow their own chores and events
  /// and only their own money.
  factory NotifPrefs.defaults({
    bool kid = false,
    String selfId = '',
    List<String> kidIds = const [],
  }) => NotifPrefs(
    types: {
      'chores': NotifTypePrefs(
        on: true,
        scope: kid ? 'me' : 'kids',
        pick: kid ? [selfId] : [...kidIds],
        events: {'done': true, 'reward': true, 'stars': false},
      ),
      'lists': NotifTypePrefs(
        on: true,
        scope: 'shop',
        events: {'added': true, 'ticked': false, 'finished': true},
      ),
      'cal': NotifTypePrefs(
        on: true,
        scope: kid ? 'me' : 'mine',
        pick: kid ? [selfId] : [if (selfId.isNotEmpty) selfId, ...kidIds],
        events: {
          'start': true,
          'added': true,
          'changed': true,
          'cancelled': true,
        },
      ),
      'money': NotifTypePrefs(
        on: true,
        scope: kid ? 'pick' : 'shared',
        pick: kid ? [selfId] : [],
        events: {'added': true, 'edited': true, 'paid': true, 'received': true},
      ),
      'wall': NotifTypePrefs(
        on: false,
        scope: 'kids',
        pick: [...kidIds],
        events: {'ticked': true, 'stars': true},
      ),
      'family': NotifTypePrefs(
        on: true,
        scope: 'all',
        events: {'joined': true, 'left': true, 'role': true},
      ),
    },
    quiet: NotifQuietPrefs(),
  );

  /// Tolerant parse: anything missing or malformed falls back to [fallback]
  /// (the defaults for this user), field by field.
  static NotifPrefs fromJson(Object? raw, NotifPrefs fallback) {
    final out = fallback.copy();
    if (raw is! Map) return out;
    for (final spec in kNotifTypes) {
      final t = raw[spec.id];
      if (t is! Map) continue;
      final cur = out.types[spec.id]!;
      if (t['on'] is bool) cur.on = t['on'] as bool;
      final scope = t['scope'];
      if (scope is String && spec.scopes.any((s) => s.id == scope)) {
        cur.scope = scope;
      }
      if (t['pick'] is List) {
        cur.pick = [for (final p in t['pick'] as List) p.toString()];
      }
      final ev = t['events'];
      if (ev is Map) {
        for (final e in spec.events) {
          if (ev[e.key] is bool) cur.events[e.key] = ev[e.key] as bool;
        }
      }
      // Every event unticked would be a silent "on": keep the type usable.
      if (cur.eventsOn == 0) cur.on = false;
    }
    final q = raw['quiet'];
    if (q is Map) {
      final quiet = out.quiet;
      if (q['on'] is bool) quiet.on = q['on'] as bool;
      if (q['from'] is String && NotifQuietPrefs._minutes(q['from']) != null) {
        quiet.from = q['from'] as String;
      }
      if (q['to'] is String && NotifQuietPrefs._minutes(q['to']) != null) {
        quiet.to = q['to'] as String;
      }
      final days = q['days'];
      if (days is List && days.length == 7) {
        quiet.days = [for (final d in days) d == true];
      }
      if (q['letReminders'] is bool) {
        quiet.letReminders = q['letReminders'] as bool;
      }
    }
    return out;
  }

  NotifPrefs copy() => NotifPrefs(
    types: {for (final e in types.entries) e.key: e.value.copy()},
    quiet: quiet.copy(),
  );

  Map<String, dynamic> toJson() => {
    for (final e in types.entries) e.key: e.value.toJson(),
    'quiet': quiet.toJson(),
  };

  /// Whether event-start notifications (#485) should fire for [ev], given
  /// the Calendar scope. [selfIds] are the ids that mean "me"; [kidIds] the
  /// family's kid member ids.
  bool wantsEventStart(
    CalendarEvent ev, {
    required Set<String> selfIds,
    required Set<String> kidIds,
  }) {
    final cal = types['cal']!;
    if (!cal.on || cal.events['start'] != true) return false;
    final who = ev.attendees.toSet();
    return switch (cal.scope) {
      'mine' => who.any((a) => selfIds.contains(a) || kidIds.contains(a)),
      'me' => who.any(selfIds.contains),
      'pick' => who.any(cal.pick.contains),
      _ => true,
    };
  }
}
