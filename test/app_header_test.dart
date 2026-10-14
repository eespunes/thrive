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

  testWidgets('light slot combinations match the golden', (tester) async {
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
    await expectLater(
      find.byKey(const ValueKey('header-slots-golden')),
      matchesGoldenFile('goldens/app_header_slots.png'),
    );
  });

  testWidgets('gradient hero matches the golden', (tester) async {
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
    await expectLater(
      find.byKey(const ValueKey('header-hero-golden')),
      matchesGoldenFile('goldens/app_header_hero.png'),
    );
  });
}
