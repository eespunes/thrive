part of 'package:family_money_management_app/main.dart';

double asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  return 0;
}

String stringValue(Object? value, {required String fallback}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String uniqueKeyFor(String value, Iterable<String> existingKeys) {
  final base =
      value
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '')
          .isEmpty
      ? 'item'
      : value
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), '');
  final existing = existingKeys.toSet();
  if (!existing.contains(base)) return base;
  var index = 2;
  while (existing.contains('${base}_$index')) {
    index++;
  }
  return '${base}_$index';
}

String shortNameFor(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return words.isEmpty ? value.trim() : words.first;
}

String initialsFor(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  final initials = words.length >= 2
      ? '${words[0][0]}${words[1][0]}'
      : words.isNotEmpty
      ? words.first.substring(0, math.min(2, words.first.length))
      : 'AC';
  return initials.toUpperCase();
}

Color colorFromInt(Object? value, {required Color fallback}) {
  if (value is int) return Color(value);
  if (value is num) return Color(value.toInt());
  return fallback;
}

AccountMeta accountForKey(String key) {
  return accountMeta.firstWhere(
    (account) => account.key == key,
    orElse: () => accountMeta.last,
  );
}

String normalizedAccountKey(
  Object? value, {
  String fallback = defaultAccountKey,
}) {
  final key = value?.toString().trim().toLowerCase();
  if (key != null && accountMeta.any((account) => account.key == key)) {
    return key;
  }
  return fallback;
}

String defaultExpenseAccountKey(
  Map<String, dynamic> item,
  Map<String, double> sumup,
) {
  if (item['paid'] == true) return defaultAccountKey;
  if ((sumup["FROM EVA'S ACCOUNT"] ?? 0) > 0) return 'eva';
  if ((sumup["FROM ERIK'S ACCOUNT"] ?? 0) > 0) return 'erik';
  if ((sumup['FROM SHARED ACCOUNT'] ?? 0) > 0) return 'shared';
  return defaultAccountKey;
}

String formatEuro(double value, {bool cents = true}) {
  final negative = value < 0;
  final abs = value.abs();
  final fixed = cents ? abs.toStringAsFixed(2) : abs.round().toString();
  final parts = fixed.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );
  final suffix = parts.length > 1 ? ',${parts.last}' : '';
  return '${negative ? '-' : ''}\u20ac $whole$suffix';
}

String signedEuro(double value) {
  if (value == 0) return '-';
  final sign = value > 0 ? '+' : '-';
  return '$sign${formatEuro(value.abs()).replaceFirst('\u20ac ', '')}';
}

String greetingForHour(int hour) {
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

String? untilLabel(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
  final serial = asDouble(value);
  if (serial <= 0) return null;
  final date = DateTime.utc(1899, 12, 30).add(Duration(days: serial.round()));
  return '${date.month.toString().padLeft(2, '0')}-${(date.year % 100).toString().padLeft(2, '0')}';
}

UntilState untilState(String label, int currentMonthIndex, int currentYear) {
  final parts = label.split('-');
  if (parts.length != 2) return UntilState.future;
  final month = int.tryParse(parts.first);
  final year = int.tryParse(parts.last);
  if (month == null || year == null) return UntilState.future;
  final diff =
      ((2000 + year) - currentYear) * 12 + (month - 1 - currentMonthIndex);
  if (diff < 0) return UntilState.ended;
  if (diff <= 6) return UntilState.soon;
  return UntilState.future;
}
