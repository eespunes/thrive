part of 'package:family_money_management_app/main.dart';

const String kStorageKey = 'thrive.v3';
const String kDefaultAccountKey = 'shared';

/// Palettes & icon choices used by the editor sheets.
const List<Color> kCatPalette = [
  Color(0xff2563eb),
  Color(0xff7c3aed),
  Color(0xffe11d48),
  Color(0xff059669),
  Color(0xffd97706),
  Color(0xffea580c),
  Color(0xff0d9488),
  Color(0xff475569),
  Color(0xff0E9A8D),
  Color(0xff9333ea),
];

const List<Color> kAccPalette = [
  Color(0xff1E7FB5),
  Color(0xff54A96A),
  Color(0xff0E9A8D),
  Color(0xff7c3aed),
  Color(0xffe11d48),
  Color(0xffd97706),
  Color(0xff0d9488),
  Color(0xff2563eb),
];

const List<String> kCatIcons = [
  'home',
  'repeat',
  'card',
  'trend',
  'users',
  'cart',
  'heart',
  'receipt',
  'folder',
  'wallet',
  'tag',
  'shield',
];

class Account {
  Account({
    required this.key,
    required this.name,
    required this.short,
    required this.initials,
    required this.color,
  });

  String key;
  String name;
  String short;
  String initials;
  Color color;

  Account copy() => Account(
    key: key,
    name: name,
    short: short,
    initials: initials,
    color: color,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'short': short,
    'initials': initials,
    'color': color.value,
  };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
    key: (j['key'] ?? kDefaultAccountKey).toString(),
    name: (j['name'] ?? 'Account').toString(),
    short: (j['short'] ?? 'Account').toString(),
    initials: (j['initials'] ?? 'AC').toString(),
    color: Color((j['color'] as num?)?.toInt() ?? 0xff0E9A8D),
  );
}

class Category {
  Category({
    required this.key,
    required this.title,
    required this.icon,
    required this.marker,
    required this.tone,
    required this.bg,
    this.hasUntil = false,
    this.temporary = false,
    this.ownerYear,
    this.ownerMonthIdx,
  });

  String key;
  String title;
  String icon;
  String marker; // 'day' | 'date'
  Color tone;
  Color bg;
  bool hasUntil;
  bool temporary;
  int? ownerYear;
  int? ownerMonthIdx;

  Category copy() => Category(
    key: key,
    title: title,
    icon: icon,
    marker: marker,
    tone: tone,
    bg: bg,
    hasUntil: hasUntil,
    temporary: temporary,
    ownerYear: ownerYear,
    ownerMonthIdx: ownerMonthIdx,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'title': title,
    'icon': icon,
    'marker': marker,
    'tone': tone.value,
    'bg': bg.value,
    'hasUntil': hasUntil,
    if (temporary) 'temporary': true,
    if (ownerYear != null) 'ownerYear': ownerYear,
    if (ownerMonthIdx != null) 'ownerMonthIdx': ownerMonthIdx,
  };

  factory Category.fromJson(Map<String, dynamic> j) {
    final tone = Color((j['tone'] as num?)?.toInt() ?? 0xff2563eb);
    return Category(
      key: (j['key'] ?? 'block').toString(),
      title: (j['title'] ?? 'Block').toString(),
      icon: (j['icon'] ?? 'folder').toString(),
      marker: (j['marker'] ?? 'date').toString(),
      tone: tone,
      bg: j['bg'] != null
          ? Color((j['bg'] as num).toInt())
          : tintFor(tone),
      hasUntil: j['hasUntil'] == true,
      temporary: j['temporary'] == true,
      ownerYear: (j['ownerYear'] as num?)?.toInt(),
      ownerMonthIdx: (j['ownerMonthIdx'] as num?)?.toInt(),
    );
  }
}

class IncomeItem {
  IncomeItem({
    required this.id,
    required this.label,
    required this.expected,
    required this.actual,
    required this.received,
    required this.account,
  });

  String id;
  String label;
  double expected;
  double actual;
  bool received;
  String account;

  IncomeItem copyWithId(String newId) => IncomeItem(
    id: newId,
    label: label,
    expected: expected,
    actual: actual,
    received: received,
    account: account,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'expected': expected,
    'actual': actual,
    'received': received,
    'account': account,
  };

  factory IncomeItem.fromJson(Map<String, dynamic> j) => IncomeItem(
    id: (j['id'] ?? uid()).toString(),
    label: (j['label'] ?? '').toString(),
    expected: parseNum(j['expected']),
    actual: parseNum(j['actual']),
    received: j['received'] == true,
    account: (j['account'] ?? kDefaultAccountKey).toString(),
  );
}

class ExpenseItem {
  ExpenseItem({
    required this.id,
    required this.label,
    required this.marker,
    required this.amount,
    required this.paid,
    required this.account,
    this.until,
  });

  String id;
  String label;
  String marker;
  double amount;
  bool paid;
  String account;
  Object? until;

  ExpenseItem copyWithId(String newId) => ExpenseItem(
    id: newId,
    label: label,
    marker: marker,
    amount: amount,
    paid: paid,
    account: account,
    until: until,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'marker': marker,
    'amount': amount,
    'paid': paid,
    'account': account,
    if (until != null) 'until': until,
  };

  factory ExpenseItem.fromJson(Map<String, dynamic> j) => ExpenseItem(
    id: (j['id'] ?? uid()).toString(),
    label: (j['label'] ?? '').toString(),
    marker: (j['marker'] ?? '').toString(),
    amount: parseNum(j['amount']),
    paid: j['paid'] == true,
    account: (j['account'] ?? kDefaultAccountKey).toString(),
    until: j['until'],
  );
}

class MonthData {
  MonthData({
    List<IncomeItem>? income,
    Map<String, List<ExpenseItem>>? blocks,
    Map<String, double>? caps,
    this.closed = false,
    this.catsSnapshot,
    this.accountsSnapshot,
  }) : income = income ?? [],
       blocks = blocks ?? {},
       caps = caps ?? {};

  List<IncomeItem> income;
  Map<String, List<ExpenseItem>> blocks;
  Map<String, double> caps;
  bool closed;
  List<Category>? catsSnapshot;
  List<Account>? accountsSnapshot;

  Map<String, dynamic> toJson() => {
    'income': income.map((e) => e.toJson()).toList(),
    'blocks': blocks.map(
      (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
    ),
    'caps': caps,
    'closed': closed,
    if (catsSnapshot != null)
      'catsSnapshot': catsSnapshot!.map((c) => c.toJson()).toList(),
    if (accountsSnapshot != null)
      'accountsSnapshot': accountsSnapshot!.map((a) => a.toJson()).toList(),
  };

  factory MonthData.fromJson(Map<String, dynamic> j) {
    final blocks = <String, List<ExpenseItem>>{};
    (j['blocks'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
      blocks[k] = [
        for (final it in (v as List? ?? []))
          ExpenseItem.fromJson(Map<String, dynamic>.from(it as Map)),
      ];
    });
    final caps = <String, double>{};
    (j['caps'] as Map<String, dynamic>? ?? {}).forEach(
      (k, v) => caps[k] = parseNum(v),
    );
    return MonthData(
      income: [
        for (final it in (j['income'] as List? ?? []))
          IncomeItem.fromJson(Map<String, dynamic>.from(it as Map)),
      ],
      blocks: blocks,
      caps: caps,
      closed: j['closed'] == true,
      catsSnapshot: j['catsSnapshot'] == null
          ? null
          : [
              for (final c in (j['catsSnapshot'] as List))
                Category.fromJson(Map<String, dynamic>.from(c as Map)),
            ],
      accountsSnapshot: j['accountsSnapshot'] == null
          ? null
          : [
              for (final a in (j['accountsSnapshot'] as List))
                Account.fromJson(Map<String, dynamic>.from(a as Map)),
            ],
    );
  }
}

List<Account> defaultAccounts() => [
  Account(
    key: 'eva',
    name: "Eva's account",
    short: 'Eva',
    initials: 'EV',
    color: const Color(0xff1E7FB5),
  ),
  Account(
    key: 'erik',
    name: "Erik's account",
    short: 'Erik',
    initials: 'ER',
    color: const Color(0xff54A96A),
  ),
  Account(
    key: 'shared',
    name: 'Shared account',
    short: 'Shared',
    initials: 'SH',
    color: const Color(0xff0E9A8D),
  ),
];

List<Category> defaultCats() => [
  Category(
    key: 'home',
    title: 'Home',
    icon: 'home',
    marker: 'day',
    tone: const Color(0xff2563eb),
    bg: const Color(0xffeff6ff),
  ),
  Category(
    key: 'subscriptions',
    title: 'Subscriptions',
    icon: 'repeat',
    marker: 'date',
    tone: const Color(0xff7c3aed),
    bg: const Color(0xfff5f3ff),
  ),
  Category(
    key: 'debt',
    title: 'Debt',
    icon: 'card',
    marker: 'day',
    tone: const Color(0xffe11d48),
    bg: const Color(0xfffff1f2),
    hasUntil: true,
  ),
  Category(
    key: 'savings',
    title: 'Savings',
    icon: 'trend',
    marker: 'date',
    tone: const Color(0xff059669),
    bg: const Color(0xffecfdf5),
  ),
  Category(
    key: 'personal',
    title: 'Personal & Family',
    icon: 'users',
    marker: 'date',
    tone: const Color(0xffd97706),
    bg: const Color(0xfffffbeb),
  ),
  Category(
    key: 'food',
    title: 'Food',
    icon: 'cart',
    marker: 'date',
    tone: const Color(0xffea580c),
    bg: const Color(0xfffff7ed),
  ),
  Category(
    key: 'health',
    title: 'Health',
    icon: 'heart',
    marker: 'date',
    tone: const Color(0xff0d9488),
    bg: const Color(0xfff0fdfa),
  ),
  Category(
    key: 'additional',
    title: 'Additional Costs',
    icon: 'receipt',
    marker: 'date',
    tone: const Color(0xff475569),
    bg: const Color(0xfff1f5f9),
  ),
];
