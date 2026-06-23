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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onSetMonth(-1),
            ),
            Text('$monthLabel $year'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onSetMonth(1),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Real Balance: ${formatEuro(computed.balance)}'),
                  Text('Expected Balance: ${formatEuro(computed.expectedBalance)}'),
                  Text('Total Budget: ${formatEuro(computed.totalBudget)}'),
                  Text('Total Paid: ${formatEuro(computed.totalPaid)}'),
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
                child: Text('This month is closed - read-only'),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Income', style: TextStyle(fontWeight: FontWeight.bold)),
          ...month.income.map((item) => ListTile(
            title: Text(item.label),
            subtitle: Text('Expected: ${formatEuro(item.expected)}, Actual: ${formatEuro(item.actual)}'),
            trailing: Checkbox(
              value: item.received,
              onChanged: isClosed ? null : (_) => onToggleIncome(item.id),
            ),
            onTap: isClosed ? null : () => onEditIncome(item),
          )),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: isClosed ? null : onAddIncome,
            child: const Text('Add Income'),
          ),
          const SizedBox(height: 24),
          const Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
          ...computed.blocks.values.map((block) => ExpenseBlockCard(
            block: block,
            isClosed: isClosed,
            onToggle: (id) => onToggleExpense(block.meta.key, id),
            onEdit: (item) => onEditExpenseItem(block.meta, item),
            onDelete: (id) => onDeleteExpenseItem(block.meta.key, id),
            onSetAccount: (id, account) => onSetExpenseAccount(block.meta.key, id, account),
          )),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: isClosed ? null : onLogExpense,
            child: const Text('Log Expense'),
          ),
        ],
      ),
    );
  }
}

class ExpenseBlockCard extends StatelessWidget {
  const ExpenseBlockCard({
    required this.block,
    required this.isClosed,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onSetAccount,
    super.key,
  });

  final ExpenseBlock block;
  final bool isClosed;
  final Function(String) onToggle;
  final Function(ExpenseItem) onEdit;
  final Function(String) onDelete;
  final Function(String, String) onSetAccount;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(block.meta.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Budget: ${formatEuro(block.total)} | Paid: ${formatEuro(block.paid)}'),
            ...block.items.map((item) => ListTile(
              title: Text(item.label),
              subtitle: Text('${formatEuro(item.amount)} on ${item.marker}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: item.paid,
                    onChanged: isClosed ? null : (_) => onToggle(item.id),
                  ),
                  PopupMenuButton(
                    itemBuilder: (_) => [
                      const PopupMenuItem(child: Text('Edit')),
                      const PopupMenuItem(child: Text('Delete')),
                    ],
                    onSelected: (value) {
                      if (value == 0) {
                        onEdit(item);
                      } else if (value == 1 && !isClosed) {
                        onDelete(item.id);
                      }
                    },
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
