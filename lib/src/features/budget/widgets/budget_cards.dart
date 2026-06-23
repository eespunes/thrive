part of 'package:family_money_management_app/main.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: cardDecoration(radius: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: tone),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: titleStyle.copyWith(fontSize: 19)),
          ),
        ],
      ),
    );
  }
}

class IncomeCard extends StatelessWidget {
  const IncomeCard({
    super.key,
    required this.computed,
    required this.onToggle,
    required this.onSetAccount,
    required this.onEdit,
    required this.onDelete,
    required this.onAddIncome,
  });

  final ComputedMonth computed;
  final ValueChanged<String> onToggle;
  final void Function(String id, String accountKey) onSetAccount;
  final ValueChanged<IncomeItem> onEdit;
  final ValueChanged<String> onDelete;
  final VoidCallback onAddIncome;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
            child: Row(
              children: [
                const ToneIcon(
                  icon: Icons.account_balance_wallet_rounded,
                  tone: AppColors.indigo,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Income',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'EXPECTED VS ACTUAL',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onAddIncome,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Income'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatEuro(computed.realIncome), style: titleStyle),
                    Text(
                      'received of ${formatEuro(computed.expectedIncome)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('SOURCE', style: headerStyle)),
                Expanded(
                  flex: 2,
                  child: Text(
                    'EXPECTED',
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ACTUAL',
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
                SizedBox(width: 154),
              ],
            ),
          ),
          ...computed.month.income.map((row) {
            final delta = row.actual - row.expected;
            return DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.faintLine)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        row.label,
                        overflow: TextOverflow.ellipsis,
                        style: itemStyle,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        formatEuro(row.expected),
                        textAlign: TextAlign.right,
                        style: moneyStyle.copyWith(color: AppColors.softText),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        formatEuro(row.actual),
                        textAlign: TextAlign.right,
                        style: moneyStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 76,
                      child: Text(
                        delta == 0 ? '-' : signedEuro(delta),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: delta > 0
                              ? AppColors.green
                              : delta < 0
                              ? AppColors.red
                              : AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AccountMenuChip(
                      accountKey: row.accountKey,
                      onChanged: (accountKey) =>
                          onSetAccount(row.id, accountKey),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(
                      active: row.received,
                      activeLabel: 'Received',
                      inactiveLabel: 'Pending',
                      onTap: () => onToggle(row.id),
                    ),
                    IconButton(
                      tooltip: 'Edit income',
                      onPressed: () => onEdit(row),
                      icon: const Icon(Icons.edit_rounded),
                      color: AppColors.muted,
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: 'Delete income',
                      onPressed: () async {
                        final confirmed = await confirmDelete(
                          context,
                          title: 'Delete income?',
                          message: 'Remove ${row.label} from this month?',
                        );
                        if (confirmed) onDelete(row.id);
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: AppColors.muted,
                      iconSize: 19,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class IncomeBlockCard extends StatefulWidget {
  const IncomeBlockCard({
    super.key,
    required this.computed,
    required this.onToggle,
    required this.onSetAccount,
    required this.onEdit,
    required this.onDelete,
    required this.onAddIncome,
    this.compact = false,
  });

  final ComputedMonth computed;
  final ValueChanged<String> onToggle;
  final void Function(String id, String accountKey) onSetAccount;
  final ValueChanged<IncomeItem> onEdit;
  final ValueChanged<String> onDelete;
  final VoidCallback onAddIncome;
  final bool compact;

  @override
  State<IncomeBlockCard> createState() => _IncomeBlockCardState();
}

class _IncomeBlockCardState extends State<IncomeBlockCard> {
  late bool _expanded = !widget.compact;

  @override
  Widget build(BuildContext context) {
    final incomeRows = widget.computed.month.income;
    final visibleRows = widget.compact && !_expanded
        ? <IncomeItem>[]
        : incomeRows;

    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: widget.compact
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
              child: Row(
                children: [
                  const ToneIcon(
                    icon: Icons.account_balance_wallet_rounded,
                    tone: AppColors.green,
                    background: Color(0xFFE9FBF3),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Income',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          widget.compact && !_expanded
                              ? 'Tap to show ${incomeRows.length} ${incomeRows.length == 1 ? 'item' : 'items'}'
                              : '${incomeRows.length} ${incomeRows.length == 1 ? 'item' : 'items'}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatEuro(widget.computed.realIncome),
                        style: moneyStyle.copyWith(fontSize: 15),
                      ),
                      Text(
                        'of ${formatEuro(widget.computed.expectedIncome, cents: false)} expected',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (widget.compact) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: widget.computed.expectedIncome > 0
                    ? (widget.computed.realIncome /
                              widget.computed.expectedIncome)
                          .clamp(0.0, 1.0)
                    : 0,
                minHeight: 6,
                backgroundColor: AppColors.track,
                valueColor: const AlwaysStoppedAnimation(AppColors.green),
              ),
            ),
          ),
          if (_expanded && incomeRows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: widget.onAddIncome,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add income'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ...visibleRows.map(
            (row) => DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.faintLine)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: itemStyle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatEuro(row.actual),
                          style: moneyStyle.copyWith(fontSize: 13.5),
                        ),
                        IconButton(
                          tooltip: 'Edit income',
                          onPressed: () => widget.onEdit(row),
                          icon: const Icon(Icons.edit_rounded),
                          color: AppColors.muted,
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          tooltip: 'Delete income',
                          onPressed: () async {
                            final confirmed = await confirmDelete(
                              context,
                              title: 'Delete income?',
                              message: 'Remove ${row.label} from this month?',
                            );
                            if (confirmed) widget.onDelete(row.id);
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: AppColors.muted,
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Expected ${formatEuro(row.expected)}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AccountMenuChip(
                          accountKey: row.accountKey,
                          dense: true,
                          onChanged: (accountKey) =>
                              widget.onSetAccount(row.id, accountKey),
                        ),
                        const SizedBox(width: 8),
                        StatusPill(
                          active: row.received,
                          activeLabel: 'Received',
                          inactiveLabel: 'Pending',
                          onTap: () => widget.onToggle(row.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetGrid extends StatelessWidget {
  const BudgetGrid({
    super.key,
    required this.computed,
    required this.onToggleExpense,
    required this.onSetExpenseAccount,
    required this.onEditExpenseItem,
    required this.onDeleteExpenseItem,
    required this.onDeleteBudgetBlock,
  });

  final ComputedMonth computed;
  final void Function(String categoryKey, String id) onToggleExpense;
  final void Function(String categoryKey, String id, String accountKey)
  onSetExpenseAccount;
  final void Function(CategoryMeta meta, ExpenseItem item) onEditExpenseItem;
  final void Function(String categoryKey, String id) onDeleteExpenseItem;
  final ValueChanged<String> onDeleteBudgetBlock;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1030 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: columns == 2 ? 1.45 : 2.65,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final meta in categoryMeta)
              ExpenseBlockCard(
                meta: meta,
                block: computed.blocks[meta.key]!,
                onToggle: (id) => onToggleExpense(meta.key, id),
                onSetAccount: (id, accountKey) =>
                    onSetExpenseAccount(meta.key, id, accountKey),
                onEditItem: (item) => onEditExpenseItem(meta, item),
                onDeleteItem: (id) => onDeleteExpenseItem(meta.key, id),
                onDeleteBlock: () => onDeleteBudgetBlock(meta.key),
              ),
          ],
        );
      },
    );
  }
}

class ExpenseBlockCard extends StatefulWidget {
  const ExpenseBlockCard({
    super.key,
    required this.meta,
    required this.block,
    required this.onToggle,
    required this.onSetAccount,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onDeleteBlock,
    this.compact = false,
  });

  final CategoryMeta meta;
  final ExpenseBlock block;
  final ValueChanged<String> onToggle;
  final void Function(String id, String accountKey) onSetAccount;
  final ValueChanged<ExpenseItem> onEditItem;
  final ValueChanged<String> onDeleteItem;
  final VoidCallback onDeleteBlock;
  final bool compact;

  @override
  State<ExpenseBlockCard> createState() => _ExpenseBlockCardState();
}

class _ExpenseBlockCardState extends State<ExpenseBlockCard> {
  late bool _expanded = !widget.compact;

  @override
  void didUpdateWidget(covariant ExpenseBlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meta.key != widget.meta.key) {
      _expanded = !widget.compact;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.compact && !_expanded
        ? widget.block.items.take(0).toList()
        : widget.block.items;

    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: widget.compact
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
              child: Row(
                children: [
                  ToneIcon(
                    icon: widget.meta.icon,
                    tone: widget.meta.tone,
                    background: widget.meta.background,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.meta.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          widget.compact && !_expanded
                              ? 'Tap to show ${widget.block.items.length} ${widget.block.items.length == 1 ? 'item' : 'items'}'
                              : '${widget.block.items.length} ${widget.block.items.length == 1 ? 'item' : 'items'}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatEuro(widget.block.total),
                            style: moneyStyle.copyWith(fontSize: 15),
                          ),
                          if (widget.compact) ...[
                            const SizedBox(width: 4),
                            Icon(
                              _expanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              size: 20,
                              color: AppColors.muted,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${formatEuro(widget.block.paid, cents: false)} paid',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Delete budget block',
                    onPressed: () async {
                      final confirmed = await confirmDelete(
                        context,
                        title: 'Delete budget block?',
                        message:
                            'Delete ${widget.meta.title} and all items inside it?',
                      );
                      if (confirmed) widget.onDeleteBlock();
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppColors.muted,
                    iconSize: 19,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: widget.block.progress,
                minHeight: 6,
                backgroundColor: AppColors.track,
                valueColor: AlwaysStoppedAnimation(widget.meta.tone),
              ),
            ),
          ),
          if (rows.isNotEmpty)
            Flexible(
              fit: widget.compact ? FlexFit.loose : FlexFit.tight,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: widget.compact,
                physics: widget.compact
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.faintLine),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: itemStyle,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        row.marker,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (row.untilLabel != null) ...[
                                      const SizedBox(width: 6),
                                      UntilChip(
                                        label: row.untilLabel!,
                                        state: row.untilState,
                                      ),
                                    ],
                                    const SizedBox(width: 6),
                                    AccountMenuChip(
                                      accountKey: row.accountKey,
                                      dense: true,
                                      onChanged: (accountKey) => widget
                                          .onSetAccount(row.id, accountKey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatEuro(row.amount),
                            style: moneyStyle.copyWith(fontSize: 13.5),
                          ),
                          const SizedBox(width: 10),
                          StatusPill(
                            active: row.paid,
                            activeLabel: widget.meta.key == 'savings'
                                ? 'Saved'
                                : 'Paid',
                            inactiveLabel: widget.meta.key == 'savings'
                                ? 'To save'
                                : 'Unpaid',
                            onTap: () => widget.onToggle(row.id),
                          ),
                          IconButton(
                            tooltip: 'Edit item',
                            onPressed: () => widget.onEditItem(row),
                            icon: const Icon(Icons.edit_rounded),
                            color: AppColors.muted,
                            iconSize: 18,
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            tooltip: 'Delete item',
                            onPressed: () async {
                              final confirmed = await confirmDelete(
                                context,
                                title: 'Delete item?',
                                message:
                                    'Remove ${row.label} from ${widget.meta.title}?',
                              );
                              if (confirmed) widget.onDeleteItem(row.id);
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: AppColors.muted,
                            iconSize: 18,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class SumUpCard extends StatelessWidget {
  const SumUpCard({
    super.key,
    required this.computed,
    required this.onDeleteAccount,
    this.compact = false,
  });

  final ComputedMonth computed;
  final ValueChanged<String> onDeleteAccount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final paidPct = computed.totalBudget > 0
        ? computed.totalPaid / computed.totalBudget
        : 1.0;
    final good = computed.balance >= 0 && computed.stillToPay == 0;
    final watch = computed.balance >= 0 && computed.stillToPay > 0;
    final statusColor = good
        ? AppColors.green
        : watch
        ? AppColors.amber
        : AppColors.red;
    final statusText = good
        ? 'On track'
        : watch
        ? 'Watch spending'
        : 'Over budget';

    return Container(
      decoration: cardDecoration(radius: 20),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ToneIcon(
                icon: Icons.monitor_heart_rounded,
                tone: AppColors.indigo,
                size: 30,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text('Sum Up', style: titleStyle.copyWith(fontSize: 16)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 13,
                      color: statusColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.deepIndigo, AppColors.indigo],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.indigo.withValues(alpha: .28),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROJECTED BALANCE',
                  style: labelStyle.copyWith(
                    color: Colors.white.withValues(alpha: .84),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatEuro(computed.balance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Expected ${formatEuro(computed.expectedBalance)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: .86),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SmallMetric(
                  label: 'Income',
                  value: '+${formatEuro(computed.realIncome, cents: false)}',
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: SmallMetric(
                  label: 'Expenses',
                  value: '-${formatEuro(computed.totalBudget, cents: false)}',
                  color: AppColors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: computed.stillToPay > 0
                  ? AppColors.amberSoft
                  : AppColors.greenSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: computed.stillToPay > 0
                    ? AppColors.amberLine
                    : AppColors.greenLine,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        computed.stillToPay > 0
                            ? 'Still to pay'
                            : 'All settled',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: computed.stillToPay > 0
                              ? AppColors.amberText
                              : AppColors.green,
                        ),
                      ),
                    ),
                    Text(
                      formatEuro(computed.stillToPay),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: computed.stillToPay > 0
                            ? AppColors.amberText
                            : AppColors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: paidPct.clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: Colors.black.withValues(alpha: .06),
                    valueColor: AlwaysStoppedAnimation(
                      computed.stillToPay > 0
                          ? AppColors.amber
                          : AppColors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${(paidPct * 100).round()}% of ${formatEuro(computed.totalBudget, cents: false)} paid',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('COVERED BY ACCOUNT', style: labelStyle),
          const SizedBox(height: 4),
          ...computed.accounts.map(
            (account) => AccountRow(
              account: account,
              onDelete: accountMeta.length > 1
                  ? () => onDeleteAccount(account.account.key)
                  : null,
            ),
          ),
          if (computed.accounts.every((account) => account.amount == 0))
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'No outstanding transfers planned this month.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BreakdownCard extends StatelessWidget {
  const BreakdownCard({super.key, required this.computed});

  final ComputedMonth computed;

  @override
  Widget build(BuildContext context) {
    final blocks =
        computed.blocks.values.where((block) => block.total > 0).toList()
          ..sort((a, b) => b.total.compareTo(a.total));
    final total = blocks.fold<double>(0, (sum, block) => sum + block.total);

    return Container(
      decoration: cardDecoration(radius: 20),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where it goes', style: titleStyle.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'Share of monthly outflow',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: DonutPainter(blocks),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('TOTAL', style: labelStyle),
                        Text(
                          formatEuro(total, cents: false),
                          style: titleStyle.copyWith(fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final block in blocks.take(6))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: block.meta.tone,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                block.meta.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: itemStyle.copyWith(fontSize: 12),
                              ),
                            ),
                            Text(
                              '${(block.total / math.max(total, 1) * 100).round()}%',
                              style: moneyStyle.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class QuickCategoryTile extends StatelessWidget {
  const QuickCategoryTile({super.key, required this.meta, required this.onTap});

  final CategoryMeta meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        decoration: cardDecoration(radius: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ToneIcon(
              icon: meta.icon,
              tone: meta.tone,
              background: meta.background,
              size: 35,
              iconSize: 18,
            ),
            const SizedBox(height: 7),
            Text(
              meta.title.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
