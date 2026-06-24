import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('models', () {
    test('default accounts and categories are seeded', () {
      expect(defaultAccounts(), isNotEmpty);
      expect(defaultCats(), isNotEmpty);
    });

    test('Account round-trips through JSON', () {
      final a = Account(
        key: 'eva',
        name: "Eva's account",
        short: 'Eva',
        initials: 'EV',
        color: const Color(0xff0E9A8D),
      );
      final back = Account.fromJson(a.toJson());
      expect(back.key, a.key);
      expect(back.name, a.name);
      expect(back.short, a.short);
      expect(back.initials, a.initials);
      expect(back.color.toARGB32(), a.color.toARGB32());
    });

    test('Category preserves temporary ownership through JSON', () {
      final c = Category(
        key: 'holiday',
        title: 'Holiday',
        icon: 'sun',
        marker: 'date',
        tone: const Color(0xff2563eb),
        bg: tintFor(const Color(0xff2563eb)),
        temporary: true,
        ownerYear: 2026,
        ownerMonthIdx: 5,
      );
      final back = Category.fromJson(c.toJson());
      expect(back.temporary, isTrue);
      expect(back.ownerYear, 2026);
      expect(back.ownerMonthIdx, 5);
    });

    test('MonthData keeps snapshots and closed flag', () {
      final m = MonthData(closed: true);
      m.catsSnapshot = defaultCats();
      m.accountsSnapshot = defaultAccounts();
      final back = MonthData.fromJson(m.toJson());
      expect(back.closed, isTrue);
      expect(back.catsSnapshot, isNotNull);
      expect(back.accountsSnapshot, isNotNull);
    });

    test('ExpenseItem copyWithId assigns a new id', () {
      final it = ExpenseItem(
        id: 'a',
        label: 'Groceries',
        marker: '1st',
        amount: 42.5,
        paid: false,
        account: 'shared',
      );
      final copy = it.copyWithId('b');
      expect(copy.id, 'b');
      expect(copy.label, it.label);
      expect(copy.amount, it.amount);
    });
  });

  group('utils', () {
    test('parseNum handles comma decimals', () {
      expect(parseNum('1234,50'), closeTo(1234.5, 0.001));
      expect(parseNum('10'), 10);
      expect(parseNum('-'), 0);
    });

    test('eur formats euro amounts', () {
      expect(eur(0), contains('0'));
      expect(eur(1234.5), contains('1'));
    });

    test('untilLabel normalizes to MM-YY', () {
      expect(untilLabel('12-28'), '12-28');
    });
  });
}
