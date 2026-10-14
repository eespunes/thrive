import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget headerHarness(Widget header) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: header)),
  ),
);

void main() {
  testWidgets('tabs have no leading slot and a period picker in the subtitle', (
    tester,
  ) async {
    var picked = false;
    await tester.pumpWidget(
      headerHarness(
        AppHeader(
          title: 'Calendar',
          subtitle: 'October 2026',
          subtitleOnPressed: () => picked = true,
          statusPill: 'PAST',
          actions: [
            AppHeaderAction(
              icon: 'search',
              tooltip: 'Search',
              onPressed: () {},
            ),
          ],
          toolbar: const Text('Month · Week · Agenda'),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('app-header-leading')), findsNothing);
    expect(find.text('PAST'), findsOneWidget);
    expect(find.text('Month · Week · Agenda'), findsOneWidget);
    await tester.tap(find.text('October 2026'));
    expect(picked, isTrue);
  });

  testWidgets('offline chip takes priority over the second icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      headerHarness(
        AppHeader(
          title: 'Calendar',
          subtitle: 'October 2026',
          statusChip: const Text('Not saved'),
          actions: [
            AppHeaderAction(
              icon: 'search',
              tooltip: 'Search',
              key: const ValueKey('first-action'),
              onPressed: () {},
            ),
            AppHeaderAction(
              icon: 'filter',
              tooltip: 'Layers',
              key: const ValueKey('second-action'),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Not saved'), findsOneWidget);
    expect(find.byKey(const ValueKey('first-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('second-action')), findsNothing);
  });

  testWidgets('hero and standard headers keep the same geometry', (
    tester,
  ) async {
    final standard = AppHeader(
      title: 'Finance',
      subtitle: 'October 2026',
      leading: AppHeaderLeading.back,
      textAction: 'Save',
    );
    await tester.pumpWidget(headerHarness(standard));
    final standardSize = tester.getSize(find.byType(AppHeader));

    final hero = AppHeader(
      title: 'Finance',
      subtitle: 'October 2026',
      leading: AppHeaderLeading.back,
      textAction: 'Save',
      hero: true,
    );
    await tester.pumpWidget(headerHarness(hero));
    expect(tester.getSize(find.byType(AppHeader)), standardSize);
  });

  testWidgets('long editor titles stay on one line before Save', (
    tester,
  ) async {
    await tester.pumpWidget(
      headerHarness(
        AppHeader(
          title: 'A very long editor title that cannot fit beside the action',
          subtitle: 'Badge and colour',
          leading: AppHeaderLeading.close,
          textAction: 'Save',
        ),
      ),
    );

    final title = tester.widget<Text>(
      find.text('A very long editor title that cannot fit beside the action'),
    );
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(find.text('Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolled header turns white and draws a hairline', (
    tester,
  ) async {
    await tester.pumpWidget(
      headerHarness(AppHeader(title: 'Lists', scrolled: true)),
    );
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(AppHeader),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, Colors.white);
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(AppHeader),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).border, isNotNull);
  });

  testWidgets('light headers show title, subtitle, leading and action slots', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('header-slots-golden'),
              child: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppHeader(
                      title: 'Lists',
                      subtitle: '4 notes · 7 things to do',
                    ),
                    AppHeader(
                      title: 'Groceries',
                      subtitle: '6 left · 14 total',
                      leading: AppHeaderLeading.back,
                      actions: [
                        AppHeaderAction(
                          icon: 'dots',
                          tooltip: 'More',
                          onPressed: () {},
                        ),
                      ],
                    ),
                    AppHeader(
                      title:
                          'A long editor title that must be truncated before Save',
                      subtitle: 'Badge & colour',
                      leading: AppHeaderLeading.close,
                      textAction: 'Save',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final headers = find.byType(AppHeader);
    expect(headers, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      expect(tester.getSize(headers.at(i)).width, 380);
    }
    expect(find.text('Lists'), findsOneWidget);
    expect(find.text('4 notes · 7 things to do'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('6 left · 14 total'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    final longTitle = tester.widget<Text>(
      find.text('A long editor title that must be truncated before Save'),
    );
    expect(longTitle.maxLines, 1);
    expect(longTitle.overflow, TextOverflow.ellipsis);
  });

  testWidgets('gradient hero keeps white text and transparent chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('header-hero-golden'),
              child: Container(
                width: 380,
                decoration: const BoxDecoration(gradient: B.grad),
                child: AppHeader(
                  hero: true,
                  title: 'Finance',
                  subtitle: 'October 2026',
                  subtitleOnPressed: () {},
                  statusPill: 'CLOSED',
                  actions: [
                    AppHeaderAction(
                      icon: 'lock',
                      tooltip: 'Reopen month',
                      onPressed: () {},
                      filled: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final hero = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('header-hero-golden')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((hero.decoration as BoxDecoration).gradient, B.grad);
    expect(
      tester.widget<Text>(find.text('Finance')).style!.color,
      Colors.white,
    );
    expect(
      tester.widget<Text>(find.text('October 2026')).style!.color,
      Colors.white,
    );
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(AppHeader),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, Colors.transparent);
    expect(find.text('CLOSED'), findsOneWidget);
  });

  testWidgets('search filters titles and subtitles and opens a result', (
    tester,
  ) async {
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppHeaderSearch(
                context,
                title: 'Search lists',
                items: [
                  AppHeaderSearchItem(
                    'Groceries',
                    'Shopping',
                    () => chosen = 'groceries',
                  ),
                  AppHeaderSearchItem(
                    'Weekend tasks',
                    'Home',
                    () => chosen = 'tasks',
                  ),
                ],
              ),
              child: const Text('Open search'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open search'));
    await tester.pumpAndSettle();
    expect(find.text('2 results'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'shopping');
    await tester.pumpAndSettle();
    expect(find.text('1 results'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Weekend tasks'), findsNothing);
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    expect(chosen, 'groceries');
    expect(find.text('Search lists'), findsNothing);
  });

  testWidgets('active badge, status dot, and dark scrolled colors render', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: AppHeader(
            title: 'Calendar',
            subtitle: 'October 2026',
            statusDot: Colors.green,
            scrolled: true,
            actions: [
              AppHeaderAction(
                icon: 'bell',
                tooltip: 'Notifications',
                badge: 3,
                active: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(AppHeader),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      material.color,
      ThemeData(brightness: Brightness.dark).colorScheme.surface,
    );
    expect(tester.takeException(), isNull);
  });
}
