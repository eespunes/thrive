import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen chrome uses the shared AppHeader', () {
    const migrated = [
      'lib/src/features/budget/presentation/thrive_home.dart',
      'lib/src/features/navigation/presentation/more_screen.dart',
      'lib/src/features/navigation/presentation/badge_studio.dart',
      'lib/src/features/navigation/presentation/settings_pending_screen.dart',
      'lib/src/features/account/presentation/onboarding_screen.dart',
      'lib/src/shared/editor_sheet.dart',
    ];
    for (final path in migrated) {
      expect(
        File(path).readAsStringSync(),
        contains('AppHeader('),
        reason: path,
      );
    }
    expect(
      File(
        'lib/src/features/navigation/presentation/badge_studio.dart',
      ).readAsStringSync(),
      isNot(contains('studioBackHeader(')),
    );

    final presentations = Directory(
      'lib/src/features',
    ).listSync(recursive: true);
    for (final entry in presentations.whereType<File>()) {
      if (!entry.path.endsWith('.dart')) continue;
      final source = entry.readAsStringSync();
      expect(source, isNot(contains('SliverAppBar(')), reason: entry.path);
      expect(source, isNot(contains('AppBar(')), reason: entry.path);
    }
  });
}
