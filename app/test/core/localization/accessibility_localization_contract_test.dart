import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/localization/accessibility_localization_contract.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('accessibility baseline passes with valid semantics and contrast', () {
    final contract = AccessibilityLocalizationContract(
      logger: InMemoryAppLogger(),
    );

    final result = contract
        .validateAccessibilityBaseline(const <AccessibilityNodeSnapshot>[
          AccessibilityNodeSnapshot(
            nodeId: 'title',
            role: 'header',
            label: 'Family dashboard',
            contrastRatio: 7.2,
            fontScale: 1.1,
          ),
        ]);

    expect(result, isA<AppSuccess<void>>());
  });

  test(
    'accessibility baseline fails deterministically when label is missing',
    () {
      final contract = AccessibilityLocalizationContract(
        logger: InMemoryAppLogger(),
      );

      final result = contract
          .validateAccessibilityBaseline(const <AccessibilityNodeSnapshot>[
            AccessibilityNodeSnapshot(
              nodeId: 'cta',
              role: 'button',
              label: '',
              contrastRatio: 5,
              fontScale: 1,
            ),
          ]);

      expect(result, isA<AppFailure<void>>());
      expect(
        (result as AppFailure<void>).detail.code,
        'accessibility_baseline_failed',
      );
    },
  );

  test('formats currency based on locale and currency rules', () {
    final contract = AccessibilityLocalizationContract(
      logger: InMemoryAppLogger(),
    );

    final result = contract.formatCurrency(
      amountMinor: 123456,
      locale: 'es_ES',
      currencyCode: 'EUR',
    );

    expect(result, isA<AppSuccess<CurrencyFormatResult>>());
    final value = (result as AppSuccess<CurrencyFormatResult>).value;
    expect(value.formatted, '1.234,56 €');
  });

  test('computes timezone-safe month bounds for offset', () {
    final contract = AccessibilityLocalizationContract(
      logger: InMemoryAppLogger(),
    );

    final result = contract.computeMonthBoundsInTimezone(
      utcInstant: DateTime.utc(2030, 3, 31, 23, 30),
      timezoneOffset: '+02:00',
    );

    expect(result, isA<AppSuccess<TimezoneMonthBounds>>());
    final bounds = (result as AppSuccess<TimezoneMonthBounds>).value;
    expect(bounds.utcStart, DateTime.utc(2030, 3, 31, 22));
    expect(bounds.utcEnd.year, 2030);
    expect(bounds.utcEnd.month, 4);
  });

  test('fails when unsupported locale is provided', () {
    final contract = AccessibilityLocalizationContract(
      logger: InMemoryAppLogger(),
    );

    final result = contract.resolveLocalization(
      const LocalizationSettings(
        locale: 'fr_FR',
        currencyCode: 'EUR',
        timezoneOffset: '+01:00',
      ),
    );

    expect(result, isA<AppFailure<LocalizationSettings>>());
    expect(
      (result as AppFailure<LocalizationSettings>).detail.code,
      'localization_locale_unsupported',
    );
  });
}
