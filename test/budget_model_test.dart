import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    accountMeta
      ..clear()
      ..addAll(defaultAccountMeta);
    categoryMeta
      ..clear()
      ..addAll(defaultCategoryMeta);
  });

  group('number and text helpers', () {
    test('asDouble accepts numbers, decimal commas, and invalid values', () {
      expect(asDouble(12), 12);
      expect(asDouble(12.5), 12.5);
      expect(asDouble('12,75'), 12.75);
      expect(asDouble('not money'), 0);
      expect(asDouble(null), 0);
    });

    test('stringValue trims text and falls back for empty input', () {
      expect(stringValue('  Salary  ', fallback: 'Fallback'), 'Salary');
      expect(stringValue('', fallback: 'Fallback'), 'Fallback');
      expect(stringValue(null, fallback: 'Fallback'), 'Fallback');
    });

    test('uniqueKeyFor creates stable safe keys and avoids duplicates', () {
      expect(uniqueKeyFor('Family Car', const []), 'family_car');
      expect(uniqueKeyFor('!!!', const []), 'item');
      expect(
        uniqueKeyFor('Family Car', const ['family_car', 'family_car_2']),
        'family_car_3',
      );
    });

    test('account labels are shortened and initialed consistently', () {
      expect(shortNameFor('Shared savings account'), 'Shared');
      expect(initialsFor('Eva Dones'), 'ED');
      expect(initialsFor('Erik'), 'ER');
      expect(initialsFor(''), 'AC');
    });
  });

  group('money and date helpers', () {
    test('formatEuro and signedEuro use Dutch-style currency formatting', () {
      expect(formatEuro(4402), '€ 4.402,00');
      expect(formatEuro(-139.27), '-€ 139,27');
      expect(formatEuro(4541, cents: false), '€ 4.541');
      expect(signedEuro(50.08), '+50,08');
      expect(signedEuro(-50.08), '-50,08');
      expect(signedEuro(0), '-');
    });

    test('greetingForHour follows morning, afternoon, evening boundaries', () {
      expect(greetingForHour(0), 'Good morning');
      expect(greetingForHour(11), 'Good morning');
      expect(greetingForHour(12), 'Good afternoon');
      expect(greetingForHour(17), 'Good afternoon');
      expect(greetingForHour(18), 'Good evening');
      expect(greetingForHour(23), 'Good evening');
    });

    test('until labels and states classify ended, soon, and future dates', () {
      expect(untilLabel(' 07-26 '), '07-26');
      expect(untilLabel(46205), '07-26');
      expect(untilLabel(null), isNull);
      expect(untilLabel(0), isNull);

      expect(untilState('05-26', 5, 2026), UntilState.ended);
      expect(untilState('06-26', 5, 2026), UntilState.soon);
      expect(untilState('12-26', 5, 2026), UntilState.soon);
      expect(untilState('01-27', 5, 2026), UntilState.future);
      expect(untilState('bad', 5, 2026), UntilState.future);
    });
  });

  group('accounts and categories', () {
    test('normalizes known account keys and falls back for unknown keys', () {
      expect(normalizedAccountKey(' EVA '), 'eva');
      expect(normalizedAccountKey('missing'), defaultAccountKey);
      expect(normalizedAccountKey('missing', fallback: 'erik'), 'erik');
    });

    test('defaultExpenseAccountKey respects paid state and sum-up hints', () {
      expect(defaultExpenseAccountKey({'paid': true}, {}), defaultAccountKey);
      expect(defaultExpenseAccountKey({}, {"FROM EVA'S ACCOUNT": 10}), 'eva');
      expect(defaultExpenseAccountKey({}, {"FROM ERIK'S ACCOUNT": 10}), 'erik');
      expect(
        defaultExpenseAccountKey({}, {'FROM SHARED ACCOUNT': 10}),
        'shared',
      );
      expect(defaultExpenseAccountKey({}, {}), defaultAccountKey);
    });

    test('state objects round-trip through serialized maps', () {
      const account = AccountMeta(
        key: 'holiday',
        name: 'Holiday savings',
        shortName: 'Holiday',
        initials: 'HS',
        color: AppColors.teal,
      );
      final restoredAccount = AccountMeta.fromState(account.toState());
      expect(restoredAccount.key, account.key);
      expect(restoredAccount.name, account.name);
      expect(restoredAccount.initials, account.initials);
      expect(restoredAccount.color, account.color);

      const category = CategoryMeta(
        key: 'transport',
        title: 'Transport',
        icon: Icons.directions_car_rounded,
        markerKey: 'date',
        tone: AppColors.indigo,
        background: AppColors.panel,
      );
      final restoredCategory = CategoryMeta.fromState(category.toState());
      expect(restoredCategory.key, category.key);
      expect(restoredCategory.title, category.title);
      expect(restoredCategory.markerKey, category.markerKey);
      expect(restoredCategory.tone, category.tone);
    });
  });

  group('budget serialization and calculations', () {
    test(
      'MonthBudget parses income, expenses, defaults, and serializes back',
      () {
        final month = MonthBudget.fromJson('Juni', {
          'sumup': {"FROM EVA'S ACCOUNT": 25},
          'income': [
            {
              'label': 'Salary',
              'expected': '1000,50',
              'actual': 900,
              'received': true,
              'account': 'eva',
            },
            {
              'label': 'Bonus',
              'expected': 100,
              'actual': 100,
              'received': false,
              'account': 'unknown',
            },
          ],
          'home': [
            {'label': 'Rent', 'day': '01', 'amount': 750, 'paid': false},
          ],
          'debt': [
            {
              'label': 'Loan',
              'day': '15',
              'amount': '50,25',
              'paid': true,
              'account': 'erik',
              'until': '07-26',
            },
          ],
        });

        expect(month.income, hasLength(2));
        expect(month.income.first.label, 'Salary');
        expect(month.income.first.accountKey, 'eva');
        expect(month.income.last.accountKey, defaultAccountKey);
        expect(month.expenses['home']!.single.accountKey, 'eva');
        expect(month.expenses['debt']!.single.amount, 50.25);

        final json = month.toJson();
        expect(json['income'], hasLength(2));
        expect(json['home'], hasLength(1));
        expect(json['debt'], hasLength(1));
        expect(json['sumup'], {"FROM EVA'S ACCOUNT": 25.0});
      },
    );

    test(
      'ComputedMonth totals income, expenses, balance, and account shares',
      () {
        final month = MonthBudget(
          key: 'Juni',
          income: [
            IncomeItem(
              id: 'salary',
              label: 'Salary',
              expected: 1000,
              actual: 950,
              received: true,
              accountKey: 'eva',
            ),
            IncomeItem(
              id: 'bonus',
              label: 'Bonus',
              expected: 100,
              actual: 100,
              received: false,
              accountKey: 'shared',
            ),
          ],
          expenses: {
            for (final meta in categoryMeta) meta.key: <ExpenseItem>[],
            'home': [
              ExpenseItem(
                id: 'rent',
                label: 'Rent',
                marker: '01',
                amount: 700,
                paid: true,
                accountKey: 'shared',
              ),
              ExpenseItem(
                id: 'energy',
                label: 'Energy',
                marker: '02',
                amount: 80,
                paid: false,
                accountKey: 'eva',
              ),
            ],
            'food': [
              ExpenseItem(
                id: 'groceries',
                label: 'Groceries',
                marker: '10',
                amount: 120,
                paid: false,
                accountKey: 'erik',
              ),
            ],
          },
          sumup: {},
        );

        final computed = ComputedMonth(month, 5, 2026);

        expect(computed.monthLabel, 'June');
        expect(computed.expectedIncome, 1100);
        expect(computed.realIncome, 950);
        expect(computed.totalBudget, 900);
        expect(computed.totalPaid, 700);
        expect(computed.stillToPay, 200);
        expect(computed.expectedBalance, 200);
        expect(computed.balance, 50);

        final eva = computed.accounts.singleWhere(
          (account) => account.account.key == 'eva',
        );
        final erik = computed.accounts.singleWhere(
          (account) => account.account.key == 'erik',
        );
        final shared = computed.accounts.singleWhere(
          (account) => account.account.key == 'shared',
        );
        expect(eva.amount, 80);
        expect(erik.amount, 120);
        expect(shared.amount, 0);
        expect(erik.progress, 1);
        expect(eva.progress, closeTo(80 / 120, .001));
      },
    );

    test('ExpenseBlock computes paid progress and until state', () {
      const meta = CategoryMeta(
        key: 'debt',
        title: 'Debt',
        icon: Icons.credit_card_rounded,
        markerKey: 'day',
        tone: AppColors.red,
        background: AppColors.panel,
        hasUntil: true,
      );
      final block = ExpenseBlock(
        meta: meta,
        monthIndex: 5,
        year: 2026,
        items: [
          ExpenseItem(
            id: 'loan',
            label: 'Loan',
            marker: '15',
            amount: 100,
            paid: true,
            accountKey: 'shared',
            untilRaw: '07-26',
          ),
          ExpenseItem(
            id: 'card',
            label: 'Card',
            marker: '20',
            amount: 300,
            paid: false,
            accountKey: 'eva',
            untilRaw: '02-27',
          ),
        ],
      );

      expect(block.total, 400);
      expect(block.paid, 100);
      expect(block.progress, .25);
      expect(block.items.first.untilLabel, '07-26');
      expect(block.items.first.untilState, UntilState.soon);
      expect(block.items.last.untilState, UntilState.future);
    });

    test('monthsFromState and emptyYearBudget always expose all months', () {
      final months = monthsFromState({
        'Juni': {
          'income': [
            {'label': 'Salary', 'expected': 1, 'actual': 1},
          ],
        },
      });
      final emptyYear = emptyYearBudget(2027);

      expect(months.keys, containsAll(monthKeys));
      expect(months['Juni']!.income.single.label, 'Salary');
      expect(months['Januari']!.income, isEmpty);
      expect(emptyYear.keys, containsAll(monthKeys));
      expect(
        emptyYear['Juni']!.expenses.keys,
        containsAll(categoryMeta.map((m) => m.key)),
      );
    });
  });
}
