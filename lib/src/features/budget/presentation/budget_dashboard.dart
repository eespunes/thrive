part of 'package:family_money_management_app/main.dart';

class BudgetDashboard extends StatefulWidget {
  const BudgetDashboard({super.key});

  @override
  State<BudgetDashboard> createState() => _BudgetDashboardState();
}

class _BudgetDashboardState extends State<BudgetDashboard> {
  final Map<int, Map<String, MonthBudget>> _yearMonths = {};
  SharedPreferences? _prefs;
  int _year = 2026;
  int _monthIndex = 5;
  bool _forcePhonePreview = false;
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

  void _setMonth(int delta) {
    setState(
      () => _monthIndex =
          (_monthIndex + delta + monthKeys.length) % monthKeys.length,
    );
    unawaited(_persistState());
  }

  void _setYear(int delta) {
    setState(() {
      _year += delta;
      _yearMonths.putIfAbsent(_year, () => emptyYearBudget(_year));
    });
    unawaited(_persistState());
  }

  void _toggleIncome(String id) {
    setState(() {
      final row = _month.income.firstWhere((item) => item.id == id);
      row.received = !row.received;
    });
    unawaited(_persistState());
  }

  void _setIncomeAccount(String id, String accountKey) {
    setState(() {
      final row = _month.income.firstWhere((item) => item.id == id);
      row.accountKey = accountKey;
    });
    unawaited(_persistState());
  }

  void _updateIncome(String id, IncomeUpdate update) {
    setState(() {
      final row = _month.income.firstWhere((item) => item.id == id);
      row.expected = update.expected;
      row.actual = update.actual;
      row.received = update.received;
      row.accountKey = update.accountKey;
    });
    unawaited(_persistState());
  }

  void _deleteIncome(String id) {
    setState(() {
      _month.income.removeWhere((item) => item.id == id);
    });
    unawaited(_persistState());
  }

  void _toggleExpense(String categoryKey, String id) {
    setState(() {
      final row = _month.expenses[categoryKey]!.firstWhere(
        (item) => item.id == id,
      );
      row.paid = !row.paid;
    });
    unawaited(_persistState());
  }

  void _setExpenseAccount(String categoryKey, String id, String accountKey) {
    setState(() {
      final row = _month.expenses[categoryKey]!.firstWhere(
        (item) => item.id == id,
      );
      row.accountKey = accountKey;
    });
    unawaited(_persistState());
  }

  void _updateExpenseItem(String categoryKey, String id, ExpenseUpdate update) {
    setState(() {
      final row = _month.expenses[categoryKey]!.firstWhere(
        (item) => item.id == id,
      );
      row.amount = update.amount;
      row.marker = update.marker;
      row.paid = update.paid;
      row.accountKey = update.accountKey;
      row.untilRaw = update.until;
    });
    unawaited(_persistState());
  }

  void _deleteExpenseItem(String categoryKey, String id) {
    setState(() {
      _month.expenses[categoryKey]?.removeWhere((item) => item.id == id);
    });
    unawaited(_persistState());
  }

  void _deleteBudgetBlock(String categoryKey) {
    setState(() {
      categoryMeta.removeWhere((meta) => meta.key == categoryKey);
      for (final month in _allMonths) {
        month.expenses.remove(categoryKey);
      }
    });
    unawaited(_persistState());
  }

  void _deleteAccount(String accountKey) {
    if (accountMeta.length <= 1) return;
    final fallback = accountMeta.firstWhere(
      (account) => account.key != accountKey,
    );
    setState(() {
      accountMeta.removeWhere((account) => account.key == accountKey);
      for (final month in _allMonths) {
        for (final income in month.income) {
          if (income.accountKey == accountKey) income.accountKey = fallback.key;
        }
        for (final items in month.expenses.values) {
          for (final item in items) {
            if (item.accountKey == accountKey) item.accountKey = fallback.key;
          }
        }
      }
    });
    unawaited(_persistState());
  }

  void _saveExpense(QuickExpense expense) {
    setState(() {
      final list = _month.expenses[expense.categoryKey]!;
      if (expense.itemId == QuickEntrySheet.newItemId) {
        list.add(
          ExpenseItem(
            id: '${_month.key}-${expense.categoryKey}-new-${DateTime.now().millisecondsSinceEpoch}',
            label: expense.label.trim().isEmpty
                ? 'NEW EXPENSE'
                : expense.label.trim().toUpperCase(),
            marker: expense.marker,
            amount: expense.amount,
            paid: true,
            accountKey: expense.accountKey,
            untilRaw: expense.until,
          ),
        );
      } else {
        final row = list.firstWhere((item) => item.id == expense.itemId);
        row.amount += expense.amount;
        row.marker = expense.marker;
        row.paid = true;
        row.accountKey = expense.accountKey;
        row.untilRaw = expense.until ?? row.untilRaw;
      }
    });
    unawaited(_persistState());
  }

  void _saveIncome(NewIncome income) {
    setState(() {
      _month.income.add(
        IncomeItem(
          id: '${_month.key}-income-new-${DateTime.now().millisecondsSinceEpoch}',
          label: income.label.trim().isEmpty
              ? 'NEW INCOME'
              : income.label.trim().toUpperCase(),
          expected: income.expected,
          actual: income.actual,
          received: income.received,
          accountKey: income.accountKey,
        ),
      );
    });
    unawaited(_persistState());
  }

  Future<void> _openCreateAccount(BuildContext context) async {
    final name = await _openNameSheet(
      context,
      title: 'New account',
      subtitle: 'Add a source or spending account',
      label: 'Account name',
      actionLabel: 'Create account',
      hint: 'e.g. Savings account',
    );
    if (name == null) return;

    setState(() {
      accountMeta.add(
        AccountMeta(
          key: uniqueKeyFor(name, accountMeta.map((account) => account.key)),
          name: name,
          shortName: shortNameFor(name),
          initials: initialsFor(name),
          color: accountPalette[accountMeta.length % accountPalette.length],
        ),
      );
    });
    unawaited(_persistState());
  }

  Future<void> _openCreateBudgetBlock(BuildContext context) async {
    final title = await _openNameSheet(
      context,
      title: 'New budget block',
      subtitle: 'Create a new budget category',
      label: 'Block name',
      actionLabel: 'Create block',
      hint: 'e.g. Transport',
    );
    if (title == null) return;

    setState(() {
      final key = uniqueKeyFor(title, categoryMeta.map((meta) => meta.key));
      categoryMeta.add(
        CategoryMeta(
          key: key,
          title: title,
          icon: Icons.folder_rounded,
          markerKey: 'date',
          tone: blockPalette[categoryMeta.length % blockPalette.length],
          background: AppColors.panel,
        ),
      );
      for (final month in _allMonths) {
        month.expenses.putIfAbsent(key, () => <ExpenseItem>[]);
      }
    });
    unawaited(_persistState());
  }

  void _copyMonth(CopyMonthSelection selection) {
    final sourceKey = monthKeys[selection.sourceMonthIndex];
    final targetKey = monthKeys[selection.targetMonthIndex];
    final source = _months[sourceKey];
    if (source == null ||
        selection.sourceMonthIndex == selection.targetMonthIndex) {
      return;
    }

    setState(() {
      _months[targetKey] = MonthBudget.fromJson(targetKey, source.toJson());
      _monthIndex = selection.targetMonthIndex;
    });
    unawaited(_persistState());
  }

  Future<void> _openCopyMonth(BuildContext context) async {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final result = compact
        ? await showModalBottomSheet<CopyMonthSelection>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) =>
                CopyMonthSheet(currentMonthIndex: _monthIndex, year: _year),
          )
        : await showDialog<CopyMonthSelection>(
            context: context,
            builder: (_) => Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: CopyMonthSheet(
                  currentMonthIndex: _monthIndex,
                  year: _year,
                ),
              ),
            ),
          );

    if (result != null && context.mounted) {
      _copyMonth(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied ${monthLabels[result.sourceMonthIndex]} $_year to ${monthLabels[result.targetMonthIndex]} $_year',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (settingsContext) => SettingsScreen(
          monthLabel: monthLabels[_monthIndex],
          year: _year,
          onCopyMonth: () => _openCopyMonth(settingsContext),
        ),
      ),
    );
  }

  Future<void> _openStatistics(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatisticsScreen(
          year: _year,
          monthIndex: _monthIndex,
          months: _months,
        ),
      ),
    );
  }

  Future<String?> _openNameSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String label,
    required String actionLabel,
    required String hint,
  }) async {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final sheet = NameEntrySheet(
      title: title,
      subtitle: subtitle,
      label: label,
      actionLabel: actionLabel,
      hint: hint,
    );
    return compact
        ? showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => sheet,
          )
        : showDialog<String>(
            context: context,
            builder: (_) => Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: sheet,
              ),
            ),
          );
  }

  Future<void> _openIncomeEdit(BuildContext context, IncomeItem income) async {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final sheet = IncomeEditSheet(income: income);
    final result = compact
        ? await showModalBottomSheet<IncomeUpdate>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => sheet,
          )
        : await showDialog<IncomeUpdate>(
            context: context,
            builder: (_) => Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: sheet,
              ),
            ),
          );
    if (result != null) {
      _updateIncome(income.id, result);
    }
  }

  Future<void> _openExpenseEdit(
    BuildContext context,
    CategoryMeta meta,
    ExpenseItem item,
  ) async {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final sheet = ExpenseEditSheet(meta: meta, item: item);
    final result = compact
        ? await showModalBottomSheet<ExpenseUpdate>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => sheet,
          )
        : await showDialog<ExpenseUpdate>(
            context: context,
            builder: (_) => Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: sheet,
              ),
            ),
          );
    if (result != null) {
      _updateExpenseItem(meta.key, item.id, result);
    }
  }

  Future<void> _openQuickEntry(BuildContext context) async {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final result = compact
        ? await showModalBottomSheet<QuickExpense>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => QuickEntrySheet(month: _month),
          )
        : await showDialog<QuickExpense>(
            context: context,
            builder: (_) => Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 440,
                  maxHeight: 700,
                ),
                child: QuickEntrySheet(month: _month),
              ),
            ),
          );

    if (result != null) {
      _saveExpense(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged ${formatEuro(result.amount)}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openIncomeEntry(BuildContext context) async {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final result = compact
        ? await showModalBottomSheet<NewIncome>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const IncomeEntrySheet(),
          )
        : await showDialog<NewIncome>(
            context: context,
            builder: (_) => Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: const IncomeEntrySheet(),
              ),
            ),
          );

    if (result != null) {
      _saveIncome(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added income ${formatEuro(result.actual)}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenIsCompact = constraints.maxWidth < 860;
        final phoneMode = screenIsCompact || _forcePhonePreview;
        final computed = ComputedMonth(_month, _monthIndex, _year);

        return Scaffold(
          body: Column(
            children: [
              if (phoneMode)
                MobileMonthHeader(
                  monthLabel: monthLabels[_monthIndex],
                  year: _year,
                  onPrev: () => _setMonth(-1),
                  onNext: () => _setMonth(1),
                  onPrevYear: () => _setYear(-1),
                  onNextYear: () => _setYear(1),
                )
              else
                AppToolbar(
                  monthLabel: monthLabels[_monthIndex],
                  year: _year,
                  phoneMode: phoneMode,
                  previewToggleEnabled: !screenIsCompact,
                  onPrev: () => _setMonth(-1),
                  onNext: () => _setMonth(1),
                  onPrevYear: () => _setYear(-1),
                  onNextYear: () => _setYear(1),
                  onDashboard: () => setState(() => _forcePhonePreview = false),
                  onPhone: () => setState(() => _forcePhonePreview = true),
                  onLogExpense: () => _openQuickEntry(context),
                  onCreateAccount: () => _openCreateAccount(context),
                  onCreateBudgetBlock: () => _openCreateBudgetBlock(context),
                  onOpenStatistics: () => _openStatistics(context),
                  onOpenSettings: () => _openSettings(context),
                ),
              Expanded(
                child: phoneMode
                    ? MobileBudgetView(
                        computed: computed,
                        onToggleExpense: _toggleExpense,
                        onSetExpenseAccount: _setExpenseAccount,
                        onEditExpenseItem: (meta, item) =>
                            _openExpenseEdit(context, meta, item),
                        onDeleteExpenseItem: _deleteExpenseItem,
                        onDeleteBudgetBlock: _deleteBudgetBlock,
                        onDeleteAccount: _deleteAccount,
                        onToggleIncome: _toggleIncome,
                        onSetIncomeAccount: _setIncomeAccount,
                        onEditIncome: (income) =>
                            _openIncomeEdit(context, income),
                        onDeleteIncome: _deleteIncome,
                        onAddIncome: () => _openIncomeEntry(context),
                        onLogExpense: () => _openQuickEntry(context),
                        onCreateAccount: () => _openCreateAccount(context),
                        onCreateBudgetBlock: () =>
                            _openCreateBudgetBlock(context),
                        onOpenStatistics: () => _openStatistics(context),
                        onOpenSettings: () => _openSettings(context),
                      )
                    : DesktopBudgetView(
                        computed: computed,
                        onToggleIncome: _toggleIncome,
                        onSetIncomeAccount: _setIncomeAccount,
                        onEditIncome: (income) =>
                            _openIncomeEdit(context, income),
                        onDeleteIncome: _deleteIncome,
                        onAddIncome: () => _openIncomeEntry(context),
                        onToggleExpense: _toggleExpense,
                        onSetExpenseAccount: _setExpenseAccount,
                        onEditExpenseItem: (meta, item) =>
                            _openExpenseEdit(context, meta, item),
                        onDeleteExpenseItem: _deleteExpenseItem,
                        onDeleteBudgetBlock: _deleteBudgetBlock,
                        onDeleteAccount: _deleteAccount,
                      ),
              ),
            ],
          ),
          floatingActionButton: phoneMode
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openQuickEntry(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Log expense'),
                ),
        );
      },
    );
  }
}
