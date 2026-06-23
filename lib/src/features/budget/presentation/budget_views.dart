part of 'package:family_money_management_app/main.dart';

class DesktopBudgetView extends StatelessWidget {
  const DesktopBudgetView({
    super.key,
    required this.computed,
    required this.onToggleIncome,
    required this.onSetIncomeAccount,
    required this.onEditIncome,
    required this.onDeleteIncome,
    required this.onAddIncome,
    required this.onToggleExpense,
    required this.onSetExpenseAccount,
    required this.onEditExpenseItem,
    required this.onDeleteExpenseItem,
    required this.onDeleteBudgetBlock,
    required this.onDeleteAccount,
  });

  final ComputedMonth computed;
  final ValueChanged<String> onToggleIncome;
  final void Function(String id, String accountKey) onSetIncomeAccount;
  final ValueChanged<IncomeItem> onEditIncome;
  final ValueChanged<String> onDeleteIncome;
  final VoidCallback onAddIncome;
  final void Function(String categoryKey, String id) onToggleExpense;
  final void Function(String categoryKey, String id, String accountKey)
  onSetExpenseAccount;
  final void Function(CategoryMeta meta, ExpenseItem item) onEditExpenseItem;
  final void Function(String categoryKey, String id) onDeleteExpenseItem;
  final ValueChanged<String> onDeleteBudgetBlock;
  final ValueChanged<String> onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BUDGET BREAKDOWN',
                          style: labelStyle.copyWith(letterSpacing: 1.4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${computed.monthLabel} ${computed.year}',
                          style: const TextStyle(
                            fontSize: 31,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    children: [
                      KpiCard(
                        label: 'Income',
                        value: formatEuro(computed.realIncome, cents: false),
                        icon: Icons.arrow_downward_rounded,
                        tone: AppColors.green,
                      ),
                      KpiCard(
                        label: 'Expenses',
                        value: formatEuro(computed.totalBudget, cents: false),
                        icon: Icons.arrow_upward_rounded,
                        tone: AppColors.red,
                      ),
                      KpiCard(
                        label: 'Still to pay',
                        value: formatEuro(computed.stillToPay, cents: false),
                        icon: Icons.schedule_rounded,
                        tone: AppColors.amber,
                      ),
                      KpiCard(
                        label: 'Balance',
                        value: formatEuro(computed.balance, cents: false),
                        icon: Icons.monitor_heart_rounded,
                        tone: computed.balance >= 0
                            ? AppColors.green
                            : AppColors.red,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        IncomeCard(
                          computed: computed,
                          onToggle: onToggleIncome,
                          onSetAccount: onSetIncomeAccount,
                          onEdit: onEditIncome,
                          onDelete: onDeleteIncome,
                          onAddIncome: onAddIncome,
                        ),
                        const SizedBox(height: 16),
                        BudgetGrid(
                          computed: computed,
                          onToggleExpense: onToggleExpense,
                          onSetExpenseAccount: onSetExpenseAccount,
                          onEditExpenseItem: onEditExpenseItem,
                          onDeleteExpenseItem: onDeleteExpenseItem,
                          onDeleteBudgetBlock: onDeleteBudgetBlock,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 364,
                    child: Column(
                      children: [
                        SumUpCard(
                          computed: computed,
                          onDeleteAccount: onDeleteAccount,
                        ),
                        const SizedBox(height: 16),
                        BreakdownCard(computed: computed),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({
    super.key,
    required this.year,
    required this.monthIndex,
    required this.months,
  });

  final int year;
  final int monthIndex;
  final Map<String, MonthBudget> months;

  @override
  Widget build(BuildContext context) {
    final currentMonth =
        months[monthKeys[monthIndex]] ??
        MonthBudget.empty(monthKeys[monthIndex]);
    final current = ComputedMonth(currentMonth, monthIndex, year);
    final yearMonths = [
      for (var i = 0; i < monthKeys.length; i++)
        ComputedMonth(
          months[monthKeys[i]] ?? MonthBudget.empty(monthKeys[i]),
          i,
          year,
        ),
    ];
    final yearly = YearlyStatistics(yearMonths);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.page,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Statistics',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          Text(
                            '${current.monthLabel} $year',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: AppColors.ink,
                    unselectedLabelColor: AppColors.muted,
                    labelStyle: TextStyle(fontWeight: FontWeight.w900),
                    tabs: [
                      Tab(text: 'Monthly'),
                      Tab(text: 'Yearly'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    MonthlyStatisticsView(computed: current),
                    YearlyStatisticsView(statistics: yearly),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MonthlyStatisticsView extends StatelessWidget {
  const MonthlyStatisticsView({super.key, required this.computed});

  final ComputedMonth computed;

  @override
  Widget build(BuildContext context) {
    final blocks =
        computed.blocks.values.where((block) => block.total > 0).toList()
          ..sort((a, b) => b.total.compareTo(a.total));
    final topBlock = blocks.isEmpty ? null : blocks.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            KpiCard(
              label: 'Income',
              value: formatEuro(computed.realIncome, cents: false),
              icon: Icons.arrow_downward_rounded,
              tone: AppColors.green,
            ),
            KpiCard(
              label: 'Expenses',
              value: formatEuro(computed.totalBudget, cents: false),
              icon: Icons.arrow_upward_rounded,
              tone: AppColors.red,
            ),
            KpiCard(
              label: 'Balance',
              value: formatEuro(computed.balance, cents: false),
              icon: Icons.monitor_heart_rounded,
              tone: computed.balance >= 0 ? AppColors.green : AppColors.red,
            ),
            KpiCard(
              label: 'Paid',
              value:
                  '${computed.totalBudget == 0 ? 0 : ((computed.totalPaid / computed.totalBudget) * 100).round()}%',
              icon: Icons.task_alt_rounded,
              tone: AppColors.indigo,
            ),
          ],
        ),
        const SizedBox(height: 16),
        StatisticsCard(
          title: 'Month summary',
          icon: Icons.insights_rounded,
          children: [
            StatLine(
              label: 'Expected income',
              value: formatEuro(computed.expectedIncome),
              color: AppColors.green,
            ),
            StatLine(
              label: 'Projected balance',
              value: formatEuro(computed.expectedBalance),
              color: computed.expectedBalance >= 0
                  ? AppColors.green
                  : AppColors.red,
            ),
            StatLine(
              label: 'Still to pay',
              value: formatEuro(computed.stillToPay),
              color: AppColors.amber,
            ),
            if (topBlock != null)
              StatLine(
                label: 'Largest block',
                value: '${topBlock.meta.title} ${formatEuro(topBlock.total)}',
                color: topBlock.meta.tone,
              ),
          ],
        ),
        const SizedBox(height: 16),
        StatisticsCard(
          title: 'Budget blocks',
          icon: Icons.pie_chart_rounded,
          children: [
            if (blocks.isEmpty)
              const EmptyStatisticsText('No budget blocks planned this month.'),
            for (final block in blocks)
              StatProgressLine(
                label: block.meta.title,
                value: formatEuro(block.total),
                progress: computed.totalBudget > 0
                    ? block.total / computed.totalBudget
                    : 0,
                color: block.meta.tone,
              ),
          ],
        ),
        const SizedBox(height: 16),
        StatisticsCard(
          title: 'Outstanding by account',
          icon: Icons.account_balance_rounded,
          children: [
            if (computed.accounts.every((account) => account.amount == 0))
              const EmptyStatisticsText('No outstanding account transfers.'),
            for (final account in computed.accounts.where(
              (item) => item.amount > 0,
            ))
              StatProgressLine(
                label: account.name,
                value: formatEuro(account.amount),
                progress: account.progress,
                color: account.color,
              ),
          ],
        ),
      ],
    );
  }
}

class YearlyStatisticsView extends StatelessWidget {
  const YearlyStatisticsView({super.key, required this.statistics});

  final YearlyStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final maxExpenses = statistics.months.fold<double>(
      1,
      (max, month) => math.max(max, month.totalBudget),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            KpiCard(
              label: 'Year income',
              value: formatEuro(statistics.realIncome, cents: false),
              icon: Icons.arrow_downward_rounded,
              tone: AppColors.green,
            ),
            KpiCard(
              label: 'Year expenses',
              value: formatEuro(statistics.totalBudget, cents: false),
              icon: Icons.arrow_upward_rounded,
              tone: AppColors.red,
            ),
            KpiCard(
              label: 'Year balance',
              value: formatEuro(statistics.balance, cents: false),
              icon: Icons.monitor_heart_rounded,
              tone: statistics.balance >= 0 ? AppColors.green : AppColors.red,
            ),
            KpiCard(
              label: 'Monthly avg.',
              value: formatEuro(statistics.averageExpenses, cents: false),
              icon: Icons.show_chart_rounded,
              tone: AppColors.indigo,
            ),
          ],
        ),
        const SizedBox(height: 16),
        StatisticsCard(
          title: 'Year summary',
          icon: Icons.calendar_month_rounded,
          children: [
            StatLine(
              label: 'Expected income',
              value: formatEuro(statistics.expectedIncome),
              color: AppColors.green,
            ),
            StatLine(
              label: 'Projected balance',
              value: formatEuro(statistics.expectedBalance),
              color: statistics.expectedBalance >= 0
                  ? AppColors.green
                  : AppColors.red,
            ),
            StatLine(
              label: 'Still to pay',
              value: formatEuro(statistics.stillToPay),
              color: AppColors.amber,
            ),
            StatLine(
              label: 'Best month',
              value:
                  '${statistics.bestMonth.monthLabel} ${formatEuro(statistics.bestMonth.balance)}',
              color: statistics.bestMonth.balance >= 0
                  ? AppColors.green
                  : AppColors.red,
            ),
          ],
        ),
        const SizedBox(height: 16),
        StatisticsCard(
          title: 'Monthly expenses',
          icon: Icons.bar_chart_rounded,
          children: [
            for (final month in statistics.months)
              StatProgressLine(
                label: month.monthLabel,
                value: formatEuro(month.totalBudget, cents: false),
                progress: month.totalBudget / maxExpenses,
                color: month.balance >= 0 ? AppColors.indigo : AppColors.red,
              ),
          ],
        ),
      ],
    );
  }
}

class YearlyStatistics {
  YearlyStatistics(this.months);

  final List<ComputedMonth> months;

  double get expectedIncome =>
      months.fold(0, (sum, month) => sum + month.expectedIncome);
  double get realIncome =>
      months.fold(0, (sum, month) => sum + month.realIncome);
  double get totalBudget =>
      months.fold(0, (sum, month) => sum + month.totalBudget);
  double get totalPaid => months.fold(0, (sum, month) => sum + month.totalPaid);
  double get stillToPay =>
      months.fold(0, (sum, month) => sum + month.stillToPay);
  double get expectedBalance => expectedIncome - totalBudget;
  double get balance => realIncome - totalBudget;
  double get averageExpenses => totalBudget / months.length;
  ComputedMonth get bestMonth => months.reduce(
    (best, month) => month.balance > best.balance ? month : best,
  );
}

class StatisticsCard extends StatelessWidget {
  const StatisticsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ToneIcon(icon: icon, tone: AppColors.indigo),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class StatLine extends StatelessWidget {
  const StatLine({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: itemStyle)),
          const SizedBox(width: 12),
          Text(value, style: moneyStyle.copyWith(color: color)),
        ],
      ),
    );
  }
}

class StatProgressLine extends StatelessWidget {
  const StatProgressLine({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: itemStyle,
                ),
              ),
              const SizedBox(width: 12),
              Text(value, style: moneyStyle.copyWith(fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              backgroundColor: AppColors.track,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStatisticsText extends StatelessWidget {
  const EmptyStatisticsText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.monthLabel,
    required this.year,
    required this.onCopyMonth,
  });

  final String monthLabel;
  final int year;
  final VoidCallback onCopyMonth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      Text(
                        '$monthLabel $year',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              decoration: cardDecoration(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ToneIcon(
                        icon: Icons.calendar_month_rounded,
                        tone: AppColors.indigo,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Month tools',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Manage repeated monthly setup',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: onCopyMonth,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy one month to another'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MobileBudgetView extends StatelessWidget {
  const MobileBudgetView({
    super.key,
    required this.computed,
    required this.onToggleExpense,
    required this.onSetExpenseAccount,
    required this.onEditExpenseItem,
    required this.onDeleteExpenseItem,
    required this.onDeleteBudgetBlock,
    required this.onDeleteAccount,
    required this.onToggleIncome,
    required this.onSetIncomeAccount,
    required this.onEditIncome,
    required this.onDeleteIncome,
    required this.onAddIncome,
    required this.onLogExpense,
    required this.onCreateAccount,
    required this.onCreateBudgetBlock,
    required this.onOpenStatistics,
    required this.onOpenSettings,
  });

  final ComputedMonth computed;
  final void Function(String categoryKey, String id) onToggleExpense;
  final void Function(String categoryKey, String id, String accountKey)
  onSetExpenseAccount;
  final void Function(CategoryMeta meta, ExpenseItem item) onEditExpenseItem;
  final void Function(String categoryKey, String id) onDeleteExpenseItem;
  final ValueChanged<String> onDeleteBudgetBlock;
  final ValueChanged<String> onDeleteAccount;
  final ValueChanged<String> onToggleIncome;
  final void Function(String id, String accountKey) onSetIncomeAccount;
  final ValueChanged<IncomeItem> onEditIncome;
  final ValueChanged<String> onDeleteIncome;
  final VoidCallback onAddIncome;
  final VoidCallback onLogExpense;
  final VoidCallback onCreateAccount;
  final VoidCallback onCreateBudgetBlock;
  final VoidCallback onOpenStatistics;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final greeting = greetingForHour(DateTime.now().hour);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting, Eva',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.indigo,
                  child: Text(
                    'E',
                    style: titleStyle.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onOpenStatistics,
                    icon: const Icon(Icons.bar_chart_rounded, size: 18),
                    label: const Text('Statistics'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Settings'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAddIncome,
                icon: const Icon(Icons.add_card_rounded, size: 18),
                label: const Text('Add income'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onCreateAccount,
                    icon: const Icon(Icons.account_balance_rounded, size: 18),
                    label: const Text('Account'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onCreateBudgetBlock,
                    icon: const Icon(Icons.add_chart_rounded, size: 18),
                    label: const Text('Budget block'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SumUpCard(
              computed: computed,
              compact: true,
              onDeleteAccount: onDeleteAccount,
            ),
            const SizedBox(height: 18),
            Text('QUICK LOG', style: labelStyle),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: .86,
              children: categoryMeta
                  .map(
                    (meta) =>
                        QuickCategoryTile(meta: meta, onTap: onLogExpense),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Text('BUDGET BLOCKS', style: labelStyle),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IncomeBlockCard(
                computed: computed,
                compact: true,
                onToggle: onToggleIncome,
                onSetAccount: onSetIncomeAccount,
                onEdit: onEditIncome,
                onDelete: onDeleteIncome,
                onAddIncome: onAddIncome,
              ),
            ),
            ...categoryMeta.map(
              (meta) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ExpenseBlockCard(
                  meta: meta,
                  block: computed.blocks[meta.key]!,
                  compact: true,
                  onToggle: (id) => onToggleExpense(meta.key, id),
                  onSetAccount: (id, accountKey) =>
                      onSetExpenseAccount(meta.key, id, accountKey),
                  onEditItem: (item) => onEditExpenseItem(meta, item),
                  onDeleteItem: (id) => onDeleteExpenseItem(meta.key, id),
                  onDeleteBlock: () => onDeleteBudgetBlock(meta.key),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 20,
          child: FilledButton.icon(
            onPressed: onLogExpense,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Log an expense'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
