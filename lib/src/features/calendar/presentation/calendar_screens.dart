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
    Widget body = switch (calView) {
      'week' => _calWeek(),
      'family' => _calFamily(),
      'agenda' => _calAgenda(),
      _ => _calMonth(),
    };
    // Month view navigates vertically (prev/next month); Week/Family
    // navigate horizontally (prev/next week); Agenda has no gesture nav.
    if (calView == 'month') {
      body = GestureDetector(
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 200) calStep(v < 0 ? 1 : -1);
        },
        child: body,
      );
    } else if (calView == 'week' || calView == 'family') {
      body = GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 200) calStep(v < 0 ? 1 : -1);
        },
        child: body,
      );
    }
    return body;
  }

  // -------------------------------------------------------------- month
  Widget _calMonth() {
    final grid = monthGrid(calAnchor);
    final curMonth = _parseIso(calAnchor).month;
    final today = todayIso();
    const headerBorderColor = Color(0xffd5dce8);
    const fadedEventOpacity = .45;

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
        final category = catById(o.ev.category);
        final left = o.date.compareTo(ws) < 0;
        final right = o.spanEnd.compareTo(we) > 0;
        final label = (o.isMultiDay && left) ? '‹ ${o.ev.title}' : o.ev.title;
        return GestureDetector(
          key: ValueKey('cal-bar-${o.ev.id}-$wi-$cs'),
          onTap: () => openEventView(o.ev.id, o.date),
          child: Opacity(
            opacity: faded ? fadedEventOpacity : 1,
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
                    categoryGlyph(category, size: 10, iconColor: Colors.white),
                    const SizedBox(width: 3),
                  ] else if (!o.isMultiDay)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                        color: Colors.white,
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
              child: bar(
                o,
                c,
                c + span - 1,
                faded: !startInCurrentMonth,
              ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight - 12
            : 640.0;
        return Container(
          height: height.clamp(360.0, double.infinity).toDouble(),
          margin: const EdgeInsets.only(top: 12),
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
                            left: dayIndex == 0
                                ? BorderSide.none
                                : const BorderSide(color: B.line),
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
              for (var wi = 0; wi < weeks.length; wi++)
                Expanded(child: weekRow(weeks[wi], wi)),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------- week
  Widget _calWeek() {
    const visibleHours = 8.0, gutter = 42.0;
    final ws = _startOfWeekIso(calAnchor);
    final days = [for (var i = 0; i < 7; i++) _addDaysIso(ws, i)];
    final today = todayIso();
    final now = DateTime.now();
    final dayHead = Row(
      children: [
        SizedBox(width: gutter),
        for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: dayIndex == 0
                      ? BorderSide.none
                      : const BorderSide(color: B.line),
                ),
              ),
              child: Builder(
                builder: (_) {
                  final d = _parseIso(days[dayIndex]);
                  final isToday = days[dayIndex] == today;
                  return Column(
                    children: [
                      Text(
                        kWeekdayLetters[d.weekday - 1],
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isToday ? B.primary : B.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        margin: const EdgeInsets.only(top: 1),
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
                    ],
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
        SizedBox(width: gutter),
        for (var dayIndex = 0; dayIndex < allDayByDay.length; dayIndex++)
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 24),
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
                                iconColor: Colors.white,
                              ),
                              const SizedBox(width: 3),
                            ],
                            Flexible(
                              child: Text(
                                o.ev.title,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
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
      return Expanded(
        child: Container(
          key: ValueKey('cal-week-day-col-$iso'),
          decoration: BoxDecoration(
            color: isToday ? const Color(0xfff0fbfa) : Colors.transparent,
            border: Border(
              left: dayIndex == 0
                  ? BorderSide.none
                  : const BorderSide(color: B.line),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final colW = constraints.maxWidth;
              return Stack(
                children: [
                  for (final item in laid)
                    Builder(
                      builder: (_) {
                        final o = item.o;
                        final col = evColor(o.ev);
                        final top = _toMinutes(o.ev.start) / 60 * rowH;
                        final endMin = _toMinutes(
                          o.ev.end.isNotEmpty ? o.ev.end : o.ev.start,
                        );
                        final h =
                            ((endMin - _toMinutes(o.ev.start)) / 60 * rowH)
                                .clamp(20.0, gridH);
                        final w = colW / item.cols;
                        return Positioned(
                          top: top,
                          height: h,
                          left: item.col * w,
                          width: w,
                          child: GestureDetector(
                            key: ValueKey('cal-timed-${o.ev.id}'),
                            onTap: () => openEventView(o.ev.id, o.date),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      if (catById(o.ev.category)
                                          case final cat?) ...[
                                        categoryGlyph(
                                          cat,
                                          size: 10,
                                          iconColor: Colors.white,
                                        ),
                                        const SizedBox(width: 3),
                                      ],
                                      Flexible(
                                        child: Text(
                                          o.ev.title,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (h > 30)
                                    Text(
                                      o.ev.start,
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
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
                      child: Container(
                        height: 2,
                        color: const Color(0xffe11d48),
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

    return Column(
      children: [
        dayHead,
        Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: B.faint),
              bottom: BorderSide(color: B.line),
            ),
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
                  final target = ((currentHour - visibleHours / 2) * rowH)
                      .clamp(0.0, gridH - viewportHeight);
                  controller.jumpTo(target);
                });
              }
              return SingleChildScrollView(
                key: const ValueKey('cal-timeline-week'),
                controller: controller,
                child: SizedBox(
                  key: const ValueKey('cal-hour-grid-week'),
                  height: gridH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: gutter,
                        height: gridH,
                        child: Stack(
                          children: [
                            for (var i = 0; i < hours.length; i++)
                              Positioned(
                                top: i * rowH + 2,
                                right: 6,
                                child: Text(
                                  '${hours[i].toString().padLeft(2, '0')}:00',
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
                      Expanded(
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
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- family
  Widget _calFamily() {
    final ws = _startOfWeekIso(calAnchor);
    final days = [for (var i = 0; i < 7; i++) _addDaysIso(ws, i)];
    final today = todayIso();
    final members = curFamily()?.members ?? const <FamilyMember>[];
    final pinnedByDay = [
      for (final iso in days)
        eventOccurrences(
          iso,
          iso,
        ).where((o) => o.isMultiDay && o.ev.attendees.isNotEmpty).toList(),
    ];

    Widget head() {
      return Row(
        children: [
          const SizedBox(
            width: 84,
            child: Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'MEMBER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: B.muted,
                ),
              ),
            ),
          ),
          for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: B.line)),
                ),
                child: Builder(
                  builder: (_) {
                    final d = _parseIso(days[dayIndex]);
                    final isToday = days[dayIndex] == today;
                    return Column(
                      children: [
                        Text(
                          kWeekdayLetters[d.weekday - 1],
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: isToday ? B.primary : B.muted,
                          ),
                        ),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isToday ? B.primary : B.ink,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      );
    }

    Widget pinnedStrip() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 84),
          for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: B.line)),
                ),
                child: Column(
                  children: [
                    for (final o in pinnedByDay[dayIndex].take(3))
                      GestureDetector(
                        key: ValueKey(
                          'cal-family-pinned-${o.ev.id}-${days[dayIndex]}',
                        ),
                        onTap: () => openEventView(o.ev.id, o.date),
                        child: Container(
                          width: double.infinity,
                          height: 14,
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: evColor(o.ev),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              if (catById(o.ev.category)
                                  case final category?) ...[
                                categoryGlyph(
                                  category,
                                  size: 9,
                                  iconColor: Colors.white,
                                ),
                                const SizedBox(width: 2),
                              ],
                              Flexible(
                                child: Text(
                                  o.ev.title,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
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
            SizedBox(
              width: 84,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    _memberAvatar(m.id, size: 24),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        m.name,
                        overflow: TextOverflow.ellipsis,
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
            ),
            for (final iso in days)
              Expanded(
                child: Builder(
                  builder: (_) {
                    final evs =
                        eventOccurrences(iso, iso)
                            .where(
                              (o) =>
                                  !o.isMultiDay &&
                                  o.ev.attendees.contains(m.id),
                            )
                            .toList()
                          ..sort(
                            (a, b) => (a.ev.allDay ? '' : a.ev.start).compareTo(
                              b.ev.allDay ? '' : b.ev.start,
                            ),
                          );
                    return Container(
                      key: ValueKey('cal-family-cell-${m.id}-$iso'),
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        border: const Border(left: BorderSide(color: B.line)),
                        color: iso == today ? const Color(0xfff0fbfa) : null,
                      ),
                      child: Column(
                        children: [
                          for (final o in evs.take(3))
                            GestureDetector(
                              key: ValueKey('cal-family-${m.id}-${o.ev.id}'),
                              onTap: () => openEventView(o.ev.id, o.date),
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
                                        iconColor: Colors.white,
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
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: head(),
          ),
          Container(
            key: const ValueKey('cal-family-pinned-strip'),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: B.faint),
                bottom: BorderSide(color: B.line),
              ),
            ),
            child: pinnedStrip(),
          ),
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
