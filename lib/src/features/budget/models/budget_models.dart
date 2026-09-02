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
  B.primary,
  Color(0xff9333ea),
];

const List<Color> kAccPalette = [
  Color(0xff1E7FB5),
  Color(0xff54A96A),
  B.primary,
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
    this.recurring = true,
    this.recurEvery = 1,
    this.seriesId,
    this.recurEndDate,
    this.generated = false,
    this.shift = 'none',
    this.cardId,
    this.day,
    this.reviewDay = false,
    this.exception = false,
    this.createdBy,
    this.createdAt,
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
  bool recurring;

  /// Repeat interval in months when [recurring] is true (issue #191). `1`
  /// means every month (the historical/default behaviour); `3` means every
  /// three months, etc.
  int recurEvery;
  String? seriesId;
  String? recurEndDate;
  bool generated;

  /// Weekend rule for the Money calendar's projection (issue #199): whether
  /// this item's resolved day moves off a Saturday/Sunday, and which way.
  /// `'none'` keeps the marker's day as-is, `'before'` moves to the last
  /// working day before the weekend (typical for salary), `'after'` moves to
  /// the first working day after. Derived at render time — the stored
  /// [marker] always stays the day the user actually meant (e.g. "24th").
  String shift;

  /// Discount card this item is (to be) paid with (epic #222). May point at
  /// a card that was since deleted — the editor then shows the dangling
  /// "Card deleted" state until the user unlinks or repicks (#297).
  String? cardId;

  /// Day of the month this entry posts on (#288), replacing the free-text
  /// [marker]. `null` means unscheduled — kept off the calendar and out of
  /// the projection (#290). [marker] is still written (derived) so older app
  /// versions in the same family workspace keep parsing a day.
  int? day;

  /// One-time "review" flag for legacy dayless income that the migration
  /// kept on day 1 (#290) — the editor points it out once, then clears it.
  bool reviewDay;

  /// Transient (never serialized): true when the loaded JSON predates the
  /// `day` field, i.e. [day] was parsed out of the legacy marker. Lets
  /// [migrateDaylessIncome] tell legacy dayless income apart from income the
  /// user explicitly unscheduled after the migration.
  bool legacyDay = false;

  /// Per-month exception in a recurring series (#292): a "save only this
  /// month" edit. Exceptions never act as series anchors and are never
  /// overwritten by [_syncRecurringSeries].
  bool exception;

  /// Member id of whoever created the entry (#300). Null on entries that
  /// predate the field — rendered as "—".
  String? createdBy;

  /// ISO date (yyyy-MM-dd) the entry was created (#300).
  String? createdAt;

  ExpenseItem copyWithId(String newId, {bool? generated}) => ExpenseItem(
    id: newId,
    payee: payee,
    label: label,
    marker: marker,
    amount: amount,
    paid: paid,
    account: account,
    until: until,
    recurring: recurring,
    recurEvery: recurEvery,
    seriesId: seriesId,
    recurEndDate: recurEndDate,
    generated: generated ?? this.generated,
    shift: shift,
    cardId: cardId,
    day: day,
    createdBy: createdBy,
    createdAt: createdAt,
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
    // Always written explicitly (rather than only when true) so a
    // user-chosen `false` round-trips distinctly from legacy data saved
    // before this field existed, which is migrated to `true` on load below.
    'recurring': recurring,
    if (recurEvery != 1) 'recurEvery': recurEvery,
    if (seriesId != null && seriesId!.isNotEmpty) 'seriesId': seriesId,
    if (recurEndDate != null) 'recurEndDate': recurEndDate,
    if (generated) 'generated': true,
    if (shift != 'none') 'shift': shift,
    if (cardId != null && cardId!.isNotEmpty) 'cardId': cardId,
    // `day` is written explicitly even when null so a deliberate
    // "unscheduled" round-trips distinctly from pre-migration data, which
    // has no `day` key at all and falls back to parsing `marker` on load.
    'day': day,
    if (reviewDay) 'reviewDay': true,
    if (exception) 'exception': true,
    if (createdBy != null) 'createdBy': createdBy,
    if (createdAt != null) 'createdAt': createdAt,
  };

  factory ExpenseItem.fromJson(Map<String, dynamic> j) {
    // Issue #185: recurring propagation is now the default. Items saved
    // before this field existed have no `recurring` key at all — migrate
    // those to `true`. Items saved after this change always carry an
    // explicit `true`/`false`, so an intentional opt-out is preserved.
    final recurring = j.containsKey('recurring')
        ? j['recurring'] == true
        : true;
    final rawSeriesId = (j['seriesId'] as String?)?.trim();
    final recurEndDate = normalizeRecurringEndDate(
      j['recurEndDate'] ?? j['until'],
    );
    return ExpenseItem(
      id: (j['id'] ?? uid()).toString(),
      payee: (j['payee'] ?? '').toString(),
      label: (j['label'] ?? '').toString(),
      marker: (j['marker'] ?? '').toString(),
      amount: parseNum(j['amount']),
      paid: j['paid'] == true,
      account: (j['account'] ?? kDefaultAccountKey).toString(),
      until: j['until'] ?? recurEndDate,
      recurring: recurring,
      recurEvery: ((j['recurEvery'] as num?)?.toInt() ?? 1).clamp(1, 60),
      seriesId: rawSeriesId?.isNotEmpty == true
          ? rawSeriesId
          : (recurring ? (j['id'] ?? uid()).toString() : null),
      recurEndDate: recurEndDate,
      generated: j['generated'] == true,
      shift: const {'none', 'before', 'after'}.contains(j['shift'])
          ? (j['shift'] as String)
          : 'none',
      cardId: (j['cardId'] as String?)?.trim().isNotEmpty == true
          ? (j['cardId'] as String).trim()
          : null,
      // #288 migration: pre-migration items have no `day` key — parse the
      // free-text marker once ("24th" → 24); unparseable ("-", "") becomes
      // unscheduled. Post-migration items always carry the key, so an
      // explicit null (unscheduled) is preserved.
      day: j.containsKey('day')
          ? ((j['day'] as num?)?.toInt())?.clamp(1, 31)
          : dayNumFromMarker((j['marker'] ?? '').toString()),
      reviewDay: j['reviewDay'] == true,
      exception: j['exception'] == true,
      createdBy: (j['createdBy'] as String?)?.trim().isNotEmpty == true
          ? (j['createdBy'] as String).trim()
          : null,
      createdAt: (j['createdAt'] as String?)?.trim().isNotEmpty == true
          ? (j['createdAt'] as String).trim()
          : null,
    )..legacyDay = !j.containsKey('day');
  }
}

class MonthData {
  MonthData({
    Map<String, List<ExpenseItem>>? blocks,
    Map<String, double>? caps,
    this.closed = false,
    this.catsSnapshot,
    this.accountsSnapshot,
    List<String>? seriesStops,
    List<String>? seriesSkips,
    this.open = 0,
  }) : blocks = blocks ?? {},
       caps = caps ?? {},
       seriesStops = seriesStops ?? <String>[],
       seriesSkips = seriesSkips ?? <String>[];

  Map<String, List<ExpenseItem>> blocks;
  Map<String, double> caps;
  bool closed;
  List<Category>? catsSnapshot;
  List<Account>? accountsSnapshot;
  List<String> seriesStops;

  /// Series ids skipped in just this month (#293 "Skip this month only") —
  /// the occurrence is removed and [_syncRecurringSeries] won't regenerate
  /// it, while the series continues in later months.
  List<String> seriesSkips;

  /// Start balance on the 1st of this month (issue #199 — Money calendar).
  /// The running-balance projection and its lowest point are counted from
  /// here.
  double open;

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
    if (seriesStops.isNotEmpty) 'seriesStops': seriesStops,
    if (seriesSkips.isNotEmpty) 'seriesSkips': seriesSkips,
    if (open != 0) 'open': open,
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
      seriesStops: [
        for (final id in (j['seriesStops'] as List? ?? const [])) id.toString(),
      ],
      seriesSkips: [
        for (final id in (j['seriesSkips'] as List? ?? const [])) id.toString(),
      ],
      open: parseNum(j['open']),
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

/// One-time migration for legacy dayless income (#290): income used to be
/// silently posted on day 1 by the Money calendar. The projection no longer
/// assigns day 1 implicitly, so existing income entries whose marker carried
/// no day keep their historical day 1 explicitly — flagged `reviewDay` so
/// the editor asks the user to confirm or unschedule it, once. Runs on every
/// load; a no-op once all items carry an explicit day. Mutates [data].
void migrateDaylessIncome(
  List<Category> cats,
  Map<int, Map<String, MonthData>> data,
) {
  final incomeKeys = {
    for (final c in cats)
      if (c.isIncome) c.key,
  };
  if (incomeKeys.isEmpty) return;
  for (final months in data.values) {
    for (final m in months.values) {
      if (m.closed) continue;
      for (final key in incomeKeys) {
        for (final it in m.blocks[key] ?? const <ExpenseItem>[]) {
          if (it.day == null && it.legacyDay) {
            it
              ..day = 1
              ..reviewDay = true;
          }
        }
      }
    }
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
    color: B.primary,
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
    tone: B.amber,
    bg: B.amberSoft,
  ),
  Category(
    key: 'food',
    title: 'Food',
    icon: 'cart',
    marker: 'date',
    tone: const Color(0xffea580c),
    bg: B.orangeSoft,
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
