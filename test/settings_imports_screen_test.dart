import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';
import 'settings_v2_seed.dart';

const String _ics =
    'BEGIN:VCALENDAR\n'
    'BEGIN:VEVENT\nUID:a1\nSUMMARY:Match day\nDTSTART;VALUE=DATE:20260715\n'
    'LOCATION:Stadium\nDESCRIPTION:League round\nEND:VEVENT\n'
    'BEGIN:VEVENT\nUID:a2\nSUMMARY:Training\nDTSTART;VALUE=DATE:20260716\n'
    'END:VEVENT\nEND:VCALENDAR\n';

/// Imported calendars sub-screen + feed studio (#326).
void main() {
  setUp(() {
    icsHttpGetOverride = (uri) async => http.Response(_ics, 200);
  });
  tearDown(() => icsHttpGetOverride = null);

  Future<void> openImports(WidgetTester tester) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    await openMoreHub(tester);
    await tapHubRow(tester, 'planning', 'more-calimports');
  }

  testWidgets('rich rows: subtitle, status pill and quick chips', (
    tester,
  ) async {
    await openImports(tester);
    expect(find.text('Imported calendars'), findsWidgets);
    expect(find.byKey(const ValueKey('imports-row-imp1')), findsOneWidget);
    expect(find.text('ICS · 1 event · Synced'), findsOneWidget);
    expect(find.text('Shown'), findsOneWidget);
    expect(find.text('✕ Auto-sync off'), findsOneWidget);
    expect(find.text('✓ Location'), findsOneWidget);
    expect(find.text('✓ Description'), findsOneWidget);
  });

  testWidgets('quick chips flip auto-sync, location, description and '
      'visibility', (tester) async {
    await openImports(tester);
    await tester.tap(find.byKey(const ValueKey('imp-chip-autosync-imp1')));
    await tester.pump();
    expect(thriveDebug.importedCalendars.first.autoSync, isTrue);
    expect(find.text('✓ Auto-syncs on open'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('imp-chip-loc-imp1')));
    await tester.pump();
    expect(thriveDebug.importedCalendars.first.includeLocation, isFalse);
    await tester.tap(find.byKey(const ValueKey('imp-chip-desc-imp1')));
    await tester.pump();
    expect(thriveDebug.importedCalendars.first.includeDescription, isFalse);
    await tester.tap(find.byKey(const ValueKey('imp-chip-vis-imp1')));
    await tester.pump();
    expect(thriveDebug.importedCalendars.first.visible, isFalse);
    expect(find.text('Feed hidden from the calendar'), findsOneWidget);
    expect(find.text('Hidden'), findsWidgets);
  });

  testWidgets('a failing feed shows the amber pill; Sync now clears it', (
    tester,
  ) async {
    await openImports(tester);
    thriveDebug.markImportFailed('imp1');
    await tester.pumpAndSettle();
    expect(find.text('Failing'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('imp-chip-sync-imp1')));
    await tester.pumpAndSettle();
    expect(thriveDebug.failedImportIds, isEmpty);
    expect(find.text('Failing'), findsNothing);
    // The canned feed carries 2 events.
    expect(thriveDebug.importedCalendars.first.events.length, 2);
  });

  testWidgets('pasting an iCal link imports the feed and opens its editor', (
    tester,
  ) async {
    await openImports(tester);
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'https://feeds.example.com/team.ics',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    expect(thriveDebug.importedCalendars.length, 2);
    // Add-then-open: the editor is on screen, named after the link's host.
    expect(find.text('Edit imported calendar'), findsOneWidget);
    expect(find.text('feeds.example.com'), findsWidgets);
  });

  testWidgets('editor: three cards, reminder chip and category tint save', (
    tester,
  ) async {
    await openImports(tester);
    await tester.tap(find.byKey(const ValueKey('imports-row-imp1')));
    await tester.pumpAndSettle();
    expect(find.text('THE LINK'), findsOneWidget);
    expect(find.text('WHAT EACH EVENT BRINGS IN'), findsOneWidget);
    expect(find.text('HOW IT SHOWS IN THRIVE'), findsOneWidget);
    expect(find.textContaining('1 event ·'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('imp-autosync')));
    await tester.pump();
    // Default reminder row scrolls; pick "2 days before".
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('imp-reminder-2d')),
      80,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('imp-reminder-2d')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('imp-cat-ec1')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('imp-cat-ec1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    final cal = thriveDebug.importedCalendars.first;
    expect(cal.autoSync, isTrue);
    expect(cal.reminder, '2d');
    expect(cal.category, 'ec1');
    // The row now shows the category name in its subtitle.
    expect(find.textContaining('Family · ICS'), findsOneWidget);
  });

  testWidgets('editor delete removes the feed and its events', (tester) async {
    await openImports(tester);
    await tester.tap(find.byKey(const ValueKey('imports-row-imp1')));
    await tester.pumpAndSettle();
    expect(
      find.text('Remove this calendar — its events disappear'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('studio-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('It takes its 1 event with it'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
    await tester.pumpAndSettle();
    expect(thriveDebug.importedCalendars, isEmpty);
    expect(find.byKey(const ValueKey('imports-row-imp1')), findsNothing);
  });

  testWidgets('Sync now surfaces a fetch error and marks the feed failing', (
    tester,
  ) async {
    await openImports(tester);
    icsHttpGetOverride = (uri) async => http.Response('nope', 500);
    await tester.tap(find.byKey(const ValueKey('imp-chip-sync-imp1')));
    await tester.pumpAndSettle();
    expect(thriveDebug.failedImportIds, contains('imp1'));
    expect(find.text('Calendar link returned 500'), findsOneWidget);
    expect(find.text('Failing'), findsWidgets);
  });

  testWidgets('a bad pasted link toasts the error instead of opening an '
      'editor', (tester) async {
    await openImports(tester);
    icsHttpGetOverride = (uri) async => http.Response('nope', 404);
    await tester.enterText(
      find.byKey(const ValueKey('list-add-input')),
      'https://feeds.example.com/broken.ics',
    );
    await tester.tap(find.byKey(const ValueKey('list-add-button')));
    await tester.pumpAndSettle();
    expect(thriveDebug.importedCalendars.length, 1);
    expect(find.text('Edit imported calendar'), findsNothing);
    expect(find.text('Calendar link returned 404'), findsOneWidget);
  });
}
