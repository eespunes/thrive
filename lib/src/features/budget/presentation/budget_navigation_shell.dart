part of 'package:family_money_management_app/main.dart';

class BudgetNavigationShell extends StatefulWidget {
  const BudgetNavigationShell({super.key});

  @override
  State<BudgetNavigationShell> createState() => _BudgetNavigationShellState();
}

class _BudgetNavigationShellState extends State<BudgetNavigationShell> {
  final Map<int, Map<String, MonthBudget>> _yearMonths = {};
  SharedPreferences? _prefs;
  int _year = 2026;
  int _monthIndex = 5;
  int _currentTabIndex = 0;
  bool _loading = true;

  Map<String, MonthBudget> get _months =>
      _yearMonths.putIfAbsent(_year, () => emptyYearBudget(_year));
  MonthBudget get _month => _months[monthKeys[_monthIndex]]!;
  Iterable<MonthBudget> get _allMonths =>
      _yearMonths.values.expand((months) => months.values);

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs?.getString(savedStateKey);
    if (saved != null) {
      try {
        _restoreState(jsonDecode(saved) as Map<String, dynamic>);
        setState(() => _loading = false);
        return;
      } catch (_) {
        await _prefs?.remove(savedStateKey);
      }
    }

    final source = await rootBundle.loadString('assets/data/budget.json');
    final raw = jsonDecode(source) as Map<String, dynamic>;
    final initialYear = <String, MonthBudget>{};
    for (final key in monthKeys) {
      final value = raw[key];
      if (value is Map<String, dynamic>) {
        initialYear[key] = MonthBudget.fromJson(key, value);
      }
    }
    _yearMonths[2026] = initialYear;
    setState(() => _loading = false);
  }

  void _restoreState(Map<String, dynamic> state) {
    accountMeta
      ..clear()
      ..addAll(
        ((state['accounts'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(AccountMeta.fromState),
      );
    if (accountMeta.isEmpty) {
      accountMeta.addAll(defaultAccountMeta);
    }

    categoryMeta
      ..clear()
      ..addAll(
        ((state['categories'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CategoryMeta.fromState),
      );
    if (categoryMeta.isEmpty) {
      categoryMeta.addAll(defaultCategoryMeta);
    }

    _yearMonths.clear();
    final yearState = state['years'];
    if (yearState is Map<String, dynamic>) {
      for (final entry in yearState.entries) {
        final year = int.tryParse(entry.key);
        final months = entry.value;
        if (year == null || months is! Map<String, dynamic>) continue;
        _yearMonths[year] = monthsFromState(months);
      }
    } else {
      final monthState = state['months'] as Map<String, dynamic>? ?? {};
      _yearMonths[2026] = monthsFromState(monthState);
    }
    if (_yearMonths.isEmpty) {
      _yearMonths[2026] = emptyYearBudget(2026);
    }
    _year = (state['year'] as num?)?.toInt() ?? 2026;
    _monthIndex = (state['monthIndex'] as num?)?.toInt().clamp(0, 11) ?? 5;
  }

  Future<void> _persistState() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(savedStateKey, jsonEncode(_stateJson()));
  }

  Map<String, dynamic> _stateJson() {
    return {
      'accounts': [for (final account in accountMeta) account.toState()],
      'categories': [for (final category in categoryMeta) category.toState()],
      'year': _year,
      'monthIndex': _monthIndex,
      'years': {
        for (final yearEntry in _yearMonths.entries)
          yearEntry.key.toString(): {
            for (final entry in yearEntry.value.entries)
              entry.key: entry.value.toJson(),
          },
      },
    };
  }

  void _closeMonth(bool close) {
    setState(() {
      _month.isClosed = close;
    });
    unawaited(_persistState());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final computed = ComputedMonth(_month, _monthIndex, _year);

    final tabs = [
      Container(color: Colors.blue, child: const Center(child: Text('Overview'))),
      Container(color: Colors.green, child: const Center(child: Text('Statistics'))),
      Container(color: Colors.orange, child: const Center(child: Text('Settings'))),
    ];

    return Scaffold(
      body: tabs[_currentTabIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Statistics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
