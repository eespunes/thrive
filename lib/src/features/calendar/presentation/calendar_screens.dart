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
        iconBtn('columns', 'kitchen-dashboard', openKitchenDashboard),
      ],
    );
  }

  Widget _buildCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: switch (calView) {
            'agenda' => _calAgenda(),
            _ => _withStickyMonthWeekdays(
              _calPagedView(
                axis: Axis.horizontal,
                periodForOffset: (offset) => _addMonthsIso(calAnchor, offset),
                pageBuilder: _calMonth,
              ),
            ),
          },
        ),
      ],
    );
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
        // Task/content occurrences render as an outlined (task) or
        // dashed-outline pink (content) pill with a leading checkbox that
        // toggles completion independently of the day-detail tap (issue:
        // calendar layers). Real/imported appointments keep the original
        // solid-colour block look.
        if (o.isTask) {
          // Household to-dos (`kind: 'chore'`) keep the original solid
          // assignee/list-colour fill so the existing "coloured by
          // assignee" behaviour (issue #199) is unchanged; content-layer
          // occurrences instead use a transparent fill with a dashed pink
          // outline, matching the Calendar Layers design.
          final accent = o.isContent ? const Color(0xffdb2777) : col;
          final fg = o.isContent ? accent : contrastOn(col);
          return Opacity(
            key: ValueKey('cal-bar-${o.ev.id}-$wi-$cs'),
            opacity: faded ? _calendarFadedOpacity : 1,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1, vertical: .5),
              height: 14,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: o.isContent ? Colors.white : col,
                borderRadius: BorderRadius.circular(4),
              ),
              foregroundDecoration: o.isContent
                  ? _DashedBoxDecoration(color: accent, radius: 4)
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    key: ValueKey('cal-check-${o.ev.id}-${o.date}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleOccurrenceDone(o),
                    child: Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: fg, width: 1.2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setCalSel(o.date);
                        openDayDetail(o.date);
                      },
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

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
  /// Agenda mode: a Mon-Sun week strip day-picker (`weekStrip()` in the
  /// design) above a single selected day's (`agendaDay`) 3 gated
  /// layer-sections (`daySchedule()`), rather than an infinite multi-day
  /// list. Tapping a strip day-cell switches which day's sections show.
  Widget _calAgenda() {
    final dayOcc = eventOccurrences(agendaDay, agendaDay);
    final today = todayIso();
    final sections = _agendaDaySections(agendaDay, dayOcc);
    final hasAny =
        dayOcc.any((o) => o.layer == 'task' && layerFilter.contains('task')) ||
        dayOcc.any(
          (o) => o.layer == 'content' && layerFilter.contains('content'),
        ) ||
        dayOcc.any((o) => o.layer == 'appt' && layerFilter.contains('appt'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _weekStrip(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            child: !hasAny
                ? _emptyState(
                    icon: 'cal',
                    title: 'No events today',
                    sub: 'Your agenda is clear for this day.',
                    actionLabel: 'Add event',
                    onAction: () => openEvent(null),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _secLabel(
                        agendaDay == today
                            ? 'Today · ${_shortDateIso(agendaDay)}'
                            : _prettyDateIso(agendaDay),
                      ),
                      sections,
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  /// Mon-Sun day-picker strip for the week containing [agendaDay] — 7
  /// cells, each showing the weekday letter, date number, and a row of
  /// small layer-colour dots for any layer with an occurrence that day
  /// (gated by `layerFilter`, mirroring `layerEnabled`). The selected cell
  /// fills solid `B.ink` with white text; today (if not selected) shows its
  /// weekday letter/number in `B.primary` (`weekStrip()` in the design).
  Widget _weekStrip() {
    final weekStart = _startOfWeekIso(agendaDay);
    final today = todayIso();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i != 0) const SizedBox(width: 6),
            Expanded(
              child: _weekStripCell(_addDaysIso(weekStart, i), i, today),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weekStripCell(String iso, int weekdayIdx, String today) {
    final selected = iso == agendaDay;
    final isToday = iso == today;
    final d = _parseIso(iso);
    final dayOcc = eventOccurrences(iso, iso);
    final dotColors = <Color>[
      for (final (id, _, _, color) in kCalLayers)
        if (layerFilter.contains(id) && dayOcc.any((o) => o.layer == id)) color,
    ];
    return GestureDetector(
      key: ValueKey('cal-week-strip-$iso'),
      onTap: () => update(() => agendaDay = iso),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? B.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kWeekdayLetters[weekdayIdx],
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: selected
                    ? Colors.white
                    : (isToday ? B.primary : B.muted),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : (isToday ? B.primary : B.ink),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var ci = 0; ci < dotColors.length; ci++) ...[
                    if (ci != 0) const SizedBox(width: 2),
                    Container(
                      key: ValueKey('cal-week-strip-dot-$iso-$ci'),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : dotColors[ci],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Splits a single day's occurrences into the mockup's three fixed-order,
  /// per-layer sections ("To-Dos" / "Content creation" / "Schedule") —
  /// each only rendered when its layer chip is enabled AND it has at least
  /// one occurrence that day (`daySchedule()` in the Calendar Layers
  /// design).
  Widget _agendaDaySections(String date, List<CalendarOccurrence> dayOcc) {
    final tasks = dayOcc.where((o) => o.layer == 'task').toList();
    final contents = dayOcc.where((o) => o.layer == 'content').toList();
    final appts = dayOcc.where((o) => o.layer == 'appt').toList()
      ..sort(
        (a, b) => (a.ev.allDay ? '' : a.ev.start).compareTo(
          b.ev.allDay ? '' : b.ev.start,
        ),
      );

    final sections = <Widget>[];
    if (layerFilter.contains('task') && tasks.isNotEmpty) {
      sections.add(
        _agendaSection(
          key: 'agenda-section-task-$date',
          label: 'To-Dos',
          color: const Color(0xff2563eb),
          rows: [for (final o in tasks) _taskAgendaRow(o)],
        ),
      );
    }
    if (layerFilter.contains('content') && contents.isNotEmpty) {
      sections.add(
        _agendaSection(
          key: 'agenda-section-content-$date',
          label: 'Content creation',
          color: const Color(0xffdb2777),
          rows: [for (final o in contents) _contentAgendaRow(o)],
        ),
      );
    }
    if (layerFilter.contains('appt') && appts.isNotEmpty) {
      sections.add(
        _agendaSection(
          key: 'agenda-section-appt-$date',
          label: 'Schedule',
          color: B.primary,
          rows: [for (final o in appts) _apptAgendaRow(o)],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  /// A layer section: dot + uppercase label header (mirrors `sectionLabel()`
  /// in the mockup) followed by its rows.
  Widget _agendaSection({
    required String key,
    required String label,
    required Color color,
    required List<Widget> rows,
  }) {
    return Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                    color: B.soft2,
                  ),
                ),
              ],
            ),
          ),
          for (final row in rows)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: row),
        ],
      ),
    );
  }

  /// The assignee's member colour for an appointment-layer occurrence's
  /// solid block background — falls back to [evColor] (category colour or
  /// the event's own colour) when no attendee resolves to a family member.
  Color _apptAssigneeColor(CalendarEvent ev) {
    for (final memberId in ev.attendees) {
      final member = _memberById(memberId);
      if (member != null) return member.color;
    }
    return evColor(ev);
  }

  /// Agenda "Schedule" row for an appointment occurrence — a solid block
  /// filled with the assignee's member colour, a narrow time column, and a
  /// repeat badge when recurring (`apptRow()` in the design).
  Widget _apptAgendaRow(CalendarOccurrence o) {
    final ev = o.ev;
    final col = _apptAssigneeColor(ev);
    return GestureDetector(
      key: ValueKey('agenda-appt-${ev.id}-${o.date}'),
      onTap: () => openEventView(ev.id, o.date),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: col,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: col.withValues(alpha: .45),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ev.allDay ? 'All' : ev.start,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    ev.allDay ? 'day' : ev.end,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: .75),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 11),
              color: Colors.white.withValues(alpha: .35),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ev.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (ev.recur != 'none')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ic('repeat', size: 10, sw: 2.6, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            'Repeats ${ev.recur}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: .85),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _attendeeStack(ev.attendees, 22),
          ],
        ),
      ),
    );
  }

  /// Agenda "To-Dos" row — a white bordered card with a tappable checkbox
  /// (untouched semantics: tapping calls [_toggleOccurrenceDone], which
  /// removes the occurrence once its underlying [ListTask] is marked done)
  /// and a recurrence badge chip (`taskRow()` in the design). [checkColor]
  /// lets the Kitchen Dashboard fill the checkbox with the member's colour
  /// instead of the to-do layer's accent; [showAvatar] is turned off there
  /// too since each column is already scoped to one member.
  Widget _taskAgendaRow(
    CalendarOccurrence o, {
    Color? checkColor,
    bool showAvatar = true,
  }) {
    final ev = o.ev;
    final accent = checkColor ?? const Color(0xff2563eb);
    return Container(
      key: ValueKey('agenda-task-${ev.id}-${o.date}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          GestureDetector(
            key: ValueKey('event-check-${ev.id}-${o.date}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleOccurrenceDone(o),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 2),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            // The recurrence badge sits below the title in its own row —
            // rather than sharing the title's line — so it can never force
            // a fixed-width horizontal overflow when this row is narrow
            // (e.g. a Kitchen Dashboard member column).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openEventView(ev.id, o.date),
                  child: Text(
                    ev.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
                    ),
                  ),
                ),
                if (ev.recur != 'none')
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    // `FittedBox` (rather than a bare `Container`/`Row`)
                    // guarantees this badge never render-overflows however
                    // narrow its column gets (e.g. a Kitchen Dashboard
                    // member tile) — it scales itself down to fit instead.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: B.soft,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ic('repeat', size: 9.5, sw: 2.6, color: B.deep),
                            const SizedBox(width: 3),
                            Text(
                              ev.recur,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: B.deep,
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
          if (showAvatar) ...[
            const SizedBox(width: 8),
            _attendeeStack(ev.attendees, 22),
          ],
        ],
      ),
    );
  }

  /// Agenda "Content creation" row — a white card with a dashed pink
  /// border, a small camera icon badge, and a pink "Content" label beneath
  /// the title (`contentRow()` in the design). [checkColor] lets the
  /// Kitchen Dashboard fill the checkbox with the member's colour instead
  /// of the content layer's pink accent; [showAvatar] is turned off there
  /// too since each column is already scoped to one member.
  Widget _contentAgendaRow(
    CalendarOccurrence o, {
    Color? checkColor,
    bool showAvatar = true,
  }) {
    final ev = o.ev;
    const pink = Color(0xffdb2777);
    final accent = checkColor ?? pink;
    return Container(
      key: ValueKey('agenda-content-${ev.id}-${o.date}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      foregroundDecoration: const _DashedBoxDecoration(color: pink, radius: 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xfffce7f3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: ic('camera', size: 15, sw: 2.1, color: pink)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openEventView(ev.id, o.date),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ev.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Content',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: pink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: ValueKey('event-check-${ev.id}-${o.date}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleOccurrenceDone(o),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 2),
              ),
            ),
          ),
          if (showAvatar) ...[
            const SizedBox(width: 8),
            _attendeeStack(ev.attendees, 22),
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
    final isContent = o.isContent;
    final accent = isContent ? const Color(0xffdb2777) : col;

    // Task/content occurrences get a tappable checkbox as their leading
    // widget instead of the plain colour strip, so completion can be
    // toggled without opening the (read-only) detail sheet (issue:
    // calendar layers checkbox).
    final leading = isTask
        ? GestureDetector(
            key: ValueKey('event-check-${ev.id}-${o.date}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleOccurrenceDone(o),
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 2),
              ),
            ),
          )
        : Container(
            width: 4,
            constraints: const BoxConstraints(minHeight: 34),
            decoration: BoxDecoration(
              color: col,
              borderRadius: BorderRadius.circular(3),
            ),
          );

    final rest = Row(
      children: [
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
                        color: isContent ? const Color(0xfffce7f3) : B.faint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ic(
                            isContent ? 'camera' : 'tasklist',
                            size: 10,
                            sw: 2.4,
                            color: isContent ? accent : B.soft2,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isContent ? 'Content' : 'Task',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isContent ? accent : B.soft2,
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
      border: isContent ? null : Border.all(color: B.line),
      borderRadius: BorderRadius.circular(14),
      boxShadow: cardShadow(),
    );

    return Builder(
      builder: (context) {
        void openTap() {
          // From the day-detail sheet: pop it first so the event view opens
          // as a single sheet, not stacked on top of a now-stale one that
          // would otherwise still show pre-edit data once dismissed
          // (issue #198).
          if (popSheetFirst) Navigator.of(context).pop();
          openEventView(ev.id, o.date);
        }

        // Task/content cards keep the checkbox (`leading`) outside the
        // open-detail tap area — only the rest of the card opens the
        // sheet, so the checkbox toggles completion independently
        // (issue: calendar layers checkbox). Real/imported events keep
        // the whole card tappable, as before.
        final cardBody = isTask
            ? Row(
                children: [
                  leading,
                  const SizedBox(width: 11),
                  Expanded(
                    child: GestureDetector(
                      key: key,
                      behavior: HitTestBehavior.opaque,
                      onTap: openTap,
                      child: rest,
                    ),
                  ),
                ],
              )
            : GestureDetector(
                key: key,
                onTap: openTap,
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 11),
                    Expanded(child: rest),
                  ],
                ),
              );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: decoration,
          foregroundDecoration: isContent
              ? _DashedBoxDecoration(color: accent, radius: 14)
              : null,
          child: cardBody,
        );
      },
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

/// A dashed rounded-rect border, painted as a [foregroundDecoration] —
/// content-layer occurrences (Month bars, Agenda/day-detail cards) use this
/// to stand out from the solid borders/fills of real appointments and
/// household task pills (Calendar Layers design).
class _DashedBoxDecoration extends Decoration {
  const _DashedBoxDecoration({required this.color, required this.radius});

  final Color color;
  final double radius;
  final double strokeWidth = 1.2;
  final double dashWidth = 3;
  final double gapWidth = 2;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DashedBoxPainter(this);
}

class _DashedBoxPainter extends BoxPainter {
  _DashedBoxPainter(this.decoration);
  final _DashedBoxDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size ?? Size.zero;
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = decoration.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = decoration.strokeWidth;
    final inset = decoration.strokeWidth / 2;
    final rect = Rect.fromLTWH(
      offset.dx + inset,
      offset.dy + inset,
      size.width - decoration.strokeWidth,
      size.height - decoration.strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(decoration.radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + decoration.dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + decoration.gapWidth;
      }
    }
  }
}
