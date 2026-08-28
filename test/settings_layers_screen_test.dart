import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'settings_v2_seed.dart';

/// Calendar layers sub-screen + layer studio (#327).
void main() {
  Future<void> openLayers(WidgetTester tester) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    await openMoreHub(tester);
    await tapHubRow(tester, 'planning', 'more-callayers');
  }

  testWidgets('lists every layer with its visibility toggle', (tester) async {
    await openLayers(tester);
    expect(find.text('Calendar layers'), findsWidgets);
    expect(find.byKey(const ValueKey('layers-row-appt')), findsOneWidget);
    expect(find.byKey(const ValueKey('layers-row-task')), findsOneWidget);
    expect(find.byKey(const ValueKey('layers-row-content')), findsOneWidget);
    expect(find.textContaining('hold a row and drag'), findsOneWidget);
  });

  testWidgets('visibility toggles drive layerFilter with a min-1 guard toast', (
    tester,
  ) async {
    await openLayers(tester);
    // Turn two layers off…
    await tester.tap(find.byKey(const ValueKey('layers-toggle-task')));
    await tester.pump();
    expect(thriveDebug.layerFilter, isNot(contains('task')));
    await tester.tap(find.byKey(const ValueKey('layers-toggle-content')));
    await tester.pump();
    expect(thriveDebug.layerFilter, ['appt']);
    // …the last one refuses with the guard toast.
    await tester.tap(find.byKey(const ValueKey('layers-toggle-appt')));
    await tester.pump();
    expect(thriveDebug.layerFilter, ['appt']);
    expect(find.text('At least one layer stays on'), findsOneWidget);
  });

  testWidgets('add creates the layer with a toast (no editor)', (tester) async {
    await openLayers(tester);
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'Workouts',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    expect(find.text('"Workouts" added'), findsOneWidget);
    expect(find.text('Workouts'), findsOneWidget);
    expect(thriveDebug.calendarLayers.length, 4);
    // New layers start visible everywhere.
    final id = thriveDebug.calendarLayers.last.id;
    expect(thriveDebug.layerFilter, contains(id));
    expect(thriveDebug.kitchenLayerFilter, contains(id));
  });

  testWidgets('hold-drag reorders the shared layer order', (tester) async {
    await openLayers(tester);
    await holdDragReorder(
      tester,
      find.byKey(const ValueKey('layers-row-appt')),
      120,
    );
    expect(thriveDebug.calendarLayers.first.id, isNot('appt'));
    expect(find.text('Order saved for the whole family'), findsOneWidget);
  });

  testWidgets('studio renames, recolours and saves a layer', (tester) async {
    await openLayers(tester);
    await tester.tap(find.byKey(const ValueKey('layers-row-appt')));
    await tester.pumpAndSettle();
    expect(find.text('Edit layer'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('badge-stage-name')),
      'Meetings',
    );
    await tester.tap(
      find.byKey(ValueKey('badge-color-${const Color(0xffe11d48).toARGB32()}')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    final def = thriveDebug.calendarLayers.firstWhere((l) => l.id == 'appt');
    expect(def.label, 'Meetings');
    expect(def.color, const Color(0xffe11d48));
    expect(find.text('Meetings'), findsOneWidget);
  });

  testWidgets('delete counts the events and moves them to another layer', (
    tester,
  ) async {
    await openLayers(tester);
    await tester.tap(find.byKey(const ValueKey('layers-row-appt')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-delete')));
    await tester.pumpAndSettle();
    // The seed has 1 appointment event.
    expect(
      find.text('It takes its 1 event with it — it moves to another layer.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
    await tester.pumpAndSettle();
    expect(thriveDebug.calendarLayers.any((l) => l.id == 'appt'), isFalse);
    // The event moved to the fallback layer (To-Dos).
    expect(thriveDebug.events.firstWhere((e) => e.id == 'ev1').layerId, 'task');
    expect(find.byKey(const ValueKey('layers-row-appt')), findsNothing);
  });

  testWidgets('the last remaining layer has no delete link', (tester) async {
    await openLayers(tester);
    // Delete down to one layer via the mutation API to keep the test lean.
    thriveDebug.mutateState(() {
      thriveDebug.calendarLayers.removeWhere((l) => l.id != 'appt');
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('layers-row-appt')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-delete')), findsNothing);
  });
}
