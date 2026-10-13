import 'dart:io';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'settings_v2_seed.dart';

/// A text-free swatch sheet so the goldens are stable across platforms.
class _Swatches extends StatelessWidget {
  const _Swatches();

  @override
  Widget build(BuildContext context) {
    final c = context.tc;
    Widget box(Color color) => Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.line),
      ),
    );
    return Container(
      color: c.page,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        children: [
          for (final color in [
            c.page,
            c.surface,
            c.ink,
            c.text,
            c.soft2,
            c.muted,
            c.line,
            c.faint,
            c.track,
            c.soft,
            c.primary,
            c.deep,
            c.green,
            c.red,
            c.amber,
            c.greenSoft,
            c.redSoft,
            c.amberSoft,
          ])
            box(color),
        ],
      ),
    );
  }
}

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance(), l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + .05) / (lo + .05);
}

void main() {
  tearDown(() => themeModeNotifier.value = ThemeMode.system);

  test('light palette equals the legacy B constants', () {
    const c = ThriveColors.light;
    expect(c.page, B.page);
    expect(c.ink, B.ink);
    expect(c.muted, B.muted);
    expect(c.line, B.line);
    expect(c.primary, B.primary);
    expect(c.redSoft, B.redSoft);
  });

  test('dark palette keeps WCAG AA for text tokens on page and surface', () {
    const d = ThriveColors.dark;
    for (final bg in [d.page, d.surface]) {
      for (final fg in [
        d.ink,
        d.text,
        d.soft2,
        d.muted,
        d.primary,
        d.green,
        d.red,
        d.amberText,
        d.greenText,
      ]) {
        expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('lerp blends and non-extensions are ignored', () {
    final mid = ThriveColors.light.lerp(ThriveColors.dark, 1);
    expect(mid.ink, ThriveColors.dark.ink);
    expect(ThriveColors.light.lerp(null, .5), ThriveColors.light);
  });

  testWidgets('themeMode swaps ThemeData and the extension values', (
    tester,
  ) async {
    late ThriveColors seen;
    late Brightness brightness;
    Widget app(ThemeMode mode) => MaterialApp(
      themeMode: mode,
      theme: buildThriveTheme(Brightness.light),
      darkTheme: buildThriveTheme(Brightness.dark),
      home: Builder(
        builder: (context) {
          seen = context.tc;
          brightness = Theme.of(context).brightness;
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(app(ThemeMode.light));
    expect(brightness, Brightness.light);
    expect(seen.ink, ThriveColors.light.ink);
    await tester.pumpWidget(app(ThemeMode.dark));
    await tester.pumpAndSettle();
    expect(brightness, Brightness.dark);
    expect(seen.ink, ThriveColors.dark.ink);
  });

  test('appearance choice is persisted per device', () async {
    SharedPreferences.setMockInitialValues({});
    await setThemeMode(ThemeMode.dark);
    expect(themeModeNotifier.value, ThemeMode.dark);
    themeModeNotifier.value = ThemeMode.system;
    await loadThemeMode();
    expect(themeModeNotifier.value, ThemeMode.dark);
    expect(themeModeFromName('nonsense'), ThemeMode.system);
  });

  testWidgets('More hub cycles System → Light → Dark and the app follows', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await openMoreHub(tester);
    await openHubCard(tester, 'account', 'hub-appearance');
    expect(find.text('System'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hub-appearance')));
    await tester.pumpAndSettle();
    expect(find.text('Light'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hub-appearance')));
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
    final ctx = tester.element(find.byKey(const ValueKey('hub-appearance')));
    expect(Theme.of(ctx).brightness, Brightness.dark);
  });

  for (final mode in [Brightness.light, Brightness.dark]) {
    testWidgets('palette golden (${mode.name})', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildThriveTheme(mode),
          home: const Scaffold(body: Center(child: _Swatches())),
        ),
      );
      await expectLater(
        find.byType(_Swatches),
        matchesGoldenFile('goldens/palette_${mode.name}.png'),
      );
    });
  }

  // Guard (#439): themed tokens must be read through `context.tc`.
  // Report-only for raw literals; failing for the legacy themed `B.*` tokens.
  test('no legacy themed B.* tokens outside theme.dart and models', () {
    final themed = RegExp(
      r'\bB\.(page|ink|text|soft2|muted|line|faint|track|soft|primary|deep|'
      r'green\w*|red\w*|amber\w*|orange\w*|grad|placeholder|handle|toggleOff|'
      r'dash|barTrack|segIdle|amountEmpty|rowOpen|info\w*|scrim)\b',
    );
    final offenders = <String>[];
    var literals = 0;
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('shared/theme.dart') || f.path.contains('/models/')) {
        continue;
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (themed.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}');
        literals += RegExp(
          r'Color\(0x|Colors\.white',
        ).allMatches(lines[i]).length;
      }
    }
    // ignore: avoid_print
    print('[dark-mode guard] raw colour literals remaining: $literals');
    expect(offenders, isEmpty);
  });
}
