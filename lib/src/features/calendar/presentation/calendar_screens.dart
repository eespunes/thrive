part of 'package:family_money_management_app/main.dart';

/// (value, label, icon) for each calendar view, in picker order.
const List<(String, String, String)> kCalViews = [
  ('month', 'Month', 'grid'),
  ('agenda', 'Agenda', 'list'),
];

/// The Calendar tab (#152): Month/Agenda views over the shared
/// family [_ThriveHomeState.events], ported from the design's
/// `renderCalendar()` / `monthView()` / `agendaView()` / `eventCard()`.
extension _ThriveCalendarScreens on _ThriveHomeState {
  static const double _calendarFadedOpacity = .45;
  static const Color _calendarHeaderBorderColor = Color(0xffd5dce8);

  static const int _calendarPageCenter = 10000;

  String _calViewIcon() {
    for (final (v, _, icon) in kCalViews) {
      if (v == calView) return icon;
    }
    return 'grid';
  }

  /// View-switcher + filter (badge) icon buttons shown in the app header
  /// when the Calendar tab is active.
  Widget _calHeaderActions() {
    final fc = calFilterCount();
    Widget iconBtn(
      String icon,
      String keySuffix,
      VoidCallback onTap, {
      int? badge,
    }) {
      final active = badge != null && badge > 0;
      return GestureDetector(
        key: ValueKey('cal-header-$keySuffix'),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            border: Border.all(color: active ? B.primary : B.line),
            color: active ? B.soft : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: ic(
                  icon,
                  size: 18,
                  sw: 2.1,
                  color: active ? B.deep : B.soft2,
                ),
              ),
              if (badge != null && badge > 0)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 17,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: B.primary,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: B.page, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconBtn(_calViewIcon(), 'view', openViewPicker),
        iconBtn('filter', 'filter', openCalFilterSheet, badge: fc),
      ],
    );
  }

  Widget _buildCalendar() {
    return switch (calView) {
      'agenda' => _calAgenda(),
      _ => _withStickyMonthWeekdays(
        _calPagedView(
          axis: Axis.horizontal,
          periodForOffset: (offset) => _addMonthsIso(calAnchor, offset),
          pageBuilder: _calMonth,
        ),
      ),
    };
  }

  Widget _calPagedView({
    required Axis axis,
    required String Function(int offset) periodForOffset,
    required Widget Function(String anchor) pageBuilder,
  }) {
    return PageView.builder(
      key: ValueKey('cal-pager-$calView'),
      controller: calPageController,
      scrollDirection: axis,
      pageSnapping: true,
      physics: const PageScrollPhysics(),
      onPageChanged: (page) {
        final offset = page - _calendarPageCenter;
        if (offset == 0) return;
        final nextAnchor = periodForOffset(offset);
        if (calPageController.hasClients) {
          calPageController.jumpToPage(_calendarPageCenter);
        }
        update(() {
          calAnchor = nextAnchor;
        });
      },
      itemBuilder: (context, index) {
        final offset = index - _calendarPageCenter;
        return pageBuilder(periodForOffset(offset));
      },
    );
  }

  /// Wraps the month pager in the calendar's card chrome, with a single
  /// weekday-letter header row genuinely fixed above the swipeable page
  /// content — as a true `Column` sibling rather than a `Stack`/`Positioned`
  /// overlay on top of it. Each month page (`_calMonth`) only renders its
  /// week rows, so there is no second, non-sticky copy of the header able to
  /// surface (crossed by event bars) while paging horizontally between
  /// months (issue #190).
  Widget _withStickyMonthWeekdays(Widget child) {
    return Container(
      key: const ValueKey('cal-sticky-month-weekdays'),
      margin: const EdgeInsets.only(top: 12),
      constraints: const BoxConstraints(minHeight: 360),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: cardShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Row(
            children: [
              for (
                var dayIndex = 0;
                dayIndex < kWeekdayLetters.length;
                dayIndex++
              )
                Expanded(
                  child: Container(
                    key: ValueKey('cal-weekday-$dayIndex'),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: const BorderSide(
                          color: _calendarHeaderBorderColor,
                        ),
                        left: dayIndex == 0
                            ? BorderSide.none
                            : const BorderSide(
                                color: _calendarHeaderBorderColor,
                              ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        kWeekdayLetters[dayIndex],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: B.soft2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- month
  Widget _calMonth(String anchor) {
    final grid = monthGrid(anchor);
    final curMonth = _parseIso(anchor).month;
    final today = todayIso();

    bool isInCurrentMonth(String iso) => _parseIso(iso).month == curMonth;

    Widget dayNumber(String iso) {
      final d = _parseIso(iso);
      final inMonth = d.month == curMonth;
      final isToday = iso == today;
      return GestureDetector(
        key: ValueKey('cal-day-$iso'),
        onTap: () {
          setCalSel(iso);
          openDayDetail(iso);
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.only(top: 2),
          child: Container(
            width: 19,
            height: 19,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? B.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
                color: isToday
                    ? Colors.white
                    : (inMonth ? B.ink : const Color(0xffc2cad6)),
              ),
            ),
          ),
        ),
      );
    }

    Widget weekRow(List<String> row, int wi) {
      final ws = row.first;
      final we = row.last;
      final occ = eventOccurrences(ws, we);
      final packed = packWeekLanes(occ, ws, we);
      final inCurrentMonth = [for (final iso in row) isInCurrentMonth(iso)];

      Widget bar(CalendarOccurrence o, int cs, int ce, {bool faded = false}) {
        final col = evColor(o.ev);
        final barFg = contrastOn(col);
        final category = catById(o.ev.category);
        final left = o.date.compareTo(ws) < 0;
        final right = o.spanEnd.compareTo(we) > 0;
        final label = (o.isMultiDay && left) ? '‹ ${o.ev.title}' : o.ev.title;
        final span = ce - cs + 1;
        return LayoutBuilder(
          builder: (context, constraints) {
            // Tapping an event bar (single- or multi-day) always opens the
            // day-detail sheet for the day under the finger — never the
            // individual event view directly — so every tap on a Month-view
            // day, on an event or on empty space, shows the day's full
            // event list first (issue #198).
            void openDetailForTap(double localX) {
              final width = constraints.maxWidth;
              final frac = width > 0 ? (localX / width).clamp(0.0, 0.999) : 0;
              final dayIndex = (cs + (frac * span).floor()).clamp(cs, ce);
              final iso = row[dayIndex];
              setCalSel(iso);
              openDayDetail(iso);
            }

            return GestureDetector(
              key: ValueKey('cal-bar-${o.ev.id}-$wi-$cs'),
              onTapUp: (details) => openDetailForTap(details.localPosition.dx),
              child: Opacity(
                opacity: faded ? _calendarFadedOpacity : 1,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 1,
                    vertical: .5,
                  ),
                  height: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: col,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(left ? 0 : 4),
                      bottomLeft: Radius.circular(left ? 0 : 4),
                      topRight: Radius.circular(right ? 0 : 4),
                      bottomRight: Radius.circular(right ? 0 : 4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (category != null) ...[
                        categoryGlyph(category, size: 10, iconColor: barFg),
                        const SizedBox(width: 3),
                      ] else if (!o.isMultiDay)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: barFg,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            color: barFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }

      final laneRows = <Widget>[];
      for (final lane in packed.lanes) {
        final cells = <Widget>[];
        var c = 0;
        while (c < 7) {
          final o = lane[c];
          if (o == null) {
            cells.add(const Expanded(child: SizedBox()));
            c++;
            continue;
          }
          final startInCurrentMonth = inCurrentMonth[c];
          var span = 1;
          while (c + span < 7 &&
              lane[c + span] == o &&
              (inCurrentMonth[c + span] == startInCurrentMonth)) {
            span++;
          }
          cells.add(
            Expanded(
              flex: span,
              child: bar(o, c, c + span - 1, faded: !startInCurrentMonth),
            ),
          );
          c += span;
        }
        laneRows.add(Row(children: cells));
      }
      final overflowRow = packed.overflow.isEmpty
          ? null
          : Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: packed.overflow[i] != null
                        ? Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: Text(
                              '+${packed.overflow[i]}',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: B.muted,
                              ),
                            ),
                          )
                        : const SizedBox(),
                  ),
              ],
            );

      return Container(
        decoration: BoxDecoration(
          border: Border(
            top: wi == 0 ? BorderSide.none : BorderSide(color: B.line),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(0, 3, 0, 4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Row(
              children: [
                for (var dayIndex = 0; dayIndex < row.length; dayIndex++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setCalSel(row[dayIndex]);
                        openDayDetail(row[dayIndex]);
                      },
                      child: Container(
                        key: ValueKey('cal-day-bg-${row[dayIndex]}'),
                        decoration: BoxDecoration(
                          color: inCurrentMonth[dayIndex]
                              ? Colors.transparent
                              : B.faint,
                          border: Border(
                            left: dayIndex == 0
                                ? BorderSide.none
                                : const BorderSide(color: B.line),
                          ),
                        ),
                        foregroundDecoration: row[dayIndex] == today
                            ? BoxDecoration(
                                border: Border.all(
                                  color: B.primary,
                                  width: 1.4,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              children: [
                Row(
                  children: [
                    for (final iso in row) Expanded(child: dayNumber(iso)),
                  ],
                ),
                ...laneRows,
                ?overflowRow,
              ],
            ),
          ],
        ),
      );
    }

    final weeks = [for (var w = 0; w < 6; w++) grid.sublist(w * 7, w * 7 + 7)];

    // No card chrome or weekday header here: `_withStickyMonthWeekdays`
    // (the caller) already renders the single genuinely-sticky weekday
    // header and the card's border/shadow/rounded corners exactly once,
    // outside the swipeable month pager. Previously this page ALSO built
    // its own weekday-letter row (`cal-weekday-N`) and its own copy of the
    // card chrome, so every month page showed a second, non-sticky header
    // stacked directly below the real sticky one while scrolling (issue
    // #190).
    return Column(
      children: [
        for (var wi = 0; wi < weeks.length; wi++)
          Expanded(child: weekRow(weeks[wi], wi)),
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
  Widget _eventCard(CalendarOccurrence o, {bool popSheetFirst = false}) {
    final ev = o.ev;
    final col = evColor(ev);
    final cat = catById(ev.category);
    final imp = o.imported;
    final isTask = o.isTask;

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
                        iconColor: contrastOn(col),
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
                      ic(
                        o.isMultiDay ? 'cal' : 'clock',
                        size: 12,
                        sw: 2.2,
                        color: B.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        o.isMultiDay
                            ? '${_shortDateIso(o.date)} – ${_shortDateIso(o.spanEnd)}'
                            : (ev.allDay
                                  ? 'All day'
                                  : '${ev.start}${ev.end.isNotEmpty ? '–${ev.end}' : ''}'),
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
                  if (isTask)
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
                          ic('tasklist', size: 10, sw: 2.4, color: B.soft2),
                          const SizedBox(width: 3),
                          const Text(
                            'Task',
                            style: TextStyle(
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

    return Builder(
      builder: (context) => GestureDetector(
        key: key,
        onTap: () {
          // From the day-detail sheet: pop it first so the event view opens
          // as a single sheet, not stacked on top of a now-stale one that
          // would otherwise still show pre-edit data once dismissed
          // (issue #198).
          if (popSheetFirst) Navigator.of(context).pop();
          openEventView(ev.id, o.date);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: decoration,
          child: inner,
        ),
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
