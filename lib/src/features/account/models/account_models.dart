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
    this.photo,
    this.role = 'member', // 'owner' | 'member'
    this.status = 'active', // 'active' | 'invited'
  });

  String id;
  String name;
  String email;
  String initials;
  Color color;
  String? photo;
  String role;
  String status;

  FamilyMember copy() => FamilyMember(
    id: id,
    name: name,
    email: email,
    initials: initials,
    color: color,
    photo: photo,
    role: role,
    status: status,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'initials': initials,
    'color': color.toARGB32(),
    if (photo != null) 'photo': photo,
    'role': role,
    'status': status,
  };

  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
    id: (j['id'] ?? uid()).toString(),
    name: (j['name'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    initials: (j['initials'] ?? initialsOf(j['name']?.toString())).toString(),
    color: Color((j['color'] as num?)?.toInt() ?? 0xff0E9A8D),
    photo: j['photo']?.toString(),
    role: (j['role'] ?? 'member').toString(),
    status: (j['status'] ?? 'active').toString(),
  );
}

/// A family workspace. Mirrors the design's `family` object.
class Family {
  Family({required this.id, required this.name, required this.members});

  String id;
  String name;
  List<FamilyMember> members;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'members': members.map((m) => m.toJson()).toList(),
  };

  factory Family.fromJson(Map<String, dynamic> j) => Family(
    id: (j['id'] ?? 'fam_main').toString(),
    name: (j['name'] ?? 'Family').toString(),
    members: [
      for (final m in (j['members'] as List? ?? []))
        FamilyMember.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
  );
}

/// Per-family budget workspace: its own accounts, blocks and month data.
/// Switching family swaps the whole workspace, mirroring the design.
class Workspace {
  Workspace({required this.accounts, required this.cats, required this.data});

  List<Account> accounts;
  List<Category> cats;
  Map<int, Map<String, MonthData>> data;

  Map<String, dynamic> toJson() => {
    'accounts': accounts.map((a) => a.toJson()).toList(),
    'cats': cats.map((c) => c.toJson()).toList(),
    'data': {
      for (final entry in data.entries)
        entry.key.toString(): {
          for (final m in entry.value.entries) m.key: m.value.toJson(),
        },
    },
  };

  factory Workspace.fromJson(Map<String, dynamic> j) {
    var accounts = <Account>[
      for (final a in (j['accounts'] as List? ?? []))
        Account.fromJson(Map<String, dynamic>.from(a as Map)),
    ];
    if (accounts.isEmpty) accounts = defaultAccounts();
    var cats = <Category>[
      for (final c in (j['cats'] as List? ?? []))
        Category.fromJson(Map<String, dynamic>.from(c as Map)),
    ];
    if (cats.isEmpty) cats = defaultCats();
    final data = <int, Map<String, MonthData>>{};
    (j['data'] as Map<String, dynamic>? ?? {}).forEach((yr, months) {
      final yKey = int.tryParse(yr) ?? 2026;
      final map = <String, MonthData>{};
      (months as Map<String, dynamic>).forEach((mk, md) {
        map[mk] = MonthData.fromJson(Map<String, dynamic>.from(md as Map));
      });
      data[yKey] = map;
    });
    return Workspace(accounts: accounts, cats: cats, data: data);
  }

  /// Builds a fresh empty workspace (default accounts/cats, empty months).
  factory Workspace.empty() {
    final cats = defaultCats();
    final yearMap = <String, MonthData>{};
    for (final mk in kMonthKeys) {
      final month = MonthData();
      for (final c in cats) {
        month.blocks[c.key] = [];
      }
      yearMap[mk] = month;
    }
    return Workspace(
      accounts: defaultAccounts(),
      cats: cats,
      data: {2026: yearMap},
    );
  }
}

/// Mirrors the design's `seedFamily(user)` — creates the initial family with
/// the user as owner plus one dummy member, so a new account isn't empty.
Family seedFamily(String id, AppUser u) {
  final last = u.name.trim().split(RegExp(r'\s+')).last;
  return Family(
    id: id,
    name: '$last family',
    members: [
      FamilyMember(
        id: 'me',
        name: u.name,
        email: u.email,
        initials: u.initials,
        color: kMemberColors[0],
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
