import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('fresh boot lands on the Home dashboard', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    expect(find.text('Hi, Eva'), findsOneWidget);
    expect(find.text('All caught up. Nice work!'), findsOneWidget);
    expect(find.byKey(const ValueKey('quickadd-fab')), findsNothing);
  });

  testWidgets('tapping each bottom nav tab switches the shown screen', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);

    await tester.tap(find.byKey(const ValueKey('nav-calendar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cal-month-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('cal-header-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('quickadd-fab')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-lists')));
    await tester.pumpAndSettle();
    expect(find.text('No lists yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('quickadd-fab')), findsOneWidget);

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
    expect(find.byKey(const ValueKey('quickadd-fab')), findsNothing);
  });

  testWidgets('bottom navigation and FAB respect the phone system inset', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 96);
    addTearDown(tester.view.resetPadding);

    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-calendar')));
    await tester.pumpAndSettle();

    final nav = tester.widget<Container>(
      find.byKey(const ValueKey('app-bottom-nav')),
    );
    final navPadding = nav.padding as EdgeInsets;
    expect(navPadding.bottom, 48);

    final fabPositioned = tester.widget<Positioned>(
      find.ancestor(
        of: find.byKey(const ValueKey('quickadd-fab')),
        matching: find.byType(Positioned),
      ),
    );
    expect(fabPositioned.bottom, 140);
  });

  testWidgets('More hub renders every row in order', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();

    for (final key in [
      'more-profile',
      'more-weekly',
      'more-calmanage',
      'more-calimports',
      'more-finsettings',
      'more-family',
      'more-invite',
      'more-signout',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }

    final firstTop = tester
        .getTopLeft(find.byKey(const ValueKey('more-profile')))
        .dy;
    final lastTop = tester
        .getTopLeft(find.byKey(const ValueKey('more-signout')))
        .dy;
    expect(firstTop, lessThan(lastTop));

    // Version label reads the pubspec version, without the build-number
    // "+N" suffix (mocked to 2.7.1+46 in tests).
    expect(find.text('Thrive · v2.7.1'), findsOneWidget);
  });

  testWidgets(
    'More → Finance settings opens as a sheet with settings content',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('more-finsettings')));
      await tester.pumpAndSettle();
      expect(find.text('Finance settings'), findsWidgets);
      expect(find.text('Add account'), findsOneWidget);

      // Dismiss the sheet and land back on the More hub, not a sub-tab.
      await tester.tapAt(const Offset(200, 60));
      await tester.pumpAndSettle();
      expect(find.text('More'), findsWidgets);
      expect(find.byKey(const ValueKey('more-finsettings')), findsOneWidget);
    },
  );

  testWidgets('More → Weekly plan opens as a sheet', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('more-weekly')));
    await tester.pumpAndSettle();
    expect(find.text('Weekly plan'), findsWidgets);
    expect(find.byKey(const ValueKey('week-prev')), findsOneWidget);
  });

  testWidgets('More → profile card opens the existing profile sheet', (
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

  testWidgets('More → Categories opens the category management sheet', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('more-calmanage')));
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsWidgets);
    expect(find.text('No categories yet.'), findsOneWidget);
  });

  testWidgets('More → Imported calendars opens the imports management sheet', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('more-calimports')));
    await tester.pumpAndSettle();
    expect(find.text('Imported calendars'), findsWidgets);
    expect(find.text('Nothing imported yet.'), findsOneWidget);
  });

  testWidgets(
    'More → Calendar layers opens the layers management sheet and its '
    'toggles drive layerFilter',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('more-callayers')));
      await tester.pumpAndSettle();
      expect(find.text('Calendar layers'), findsWidgets);
      expect(find.text('Appointments'), findsOneWidget);
      expect(find.text('To-Dos'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      expect(find.text('+ Add layer'), findsOneWidget);

      // The switch reflects `layerFilter` membership for the layer.
      var taskSwitch = tester.widget<Switch>(
        find.byKey(const ValueKey('cal-manage-layer-switch-task')),
      );
      expect(taskSwitch.value, isTrue);

      // Disabling the to-dos layer here drives the same `layerFilter` the
      // calendar's filter sheet reads from.
      await tester.tap(
        find.byKey(const ValueKey('cal-manage-layer-switch-task')),
      );
      await tester.pumpAndSettle();
      taskSwitch = tester.widget<Switch>(
        find.byKey(const ValueKey('cal-manage-layer-switch-task')),
      );
      expect(taskSwitch.value, isFalse);

      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await rebootApp(tester);
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('more-callayers')));
      await tester.pumpAndSettle();

      taskSwitch = tester.widget<Switch>(
        find.byKey(const ValueKey('cal-manage-layer-switch-task')),
      );
      expect(taskSwitch.value, isFalse);
    },
  );
}
