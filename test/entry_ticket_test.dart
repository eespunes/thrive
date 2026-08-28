import 'package:family_money_management_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('amount parsing & errors (#287)', () {
    test('comma decimals parse', () {
      expect(parseEntryAmount('45,'), 45);
      expect(parseEntryAmount('45,5'), 45.5);
      expect(parseEntryAmount('1.250,00'), 1250);
    });

    test('every invalid state blocks save with a visible reason', () {
      expect(entryAmountError(''), 'Give it an amount.');
      expect(entryAmountError('abc'), contains('Numbers only'));
      expect(entryAmountError('-5'), contains("can't be negative"));
      expect(entryAmountError('0'), contains('€0 would be skipped'));
      expect(entryAmountError('12,50'), isNull);
    });
  });

  group('adaptive labels (#286)', () {
    test('all four strings re-label per direction', () {
      final e = entryWords('expense');
      expect(e.payeePh, 'Company');
      expect(e.dayHead, 'Pay day');
      expect(e.paid, 'Paid');
      expect(e.accHead, 'Pay from');

      final i = entryWords('income');
      expect(i.payeePh, 'From');
      expect(i.dayHead, 'Date');
      expect(i.paid, 'Received');
      expect(i.accHead, 'Received into');

      final s = entryWords('savings');
      expect(s.paid, 'Saved');
      expect(s.accHead, 'Save from');
    });
  });

  group('weekend shift, bounded (#289)', () {
    test('Sat/Sun day 1 with Fri-before stays put', () {
      // 1 Aug 2026 is a Saturday; shifting before would leave August.
      final r = resolveMoneyDay(1, 'before', 2026, 7);
      expect(r.day, 1);
      expect(r.movedFrom, isNull);
    });

    test('last-day weekend with Mon-after stays put', () {
      // 31 May 2026 is a Sunday; shifting after would leave May.
      final r = resolveMoneyDay(31, 'after', 2026, 4);
      expect(r.day, 31);
      expect(r.movedFrom, isNull);
    });

    test('a shifted day clears the whole weekend', () {
      // 23 Aug 2026 is a Sunday → Fri before lands on the 21st.
      final r = resolveMoneyDay(23, 'before', 2026, 7);
      expect(r.day, 21);
      expect(r.movedFrom, 23);
    });

    test('Feb entry with day 31 posts on the last day (#288)', () {
      final r = resolveMoneyDay(31, 'none', 2026, 1);
      expect(r.day, 28);
    });
  });

  group('repeat maths (#291)', () {
    test('recurEvery bounds are enforced on load', () {
      final it = ExpenseItem.fromJson({
        'id': 'a',
        'label': 'x',
        'marker': '1st',
        'amount': 1,
        'paid': false,
        'account': 'shared',
        'recurEvery': 99,
      });
      expect(it.recurEvery, 60);
    });

    test('last occurrence is floor((end-anchor)/every)*every from anchor', () {
      // Every 3 months anchored Aug 2026 (ord 24319) ending Oct → last Aug.
      const anchor = 2026 * 12 + 7;
      expect(lastChargedMonthOrd(anchor, anchor + 2, 3), anchor);
      expect(lastChargedMonthOrd(anchor, anchor + 3, 3), anchor + 3);
      expect(lastChargedMonthOrd(anchor, anchor - 1, 3), isNull);
    });

    test('summary spells out cadence, day, end and shift', () {
      const anchor = 2026 * 12 + 7;
      final s = entryRecurSummary(
        recurring: true,
        every: 2,
        day: 24,
        shift: 'before',
        anchorOrd: anchor,
        endOrd: 2026 * 12 + 11,
      );
      expect(s, contains('every 2 months'));
      expect(s, contains('on the 24th'));
      expect(s, contains('until Dec 2026'));
      expect(s, contains('Friday before'));
    });

    test('end before the open month reads as an error', () {
      const anchor = 2026 * 12 + 7;
      final s = entryRecurSummary(
        recurring: true,
        every: 1,
        day: 1,
        shift: 'none',
        anchorOrd: anchor,
        endOrd: anchor - 2,
      );
      expect(s, contains('before August'));
    });
  });

  group('marker → day migration (#288/#290)', () {
    ExpenseItem load(Map<String, dynamic> j) => ExpenseItem.fromJson({
      'id': 'x',
      'label': 'x',
      'amount': 1,
      'paid': false,
      'account': 'shared',
      ...j,
    });

    test('legacy markers parse to a day int', () {
      expect(load({'marker': '24th'}).day, 24);
      expect(load({'marker': '1st'}).day, 1);
    });

    test('unparseable markers become unscheduled', () {
      expect(load({'marker': '-'}).day, isNull);
      expect(load({'marker': ''}).day, isNull);
    });

    test('an explicit null day round-trips as unscheduled, not legacy', () {
      final back = load(load({'marker': '24th', 'day': null}).toJson());
      expect(back.day, isNull);
      expect(back.legacyDay, isFalse);
    });

    test('legacy dayless income keeps day 1, flagged for review once', () {
      final cats = [defaultIncomeCat()];
      final income = load({'marker': ''});
      final expense = load({'marker': ''});
      final data = {
        2026: {
          kMonthKeys[7]: MonthData(
            blocks: {
              kIncomeBlockKey: [income],
              'food': [expense],
            },
          ),
        },
      };
      migrateDaylessIncome(cats, data);
      expect(income.day, 1);
      expect(income.reviewDay, isTrue);
      // Expenses stay genuinely unscheduled.
      expect(expense.day, isNull);
      // Post-migration explicit unscheduled income is left alone.
      final chosen = load({'marker': '', 'day': null});
      data[2026]![kMonthKeys[7]]!.blocks[kIncomeBlockKey]!.add(chosen);
      migrateDaylessIncome(cats, data);
      expect(chosen.day, isNull);
    });
  });

  group('scope & attribution fields (#292/#293/#300)', () {
    test('exception and createdBy/createdAt sync like the rest', () {
      final it = ExpenseItem(
        id: 'a',
        label: 'Netflix',
        marker: '30th',
        day: 30,
        amount: 20.99,
        paid: false,
        account: 'eva',
        createdBy: 'm1',
        createdAt: '2026-08-12',
      )..exception = true;
      final back = ExpenseItem.fromJson(it.toJson());
      expect(back.exception, isTrue);
      expect(back.createdBy, 'm1');
      expect(back.createdAt, '2026-08-12');
      expect(back.day, 30);
    });

    test('pre-migration entries have no attribution, without breakage', () {
      final it = ExpenseItem.fromJson({
        'id': 'a',
        'label': 'x',
        'marker': '1st',
        'amount': 1,
        'paid': false,
        'account': 'shared',
      });
      expect(it.createdBy, isNull);
      expect(it.createdAt, isNull);
    });

    test('seriesSkips round-trip on MonthData', () {
      final m = MonthData(seriesSkips: ['s1']);
      final back = MonthData.fromJson(m.toJson());
      expect(back.seriesSkips, ['s1']);
    });
  });
}
