import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The event ticket keeps the app's single two-tab colour panel (Palette +
/// RGB / Hex) after the Settings v2 editors moved to fixed badge-colour dot
/// rows — this pins its behaviour where it still lives.
void main() {
  Future<void> openEventColourTray(WidgetTester tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Picnic');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Picnic').first);
    await tester.pumpAndSettle();
    // Month view opens the day sheet first; tap through to the event.
    if (find.text('Edit').evaluate().isEmpty) {
      await tester.tap(find.text('Picnic').last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('ticket-colour')));
    await tester.tap(
      find.byKey(const ValueKey('ticket-colour')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('RGB / Hex tab: channel fields, hex input, opacity and back to '
      'the palette', (tester) async {
    await openEventColourTray(tester);
    expect(find.text('Palette'), findsOneWidget);
    await tester.tap(find.text('RGB / Hex'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('red-channel-input')),
      '10',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('green-channel-input')),
      '20',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('blue-channel-input')),
      '30',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('hex-color-input')),
      'ABCDEF',
    );
    await tester.pump();

    // Drag the channel/opacity sliders.
    final sliders = find.byType(GestureDetector);
    await tester.drag(sliders.last, const Offset(20, 0));
    await tester.pump();

    // Back to the palette; pick a swatch.
    await tester.tap(find.text('Palette'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AnimatedContainer).last);
    await tester.pump();
  });
}
