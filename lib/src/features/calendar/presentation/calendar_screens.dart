part of 'package:family_money_management_app/main.dart';

/// The Calendar tab (#152): Month/Week/Agenda views over the shared family
/// [_ThriveHomeState.events], ported from the design's `renderCalendar()` /
/// `calMonth()` / `calWeek()` / `calAgenda()` / `eventCard()`.
extension _ThriveCalendarScreens on _ThriveHomeState {
  Widget _buildCalendar() {
    switch (calView) {
      case 'week':
        return _calWeek();
      case 'agenda':
        return _calAgenda();
      default:
        return _calMonth();
    }
  }

  /// The calendar sub-header: view toggle, prev/today/next nav (hidden in
  /// agenda), member filter chips and category filter chips + "Manage".
  Widget _calSubHeader() {
    final toggle = _segRow(
      const [('month', 'Month'), ('week', 'Week'), ('agenda', 'Agenda')],
      calView,
      setCalView,
    );

    final nav = calView == 'agenda'
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                _calNavBtn('cleft', () => calStep(-1)),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('cal-today'),
                    onTap: calToday,
                    child: Container(
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: B.line),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        calView == 'month'
                            ? _monthTitleIso(calAnchor)
                            : _weekRangeIso(_startOfWeekIso(calAnchor)),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: B.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _calNavBtn('cright', () => calStep(1)),
              ],
            ),
          );

    final members = curFamily()?.members ?? const <FamilyMember>[];
    final memberChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          _calFilterChip(
            key: 'cal-filter-all',
            label: 'Everyone',
            active: calFilter == null,
            onTap: () => setCalFilter(null),
          ),
          for (final m in members) ...[
            const SizedBox(width: 7),
            _calFilterChip(
              key: 'cal-filter-${m.id}',
              label: m.name,
              active: calFilter == m.id,
              onTap: () => setCalFilter(m.id),
              avatar: _memberAvatar(m.id, size: 20),
            ),
          ],
        ],
      ),
    );

    final catChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        children: [
          for (final c in eventCategories) ...[
            _calCategoryChip(c),
            const SizedBox(width: 7),
          ],
          GestureDetector(
            key: const ValueKey('cal-manage'),
            onTap: openCalendarManageSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: B.line, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ic('sliders', size: 12, sw: 2.3, color: B.primary),
                  const SizedBox(width: 4),
                  const Text(
                    'Manage',
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
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [toggle, ?nav, memberChips, catChips],
    );
  }

  Widget _calNavBtn(String icon, VoidCallback onTap) {
    return GestureDetector(
      key: ValueKey('cal-nav-$icon'),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: B.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Center(child: ic(icon, size: 17, sw: 2.4, color: B.soft2)),
      ),
    );
  }

  Widget _calFilterChip({
    required String key,
    required String label,
    required bool active,
    required VoidCallback onTap,
    Widget? avatar,
  }) {
    return GestureDetector(
      key: ValueKey(key),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(avatar != null ? 5 : 11, 5, 11, 5),
        decoration: BoxDecoration(
          color: active ? B.soft : Colors.white,
          border: Border.all(color: active ? B.primary : B.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null) ...[avatar, const SizedBox(width: 6)],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? B.deep : B.soft2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calCategoryChip(EventCategory c) {
    final active = calCatFilter == c.id;
    return GestureDetector(
      key: ValueKey('cal-cat-${c.id}'),
      onTap: () => setCalCatFilter(c.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? c.color : Colors.white,
          border: Border.all(color: active ? c.color : B.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            categoryGlyph(
              c,
              size: 14,
              iconColor: active ? Colors.white : c.color,
            ),
            const SizedBox(width: 5),
            Text(
              c.name,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : B.soft2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- month
  Widget _calMonth() {
    final grid = monthGrid(calAnchor);
    final curMonth = _parseIso(calAnchor).month;
    final counts = <String, List<Color>>{};
    for (final o in eventOccurrences(grid.first, grid.last)) {
      final list = counts.putIfAbsent(o.date, () => []);
      if (list.length < 3) list.add(evColor(o.ev));
    }
    final today = todayIso();

    Widget cell(String iso) {
      final d = _parseIso(iso);
      final inMonth = d.month == curMonth;
      final isToday = iso == today;
      final sel = iso == calSel;
      final dots = counts[iso] ?? const <Color>[];
      return GestureDetector(
        key: ValueKey('cal-day-$iso'),
        onTap: () => setCalSel(iso),
        child: Container(
          decoration: BoxDecoration(
            color: sel ? B.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday || sel
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: sel
                      ? Colors.white
                      : (isToday
                            ? B.primary
                            : (inMonth ? B.ink : const Color(0xffc2cad6))),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in dots)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: sel ? Colors.white : c,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dayEvents = eventOccurrences(calSel, calSel)
      ..sort(
        (a, b) => (a.ev.allDay ? '' : a.ev.start).compareTo(
          b.ev.allDay ? '' : b.ev.start,
        ),
      );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: B.line),
              borderRadius: BorderRadius.circular(18),
              boxShadow: cardShadow(),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    for (final w in kWeekdayLetters)
                      Expanded(
                        child: Text(
                          w,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: B.muted,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                for (var row = 0; row < 6; row++)
                  AspectRatio(
                    aspectRatio: 7,
                    child: Row(
                      children: [
                        for (var col = 0; col < 7; col++)
                          Expanded(child: cell(grid[row * 7 + col])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _secLabel(calSel == today ? 'Today' : _prettyDateIso(calSel)),
          if (dayEvents.isEmpty)
            _emptyState(
              icon: 'cal',
              title: 'No events',
              sub: 'Nothing planned for this day.',
              actionLabel: 'Add event',
              onAction: () => openEvent(null, calSel),
            )
          else
            Column(
              children: [
                for (final o in dayEvents) ...[
                  _eventCard(o),
                  if (o != dayEvents.last) const SizedBox(height: 9),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- week
  Widget _calWeek() {
    final ws = _startOfWeekIso(calAnchor);
    final days = [for (var i = 0; i < 7; i++) _addDaysIso(ws, i)];
    final today = todayIso();
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          for (final iso in days) ...[
            _calWeekDayRow(iso, today),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _calWeekDayRow(String iso, String today) {
    final evs = eventOccurrences(iso, iso)
      ..sort(
        (a, b) => (a.ev.allDay ? '' : a.ev.start).compareTo(
          b.ev.allDay ? '' : b.ev.start,
        ),
      );
    final d = _parseIso(iso);
    final isToday = iso == today;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Column(
            children: [
              Text(
                kWeekdayLetters[d.weekday - 1],
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isToday ? B.primary : B.muted,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? B.primary : Colors.white,
                  border: isToday ? null : Border.all(color: B.line),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '${d.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isToday ? Colors.white : B.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: evs.isEmpty
                ? GestureDetector(
                    onTap: () => openEvent(null, iso),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: B.line,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'No events',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: B.muted,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final o in evs) ...[
                        _eventCard(o),
                        if (o != evs.last) const SizedBox(height: 7),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- agenda
  Widget _calAgenda() {
    final occ = eventOccurrences(todayIso(), _addDaysIso(todayIso(), 160))
      ..sort(
        (a, b) => (a.date + (a.ev.allDay ? '' : a.ev.start)).compareTo(
          b.date + (b.ev.allDay ? '' : b.ev.start),
        ),
      );
    if (occ.isEmpty) {
      return _emptyState(
        icon: 'cal',
        title: 'No upcoming events',
        sub: 'Your agenda is clear for now.',
        actionLabel: 'Add event',
        onAction: () => openEvent(null),
      );
    }
    final groups = <String, List<CalendarOccurrence>>{};
    for (final o in occ) {
      groups.putIfAbsent(o.date, () => []).add(o);
    }
    final today = todayIso();
    final dates = groups.keys.toList()..sort();
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final date in dates) ...[
            _secLabel(
              date == today
                  ? 'Today · ${_shortDateIso(date)}'
                  : _prettyDateIso(date),
            ),
            for (final o in groups[date]!) ...[
              _eventCard(o),
              const SizedBox(height: 9),
            ],
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- card
  Widget _eventCard(CalendarOccurrence o) {
    final ev = o.ev;
    final col = evColor(ev);
    final cat = catById(ev.category);
    final imp = o.imported;

    final inner = Row(
      children: [
        Container(
          width: 4,
          constraints: const BoxConstraints(minHeight: 34),
          decoration: BoxDecoration(
            color: col,
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
                  if (cat != null) ...[
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: col,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: categoryGlyph(
                        cat,
                        size: 18,
                        iconColor: Colors.white,
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
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ic('clock', size: 12, sw: 2.2, color: B.muted),
                      const SizedBox(width: 4),
                      Text(
                        ev.allDay
                            ? 'All day'
                            : '${ev.start}${ev.end.isNotEmpty ? '–${ev.end}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: B.soft2,
                        ),
                      ),
                    ],
                  ),
                  if (ev.location.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ic('mappin', size: 12, sw: 2.2, color: B.muted),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            ev.location,
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
                  if (ev.recur != 'none')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: B.soft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ic('repeat', size: 10, sw: 2.4, color: B.deep),
                          const SizedBox(width: 3),
                          Text(
                            ev.recur,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: B.deep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (imp)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: B.faint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ic('download', size: 10, sw: 2.4, color: B.soft2),
                          const SizedBox(width: 3),
                          Text(
                            ev.createdBy ?? 'Imported',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: B.soft2,
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
        if (!imp) ...[
          const SizedBox(width: 8),
          _attendeeStack(ev.attendees, 24),
        ],
      ],
    );

    final key = ValueKey('event-${ev.id}-${o.date}');
    final decoration = BoxDecoration(
      color: imp ? const Color(0xfffbfcfd) : Colors.white,
      border: Border.all(color: B.line),
      borderRadius: BorderRadius.circular(14),
      boxShadow: cardShadow(),
    );

    return GestureDetector(
      key: key,
      onTap: () => openEventView(ev.id, o.date),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: decoration,
        child: inner,
      ),
    );
  }

  /// A small overlapping avatar stack for event attendees, mirroring the
  /// design's `mStack()`. Calendar-only (Lists never needed multi-avatar
  /// overlap since tasks have a single assignee).
  Widget _attendeeStack(List<String> memberIds, double size) {
    final shown = memberIds.take(3).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: size + (shown.length - 1) * size * 0.6,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * size * 0.6,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: _memberAvatar(shown[i], size: size - 4),
              ),
            ),
        ],
      ),
    );
  }
}
