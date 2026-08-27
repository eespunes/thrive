import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Scratch perf probe (not meant for CI): boots the app with the generated
// heavy-family blob and times key screens. Run with:
//   flutter test test/perf_probe_test.dart --dart-define=PERF_BLOB=<path>
const _blobPath = String.fromEnvironment('PERF_BLOB');

void main() {
  if (_blobPath.isEmpty) {
    test('perf probe skipped (no PERF_BLOB)', () {});
    return;
  }

  testWidgets('boot + navigate with a heavy family', (tester) async {
    var raw = File(_blobPath).readAsStringSync();
    if (raw.startsWith('"')) raw = jsonDecode(raw) as String;

    final sw = Stopwatch()..start();
    await pumpApp(
      tester,
      landOnDefaultTab: true,
      prefs: {'thrive.v4': raw},
    );
    debugPrint('BOOT: ${sw.elapsedMilliseconds}ms');

    Future<void> step(String name, Future<void> Function() fn) async {
      final s = Stopwatch()..start();
      await fn();
      debugPrint('STEP $name: ${s.elapsedMilliseconds}ms');
    }

    await step('calendar', () async {
      await tester.tap(find.byKey(const ValueKey('nav-calendar')));
      await tester.pumpAndSettle();
    });
    await step('lists', () async {
      await tester.tap(find.byKey(const ValueKey('nav-lists')));
      await tester.pumpAndSettle();
    });
    await step('finance', () async {
      await tester.tap(find.byKey(const ValueKey('nav-finance')));
      await tester.pumpAndSettle();
    });
    await step('more', () async {
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();
    });
    expect(find.byKey(const ValueKey('more-profile')), findsOneWidget);
  });
}
