part of 'package:family_money_management_app/main.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    required this.year,
    required this.monthIndex,
    required this.months,
    required this.allMonths,
    super.key,
  });

  final int year;
  final int monthIndex;
  final Map<String, MonthBudget> months;
  final Iterable<MonthBudget> allMonths;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late int _selectedMonthIndex;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedMonthIndex = widget.monthIndex;
    _selectedYear = widget.year;
  }

  @override
  Widget build(BuildContext context) {
    final monthKey = monthKeys[_selectedMonthIndex];
    final computed = widget.months[monthKey] != null
        ? ComputedMonth(widget.months[monthKey]!, _selectedMonthIndex, _selectedYear)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonthIndex = (_selectedMonthIndex - 1 + monthKeys.length) % monthKeys.length;
                    });
                  },
                  child: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${monthLabels[_selectedMonthIndex]} $_selectedYear',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonthIndex = (_selectedMonthIndex + 1) % monthKeys.length;
                    });
                  },
                  child: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (computed != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Text('Real Income: ${formatEuro(computed.realIncome)}'),
                      Text('Expected Income: ${formatEuro(computed.expectedIncome)}'),
                      Text('Total Budget: ${formatEuro(computed.totalBudget)}'),
                      Text('Total Paid: ${formatEuro(computed.totalPaid)}'),
                      Text('Real Balance: ${formatEuro(computed.balance)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Spending by Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      ...computed.blocks.values.map((block) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(block.meta.title),
                            Text(
                              '${formatEuro(block.total)} (${formatPercent(block.progress * 100)}%)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
