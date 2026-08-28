import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'settings_v2_seed.dart';

/// Kitchen wall sub-page (#281): star stepper clamps 0–5, photo-tile toggle,
/// min-1 layer guard and the hub value reflecting the state.
void main() {
  Future<void> openKitchen(WidgetTester tester) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    await openMoreHub(tester);
    await tapHubRow(tester, 'planning', 'more-kitchen-settings');
  }

  testWidgets('reward stars step and clamp between 0 and 5', (tester) async {
    await openKitchen(tester);
    final plus = find.byKey(const ValueKey('kitchen-stars-me-plus'));
    final minus = find.byKey(const ValueKey('kitchen-stars-me-minus'));
    // Down from 0 stays 0.
    await tester.tap(minus);
    await tester.pump();
    expect(thriveDebug.starsMap['me'] ?? 0, 0);
    // Seven ups clamp at 5.
    for (var i = 0; i < 7; i++) {
      await tester.tap(plus);
      await tester.pump();
    }
    expect(thriveDebug.starsMap['me'], 5);
    expect(find.text('★ 5'), findsOneWidget);
    await tester.tap(minus);
    await tester.pump();
    expect(thriveDebug.starsMap['me'], 4);
  });

  testWidgets('photo-tile toggle flips one member only', (tester) async {
    await openKitchen(tester);
    expect(find.text('Colour tile · reward stars'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('kitchen-picmode-m2')));
    await tester.pump();
    expect(thriveDebug.picMembers['m2'], isTrue);
    expect(thriveDebug.picMembers['me'] ?? false, isFalse);
    expect(find.text('Photo tile · reward stars'), findsOneWidget);
    expect(find.text('Colour tile · reward stars'), findsOneWidget);
  });

  testWidgets('the min-1 wall layer guard toasts instead of hiding all', (
    tester,
  ) async {
    await openKitchen(tester);
    await tester.tap(find.byKey(const ValueKey('kitchen-layer-toggle-task')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('kitchen-layer-toggle-content')),
    );
    await tester.pump();
    expect(thriveDebug.kitchenLayerFilter, ['appt']);
    await tester.tap(find.byKey(const ValueKey('kitchen-layer-toggle-appt')));
    await tester.pump();
    expect(thriveDebug.kitchenLayerFilter, ['appt']);
    expect(find.text('At least one layer stays visible'), findsOneWidget);
  });

  testWidgets('the hub value reflects the wall layer count', (tester) async {
    await openKitchen(tester);
    await tester.tap(find.byKey(const ValueKey('kitchen-layer-toggle-task')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-back')));
    await tester.pumpAndSettle();
    expect(find.text('2 of 3 layers'), findsOneWidget);
  });
}
