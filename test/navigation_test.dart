import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('fresh boot lands on the Home dashboard', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    expect(find.text('Hi, Eva'), findsOneWidget);
    expect(find.text('All caught up.'), findsOneWidget);
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
    expect(find.text('Nothing on the door yet'), findsOneWidget);
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

  testWidgets('More hub: hero, expanding cards and their rows', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();

    // Hero (profile entry) + the four collapsed cards.
    expect(find.byKey(const ValueKey('more-profile')), findsOneWidget);
    for (final card in ['planning', 'money', 'family', 'account']) {
      expect(find.byKey(ValueKey('hub-card-$card')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('more-weekly')), findsNothing);

    // One card open at a time; each holds its rows.
    await openHubCard(tester, 'planning', 'more-weekly');
    for (final key in [
      'more-weekly',
      'more-calmanage',
      'more-calimports',
      'more-callayers',
      'more-kitchen-settings',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    await openHubCard(tester, 'money', 'more-finsettings');
    expect(find.byKey(const ValueKey('more-weekly')), findsNothing);
    for (final key in [
      'more-wallet',
      'more-widget-privacy',
      'more-finsettings',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    await openHubCard(tester, 'family', 'more-family');
    expect(find.byKey(const ValueKey('more-invite')), findsOneWidget);
    await openHubCard(tester, 'account', 'more-signout');
    expect(find.byKey(const ValueKey('more-signout')), findsOneWidget);
    expect(find.byKey(const ValueKey('more-delete-account')), findsOneWidget);

    // Version label reads the pubspec version, without the build-number
    // "+N" suffix (mocked to 2.7.1+46 in tests).
    await tester.scrollUntilVisible(
      find.text('Thrive 2.7.1 · English (UK)'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Thrive 2.7.1 · English (UK)'), findsOneWidget);
  });

  testWidgets(
    'Account card: notifications & device-calendar sync are real, persisted '
    'toggles',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();
      await openHubCard(tester, 'account', 'more-signout');

      expect(thriveDebug.notificationsEnabled, isTrue);
      expect(thriveDebug.deviceCalendarSyncEnabled, isTrue);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('hub-notifications')),
        80,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('hub-notifications')));
      await tester.pumpAndSettle();
      expect(thriveDebug.notificationsEnabled, isFalse);

      await tester.tap(find.byKey(const ValueKey('hub-calsync')));
      await tester.pumpAndSettle();
      expect(thriveDebug.deviceCalendarSyncEnabled, isFalse);

      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await rebootApp(tester);
      expect(thriveDebug.notificationsEnabled, isFalse);
      expect(thriveDebug.deviceCalendarSyncEnabled, isFalse);
    },
  );

  testWidgets(
    'More → Finance settings opens as a sheet with settings content',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();

      await tapHubRow(tester, 'money', 'more-finsettings');
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

    await tapHubRow(tester, 'planning', 'more-weekly');
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

    await tapHubRow(tester, 'family', 'more-family');
    expect(find.textContaining('separate budget'), findsOneWidget);
  });

  testWidgets('More → Categories opens the category management sheet', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();

    await tapHubRow(tester, 'planning', 'more-calmanage');
    expect(find.text('Categories'), findsWidgets);
    expect(find.text('No categories yet.'), findsOneWidget);
  });

  testWidgets('More → Imported calendars opens the imports management sheet', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();

    await tapHubRow(tester, 'planning', 'more-calimports');
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

      await tapHubRow(tester, 'planning', 'more-callayers');
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
      await tapHubRow(tester, 'planning', 'more-callayers');

      taskSwitch = tester.widget<Switch>(
        find.byKey(const ValueKey('cal-manage-layer-switch-task')),
      );
      expect(taskSwitch.value, isFalse);
    },
  );
}
