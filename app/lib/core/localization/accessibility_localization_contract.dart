import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

class AccessibilityNodeSnapshot {
  const AccessibilityNodeSnapshot({
    required this.nodeId,
    required this.role,
    required this.label,
    required this.contrastRatio,
    required this.fontScale,
  });

  final String nodeId;
  final String role;
  final String label;
  final double contrastRatio;
  final double fontScale;
}

class LocalizationSettings {
  const LocalizationSettings({
    required this.locale,
    required this.currencyCode,
    required this.timezoneOffset,
  });

  final String locale;
  final String currencyCode;
  final String timezoneOffset;
}

class CurrencyFormatResult {
  const CurrencyFormatResult({
    required this.formatted,
    required this.decimalDigits,
  });

  final String formatted;
  final int decimalDigits;
}

class TimezoneMonthBounds {
  const TimezoneMonthBounds({required this.utcStart, required this.utcEnd});

  final DateTime utcStart;
  final DateTime utcEnd;
}

class AccessibilityLocalizationContract {
  AccessibilityLocalizationContract({required AppLogger logger})
    : _logger = logger;

  static const Set<String> supportedLocales = <String>{
    'en_US',
    'en_GB',
    'es_ES',
  };

  final AppLogger _logger;

  AppResult<void> validateAccessibilityBaseline(
    List<AccessibilityNodeSnapshot> nodes,
  ) {
    if (nodes.isEmpty) {
      return _failure(
        code: 'accessibility_nodes_missing',
        developerMessage: 'Accessibility node snapshot cannot be empty.',
        userMessage: 'Could not validate accessibility right now.',
      );
    }

    for (final node in nodes) {
      if (node.nodeId.trim().isEmpty ||
          node.role.trim().isEmpty ||
          node.label.trim().isEmpty ||
          node.contrastRatio < 4.5 ||
          node.fontScale < 1) {
        return _failure(
          code: 'accessibility_baseline_failed',
          developerMessage:
              'Node ${node.nodeId} failed semantics/contrast/font baseline checks.',
          userMessage: 'Some accessibility settings require attention.',
        );
      }
    }

    _logger.info(
      code: 'accessibility_baseline_validated',
      message: 'Accessibility baseline validated successfully',
      metadata: <String, Object?>{'nodeCount': nodes.length},
    );
    return const AppSuccess<void>(null);
  }

  AppResult<LocalizationSettings> resolveLocalization(
    LocalizationSettings settings,
  ) {
    if (!supportedLocales.contains(settings.locale)) {
      return AppFailure<LocalizationSettings>(
        FailureDetail(
          code: 'localization_locale_unsupported',
          developerMessage: 'Locale ${settings.locale} is not supported.',
          userMessage: 'Selected language is not supported right now.',
          recoverable: true,
        ),
      );
    }

    if (!RegExp(r'^[A-Z]{3}$').hasMatch(settings.currencyCode)) {
      return AppFailure<LocalizationSettings>(
        FailureDetail(
          code: 'localization_currency_invalid',
          developerMessage:
              'Currency code ${settings.currencyCode} is invalid.',
          userMessage: 'Selected currency is invalid.',
          recoverable: true,
        ),
      );
    }

    final offset = _parseOffset(settings.timezoneOffset);
    if (offset == null) {
      return AppFailure<LocalizationSettings>(
        FailureDetail(
          code: 'localization_timezone_invalid',
          developerMessage:
              'Timezone offset ${settings.timezoneOffset} is invalid.',
          userMessage: 'Selected timezone is invalid.',
          recoverable: true,
        ),
      );
    }

    _logger.info(
      code: 'localization_settings_resolved',
      message: 'Localization settings resolved',
      metadata: <String, Object?>{
        'locale': settings.locale,
        'currencyCode': settings.currencyCode,
        'timezoneOffset': settings.timezoneOffset,
      },
    );

    return AppSuccess<LocalizationSettings>(settings);
  }

  AppResult<CurrencyFormatResult> formatCurrency({
    required int amountMinor,
    required String locale,
    required String currencyCode,
  }) {
    final settingsResult = resolveLocalization(
      LocalizationSettings(
        locale: locale,
        currencyCode: currencyCode,
        timezoneOffset: '+00:00',
      ),
    );
    if (settingsResult is AppFailure<LocalizationSettings>) {
      return AppFailure<CurrencyFormatResult>(settingsResult.detail);
    }

    final decimalDigits = (currencyCode == 'JPY' || currencyCode == 'KRW')
        ? 0
        : 2;
    final unit = decimalDigits == 0 ? 1 : 100;
    final sign = amountMinor < 0 ? '-' : '';
    final absolute = amountMinor.abs();
    final major = absolute ~/ unit;
    final minor = absolute % unit;

    final groupingSeparator = locale == 'es_ES' ? '.' : ',';
    final decimalSeparator = locale == 'es_ES' ? ',' : '.';

    final groupedMajor = _groupDigits(major.toString(), groupingSeparator);
    final formattedNumber = decimalDigits == 0
        ? groupedMajor
        : '$groupedMajor$decimalSeparator${minor.toString().padLeft(decimalDigits, '0')}';

    final symbol = _currencySymbols[currencyCode] ?? currencyCode;
    final formatted = locale == 'es_ES'
        ? '$sign$formattedNumber $symbol'
        : '$sign$symbol$formattedNumber';

    return AppSuccess<CurrencyFormatResult>(
      CurrencyFormatResult(formatted: formatted, decimalDigits: decimalDigits),
    );
  }

  AppResult<TimezoneMonthBounds> computeMonthBoundsInTimezone({
    required DateTime utcInstant,
    required String timezoneOffset,
  }) {
    final offset = _parseOffset(timezoneOffset);
    if (offset == null) {
      return AppFailure<TimezoneMonthBounds>(
        FailureDetail(
          code: 'timezone_offset_invalid',
          developerMessage: 'Invalid timezone offset: $timezoneOffset',
          userMessage: 'Could not compute date range for this timezone.',
          recoverable: true,
        ),
      );
    }

    final localPseudoUtc = DateTime.fromMillisecondsSinceEpoch(
      utcInstant.toUtc().millisecondsSinceEpoch + offset.inMilliseconds,
      isUtc: true,
    );
    final startLocalPseudoUtc = DateTime.utc(
      localPseudoUtc.year,
      localPseudoUtc.month,
      1,
    );
    final endLocalPseudoUtc = DateTime.utc(
      localPseudoUtc.year,
      localPseudoUtc.month + 1,
      0,
      23,
      59,
      59,
      999,
    );

    final bounds = TimezoneMonthBounds(
      utcStart: DateTime.fromMillisecondsSinceEpoch(
        startLocalPseudoUtc.millisecondsSinceEpoch - offset.inMilliseconds,
        isUtc: true,
      ),
      utcEnd: DateTime.fromMillisecondsSinceEpoch(
        endLocalPseudoUtc.millisecondsSinceEpoch - offset.inMilliseconds,
        isUtc: true,
      ),
    );

    _logger.info(
      code: 'timezone_month_bounds_computed',
      message: 'Timezone-safe month bounds computed',
      metadata: <String, Object?>{
        'timezoneOffset': timezoneOffset,
        'utcStart': bounds.utcStart.toIso8601String(),
        'utcEnd': bounds.utcEnd.toIso8601String(),
      },
    );
    return AppSuccess<TimezoneMonthBounds>(bounds);
  }

  AppFailure<void> _failure({
    required String code,
    required String developerMessage,
    required String userMessage,
  }) {
    _logger.warning(code: code, message: developerMessage);
    return AppFailure<void>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: userMessage,
        recoverable: true,
      ),
    );
  }

  Duration? _parseOffset(String raw) {
    final match = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(raw.trim());
    if (match == null) {
      return null;
    }

    final sign = match.group(1) == '-' ? -1 : 1;
    final hours = int.tryParse(match.group(2)!);
    final minutes = int.tryParse(match.group(3)!);
    if (hours == null || minutes == null || hours > 14 || minutes > 59) {
      return null;
    }

    return Duration(hours: sign * hours, minutes: sign * minutes);
  }
}

String _groupDigits(String input, String separator) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i += 1) {
    final positionFromRight = input.length - i;
    buffer.write(input[i]);
    if (positionFromRight > 1 && positionFromRight % 3 == 1) {
      buffer.write(separator);
    }
  }
  return buffer.toString();
}

const Map<String, String> _currencySymbols = <String, String>{
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
};
