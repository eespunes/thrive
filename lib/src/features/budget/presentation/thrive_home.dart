part of 'package:family_money_management_app/main.dart';

/// Root screen — a faithful Flutter port of the Thrive design `Component`.
/// Holds all app state and renders the three screens (overview, stats,
/// settings) plus the segmented header switcher.
class ThriveHome extends StatefulWidget {
  const ThriveHome({super.key});

  @override
  State<ThriveHome> createState() => _ThriveHomeState();
}

class _ThriveHomeState extends State<ThriveHome> {
  bool ready = false;
  int year = 2026;
  int monthIdx = 5;
  String screen = 'overview'; // overview | stats | settings
  String statsMode = 'month'; // month | year

  List<Account> accounts = defaultAccounts();
  List<Category> cats = defaultCats();
  Map<int, Map<String, MonthData>> data = {};
  Map<String, bool> collapsed = {};
  String? swipedId;
  String? toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- boot
  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSaved = prefs.getString(kStorageKey);
    if (rawSaved != null) {
      try {
        _restore(json.decode(rawSaved) as Map<String, dynamic>);
        setState(() => ready = true);
        return;
      } catch (_) {/* fall through to seed */}
    }
    await _seedFromAsset();
  }

  void _restore(Map<String, dynamic> saved) {
    year = (saved['year'] as num?)?.toInt() ?? 2026;
    monthIdx = (saved['monthIdx'] as num?)?.toInt() ?? 5;
    screen = (saved['screen'] ?? 'overview').toString();
    if (saved['accounts'] is List) {
      accounts = [
        for (final a in (saved['accounts'] as List))
          Account.fromJson(Map<String, dynamic>.from(a as Map)),
      ];
    }
    if (saved['cats'] is List) {
      cats = [
        for (final c in (saved['cats'] as List))
          Category.fromJson(Map<String, dynamic>.from(c as Map)),
      ];
    }
    data = {};
    (saved['data'] as Map<String, dynamic>? ?? {}).forEach((yr, months) {
      final yKey = int.tryParse(yr) ?? year;
      final map = <String, MonthData>{};
      (months as Map<String, dynamic>).forEach((mk, md) {
        map[mk] = MonthData.fromJson(Map<String, dynamic>.from(md as Map));
      });
      data[yKey] = map;
    });
  }

  Future<void> _seedFromAsset() async {
    Map<String, dynamic> raw = {};
    try {
      final text = await rootBundle.loadString('assets/data/budget.json');
      raw = json.decode(text) as Map<String, dynamic>;
    } catch (_) {/* empty seed */}
    final seededCats = defaultCats();
    final yearMap = <String, MonthData>{};
    for (final mk in kMonthKeys) {
      final month = MonthData();
      for (final c in seededCats) {
        month.blocks[c.key] = [];
      }
      final m = raw[mk] as Map<String, dynamic>?;
      if (m != null) {
        for (final it in (m['income'] as List? ?? [])) {
          final map = Map<String, dynamic>.from(it as Map);
          month.income.add(
            IncomeItem(
              id: uid(),
              label: (map['label'] ?? '').toString(),
              expected: parseNum(map['expected']),
              actual: parseNum(map['actual']),
              received: map['received'] == true,
              account: accForLabel(map['label']?.toString()),
            ),
          );
        }
        for (final c in seededCats) {
          for (final it in (m[c.key] as List? ?? [])) {
            final map = Map<String, dynamic>.from(it as Map);
            month.blocks[c.key]!.add(
              ExpenseItem(
                id: uid(),
                label: (map['label'] ?? '').toString(),
                marker: markerShow(map['day'] ?? map['date']),
                amount: parseNum(map['amount']),
                paid: map['paid'] == true,
                account: accForLabel(map['label']?.toString()),
                until: map['until'],
              ),
            );
          }
        }
      }
      yearMap[mk] = month;
    }
    // Sample limits so the feature is visible.
    yearMap['Juli']?.caps.addAll({'food': 850, 'personal': 700, 'additional': 1600});
    yearMap['Juni']?.caps.addAll({'food': 800});

    setState(() {
      cats = seededCats;
      data = {2026: yearMap};
      ready = true;
    });
    _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'year': year,
      'monthIdx': monthIdx,
      'screen': screen,
      'accounts': accounts.map((a) => a.toJson()).toList(),
      'cats': cats.map((c) => c.toJson()).toList(),
      'data': {
        for (final entry in data.entries)
          entry.key.toString(): {
            for (final m in entry.value.entries) m.key: m.value.toJson(),
          },
      },
    };
    await prefs.setString(kStorageKey, json.encode(payload));
  }

  // ------------------------------------------------------------- helpers
  void update(VoidCallback fn) => setState(fn);

  void mutate(VoidCallback fn, [VoidCallback? cb]) {
    setState(fn);
    _persist();
    cb?.call();
  }

  void flash(String msg) {
    setState(() => toast = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2100), () {
      if (mounted) setState(() => toast = null);
    });
  }

  MonthData? cur() => data[year]?[kMonthKeys[monthIdx]];

  void ensureYear(int yr) {
    if (!data.containsKey(yr)) {
      final map = <String, MonthData>{};
      for (final mk in kMonthKeys) {
        final month = MonthData();
        for (final c in cats) {
          month.blocks[c.key] = [];
        }
        map[mk] = month;
      }
      data[yr] = map;
    }
  }

  Account accByKey(String k) =>
      accounts.firstWhere((a) => a.key == k, orElse: () => accounts.last);

  Category? catByKey(String k) {
    for (final c in cats) {
      if (c.key == k) return c;
    }
    return null;
  }

  List<Category> catsForMonth(int mIdx, [int? yr]) {
    yr ??= year;
    final m = data[yr]?[kMonthKeys[mIdx]];
    if (m != null && m.closed && m.catsSnapshot != null) {
      return m.catsSnapshot!;
    }
    return cats
        .where((c) =>
            !c.temporary || (c.ownerYear == yr && c.ownerMonthIdx == mIdx))
        .toList();
  }

  List<Account> accountsForMonth(int mIdx, [int? yr]) {
    yr ??= year;
    final m = data[yr]?[kMonthKeys[mIdx]];
    if (m != null && m.closed && m.accountsSnapshot != null) {
      return m.accountsSnapshot!;
    }
    return accounts;
  }

  bool isClosed([int? mIdx, int? yr]) {
    yr ??= year;
    final m = data[yr]?[kMonthKeys[mIdx ?? monthIdx]];
    return m?.closed ?? false;
  }

  void closeMonth() {
    mutate(() {
      final m = data[year]![kMonthKeys[monthIdx]]!;
      m.closed = true;
      m.catsSnapshot = catsForMonth(monthIdx, year).map((c) => c.copy()).toList();
      m.accountsSnapshot = accounts.map((a) => a.copy()).toList();
    }, () => flash('Month closed'));
  }

  void reopenMonth() {
    mutate(() {
      final m = data[year]![kMonthKeys[monthIdx]]!;
      m.closed = false;
      m.catsSnapshot = null;
      m.accountsSnapshot = null;
    }, () => flash('Month reopened'));
  }

  void setYear(int y) {
    ensureYear(y);
    setState(() => year = y);
    _persist();
  }

  void moveAccount(String key, int dir) {
    final i = accounts.indexWhere((a) => a.key == key);
    final j = i + dir;
    if (j < 0 || j >= accounts.length) return;
    setState(() {
      final t = accounts[i];
      accounts[i] = accounts[j];
      accounts[j] = t;
    });
    _persist();
  }

  void moveBlock(String key, int dir) {
    final i = cats.indexWhere((c) => c.key == key);
    final j = i + dir;
    if (j < 0 || j >= cats.length) return;
    setState(() {
      final t = cats[i];
      cats[i] = cats[j];
      cats[j] = t;
    });
    _persist();
  }

  // ---------------------------------------------------------------- nav
  void go(String s) {
    setState(() {
      screen = s;
      swipedId = null;
    });
    _persist();
  }

  void setMonth(int d) {
    setState(() {
      monthIdx = (monthIdx + d + 12) % 12;
      swipedId = null;
    });
    _persist();
  }

  void pickMonth(int i) {
    setState(() {
      monthIdx = i;
      swipedId = null;
    });
    _persist();
  }

  void toggleCollapse(String k) =>
      setState(() => collapsed[k] = !(collapsed[k] ?? false));

  // ------------------------------------------------------------ toggles
  void togglePaid(String catKey, String id) {
    if (isClosed()) return;
    mutate(() {
      final arr = data[year]![kMonthKeys[monthIdx]]!.blocks[catKey];
      final it = arr?.firstWhere((x) => x.id == id, orElse: () => arr.first);
      if (it != null && arr!.any((x) => x.id == id)) it.paid = !it.paid;
    });
  }

  void toggleReceived(String id) {
    if (isClosed()) return;
    mutate(() {
      final arr = data[year]![kMonthKeys[monthIdx]]!.income;
      for (final it in arr) {
        if (it.id == id) it.received = !it.received;
      }
    });
  }

  // --------------------------------------------------------------- delete confirm
  void askDelete(String name, String message, VoidCallback onConfirm) {
    setState(() => swipedId = null);
    showDialog<void>(
      context: context,
      barrierColor: const Color(0x80101828),
      builder: (ctx) => _ConfirmDialog(
        name: name,
        message: message,
        onCancel: () => Navigator.of(ctx).pop(),
        onDelete: () {
          Navigator.of(ctx).pop();
          onConfirm();
        },
      ),
    );
  }

  // -------------------------------------------------------------- compute
  _Compute compute(int mIdx) {
    final m = data[year]?[kMonthKeys[mIdx]] ?? MonthData();
    final expIncome = m.income.fold<double>(0, (a, b) => a + b.expected);
    final realIncome =
        m.income.fold<double>(0, (a, b) => a + (b.received ? b.actual : 0));
    final actIncome = m.income.fold<double>(0, (a, b) => a + b.actual);

    double totalBudget = 0, totalPaid = 0;
    final blocks = <_BlockCompute>[];
    final acctTotals = <String, double>{};
    final accts = accountsForMonth(mIdx);
    for (final a in accts) {
      acctTotals[a.key] = 0;
    }
    for (final c in catsForMonth(mIdx)) {
      final items = m.blocks[c.key] ?? const <ExpenseItem>[];
      double bud = 0, paid = 0;
      final rows = <_RowCompute>[];
      for (final it in items) {
        final amt = it.amount;
        bud += amt;
        if (it.paid) {
          paid += amt;
        } else {
          acctTotals[it.account] = (acctTotals[it.account] ?? 0) + amt;
        }
        final ul = c.hasUntil ? untilLabel(it.until) : null;
        rows.add(_RowCompute(
          item: it,
          untilLabel: ul,
          untilState: ul != null ? untilState(ul, mIdx, year) : UntilState.future,
        ));
      }
      totalBudget += bud;
      totalPaid += paid;
      final cap = m.caps[c.key];
      blocks.add(_BlockCompute(
        key: c.key,
        title: c.title,
        icon: c.icon,
        tone: c.tone,
        bg: c.bg,
        hasUntil: c.hasUntil,
        items: rows,
        total: bud,
        paid: paid,
        cap: cap,
        count: items.length,
      ));
    }
    final stillToPay = math.max(0, totalBudget - totalPaid).toDouble();
    return _Compute(
      monthIdx: mIdx,
      expIncome: expIncome,
      realIncome: realIncome,
      actIncome: actIncome,
      blocks: blocks,
      totalBudget: totalBudget,
      totalPaid: totalPaid,
      stillToPay: stillToPay,
      expectedBalance: expIncome - totalBudget,
      balance: realIncome - totalBudget,
      acctTotals: acctTotals,
      accounts: accts,
      closed: isClosed(mIdx),
      income: m.income,
    );
  }

  // =============================================================== build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: B.page,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ready
                      ? _buildBody()
                      : const Center(
                          child: Text(
                            'Loading budget…',
                            style: TextStyle(
                              color: B.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
              ],
            ),
            if (toast != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 36,
                child: Center(child: _buildToast()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToast() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: B.ink,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .4),
            blurRadius: 28,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ic('check', size: 14, sw: 2.8, color: const Color(0xff4ade80)),
          const SizedBox(width: 7),
          Text(
            toast ?? '',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (screen) {
      case 'stats':
        return _buildStats();
      case 'settings':
        return _buildSettings();
      default:
        return _buildOverview();
    }
  }

  // ------------------------------------------------------------- header
  Widget _buildHeader() {
    final titles = <String, List<String>>{
      'overview': ['Overview', '${kMonthsEn[monthIdx]} $year'],
      'stats': [
        'Statistics',
        statsMode == 'month'
            ? '${kMonthsEn[monthIdx]} $year'
            : 'Full year $year',
      ],
      'settings': ['Settings', 'Accounts, blocks & tools'],
    };
    final title = ready ? titles[screen]![0] : 'Thrive';
    final subtitle = ready ? titles[screen]![1] : 'Loading…';

    return Container(
      color: B.page,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: B.grad,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff0F8A76).withValues(alpha: .6),
                      blurRadius: 14,
                      spreadRadius: -3,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(child: logoMark(size: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.3,
                        color: B.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: B.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _buildSwitcher(),
            ],
          ),
          if (ready && screen != 'settings') ...[
            const SizedBox(height: 13),
            _buildSubHeader(),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitcher() {
    Widget tab(String k, String icon) {
      final active = screen == k;
      return GestureDetector(
        onTap: () => go(k),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 34,
          height: 30,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .14),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: ic(icon,
                size: 17,
                sw: 2.1,
                color: active ? B.primary : const Color(0xff8995a6)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xffe8ecf2),
        borderRadius: BorderRadius.circular(13),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tab('overview', 'grid'),
          const SizedBox(width: 4),
          tab('stats', 'chart'),
          const SizedBox(width: 4),
          tab('settings', 'gear'),
        ],
      ),
    );
  }

  Widget _buildSubHeader() {
    Widget arrow(int d, String name) => GestureDetector(
          onTap: () => setMonth(d),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: B.line),
            ),
            child: Center(child: ic(name, size: 17, sw: 2.4, color: B.soft2)),
          ),
        );

    final monthChip = GestureDetector(
      onTap: openMonthPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: B.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ic('cal', size: 15, sw: 2.2, color: B.primary),
            const SizedBox(width: 7),
            Text(
              '${kMonthsEn[monthIdx]} $year',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: B.ink,
              ),
            ),
            const SizedBox(width: 7),
            ic('cdown', size: 14, sw: 2.4, color: B.muted),
          ],
        ),
      ),
    );

    final left = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        arrow(-1, 'cleft'),
        const SizedBox(width: 8),
        monthChip,
        const SizedBox(width: 8),
        arrow(1, 'cright'),
      ],
    );

    if (screen == 'overview') {
      final closed = isClosed();
      final lockBtn = GestureDetector(
        onTap: () => closed ? reopenMonth() : openCloseConfirm(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: closed ? B.ink : Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: closed ? B.ink : B.line),
          ),
          child: Center(
            child: ic(closed ? 'lock' : 'unlock',
                size: 16, sw: 2.2, color: closed ? Colors.white : B.soft2),
          ),
        ),
      );
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [left, lockBtn],
      );
    }

    // stats: month strip + month/year toggle
    Widget seg(String label, String val) {
      final active = statsMode == val;
      return GestureDetector(
        onTap: () => setState(() => statsMode = val),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .12),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: active ? B.primary : const Color(0xff8995a6),
            ),
          ),
        ),
      );
    }

    final toggle = Container(
      decoration: BoxDecoration(
        color: const Color(0xffe8ecf2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('Month', 'month'), seg('Year', 'year')],
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [left, toggle],
    );
  }
}

// ====================================================== compute records
class _Compute {
  _Compute({
    required this.monthIdx,
    required this.expIncome,
    required this.realIncome,
    required this.actIncome,
    required this.blocks,
    required this.totalBudget,
    required this.totalPaid,
    required this.stillToPay,
    required this.expectedBalance,
    required this.balance,
    required this.acctTotals,
    required this.accounts,
    required this.closed,
    required this.income,
  });

  final int monthIdx;
  final double expIncome, realIncome, actIncome;
  final List<_BlockCompute> blocks;
  final double totalBudget, totalPaid, stillToPay, expectedBalance, balance;
  final Map<String, double> acctTotals;
  final List<Account> accounts;
  final bool closed;
  final List<IncomeItem> income;
}

class _BlockCompute {
  _BlockCompute({
    required this.key,
    required this.title,
    required this.icon,
    required this.tone,
    required this.bg,
    required this.hasUntil,
    required this.items,
    required this.total,
    required this.paid,
    required this.cap,
    required this.count,
  });

  final String key, title, icon;
  final Color tone, bg;
  final bool hasUntil;
  final List<_RowCompute> items;
  final double total, paid;
  final double? cap;
  final int count;
}

class _RowCompute {
  _RowCompute({
    required this.item,
    required this.untilLabel,
    required this.untilState,
  });

  final ExpenseItem item;
  final String? untilLabel;
  final UntilState untilState;
}

// ================================================== confirm dialog widget
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.name,
    required this.message,
    required this.onCancel,
    required this.onDelete,
  });

  final String name;
  final String message;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(26),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 312),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: B.redSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(child: ic('trash', size: 23, sw: 2.2, color: B.red)),
            ),
            const SizedBox(height: 15),
            Text(
              'Delete ${name.isNotEmpty ? '\u201C$name\u201D' : 'this'}?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
                color: B.ink,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: B.soft2,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 19),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: B.line),
                      ),
                      child: const Text(
                        'Cancel',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: B.text,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: B.red,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Text(
                        'Delete',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
