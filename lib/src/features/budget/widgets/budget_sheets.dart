part of 'package:family_money_management_app/main.dart';

class NameEntrySheet extends StatefulWidget {
  const NameEntrySheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.actionLabel,
    required this.hint,
  });

  final String title;
  final String subtitle;
  final String label;
  final String actionLabel;
  final String hint;

  @override
  State<NameEntrySheet> createState() => _NameEntrySheetState();
}

class _NameEntrySheetState extends State<NameEntrySheet> {
  final _controller = TextEditingController();

  bool get _canSave => _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(26),
            bottom: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: titleStyle),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(widget.label.toUpperCase(), style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  filled: true,
                  fillColor: AppColors.panel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.indigo,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.line,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(widget.actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CopyMonthSheet extends StatefulWidget {
  const CopyMonthSheet({
    super.key,
    required this.currentMonthIndex,
    required this.year,
  });

  final int currentMonthIndex;
  final int year;

  @override
  State<CopyMonthSheet> createState() => _CopyMonthSheetState();
}

class _CopyMonthSheetState extends State<CopyMonthSheet> {
  late int _sourceMonthIndex = widget.currentMonthIndex;
  late int _targetMonthIndex =
      (widget.currentMonthIndex + 1) % monthKeys.length;

  bool get _canCopy => _sourceMonthIndex != _targetMonthIndex;

  void _copy() {
    if (!_canCopy) return;
    Navigator.of(context).pop(
      CopyMonthSelection(
        sourceMonthIndex: _sourceMonthIndex,
        targetMonthIndex: _targetMonthIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(26),
            bottom: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Copy month', style: titleStyle),
                        const SizedBox(height: 3),
                        const Text(
                          'Replace one month with a copy of another',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('COPY FROM', style: labelStyle),
              const SizedBox(height: 8),
              MonthDropdown(
                value: _sourceMonthIndex,
                year: widget.year,
                onChanged: (value) => setState(() => _sourceMonthIndex = value),
              ),
              const SizedBox(height: 14),
              Text('COPY TO', style: labelStyle),
              const SizedBox(height: 8),
              MonthDropdown(
                value: _targetMonthIndex,
                year: widget.year,
                onChanged: (value) => setState(() => _targetMonthIndex = value),
              ),
              const SizedBox(height: 12),
              Text(
                _canCopy
                    ? '${monthLabels[_targetMonthIndex]} ${widget.year} will be overwritten.'
                    : 'Choose two different months.',
                style: TextStyle(
                  color: _canCopy ? AppColors.muted : AppColors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canCopy ? _copy : null,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy month'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.indigo,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.line,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MonthDropdown extends StatelessWidget {
  const MonthDropdown({
    super.key,
    required this.value,
    required this.year,
    required this.onChanged,
  });

  final int value;
  final int year;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      items: [
        for (var i = 0; i < monthLabels.length; i++)
          DropdownMenuItem(value: i, child: Text('${monthLabels[i]} $year')),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
    );
  }
}

class EditSheetScaffold extends StatelessWidget {
  const EditSheetScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionColor,
    required this.canSave,
    required this.onSave,
    required this.children,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final Color actionColor;
  final bool canSave;
  final VoidCallback onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(26),
            bottom: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: titleStyle),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ...children,
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: canSave ? onSave : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.line,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MoneyTextField extends StatelessWidget {
  const MoneyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: fieldDecoration(hintText).copyWith(prefixText: '€ '),
    );
  }
}

class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

InputDecoration fieldDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: AppColors.panel,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AppColors.line),
    ),
  );
}

String decimalText(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

class IncomeEntrySheet extends StatefulWidget {
  const IncomeEntrySheet({super.key});

  @override
  State<IncomeEntrySheet> createState() => _IncomeEntrySheetState();
}

class _IncomeEntrySheetState extends State<IncomeEntrySheet> {
  final _sourceController = TextEditingController();
  final _expectedController = TextEditingController();
  final _actualController = TextEditingController();
  String _accountKey = defaultAccountKey;
  bool _received = true;

  double get _expected =>
      double.tryParse(_expectedController.text.replaceAll(',', '.')) ?? 0;
  double get _actual =>
      double.tryParse(_actualController.text.replaceAll(',', '.')) ?? 0;
  bool get _canSave =>
      _sourceController.text.trim().isNotEmpty && _expected > 0;

  @override
  void dispose() {
    _sourceController.dispose();
    _expectedController.dispose();
    _actualController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      NewIncome(
        label: _sourceController.text.trim(),
        expected: _expected,
        actual: _actualController.text.trim().isEmpty ? _expected : _actual,
        received: _received,
        accountKey: _accountKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(26),
            bottom: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add income', style: titleStyle),
                        const SizedBox(height: 3),
                        const Text(
                          'Record money received this month',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('SOURCE', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _sourceController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'e.g. Salary, allowance, refund',
                  filled: true,
                  fillColor: AppColors.panel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('EXPECTED AMOUNT', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _expectedController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixText: '€ ',
                  hintText: '0,00',
                  filled: true,
                  fillColor: AppColors.panel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('ACTUAL AMOUNT', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _actualController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixText: '€ ',
                  hintText: 'Leave empty to match expected',
                  filled: true,
                  fillColor: AppColors.panel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ToggleRow(
                label: 'Received',
                value: _received,
                onChanged: (value) => setState(() => _received = value),
              ),
              const SizedBox(height: 14),
              AccountChoiceSegmented(
                label: _received ? 'Received in' : 'Expected in',
                selectedKey: _accountKey,
                onChanged: (accountKey) =>
                    setState(() => _accountKey = accountKey),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.line,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('Add income'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IncomeEditSheet extends StatefulWidget {
  const IncomeEditSheet({super.key, required this.income});

  final IncomeItem income;

  @override
  State<IncomeEditSheet> createState() => _IncomeEditSheetState();
}

class _IncomeEditSheetState extends State<IncomeEditSheet> {
  late final _expectedController = TextEditingController(
    text: decimalText(widget.income.expected),
  );
  late final _actualController = TextEditingController(
    text: decimalText(widget.income.actual),
  );
  late bool _received = widget.income.received;
  late String _accountKey = widget.income.accountKey;

  double get _expected =>
      double.tryParse(_expectedController.text.replaceAll(',', '.')) ?? 0;
  double get _actual =>
      double.tryParse(_actualController.text.replaceAll(',', '.')) ?? 0;
  bool get _canSave => _expected > 0;

  @override
  void dispose() {
    _expectedController.dispose();
    _actualController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      IncomeUpdate(
        expected: _expected,
        actual: _actual,
        received: _received,
        accountKey: _accountKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EditSheetScaffold(
      title: 'Edit income',
      subtitle: widget.income.label,
      actionLabel: 'Save income',
      actionColor: AppColors.green,
      canSave: _canSave,
      onSave: _save,
      children: [
        Text('EXPECTED AMOUNT', style: labelStyle),
        const SizedBox(height: 8),
        MoneyTextField(
          controller: _expectedController,
          hintText: '0,00',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        Text('ACTUAL AMOUNT', style: labelStyle),
        const SizedBox(height: 8),
        MoneyTextField(
          controller: _actualController,
          hintText: '0,00',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        ToggleRow(
          label: 'Received',
          value: _received,
          onChanged: (value) => setState(() => _received = value),
        ),
        const SizedBox(height: 14),
        AccountChoiceSegmented(
          label: _received ? 'Received in' : 'Expected in',
          selectedKey: _accountKey,
          onChanged: (accountKey) => setState(() => _accountKey = accountKey),
        ),
      ],
    );
  }
}

class ExpenseEditSheet extends StatefulWidget {
  const ExpenseEditSheet({super.key, required this.meta, required this.item});

  final CategoryMeta meta;
  final ExpenseItem item;

  @override
  State<ExpenseEditSheet> createState() => _ExpenseEditSheetState();
}

class _ExpenseEditSheetState extends State<ExpenseEditSheet> {
  late final _amountController = TextEditingController(
    text: decimalText(widget.item.amount),
  );
  late final _markerController = TextEditingController(
    text: widget.item.marker,
  );
  late final _untilController = TextEditingController(
    text: widget.item.untilLabel ?? '',
  );
  late bool _paid = widget.item.paid;
  late String _accountKey = widget.item.accountKey;

  double get _amount =>
      double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
  bool get _canSave => _amount > 0 && _markerController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _amountController.dispose();
    _markerController.dispose();
    _untilController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      ExpenseUpdate(
        amount: _amount,
        marker: _markerController.text.trim(),
        paid: _paid,
        accountKey: _accountKey,
        until: _untilController.text.trim().isEmpty
            ? null
            : _untilController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EditSheetScaffold(
      title: 'Edit item',
      subtitle: widget.item.label,
      actionLabel: 'Save item',
      actionColor: AppColors.indigo,
      canSave: _canSave,
      onSave: _save,
      children: [
        Text('AMOUNT', style: labelStyle),
        const SizedBox(height: 8),
        MoneyTextField(
          controller: _amountController,
          hintText: '0,00',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        Text('PAYMENT DATE', style: labelStyle),
        const SizedBox(height: 8),
        TextField(
          controller: _markerController,
          onChanged: (_) => setState(() {}),
          decoration: fieldDecoration('e.g. today, 15, 15-06'),
        ),
        if (widget.meta.hasUntil) ...[
          const SizedBox(height: 14),
          Text('DEBT END DATE', style: labelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: _untilController,
            decoration: fieldDecoration('MM-YY, e.g. 12-27'),
          ),
        ],
        const SizedBox(height: 14),
        ToggleRow(
          label: widget.meta.key == 'savings' ? 'Saved' : 'Paid',
          value: _paid,
          onChanged: (value) => setState(() => _paid = value),
        ),
        const SizedBox(height: 14),
        AccountChoiceSegmented(
          label: widget.meta.key == 'savings' ? 'Saved from' : 'Paid from',
          selectedKey: _accountKey,
          onChanged: (accountKey) => setState(() => _accountKey = accountKey),
        ),
      ],
    );
  }
}

class QuickEntrySheet extends StatefulWidget {
  const QuickEntrySheet({super.key, required this.month});

  static const newItemId = '__new';
  final MonthBudget month;

  @override
  State<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<QuickEntrySheet> {
  int _step = 1;
  CategoryMeta? _category;
  ExpenseItem? _item;
  final _amountController = TextEditingController();
  final _markerController = TextEditingController(text: 'today');
  final _untilController = TextEditingController();
  String _label = '';
  String _accountKey = defaultAccountKey;

  double get _amount =>
      double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;

  bool get _canSave {
    if (_amount <= 0 || _category == null) return false;
    if (_item == null && _label.trim().isEmpty) return false;
    return true;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _markerController.dispose();
    _untilController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_canSave || _category == null) return;
    Navigator.of(context).pop(
      QuickExpense(
        categoryKey: _category!.key,
        itemId: _item?.id ?? QuickEntrySheet.newItemId,
        label: _label,
        amount: _amount,
        accountKey: _accountKey,
        marker: _markerController.text.trim().isEmpty
            ? 'today'
            : _markerController.text.trim(),
        until: _untilController.text.trim().isEmpty
            ? null
            : _untilController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxSheetHeight = MediaQuery.sizeOf(context).height - 18;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(26),
                bottom: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + viewInsets.bottom),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _step == 1
                      ? _categoryStep()
                      : _step == 2
                      ? _itemStep()
                      : _amountStep(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetHeader(String title, String subtitle, {bool back = false}) {
    return Row(
      children: [
        if (back) ...[
          IconButton.filledTonal(
            onPressed: () => setState(() => _step = math.max(1, _step - 1)),
            icon: const Icon(Icons.arrow_back_rounded),
            iconSize: 18,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle.copyWith(fontSize: 18)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          iconSize: 18,
        ),
      ],
    );
  }

  Widget _categoryStep() {
    return Column(
      key: const ValueKey('category'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 5,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.line,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        _sheetHeader('Log an expense', 'Pick a category'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: .96,
          children: categoryMeta.map((meta) {
            return InkWell(
              onTap: () => setState(() {
                _category = meta;
                _step = 2;
              }),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                decoration: cardDecoration(radius: 15),
                padding: const EdgeInsets.all(9),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ToneIcon(
                      icon: meta.icon,
                      tone: meta.tone,
                      background: meta.background,
                      size: 42,
                      iconSize: 20,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      meta.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _itemStep() {
    final category = _category!;
    final rows = widget.month.expenses[category.key] ?? [];
    return Column(
      key: const ValueKey('item'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeader(category.title, 'Choose item or add new', back: true),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: rows.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 7),
            itemBuilder: (context, index) {
              if (index == rows.length) {
                return DashedAction(
                  color: category.tone,
                  onTap: () => setState(() {
                    _item = null;
                    _accountKey = defaultAccountKey;
                    _markerController.text = 'today';
                    _untilController.clear();
                    _step = 3;
                  }),
                );
              }
              final row = rows[index];
              return InkWell(
                onTap: () => setState(() {
                  _item = row;
                  _accountKey = row.accountKey;
                  _markerController.text = row.marker;
                  _untilController.text = row.untilLabel ?? '';
                  _step = 3;
                }),
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  decoration: cardDecoration(radius: 13),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: itemStyle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatEuro(row.amount),
                        style: moneyStyle.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _amountStep() {
    final category = _category!;
    final newItem = _item == null;
    return Column(
      key: const ValueKey('amount'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeader(
          category.title,
          newItem ? 'New item' : _item!.label,
          back: true,
        ),
        const SizedBox(height: 12),
        if (newItem)
          TextField(
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Item name',
              filled: true,
              fillColor: AppColors.panel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
            onChanged: (value) => setState(() => _label = value),
          ),
        const SizedBox(height: 16),
        AccountChoiceSegmented(
          label: newItem ? 'Spent from' : 'Add spend from',
          selectedKey: _accountKey,
          onChanged: (accountKey) => setState(() => _accountKey = accountKey),
        ),
        const SizedBox(height: 16),
        Text('PAYMENT DATE', style: labelStyle),
        const SizedBox(height: 8),
        TextField(
          controller: _markerController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'e.g. today, 15, 15-06',
            filled: true,
            fillColor: AppColors.panel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: AppColors.line),
            ),
          ),
        ),
        if (category.hasUntil) ...[
          const SizedBox(height: 16),
          Text('DEBT END DATE', style: labelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: _untilController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'MM-YY, e.g. 12-27',
              filled: true,
              fillColor: AppColors.panel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('AMOUNT', style: labelStyle),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          autofocus: !newItem,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            prefixText: '€ ',
            hintText: '0,00',
            filled: true,
            fillColor: AppColors.panel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: AppColors.line),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canSave ? _save : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.indigo,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.line,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Text('Add expense'),
          ),
        ),
      ],
    );
  }
}
