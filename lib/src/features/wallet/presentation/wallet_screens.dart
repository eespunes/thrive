part of 'package:family_money_management_app/main.dart';

/// Family wallet (epic #222): the card list, the full-screen card face for
/// the till, and every card mutation. Follows the Kitchen-dashboard pattern:
/// full screens are pushed as their own routes and re-derive everything from
/// the shared [_ThriveHomeState] (`_rev` bumps drive live rebuilds).
extension _ThriveWallet on _ThriveHomeState {
  void openWalletScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _WalletScreen(state: this)),
    );
  }

  /// Opens a card full-screen. With [payCat]/[payItemId] it opens in
  /// "paying" mode: the primary action marks that expense item paid with
  /// this card (issue #231).
  void openCardFace(String cardId, {String? payCat, String? payItemId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CardFaceScreen(
          state: this,
          cardId: cardId,
          payCat: payCat,
          payItemId: payItemId,
        ),
      ),
    );
  }

  DiscountCard? cardById(String? id) =>
      id == null ? null : cards.where((c) => c.id == id).firstOrNull;

  String cardOwnerName(DiscountCard c) =>
      curFamily()?.members.where((m) => m.id == c.ownerId).firstOrNull?.name ??
      'Family';

  void saveCard(DiscountCard card) {
    mutate(() => cards.add(card), () => flash('Card saved'));
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
      'This removes the card for the whole family. Items paid with it keep '
      'their history.',
      () => mutate(
        () => cards.removeWhere((x) => x.id == c.id),
        () => flash('Card deleted'),
      ),
    );
  }

  /// "Scanned at the till" — bumps the use counter + last-used (issue #228).
  void logCardUse(String cardId) {
    final c = cardById(cardId);
    if (c == null) return;
    mutate(
      () => c.logUse(DateTime.now().millisecondsSinceEpoch),
      () => flash('Logged — enjoy the discount!'),
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
    ExpenseItem? hit;
    mutate(() {
      final arr = data[year]?[kMonthKeys[monthIdx]]?.blocks[catKey];
      final it = arr?.where((x) => x.id == itemId).firstOrNull;
      if (it == null) return;
      it
        ..paid = true
        ..cardId = cardId
        ..generated = false;
      cardById(cardId)?.logUse(DateTime.now().millisecondsSinceEpoch);
      hit = it;
    }, () => flash("Marked '${_itemTitle(hit)}' paid"));
    if (hit != null) {
      logAnalyticsEvent('expense_paid_with_card', {
        'card': cardId,
        'amount': hit!.amount,
      });
    }
  }
}

String _itemTitle(ExpenseItem? it) {
  if (it == null) return 'item';
  final t = it.payee.trim().isNotEmpty ? it.payee.trim() : it.label.trim();
  return t.isEmpty ? 'item' : t;
}

/// "Last used today/yesterday/N days ago/date" label for wallet rows and
/// card-face stats (issue #233).
String cardLastUsedLabel(int? millis, DateTime now) {
  if (millis == null) return 'Never used';
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final days = today.difference(that).inDays;
  if (days <= 0) return 'Used today';
  if (days == 1) return 'Used yesterday';
  if (days < 30) return 'Used $days days ago';
  return 'Used ${that.day}/${that.month}/${that.year}';
}

/// Picks the symbology the card face renders with: QR for QR cards, EAN-13
/// when the number is a valid EAN-13, Code 128 otherwise (every till scanner
/// reads it and it accepts any length).
bw.Barcode cardBarcodeFor(DiscountCard c) {
  if (c.codeType == 'qr') return bw.Barcode.qrCode();
  if (isValidEan13(c.number)) return bw.Barcode.ean13();
  return bw.Barcode.code128();
}

// ============================================================ wallet list

class _WalletScreen extends StatefulWidget {
  const _WalletScreen({required this.state});
  final _ThriveHomeState state;

  @override
  State<_WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<_WalletScreen> {
  _ThriveHomeState get s => widget.state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: B.page,
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: s._rev,
          builder: (context, _, _) {
            final cards = s.cards;
            return Column(
              children: [
                _walletHeader(context, cards.length),
                Expanded(
                  child: cards.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                          itemCount: cards.length,
                          itemBuilder: (_, i) => _cardRow(cards[i]),
                        ),
                ),
                _addBar(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _walletHeader(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('wallet-back'),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: B.line),
              ),
              child: Center(
                child: ic('cleft', size: 17, sw: 2.4, color: B.soft2),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Discount cards',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3,
                    color: B.ink,
                  ),
                ),
                Text(
                  count == 0
                      ? 'The family wallet'
                      : '$count card${count == 1 ? '' : 's'} in the family '
                            'wallet',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: B.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ic('card', size: 34, sw: 1.8, color: B.muted),
          const SizedBox(height: 10),
          const Text(
            'No cards yet',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: B.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Photograph a loyalty card and the whole family can use it at '
              'the till.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: B.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardRow(DiscountCard c) {
    final inner = GestureDetector(
      key: ValueKey('wallet-card-${c.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => s.openCardFace(c.id),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _cardChip(c),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (c.maskedNumber.isNotEmpty) c.maskedNumber,
                      cardLastUsedLabel(c.lastUsedMillis, DateTime.now()),
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: B.muted,
                    ),
                  ),
                ],
              ),
            ),
            ic('cright', size: 16, sw: 2.2, color: B.muted),
          ],
        ),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: B.line),
        boxShadow: cardShadow(),
      ),
      child: _SwipeRow(
        key: ValueKey('wallet-swipe-${c.id}'),
        open: s.swipedId == 'card-${c.id}',
        onOpenChanged: (open) =>
            setState(() => s.swipedId = open ? 'card-${c.id}' : null),
        onDelete: () => s.confirmDeleteCard(c),
        borderRadius: 14,
        child: inner,
      ),
    );
  }

  Widget _cardChip(DiscountCard c) {
    final photo = c.photo;
    return Container(
      width: 46,
      height: 32,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: photo != null
          ? Image.memory(
              base64Decode(photo),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          : Center(
              child: Text(
                initialsOf(c.name),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: contrastOn(c.color),
                ),
              ),
            ),
    );
  }

  Widget _addBar(BuildContext context) {
    Widget btn(Key key, String icon, String label, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          key: key,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: B.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ic(icon, size: 16, sw: 2.3, color: Colors.white),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Row(
        children: [
          btn(
            const ValueKey('wallet-scan'),
            'camera',
            'Scan a card',
            () => s.startCardImport(ImageSource.camera),
          ),
          const SizedBox(width: 10),
          btn(
            const ValueKey('wallet-import'),
            'plus',
            'From photos',
            () => s.startCardImport(ImageSource.gallery),
          ),
        ],
      ),
    );
  }
}

// ============================================================== card face

class _CardFaceScreen extends StatefulWidget {
  const _CardFaceScreen({
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
  State<_CardFaceScreen> createState() => _CardFaceScreenState();
}

class _CardFaceScreenState extends State<_CardFaceScreen> {
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) {
        final c = s.cardById(widget.cardId);
        if (c == null) {
          // Deleted by another family member while open.
          return Scaffold(
            backgroundColor: B.page,
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('This card is gone — go back'),
              ),
            ),
          );
        }
        final fg = contrastOn(c.color);
        return Scaffold(
          backgroundColor: c.color,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: Row(
                    children: [
                      GestureDetector(
                        key: const ValueKey('cardface-close'),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: fg.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: ic('x', size: 17, sw: 2.4, color: fg),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.3,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
                    child: Column(
                      children: [
                        _plate(c),
                        const SizedBox(height: 12),
                        Text(
                          'Hold the screen at the scanner',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: fg.withValues(alpha: .85),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _stats(c, fg),
                        if (c.note.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            c.note,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: fg.withValues(alpha: .8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: _actions(context, c, fg),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// White plate with the rendered, till-legible barcode/QR + digits.
  Widget _plate(DiscountCard c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: cardShadow(),
      ),
      child: Column(
        children: [
          if (c.number.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
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
              height: c.codeType == 'qr' ? 190 : 96,
              width: c.codeType == 'qr' ? 190 : double.infinity,
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
            const SizedBox(height: 10),
            Text(
              c.number,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: B.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stats(DiscountCard c, Color fg) {
    Widget cell(String value, String label) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: fg.withValues(alpha: .75),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          cell('${c.timesUsed}', 'times used'),
          cell(
            cardLastUsedLabel(
              c.lastUsedMillis,
              DateTime.now(),
            ).replaceFirst('Used ', ''),
            'last used',
          ),
          cell(s.cardOwnerName(c), 'whose card'),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, DiscountCard c, Color fg) {
    final payItem = _payItem;
    Widget solid(Key key, String label, VoidCallback onTap) {
      return GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: B.ink,
            ),
          ),
        ),
      );
    }

    if (payItem != null && !payItem.paid) {
      // "Paying" mode (issue #231), reached from an item's card tag.
      return solid(
        const ValueKey('cardface-paywith'),
        "Mark '${_itemTitle(payItem)}' paid",
        () {
          s.payItemWithCard(widget.payCat!, payItem.id, c.id);
          Navigator.of(context).pop();
        },
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        solid(
          const ValueKey('cardface-scanned'),
          'Scanned at the till',
          () => s.logCardUse(c.id),
        ),
        const SizedBox(height: 9),
        GestureDetector(
          key: const ValueKey('cardface-paysomething'),
          onTap: () => s.openPayWithCardSheet(c.id),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              border: Border.all(color: fg.withValues(alpha: .5)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Pay something with it',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
