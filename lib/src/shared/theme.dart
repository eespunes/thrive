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

  // Editor sheets (`Editors.dc.html`, #399).
  /// Placeholders, chevrons, weekend day numbers and disabled labels.
  static const placeholder = Color(0xff94a0b0);
  static const handle = Color(0xffdde2ea);
  static const toggleOff = Color(0xffcfd6df);
  static const dash = Color(0xffcfd8e3);
  static const barTrack = Color(0xffe2e7ee);
  static const segIdle = Color(0xff8995a6);
  static const amountEmpty = Color(0xffcbd3dc);
  static const rowOpen = Color(0xfff8fafb);
  static const scrim = Color(0x73101828);
  static const segShadow = Color(0x1f101828);
  static const infoSoft = Color(0xffeef6ff);
  static const infoLine = Color(0xffd3e5f8);
  static const infoText = Color(0xff1d4ed8);

  static const ocean = Color(0xff1684B4);
  static const blue = Color(0xff2563eb);
  static const violet = Color(0xff7c3aed);
  static const pink = Color(0xffdb2777);
  static const rose = Color(0xffe11d48);
  static const yellow = Color(0xfff59e0b);
  static const slate = Color(0xff475569);
  static const leaf = Color(0xff54A96A);

  /// The 12 colour swatches every editor offers (badges, wallet cards).
  static const List<Color> swatches = [
    primary,
    ocean,
    blue,
    violet,
    pink,
    rose,
    red,
    amber,
    yellow,
    green,
    soft2,
    ink,
  ];

  /// Sticky-note papers and their matching tape (list editor, fridge door).
  static const paperYellow = Color(0xfffff8c4);
  static const paperBlue = Color(0xffdcefff);
  static const paperPeach = Color(0xffffe3d3);
  static const paperGreen = Color(0xffe2f4e0);
  static const paperPink = Color(0xfffde2ec);
  static const paperGrey = Color(0xffececec);
  static const tapeYellow = Color(0xffffd6a5);
  static const tapeBlue = Color(0xffb5d8f5);
  static const tapePeach = Color(0xfff5c6a5);
  static const tapeGreen = Color(0xffbcd9b8);
  static const tapePink = Color(0xfff2b8cf);
  static const tapeGrey = Color(0xffd4d4d4);

  /// Hairline around paper swatches and the note shadow.
  static const paperEdge = Color(0x140f172a);
  static const noteShadow = Color(0x730f172a);

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
