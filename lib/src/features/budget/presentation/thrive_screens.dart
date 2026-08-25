part of 'package:family_money_management_app/main.dart';

/// All three screen bodies + their row/card widgets, ported from the design's
/// renderOverview / renderStats / renderSettings.
extension _ThriveScreens on _ThriveHomeState {
  // ============================================================ OVERVIEW
  Widget _buildOverview() {
    final c = compute(monthIdx);
    final locked = c.closed;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => update(() => swipedId = null),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
        children: [
          if (locked) _closedBanner(),
          _sumUpCard(c),
          const SizedBox(height: 12),
          // Income blocks first (issue #137 — income is just an income-direction
          // block), then the withdrawing blocks.
          for (final b in c.incomeBlocks) ...[
            _expenseBlock(b, locked),
            const SizedBox(height: 12),
          ],
          for (final b in c.expenseBlocks) ...[
            _expenseBlock(b, locked),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _closedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: B.ink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: ic('lock', size: 16, sw: 2.2, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Month closed',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Locked — read only. Deleting a block elsewhere won\u2019t change this month.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xccffffff),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: reopenMonth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ic('unlock', size: 14, sw: 2.4, color: B.ink),
                  const SizedBox(width: 6),
                  const Text(
                    'Reopen',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sumUpCard(_Compute c) {
    final good = c.balance >= 0 && c.stillToPay == 0;
    final mid = c.balance >= 0;
    final hColor = good ? B.green : (mid ? B.amber : B.red);
    final hBg = good ? B.greenSoft : (mid ? B.amberSoft : B.redSoft);
    final hLabel = good ? 'On track' : (mid ? 'Watch spending' : 'Over budget');
    final paidPct = c.totalBudget > 0
        ? (c.totalPaid / c.totalBudget * 100).round()
        : 100;

    Widget tile(String label, String val, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: B.faint,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
                color: B.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              val,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );

    final maxAcct = math.max(
      1.0,
      c.accounts.fold<double>(
        0,
        (p, a) => math.max(p, c.acctTotals[a.key] ?? 0),
      ),
    );
    final accts = c.accounts.map((a) {
      final amt = c.acctTotals[a.key] ?? 0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: a.color,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: glyphTile(
                size: 28,
                radius: 9,
                picture: a.picture,
                emoji: a.emoji,
                emojiSize: 15,
                fallback: Text(
                  a.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: B.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        eur(amt),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: amt > 0 ? B.ink : B.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _bar(amt / maxAcct, a.color, height: 6),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: B.line),
        boxShadow: cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: B.soft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: ic('gauge', size: 16, sw: 2.2, color: B.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sum Up',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: hBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ic('shield', size: 12, sw: 2.4, color: hColor),
                    const SizedBox(width: 5),
                    Text(
                      hLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: hColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              gradient: B.grad,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff0E9A8D).withValues(alpha: .7),
                  blurRadius: 26,
                  spreadRadius: -12,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'EXPECTED BALANCE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                    color: Colors.white.withValues(alpha: .9),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  eur(c.expectedBalance),
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.6,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              tile('Income', '+${eur(c.realIncome, cents: false)}', B.green),
              const SizedBox(width: 8),
              tile(
                'Expenses',
                '\u2212${eur(c.totalBudget, cents: false)}',
                B.red,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: c.stillToPay > 0 ? B.amberSoft : B.greenSoft,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: c.stillToPay > 0 ? B.amberLine : B.greenLine,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      c.stillToPay > 0 ? 'Still to pay' : 'All settled',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: c.stillToPay > 0 ? B.amberText : B.greenText,
                      ),
                    ),
                    Text(
                      eur(c.stillToPay),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.stillToPay > 0 ? B.amberText : B.greenText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _bar(
                  paidPct / 100,
                  c.stillToPay > 0 ? B.amber : B.green,
                  height: 6,
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$paidPct% of ${eur(c.totalBudget, cents: false)} paid',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: B.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'STILL TO PAY FROM',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
              color: B.muted,
            ),
          ),
          ...accts,
        ],
      ),
    );
  }

  Widget _expenseBlock(_BlockCompute b, bool locked) {
    final isCollapsed = collapsed[b.key] ?? false;
    // Income/savings blocks reuse this card; only the verbs differ (issue #137).
    final verbPast = b.isIncome ? 'received' : (b.isSavings ? 'saved' : 'paid');
    final verbLabel = b.isIncome
        ? 'RECEIVED'
        : (b.isSavings ? 'SAVED' : 'PAID');
    final overCap = b.cap != null && b.total > b.cap!;
    final capPct = b.cap != null
        ? math.min(100, (b.total / math.max(1, b.cap!) * 100).round())
        : 0;
    final payPct = b.total > 0
        ? (b.paid / b.total * 100).round()
        : (b.paid > 0 ? 100 : 0);
    Color barColor;
    double barW;
    if (b.cap != null) {
      barColor = overCap
          ? B.red
          : (b.total / b.cap! >= 0.85 ? B.amber : b.tone);
      barW = capPct / 100;
    } else {
      barColor = b.tone;
      barW = payPct / 100;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: overCap ? B.redLine : B.line),
        boxShadow: cardShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => toggleCollapse(b.key),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: b.bg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: glyphTile(
                      size: 36,
                      radius: 11,
                      picture: b.picture,
                      emoji: b.emoji,
                      emojiSize: 19,
                      fallback: Center(
                        child: ic(b.icon, size: 18, sw: 2, color: b.tone),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          b.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: B.ink,
                          ),
                        ),
                        Text(
                          '${b.count} item${b.count == 1 ? '' : 's'}'
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .3,
                            color: B.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        eur(b.total, cents: false),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: overCap ? B.red : B.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        b.cap != null
                            ? 'limit ${eur(b.cap, cents: false)}'
                            : '${eur(b.paid, cents: false)} $verbPast',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: B.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: isCollapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: ic('cdown', size: 18, sw: 2.4, color: B.muted),
                  ),
                ],
              ),
            ),
          ),
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        b.cap != null ? 'BUDGET USED' : verbLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .3,
                          color: B.muted,
                        ),
                      ),
                      // Spending limits only make sense for withdrawing blocks.
                      if (!b.isIncome) _limitChip(b, overCap, locked),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _bar(barW, barColor, height: 6),
                ],
              ),
            ),
          if (!isCollapsed)
            for (final r in b.items) _expenseRow(b, r, locked),
          if (!isCollapsed && !locked)
            _addButton(
              'Add to ${b.title}',
              b.tone,
              () => openExpenseSheet(mode: 'add', cat: b.key),
            ),
        ],
      ),
    );
  }

  Widget _limitChip(_BlockCompute b, bool overCap, bool locked) {
    final hasCap = b.cap != null;
    return GestureDetector(
      onTap: locked ? null : () => openCapSheet(b.key, b.cap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: hasCap ? (overCap ? B.redSoft : B.faint) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: hasCap ? Colors.transparent : const Color(0xffcfd6e0),
            style: hasCap ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ic(
              hasCap ? 'edit' : 'plus',
              size: 12,
              sw: 2.4,
              color: hasCap ? (overCap ? B.red : B.soft2) : B.primary,
            ),
            const SizedBox(width: 5),
            Text(
              hasCap
                  ? (overCap
                        ? 'Over by ${eur(b.total - b.cap!, cents: false)}'
                        : '${eur(b.total, cents: false)} / ${eur(b.cap, cents: false)}')
                  : 'Set limit',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: hasCap ? (overCap ? B.red : B.soft2) : B.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expenseRow(_BlockCompute b, _RowCompute r, bool locked) {
    final it = r.item;
    final acc = accByKey(it.account);
    final payee = it.payee.trim();
    final subcategory = it.label.trim();
    final title = payee.isNotEmpty ? payee : subcategory;
    final showSubcategory = payee.isNotEmpty && subcategory.isNotEmpty;
    final uStyle = <UntilState, List<Color>>{
      UntilState.soon: [B.orangeSoft, B.orangeText, const Color(0xfffed7aa)],
      UntilState.future: [B.soft, B.deep, const Color(0xffc5e8e2)],
      UntilState.ended: [
        const Color(0xfff1f5f9),
        const Color(0xff94a3b8),
        const Color(0xffe2e8f0),
      ],
    };
    final inner = GestureDetector(
      onTap: locked
          ? null
          : () => openExpenseSheet(mode: 'edit', cat: b.key, id: it.id),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      text: title,
                      children: [
                        if (showSubcategory)
                          TextSpan(
                            text: ' - $subcategory',
                            style: const TextStyle(
                              color: B.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: B.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _accountPill(
                        acc,
                        onTap: locked
                            ? null
                            : () => openAccountPicker(
                                b.isIncome ? 'income' : 'expense',
                                it.id,
                                it.account,
                                b.key,
                              ),
                      ),
                      if (markerShow(it.marker).isNotEmpty)
                        Text(
                          markerShow(it.marker),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: B.muted,
                          ),
                        ),
                      if (cardById(it.cardId) case final DiscountCard card)
                        GestureDetector(
                          key: ValueKey('card-tag-${it.id}'),
                          onTap: () => openCardFace(
                            card.id,
                            payCat: b.key,
                            payItemId: it.id,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: B.line),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: card.color,
                                    borderRadius: BorderRadius.circular(2.5),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  card.name,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: B.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (r.untilLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: uStyle[r.untilState]![0],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: uStyle[r.untilState]![2]),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ic(
                                'clock',
                                size: 10,
                                sw: 2.4,
                                color: uStyle[r.untilState]![1],
                              ),
                              const SizedBox(width: 3),
                              Text(
                                r.untilLabel!,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: uStyle[r.untilState]![1],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              eur(it.amount),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: B.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            _statusPill(
              it.paid,
              b.isIncome
                  ? (it.paid ? 'In' : 'Pending')
                  : b.isSavings
                  ? (it.paid ? 'Saved' : 'Save')
                  : (it.paid ? 'Paid' : 'Open'),
              onTap: locked ? null : () => togglePaid(b.key, it.id),
            ),
          ],
        ),
      ),
    );
    if (locked) {
      return Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: B.faint)),
        ),
        child: inner,
      );
    }
    return _SwipeRow(
      key: ValueKey('exp-${b.key}-${it.id}'),
      open: swipedId == it.id,
      onOpenChanged: (open) => update(() => swipedId = open ? it.id : null),
      onDelete: () => askDelete(
        it.label,
        it.recurring
            ? 'This recurring item will be removed from ${b.title} this month and all future open months.'
            : 'This item will be removed from ${b.title} this month.',
        () => deleteExpense(b.key, it.id),
      ),
      topBorder: true,
      child: inner,
    );
  }

  // -------------------------------------------------------- shared bits
  Widget _addButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: B.faint)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ic('plus', size: 15, sw: 2.5, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountPill(Account acc, {VoidCallback? onTap}) {
    final pill = Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 8, 2),
      decoration: BoxDecoration(
        color: B.faint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: acc.color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: glyphTile(
              size: 16,
              radius: 8,
              picture: acc.picture,
              emoji: acc.emoji,
              emojiSize: 10,
              fallback: Text(
                acc.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            acc.short,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: B.soft2,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return GestureDetector(onTap: onTap, child: pill);
  }

  Widget _statusPill(bool on, String label, {VoidCallback? onTap}) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: on ? B.greenSoft : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: on ? B.greenLine : const Color(0xffe5e7eb)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (on) ...[
            ic('check', size: 12, sw: 2.8, color: B.greenText),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: on ? B.greenText : B.muted,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return GestureDetector(onTap: onTap, child: pill);
  }

  Widget _bar(
    double frac,
    Color color, {
    double height = 6,
    Color track = B.track,
  }) {
    final f = frac.isNaN ? 0.0 : frac.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: double.infinity,
        height: height,
        color: track,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: f,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================ SETTINGS
  /// [embed] drops the tab body's own side padding for when this is reused
  /// inside a bottom sheet (which already has its own horizontal inset).
  Widget _buildSettings({bool embed = false}) {
    Widget card(String title, String iconName, Widget child, [Widget? action]) {
      return Container(
        margin: const EdgeInsets.only(bottom: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: B.line),
          boxShadow: cardShadow(),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: B.soft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: ic(iconName, size: 16, sw: 2.2, color: B.primary),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  ?action,
                ],
              ),
            ),
            child,
          ],
        ),
      );
    }

    // accounts
    final accRows = <Widget>[];
    for (int idx = 0; idx < accounts.length; idx++) {
      final a = accounts[idx];
      final inner = GestureDetector(
        key: ValueKey('acc-edit-${a.key}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => openAccountSheet(mode: 'edit', key: a.key),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: B.faint)),
          ),
          child: Row(
            children: [
              _reorder(
                idx,
                accounts.length,
                (d) => moveAccount(a.key, d),
                keyPrefix: 'acc-move-${a.key}',
              ),
              const SizedBox(width: 9),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: a.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: glyphTile(
                  size: 32,
                  radius: 10,
                  picture: a.picture,
                  emoji: a.emoji,
                  emojiSize: 17,
                  fallback: Text(
                    a.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      a.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: B.ink,
                      ),
                    ),
                    Text(
                      'Short \u00b7 ${a.short}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: B.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      accRows.add(
        accounts.length > 1
            ? _SwipeRow(
                key: ValueKey('acc-${a.key}'),
                open: swipedId == 'acc-${a.key}',
                onOpenChanged: (open) =>
                    update(() => swipedId = open ? 'acc-${a.key}' : null),
                onDelete: () => deleteAccount(a.key),
                child: inner,
              )
            : inner,
      );
    }
    accRows.add(
      _addButton('Add account', B.primary, () => openAccountSheet(mode: 'add')),
    );

    // blocks
    final blockRows = <Widget>[];
    for (int idx = 0; idx < cats.length; idx++) {
      final c = cats[idx];
      final inner = GestureDetector(
        key: ValueKey('blk-edit-${c.key}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => openBlockSheet(mode: 'edit', key: c.key),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: B.faint)),
          ),
          child: Row(
            children: [
              _reorder(
                idx,
                cats.length,
                (d) => moveBlock(c.key, d),
                keyPrefix: 'blk-move-${c.key}',
              ),
              const SizedBox(width: 9),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: glyphTile(
                  size: 32,
                  radius: 10,
                  picture: c.picture,
                  emoji: c.emoji,
                  emojiSize: 17,
                  fallback: Center(
                    child: ic(c.icon, size: 16, sw: 2, color: c.tone),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: B.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (c.temporary)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: B.amberSoft,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${kMonthsShort[c.ownerMonthIdx ?? 0]} ${c.ownerYear ?? ''} only',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: B.amberText,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: B.faint,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'Every month',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: B.soft2,
                              ),
                            ),
                          ),
                        if (c.hasUntil) ...[
                          const SizedBox(width: 6),
                          const Text(
                            '\u00b7 end dates',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: B.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      blockRows.add(
        cats.length > 1
            ? _SwipeRow(
                key: ValueKey('blk-${c.key}'),
                open: swipedId == 'blk-${c.key}',
                onOpenChanged: (open) =>
                    update(() => swipedId = open ? 'blk-${c.key}' : null),
                onDelete: () => deleteBlock(c.key),
                child: inner,
              )
            : inner,
      );
    }
    blockRows.add(
      _addButton(
        'Add budget block',
        B.primary,
        () => openBlockSheet(mode: 'add'),
      ),
    );

    final deleteAccountBtn = GestureDetector(
      key: const ValueKey('settings-delete-account'),
      onTap: () => askDelete(
        'your account',
        'This permanently deletes your account. Any family where you are the '
            'only member is deleted too; families with others stay.',
        () => unawaited(deleteUserAccount()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: B.line),
        ),
        child: const Text(
          'Delete account',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: B.red,
          ),
        ),
      ),
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(embed ? 0 : 14, 4, embed ? 0 : 14, 28),
      children: [
        card('Accounts', 'users', Column(children: accRows)),
        card('Budget blocks', 'grid', Column(children: blockRows)),
        deleteAccountBtn,
        const SizedBox(height: 14),
        Text(
          'Thrive \u00b7 Family budget \u00b7 $year',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: B.muted,
          ),
        ),
      ],
    );
  }

  Widget _reorder(
    int idx,
    int len,
    void Function(int dir) onMove, {
    String? keyPrefix,
  }) {
    Widget btn(int dir, bool disabled) => GestureDetector(
      key: keyPrefix == null
          ? null
          : ValueKey('$keyPrefix-${dir < 0 ? 'up' : 'down'}'),
      onTap: disabled ? null : () => onMove(dir),
      child: SizedBox(
        width: 20,
        height: 15,
        child: Center(
          child: ic(
            dir < 0 ? 'cup' : 'cdown',
            size: 14,
            sw: 2.6,
            color: disabled ? const Color(0xffd2d8e1) : B.soft2,
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [btn(-1, idx == 0), btn(1, idx == len - 1)],
    );
  }
}
