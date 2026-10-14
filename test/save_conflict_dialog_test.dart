import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('a concurrent save offers both versions and can keep mine', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);

    thriveDebug.showSaveConflictForTest({
      'id': 'test-conflict',
      'title': 'Weekend plans',
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('save-conflict-dialog')), findsOneWidget);
    expect(find.textContaining('also edited'), findsOneWidget);
    expect(find.text('Use theirs'), findsOneWidget);
    expect(find.text('Keep mine'), findsOneWidget);

    await tester.tap(find.text('Keep mine'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('save-conflict-dialog')), findsNothing);
  });
}
