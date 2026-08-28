part of 'package:family_money_management_app/main.dart';

/// The Home-board widget catalogue implementations (issues #241–#243),
/// mirroring `Home & nav options.dc.html` (option 1a, Turn 2 catalogue):
/// every widget deep-links to the matching screen with the right filter,
/// small controls act in place (issue #244), and widgets with no data show
/// a helpful line, never a hollow card.
extension _ThriveHomeBoardWidgets on _ThriveHomeState {
  bool _homeWidgetHasOptions(String widgetId) => const {
    'budget_blocks',
    'today',
    'tasks',
    'shopping',
    'quick_actions',
    'family_note',
    'divider',
  }.contains(widgetId);

  Widget buildHomeWidget(BoardEntry e, int index) {
    switch (e.widgetId) {
      case 'balance':
        return _wBalance(e);
      case 'still_to_pay':
        return _wStillToPay();
      case 'next_bills':
        return _wNextBills(e);
      case 'budget_blocks':
        return _wBudgetBlocks(e);
      case 'cards_wallet':
        return _wCardsWallet();
      case 'income':
        return _wIncome();
      case 'savings':
        return _wSavings();
      case 'month_status':
        return _wMonthStatus();
      case 'pocket_money':
        return _wPocketMoney();
      case 'today':
        return _wToday(e);
      case 'week_strip':
        return _wWeekStrip();
      case 'family_day':
        return _wFamilyDay();
      case 'next_up':
        return _wNextUp();
      case 'birthdays':
        return _wBirthdays();
      case 'imported_cals':
        return _wImportedCals(e, index);
      case 'tasks':
        return _wTasks(e);
      case 'shopping':
        return _wShopping(e, index);
      case 'meals':
        return _wMeals(e);
      case 'chores':
        return _wChores();
      case 'quick_actions':
        return _wQuickActions(e);
      case 'family_note':
        return _wFamilyNote(e, index);
      case 'divider':
        return _wDivider(e);
    }
    return const SizedBox.shrink();
  }

  // ------------------------------------------------------ shared visuals

  /// The design's white widget card: 18px radius, hairline border.
  Widget _bCard({
    required Widget child,
    VoidCallback? onTap,
    Color? bg,
    Color? border,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
        decoration: BoxDecoration(
          color: bg ?? Colors.white,
          border: Border.all(color: border ?? B.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      ),
    );
  }

  /// Uppercase muted caption header ("NEXT BILLS", "MEALS · …").
  Widget _bLabel(String text, {Widget? trailing, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
                color: color ?? B.muted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  /// Icon-tile header ("Today & upcoming", "Tasks due soon").
  Widget _bIconTitle(String icon, String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: B.soft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(child: ic(icon, size: 15, sw: 2.1, color: B.primary)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: B.ink,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _bDivider() => const Divider(color: B.faint, height: 1, thickness: 1);

  Widget _wEmptyLine(String text, String action, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: B.muted,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onTap,
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: B.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- Money

  /// Design: gradient card, "PROJECTED BALANCE · JUNE", big amount, then
  /// "Expected … · … still to pay". L adds an income/planned/paid row.
  Widget _wBalance(BoardEntry e) {
    final c = compute(monthIdx);
    return GestureDetector(
      onTap: () => goTab('finance'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: B.grad,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: B.primary.withValues(alpha: .45),
              blurRadius: 30,
              spreadRadius: -16,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROJECTED BALANCE · ${kMonthsEn[monthIdx].toUpperCase()}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
                color: Colors.white.withValues(alpha: .9),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              eur(c.balance),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -.6,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Expected ${eur(c.expectedBalance)} · ${eur(c.stillToPay)} still to pay',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: .9),
              ),
            ),
            if (e.size == 'l') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (label, value) in [
                    ('Income', eur(c.realIncome)),
                    ('Planned', eur(c.totalBudget)),
                    ('Paid', eur(c.totalPaid)),
                  ])
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: .8),
                            ),
                          ),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Design: amber "Still to pay" + total, amber progress bar, then one row
  /// per account with its square initials chip.
  Widget _wStillToPay() {
    final c = compute(monthIdx);
    final rows = [
      for (final a in c.accounts)
        if ((c.acctTotals[a.key] ?? 0) > 0) (a, c.acctTotals[a.key]!),
    ];
    final progress = c.totalBudget > 0 ? c.totalPaid / c.totalBudget : 0.0;
    return _bCard(
      onTap: () => goTab('finance'),
      child: rows.isEmpty
          ? _wEmptyLine('All paid up.', 'Open Finance', () => goTab('finance'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Still to pay',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: B.amberText,
                        ),
                      ),
                    ),
                    Text(
                      eur(c.stillToPay),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: B.amberText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: const Color(0xfffef3c7),
                    color: B.amber,
                  ),
                ),
                const SizedBox(height: 11),
                for (final (a, amt) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.5),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: a.color,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Center(
                            child: Text(
                              a.initials,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: contrastOn(a.color),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            a.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: B.text,
                            ),
                          ),
                        ),
                        Text(
                          eur(amt),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: B.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  /// Due-day label for a bill: "Today" (red) / "In Nd" (amber) / "12 Jul".
  (String, Color) _billDue(ExpenseItem it) {
    final day = int.tryParse(digitsOnly(it.marker));
    if (day == null) return ('—', B.muted);
    final today = DateTime.now().day;
    if (day <= today) return ('Today', B.red);
    if (day - today <= 3) return ('In ${day - today}d', B.amber);
    return (
      '$day ${kMonthsEn[monthIdx].substring(0, 3)}',
      const Color(0xff94a0b0),
    );
  }

  /// Design: "NEXT BILLS" rows — due label · title + account · amount ·
  /// Pay button (first one filled teal), payable in place (#244).
  Widget _wNextBills(BoardEntry e) {
    final locked = isClosed();
    final bills = unpaidItemsThisMonth()
      ..sort(
        (a, b) => (int.tryParse(digitsOnly(a.$2.marker)) ?? 32).compareTo(
          int.tryParse(digitsOnly(b.$2.marker)) ?? 32,
        ),
      );
    final take = e.size == 'l' ? 6 : 3;
    return _bCard(
      onTap: () => goTab('finance'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bLabel('Next bills'),
          if (bills.isEmpty)
            _wEmptyLine('Nothing open.', 'Open Finance', () => goTab('finance'))
          else
            for (final (i, (cat, it)) in bills.take(take).indexed) ...[
              if (i > 0) _bDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        _billDue(it).$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _billDue(it).$2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _itemTitle(it),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: B.ink,
                            ),
                          ),
                          Text(
                            accByKey(it.account).name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: B.soft2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      eur(it.amount),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: B.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      key: ValueKey('home-bill-pay-${it.id}'),
                      onTap: locked ? null : () => togglePaid(cat.key, it.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: locked
                              ? B.faint
                              : (i == 0 ? B.primary : Colors.white),
                          border: i == 0 || locked
                              ? null
                              : Border.all(color: B.line),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Pay',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: locked
                                ? B.muted
                                : (i == 0 ? Colors.white : B.soft2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  /// Design: "BUDGET BLOCKS" rows — name, "€ spent / cap" coloured by how
  /// close to the limit, thin progress bar (green / amber / red).
  Widget _wBudgetBlocks(BoardEntry e) {
    final c = compute(monthIdx);
    final chosen = [
      for (final k in (e.options['blocks'] as List? ?? const [])) k.toString(),
    ];
    var blocks = c.blocks.where((b) => !b.isIncome).toList();
    blocks = chosen.isNotEmpty
        ? blocks.where((b) => chosen.contains(b.key)).toList()
        : blocks.take(e.size == 'l' ? 6 : 3).toList();
    return _bCard(
      onTap: () => goTab('finance'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bLabel('Budget blocks'),
          if (blocks.isEmpty)
            _wEmptyLine('No blocks yet.', 'Set up', () => goTab('finance'))
          else
            for (final b in blocks)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Builder(
                  builder: (context) {
                    final ratio = b.cap != null && b.cap! > 0
                        ? b.total / b.cap!
                        : null;
                    final tone = ratio == null
                        ? B.green
                        : ratio > 1
                        ? B.red
                        : ratio >= .85
                        ? B.amber
                        : B.green;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                b.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: B.ink,
                                ),
                              ),
                            ),
                            Text(
                              b.cap != null
                                  ? '${eur(b.total)} / ${eur(b.cap!)}'
                                  : eur(b.total),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: tone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value:
                                ratio?.clamp(0.0, 1.0) ??
                                (b.total > 0
                                    ? (b.paid / b.total).clamp(0.0, 1.0)
                                    : 0.0),
                            minHeight: 6,
                            backgroundColor: ratio != null && ratio > 1
                                ? const Color(0xfffee2e2)
                                : B.track,
                            color: tone,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  /// Design (`homeCardsStrip`): "Discount cards" + "All cards" link;
  /// horizontally scrolling 136×76 card tiles (name top, masked tail
  /// bottom) and a dashed camera "Scan card" tile.
  Widget _wCardsWallet() {
    return _bCard(
      onTap: openWalletScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bIconTitle(
            'card',
            'Discount cards',
            trailing: GestureDetector(
              onTap: openWalletScreen,
              child: const Text(
                'All cards',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: B.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (cards.isEmpty)
            _wEmptyLine('No cards yet.', 'Scan one', openCardScan)
          else
            SizedBox(
              height: 76,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final card in cards) ...[
                    GestureDetector(
                      key: ValueKey('home-card-${card.id}'),
                      onTap: () => openCardFace(card.id),
                      child: Container(
                        width: 136,
                        clipBehavior: Clip.antiAlias,
                        padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                        decoration: BoxDecoration(
                          color: card.color,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              card.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                color: contrastOn(card.color),
                              ),
                            ),
                            Text(
                              card.maskedNumber,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .7,
                                color: contrastOn(
                                  card.color,
                                ).withValues(alpha: .9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  GestureDetector(
                    key: const ValueKey('home-card-scan'),
                    onTap: openCardScan,
                    child: Container(
                      width: 104,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xffcfd8e3),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ic('camera', size: 18, sw: 2.2, color: B.primary),
                          const SizedBox(height: 5),
                          const Text(
                            'Scan card',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: B.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Design's small stat tile: muted title top, big value + sub bottom.
  Widget _statTile({
    required String keyName,
    required String title,
    required Widget value,
    required String sub,
    Color subColor = const Color(0xff94a0b0),
    required VoidCallback onOpen,
  }) {
    return _bCard(
      onTap: onOpen,
      child: SizedBox(
        key: ValueKey(keyName),
        height: 76,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: B.soft2,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                value,
                const SizedBox(height: 2),
                Text(
                  sub,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Text _statValue(String text, {Color color = B.ink}) => Text(
    text,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      letterSpacing: -.4,
      color: color,
    ),
  );

  Widget _wIncome() {
    final c = compute(monthIdx);
    return _statTile(
      keyName: 'home-w-income-body',
      title: 'Income in',
      value: _statValue(eur(c.realIncome), color: B.green),
      sub: 'of ${eur(c.expIncome)} expected',
      onOpen: () => goTab('finance'),
    );
  }

  Widget _wSavings() {
    final c = compute(monthIdx);
    return _statTile(
      keyName: 'home-w-savings-body',
      title: 'Savings',
      value: _statValue(eur(c.savings)),
      sub: 'put aside this month',
      subColor: B.green,
      onOpen: () => goTab('finance'),
    );
  }

  /// Design: a status pill ("Over budget" red / "On track" green) plus
  /// "N days to close June".
  Widget _wMonthStatus() {
    final c = compute(monthIdx);
    final closed = isClosed();
    final over = c.totalBudget > c.expIncome && c.expIncome > 0;
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final (label, bg, fg) = closed
        ? ('Closed', B.faint, B.soft2)
        : over
        ? ('Over budget', B.redSoft, B.red)
        : ('On track', B.greenSoft, B.greenText);
    return _statTile(
      keyName: 'home-w-month-body',
      title: 'Month status',
      value: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ),
      sub: closed
          ? kMonthsEn[monthIdx]
          : '${lastDay - now.day} days to close ${kMonthsEn[monthIdx]}',
      onOpen: () => goTab('finance'),
    );
  }

  Widget _wPocketMoney() {
    final mine = _homeCurrentUserMemberIds();
    final stars = (curFamily()?.members ?? const <FamilyMember>[])
        .where((m) => mine.contains(m.id))
        .fold<int>(0, (acc, m) => acc + (starsMap[m.id] ?? 0));
    return _statTile(
      keyName: 'home-w-pocket-body',
      title: 'Pocket money',
      value: _statValue('$stars ⭐'),
      sub: stars == 0 ? 'Earn stars with chores' : 'saved toward a reward',
      onOpen: () => goTab('calendar'),
    );
  }

  // ------------------------------------------------------------ Calendar

  bool _occurrenceIsMine(CalendarOccurrence o) {
    final mine = _homeCurrentUserMemberIds();
    return o.ev.attendees.any(mine.contains);
  }

  /// Today + coming days, soonest first — the "Today & upcoming" source.
  List<CalendarOccurrence> _homeUpcoming() {
    final today = todayIso();
    final horizon = _iso(DateTime.now().add(const Duration(days: 7)));
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    return (eventOccurrences(today, horizon)..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.ev.start.compareTo(b.ev.start);
        }))
        .where(
          (o) =>
              o.date != today || _homeOccurrenceIsNotPast(o, today, nowMinutes),
        )
        .toList();
  }

  String _upcomingWhen(CalendarOccurrence o) {
    final today = todayIso();
    final tomorrow = _iso(DateTime.now().add(const Duration(days: 1)));
    final day = o.date == today
        ? 'Today'
        : o.date == tomorrow
        ? 'Tomorrow'
        : _displayDateIso(o.date);
    return o.ev.allDay || o.ev.start.isEmpty ? day : '$day · ${o.ev.start}';
  }

  /// Design: colour bar rows — title, "Today · 14:30", attendee avatar.
  Widget _wToday(BoardEntry e) {
    final onlyMe = e.options['who'] == 'me';
    var events = _homeUpcoming();
    if (onlyMe) events = events.where(_occurrenceIsMine).toList();
    final take = e.size == 'l' ? 6 : 3;
    final members = curFamily()?.members ?? const <FamilyMember>[];
    return _bCard(
      onTap: () => goTab('calendar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bIconTitle('cal', onlyMe ? 'My day' : 'Today & upcoming'),
          if (events.isEmpty)
            _wEmptyLine(
              'Nothing scheduled.',
              'Plan something',
              () => openEvent(null),
            )
          else
            for (final (i, o) in events.take(take).indexed) ...[
              if (i > 0) _bDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 28,
                      decoration: BoxDecoration(
                        color: evColor(o.ev),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.ev.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: B.ink,
                            ),
                          ),
                          Text(
                            _upcomingWhen(o),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: B.soft2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final m = members
                            .where((m) => o.ev.attendees.contains(m.id))
                            .firstOrNull;
                        if (m == null) return const SizedBox.shrink();
                        return avatarNode(
                          photo: m.photo,
                          emoji: m.emoji,
                          initials: m.initials,
                          color: m.color,
                          size: 22,
                          radius: 11,
                          fs: 8.5,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  /// Design: "THIS WEEK" + date range; 7 rounded day cells whose fill shows
  /// how busy the day is; today is the filled teal cell.
  Widget _wWeekStrip() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return _bCard(
      onTap: () => goTab('calendar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bLabel(
            'This week',
            trailing: Text(
              '${monday.day} – ${sunday.day} ${kMonthsEn[sunday.month - 1].substring(0, 3)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: B.primary,
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final day = monday.add(Duration(days: i));
                      final iso = _iso(day);
                      final count = eventOccurrences(iso, iso).length;
                      final isToday = iso == todayIso();
                      final bg = isToday
                          ? B.primary
                          : count == 0
                          ? B.page
                          : count == 1
                          ? B.soft
                          : const Color(0xffc5e8e2);
                      return GestureDetector(
                        onTap: () {
                          update(() => calSel = iso);
                          goTab('calendar');
                        },
                        child: Column(
                          children: [
                            Text(
                              kWeekdayLetters[i],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isToday ? B.primary : B.muted,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              height: 44,
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isToday
                                      ? Colors.white
                                      : count > 0
                                      ? B.deep
                                      : B.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 9),
            child: Text(
              'Colour = how full the day is',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: B.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Design: "FAMILY DAY" — avatar + a chip per event (time + title in the
  /// event's colour); members with nothing show a muted "Free".
  Widget _wFamilyDay() {
    final members = curFamily()?.members ?? const <FamilyMember>[];
    final todays = _homeTodayEvents();
    return _bCard(
      onTap: () => goTab('calendar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bLabel('Family day'),
          if (members.isEmpty)
            _wEmptyLine('No members yet.', 'Invite', openInviteSheet)
          else
            for (final (i, m) in members.indexed) ...[
              if (i > 0) _bDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    avatarNode(
                      photo: m.photo,
                      emoji: m.emoji,
                      initials: m.initials,
                      color: m.color,
                      size: 26,
                      radius: 13,
                      fs: 9,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final his = todays
                              .where((o) => o.ev.attendees.contains(m.id))
                              .take(2)
                              .toList();
                          if (his.isEmpty) {
                            return const Text(
                              'Free',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: B.muted,
                              ),
                            );
                          }
                          return Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              for (final o in his)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: evColor(o.ev),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    o.ev.allDay || o.ev.start.isEmpty
                                        ? o.ev.title
                                        : '${o.ev.start} ${o.ev.title}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: contrastOn(evColor(o.ev)),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  /// Design: event title + red countdown ("in 4 h 50 m").
  Widget _wNextUp() {
    final next = _homeUpcoming().firstOrNull;
    String sub = 'Enjoy the calm';
    if (next != null) {
      if (next.date == todayIso() && next.ev.start.isNotEmpty) {
        final parts = next.ev.start.split(':');
        final at = DateTime.now().copyWith(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0,
        );
        final d = at.difference(DateTime.now());
        sub = d.inMinutes <= 0
            ? 'now'
            : d.inHours > 0
            ? 'in ${d.inHours} h ${d.inMinutes % 60} m'
            : 'in ${d.inMinutes} m';
      } else {
        sub = _upcomingWhen(next);
      }
    }
    return _statTile(
      keyName: 'home-w-nextup-body',
      title: 'Next up',
      value: Text(
        next?.ev.title ?? 'Nothing planned',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
          color: B.ink,
        ),
      ),
      sub: sub,
      subColor: next != null && next.date == todayIso()
          ? const Color(0xffe11d48)
          : const Color(0xff94a0b0),
      onOpen: () => goTab('calendar'),
    );
  }

  /// Design: "Coming up 🎂" — next yearly-recurring event with its date and
  /// "in N days".
  Widget _wBirthdays() {
    final today = todayIso();
    final horizon = _iso(DateTime.now().add(const Duration(days: 365)));
    final next =
        (eventOccurrences(today, horizon)
              ..sort((a, b) => a.date.compareTo(b.date)))
            .where((o) => o.ev.recur == 'yearly')
            .firstOrNull;
    final days = next == null
        ? 0
        : _parseIso(next.date).difference(DateTime.now()).inDays + 1;
    return _statTile(
      keyName: 'home-w-birthdays-body',
      title: 'Coming up 🎂',
      value: Text(
        next?.ev.title ?? 'None saved',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: B.ink,
        ),
      ),
      sub: next == null
          ? 'Add a yearly event'
          : '${_displayDateIso(next.date)} · in $days days',
      onOpen: () => next == null ? openEvent(null) : goTab('calendar'),
    );
  }

  /// Design: "IMPORTED CALENDARS" + "Manage" — colour dot, feed name,
  /// today's count, and the visibility eye acting in place.
  Widget _wImportedCals(BoardEntry e, int index) {
    final today = todayIso();
    return _bCard(
      onTap: () => openImportedCalendarsScreen(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bLabel(
            'Imported calendars',
            trailing: const Text(
              'Manage',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: B.primary,
              ),
            ),
          ),
          if (importedCalendars.isEmpty)
            _wEmptyLine(
              'No feeds yet.',
              'Import one',
              () => openImportedCalendarsScreen(),
            )
          else
            for (final (i, cal) in importedCalendars.indexed) ...[
              if (i > 0) _bDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cal.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cal.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: B.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${cal.events.where((ev) => ev.date == today).length} today',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: B.soft2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      key: ValueKey('home-feed-eye-${cal.id}'),
                      onTap: () => toggleImportVisible(cal.id),
                      child: ic(
                        cal.visible ? 'eye' : 'eyeoff',
                        size: 16,
                        sw: 2.1,
                        color: cal.visible ? B.primary : B.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  // ----------------------------------------------------------- Home life

  /// Design: icon header + count badge; checkbox rows with "List · due"
  /// subs and assignee avatars — tick straight from Home (#244).
  Widget _wTasks(BoardEntry e) {
    final onlyMine = e.options['onlyMine'] == true;
    final mine = _homeCurrentUserMemberIds();
    final open = <(TaskList, ListTask)>[
      for (final l in taskLists)
        for (final t in l.tasks)
          if (!t.done && (!onlyMine || mine.contains(t.assignee))) (l, t),
    ];
    final take = e.size == 'l' ? 6 : 3;
    return _bCard(
      onTap: () {
        update(() => taskFilter = onlyMine ? 'me' : 'all');
        goTab('lists');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bIconTitle(
            'tasklist',
            onlyMine ? 'My tasks' : 'Tasks due soon',
            trailing: open.isEmpty
                ? null
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: B.soft,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${open.length}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: B.primary,
                      ),
                    ),
                  ),
          ),
          if (open.isEmpty)
            _wEmptyLine('All caught up.', 'Open Lists', () => goTab('lists'))
          else
            for (final (i, entry) in open.take(take).indexed)
              SizedBox(
                height: _kHomeTaskRowHeight,
                child: _miniTaskRow(entry.$1, entry.$2, border: i > 0),
              ),
        ],
      ),
    );
  }

  /// Design: list name + "N left" badge, an "Add an item…" affordance, and
  /// the open items as chips with a "+N" overflow.
  Widget _wShopping(BoardEntry e, int index) {
    final listId = (e.options['listId'] ?? '').toString();
    final list =
        shoppingLists.where((l) => l.id == listId).firstOrNull ??
        shoppingLists.firstOrNull;
    final openItems = list?.items.where((i) => !i.checked).toList() ?? const [];
    void openList() {
      goTab('lists');
      if (list != null) {
        openShopListDetail(list.id);
        shopQuickAddFocus.requestFocus();
      }
    }

    return _bCard(
      onTap: () {
        goTab('lists');
        if (list != null) openShopListDetail(list.id);
      },
      child: list == null
          ? _wEmptyLine('No lists yet.', 'Create one', () => goTab('lists'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bIconTitle(
                  'cart',
                  list.name,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: B.orangeSoft,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${openItems.length} left',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: B.orangeText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  key: ValueKey('home-shop-add-$index'),
                  onTap: openList,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: B.line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ic('plus', size: 14, sw: 2.5, color: B.primary),
                        const SizedBox(width: 9),
                        const Text(
                          'Add an item…',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: B.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (openItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final item in openItems.take(3))
                          GestureDetector(
                            key: ValueKey('home-shop-tick-${item.id}'),
                            onTap: () => toggleShop(list.id, item.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: B.page,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                item.qty > 1
                                    ? '${item.name} ×${item.qty}'
                                    : item.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: B.ink,
                                ),
                              ),
                            ),
                          ),
                        if (openItems.length > 3)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: B.page,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '+${openItems.length - 3}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: B.soft2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  /// Design: "MEALS · NEXT THREE DAYS" — Today/weekday label, the dinner,
  /// and a teal "Plan" action for unplanned days.
  Widget _wMeals(BoardEntry e) {
    final days = e.size == 'l' ? 5 : 3;
    final now = DateTime.now();
    return _bCard(
      onTap: () => goTab('weekly'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bLabel('Meals · next ${days == 3 ? 'three' : 'five'} days'),
          for (var i = 0; i < days; i++) ...[
            if (i > 0) _bDivider(),
            Builder(
              builder: (context) {
                final day = now.add(Duration(days: i));
                final dinner = dayPlan(_iso(day))?.dinner;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          i == 0
                              ? 'Today'
                              : _kWeekdaysFull[day.weekday - 1].substring(0, 3),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: i == 0 ? B.primary : const Color(0xff94a0b0),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          dinner ?? 'Not planned',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: dinner == null
                                ? FontWeight.w700
                                : FontWeight.w800,
                            color: dinner == null
                                ? const Color(0xff94a0b0)
                                : B.ink,
                          ),
                        ),
                      ),
                      if (dinner == null)
                        GestureDetector(
                          onTap: () => goTab('weekly'),
                          child: const Text(
                            'Plan',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: B.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Design: "CHORES & STARS" — avatar, name, progress bar, "N ⭐".
  Widget _wChores() {
    final members = curFamily()?.members ?? const <FamilyMember>[];
    return _bCard(
      onTap: openKitchenDashboard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bLabel('Chores & stars'),
          if (members.isEmpty)
            _wEmptyLine('No members yet.', 'Invite', openInviteSheet)
          else
            for (final (i, m) in members.indexed) ...[
              if (i > 0) _bDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    avatarNode(
                      photo: m.photo,
                      emoji: m.emoji,
                      initials: m.initials,
                      color: m.color,
                      size: 26,
                      radius: 13,
                      fs: 9,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        m.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: B.ink,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: ((starsMap[m.id] ?? 0) / 5).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: B.track,
                          color: m.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Text(
                      '${starsMap[m.id] ?? 0} ⭐',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: B.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  void runHomeQuickAction(String id) {
    switch (id) {
      case 'add_expense':
        goTab('finance');
      case 'scan_card':
        unawaited(startCardImport(ImageSource.camera));
      case 'add_event':
        openEvent(null);
      case 'add_task':
        quickAddTask();
      case 'add_shop':
        quickAddShopItem();
      case 'open_wallet':
        openWalletScreen();
      case 'open_weekly':
        goTab('weekly');
      case 'open_stats':
        goTab('finance');
        go('stats');
      case 'open_flow':
        goTab('finance');
        go('flow');
    }
  }

  /// Design: "QUICK ACTIONS" — a 2-column grid of soft-grey buttons.
  Widget _wQuickActions(BoardEntry e) {
    final chosen = [
      for (final a in (e.options['actions'] as List? ?? kDefaultQuickActions))
        a.toString(),
    ].take(4).toList();
    final defs = [
      for (final id in chosen)
        kHomeQuickActions.where((a) => a.$1 == id).firstOrNull,
    ].whereType<(String, String, String)>().toList();
    return _bCard(
      onTap: openQuickAddSheet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bLabel('Quick actions'),
          GridView.count(
            crossAxisCount: e.size == 's' ? 1 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: e.size == 's' ? 3.6 : 3.4,
            children: [
              for (final (id, label, icon) in defs)
                GestureDetector(
                  key: ValueKey('home-qa-$id'),
                  onTap: () => runHomeQuickAction(id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: B.page,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ic(icon, size: 15, sw: 2.2, color: B.primary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: B.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Design: amber sticky-note card with the note text and an author line.
  Widget _wFamilyNote(BoardEntry e, int index) {
    final text = (e.options['text'] ?? '').toString();
    final by = (e.options['by'] ?? '').toString();
    return _bCard(
      bg: B.amberSoft,
      border: B.amberLine,
      onTap: () => openHomeWidgetOptions(_boardIndexFor(e, index)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bLabel('Family note', color: B.amberText),
          if (text.isEmpty)
            _wEmptyLine(
              'Nothing pinned.',
              'Write a note',
              () => openHomeWidgetOptions(_boardIndexFor(e, index)),
            )
          else ...[
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xff78350f),
                height: 1.5,
              ),
            ),
            if (by.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  '$by · ${cardLastUsedLabel((e.options['at'] as num?)?.toInt(), DateTime.now()).replaceFirst('Used ', '').replaceFirst('Never used', 'just now')}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: B.amberText.withValues(alpha: .75),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Design: dashed rule with a left-aligned uppercase label.
  Widget _wDivider(BoardEntry e) {
    final label = (e.options['label'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.only(top: 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffd8dee7))),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
          color: B.soft2,
        ),
      ),
    );
  }

  /// Options edits act on the STORED board, whose index can differ from the
  /// rendered index on kid boards (non-kid-safe entries are filtered out of
  /// the render, not the stored list).
  int _boardIndexFor(BoardEntry e, int renderedIndex) {
    final stored = homeBoard;
    if (stored == null) return renderedIndex;
    final at = stored.indexOf(e);
    return at >= 0 ? at : renderedIndex;
  }
}
