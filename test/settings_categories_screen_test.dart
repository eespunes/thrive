import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'settings_v2_seed.dart';

/// Categories sub-screen + category studio (#325).
void main() {
  Future<void> openCats(WidgetTester tester) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    await openMoreHub(tester);
    await tapHubRow(tester, 'planning', 'more-calmanage');
  }

  testWidgets('rows carry the "layer · N members" subtitle', (tester) async {
    await openCats(tester);
    expect(find.text('Categories'), findsWidgets);
    expect(find.byKey(const ValueKey('cats-row-ec1')), findsOneWidget);
    expect(find.text('Appointments · 2 members'), findsOneWidget);
    expect(find.text('To-Dos · no one assigned'), findsOneWidget);
  });

  testWidgets('add-then-open: a typed name creates and opens the studio', (
    tester,
  ) async {
    await openCats(tester);
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'Sports',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    expect(find.text('Edit category'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(thriveDebug.eventCategories.length, 3);
    await tester.tap(find.byKey(const ValueKey('studio-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('list-add-input')), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
  });

  testWidgets('layer chips single-select and people chips multi-select', (
    tester,
  ) async {
    await openCats(tester);
    await tester.tap(find.byKey(const ValueKey('cats-row-ec1')));
    await tester.pumpAndSettle();
    // Move the category to the To-Dos layer.
    await tester.tap(find.byKey(const ValueKey('cat-layer-task')));
    await tester.pump();
    // Unassign Erik, keep Eva.
    await tester.tap(find.byKey(const ValueKey('cat-person-m2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    final cat = thriveDebug.eventCategories.firstWhere((c) => c.id == 'ec1');
    expect(cat.layerId, 'task');
    expect(cat.members, ['me']);
    expect(find.text('To-Dos · 1 member'), findsOneWidget);
  });

  testWidgets('delete confirms that events keep their times', (tester) async {
    await openCats(tester);
    await tester.tap(find.byKey(const ValueKey('cats-row-ec1')));
    await tester.pumpAndSettle();
    expect(
      find.text('Delete category — events keep their times'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('studio-delete')));
    await tester.pumpAndSettle();
    expect(
      find.text('Its 1 event keeps its time — it just loses the badge.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
    await tester.pumpAndSettle();
    expect(thriveDebug.eventCategories.any((c) => c.id == 'ec1'), isFalse);
    // The event survives, just uncategorised.
    expect(
      thriveDebug.events.firstWhere((e) => e.id == 'ev1').category,
      isNull,
    );
  });

  testWidgets('cancel on the counting confirm keeps the category', (
    tester,
  ) async {
    await openCats(tester);
    await tester.tap(find.byKey(const ValueKey('cats-row-ec2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('counting-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(thriveDebug.eventCategories.any((c) => c.id == 'ec2'), isTrue);
  });
}
