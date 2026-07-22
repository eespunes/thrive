import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('fresh boot lands on the Home dashboard', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    expect(find.text('Hi, Eva'), findsOneWidget);
    expect(find.text('All caught up. Nice work!'), findsOneWidget);
    expect(find.byKey(const ValueKey('quickadd-fab')), findsOneWidget);
  });

  testWidgets('tapping each bottom nav tab switches the shown screen', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);

    await tester.tap(find.byKey(const ValueKey('nav-calendar')));
    await tester.pumpAndSettle();
    expect(find.text('No events'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-lists')));
    await tester.pumpAndSettle();
    expect(find.text('No lists yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-finance')));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
    expect(find.byKey(const ValueKey('quickadd-fab')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    expect(find.text('More'), findsWidgets);
    expect(find.byKey(const ValueKey('quickadd-fab')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('Hi, Eva'), findsOneWidget);
    expect(find.byKey(const ValueKey('quickadd-fab')), findsOneWidget);
  });

  testWidgets('More hub renders every row in order', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();

    for (final key in [
      'more-lists',
      'more-weekly',
      'more-calmanage',
      'more-family',
      'more-finsettings',
      'more-profile',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }

    final firstTop = tester
        .getTopLeft(find.byKey(const ValueKey('more-lists')))
        .dy;
    final lastTop = tester
        .getTopLeft(find.byKey(const ValueKey('more-profile')))
        .dy;
    expect(firstTop, lessThan(lastTop));
  });

  testWidgets(
    'More → Finance settings shows settings with a working back row',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('more-finsettings')));
      await tester.pumpAndSettle();
      expect(find.text('Finance settings'), findsOneWidget);
      expect(find.text('Add account'), findsOneWidget);

      // More stays highlighted while on the finsettings sub-screen.
      await tester.tap(find.byKey(const ValueKey('back-row')));
      await tester.pumpAndSettle();
      expect(find.text('More'), findsWidgets);
    },
  );

  testWidgets('More → Lists / Weekly plan switch tabs', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('more-lists')));
    await tester.pumpAndSettle();
    expect(find.text('No lists yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('more-weekly')));
    await tester.pumpAndSettle();
    expect(find.text('Weekly plan is coming soon'), findsOneWidget);
  });

  testWidgets('More → Your profile opens the existing profile sheet', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('more-profile')));
    await tester.pumpAndSettle();
    expect(find.text('eva.janssen@gmail.com'), findsWidgets);
  });

  testWidgets('More → Family opens the existing family sheet', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('more-family')));
    await tester.pumpAndSettle();
    expect(find.textContaining('separate budget'), findsOneWidget);
  });

  testWidgets('More → Calendars & categories opens the management sheet', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('more-calmanage')));
    await tester.pumpAndSettle();
    expect(find.text('Calendars & categories'), findsWidgets);
    expect(find.text('No categories yet.'), findsOneWidget);
    expect(find.text('Nothing imported yet.'), findsOneWidget);
  });

  testWidgets('Quick-Add FAB shows a coming-soon toast', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pump();
    expect(find.text('Quick-Add is coming soon'), findsOneWidget);
  });
}
