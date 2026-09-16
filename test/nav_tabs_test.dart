import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('sanitiseNavTabs', () {
    test('a fresh person gets the default bar, never an empty one', () {
      expect(sanitiseNavTabs(null), kDefaultNavTabs);
      expect(sanitiseNavTabs([]), kDefaultNavTabs);
    });

    test('unknown sections are dropped and the list tops up', () {
      // 'chores' does not exist in this app yet; a bar naming it must still
      // come back three long rather than short.
      final out = sanitiseNavTabs(['weekly', 'chores', 'nope']);
      expect(out.length, kNavPickCount);
      expect(out.first, 'weekly');
      expect(out.contains('chores'), isFalse);
    });

    test('duplicates collapse and the list is capped', () {
      expect(sanitiseNavTabs(['lists', 'lists', 'lists']).length, 3);
      expect(sanitiseNavTabs(['weekly', 'lists', 'finance', 'calendar']), [
        'weekly',
        'lists',
        'finance',
      ]);
    });

    test('order is the order picked', () {
      expect(sanitiseNavTabs(['finance', 'weekly', 'lists']), [
        'finance',
        'weekly',
        'lists',
      ]);
    });
  });

  testWidgets('the bar shows the default picks and never asks to configure', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    for (final key in ['home', ...kDefaultNavTabs, 'more']) {
      expect(find.byKey(ValueKey('nav-$key')), findsOneWidget);
    }
    // Meal plan isn't on the default bar…
    expect(find.byKey(const ValueKey('nav-weekly')), findsNothing);
    // …so it waits in More, one tap away.
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await openHubCard(tester, 'sections', 'more-section-weekly');
    expect(find.byKey(const ValueKey('more-section-weekly')), findsOneWidget);
  });

  testWidgets('long-pressing the bar opens the editor and a pick swaps a tab', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.longPress(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('Your tab bar'), findsOneWidget);
    // Home is fixed and cannot be unpicked.
    expect(find.byKey(const ValueKey('nav-edit-home')), findsOneWidget);
    expect(find.text('FIXED'), findsOneWidget);

    // Picking a fourth drops the oldest pick rather than refusing the tap.
    await tester.tap(find.byKey(const ValueKey('nav-edit-weekly')));
    await tester.pumpAndSettle();
    expect(thriveDebug.navPickedTabs.contains('weekly'), isTrue);
    expect(thriveDebug.navPickedTabs.length, kNavPickCount);
    expect(thriveDebug.navPickedTabs.contains('calendar'), isFalse);

    // Close the sheet the way a person does — the bar behind it must have
    // changed.
    Navigator.of(tester.element(find.text('Your tab bar'))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-weekly')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-calendar')), findsNothing);
  });

  testWidgets('an unpicked section is still reachable and lights up More', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.setNavTabs(['weekly', 'lists', 'finance']);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await openHubCard(tester, 'sections', 'more-section-calendar');
    await tester.tap(find.byKey(const ValueKey('more-section-calendar')));
    await tester.pumpAndSettle();

    // The calendar opened even though it has no tab of its own…
    expect(thriveDebug.tab, 'calendar');
    // …and More stays lit, because More is where it now lives.
    expect(find.byKey(const ValueKey('nav-calendar')), findsNothing);
    expect(find.byKey(const ValueKey('nav-more')), findsOneWidget);
  });

  testWidgets('the picks survive a restart', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.setNavTabs(['finance', 'weekly', 'lists']);
    await tester.pumpAndSettle();
    // Settle the debounced persist, then boot the app again from what it
    // wrote — the picks have to survive a cold start, not just a rebuild.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await pumpApp(tester, landOnDefaultTab: true);
    expect(thriveDebug.navPickedTabs, ['finance', 'weekly', 'lists']);
    expect(find.byKey(const ValueKey('nav-weekly')), findsOneWidget);
  });
}
