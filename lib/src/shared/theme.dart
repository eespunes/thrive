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

/// Theme-aware twin of [B]: same token names, light values equal to `B`,
/// dark values from the app-wide dark palette. Read via `context.tc.ink`.
/// User-chosen colours (categories, members, note papers) are never re-tinted.
@immutable
class ThriveColors extends ThemeExtension<ThriveColors> {
  const ThriveColors({
    required this.page,
    required this.surface,
    required this.ink,
    required this.text,
    required this.soft2,
    required this.muted,
    required this.line,
    required this.faint,
    required this.track,
    required this.soft,
    required this.primary,
    required this.deep,
    required this.green,
    required this.greenSoft,
    required this.greenLine,
    required this.greenText,
    required this.red,
    required this.redSoft,
    required this.redLine,
    required this.amber,
    required this.amberSoft,
    required this.amberLine,
    required this.amberText,
    required this.orangeSoft,
    required this.orangeText,
    required this.grad,
  });

  final Color page;

  /// Cards, sheets and dialogs (white in light mode).
  final Color surface;
  final Color ink;
  final Color text;
  final Color soft2;
  final Color muted;
  final Color line;
  final Color faint;
  final Color track;
  final Color soft;
  final Color primary;
  final Color deep;
  final Color green;
  final Color greenSoft;
  final Color greenLine;
  final Color greenText;
  final Color red;
  final Color redSoft;
  final Color redLine;
  final Color amber;
  final Color amberSoft;
  final Color amberLine;
  final Color amberText;
  final Color orangeSoft;
  final Color orangeText;
  final LinearGradient grad;

  /// Active palette for code with no [BuildContext]; set by [ThriveApp].
  static ThriveColors current = light;

  static const light = ThriveColors(
    page: B.page,
    surface: Colors.white,
    ink: B.ink,
    text: B.text,
    soft2: B.soft2,
    muted: B.muted,
    line: B.line,
    faint: B.faint,
    track: B.track,
    soft: B.soft,
    primary: B.primary,
    deep: B.deep,
    green: B.green,
    greenSoft: B.greenSoft,
    greenLine: B.greenLine,
    greenText: B.greenText,
    red: B.red,
    redSoft: B.redSoft,
    redLine: B.redLine,
    amber: B.amber,
    amberSoft: B.amberSoft,
    amberLine: B.amberLine,
    amberText: B.amberText,
    orangeSoft: B.orangeSoft,
    orangeText: B.orangeText,
    grad: B.grad,
  );

  static const dark = ThriveColors(
    page: Color(0xff0b1018),
    surface: Color(0xff141b26),
    ink: Color(0xfff1f5f9),
    text: Color(0xffcbd5e1),
    soft2: Color(0xff94a3b8),
    muted: Color(0xff8593a8),
    line: Color(0xff263243),
    faint: Color(0xff1b2433),
    track: Color(0xff222d3d),
    soft: Color(0xff12332f),
    primary: B.primary,
    deep: Color(0xff2dc4b4),
    green: Color(0xff34d399),
    greenSoft: Color(0xff0f2a22),
    greenLine: Color(0xff1d5c43),
    greenText: Color(0xff6ee7b7),
    red: Color(0xfff87171),
    redSoft: Color(0xff2d1417),
    redLine: Color(0xff6b2328),
    amber: Color(0xfffbbf24),
    amberSoft: Color(0xff2b2210),
    amberLine: Color(0xff6b5314),
    amberText: Color(0xfffcd34d),
    orangeSoft: Color(0xff2b1a0f),
    orangeText: Color(0xfffdba74),
    grad: B.grad,
  );

  @override
  ThriveColors copyWith({Color? page, Color? surface, Color? ink}) =>
      ThriveColors(
        page: page ?? this.page,
        surface: surface ?? this.surface,
        ink: ink ?? this.ink,
        text: text,
        soft2: soft2,
        muted: muted,
        line: line,
        faint: faint,
        track: track,
        soft: soft,
        primary: primary,
        deep: deep,
        green: green,
        greenSoft: greenSoft,
        greenLine: greenLine,
        greenText: greenText,
        red: red,
        redSoft: redSoft,
        redLine: redLine,
        amber: amber,
        amberSoft: amberSoft,
        amberLine: amberLine,
        amberText: amberText,
        orangeSoft: orangeSoft,
        orangeText: orangeText,
        grad: grad,
      );

  @override
  ThriveColors lerp(ThemeExtension<ThriveColors>? other, double t) {
    if (other is! ThriveColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ThriveColors(
      page: l(page, other.page),
      surface: l(surface, other.surface),
      ink: l(ink, other.ink),
      text: l(text, other.text),
      soft2: l(soft2, other.soft2),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      faint: l(faint, other.faint),
      track: l(track, other.track),
      soft: l(soft, other.soft),
      primary: l(primary, other.primary),
      deep: l(deep, other.deep),
      green: l(green, other.green),
      greenSoft: l(greenSoft, other.greenSoft),
      greenLine: l(greenLine, other.greenLine),
      greenText: l(greenText, other.greenText),
      red: l(red, other.red),
      redSoft: l(redSoft, other.redSoft),
      redLine: l(redLine, other.redLine),
      amber: l(amber, other.amber),
      amberSoft: l(amberSoft, other.amberSoft),
      amberLine: l(amberLine, other.amberLine),
      amberText: l(amberText, other.amberText),
      orangeSoft: l(orangeSoft, other.orangeSoft),
      orangeText: l(orangeText, other.orangeText),
      grad: LinearGradient.lerp(grad, other.grad, t)!,
    );
  }
}

/// Secondary tokens derived per brightness (editor sheets, #399).
extension ThriveColorsExtra on ThriveColors {
  /// Keeps an exact legacy [light] colour in light mode.
  Color pick(Color light, Color dark) => isDark ? dark : light;
  bool get isDark => page.computeLuminance() < .5;

  /// Foreground for controls and cards filled with [ink].
  Color get onInk => isDark ? B.ink : Colors.white;
  Color get placeholder => isDark ? const Color(0xff64748b) : B.placeholder;
  Color get handle => isDark ? const Color(0xff334155) : B.handle;
  Color get toggleOff => isDark ? const Color(0xff3b4a5e) : B.toggleOff;
  Color get dash => isDark ? const Color(0xff334155) : B.dash;
  Color get barTrack => isDark ? const Color(0xff2b384a) : B.barTrack;
  Color get segIdle => isDark ? const Color(0xff7d8ba0) : B.segIdle;
  Color get amountEmpty => isDark ? const Color(0xff3b4a5e) : B.amountEmpty;
  Color get rowOpen => isDark ? const Color(0xff18212e) : B.rowOpen;
  Color get infoSoft => isDark ? const Color(0xff10243a) : B.infoSoft;
  Color get infoLine => isDark ? const Color(0xff1f4770) : B.infoLine;
  Color get infoText => isDark ? const Color(0xff93c5fd) : B.infoText;
  Color get scrim => isDark ? const Color(0xa6000000) : B.scrim;
}

extension ThriveColorsContext on BuildContext {
  /// The active palette; falls back to light when no extension is installed.
  ThriveColors get tc =>
      Theme.of(this).extension<ThriveColors>() ?? ThriveColors.light;
}

/// Builds the app [ThemeData] for one palette.
ThemeData buildThriveTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final c = dark ? ThriveColors.dark : ThriveColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: B.primary,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: c.page,
    colorScheme: dark
        ? scheme.copyWith(
            surface: c.surface,
            onSurface: c.ink,
            primary: c.primary,
            outline: c.line,
            outlineVariant: c.line,
          )
        : scheme,
    fontFamily: 'PlusJakartaSans',
    textTheme: TextTheme(bodyMedium: TextStyle(color: c.ink)),
    dividerTheme: dark ? DividerThemeData(color: c.line) : null,
    bottomSheetTheme: dark
        ? BottomSheetThemeData(
            backgroundColor: c.surface,
            modalBackgroundColor: c.surface,
          )
        : null,
    dialogTheme: dark ? DialogThemeData(backgroundColor: c.surface) : null,
    switchTheme: dark
        ? SwitchThemeData(
            thumbColor: WidgetStateProperty.all(Colors.white),
            trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? c.primary : c.track,
            ),
          )
        : null,
    inputDecorationTheme: dark
        ? InputDecorationTheme(hintStyle: TextStyle(color: c.muted))
        : null,
    extensions: [c],
  );
}

/// Appearance choice (#428). Per device, persisted in SharedPreferences.
const String kThemeModePrefKey = 'thrive.themeMode';
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.system,
);

ThemeMode themeModeFromName(String? name) => ThemeMode.values.firstWhere(
  (m) => m.name == name,
  orElse: () => ThemeMode.system,
);

String themeModeLabel(ThemeMode m) => switch (m) {
  ThemeMode.system => 'System',
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
};

Future<void> loadThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    themeModeNotifier.value = themeModeFromName(
      prefs.getString(kThemeModePrefKey),
    );
  } catch (_) {}
}

Future<void> setThemeMode(ThemeMode mode) async {
  themeModeNotifier.value = mode;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kThemeModePrefKey, mode.name);
  } catch (_) {}
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
