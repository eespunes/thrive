part of 'package:family_money_management_app/main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.monthLabel,
    required this.year,
    required this.month,
    required this.isClosed,
    required this.onCloseMonth,
    required this.onCopyMonth,
    required this.onCreateAccount,
    required this.onCreateBudgetBlock,
    required this.onDeleteBudgetBlock,
    required this.onDeleteAccount,
    required this.onReorderAccounts,
    required this.onReorderCategories,
    super.key,
  });

  final String monthLabel;
  final int year;
  final MonthBudget month;
  final bool isClosed;
  final Function(bool) onCloseMonth;
  final Function() onCopyMonth;
  final Function() onCreateAccount;
  final Function() onCreateBudgetBlock;
  final Function(String) onDeleteBudgetBlock;
  final Function(String) onDeleteAccount;
  final Function(int, int) onReorderAccounts;
  final Function(int, int) onReorderCategories;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Accounts'),
            Tab(text: 'Blocks'),
            Tab(text: 'Month'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AccountsTab(
            onCreateAccount: widget.onCreateAccount,
            onDeleteAccount: widget.onDeleteAccount,
            onReorderAccounts: widget.onReorderAccounts,
          ),
          _BudgetBlocksTab(
            onCreateBlock: widget.onCreateBudgetBlock,
            onDeleteBlock: widget.onDeleteBudgetBlock,
            onReorderBlocks: widget.onReorderCategories,
          ),
          _MonthTab(
            monthLabel: widget.monthLabel,
            year: widget.year,
            isClosed: widget.isClosed,
            onCloseMonth: widget.onCloseMonth,
            onCopyMonth: widget.onCopyMonth,
          ),
        ],
      ),
    );
  }
}

class _AccountsTab extends StatelessWidget {
  const _AccountsTab({
    required this.onCreateAccount,
    required this.onDeleteAccount,
    required this.onReorderAccounts,
  });

  final Function() onCreateAccount;
  final Function(String) onDeleteAccount;
  final Function(int, int) onReorderAccounts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: onCreateAccount,
            icon: const Icon(Icons.add),
            label: const Text('Add Account'),
          ),
        ),
        Expanded(
          child: ReorderableListView(
            onReorder: onReorderAccounts,
            children: [
              for (int i = 0; i < accountMeta.length; i++)
                _AccountTile(
                  key: ValueKey(accountMeta[i].key),
                  account: accountMeta[i],
                  index: i,
                  onDelete: () => onDeleteAccount(accountMeta[i].key),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.index,
    required this.onDelete,
    required Key key,
  }) : super(key: key);

  final AccountMeta account;
  final int index;
  final Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(account.key),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Account?'),
            content: Text('Are you sure you want to delete "${account.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          title: Text(account.name),
          subtitle: Text(account.shortName),
          trailing: CircleAvatar(
            backgroundColor: account.color,
            child: Text(
              account.initials,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetBlocksTab extends StatelessWidget {
  const _BudgetBlocksTab({
    required this.onCreateBlock,
    required this.onDeleteBlock,
    required this.onReorderBlocks,
  });

  final Function() onCreateBlock;
  final Function(String) onDeleteBlock;
  final Function(int, int) onReorderBlocks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: onCreateBlock,
            icon: const Icon(Icons.add),
            label: const Text('Add Budget Block'),
          ),
        ),
        Expanded(
          child: ReorderableListView(
            onReorder: onReorderBlocks,
            children: [
              for (int i = 0; i < categoryMeta.length; i++)
                _BlockTile(
                  key: ValueKey(categoryMeta[i].key),
                  category: categoryMeta[i],
                  index: i,
                  onDelete: () => onDeleteBlock(categoryMeta[i].key),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({
    required this.category,
    required this.index,
    required this.onDelete,
    required Key key,
  }) : super(key: key);

  final CategoryMeta category;
  final int index;
  final Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(category.key),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Budget Block?'),
            content: Text('Are you sure you want to delete "${category.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          leading: ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle, color: category.tone),
          ),
          title: Text(category.title),
          subtitle: Text(category.isTemporary ? 'Temporary' : 'Recurring'),
          trailing: Icon(category.icon, color: category.tone),
        ),
      ),
    );
  }
}

class _MonthTab extends StatefulWidget {
  const _MonthTab({
    required this.monthLabel,
    required this.year,
    required this.isClosed,
    required this.onCloseMonth,
    required this.onCopyMonth,
  });

  final String monthLabel;
  final int year;
  final bool isClosed;
  final Function(bool) onCloseMonth;
  final Function() onCopyMonth;

  @override
  State<_MonthTab> createState() => _MonthTabState();
}

class _MonthTabState extends State<_MonthTab> {
  late bool _isClosed;

  @override
  void initState() {
    super.initState();
    _isClosed = widget.isClosed;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Text('${widget.monthLabel} ${widget.year}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Close Month'),
          subtitle: const Text('No changes allowed'),
          value: _isClosed,
          onChanged: (value) {
            setState(() => _isClosed = value);
            widget.onCloseMonth(value);
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: widget.onCopyMonth,
          icon: const Icon(Icons.content_copy),
          label: const Text('Copy Month Structure'),
        ),
      ],
    );
  }
}
