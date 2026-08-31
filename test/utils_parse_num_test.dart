import 'package:family_money_management_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseNum', () {
    test('handles null, empty and non-numeric input', () {
      expect(parseNum(null), 0);
      expect(parseNum(''), 0);
      expect(parseNum('  '), 0);
      expect(parseNum('-'), 0);
      expect(parseNum('abc'), 0);
      expect(parseNum(double.nan), 0);
    });

    test('passes through nums', () {
      expect(parseNum(12), 12.0);
      expect(parseNum(12.5), 12.5);
      expect(parseNum(-3), -3.0);
    });

    test('single separator', () {
      expect(parseNum('12.5'), 12.5);
      expect(parseNum('12,5'), 12.5);
      expect(parseNum('1.234'), 1.234);
      expect(parseNum('1,234'), 1.234);
      expect(parseNum('-7,25'), -7.25);
    });

    test('both separators: last one is the decimal separator', () {
      expect(parseNum('1.234,56'), 1234.56);
      expect(parseNum('1,234.56'), 1234.56);
      expect(parseNum('1.234.567,89'), 1234567.89);
      expect(parseNum('1,234,567.89'), 1234567.89);
    });
  });
}
