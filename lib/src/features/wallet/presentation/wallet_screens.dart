part of 'package:family_money_management_app/main.dart';

/// Family wallet (epic #222), mirroring the design's discount-cards flows
/// (`Thrive.dc.html`: `sheetCardWallet` / `sheetCardFace` and the card
/// mutations). Everything is a bottom sheet; this file holds the actions
/// and the card face.
extension _ThriveWallet on _ThriveHomeState {
  /// Opens the wallet sheet. (Kept under the historical name — every entry
  /// point routes through here.)
  void openWalletScreen() => _showSheet((ctx) => _WalletSheet(state: this));

  /// Opens a card's face sheet. With [payCat]/[payItemId] it opens in
  /// "paying" mode: the primary action marks that expense item paid with
  /// this card (issue #231).
  void openCardFace(String cardId, {String? payCat, String? payItemId}) {
    _showSheet(
      (ctx) => _CardFaceSheet(
        state: this,
        cardId: cardId,
        payCat: payCat,
        payItemId: payItemId,
      ),
    );
  }

  DiscountCard? cardById(String? id) =>
      id == null ? null : cards.where((c) => c.id == id).firstOrNull;

  String cardOwnerName(DiscountCard c) =>
      (curFamily()?.members.where((m) => m.id == c.ownerId).firstOrNull?.name ??
              'Family')
          .split(' ')
          .first;

  void saveCard(DiscountCard card) {
    mutate(
      () => cards.add(card),
      () => flash('${card.name} saved to your wallet'),
    );
    logAnalyticsEvent('card_scanned', {
      'codeType': card.codeType,
      'numberDetected': card.number.isNotEmpty,
    });
  }

  /// Swipe-delete with a confirmation that states it affects the whole
  /// family (issue #229). Expense items keep their `cardId`; the tag simply
  /// no longer resolves and disappears from the finance list.
  void confirmDeleteCard(DiscountCard c) {
    askDelete(
      c.name,
      'The whole family loses this card at the till.',
      () => mutate(
        () => cards.removeWhere((x) => x.id == c.id),
        () => flash('Card removed'),
      ),
    );
  }

  /// "Scanned at the till" — bumps the use counter + last-used (issue #228).
  void logCardUse(String cardId, [String? msg]) {
    final c = cardById(cardId);
    if (c == null) return;
    mutate(
      () => c.logUse(DateTime.now().millisecondsSinceEpoch),
      () => flash(msg ?? '${c.name} scanned'),
    );
    logAnalyticsEvent('card_used_at_till', {'card': cardId});
  }

  /// This month's unpaid expense items, for "pay something with it"
  /// (issue #232). Income blocks don't take part.
  List<(Category, ExpenseItem)> unpaidItemsThisMonth() {
    final m = data[year]?[kMonthKeys[monthIdx]];
    if (m == null) return const [];
    return [
      for (final c in cats.where((c) => !c.isIncome))
        for (final it in m.blocks[c.key] ?? const <ExpenseItem>[])
          if (!it.paid) (c, it),
    ];
  }

  /// Marks [itemId] paid with [cardId]: sets the paid flag, stores the card
  /// on the item, logs a card use, and toasts (issues #231/#232). Respects
  /// the month-closed rule.
  void payItemWithCard(String catKey, String itemId, String cardId) {
    if (isClosed()) {
      showError('Month is closed');
      return;
    }
    final card = cardById(cardId);
    ExpenseItem? hit;
    mutate(() {
      final arr = data[year]?[kMonthKeys[monthIdx]]?.blocks[catKey];
      final it = arr?.where((x) => x.id == itemId).firstOrNull;
      if (it == null) return;
      it
        ..paid = true
        ..cardId = cardId
        ..generated = false;
      card?.logUse(DateTime.now().millisecondsSinceEpoch);
      hit = it;
    }, () => flash("${_itemTitle(hit)} paid with ${card?.name ?? 'card'}"));
    if (hit != null) {
      logAnalyticsEvent('expense_paid_with_card', {
        'card': cardId,
        'amount': hit!.amount,
      });
    }
  }

  /// "Pin the wallet to my home" (design `pinWalletWidget`): places the
  /// Discount-cards widget on this member's Home board.
  void pinWalletWidget() {
    if (effectiveHomeBoard().any((e) => e.widgetId == 'cards_wallet')) {
      flash('Already on your home');
      return;
    }
    addHomeWidget('cards_wallet');
    flash('Wallet pinned to your home');
  }
}

String _itemTitle(ExpenseItem? it) {
  if (it == null) return 'item';
  final t = it.payee.trim().isNotEmpty ? it.payee.trim() : it.label.trim();
  return t.isEmpty ? 'item' : t;
}

/// "last used 26 Jun" / "not used yet" for wallet rows.
String cardLastUsedLabel(int? millis, DateTime now) {
  if (millis == null) return 'not used yet';
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return 'last used ${d.day} ${kMonthsEn[d.month - 1].substring(0, 3)}';
}

/// The card number spaced in groups of four, as printed on the card face.
String cardSpacedNumber(String digits) =>
    digits.replaceAllMapped(RegExp(r'\d{4}(?=\d)'), (m) => '${m[0]} ');

/// Picks the symbology the card face renders with: QR for QR cards, EAN-13
/// when the number is a valid EAN-13, Code 128 otherwise (every till scanner
/// reads it and it accepts any length).
bw.Barcode cardBarcodeFor(DiscountCard c) {
  if (c.codeType == 'qr') return bw.Barcode.qrCode();
  if (isValidEan13(c.number)) return bw.Barcode.ean13();
  return bw.Barcode.code128();
}

/// The design's card visual: coloured plate, photo underlay, name + note,
/// code-type icon tile and the spaced digits (design `cardFaceEl`).
class _CardVisual extends StatelessWidget {
  const _CardVisual({required this.card, required this.height});
  final DiscountCard card;
  final double height;

  @override
  Widget build(BuildContext context) {
    final photo = card.photo;
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: card.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0f172a).withValues(alpha: .65),
            blurRadius: 34,
            spreadRadius: -22,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null)
            Opacity(
              opacity: .35,
              child: Image.memory(
                base64Decode(photo),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x3dffffff), Color(0x6b0f172a)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.3,
                              color: Colors.white,
                            ),
                          ),
                          if (card.note.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                card.note,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: .88),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: ic(
                          card.codeType == 'qr' ? 'grid' : 'signal',
                          size: 16,
                          sw: 2.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  cardSpacedNumber(card.number),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: Colors.white.withValues(alpha: .95),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================== card face

/// Card face sheet (design `sheetCardFace`): the card visual, a white plate
/// with the till-legible code, usage meta tiles, the primary action, an
/// inline "Pay something with it" list, and Remove card.
class _CardFaceSheet extends StatefulWidget {
  const _CardFaceSheet({
    required this.state,
    required this.cardId,
    this.payCat,
    this.payItemId,
  });
  final _ThriveHomeState state;
  final String cardId;
  final String? payCat;
  final String? payItemId;

  @override
  State<_CardFaceSheet> createState() => _CardFaceSheetState();
}

class _CardFaceSheetState extends State<_CardFaceSheet> {
  _ThriveHomeState get s => widget.state;

  @override
  void initState() {
    super.initState();
    // NFR (issue #228): raise the screen brightness while the card face is
    // open so till scanners read it. Best-effort — unsupported platforms
    // (web, tests) simply keep their brightness.
    unawaited(
      ScreenBrightness().setApplicationScreenBrightness(1.0).catchError((_) {}),
    );
  }

  @override
  void dispose() {
    unawaited(
      ScreenBrightness().resetApplicationScreenBrightness().catchError((_) {}),
    );
    super.dispose();
  }

  ExpenseItem? get _payItem {
    final cat = widget.payCat;
    if (cat == null) return null;
    return (s.cur()?.blocks[cat] ?? const <ExpenseItem>[])
        .where((x) => x.id == widget.payItemId)
        .firstOrNull;
  }

  Widget _plate(DiscountCard c) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: cardShadow(),
      ),
      child: Column(
        children: [
          if (c.number.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No card number saved',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: B.muted,
                ),
              ),
            )
          else ...[
            bw.BarcodeWidget(
              key: const ValueKey('cardface-code'),
              barcode: cardBarcodeFor(c),
              data: c.number,
              height: c.codeType == 'qr' ? 150 : 66,
              width: c.codeType == 'qr' ? 150 : double.infinity,
              drawText: false,
              color: Colors.black,
              errorBuilder: (_, _) => const Text(
                'This number cannot be rendered as a code',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: B.muted,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              c.number,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: B.text,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ic('sun', size: 12, sw: 2.4, color: B.muted),
              const SizedBox(width: 6),
              const Text(
                'Hold the screen at the scanner',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: B.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(DiscountCard c) {
    Widget cell(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: B.faint,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: B.muted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: B.ink,
              ),
            ),
          ],
        ),
      ),
    );

    final last = c.lastUsedMillis == null
        ? '—'
        : cardLastUsedLabel(
            c.lastUsedMillis,
            DateTime.now(),
          ).replaceFirst('last used ', '');
    return Padding(
      padding: const EdgeInsets.only(top: 13, bottom: 15),
      child: Row(
        children: [
          cell('Used', '${c.timesUsed}×'),
          const SizedBox(width: 9),
          cell('Last used', last),
          const SizedBox(width: 9),
          cell('Card of', s.cardOwnerName(c)),
        ],
      ),
    );
  }

  /// Inline "Pay something with it" list (design: up to 4 open items with
  /// their block icon and amount).
  Widget _payList(DiscountCard c) {
    final open = s.unpaidItemsThisMonth();
    if (open.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            'PAY SOMETHING WITH IT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
              color: B.muted,
            ),
          ),
        ),
        for (final (cat, it) in open.take(4))
          GestureDetector(
            key: ValueKey('paywith-${it.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              s.payItemWithCard(cat.key, it.id, c.id);
              Navigator.of(context).pop();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: B.line),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: cat.bg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: ic(cat.icon, size: 15, sw: 2.1, color: cat.tone),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _itemTitle(it),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: B.ink,
                          ),
                        ),
                        Text(
                          cat.title,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: B.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    eur(it.amount),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = s.cardById(widget.cardId);
    if (c == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [_sheetHead(context, 'Card', 'Not found')],
      );
    }
    final payItem = _payItem;
    final paying = payItem != null && !payItem.paid;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHead(
          context,
          c.name,
          paying ? 'Paying · ${_itemTitle(payItem)}' : 'Ready for the scanner',
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardVisual(card: c, height: 124),
                _plate(c),
                _meta(c),
                if (paying)
                  KeyedSubtree(
                    key: const ValueKey('cardface-paywith'),
                    child: _primaryBtn(
                      "Mark '${_itemTitle(payItem)}' paid",
                      () {
                        s.payItemWithCard(widget.payCat!, payItem.id, c.id);
                        Navigator.of(context).pop();
                      },
                    ),
                  )
                else ...[
                  KeyedSubtree(
                    key: const ValueKey('cardface-scanned'),
                    child: _primaryBtn('Scanned at the till', () {
                      s.logCardUse(c.id, '${c.name} · logged');
                      Navigator.of(context).pop();
                    }),
                  ),
                  _payList(c),
                ],
                GestureDetector(
                  key: const ValueKey('cardface-remove'),
                  onTap: () {
                    Navigator.of(context).pop();
                    s.confirmDeleteCard(c);
                  },
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(0, 14, 0, 2),
                    child: Text(
                      'Remove card',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: B.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
