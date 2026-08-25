import 'dart:typed_data';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'helpers.dart';

// The family wallet flows (epic #222): More-hub entry, wallet list, card
// face + till logging, photo-import review sheet, card-on-expense picker,
// pay-from-item and pay-from-card, delete, and the month-closed rule.

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

void main() {
  testWidgets('wallet is reachable from More and shows the empty state', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    expect(find.text('Discount cards'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('more-wallet')));
    await tester.pumpAndSettle();
    expect(find.text('No cards yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-scan')), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-import')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wallet-back')));
    await tester.pumpAndSettle();
    expect(find.text('No cards yet'), findsNothing);
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
    expect(find.text('Albert Heijn'), findsOneWidget);
    expect(find.textContaining('•••• 3457'), findsOneWidget);
    expect(find.textContaining('Never used'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wallet-card-c1')));
    await tester.pumpAndSettle();
    expect(find.text('Hold the screen at the scanner'), findsOneWidget);
    expect(find.text('5901234123457'), findsOneWidget);
    expect(find.byKey(const ValueKey('cardface-code')), findsOneWidget);
    expect(find.text('times used'), findsOneWidget);
    expect(find.text('whose card'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cardface-scanned')));
    await tester.pumpAndSettle();
    expect(thriveDebug.cards.single.timesUsed, 1);
    expect(thriveDebug.cards.single.lastUsedMillis, isNotNull);
    expect(kAnalyticsEvents.map((e) => e.name), contains('card_used_at_till'));
    await tester.tap(find.byKey(const ValueKey('cardface-close')));
    await tester.pumpAndSettle();
  });

  testWidgets('import review sheet: badges, required name, save', (
    tester,
  ) async {
    await pumpApp(tester);
    kAnalyticsEvents.clear();
    thriveDebug.importCardFromBytes(_redPhoto());
    await tester.pumpAndSettle();
    expect(find.text('Check the card'), findsOneWidget);
    // No code in a plain photo; the colour was sampled; name always asked.
    expect(find.text('Type the number'), findsOneWidget);
    expect(find.text('Colour matched'), findsOneWidget);
    expect(find.text('Add the shop name'), findsOneWidget);

    // Confirm disabled until a shop name is entered.
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Check the card'), findsOneWidget);
    expect(thriveDebug.cards, isEmpty);

    await tester.enterText(find.byType(TextField).first, 'Kruidvat');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('card-type-qr')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('card-owner-family')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
    await tester.pumpAndSettle();

    final saved = thriveDebug.cards.single;
    expect(saved.name, 'Kruidvat');
    expect(saved.codeType, 'qr');
    expect(saved.photo, isNotNull);
    // Sampled dominant colour, not a random palette pick.
    expect((saved.color.r * 255).round(), greaterThan(120));
    expect(kAnalyticsEvents.map((e) => e.name), contains('card_scanned'));
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
    expect(find.text('DISCOUNT CARD'), findsOneWidget);
    expect(find.byKey(const ValueKey('exp-card-none')), findsOneWidget);
    expect(find.byKey(const ValueKey('exp-card-scan')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('exp-card-c1')));
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
    expect(
      thriveDebug.unpaidItemsThisMonth().map((e) => e.$2.id),
      isNot(contains(item.id)),
    );
    expect(cat.isIncome, isFalse);
  });

  testWidgets('"Pay something with it" pays an open item of the month', (
    tester,
  ) async {
    await pumpApp(tester);
    thriveDebug.saveCard(_card());
    await tester.pumpAndSettle();
    final (_, item) = thriveDebug.unpaidItemsThisMonth().first;
    thriveDebug.openCardFace('c1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cardface-paysomething')));
    await tester.pumpAndSettle();
    expect(find.text('Pay something with it'), findsWidgets);
    await tester.tap(find.byKey(ValueKey('paywith-${item.id}')));
    await tester.pumpAndSettle();
    expect(item.paid, isTrue);
    expect(item.cardId, 'c1');
  });

  testWidgets('paying respects the month-closed rule', (tester) async {
    await pumpApp(tester);
    thriveDebug.saveCard(_card());
    await tester.pumpAndSettle();
    final open = thriveDebug.unpaidItemsThisMonth();
    final (cat, item) = open.first;
    thriveDebug.closeMonth();
    await tester.pumpAndSettle();
    thriveDebug.payItemWithCard(cat.key, item.id, 'c1');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(item.paid, isFalse);
    expect(thriveDebug.cards.single.timesUsed, 0);
    thriveDebug.reopenMonth();
    await tester.pumpAndSettle();
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
    expect(find.textContaining('whole family'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(thriveDebug.cards, isEmpty);
    // The item keeps working; its tag just no longer resolves.
    expect(item.cardId, 'c1');
    await tester.tap(find.byKey(const ValueKey('wallet-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('card-tag-${item.id}')), findsNothing);
  });

  testWidgets('home shows a cards glance and quick-add opens the wallet', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    expect(find.byKey(const ValueKey('home-card-c1')), findsNothing);
    thriveDebug.saveCard(_card());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-card-c1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-card-c1')));
    await tester.pumpAndSettle();
    expect(find.text('Hold the screen at the scanner'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cardface-close')));
    await tester.pumpAndSettle();

    thriveDebug.openQuickAdd();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quickadd-card')));
    await tester.pumpAndSettle();
    expect(find.text('Discount cards'), findsOneWidget);
  });

  testWidgets('card face survives the card being deleted while open', (
    tester,
  ) async {
    await pumpApp(tester);
    thriveDebug.saveCard(_card());
    await tester.pumpAndSettle();
    thriveDebug.openCardFace('c1');
    await tester.pumpAndSettle();
    thriveDebug.mutateState(
      () => thriveDebug.cards.removeWhere((c) => c.id == 'c1'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('This card is gone — go back'));
    await tester.pumpAndSettle();
  });
}
