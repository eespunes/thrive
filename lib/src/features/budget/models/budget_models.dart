part of 'package:family_money_management_app/main.dart';

class DonutPainter extends CustomPainter {
  DonutPainter(this.blocks);

  final List<ExpenseBlock> blocks;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()
      ..color = AppColors.track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    canvas.drawCircle(center, radius, base);

    final total = blocks.fold<double>(0, (sum, block) => sum + block.total);
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final block in blocks) {
      final sweep = (block.total / total) * math.pi * 2;
      final paint = Paint()
        ..color = block.meta.tone
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) =>
      oldDelegate.blocks != blocks;
}

class ComputedMonth {
  ComputedMonth(this.month, this.monthIndex, this.year) {
    for (final meta in categoryMeta) {
      final items = month.expenses[meta.key] ?? <ExpenseItem>[];
      blocks[meta.key] = ExpenseBlock(
        meta: meta,
        items: items,
        monthIndex: monthIndex,
        year: year,
      );
    }
    final accountMax = math.max(
      1,
      accountRaw.map((item) => item.amount).fold<double>(0, math.max),
    );
    accounts = accountRaw
        .map((item) => item.copyWith(progress: item.amount / accountMax))
        .toList();
  }

  final MonthBudget month;
  final int monthIndex;
  final int year;
  final Map<String, ExpenseBlock> blocks = {};
  late final List<AccountShare> accounts;

  String get monthLabel => monthLabels[monthIndex];
  double get expectedIncome =>
      month.income.fold(0, (sum, item) => sum + item.expected);
  double get realIncome => month.income.fold(
    0,
    (sum, item) => sum + (item.received ? item.actual : 0),
  );
  double get totalBudget =>
      blocks.values.fold(0, (sum, block) => sum + block.total);
  double get totalPaid =>
      blocks.values.fold(0, (sum, block) => sum + block.paid);
  double get stillToPay => math.max(0, totalBudget - totalPaid);
  double get expectedBalance => expectedIncome - totalBudget;
  double get balance => realIncome - totalBudget;

  List<AccountShare> get accountRaw {
    final totals = {for (final account in accountMeta) account.key: 0.0};
    for (final block in blocks.values) {
      for (final item in block.items) {
        if (!item.paid) {
          totals[item.accountKey] =
              (totals[item.accountKey] ?? 0) + item.amount;
        }
      }
    }

    return [
      for (final account in accountMeta)
        AccountShare(account: account, amount: totals[account.key] ?? 0),
    ];
  }
}

class ExpenseBlock {
  ExpenseBlock({
    required this.meta,
    required this.items,
    required this.monthIndex,
    required this.year,
  }) {
    for (final item in items) {
      item.untilLabel = meta.hasUntil ? untilLabel(item.untilRaw) : null;
      item.untilState = item.untilLabel == null
          ? UntilState.future
          : untilState(item.untilLabel!, monthIndex, year);
    }
  }

  final CategoryMeta meta;
  final List<ExpenseItem> items;
  final int monthIndex;
  final int year;

  double get total => items.fold(0, (sum, item) => sum + item.amount);
  double get paid =>
      items.fold(0, (sum, item) => sum + (item.paid ? item.amount : 0));
  double get progress =>
      total > 0 ? (paid / total).clamp(0, 1) : (paid > 0 ? 1 : 0);
}

class MonthBudget {
  MonthBudget({
    required this.key,
    required this.income,
    required this.expenses,
    required this.sumup,
    this.isClosed = false,
  });

  final String key;
  final List<IncomeItem> income;
  final Map<String, List<ExpenseItem>> expenses;
  final Map<String, double> sumup;
  bool isClosed;

  factory MonthBudget.fromJson(String key, Map<String, dynamic> json) {
    final sumup = (json['sumup'] as Map<String, dynamic>? ?? {}).map(
      (key, value) => MapEntry(key, asDouble(value)),
    );
    return MonthBudget(
      key: key,
      income: [
        for (final indexed in (json['income'] as List? ?? []).indexed)
          IncomeItem.fromJson(
            '$key-income-${indexed.$1}',
            indexed.$2 as Map<String, dynamic>,
          ),
      ],
      expenses: {
        for (final meta in categoryMeta)
          meta.key: [
            for (final indexed in (json[meta.key] as List? ?? []).indexed)
              ExpenseItem.fromJson(
                '$key-${meta.key}-${indexed.$1}',
                indexed.$2 as Map<String, dynamic>,
                meta,
                defaultExpenseAccountKey(
                  indexed.$2 as Map<String, dynamic>,
                  sumup,
                ),
              ),
          ],
      },
      sumup: sumup,
      isClosed: json['isClosed'] == true,
    );
  }

  factory MonthBudget.empty(String key) {
    return MonthBudget(
      key: key,
      income: [],
      expenses: {for (final meta in categoryMeta) meta.key: <ExpenseItem>[]},
      sumup: {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'income': [for (final item in income) item.toJson()],
      for (final entry in expenses.entries)
        entry.key: [for (final item in entry.value) item.toJson()],
      'sumup': sumup,
      'isClosed': isClosed,
    };
  }
}

Map<String, MonthBudget> monthsFromState(Map<String, dynamic> monthState) {
  return {
    for (final key in monthKeys)
      key: monthState[key] is Map<String, dynamic>
          ? MonthBudget.fromJson(key, monthState[key] as Map<String, dynamic>)
          : MonthBudget.empty(key),
  };
}

Map<String, MonthBudget> emptyYearBudget(int year) {
  return {for (final key in monthKeys) key: MonthBudget.empty(key)};
}

class IncomeItem {
  IncomeItem({
    required this.id,
    required this.label,
    required this.expected,
    required this.actual,
    required this.received,
    required this.accountKey,
  });

  final String id;
  final String label;
  double expected;
  double actual;
  bool received;
  String accountKey;

  factory IncomeItem.fromJson(String id, Map<String, dynamic> json) {
    return IncomeItem(
      id: id,
      label: stringValue(json['label'], fallback: 'Income'),
      expected: asDouble(json['expected']),
      actual: asDouble(json['actual']),
      received: json['received'] == true,
      accountKey: normalizedAccountKey(json['account']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'expected': expected,
      'actual': actual,
      'received': received,
      'account': accountKey,
    };
  }
}

class ExpenseItem {
  ExpenseItem({
    required this.id,
    required this.label,
    required this.marker,
    required this.amount,
    required this.paid,
    required this.accountKey,
    this.untilRaw,
  });

  final String id;
  final String label;
  String marker;
  double amount;
  bool paid;
  String accountKey;
  Object? untilRaw;
  String? untilLabel;
  UntilState untilState = UntilState.future;

  factory ExpenseItem.fromJson(
    String id,
    Map<String, dynamic> json,
    CategoryMeta meta,
    String defaultAccount,
  ) {
    return ExpenseItem(
      id: id,
      label: stringValue(json['label'], fallback: 'Expense'),
      marker: stringValue(
        json[meta.markerKey] ?? json['day'] ?? json['date'],
        fallback: '-',
      ),
      amount: asDouble(json['amount']),
      paid: json['paid'] == true,
      accountKey: normalizedAccountKey(
        json['account'],
        fallback: defaultAccount,
      ),
      untilRaw: json['until'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'date': marker,
      'amount': amount,
      'paid': paid,
      'account': accountKey,
      if (untilRaw != null) 'until': untilRaw,
    };
  }
}

class CategoryMeta {
   CategoryMeta({
    required this.key,
    required this.title,
    required this.icon,
    required this.markerKey,
    required this.tone,
    required this.background,
    this.hasUntil = false,
    this.isTemporary = false,
    this.orderIndex = 0,
  });

  final String key;
  final String title;
  final IconData icon;
  final String markerKey;
  final Color tone;
  final Color background;
  final bool hasUntil;
  bool isTemporary;
  int orderIndex;

  factory CategoryMeta.fromState(Map<String, dynamic> state) {
    final key = stringValue(state['key'], fallback: 'block');
    final defaultMeta = defaultCategoryMeta.where((meta) => meta.key == key);
    if (defaultMeta.isNotEmpty) {
      final meta = defaultMeta.first;
      return CategoryMeta(
        key: key,
        title: meta.title,
        icon: meta.icon,
        markerKey: meta.markerKey,
        tone: meta.tone,
        background: meta.background,
        hasUntil: meta.hasUntil,
        isTemporary: state['isTemporary'] == true,
        orderIndex: (state['orderIndex'] as num?)?.toInt() ?? 0,
      );
    }
    return CategoryMeta(
      key: key,
      title: stringValue(state['title'], fallback: 'Budget block'),
      icon: Icons.folder_rounded,
      markerKey: stringValue(state['markerKey'], fallback: 'date'),
      tone: colorFromInt(state['tone'], fallback: AppColors.indigo),
      background: AppColors.panel,
      hasUntil: state['hasUntil'] == true,
      isTemporary: state['isTemporary'] == true,
      orderIndex: (state['orderIndex'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toState() {
    return {
      'key': key,
      'title': title,
      'markerKey': markerKey,
      'tone': tone.toARGB32(),
      'hasUntil': hasUntil,
      'isTemporary': isTemporary,
      'orderIndex': orderIndex,
    };
  }
}

class AccountShare {
  const AccountShare({
    required this.account,
    required this.amount,
    this.progress = 0,
  });

  final AccountMeta account;
  final double amount;
  final double progress;

  String get name => account.name;
  String get initials => account.initials;
  Color get color => account.color;

  AccountShare copyWith({double? progress}) {
    return AccountShare(
      account: account,
      amount: amount,
      progress: progress ?? this.progress,
    );
  }
}

class AccountMeta {
  AccountMeta({
    required this.key,
    required this.name,
    required this.shortName,
    required this.initials,
    required this.color,
    this.orderIndex = 0,
  });

  final String key;
  final String name;
  final String shortName;
  final String initials;
  final Color color;
  int orderIndex;

  factory AccountMeta.fromState(Map<String, dynamic> state) {
    final key = stringValue(state['key'], fallback: defaultAccountKey);
    return AccountMeta(
      key: key,
      name: stringValue(state['name'], fallback: 'Account'),
      shortName: stringValue(state['shortName'], fallback: 'Account'),
      initials: stringValue(state['initials'], fallback: 'AC').toUpperCase(),
      color: colorFromInt(state['color'], fallback: AppColors.indigo),
      orderIndex: (state['orderIndex'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toState() {
    return {
      'key': key,
      'name': name,
      'shortName': shortName,
      'initials': initials,
      'color': color.toARGB32(),
      'orderIndex': orderIndex,
    };
  }
}

class QuickExpense {
  QuickExpense({
    required this.categoryKey,
    required this.itemId,
    required this.label,
    required this.amount,
    required this.accountKey,
    required this.marker,
    this.until,
  });

  final String categoryKey;
  final String itemId;
  final String label;
  final double amount;
  final String accountKey;
  final String marker;
  final String? until;
}

class NewIncome {
  NewIncome({
    required this.label,
    required this.expected,
    required this.actual,
    required this.received,
    required this.accountKey,
  });

  final String label;
  final double expected;
  final double actual;
  final bool received;
  final String accountKey;
}

class IncomeUpdate {
  const IncomeUpdate({
    required this.expected,
    required this.actual,
    required this.received,
    required this.accountKey,
  });

  final double expected;
  final double actual;
  final bool received;
  final String accountKey;
}

class ExpenseUpdate {
  const ExpenseUpdate({
    required this.amount,
    required this.marker,
    required this.paid,
    required this.accountKey,
    this.until,
  });

  final double amount;
  final String marker;
  final bool paid;
  final String accountKey;
  final String? until;
}

class CopyMonthSelection {
  const CopyMonthSelection({
    required this.sourceMonthIndex,
    required this.targetMonthIndex,
  });

  final int sourceMonthIndex;
  final int targetMonthIndex;
}
