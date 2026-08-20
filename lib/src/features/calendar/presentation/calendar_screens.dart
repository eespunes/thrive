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

      // Every occurrence's Month-view bar uses the exact same visual
      // treatment now — a solid colour-filled block, regardless of which
      // calendar layer it belongs to (issue: calendar layers uniform
      // rendering) — rather than appointments getting a solid block while
      // task/content occurrences got a distinct outlined/dashed pill.
      // To-do/content-style occurrences (`o.isTask`) still get a small
      // leading checkbox that toggles completion independently of the
      // day-detail tap; a done occurrence stays on the calendar (never
      // removed) but shows a strikethrough label and reduced opacity.
      Widget bar(CalendarOccurrence o, int cs, int ce, {bool faded = false}) {
        final col = evColor(o.ev);
        final barFg = contrastOn(col);
        final category = catById(o.ev.category);
        final left = o.date.compareTo(ws) < 0;
        final right = o.spanEnd.compareTo(we) > 0;
        final label = (o.isMultiDay && left) ? '‹ ${o.ev.title}' : o.ev.title;
        final span = ce - cs + 1;
        final done = o.done;

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
                opacity: (faded || done) ? _calendarFadedOpacity : 1,
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
                      if (o.isTask)
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
                              color: done ? barFg.withValues(alpha: .22) : null,
                              border: Border.all(color: barFg, width: 1.2),
                            ),
                            child: done
                                ? Icon(Icons.check, size: 6.5, color: barFg)
                                : null,
                          ),
                        )
                      else if (category != null) ...[
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
                            decoration: done
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _weekStripPager(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            child: Column(
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

  List<CalendarLayerDef> _agendaLayerDefs(List<CalendarOccurrence> dayOcc) {
    final base = calendarLayers.isEmpty
        ? kDefaultCalendarLayers()
        : calendarLayers;
    final out = <CalendarLayerDef>[
      for (final layer in base)
        if (layerFilter.contains(layer.id)) layer,
    ];
    final seen = {for (final layer in out) layer.id};
    for (final o in dayOcc) {
      if (!layerFilter.contains(o.layer) || seen.contains(o.layer)) continue;
      out.add(
        layerDefFor(o.layer) ??
            CalendarLayerDef(
              id: o.layer,
              label: 'Layer',
              icon: 'cal',
              color: evColor(o.ev),
            ),
      );
      seen.add(o.layer);
    }
    return out;
  }

  int _compareAgendaOccurrences(CalendarOccurrence a, CalendarOccurrence b) {
    final time = (a.ev.allDay ? '' : a.ev.start).compareTo(
      b.ev.allDay ? '' : b.ev.start,
    );
    if (time != 0) return time;
    return a.ev.title.compareTo(b.ev.title);
  }

  /// Mon-Sun day-picker strip for the week containing [agendaDay] — 7
  /// cells, each showing the weekday letter, date number, and a row of
  /// small layer-colour dots for any layer with an occurrence that day
  /// (gated by `layerFilter`, mirroring `layerEnabled`). The selected cell
  /// fills solid `B.ink` with white text; today (if not selected) shows its
  /// weekday letter/number in `B.primary` (`weekStrip()` in the design).
  /// Swipeable pager over Mon-Sun weeks, so the user can navigate to the
  /// next/previous week; the first day of each page is always Monday.
  /// Swiping settles `agendaDay` on the Monday of the newly-shown week
  /// (mirrors `_calPagedView`'s month-paging pattern).
  Widget _weekStripPager() {
    return SizedBox(
      height: 78,
      child: PageView.builder(
        key: const ValueKey('cal-week-pager'),
        controller: calWeekPageController,
        pageSnapping: true,
        physics: const PageScrollPhysics(),
        onPageChanged: (page) {
          final offset = page - _calendarPageCenter;
          if (offset == 0) return;
          final weekStart = _startOfWeekIso(agendaDay);
          final nextWeekStart = _addDaysIso(weekStart, offset * 7);
          if (calWeekPageController.hasClients) {
            calWeekPageController.jumpToPage(_calendarPageCenter);
          }
          update(() => agendaDay = nextWeekStart);
        },
        itemBuilder: (context, index) {
          final offset = index - _calendarPageCenter;
          final weekStart = _addDaysIso(_startOfWeekIso(agendaDay), offset * 7);
          return _weekStrip(weekStart);
        },
      ),
    );
  }

  Widget _weekStrip(String weekStart) {
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
    // Built straight from the day's occurrences (gated by `layerFilter`)
    // rather than by iterating [calendarLayers] — so a dot still shows for
    // a layer with an occurrence that day (e.g. plain appointments) even
    // when [calendarLayers] hasn't been seeded yet (a legacy/new
    // workspace with zero layer definitions).
    final seenLayers = <String>{};
    final dotColors = <Color>[
      for (final o in dayOcc)
        if (layerFilter.contains(o.layer) && seenLayers.add(o.layer))
          layerDefFor(o.layer)?.color ?? evColor(o.ev),
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

  Widget _agendaLayerHeader(CalendarLayerDef layer, String date) {
    return Container(
      key: ValueKey('agenda-layer-header-${layer.id}-$date'),
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: layer.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: glyphTile(
              size: 24,
              radius: 8,
              picture: layer.picture,
              emoji: layer.emoji,
              emojiSize: 13,
              fallback: Center(
                child: ic(layer.icon, size: 13, sw: 2.3, color: layer.color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              layer.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: B.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _agendaLayerEmpty(CalendarLayerDef layer, String date) {
    return Container(
      key: ValueKey('agenda-layer-empty-${layer.id}-$date'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: B.faint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: B.line),
      ),
      child: const Text(
        'No events yet',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: B.muted,
        ),
      ),
    );
  }

  /// A single day's occurrences grouped by the enabled calendar layers in
  /// their saved order. Each visible layer renders a header and either its
  /// time-sorted rows or an empty state, while every actual occurrence keeps
  /// the same solid agenda row style regardless of layer.
  Widget _agendaDaySections(String date, List<CalendarOccurrence> dayOcc) {
    final layers = _agendaLayerDefs(dayOcc);
    if (layers.isEmpty) {
      return _emptyState(
        icon: 'cal',
        title: 'No layers enabled',
        sub: 'Turn on a calendar layer to see its agenda.',
        actionLabel: 'Add event',
        onAction: () => openEvent(null),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final layer in layers) ...[
          _agendaLayerHeader(layer, date),
          Builder(
            builder: (context) {
              final rows = dayOcc.where((o) => o.layer == layer.id).toList()
                ..sort(_compareAgendaOccurrences);
              if (rows.isEmpty) return _agendaLayerEmpty(layer, date);
              return Column(
                children: [
                  for (final o in rows) ...[
                    _apptAgendaRow(o),
                    if (o != rows.last) const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  /// Agenda row for ANY occurrence, regardless of layer — a solid block
  /// filled with the resolved event colour, a narrow time column, and a repeat
  /// badge when recurring (`apptRow()` in the design). Colour priority is
  /// category, explicit event colour, then assigned member fallback.
  Widget _apptAgendaRow(
    CalendarOccurrence o, {
    bool popSheetFirst = false,
    String rowKeyPrefix = 'agenda-appt',
    VoidCallback? onToggleDone,
  }) {
    final ev = o.ev;
    final col = evColor(ev);
    final fg = contrastOn(col);
    final cat = catById(ev.category);
    final isTodo = o.isTask;
    final done = o.done;
    return Builder(
      builder: (context) {
        void openTap() {
          if (popSheetFirst) Navigator.of(context).pop();
          openEventView(ev.id, o.date);
        }

        return Opacity(
          opacity: done ? _calendarFadedOpacity : 1,
          child: GestureDetector(
            key: ValueKey('$rowKeyPrefix-${ev.id}-${o.date}'),
            onTap: openTap,
            child: Container(
              key: ValueKey('$rowKeyPrefix-surface-${ev.id}-${o.date}'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: col,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  if (isTodo)
                    GestureDetector(
                      key: ValueKey('event-check-${ev.id}-${o.date}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _toggleOccurrenceDone(o);
                        onToggleDone?.call();
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done ? fg.withValues(alpha: .22) : null,
                          border: Border.all(color: fg, width: 2),
                        ),
                        child: done
                            ? Icon(Icons.check, size: 14, color: fg)
                            : null,
                      ),
                    ),
                  SizedBox(
                    width: 40,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ev.allDay ? 'All' : ev.start,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ).copyWith(color: fg),
                          ),
                          Text(
                            ev.allDay ? 'day' : ev.end,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              height: 1.05,
                              color: fg.withValues(alpha: .75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 11),
                    color: fg.withValues(alpha: .35),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (cat != null) ...[
                              Container(
                                key: ValueKey(
                                  'agenda-title-category-${ev.id}-${o.date}',
                                ),
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.only(right: 7),
                                decoration: BoxDecoration(
                                  color: fg.withValues(alpha: .18),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: fg.withValues(alpha: .28),
                                  ),
                                ),
                                child: Center(
                                  child: categoryGlyph(
                                    cat,
                                    size: 14,
                                    iconColor: fg,
                                  ),
                                ),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                ev.title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: fg,
                                  decoration: done
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (ev.recur != 'none')
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ic('repeat', size: 10, sw: 2.6, color: fg),
                                const SizedBox(width: 3),
                                Text(
                                  'Repeats ${ev.recur}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: fg.withValues(alpha: .85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (ev.attendees.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    KeyedSubtree(
                      key: ValueKey('agenda-attendees-${ev.id}-${o.date}'),
                      child: _attendeeStack(
                        ev.attendees,
                        22,
                        maxShown: ev.attendees.length,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Agenda "To-Dos" row — a white bordered card with a tappable checkbox
  /// (untouched semantics: tapping calls [_toggleOccurrenceDone], which marks
  /// the occurrence done while keeping it visible) and a recurrence badge chip
  /// (`taskRow()` in the design). [checkColor] lets the Kitchen Dashboard fill
  /// the checkbox with the member's colour instead of the to-do layer's accent;
  /// [showAvatar] is turned off there too since each column is already scoped
  /// to one member.
  // ignore: unused_element
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
  // ignore: unused_element
  Widget _contentAgendaRow(
    CalendarOccurrence o, {
    Color? checkColor,
    bool showAvatar = true,
    CalendarLayerDef? layer,
  }) {
    final ev = o.ev;
    final def = layer ?? layerDefFor(o.layer);
    final pink = def?.color ?? const Color(0xffdb2777);
    final accent = checkColor ?? pink;
    return Container(
      key: ValueKey('agenda-content-${ev.id}-${o.date}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      foregroundDecoration: _DashedBoxDecoration(color: pink, radius: 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: pink.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: glyphTile(
              size: 30,
              radius: 10,
              picture: def?.picture,
              emoji: def?.emoji,
              emojiSize: 16,
              fallback: Center(
                child: ic(
                  def?.icon ?? 'camera',
                  size: 15,
                  sw: 2.1,
                  color: pink,
                ),
              ),
            ),
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
                  Text(
                    def?.label ?? 'Content',
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
  Widget _eventCard(
    CalendarOccurrence o, {
    bool popSheetFirst = false,
    VoidCallback? onToggleDone,
  }) => _apptAgendaRow(
    o,
    popSheetFirst: popSheetFirst,
    rowKeyPrefix: 'event',
    onToggleDone: onToggleDone,
  );

  /// A small overlapping avatar stack for event attendees, mirroring the
  /// design's `mStack()`. Calendar-only (Lists never needed multi-avatar
  /// overlap since tasks have a single assignee).
  Widget _attendeeStack(List<String> memberIds, double size, {int? maxShown}) {
    final shown = memberIds.take(maxShown ?? 3).toList();
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
