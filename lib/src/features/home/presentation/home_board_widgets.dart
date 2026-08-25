part of 'package:family_money_management_app/main.dart';

/// The Home-board widget catalogue implementations (issues #241–#243).
/// Every widget deep-links to the matching screen with the right filter;
/// small controls act in place (issue #244); widgets with no data show a
/// helpful line, never a hollow card.
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

  Widget _wBalance(BoardEntry e) {
    final c = compute(monthIdx);
    return GestureDetector(
      onTap: () => goTab('finance'),
      child: Container(
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PROJECTED BALANCE · ${kMonthsEn[monthIdx].toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                          color: Colors.white.withValues(alpha: .85),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        eur(c.balance),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${eur(c.stillToPay)} still to pay',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: .9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: ic('cright', size: 22, sw: 2.4, color: Colors.white),
                  ),
                ),
              ],
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

  Widget _wStillToPay() {
    final c = compute(monthIdx);
    final rows = [
      for (final a in c.accounts)
        if ((c.acctTotals[a.key] ?? 0) > 0) (a, c.acctTotals[a.key]!),
    ];
    return _homeCard(
      title: 'Still to pay',
      icon: 'card',
      onOpen: () => goTab('finance'),
      body: rows.isEmpty
          ? _wEmptyLine('All paid up.', 'Open Finance', () => goTab('finance'))
          : Column(
              children: [
                for (final (a, amt) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        _accountPill(a),
                        const Spacer(),
                        Text(
                          eur(amt),
                          style: const TextStyle(
                            fontSize: 13,
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

  /// Unpaid items of this month by day marker — payable in place (#244).
  Widget _wNextBills(BoardEntry e) {
    final locked = isClosed();
    final bills = unpaidItemsThisMonth()
      ..sort(
        (a, b) => (int.tryParse(digitsOnly(a.$2.marker)) ?? 32).compareTo(
          int.tryParse(digitsOnly(b.$2.marker)) ?? 32,
        ),
      );
    final take = e.size == 'l' ? 6 : 3;
    return _homeCard(
      title: 'Next bills',
      icon: 'clock',
      onOpen: () => goTab('finance'),
      body: bills.isEmpty
          ? _wEmptyLine('Nothing open.', 'Open Finance', () => goTab('finance'))
          : Column(
              children: [
                for (final (cat, it) in bills.take(take))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _itemTitle(it),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: B.ink,
                                ),
                              ),
                              Text(
                                [
                                  cat.title,
                                  if (markerShow(it.marker).isNotEmpty)
                                    markerShow(it.marker),
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: B.muted,
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
                          onTap: locked
                              ? null
                              : () => togglePaid(cat.key, it.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: locked ? B.faint : B.soft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Pay',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: locked ? B.muted : B.deep,
                              ),
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

  Widget _wBudgetBlocks(BoardEntry e) {
    final c = compute(monthIdx);
    final chosen = [
      for (final k in (e.options['blocks'] as List? ?? const [])) k.toString(),
    ];
    var blocks = c.blocks.where((b) => !b.isIncome).toList();
    if (chosen.isNotEmpty) {
      blocks = blocks.where((b) => chosen.contains(b.key)).toList();
    } else {
      blocks = blocks.take(e.size == 'l' ? 6 : 3).toList();
    }
    return _homeCard(
      title: 'Budget blocks',
      icon: 'chart',
      onOpen: () => goTab('finance'),
      body: blocks.isEmpty
          ? _wEmptyLine('No blocks yet.', 'Set up', () => goTab('finance'))
          : Column(
              children: [
                for (final b in blocks)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                b.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
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
                                color: b.cap != null && b.total > b.cap!
                                    ? B.red
                                    : B.soft2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: b.cap != null && b.cap! > 0
                                ? (b.total / b.cap!).clamp(0.0, 1.0)
                                : (b.total > 0 ? b.paid / b.total : 0),
                            minHeight: 5,
                            backgroundColor: B.track,
                            color: b.cap != null && b.total > b.cap!
                                ? B.red
                                : B.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _wCardsWallet() {
    return _homeCard(
      title: 'Discount cards',
      icon: 'card',
      onOpen: openWalletScreen,
      body: cards.isEmpty
          ? _wEmptyLine('No cards yet.', 'Scan one', openWalletScreen)
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final card in cards)
                    GestureDetector(
                      key: ValueKey('home-card-${card.id}'),
                      onTap: () => openCardFace(card.id),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: card.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          card.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: contrastOn(card.color),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _statTile({
    required String keyName,
    required String title,
    required String icon,
    required String value,
    required String sub,
    required VoidCallback onOpen,
  }) {
    return _glanceCard(
      title: title,
      icon: icon,
      onOpen: onOpen,
      body: Padding(
        key: ValueKey(keyName),
        padding: const EdgeInsets.only(top: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: B.ink,
              ),
            ),
            Text(
              sub,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: B.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wIncome() {
    final c = compute(monthIdx);
    return _statTile(
      keyName: 'home-w-income-body',
      title: 'Income',
      icon: 'download',
      value: eur(c.realIncome),
      sub: 'of ${eur(c.expIncome)} expected',
      onOpen: () => goTab('finance'),
    );
  }

  Widget _wSavings() {
    final c = compute(monthIdx);
    return _statTile(
      keyName: 'home-w-savings-body',
      title: 'Savings',
      icon: 'star',
      value: eur(c.savings),
      sub: 'planned this month',
      onOpen: () => goTab('finance'),
    );
  }

  Widget _wMonthStatus() {
    final closed = isClosed();
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return _statTile(
      keyName: 'home-w-month-body',
      title: 'Month status',
      icon: 'cal',
      value: closed ? 'Closed' : 'Open',
      sub: closed
          ? kMonthsEn[monthIdx]
          : '${lastDay - now.day} days to month end',
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
      title: 'My pocket money',
      icon: 'star',
      value: '$stars star${stars == 1 ? '' : 's'}',
      sub: stars == 0 ? 'Earn stars with chores' : 'saved toward a reward',
      onOpen: () => goTab('calendar'),
    );
  }

  // ------------------------------------------------------------ Calendar

  bool _occurrenceIsMine(CalendarOccurrence o) {
    final mine = _homeCurrentUserMemberIds();
    return o.ev.attendees.any(mine.contains);
  }

  Widget _wToday(BoardEntry e) {
    final onlyMe = e.options['who'] == 'me';
    var events = _homeTodayEvents();
    if (onlyMe) events = events.where(_occurrenceIsMine).toList();
    final take = e.size == 'l' ? 6 : 3;
    return _homeCard(
      title: onlyMe ? 'My day' : 'Today & upcoming',
      icon: 'cal',
      onOpen: () => goTab('calendar'),
      body: events.isEmpty
          ? _wEmptyLine(
              'Nothing scheduled.',
              'Plan something',
              () => openEvent(null),
            )
          : Column(
              children: [
                for (final o in events.take(take))
                  SizedBox(
                    height: _kHomeTodayEventRowHeight,
                    child: _apptAgendaRow(o, rowKeyPrefix: 'home-event'),
                  ),
              ],
            ),
    );
  }

  Widget _wWeekStrip() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return _homeCard(
      title: 'This week',
      icon: 'cal',
      onOpen: () => goTab('calendar'),
      body: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final day = monday.add(Duration(days: i));
                  final iso = _iso(day);
                  final count = eventOccurrences(iso, iso).length;
                  final isToday = iso == todayIso();
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
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isToday ? B.primary : B.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isToday ? B.primary : B.faint,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isToday ? Colors.white : B.text,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var d = 0; d < count.clamp(0, 3); d++)
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: const BoxDecoration(
                                  color: B.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _wFamilyDay() {
    final members = curFamily()?.members ?? const <FamilyMember>[];
    final todays = _homeTodayEvents();
    return _homeCard(
      title: 'Family day',
      icon: 'users',
      onOpen: () => goTab('calendar'),
      body: members.isEmpty
          ? _wEmptyLine('No members yet.', 'Invite', openInviteSheet)
          : Column(
              children: [
                for (final m in members)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        avatarNode(
                          photo: m.photo,
                          emoji: m.emoji,
                          initials: m.initials,
                          color: m.color,
                          size: 26,
                          radius: 13,
                          fs: 11,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            m.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: B.ink,
                            ),
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final his = todays
                                .where((o) => o.ev.attendees.contains(m.id))
                                .toList();
                            return Text(
                              his.isEmpty
                                  ? 'Free'
                                  : his.first.ev.title +
                                        (his.length > 1
                                            ? ' +${his.length - 1}'
                                            : ''),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: his.isEmpty ? B.muted : B.deep,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _wNextUp() {
    final today = todayIso();
    final horizon = _iso(DateTime.now().add(const Duration(days: 7)));
    final next =
        (eventOccurrences(today, horizon)..sort((a, b) {
              final byDate = a.date.compareTo(b.date);
              return byDate != 0 ? byDate : a.ev.start.compareTo(b.ev.start);
            }))
            .where(
              (o) =>
                  o.date != today ||
                  _homeOccurrenceIsNotPast(
                    o,
                    today,
                    DateTime.now().hour * 60 + DateTime.now().minute,
                  ),
            )
            .firstOrNull;
    return _statTile(
      keyName: 'home-w-nextup-body',
      title: 'Next up',
      icon: 'clock',
      value: next?.ev.title ?? 'Nothing planned',
      sub: next == null
          ? 'Enjoy the calm'
          : next.date == todayIso()
          ? (next.ev.allDay ? 'Today' : 'Today · ${next.ev.start}')
          : _displayDateIso(next.date),
      onOpen: () => goTab('calendar'),
    );
  }

  Widget _wBirthdays() {
    final today = todayIso();
    final horizon = _iso(DateTime.now().add(const Duration(days: 365)));
    final next =
        (eventOccurrences(today, horizon)
              ..sort((a, b) => a.date.compareTo(b.date)))
            .where((o) => o.ev.recur == 'yearly')
            .firstOrNull;
    return _statTile(
      keyName: 'home-w-birthdays-body',
      title: 'Birthdays',
      icon: 'cake',
      value: next?.ev.title ?? 'None saved',
      sub: next == null ? 'Add a yearly event' : _displayDateIso(next.date),
      onOpen: () => next == null ? openEvent(null) : goTab('calendar'),
    );
  }

  Widget _wImportedCals(BoardEntry e, int index) {
    return _homeCard(
      title: 'Imported calendars',
      icon: 'download',
      onOpen: () => openCalendarManageSheet(mode: _CalManageMode.imports),
      body: importedCalendars.isEmpty
          ? _wEmptyLine(
              'No feeds yet.',
              'Import one',
              () => openCalendarManageSheet(mode: _CalManageMode.imports),
            )
          : Column(
              children: [
                for (final cal in importedCalendars)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
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
            ),
    );
  }

  // ----------------------------------------------------------- Home life

  Widget _wTasks(BoardEntry e) {
    final onlyMine = e.options['onlyMine'] == true;
    final mine = _homeCurrentUserMemberIds();
    final open = <(TaskList, ListTask)>[
      for (final l in taskLists)
        for (final t in l.tasks)
          if (!t.done && (!onlyMine || mine.contains(t.assignee))) (l, t),
    ];
    final take = e.size == 'l' ? 6 : 3;
    return _homeCard(
      title: onlyMine ? 'My tasks' : 'Tasks due soon',
      icon: 'tasklist',
      onOpen: () {
        update(() => taskFilter = onlyMine ? 'me' : 'all');
        goTab('lists');
      },
      body: open.isEmpty
          ? _wEmptyLine('All caught up.', 'Open Lists', () => goTab('lists'))
          : Column(
              children: [
                for (final (i, entry) in open.take(take).indexed)
                  SizedBox(
                    height: _kHomeTaskRowHeight,
                    child: _miniTaskRow(entry.$1, entry.$2, border: i > 0),
                  ),
              ],
            ),
    );
  }

  Widget _wShopping(BoardEntry e, int index) {
    final listId = (e.options['listId'] ?? '').toString();
    final list =
        shoppingLists.where((l) => l.id == listId).firstOrNull ??
        shoppingLists.firstOrNull;
    final openItems = list?.items.where((i) => !i.checked).toList() ?? const [];
    return _homeCard(
      title: list?.name ?? 'Shopping list',
      icon: 'cart',
      onOpen: () {
        goTab('lists');
        if (list != null) openShopListDetail(list.id);
      },
      body: list == null
          ? _wEmptyLine('No lists yet.', 'Create one', () => goTab('lists'))
          : Column(
              children: [
                if (openItems.isEmpty)
                  _wEmptyLine('All bought.', 'Add items', () {
                    goTab('lists');
                    openShopListDetail(list.id);
                    shopQuickAddFocus.requestFocus();
                  })
                else
                  for (final item in openItems.take(4))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          GestureDetector(
                            key: ValueKey('home-shop-tick-${item.id}'),
                            onTap: () => toggleShop(list.id, item.id),
                            child: Container(
                              width: 19,
                              height: 19,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xffcdd5df),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              item.qty > 1
                                  ? '${item.name} ×${item.qty}'
                                  : item.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: B.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    key: ValueKey('home-shop-add-$index'),
                    onTap: () {
                      goTab('lists');
                      openShopListDetail(list.id);
                      shopQuickAddFocus.requestFocus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ic('plus', size: 12, sw: 2.6, color: B.primary),
                          const SizedBox(width: 4),
                          const Text(
                            'Add an item',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: B.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _wMeals(BoardEntry e) {
    final days = e.size == 'l' ? 5 : 3;
    final now = DateTime.now();
    return _homeCard(
      title: 'Meal plan',
      icon: 'moon',
      onOpen: () => goTab('weekly'),
      body: Column(
        children: [
          for (var i = 0; i < days; i++)
            Builder(
              builder: (context) {
                final day = now.add(Duration(days: i));
                final plan = dayPlan(_iso(day));
                final dinner = plan?.dinner;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 74,
                        child: Text(
                          i == 0
                              ? 'Tonight'
                              : i == 1
                              ? 'Tomorrow'
                              : _kWeekdaysFull[day.weekday - 1],
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: B.soft2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          dinner ?? 'Not planned',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: dinner == null ? B.muted : B.ink,
                          ),
                        ),
                      ),
                      if (dinner == null)
                        GestureDetector(
                          onTap: () => goTab('weekly'),
                          child: const Text(
                            'Plan',
                            style: TextStyle(
                              fontSize: 11.5,
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
      ),
    );
  }

  Widget _wChores() {
    final members = curFamily()?.members ?? const <FamilyMember>[];
    return _homeCard(
      title: 'Chores & stars',
      icon: 'star',
      onOpen: openKitchenDashboard,
      body: members.isEmpty
          ? _wEmptyLine('No members yet.', 'Invite', openInviteSheet)
          : Column(
              children: [
                for (final m in members)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        avatarNode(
                          photo: m.photo,
                          emoji: m.emoji,
                          initials: m.initials,
                          color: m.color,
                          size: 24,
                          radius: 12,
                          fs: 10,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            m.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: B.ink,
                            ),
                          ),
                        ),
                        for (var s = 0; s < 5; s++)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: ic(
                              'star',
                              size: 13,
                              sw: 2.2,
                              color: s < (starsMap[m.id] ?? 0)
                                  ? B.amber
                                  : B.line,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  void runHomeQuickAction(String id) {
    switch (id) {
      case 'add_expense':
        goTab('finance');
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

  Widget _wQuickActions(BoardEntry e) {
    final chosen = [
      for (final a in (e.options['actions'] as List? ?? kDefaultQuickActions))
        a.toString(),
    ].take(4).toList();
    final defs = [
      for (final id in chosen)
        kHomeQuickActions.where((a) => a.$1 == id).firstOrNull,
    ].whereType<(String, String, String)>().toList();
    return _glanceCard(
      title: 'Quick actions',
      icon: 'plus',
      onOpen: openQuickAddSheet,
      body: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (id, label, icon) in defs)
              GestureDetector(
                key: ValueKey('home-qa-$id'),
                onTap: () => runHomeQuickAction(id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: B.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ic(icon, size: 13, sw: 2.3, color: B.deep),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: B.deep,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _wFamilyNote(BoardEntry e, int index) {
    final text = (e.options['text'] ?? '').toString();
    return _homeCard(
      title: 'Family note',
      icon: 'note',
      onOpen: () => openHomeWidgetOptions(_boardIndexFor(e, index)),
      body: text.isEmpty
          ? _wEmptyLine(
              'Nothing pinned.',
              'Write a note',
              () => openHomeWidgetOptions(_boardIndexFor(e, index)),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: B.text,
                  height: 1.4,
                ),
              ),
            ),
    );
  }

  Widget _wDivider(BoardEntry e) {
    final label = (e.options['label'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Expanded(child: Divider(color: B.line)),
          if (label.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .4,
                  color: B.muted,
                ),
              ),
            ),
            const Expanded(child: Divider(color: B.line)),
          ],
        ],
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
