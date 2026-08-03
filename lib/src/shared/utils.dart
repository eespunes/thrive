part of 'package:family_money_management_app/main.dart';

enum UntilState { soon, future, ended }

int _uidCounter = 0;

/// Mirrors `uid()` — short unique id.
String uid() {
  _uidCounter++;
  final rand = math.Random().nextInt(1 << 31).toRadixString(36);
  return 'x$rand${_uidCounter.toRadixString(36)}';
}

/// Today's date as `YYYY-MM-DD`, mirrors the design's `TODAY` constant.
String todayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? _dateFromUntil(Object? v) {
  if (v == null) return null;
  if (v is String) {
    final t = v.trim();
    if (t.isEmpty || t == '-') return null;
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(t);
    if (iso != null) {
      final yy = int.parse(iso.group(1)!);
      final mm = int.parse(iso.group(2)!);
      final dd = int.parse(iso.group(3)!);
      return DateTime(yy, mm, dd);
    }
    final mmYy = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(t);
    if (mmYy != null) {
      final mm = int.parse(mmYy.group(1)!);
      final yy = 2000 + int.parse(mmYy.group(2)!);
      return DateTime(yy, mm + 1, 0);
    }
    return null;
  }
  final serial = parseNum(v);
  if (serial <= 0) return null;
  return DateTime.utc(1899, 12, 30).add(Duration(days: serial.round()));
}

/// Normalizes a recurring end date to an ISO `YYYY-MM-DD` string.
String? normalizeRecurringEndDate(Object? v) {
  final d = _dateFromUntil(v);
  return d == null ? null : _isoDate(d);
}

/// Mirrors `num(v)` — tolerant number parsing.
double parseNum(Object? v) {
  if (v is num) return v.isNaN ? 0 : v.toDouble();
  if (v is String) {
    final t = v.trim();
    if (t == '-' || t.isEmpty) return 0;
    final n = double.tryParse(t.replaceAll(',', '.'));
    return n == null || n.isNaN ? 0 : n;
  }
  return 0;
}

/// Mirrors `eur(n,cents)` — European currency formatting with thin nbsp.
String eur(num? value, {bool cents = true}) {
  var n = (value ?? 0).toDouble();
  if (n.isNaN) n = 0;
  final neg = n < 0;
  n = n.abs();
  final s = cents ? n.toStringAsFixed(2) : n.round().toString();
  final parts = s.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => '.',
  );
  final dec = parts.length > 1 ? ',${parts.last}' : '';
  return '${neg ? '\u2212' : ''}\u20ac\u00A0$whole$dec';
}

/// Strips the euro glyph + nbsp for inline deltas.
String eurBare(num? value, {bool cents = true}) =>
    eur(value, cents: cents).replaceFirst('\u20ac\u00A0', '');

/// Mirrors `markerShow(v)` — hides pure serial numbers / placeholders.
String markerShow(Object? v) {
  if (v == null) return '';
  final s = v.toString().trim();
  if (RegExp(r'^\d{4,}$').hasMatch(s)) return '';
  return s == '-' ? '' : s;
}

/// Mirrors `untilLabel(v)` — normalizes an "until" value to MM-YY.
String? untilLabel(Object? v) {
  final d = _dateFromUntil(v);
  if (d == null) return null;
  return '${d.month.toString().padLeft(2, '0')}-'
      '${(d.year % 100).toString().padLeft(2, '0')}';
}

/// Mirrors `untilState(label,mIdx,year)`.
UntilState untilState(String? label, int mIdx, int year) {
  final p = (label ?? '').split('-');
  if (p.length != 2) return UntilState.future;
  final mm = int.tryParse(p[0]);
  final yy = int.tryParse(p[1]);
  if (mm == null || yy == null) return UntilState.future;
  final diff = ((2000 + yy) - year) * 12 + (mm - 1 - mIdx);
  if (diff < 0) return UntilState.ended;
  if (diff <= 6) return UntilState.soon;
  return UntilState.future;
}

/// Mirrors `accForLabel(label)` — heuristics that route a row to an account.
String accForLabel(String? label) {
  final u = (label ?? '').toUpperCase();
  if (u.contains('EVA')) return 'eva';
  if (u.contains('ERIK')) return 'erik';
  return 'shared';
}

/// Light tint for a category background, mirrors `tintFor(hex)`.
Color tintFor(Color tone) => tone.withValues(alpha: 0.10);
