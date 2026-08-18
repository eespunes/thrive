part of 'package:family_money_management_app/main.dart';

/// Storage key for the v4 multi-family state blob (families + workspaces).
const String kStorageKeyV4 = 'thrive.v4';

/// Storage key for the signed-in user (mirrors the design's `thrive.user`).
const String kUserKey = 'thrive.user';

/// Member avatar palette, mirrored from the design's `MEMBER_COLORS`.
const List<Color> kMemberColors = [
  Color(0xff0E9A8D),
  Color(0xff1684B4),
  Color(0xff7c3aed),
  Color(0xffd97706),
  Color(0xffe11d48),
  Color(0xff54A96A),
];

/// Generates a fresh id outside any class scope (so the `uid()` generator is
/// reachable even where a `uid` field would otherwise shadow it).
String _genUid() => uid();

/// Mirrors the design's `slug(s)` — a URL/username-safe family handle.
String familySlug(String? s) {
  var out = (s ?? '')
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'(^-+|-+$)'), '');
  if (out.length > 24) out = out.substring(0, 24);
  return out;
}

/// Mirrors the design's `validUsername(u)` — 3–24 chars, starts alphanumeric.
bool validFamilyUsername(String? u) =>
    RegExp(r'^[a-z0-9][a-z0-9_-]{2,23}$').hasMatch(u ?? '');

/// Mirrors `initialsOf(name)` — up to two uppercase initials from a name.
String initialsOf(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final a = parts[0][0];
  final b = parts.length > 1 ? parts[1][0] : '';
  return (a + b).toUpperCase();
}

/// The signed-in user. Mirrors the design's `state.user` object.
class AppUser {
  AppUser({
    required this.name,
    required this.email,
    required this.initials,
    this.provider = 'email',
    this.photo,
    this.color,
  });

  String name;
  String email;
  String initials;
  String provider; // 'email' | 'google'
  String? photo; // data-uri / path; dummy only
  Color? color;

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'initials': initials,
    'provider': provider,
    if (photo != null) 'photo': photo,
    if (color != null) 'color': color!.toARGB32(),
  };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    name: (j['name'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    initials: (j['initials'] ?? initialsOf(j['name']?.toString())).toString(),
    provider: (j['provider'] ?? 'email').toString(),
    photo: j['photo']?.toString(),
    color: j['color'] != null ? Color((j['color'] as num).toInt()) : null,
  );
}

/// A single member of a family. Mirrors the design member objects.
class FamilyMember {
  FamilyMember({
    required this.id,
    required this.name,
    required this.email,
    required this.initials,
    required this.color,
    this.uid,
    this.photo,
    this.emoji,
    this.role = 'member', // 'owner' | 'member'
    this.status = 'active', // 'active' | 'invited'
  });

  String id;
  String name;
  String email;
  String initials;
  Color color;

  /// Firebase Auth uid of the signed-in user backing this member, when known.
  /// `null` for invited-but-not-yet-joined members.
  String? uid;

  /// Base64 uploaded avatar picture, if set.
  String? photo;

  /// Emoji avatar (e.g. for a login-less kid profile) — mutually exclusive
  /// with [photo]; shown instead of it, falling back to [initials] when
  /// neither is set.
  String? emoji;
  String role;
  String status;

  FamilyMember copy() => FamilyMember(
    id: id,
    name: name,
    email: email,
    initials: initials,
    color: color,
    uid: uid,
    photo: photo,
    emoji: emoji,
    role: role,
    status: status,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'initials': initials,
    'color': color.toARGB32(),
    if (uid != null) 'uid': uid,
    if (photo != null) 'photo': photo,
    if (emoji != null) 'emoji': emoji,
    'role': role,
    'status': status,
  };

  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
    id: (j['id'] ?? _genUid()).toString(),
    name: (j['name'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    initials: (j['initials'] ?? initialsOf(j['name']?.toString())).toString(),
    color: Color((j['color'] as num?)?.toInt() ?? 0xff0E9A8D),
    uid: j['uid']?.toString(),
    photo: j['photo']?.toString(),
    emoji: (j['emoji'] as String?)?.isNotEmpty == true ? j['emoji'] : null,
    role: (j['role'] ?? 'member').toString(),
    status: (j['status'] ?? 'active').toString(),
  );
}

/// A family workspace. Mirrors the design's `family` object.
class Family {
  Family({
    required this.id,
    required this.name,
    required this.members,
    this.username = '',
    this.picture,
    this.ownerUid,
    List<String>? memberUids,
  }) : memberUids = memberUids ?? <String>[];

  String id;
  String name;
  List<FamilyMember> members;

  /// Shared family handle relatives type to join (mirrors the design).
  String username;

  /// Optional base64 family avatar.
  String? picture;

  /// Firebase Auth uid of the owner (cloud mode). `null` in local/demo mode.
  String? ownerUid;

  /// Firebase Auth uids with access — the source of truth for sharing and the
  /// field Firestore security rules check for membership.
  List<String> memberUids;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    if (picture != null) 'picture': picture,
    if (ownerUid != null) 'ownerUid': ownerUid,
    'memberUids': memberUids,
    'members': members.map((m) => m.toJson()).toList(),
  };

  factory Family.fromJson(Map<String, dynamic> j) => Family(
    id: (j['id'] ?? 'fam_main').toString(),
    name: (j['name'] ?? 'Family').toString(),
    username: (j['username'] ?? '').toString(),
    picture: j['picture']?.toString(),
    ownerUid: j['ownerUid']?.toString(),
    memberUids: [
      for (final u in (j['memberUids'] as List? ?? [])) u.toString(),
    ],
    members: [
      for (final m in (j['members'] as List? ?? []))
        FamilyMember.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
  );
}

/// Per-family budget workspace: its own accounts, blocks and month data.
/// Switching family swaps the whole workspace, mirroring the design.
class Workspace {
  Workspace({
    required this.accounts,
    required this.cats,
    required this.data,
    List<TaskList>? taskLists,
    List<ShoppingList>? shoppingLists,
    List<CalendarEvent>? events,
    List<EventCategory>? eventCategories,
    List<ImportedCalendar>? importedCalendars,
    Map<String, DayPlan>? weeklyPlan,
    List<CalendarLayerDef>? calendarLayers,
  }) : taskLists = taskLists ?? <TaskList>[],
       shoppingLists = shoppingLists ?? <ShoppingList>[],
       events = events ?? <CalendarEvent>[],
       eventCategories = eventCategories ?? <EventCategory>[],
       importedCalendars = importedCalendars ?? <ImportedCalendar>[],
       weeklyPlan = weeklyPlan ?? <String, DayPlan>{},
       calendarLayers = (calendarLayers == null || calendarLayers.isEmpty)
           ? kDefaultCalendarLayers()
           : calendarLayers;

  List<Account> accounts;
  List<Category> cats;
  Map<int, Map<String, MonthData>> data;
  List<TaskList> taskLists;
  List<ShoppingList> shoppingLists;
  List<CalendarEvent> events;
  List<EventCategory> eventCategories;
  List<ImportedCalendar> importedCalendars;

  /// User-customizable calendar layers (built-ins + any custom ones), in
  /// display order. Always seeded with the 3 built-in defaults when absent
  /// or empty (see the constructor and [Workspace.fromJson]) so every
  /// existing family keeps today's exact 3 layers with zero visible change.
  List<CalendarLayerDef> calendarLayers;

  /// Weekly meal plan + notes, keyed by ISO `YYYY-MM-DD` date. Sparse — only
  /// days with content need an entry.
  Map<String, DayPlan> weeklyPlan;

  Map<String, dynamic> toJson() => {
    'accounts': accounts.map((a) => a.toJson()).toList(),
    'cats': cats.map((c) => c.toJson()).toList(),
    'data': {
      for (final entry in data.entries)
        entry.key.toString(): {
          for (final m in entry.value.entries) m.key: m.value.toJson(),
        },
    },
    'taskLists': taskLists.map((l) => l.toJson()).toList(),
    'shoppingLists': shoppingLists.map((l) => l.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'eventCategories': eventCategories.map((c) => c.toJson()).toList(),
    'importedCalendars': importedCalendars.map((c) => c.toJson()).toList(),
    'weeklyPlan': {
      for (final entry in weeklyPlan.entries) entry.key: entry.value.toJson(),
    },
    'calendarLayers': calendarLayers.map((l) => l.toJson()).toList(),
  };

  factory Workspace.fromJson(Map<String, dynamic> j) {
    // A freshly created family starts with no accounts and no budget blocks
    // (see [Workspace.empty]). We must NOT backfill defaults here, otherwise a
    // legitimately-empty workspace would sprout default accounts/blocks the
    // next time it round-trips through Firestore or local storage.
    final accounts = <Account>[
      for (final a in (j['accounts'] as List? ?? []))
        Account.fromJson(Map<String, dynamic>.from(a as Map)),
    ];
    final cats = <Category>[
      for (final c in (j['cats'] as List? ?? []))
        Category.fromJson(Map<String, dynamic>.from(c as Map)),
    ];
    final data = <int, Map<String, MonthData>>{};
    (j['data'] as Map<String, dynamic>? ?? {}).forEach((yr, months) {
      final yKey = int.tryParse(yr) ?? 2026;
      final map = <String, MonthData>{};
      (months as Map<String, dynamic>).forEach((mk, md) {
        map[mk] = MonthData.fromJson(Map<String, dynamic>.from(md as Map));
      });
      data[yKey] = map;
    });
    ensureIncomeCategory(cats, data);
    final taskLists = <TaskList>[
      for (final l in (j['taskLists'] as List? ?? []))
        TaskList.fromJson(Map<String, dynamic>.from(l as Map)),
    ];
    final shoppingLists = <ShoppingList>[
      for (final l in (j['shoppingLists'] as List? ?? []))
        ShoppingList.fromJson(Map<String, dynamic>.from(l as Map)),
    ];
    final events = <CalendarEvent>[
      for (final e in (j['events'] as List? ?? []))
        CalendarEvent.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    final eventCategories = <EventCategory>[
      for (final c in (j['eventCategories'] as List? ?? []))
        EventCategory.fromJson(Map<String, dynamic>.from(c as Map)),
    ];
    final importedCalendars = <ImportedCalendar>[
      for (final c in (j['importedCalendars'] as List? ?? []))
        ImportedCalendar.fromJson(Map<String, dynamic>.from(c as Map)),
    ];
    final weeklyPlan = <String, DayPlan>{
      for (final entry
          in (j['weeklyPlan'] as Map<String, dynamic>? ?? {}).entries)
        entry.key: DayPlan.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        ),
    };
    // Absent or empty `calendarLayers` (every family's workspace saved
    // before layers became customizable) is backfilled with today's exact
    // 3 built-in defaults — see [Workspace]'s constructor, which applies
    // the same fallback.
    final rawLayers = j['calendarLayers'] as List?;
    final calendarLayers = <CalendarLayerDef>[
      for (final l in (rawLayers ?? const []))
        CalendarLayerDef.fromJson(Map<String, dynamic>.from(l as Map)),
    ];
    return Workspace(
      accounts: accounts,
      cats: cats,
      data: data,
      taskLists: taskLists,
      shoppingLists: shoppingLists,
      events: events,
      eventCategories: eventCategories,
      importedCalendars: importedCalendars,
      weeklyPlan: weeklyPlan,
      calendarLayers: calendarLayers,
    );
  }

  /// Builds a fresh, truly empty workspace: no accounts and no budget blocks.
  /// A newly created family starts blank — the user adds their own accounts and
  /// blocks from Settings (see issue #119).
  factory Workspace.empty() {
    final yearMap = <String, MonthData>{};
    for (final mk in kMonthKeys) {
      yearMap[mk] = MonthData();
    }
    return Workspace(
      accounts: <Account>[],
      cats: <Category>[],
      data: {2026: yearMap},
    );
  }
}

/// Mirrors the design's `seedFamily(user)` — creates the initial family with
/// the user as owner plus one dummy member, so a new account isn't empty.
/// [selfId] is the caller's own stable id (`myId`) for the owner's member row.
Family seedFamily(String id, AppUser u, String selfId, {String? ownerUid}) {
  final last = u.name.trim().split(RegExp(r'\s+')).last;
  final name = '$last family';
  return Family(
    id: id,
    name: name,
    username: familySlug(name),
    ownerUid: ownerUid,
    memberUids: ownerUid != null ? [ownerUid] : <String>[],
    members: [
      FamilyMember(
        id: selfId,
        name: u.name,
        email: u.email,
        initials: u.initials,
        color: kMemberColors[0],
        uid: ownerUid ?? selfId,
        photo: u.photo,
        role: 'owner',
        status: 'active',
      ),
      FamilyMember(
        id: uid(),
        name: 'Erik $last',
        email: 'erik.${last.toLowerCase()}@gmail.com',
        initials: initialsOf('Erik $last'),
        color: kMemberColors[1],
        role: 'member',
        status: 'active',
      ),
    ],
  );
}
