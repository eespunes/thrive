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
    expect(find.byKey(const ValueKey('cal-month-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('cal-header-view')), findsOneWidget);

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
    'Quick-Add FAB on Home opens the chooser with Event/Task/Shopping rows',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();

      expect(find.text('What would you like to add?'), findsOneWidget);
      expect(find.byKey(const ValueKey('quickadd-event')), findsOneWidget);
      expect(find.byKey(const ValueKey('quickadd-task')), findsOneWidget);
      expect(find.byKey(const ValueKey('quickadd-shopping')), findsOneWidget);
    },
  );

  testWidgets('Quick-Add chooser → Event opens the event editor', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quickadd-event')));
    await tester.pumpAndSettle();
    expect(find.text('New event'), findsOneWidget);
  });

  testWidgets(
    'Quick-Add chooser → Task prompts to create a list when none exist yet',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('quickadd-task')));
      await tester.pumpAndSettle();
      // Lands on the Lists tab with the "new list" sheet open.
      expect(find.text('New list'), findsWidgets);
    },
  );

  testWidgets(
    'Quick-Add chooser → Shopping item prompts to create a list when none '
    'exist yet',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('quickadd-shopping')));
      await tester.pumpAndSettle();
      expect(find.text('New list'), findsWidgets);
    },
  );

  testWidgets(
    'Quick-Add chooser → Task goes straight to the single to-do list',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await tester.tap(find.byKey(const ValueKey('nav-lists')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New list'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Household');
      await tester.pump();
      await tester.tap(find.text('Create list'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quickadd-task')));
      await tester.pumpAndSettle();

      // Lands directly on the "Household" list's task sheet, skipping any
      // picker since it's the only to-do list.
      expect(find.text('Household'), findsWidgets);
      expect(find.text('Add task'), findsWidgets);
    },
  );

  testWidgets(
    'Quick-Add chooser → Task shows a picker when multiple to-do lists exist',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await tester.tap(find.byKey(const ValueKey('nav-lists')));
      await tester.pumpAndSettle();

      for (final name in ['Household', 'Errands']) {
        await tester.tap(find.text('New list'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, name);
        await tester.pump();
        await tester.tap(find.text('Create list'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const ValueKey('nav-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quickadd-task')));
      await tester.pumpAndSettle();

      expect(find.text('Add a task'), findsOneWidget);
      expect(find.text('Which list should it go on?'), findsOneWidget);
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) =>
                  w is GestureDetector &&
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.startsWith('pick-list-'),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Errands'), findsWidgets);
    },
  );

  testWidgets('Quick-Add chooser → Shopping item goes straight to the single '
      'shopping list', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-lists')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Supermarket');
    await tester.pump();
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quickadd-shopping')));
    await tester.pumpAndSettle();

    expect(find.text('Supermarket'), findsWidgets);
  });

  testWidgets('Quick-Add chooser → Shopping item shows a picker when multiple '
      'shopping lists exist', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-lists')));
    await tester.pumpAndSettle();

    for (final name in ['Supermarket', 'Pharmacy']) {
      await tester.tap(find.text('New list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shopping'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, name);
      await tester.pump();
      await tester.tap(find.text('Create list'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quickadd-shopping')));
    await tester.pumpAndSettle();

    expect(find.text('Add a shopping item'), findsOneWidget);
    expect(find.text('Which list should it go on?'), findsOneWidget);
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) =>
                w is GestureDetector &&
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith('pick-list-'),
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Pharmacy'), findsWidgets);
  });
}
