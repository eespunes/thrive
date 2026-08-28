import 'dart:typed_data';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'helpers.dart';

// The family wallet flows (epic #222), design-aligned (`Thrive.dc.html`):
// wallet sheet, three-stage scan flow, card face sheet with inline pay
// list, delete, month-closed rule and the pin-to-home shortcut.

DiscountCard _card({String id = 'c1', String name = 'Albert Heijn'}) =>
    DiscountCard(
      id: id,
      name: name,
      number: '5901234123457',
      color: const Color(0xff1684B4),
    );

Uint8List _redPhoto() {
  final image = img.Image(width: 80, height: 60);
  img.fill(image, color: img.ColorRgb8(190, 25, 35));
  return img.encodePng(image);
}

/// Closes the topmost sheet/dialog by tapping the barrier.
Future<void> dismissSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(210, 40));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('wallet sub-page from More: empty state and scan entry (#282)', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await openHubCard(tester, 'money', 'more-wallet');
    expect(find.text('Discount cards'), findsOneWidget);
    await tapHubRow(tester, 'money', 'more-wallet');

    // The Settings v2 wallet sub-page (#282) with no cards yet.
    expect(find.textContaining('can use these at the till'), findsOneWidget);
    expect(find.textContaining('No cards yet — add one'), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-sub-add')), findsOneWidget);

    // "＋ Add a card" hands over to the pick stage of the scan sheet
    // (scanner path unchanged).
    await tester.tap(find.byKey(const ValueKey('wallet-sub-add')));
    await tester.pumpAndSettle();
    expect(find.text('Scan a discount card'), findsOneWidget);
    expect(find.text('Take a photo of the card'), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-scan-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-scan-gallery')), findsOneWidget);
    await dismissSheet(tester);
  });

  testWidgets('wallet sheet still shows empty state, scan entry and footer', (
    tester,
  ) async {
    await pumpApp(tester);
    thriveDebug.openWalletScreen();
    await tester.pumpAndSettle();
    expect(find.text('Nothing scanned yet'), findsOneWidget);
    expect(find.text('No cards yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-scan')), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-pin')), findsOneWidget);
    expect(find.textContaining('Photograph the barcode side'), findsOneWidget);
  });

  testWidgets('wallet row -> card face -> "Scanned at the till" logs a use', (
    tester,
  ) async {
    await pumpApp(tester);
    kAnalyticsEvents.clear();
    thriveDebug.saveCard(_card());
    await tester.pumpAndSettle();
    thriveDebug.openWalletScreen();
    await tester.pumpAndSettle();
    expect(find.text('1 card · shared with the family'), findsOneWidget);
    expect(find.text('Albert Heijn'), findsOneWidget);
    expect(find.textContaining('•••• 3457'), findsOneWidget);
    expect(find.textContaining('not used yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wallet-card-c1')));
    await tester.pumpAndSettle();
    expect(find.text('Ready for the scanner'), findsOneWidget);
    expect(find.text('Hold the screen at the scanner'), findsOneWidget);
    expect(find.byKey(const ValueKey('cardface-code')), findsOneWidget);
    expect(find.text('USED'), findsOneWidget);
    expect(find.text('CARD OF'), findsOneWidget);
    expect(find.text('5901 2341 2345 7'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cardface-scanned')));
    await tester.pumpAndSettle();
    expect(thriveDebug.cards.single.timesUsed, 1);
    expect(thriveDebug.cards.single.lastUsedMillis, isNotNull);
    expect(kAnalyticsEvents.map((e) => e.name), contains('card_used_at_till'));
  });

  testWidgets('scan flow: reading stage, badges, required name, save', (
    tester,
  ) async {
    await pumpApp(tester);
    kAnalyticsEvents.clear();
    thriveDebug.importCardFromBytes(_redPhoto());
    await tester.pump();
    expect(find.text('Reading the card'), findsOneWidget);
    expect(find.text('Finding the barcode…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    expect(find.text('Check the details'), findsOneWidget);
    // No code in a plain photo; the colour was sampled; name always asked.
    expect(find.text('Type the number'), findsOneWidget);
    expect(find.text('Colour matched'), findsOneWidget);
    expect(find.text('Add the shop name'), findsOneWidget);

    // Save is disabled until a shop name is entered.
    await tester.tap(find.byKey(const ValueKey('card-save')));
    await tester.pumpAndSettle();
    expect(thriveDebug.cards, isEmpty);

    await tester.enterText(find.byType(TextField).first, 'Kruidvat');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('card-type-qr')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('card-save')));
    await tester.pumpAndSettle();

    final saved = thriveDebug.cards.single;
    expect(saved.name, 'Kruidvat');
    expect(saved.codeType, 'qr');
    // The scan photo is input-only: never persisted, and cards start
    // unassigned unless an owner is explicitly picked.
    expect(saved.photo, isNull);
    expect(saved.ownerId, isNull);
    // Sampled dominant colour, not a random palette pick.
    expect((saved.color.r * 255).round(), greaterThan(120));
    expect(kAnalyticsEvents.map((e) => e.name), contains('card_scanned'));
    // The design opens the fresh card's face right away.
    expect(find.text('Ready for the scanner'), findsOneWidget);
    expect(find.text('Kruidvat'), findsNWidgets(2)); // sheet head + card face
    await dismissSheet(tester);
  });

  testWidgets('retake returns the scan flow to the pick stage', (tester) async {
    await pumpApp(tester);
    thriveDebug.importCardFromBytes(_redPhoto());
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('card-retake')));
    await tester.pumpAndSettle();
    expect(find.text('Scan a discount card'), findsOneWidget);
    await dismissSheet(tester);
  });

  testWidgets('attach a card in the expense sheet and see the tag', (
    tester,
  ) async {
    await pumpApp(tester);
    thriveDebug.saveCard(_card());
    await tester.pumpAndSettle();
    final (cat, item) = thriveDebug.unpaidItemsThisMonth().first;
    await tester.tap(
      find.byKey(ValueKey('exp-${cat.key}-${item.id}')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-badge-card')));
    await tester.pumpAndSettle();
    expect(find.text('DISCOUNT CARD'), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-card-none')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-card-scan')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('entry-card-c1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    expect(item.cardId, 'c1');
    expect(find.byKey(ValueKey('card-tag-${item.id}')), findsOneWidget);
    expect(find.textContaining('Albert Heijn'), findsWidgets);
  });

  testWidgets('card tag opens paying mode and marks the item paid', (
    tester,
  ) async {
    await pumpApp(tester);
    kAnalyticsEvents.clear();
    thriveDebug.saveCard(_card());
    await tester.pumpAndSettle();
    final open = thriveDebug.unpaidItemsThisMonth();
    expect(open, isNotEmpty);
    final (cat, item) = open.first;
    thriveDebug.mutateState(() => item.cardId = 'c1');
    await tester.pumpAndSettle();

    final tag = find.byKey(ValueKey('card-tag-${item.id}'));
    expect(tag, findsOneWidget);
    await tester.tap(tag, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Paying ·'), findsOneWidget);
    expect(find.byKey(const ValueKey('cardface-paywith')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cardface-paywith')));
    await tester.pumpAndSettle();

    expect(item.paid, isTrue);
    expect(item.cardId, 'c1');
    expect(thriveDebug.cards.single.timesUsed, 1);
    expect(
      kAnalyticsEvents.map((e) => e.name),
      contains('expense_paid_with_card'),
    );
    expect(cat.isIncome, isFalse);
  });

  testWidgets('card face lists open items inline and pays one', (tester) async {
    await pumpApp(tester);
    thriveDebug.saveCard(_card());
    await tester.pumpAndSettle();
    final (_, item) = thriveDebug.unpaidItemsThisMonth().first;
    thriveDebug.openCardFace('c1');
    await tester.pumpAndSettle();
    expect(find.text('PAY SOMETHING WITH IT'), findsOneWidget);
    await tester.tap(
      find.byKey(ValueKey('paywith-${item.id}')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(item.paid, isTrue);
    expect(item.cardId, 'c1');
  });

  testWidgets('paying respects the month-closed rule', (tester) async {
    await pumpApp(tester);
    thriveDebug.saveCard(_card());
    await tester.pumpAndSettle();
    final (cat, item) = thriveDebug.unpaidItemsThisMonth().first;
    thriveDebug.closeMonth();
    await tester.pumpAndSettle();
    thriveDebug.payItemWithCard(cat.key, item.id, 'c1');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(item.paid, isFalse);
    expect(thriveDebug.cards.single.timesUsed, 0);
    thriveDebug.reopenMonth();
    await tester.pumpAndSettle();
  });

  testWidgets('marking a tagged item paid in the list logs a card use', (
    tester,
  ) async {
    await pumpApp(tester);
    thriveDebug.saveCard(_card());
    await tester.pumpAndSettle();
    final (cat, item) = thriveDebug.unpaidItemsThisMonth().first;
    thriveDebug.mutateState(() => item.cardId = 'c1');
    thriveDebug.togglePaid(cat.key, item.id);
    await tester.pumpAndSettle();
    expect(item.paid, isTrue);
    expect(thriveDebug.cards.single.timesUsed, 1);
  });

  testWidgets('swipe-delete a card with family-wide confirmation', (
    tester,
  ) async {
    await pumpApp(tester);
    thriveDebug.saveCard(_card());
    await tester.pumpAndSettle();
    final (_, item) = thriveDebug.unpaidItemsThisMonth().first;
    thriveDebug.mutateState(() => item.cardId = 'c1');
    await tester.pumpAndSettle();
    thriveDebug.openWalletScreen();
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('wallet-card-c1'))),
    );
    await gesture.moveBy(const Offset(-24, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-196, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('wallet-swipe-c1-delete')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The whole family loses this card at the till.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(thriveDebug.cards, isEmpty);
    // The item keeps working; its tag just no longer resolves.
    expect(item.cardId, 'c1');
    expect(find.byKey(ValueKey('card-tag-${item.id}')), findsNothing);
  });

  testWidgets('pin the wallet to my home places the cards widget', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.saveCard(_card());
    await tester.pumpAndSettle();
    thriveDebug.openWalletScreen();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallet-pin')));
    await tester.pumpAndSettle();
    expect(
      thriveDebug.homeBoard!.map((e) => e.widgetId),
      contains('cards_wallet'),
    );
    expect(find.byKey(const ValueKey('home-card-c1')), findsOneWidget);

    // Pinning again just flashes.
    thriveDebug.pinWalletWidget();
    await tester.pumpAndSettle();
    expect(
      thriveDebug.homeBoard!.where((e) => e.widgetId == 'cards_wallet').length,
      1,
    );

    // The widget's tiles open the card face; Scan card opens the scan flow.
    await tester.tap(find.byKey(const ValueKey('home-card-c1')));
    await tester.pumpAndSettle();
    expect(find.text('Ready for the scanner'), findsOneWidget);
    await dismissSheet(tester);
    await tester.tap(
      find.byKey(const ValueKey('home-card-scan')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('Scan a discount card'), findsOneWidget);
    await dismissSheet(tester);
  });

  testWidgets('quick add offers "Snap a loyalty card"', (tester) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.openQuickAdd();
    await tester.pumpAndSettle();
    expect(find.text('Snap a loyalty card'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quickadd-card')));
    await tester.pumpAndSettle();
    expect(find.text('Scan a discount card'), findsOneWidget);
    await dismissSheet(tester);
  });

  testWidgets('card face for a deleted card shows Not found', (tester) async {
    await pumpApp(tester);
    thriveDebug.saveCard(_card());
    await tester.pumpAndSettle();
    thriveDebug.mutateState(
      () => thriveDebug.cards.removeWhere((c) => c.id == 'c1'),
    );
    thriveDebug.openCardFace('c1');
    await tester.pumpAndSettle();
    expect(find.text('Not found'), findsOneWidget);
    await dismissSheet(tester);
  });
}
