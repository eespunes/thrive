part of 'package:family_money_management_app/main.dart';

class BudgetOverviewScreen extends StatelessWidget {
  const BudgetOverviewScreen({
    required this.computed,
    required this.year,
    required this.monthIndex,
    required this.month,
    required this.monthLabel,
    required this.isClosed,
    required this.onSetMonth,
    required this.onSetYear,
    required this.onToggleExpense,
    required this.onSetExpenseAccount,
    required this.onEditExpenseItem,
    required this.onDeleteExpenseItem,
    required this.onToggleIncome,
    required this.onSetIncomeAccount,
    required this.onEditIncome,
    required this.onDeleteIncome,
    required this.onAddIncome,
    required this.onLogExpense,
    super.key,
  });

  final ComputedMonth computed;
  final int year;
  final int monthIndex;
  final MonthBudget month;
  final String monthLabel;
  final bool isClosed;
  final Function(int) onSetMonth;
  final Function(int) onSetYear;
  final Function(String, String) onToggleExpense;
  final Function(String, String, String) onSetExpenseAccount;
  final Function(CategoryMeta, ExpenseItem) onEditExpenseItem;
  final Function(String, String) onDeleteExpenseItem;
  final Function(String) onToggleIncome;
  final Function(String, String) onSetIncomeAccount;
  final Function(IncomeItem) onEditIncome;
  final Function(String) onDeleteIncome;
  final Function() onAddIncome;
  final Function() onLogExpense;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              '$monthLabel $year',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Real Balance: ${formatEuro(computed.balance)}'),
                  Text('Expected Balance: ${formatEuro(computed.expectedBalance)}'),
                  Text('Total Budget: ${formatEuro(computed.totalBudget)}'),
                  Text('Total Paid: ${formatEuro(computed.totalPaid)}'),
                  Text('Still To Pay: ${formatEuro(computed.stillToPay)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isClosed)
            const Card(
              color: Colors.amber,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'This month is closed - read-only',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Income', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ...month.income.map((item) => ListTile(
            title: Text(item.label),
            subtitle: Text('Expected: ${formatEuro(item.expected)}, Actual: ${formatEuro(item.actual)}'),
            trailing: Checkbox(
              value: item.received,
              onChanged: isClosed ? null : (_) => onToggleIncome(item.id),
            ),
          )),
          const SizedBox(height: 16),
          const Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ...computed.blocks.values.map((block) => _ExpenseBlockTile(
            block: block,
            isClosed: isClosed,
          )),
        ],
      ),
    );
  }
}

class _ExpenseBlockTile extends StatelessWidget {
  const _ExpenseBlockTile({
    required this.block,
    required this.isClosed,
  });

  final ExpenseBlock block;
  final bool isClosed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(block.meta.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${formatEuro(block.total)} / ${formatEuro(block.paid)}'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: block.progress,
              minHeight: 4,
            ),
            const SizedBox(height: 8),
            ...block.items.take(3).map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(item.label, overflow: TextOverflow.ellipsis)),
                  Checkbox(
                    value: item.paid,
                    onChanged: isClosed ? null : (_) {},
                  ),
                  Text(formatEuro(item.amount), style: const TextStyle(fontSize: 12)),
                ],
              ),
            )),
            if (block.items.length > 3)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '+${block.items.length - 3} more items',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
