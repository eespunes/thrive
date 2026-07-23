part of 'package:family_money_management_app/main.dart';

const String kStorageKey = 'thrive.v3';
const String kDefaultAccountKey = 'shared';

/// Reserved key for the block that legacy `MonthData.income` entries migrate
/// into (issue #137 — income is now just a block whose [Category.isIncome] is
/// true). Kept stable so the migration in [MonthData.fromJson] and the income
/// category injected on load line up.
const String kIncomeBlockKey = 'income';

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

class Account {
  Account({
    required this.key,
    required this.name,
    required this.short,
    required this.initials,
    required this.color,
    this.emoji,
    this.picture,
  });

  String key;
  String name;
  String short;
  String initials;
  Color color;

  /// Optional emoji shown instead of the colored initials tile (issue #131).
  String? emoji;

  /// Optional base64 picture shown instead of the emoji/initials (issue #131).
  String? picture;

  Account copy() => Account(
    key: key,
    name: name,
    short: short,
    initials: initials,
    color: color,
    emoji: emoji,
    picture: picture,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'short': short,
    'initials': initials,
    'color': color.toARGB32(),
    if (emoji != null) 'emoji': emoji,
    if (picture != null) 'picture': picture,
  };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
    key: (j['key'] ?? kDefaultAccountKey).toString(),
    name: (j['name'] ?? 'Account').toString(),
    short: (j['short'] ?? 'Account').toString(),
    initials: (j['initials'] ?? 'AC').toString(),
    color: Color((j['color'] as num?)?.toInt() ?? 0xff0E9A8D),
    emoji: (j['emoji'] as String?)?.isNotEmpty == true ? j['emoji'] : null,
    picture: (j['picture'] as String?)?.isNotEmpty == true
        ? j['picture']
        : null,
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
    this.emoji,
    this.picture,
    this.hasUntil = false,
    this.temporary = false,
    this.ownerYear,
    this.ownerMonthIdx,
    this.isIncome = false,
    this.isSavings = false,
  });

  String key;
  String title;

  /// Legacy stroke-icon name. Kept for blocks created before the emoji/picture
  /// picker (issue #131); rendered only as the fallback when no emoji/picture
  /// is set.
  String icon;
  String marker; // 'day' | 'date'
  Color tone;
  Color bg;

  /// Optional emoji shown instead of the icon (issue #131).
  String? emoji;

  /// Optional base64 picture shown instead of the emoji/icon (issue #131).
  String? picture;
  bool hasUntil;
  bool temporary;
  int? ownerYear;
  int? ownerMonthIdx;

  /// Whether this block *receives* money (income) rather than withdrawing it
  /// (a normal expense). Issue #137 — income is just a block with a direction.
  bool isIncome;

  /// Whether this block's amounts count towards savings in the statistics
  /// (issue #136). Only meaningful for withdrawing blocks.
  bool isSavings;

  Category copy() => Category(
    key: key,
    title: title,
    icon: icon,
    marker: marker,
    tone: tone,
    bg: bg,
    emoji: emoji,
    picture: picture,
    hasUntil: hasUntil,
    temporary: temporary,
    ownerYear: ownerYear,
    ownerMonthIdx: ownerMonthIdx,
    isIncome: isIncome,
    isSavings: isSavings,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'title': title,
    'icon': icon,
    'marker': marker,
    'tone': tone.toARGB32(),
    'bg': bg.toARGB32(),
    if (emoji != null) 'emoji': emoji,
    if (picture != null) 'picture': picture,
    'hasUntil': hasUntil,
    if (temporary) 'temporary': true,
    if (ownerYear != null) 'ownerYear': ownerYear,
    if (ownerMonthIdx != null) 'ownerMonthIdx': ownerMonthIdx,
    if (isIncome) 'isIncome': true,
    if (isSavings) 'isSavings': true,
  };

  factory Category.fromJson(Map<String, dynamic> j) {
    final tone = Color((j['tone'] as num?)?.toInt() ?? 0xff2563eb);
    return Category(
      key: (j['key'] ?? 'block').toString(),
      title: (j['title'] ?? 'Block').toString(),
      icon: (j['icon'] ?? 'folder').toString(),
      marker: (j['marker'] ?? 'date').toString(),
      tone: tone,
      bg: j['bg'] != null ? Color((j['bg'] as num).toInt()) : tintFor(tone),
      emoji: (j['emoji'] as String?)?.isNotEmpty == true ? j['emoji'] : null,
      picture: (j['picture'] as String?)?.isNotEmpty == true
          ? j['picture']
          : null,
      hasUntil: j['hasUntil'] == true,
      temporary: j['temporary'] == true,
      ownerYear: (j['ownerYear'] as num?)?.toInt(),
      ownerMonthIdx: (j['ownerMonthIdx'] as num?)?.toInt(),
      isIncome: j['isIncome'] == true,
      isSavings: j['isSavings'] == true,
    );
  }
}

class ExpenseItem {
  ExpenseItem({
    required this.id,
    required this.label,
    required this.marker,
    required this.amount,
    required this.paid,
    required this.account,
    this.payee = '',
    this.until,
  });

  String id;

  /// Company/person paid to or received from.
  String payee;

  /// Subcategory or short note describing the item.
  String label;
  String marker;
  double amount;
  bool paid;
  String account;
  Object? until;

  ExpenseItem copyWithId(String newId) => ExpenseItem(
    id: newId,
    payee: payee,
    label: label,
    marker: marker,
    amount: amount,
    paid: paid,
    account: account,
    until: until,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (payee.isNotEmpty) 'payee': payee,
    'label': label,
    'marker': marker,
    'amount': amount,
    'paid': paid,
    'account': account,
    if (until != null) 'until': until,
  };

  factory ExpenseItem.fromJson(Map<String, dynamic> j) => ExpenseItem(
    id: (j['id'] ?? uid()).toString(),
    payee: (j['payee'] ?? '').toString(),
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
    Map<String, List<ExpenseItem>>? blocks,
    Map<String, double>? caps,
    this.closed = false,
    this.catsSnapshot,
    this.accountsSnapshot,
  }) : blocks = blocks ?? {},
       caps = caps ?? {};

  Map<String, List<ExpenseItem>> blocks;
  Map<String, double> caps;
  bool closed;
  List<Category>? catsSnapshot;
  List<Account>? accountsSnapshot;

  Map<String, dynamic> toJson() => {
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
    // Migrate legacy `income` entries (pre-#137) into the reserved income
    // block. Income used `expected`/`actual`/`received`; the unified item keeps
    // the planned amount and maps `received` onto `paid`.
    final legacyIncome = j['income'] as List? ?? const [];
    if (legacyIncome.isNotEmpty) {
      final dst = blocks.putIfAbsent(kIncomeBlockKey, () => <ExpenseItem>[]);
      for (final raw in legacyIncome) {
        final map = Map<String, dynamic>.from(raw as Map);
        final expected = parseNum(map['expected']);
        dst.add(
          ExpenseItem(
            id: (map['id'] ?? uid()).toString(),
            label: (map['label'] ?? '').toString(),
            marker: '',
            amount: expected != 0 ? expected : parseNum(map['actual']),
            paid: map['received'] == true,
            account: (map['account'] ?? kDefaultAccountKey).toString(),
          ),
        );
      }
    }
    final caps = <String, double>{};
    (j['caps'] as Map<String, dynamic>? ?? {}).forEach(
      (k, v) => caps[k] = parseNum(v),
    );
    return MonthData(
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

/// Ensures the category list has an income block when month data carries
/// migrated legacy income (issue #137). Existing workspaces stored income
/// outside `cats`, so after [MonthData.fromJson] lifts it into the reserved
/// income block we must surface a matching [Category] or it would render
/// nowhere. Mutates and returns [cats].
List<Category> ensureIncomeCategory(
  List<Category> cats,
  Map<int, Map<String, MonthData>> data,
) {
  if (cats.any((c) => c.key == kIncomeBlockKey || c.isIncome)) return cats;
  final hasIncomeItems = data.values.any(
    (months) => months.values.any(
      (m) => (m.blocks[kIncomeBlockKey] ?? const []).isNotEmpty,
    ),
  );
  if (hasIncomeItems) cats.insert(0, defaultIncomeCat());
  return cats;
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

/// The reserved income block (issue #137). Income is rendered like any other
/// block but [isIncome] flips its labels and routes its amounts to income
/// totals instead of expenses.
Category defaultIncomeCat() => Category(
  key: kIncomeBlockKey,
  title: 'Income',
  icon: 'wallet',
  marker: 'date',
  tone: const Color(0xff059669),
  bg: const Color(0xffecfdf5),
  isIncome: true,
);

List<Category> defaultCats() => [
  defaultIncomeCat(),
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
    isSavings: true,
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
