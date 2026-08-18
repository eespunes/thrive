part of 'package:family_money_management_app/main.dart';

const List<String> _kWeekdaysFull = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The Home dashboard (#158): today & upcoming, tasks due soon, a shopping
/// glance, tonight's dinner and the projected balance. Ported from the
/// design's `renderHome()` / `homeCard()` / `glanceCard()` / `miniTaskRow()`.
///
/// Today & upcoming events, tasks, shopping, today's dinner (#157) and
/// projected balance are all real.
extension _ThriveHomeScreen on _ThriveHomeState {
  String firstName() {
    final name = user?.name.trim() ?? '';
    if (name.isEmpty) return 'there';
    final first = name.split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'there' : first;
  }

  String prettyToday() {
    final now = DateTime.now();
    return '${_kWeekdaysFull[now.weekday - 1]}, ${now.day} ${kMonthsEn[now.month - 1]}';
  }

  Widget _buildHomeDashboard() {
    final openTasks = <(TaskList, ListTask)>[];
    for (final l in taskLists) {
      for (final t in l.tasks) {
        if (!t.done) openTasks.add((l, t));
      }
    }
    final topDue = openTasks.take(4).toList();
    final c = compute(monthIdx);
    final todayEv = eventOccurrences(todayIso(), _addDaysIso(todayIso(), 6))
      ..sort(
        (a, b) => (a.date + (a.ev.allDay ? '' : a.ev.start)).compareTo(
          b.date + (b.ev.allDay ? '' : b.ev.start),
        ),
      );
    final topEvents = todayEv.take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        _homeCard(
          title: 'Today & upcoming',
          icon: 'cal',
          onOpen: () => goTab('calendar'),
          body: topEvents.isEmpty
              ? _emptyRow('Nothing scheduled — enjoy the calm.')
              : Column(
                  children: [
                    for (var i = 0; i < topEvents.length; i++)
                      _miniEventRow(topEvents[i], border: i > 0),
                  ],
                ),
        ),
        _homeCard(
          title: 'Open tasks',
          icon: 'tasklist',
          onOpen: () => goTab('lists'),
          body: topDue.isEmpty
              ? _emptyRow('All caught up. Nice work!')
              : Column(
                  children: [
                    for (var i = 0; i < topDue.length; i++)
                      _miniTaskRow(topDue[i].$1, topDue[i].$2, border: i > 0),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _glanceCard(
                    title: 'Shopping',
                    icon: 'cart',
                    onOpen: () => goTab('lists'),
                    body: shoppingLists.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'No lists yet',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: B.muted,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final l in shoppingLists.take(2))
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: B.text,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: B.soft,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${l.items.where((i) => !i.checked).length}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: B.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _glanceCard(
                    title: "Today's dinner",
                    icon: 'moon',
                    onOpen: () => goTab('weekly'),
                    body: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        dayPlan(todayIso())?.dinner ?? 'Not planned',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: B.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: () => goTab('finance'),
          child: Container(
            margin: const EdgeInsets.only(top: 12),
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
            child: Row(
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
                      const SizedBox(height: 2),
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
          ),
        ),
      ],
    );
  }

  Widget _homeCard({
    required String title,
    required String icon,
    required VoidCallback onOpen,
    required Widget body,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
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
                      child: ic(icon, size: 16, sw: 2.1, color: B.primary),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: B.ink,
                      ),
                    ),
                  ),
                  ic('cright', size: 17, sw: 2.2, color: B.muted),
                ],
              ),
            ),
          ),
          body,
        ],
      ),
    );
  }

  Widget _glanceCard({
    required String title,
    required String icon,
    required VoidCallback onOpen,
    required Widget body,
  }) {
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: B.line),
          borderRadius: BorderRadius.circular(18),
          boxShadow: cardShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: B.soft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: ic(icon, size: 14, sw: 2.1, color: B.primary),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: B.soft2,
                  ),
                ),
              ],
            ),
            body,
          ],
        ),
      ),
    );
  }

  Widget _emptyRow(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: B.muted,
      ),
    ),
  );

  Widget _miniEventRow(CalendarOccurrence o, {required bool border}) {
    final ev = o.ev;
    final category = catById(ev.category);
    final color = evColor(ev);
    final today = todayIso();
    final timing = o.isMultiDay
        ? '${o.date == today ? 'Today' : _shortDateIso(o.date)} – '
              '${_shortDateIso(o.spanEnd)}'
        : '${o.date == today ? 'Today' : _shortDateIso(o.date)} · '
              '${ev.allDay ? 'All day' : ev.start}';
    return GestureDetector(
      key: ValueKey('home-event-${ev.id}-${o.date}'),
      onTap: () => openEventView(ev.id, o.date),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          border: border ? const Border(top: BorderSide(color: B.faint)) : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              key: ValueKey('home-event-accent-${ev.id}'),
              width: 4,
              constraints: const BoxConstraints(minHeight: 34),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (category != null) ...[
                        Container(
                          key: ValueKey('home-event-visual-${ev.id}'),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: categoryGlyph(
                            category,
                            size: 18,
                            iconColor: contrastOn(color),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          ev.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: B.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      ic(
                        o.isMultiDay ? 'cal' : 'clock',
                        size: 12,
                        sw: 2.2,
                        color: B.muted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          timing,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: B.soft2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _attendeeStack(ev.attendees, 22),
          ],
        ),
      ),
    );
  }

  Widget _miniTaskRow(TaskList list, ListTask t, {required bool border}) {
    return Container(
      decoration: BoxDecoration(
        border: border ? const Border(top: BorderSide(color: B.faint)) : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => toggleTask(list.id, t.id),
            child: Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                color: t.done ? B.primary : Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: t.done ? B.primary : const Color(0xffcdd5df),
                  width: 2,
                ),
              ),
              child: t.done
                  ? Center(
                      child: ic('check', size: 13, sw: 3, color: Colors.white),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                goTab('lists');
                openTaskListDetail(list.id);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: B.ink,
                    ),
                  ),
                  Text(
                    list.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: B.soft2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _memberAvatar(t.assignee, size: 24),
        ],
      ),
    );
  }
}
