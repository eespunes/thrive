import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'settings_v2_seed.dart';

/// #401 status chips and error sheets (`Offline Screen.dc.html`).
void main() {
  testWidgets('a main-screen edit floats Saving… → Saved, then clears', (
    tester,
  ) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    expect(find.byType(StatusChip), findsNothing);

    thriveDebug.mutateState(() {});
    await tester.pump();
    expect(find.byKey(const ValueKey('status-chip-saving')), findsOneWidget);
    expect(find.text('Saving…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('status-chip-saved')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pumpAndSettle();
    expect(find.byType(StatusChip), findsNothing);
  });

  testWidgets('offline: the floating chip stays until saves get through', (
    tester,
  ) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    thriveDebug.netOffline.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('status-chip-queued')), findsOneWidget);
    expect(find.text('Offline · saved on phone'), findsOneWidget);

    thriveDebug.netOffline.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(StatusChip), findsNothing);
  });

  testWidgets('tapping the offline chip syncs now', (tester) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    thriveDebug.netOffline.value = true;
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('status-chip-queued')));
    // Still flagged offline: the sync settles back on the offline chip.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('status-chip-queued')), findsOneWidget);
    thriveDebug.netOffline.value = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('"changes waiting to sync" sheet: Got it / Try syncing now', (
    tester,
  ) async {
    await pumpApp(tester, prefs: settingsV2Prefs(), landOnDefaultTab: true);
    thriveDebug.showWaitingToSyncSheet();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('status-sheet')), findsOneWidget);
    expect(find.text('Changes waiting to sync'), findsOneWidget);
    expect(
      find.textContaining('Your changes are saved on this phone'),
      findsOneWidget,
    );

    // Only one sheet at a time.
    thriveDebug.showWaitingToSyncSheet();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('status-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('status-sheet-primary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('status-sheet')), findsNothing);

    thriveDebug.showWaitingToSyncSheet();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('status-sheet-secondary')));
    await tester.pump(const Duration(milliseconds: 300));
    // Online (local mode saves straight away): Syncing settles to "Saved".
    expect(find.byKey(const ValueKey('status-chip-saved')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('status-sheet')), findsNothing);
  });

  testWidgets('sheet card: busy primary dims and swaps its label', (
    tester,
  ) async {
    var taps = 0;
    Widget card(bool busy) => MaterialApp(
      home: Scaffold(
        body: StatusSheetCard(
          tone: StatusTone.amber,
          title: 'Can’t connect to Thrive',
          body: 'Your family’s data lives online.',
          primary: 'Try again',
          busy: busy,
          busyLabel: 'Connecting…',
          onPrimary: () => taps++,
          primaryKey: const ValueKey('p'),
        ),
      ),
    );
    await tester.pumpWidget(card(false));
    await tester.tap(find.byKey(const ValueKey('p')));
    expect(taps, 1);
    await tester.pumpWidget(card(true));
    expect(find.text('Connecting…'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('p')));
    expect(taps, 1);
  });

  testWidgets('can’t connect: greyed app under the sheet; retry, then '
      'Connecting…', (tester) async {
    var retries = 0;
    Widget screen(bool busy) => MaterialApp(
      home: Scaffold(
        body: CloudOfflineScreen(onRetry: () => retries++, busy: busy),
      ),
    );
    await tester.pumpWidget(screen(false));
    expect(find.byKey(const ValueKey('cloud-offline-screen')), findsOneWidget);
    expect(find.text('Can’t connect to Thrive'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cloud-offline-retry')));
    expect(retries, 1);

    await tester.pumpWidget(screen(true));
    expect(find.text('Connecting…'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cloud-offline-retry')));
    expect(retries, 1);
  });

  testWidgets('status sheet: secondary button and every tone render', (
    tester,
  ) async {
    final taps = <String>[];
    for (final tone in StatusTone.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showStatusSheet(
                  context,
                  tone: tone,
                  title: 'T ${tone.name}',
                  body: 'B',
                  primary: 'P',
                  onPrimary: () => taps.add('p'),
                  secondary: 'S',
                  onSecondary: () => taps.add('s'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('T ${tone.name}'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('status-sheet-secondary')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('status-sheet')), findsNothing);
    }
    expect(taps, List.filled(StatusTone.values.length, 's'));
  });

  testWidgets('every chip kind renders, light and dark', (tester) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (final k in StatusChipKind.values)
                  SizedBox(
                    width: 260,
                    child: StatusChip(
                      kind: k,
                      text: statusChipText(k),
                      dark: dark,
                      compact: !dark,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      for (final k in StatusChipKind.values) {
        expect(find.text(statusChipText(k)), findsOneWidget);
      }
    }
  });

  test('chip texts', () {
    expect(
      statusChipText(StatusChipKind.syncing, count: 3),
      'Syncing 3 changes',
    );
    expect(
      statusChipText(StatusChipKind.syncing, count: 1),
      'Syncing 1 change',
    );
    expect(statusChipText(StatusChipKind.offline), 'Offline · saved on phone');
  });
}
