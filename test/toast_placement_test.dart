import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('toasts appear at the top, including above an editor sheet', (
    tester,
  ) async {
    await pumpApp(tester);
    thriveDebug.flash('Saved');
    await tester.pump();

    final toast = find.byKey(const ValueKey('toast'));
    expect(toast, findsOneWidget);
    expect(tester.getTopLeft(toast).dy, lessThan(100));

    await goToTab(tester, 'flow');
    await tester.tap(find.byKey(const ValueKey('flow-start-btn')));
    await tester.pumpAndSettle();
    thriveDebug.flash('Start balance saved');
    await tester.pump();

    expect(toast, findsOneWidget);
    expect(tester.getTopLeft(toast).dy, lessThan(100));
    expect(find.text('Start balance saved'), findsOneWidget);
  });
}
