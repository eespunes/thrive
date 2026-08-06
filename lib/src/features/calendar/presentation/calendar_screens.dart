part of 'package:family_money_management_app/main.dart';

/// (value, label, icon) for each calendar view, in picker order.
const List<(String, String, String)> kCalViews = [
  ('month', 'Month', 'grid'),
  ('week', 'Week', 'columns'),
  ('family', 'Family', 'users'),
  ('agenda', 'Agenda', 'list'),
];

/// The Calendar tab (#152): Month/Week/Family/Agenda views over the shared
/// family [_ThriveHomeState.events], ported from the design's
/// `renderCalendar()` / `monthView()` / `weekView()` / `familyView()` /
/// `agendaView()` / `eventCard()`.
extension _ThriveCalendarScreens on _ThriveHomeState {
  static const double _calendarFadedOpacity = .45;
  static const Color _calendarTodayFill = Color(0xfff0fbfa);
  static const Color _calendarHeaderBorderColor = Color(0xffd5dce8);

  // Week view's day-head (weekday letter + date circle) is always the same
  // fixed content, so its rendered height is constant; the all-day strip's
  // height is fixed (not min-) so it never grows past this regardless of
  // event count. Both `_calWeek` and `_withStickyWeekHours` reference these
  // so the sticky hour-number gutter always lines up with the real grid
  // (issue #190).
  static const double _calWeekDayHeadHeight = 58;
  static const double _calWeekAllDayStripHeight = 54;

  // Family view's day-head height (weekday letter + date circle, same fixed
  // content as week view) and each member row's fixed cell height, shared by
  // `_calFamily` and `_withStickyFamilyMembers` so the member gutter always
  // lines up with the real per-day grid rows (issue #190).
  static const double _calFamilyDayHeadHeight = 58;
  static const double _calFamilyRowHeight = 58;

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
      'week' => _withStickyWeekHours(
        _calPagedView(
          axis: Axis.horizontal,
          periodForOffset: (offset) => _addDaysIso(calAnchor, 7 * offset),
          pageBuilder: _calWeek,
        ),
      ),
      'family' => _withStickyFamilyMembers(
        _calPagedView(
          axis: Axis.horizontal,
          periodForOffset: (offset) => _addDaysIso(calAnchor, 7 * offset),
          pageBuilder: _calFamily,
        ),
      ),
      'agenda' => _calAgenda(),
      _ => _withStickyMonthWeekdays(
        _calPagedView(
          axis: Axis.vertical,
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
          calWeekTimelineCentered = false;
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
  /// surface (crossed by event bars) while paging vertically between months
  /// (issue #190).
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

  Widget _withStickyWeekHours(Widget child) {
    const gutter = 42.0;
    const visibleHours = 8.0;
    const headerHeight = _calWeekDayHeadHeight;
    const pinnedHeight = _calWeekAllDayStripHeight;
    final hours = [for (var h = 0; h < 24; h++) h];

    // True `Row` sibling (gutter column + the swipeable pager), matching
    // `_withStickyFamilyMembers`'s pattern, rather than a `Stack`/`Positioned`
    // overlay on top of the pager. `_calWeek`'s pages no longer reserve
    // their own leading gutter-width space, so this is now the ONLY place
    // that space is reserved — with a `Stack`/`Positioned` overlay, each
    // week page still had to bake in its own blank gutter placeholder to
    // keep its day columns aligned with the overlay, which showed up as a
    // stray blank strip mid-screen while horizontally swiping between two
    // partially-visible weeks (issue #190).
    return Row(
      children: [
        Container(
          key: const ValueKey('cal-sticky-week-hours'),
          width: gutter,
          color: Colors.white,
          child: Column(
            children: [
              Container(
                height: headerHeight,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _calendarHeaderBorderColor),
                  ),
                ),
              ),
              Container(
                height: pinnedHeight,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: B.line)),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final viewportHeight = constraints.maxHeight;
                    final rowH = viewportHeight / visibleHours;
                    final gridH = hours.length * rowH;
                    final maxScroll = (gridH - viewportHeight).clamp(
                      0.0,
                      double.infinity,
                    );
                    final offset = calWeekHourOffset
                        .clamp(0.0, maxScroll)
                        .toDouble();
                    // `gridH` is taller than the viewport (24 hours vs.
                    // `visibleHours`), but `Expanded` gives this
                    // LayoutBuilder a TIGHT height constraint, so a
                    // plain `SizedBox(height: gridH)` would get clamped
                    // back down to `viewportHeight` (its child's real
                    // height is capped to the incoming tight
                    // constraint), silently discarding every hour
                    // beyond the first sliver. `OverflowBox` lets the
                    // inner content lay out at its true `gridH` height
                    // regardless of the tight parent constraint, while
                    // the outer `ClipRect` still clips it back down to
                    // the visible viewport.
                    return ClipRect(
                      child: OverflowBox(
                        minHeight: gridH,
                        maxHeight: gridH,
                        alignment: Alignment.topCenter,
                        child: Transform.translate(
                          offset: Offset(0, -offset),
                          child: SizedBox(
                            height: gridH,
                            child: Stack(
                              children: [
                                // Row divider lines matching the real
                                // hour-grid's `Container(height: rowH,
                                // border: Border(top: B.line))` column
                                // (see the `cal-week-hour-$i` grid
                                // below), so the gutter reads as part
                                // of the same grid instead of floating
                                // text with no row separation (#190).
                                Column(
                                  children: [
                                    for (var i = 0; i < hours.length; i++)
                                      Container(
                                        height: rowH,
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            top: BorderSide(color: B.line),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                for (final hour in hours)
                                  Positioned(
                                    top: hour * rowH + 2,
                                    right: 6,
                                    child: Text(
                                      '${hour.toString().padLeft(2, '0')}:00',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: B.muted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          // Mirrors the real hour-grid's vertical scroll offset into
          // `calWeekHourOffset` via notification bubbling rather than
          // reading `calWeekTimelineController.offset` directly — the
          // controller is shared across every week page's scroll view (so
          // `PageView.builder` keeping neighboring pages mounted means more
          // than one position is usually attached, making `.offset`
          // unusable/undefined). Filtering on `Axis.vertical` also excludes
          // the pager's own horizontal scroll notifications, which
          // otherwise bubble through here too (issue #190).
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.vertical) {
                final next = notification.metrics.pixels;
                if (next != calWeekHourOffset) {
                  update(() => calWeekHourOffset = next);
                }
              }
              return false;
            },
            child: child,
          ),
        ),
      ],
    );
  }

  /// Wraps the family pager with the member list fixed to the left, as a
  /// true `Row` sibling rather than a `Stack`/`Positioned` overlay drawn on
  /// top of it. Each family page (`_calFamily`) only renders the per-day
  /// columns (no leading member-name cell), so there is no second, non-sticky
  /// copy of the member column able to surface while paging horizontally
  /// between weeks (issue #190).
  Widget _withStickyFamilyMembers(Widget child) {
    const gutter = 84.0;
    final members = curFamily()?.members ?? const <FamilyMember>[];

    return Row(
      children: [
        Container(
          key: const ValueKey('cal-sticky-family-members'),
          width: gutter,
          color: Colors.white,
          child: Column(
            children: [
              Container(
                height: _calFamilyDayHeadHeight,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 4),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _calendarHeaderBorderColor),
                  ),
                ),
                child: const Text(
                  'MEMBER',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: B.soft2,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      for (var i = 0; i < members.length; i++)
                        Container(
                          height: _calFamilyRowHeight,
                          decoration: BoxDecoration(
                            border: Border(
                              top: i == 0
                                  ? BorderSide.none
                                  : const BorderSide(color: B.line),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              _memberAvatar(members[i].id, size: 24),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  members[i].name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: B.ink,
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
            ],
          ),
        ),
        Expanded(child: child),
      ],
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
        return GestureDetector(
          key: ValueKey('cal-bar-${o.ev.id}-$wi-$cs'),
          onTap: () => openEventView(o.ev.id, o.date),
          child: Opacity(
            opacity: faded ? _calendarFadedOpacity : 1,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1, vertical: .5),
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

  // --------------------------------------------------------------- week
  // --------------------------------------------------------------- week
  Widget _calWeek(String anchor) {
    const visibleHours = 8.0;
    final ws = _startOfWeekIso(anchor);
    final days = [for (var i = 0; i < 7; i++) _addDaysIso(ws, i)];
    final today = todayIso();
    final now = DateTime.now();
    final currentDayElapsed = (now.hour * 60 + now.minute) / 60;

    bool isPastDay(String iso) => iso.compareTo(today) < 0;

    bool isPastOccurrence(CalendarOccurrence o, String iso) {
      if (iso.compareTo(today) < 0) return true;
      if (iso.compareTo(today) > 0 || o.ev.allDay || o.isMultiDay) {
        return false;
      }
      return _timedEventEndMinutes(o.ev) <= now.hour * 60 + now.minute;
    }

    final dayHead = Row(
      children: [
        for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
          Expanded(
            child: Container(
              key: ValueKey('cal-week-day-head-${days[dayIndex]}'),
              // Fixed height matching `_calWeekDayHeadHeight` used by the
              // sticky hour gutter (issue #190).
              height: _calWeekDayHeadHeight,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: isPastDay(days[dayIndex]) ? B.faint : Colors.white,
                border: Border(
                  bottom: const BorderSide(color: _calendarHeaderBorderColor),
                  left: dayIndex == 0
                      ? BorderSide.none
                      : const BorderSide(color: _calendarHeaderBorderColor),
                ),
              ),
              foregroundDecoration: days[dayIndex] == today
                  ? BoxDecoration(
                      border: Border.all(color: B.primary, width: 1.4),
                    )
                  : null,
              child: Builder(
                builder: (_) {
                  final d = _parseIso(days[dayIndex]);
                  final isToday = days[dayIndex] == today;
                  final faded = isPastDay(days[dayIndex]);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      children: [
                        Opacity(
                          opacity: faded ? _calendarFadedOpacity : 1,
                          child: Text(
                            kWeekdayLetters[d.weekday - 1],
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isToday ? B.primary : B.soft2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Opacity(
                          opacity: faded ? _calendarFadedOpacity : 1,
                          child: Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isToday ? B.primary : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${d.day}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isToday ? Colors.white : B.ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );

    final allDayByDay = [
      for (final iso in days)
        eventOccurrences(
          iso,
          iso,
        ).where((o) => o.ev.allDay || o.isMultiDay).toList(),
    ];
    final allStrip = Row(
      children: [
        for (var dayIndex = 0; dayIndex < allDayByDay.length; dayIndex++)
          Expanded(
            child: Container(
              // Fixed (not min-) height so this strip's rendered height
              // always matches `_withStickyWeekHours`'s pinnedHeight
              // constant exactly, regardless of how many all-day events a
              // given week has — otherwise the sticky hour-number gutter
              // drifts out of alignment with the real hour rows (#190).
              height: _calWeekAllDayStripHeight,
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                border: Border(
                  left: dayIndex == 0
                      ? BorderSide.none
                      : const BorderSide(color: B.line),
                ),
              ),
              child: Column(
                children: [
                  for (final o in allDayByDay[dayIndex].take(3))
                    GestureDetector(
                      key: ValueKey(
                        'cal-pinned-week-${o.ev.id}-${days[dayIndex]}',
                      ),
                      onTap: () => openEventView(o.ev.id, o.date),
                      child: Opacity(
                        opacity: isPastOccurrence(o, days[dayIndex])
                            ? _calendarFadedOpacity
                            : 1,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          width: double.infinity,
                          height: 14,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: evColor(o.ev),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (catById(o.ev.category) case final cat?) ...[
                                categoryGlyph(
                                  cat,
                                  size: 9,
                                  iconColor: contrastOn(evColor(o.ev)),
                                ),
                                const SizedBox(width: 3),
                              ],
                              Flexible(
                                child: Text(
                                  o.ev.title,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: contrastOn(evColor(o.ev)),
                                  ),
                                ),
                              ),
                            ],
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

    final hours = [for (var h = 0; h < 24; h++) h];

    Widget dayCol(String iso, int dayIndex, double rowH, double gridH) {
      final timed =
          eventOccurrences(
            iso,
            iso,
          ).where((o) => !o.ev.allDay && !o.isMultiDay).toList()..sort(
            (a, b) => _toMinutes(a.ev.start).compareTo(_toMinutes(b.ev.start)),
          );
      final laid = packTimedColumns(timed);
      final isToday = iso == today;
      final isPast = isPastDay(iso);
      return Expanded(
        child: Container(
          key: ValueKey('cal-week-day-col-$iso'),
          decoration: BoxDecoration(
            color: isPast
                ? B.faint
                : (isToday ? _calendarTodayFill : Colors.transparent),
            border: Border(
              left: dayIndex == 0
                  ? BorderSide.none
                  : const BorderSide(color: B.line),
            ),
          ),
          foregroundDecoration: isToday
              ? BoxDecoration(border: Border.all(color: B.primary, width: 1.4))
              : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final colW = constraints.maxWidth;
              return Stack(
                children: [
                  if (isToday)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: (currentDayElapsed * rowH).clamp(0.0, gridH),
                      child: const IgnorePointer(
                        key: ValueKey('cal-week-today-past-hours'),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: B.faint),
                        ),
                      ),
                    ),
                  // Hour-line dividers must be redrawn on top of any
                  // OPAQUE per-day fill (today's tint or a past day's
                  // `B.faint` background), since both fully occlude the
                  // shared hour-line grid painted behind the day columns.
                  // Previously only `isToday` did this, so past days'
                  // opaque fill silently hid the grid lines entirely.
                  if (isToday || isPast)
                    IgnorePointer(
                      child: Column(
                        key: ValueKey(
                          isToday
                              ? 'cal-week-today-hour-lines'
                              : 'cal-week-past-hour-lines-$iso',
                        ),
                        children: [
                          for (var i = 0; i < hours.length; i++)
                            Container(
                              height: rowH,
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: B.line)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  for (final item in laid)
                    Builder(
                      builder: (_) {
                        final o = item.o;
                        final col = evColor(o.ev);
                        final fg = contrastOn(col);
                        final top = _toMinutes(o.ev.start) / 60 * rowH;
                        final endMin = _timedEventEndMinutes(o.ev);
                        final h =
                            ((endMin - _toMinutes(o.ev.start)) / 60 * rowH)
                                .clamp(20.0, gridH);
                        final w = colW / item.cols;
                        final titleMaxLines = ((h - 4) / (9.5 * 1.05))
                            .floor()
                            .clamp(1, 60);
                        final category = catById(o.ev.category);
                        return Positioned(
                          top: top,
                          height: h,
                          left: item.col * w,
                          width: w,
                          child: GestureDetector(
                            key: ValueKey('cal-timed-${o.ev.id}'),
                            onTap: () => openEventView(o.ev.id, o.date),
                            child: Opacity(
                              opacity: isPastOccurrence(o, iso)
                                  ? _calendarFadedOpacity
                                  : 1,
                              child: Container(
                                margin: const EdgeInsets.only(right: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: col,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: category == null
                                    ? Text(
                                        o.ev.title,
                                        softWrap: true,
                                        overflow: TextOverflow.clip,
                                        maxLines: titleMaxLines,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          height: 1.05,
                                          color: fg,
                                        ),
                                      )
                                    : Text.rich(
                                        TextSpan(
                                          children: [
                                            WidgetSpan(
                                              alignment:
                                                  PlaceholderAlignment.middle,
                                              child: categoryGlyph(
                                                category,
                                                size: 9,
                                                iconColor: fg,
                                              ),
                                            ),
                                            TextSpan(text: ' ${o.ev.title}'),
                                          ],
                                        ),
                                        softWrap: true,
                                        overflow: TextOverflow.clip,
                                        maxLines: titleMaxLines,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          height: 1.05,
                                          color: fg,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  if (isToday)
                    Positioned(
                      top: (now.hour * 60 + now.minute) / 60 * rowH,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 2,
                          color: const Color(0xffe11d48),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
    }

    final controller = calWeekTimelineController;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          dayHead,
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: B.line)),
            ),
            child: allStrip,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportHeight = constraints.maxHeight;
                final rowH = viewportHeight / visibleHours;
                final gridH = hours.length * rowH;
                if (!calWeekTimelineCentered) {
                  calWeekTimelineCentered = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || !controller.hasClients) return;
                    final currentHour = now.hour + now.minute / 60;
                    final target = (currentHour * rowH).clamp(
                      0.0,
                      gridH - viewportHeight,
                    );
                    controller.jumpTo(target);
                  });
                }
                return SingleChildScrollView(
                  key: const ValueKey('cal-timeline-week'),
                  controller: controller,
                  child: SizedBox(
                    key: const ValueKey('cal-hour-grid-week'),
                    height: gridH,
                    // No leading gutter-width placeholder here: this page's
                    // day-column grid now spans the full pager width, with
                    // the hour gutter reserved once by `_withStickyWeekHours`
                    // as a true sibling column outside the `PageView`. A
                    // per-page blank gutter used to be baked into every
                    // week's `Row`, which showed up as a stray blank strip
                    // mid-screen while horizontally swiping between weeks,
                    // since two pages are partially visible at once during
                    // the transition (issue #190).
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            for (var i = 0; i < hours.length; i++)
                              Container(
                                key: ValueKey('cal-week-hour-$i'),
                                height: rowH,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: B.line),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            for (
                              var dayIndex = 0;
                              dayIndex < days.length;
                              dayIndex++
                            )
                              dayCol(days[dayIndex], dayIndex, rowH, gridH),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- family
  Widget _calFamily(String anchor) {
    final ws = _startOfWeekIso(anchor);
    final days = [for (var i = 0; i < 7; i++) _addDaysIso(ws, i)];
    final today = todayIso();
    final members = curFamily()?.members ?? const <FamilyMember>[];

    bool isPastDay(String iso) => iso.compareTo(today) < 0;

    // The "MEMBER" label lives once in the fixed gutter built by
    // `_withStickyFamilyMembers` — this per-page header only renders the
    // day-of-week cells so it can't surface a second, non-sticky copy while
    // paging horizontally between weeks (issue #190).
    Widget head() {
      return Row(
        children: [
          for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
            Expanded(
              child: Container(
                key: ValueKey('cal-family-day-head-${days[dayIndex]}'),
                // Fixed height matching `_calFamilyDayHeadHeight` used by
                // the sticky member gutter's header cell (issue #190).
                height: _calFamilyDayHeadHeight,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: isPastDay(days[dayIndex]) ? B.faint : Colors.white,
                  border: const Border(
                    left: BorderSide(color: _calendarHeaderBorderColor),
                    bottom: BorderSide(color: _calendarHeaderBorderColor),
                  ),
                ),
                foregroundDecoration: days[dayIndex] == today
                    ? BoxDecoration(
                        border: Border.all(color: B.primary, width: 1.4),
                      )
                    : null,
                child: Builder(
                  builder: (_) {
                    final d = _parseIso(days[dayIndex]);
                    final isToday = days[dayIndex] == today;
                    final faded = isPastDay(days[dayIndex]);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Column(
                        children: [
                          Opacity(
                            opacity: faded ? _calendarFadedOpacity : 1,
                            child: Text(
                              kWeekdayLetters[d.weekday - 1],
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: isToday ? B.primary : B.soft2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Opacity(
                            opacity: faded ? _calendarFadedOpacity : 1,
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isToday ? B.primary : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${d.day}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isToday ? Colors.white : B.ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      );
    }

    Widget memberRow(FamilyMember m, bool top) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            top: top ? BorderSide.none : BorderSide(color: B.line),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final iso in days)
              Expanded(
                child: Builder(
                  builder: (_) {
                    final isPast = isPastDay(iso);
                    final evs =
                        eventOccurrences(
                            iso,
                            iso,
                          ).where((o) => o.ev.attendees.contains(m.id)).toList()
                          ..sort(
                            (a, b) => (a.ev.allDay ? '' : a.ev.start).compareTo(
                              b.ev.allDay ? '' : b.ev.start,
                            ),
                          );
                    return Container(
                      key: ValueKey('cal-family-cell-${m.id}-$iso'),
                      // Fixed (not min-) height matching `_calFamilyRowHeight`
                      // used by the sticky member gutter's row, so the two
                      // never drift out of sync as event counts vary
                      // (issue #190). Content is capped at 3 events + an
                      // overflow label, which always fits within this
                      // height; `clipBehavior` guards edge cases.
                      height: _calFamilyRowHeight,
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        border: const Border(left: BorderSide(color: B.line)),
                        color: isPast
                            ? B.faint
                            : (iso == today ? _calendarTodayFill : null),
                      ),
                      foregroundDecoration: iso == today
                          ? BoxDecoration(
                              border: Border.all(color: B.primary, width: 1.4),
                            )
                          : null,
                      child: Column(
                        children: [
                          for (final o in evs.take(3))
                            GestureDetector(
                              key: ValueKey(
                                'cal-family-${m.id}-${o.ev.id}-$iso',
                              ),
                              onTap: () => openEventView(o.ev.id, iso),
                              child: Opacity(
                                opacity: isPast ? _calendarFadedOpacity : 1,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 2),
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: evColor(o.ev),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Row(
                                    children: [
                                      if (catById(o.ev.category)
                                          case final cat?) ...[
                                        categoryGlyph(
                                          cat,
                                          size: 9,
                                          iconColor: contrastOn(evColor(o.ev)),
                                        ),
                                        const SizedBox(width: 2),
                                      ],
                                      Flexible(
                                        child: Text(
                                          o.ev.allDay
                                              ? o.ev.title
                                              : '${o.ev.start} ${o.ev.title}',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                            color: contrastOn(evColor(o.ev)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (evs.length > 3)
                            Text(
                              '+${evs.length - 3}',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: B.muted,
                              ),
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

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // No extra padding/border here: each day-head cell built by
          // `head()` already has a fixed height (`_calFamilyDayHeadHeight`)
          // and its own bottom border, matching the sticky member gutter's
          // header cell exactly. Wrapping padding previously added 16px on
          // top of that fixed height (plus a second border), which the
          // gutter didn't have — throwing the whole grid out of alignment
          // with the member rows below (issue #190).
          head(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < members.length; i++)
                    memberRow(members[i], i == 0),
                ],
              ),
            ),
          ),
        ],
      ),
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
