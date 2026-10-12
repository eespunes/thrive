import 'package:family_money_management_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Untouched recurring copies are not stored in the cloud
// (`isDerivedSeriesCopy`); loading the stored records and running the series
// sync must bring them back exactly, without any further write.
void main() {
  testWidgets('derived recurring copies are regenerated after a cloud load', (
    tester,
  ) async {
    await pumpApp(tester);
    final anchor = ExpenseItem.fromJson({
      'id': 'rent',
      'label': 'Rent',
      'amount': 900,
      'account': 'shared',
      'recurring': true,
      'day': 1,
    });
    final ws = Workspace(
      accounts: defaultAccounts(),
      cats: defaultCats(),
      data: {
        2026: {
          for (final m in ['Augustus', 'September', 'Oktober', 'November'])
            m: MonthData()..blocks['home'] = [],
        },
      },
    );
    ws.data[2026]!['Augustus']!.blocks['home']!.add(anchor);
    thriveDebug.syncRecurringSeries(ws);
    // A paid copy is real state and stays stored.
    ws.data[2026]!['Oktober']!.blocks['home']!.single.paid = true;

    final stored = normalizedRecords(ws);
    final budgetKeys = stored.keys.where((k) => k.startsWith('budgetItems/'));
    expect(budgetKeys, hasLength(2)); // the anchor + the paid copy

    final loaded = thriveDebug.syncRecurringSeries(
      workspaceFromRecords(stored),
    );
    for (final m in ['September', 'Oktober', 'November']) {
      final items = loaded.data[2026]![m]!.blocks['home']!;
      expect(items, hasLength(1), reason: m);
      expect(items.single.label, 'Rent');
      expect(items.single.generated, isTrue);
      expect(items.single.paid, m == 'Oktober');
    }
    final replan = planRecordWrites(stored, normalizedRecords(loaded));
    expect(replan.creates, isEmpty);
    expect(replan.updates, isEmpty);
    expect(replan.deletes, isEmpty);
  });
}
