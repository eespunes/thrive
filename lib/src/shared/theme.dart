part of 'package:family_money_management_app/main.dart';

/// Brand palette mirrored from the Thrive design (the `B` object).
class B {
  static const primary = Color(0xff0E9A8D);
  static const deep = Color(0xff0B7F74);
  static const soft = Color(0xffe4f4f1);
  static const ink = Color(0xff0f172a);
  static const text = Color(0xff334155);
  static const soft2 = Color(0xff64748b);
  // Darkened from the design's #94a0b0 (~2.6:1 on white — below WCAG AA) so
  // muted labels stay readable at the 10-11px sizes they're used at.
  static const muted = Color(0xff77839a);
  static const line = Color(0xffe7eaf0);
  static const faint = Color(0xfff0f2f6);
  static const track = Color(0xffeef1f5);

  static const green = Color(0xff0f9d6a);
  static const greenSoft = Color(0xffe7f7ef);
  static const greenLine = Color(0xffbbf0d3);
  static const greenText = Color(0xff0b7a52);

  static const red = Color(0xffdc2626);
  static const redSoft = Color(0xfffef2f2);
  static const redLine = Color(0xfffecaca);

  static const amber = Color(0xffd97706);
  static const amberSoft = Color(0xfffffbeb);
  static const amberLine = Color(0xfffde68a);
  static const amberText = Color(0xffb45309);

  static const orangeSoft = Color(0xfffff7ed);
  static const orangeText = Color(0xffc2410c);

  static const page = Color(0xfff4f6f9);

  /// Brand gradient used on the projected balance hero + logo mark.
  static const grad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xff46B873), Color(0xff0FA08E), Color(0xff1684B4)],
    stops: [0.0, 0.52, 1.0],
  );
}

/// Picks readable foreground text/icon colour for a user-chosen [bg]
/// (category, member, event colours, etc.): white on darker/saturated
/// colours, a dark ink on pale/light ones (e.g. yellow, lime) where white
/// would be hard to read.
Color contrastOn(Color bg) {
  return bg.computeLuminance() > 0.55 ? B.ink : Colors.white;
}

const List<String> kMonthKeys = [
  'Januari',
  'Februari',
  'Maart',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Augustus',
  'September',
  'Oktober',
  'November',
  'December',
];

const List<String> kMonthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> kMonthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Card shadow used across the app surfaces.
List<BoxShadow> cardShadow() => const [
  BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(
    color: Color(0x47101828),
    blurRadius: 26,
    spreadRadius: -20,
    offset: Offset(0, 10),
  ),
];
