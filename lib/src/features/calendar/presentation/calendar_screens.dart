part of 'package:family_money_management_app/main.dart';

/// Memo cache for a Month-view page's occurrences: expansion is expensive
/// (recurrence expansion over all events + imported calendars) and would
/// otherwise rerun for every one of the 42 cells on every whole-app
/// rebuild. Keyed by grid start/end, holding the per-day buckets each cell
/// reads. Entries are invalidated by the state revision
/// ([_ThriveHomeState._rev]) and a signature of everything else that affects
/// the result (active filters, family, state instance).
final Map<
  String,
  ({int rev, String sig, Map<String, List<CalendarOccurrence>> byDay})
>
_calWeekMemo = {};

/// Birthday kind palette (design §3a) — cream fill, amber rule, amber-brown
/// ink. Shared by every surface so a birthday looks identical everywhere.
const Color kBirthdayCream = Color(0xfffdf1d8);
const Color kBirthdayAmber = Color(0xffd97706);
const Color kBirthdayInk = Color(0xff92610c);
const Color kBirthdaySubInk = Color(0xffb18a45);

/// Imported-feed stripes — "not ours": read-only, tap opens details. The
/// stripes take the event's OWN colour, which for an imported feed is its
/// assigned category's (see `importedSyntheticEvent`), so a feed reads as its
/// category everywhere; it's the stripe pattern, not a grey, that says
/// read-only. Feeds with no category keep falling back to the feed's colour.
ImportedStripes importedStripes(Color base) => ImportedStripes(base);

/// A repeating 45° hatch, the design's mark for "imported, read-only".
///
/// It can't be a plain [LinearGradient]: `begin`/`end` are fractions of the
/// painted box, so a repeated gradient across topLeft→bottomRight covers the
/// box exactly once and paints two halves instead of stripes. This builds the
/// shader itself over a fixed [pitch] in logical pixels, so the hatch reads
/// the same on a 15px month bar and a 56px agenda row.
@immutable
class ImportedStripes extends Gradient {
  ImportedStripes(this.base, {this.pitch = 7})
    : super(colors: [base, base, _stripeLift(base), _stripeLift(base)]);

  final Color base;

  /// Logical pixels covered by one dark+light stripe pair.
  final double pitch;

  static const List<double> _stops = [0.0, 0.5, 0.5, 1.0];

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    // A 45° band: stepping `pitch / sqrt2` on both axes advances exactly
    // `pitch` along the stripe normal.
    final step = pitch / math.sqrt2;
    return ui.Gradient.linear(
      rect.topLeft,
      rect.topLeft + Offset(step, step),
      colors,
      _stops,
      TileMode.repeated,
    );
  }

  @override
  ImportedStripes scale(double factor) =>
      ImportedStripes(Color.lerp(null, base, factor)!, pitch: pitch);

  @override
  ImportedStripes withOpacity(double opacity) =>
      ImportedStripes(base.withValues(alpha: opacity), pitch: pitch);

  @override
  bool operator ==(Object other) =>
      other is ImportedStripes && other.base == base && other.pitch == pitch;

  @override
  int get hashCode => Object.hash(base, pitch);
}

/// The second stripe tone: a step towards white on dark colours, towards
/// black on light ones, so the stripes stay visible whatever the category is.
Color _stripeLift(Color base) => Color.lerp(
  base,
  contrastOn(base) == Colors.white ? Colors.white : Colors.black,
  .16,
)!;

/// The resolved display anatomy of one occurrence on one day — the single
/// source every calendar surface paints from (epic #343).
class _EvAnatomy {
  const _EvAnatomy({
    required this.kind,
    required this.color,
    required this.category,
    required this.layer,
    required this.title,
    required this.barTitle,
    required this.sub,
    required this.when,
    required this.chip,
    required this.done,
    required this.past,
    required this.recurring,
    required this.multiDay,
  });

  final CalEventKind kind;
  final Color color;
  final EventCategory? category;
  final CalendarLayerDef? layer;

  /// Title with its ↻ / ⇩ affixes already applied, in that order.
  final String title;

  /// The title WITHOUT the ↻ recurrence mark (⇩ stays — read-only is worth
  /// the character). Month bars use this: they lead with the event's category
  /// glyph instead, which says more in the same space than a repeat mark
  /// repeated on every occurrence.
  final String barTitle;

  /// `when · Category (· read-only)`.
  final String sub;
  final String when;

  /// The compact time-chip text used by kitchen pills.
  final String chip;
  final bool done;
  final bool past;
  final bool recurring;
  final bool multiDay;

  /// The month-cell bar label: prefixes, then the title. The category glyph
  /// is a widget, not text, so [_ThriveCalendarScreens._calMonthBar] draws it
  /// ahead of this.
  String get barLabel {
    final buf = StringBuffer();
    if (kind == CalEventKind.todo) buf.write('▢ ');
    buf.write(barTitle);
    return buf.toString();
  }
}

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

  /// The calendar header's right-hand controls (design §2a): three inline
  /// view buttons — month / agenda / kitchen — and the funnel filter
  /// button. There is no second toolbar and no view-picker sheet: the three
  /// buttons ARE the switcher.
  Widget _calHeaderActions() {
    final filtersOn = calFiltersActive();

    Widget squareBtn({
      required Key key,
      required Widget child,
      required VoidCallback onTap,
      required bool active,
      bool dimmed = false,
      bool ringTeal = false,
      bool dot = false,
    }) {
      return GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active
                ? B.ink
                : ringTeal
                ? B.soft
                : Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: active
                ? null
                : Border.all(
                    color: ringTeal ? B.primary : const Color(0xffdde3ea),
                    width: ringTeal ? 1.5 : 1,
                  ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Opacity(opacity: dimmed ? .5 : 1, child: child),
              ),
              if (dot)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: B.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget viewBtn(String value, String icon) {
      final active = calView == value;
      return squareBtn(
        key: ValueKey('cal-view-$value'),
        active: active,
        onTap: () => setCalView(value),
        child: ic(
          icon,
          size: 16,
          sw: 2.2,
          color: active ? Colors.white : B.soft2,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _deviceCalendarSavingIndicator(),
        for (final (value, _, icon) in kCalViews) viewBtn(value, icon),
        // The kitchen wall is a full-screen route, not a `calView` — the
        // chef button is greyed while the wall is switched off, and tapping
        // it then re-enables it (as the old picker sheet row did).
        squareBtn(
          key: const ValueKey('cal-view-kitchen'),
          active: false,
          dimmed: !kitchenEnabled,
          onTap: () {
            if (kitchenEnabled) {
              openKitchenDashboard();
            } else {
              toggleKitchenEnabled();
            }
          },
          child: ic('columns', size: 16, sw: 2.2, color: B.soft2),
        ),
        squareBtn(
          key: const ValueKey('cal-header-filter'),
          active: false,
          ringTeal: filtersOn,
          dot: filtersOn,
          onTap: openCalFilterSheet,
          child: ic(
            'funnel',
            size: 15,
            sw: 2.6,
            color: filtersOn ? B.deep : B.soft2,
          ),
        ),
      ],
    );
  }

  Widget _deviceCalendarSavingIndicator() {
    return SizedBox(
      width: 30,
      height: 38,
      child: ValueListenableBuilder<bool>(
        valueListenable: DeviceCalendarSync.instance.saving,
        builder: (context, saving, _) {
          if (!saving) return const SizedBox.shrink();
          return Semantics(
            label: 'Saving calendar',
            child: Container(
              key: const ValueKey('device-calendar-saving'),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: B.line),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: B.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
          // Selection resets on month travel: today for the current month,
          // the 1st otherwise (design §2a state model).
          final landing = _calLandingDay(nextAnchor);
          calSel = landing;
          agendaDay = landing;
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
  /// Cell-stack order inside a month day (design `onDayM`): birthdays
  /// first, then all-day/multi-day banners, then timed events, then to-dos.
  static int _monthCellRank(CalendarOccurrence o) {
    if (o.isBirthday) return 0;
    if (o.ev.allDay || o.isMultiDay) return 1;
    if (o.isTask) return 3;
    return 2;
  }

  static int _compareMonthCell(CalendarOccurrence a, CalendarOccurrence b) {
    final rank = _monthCellRank(a).compareTo(_monthCellRank(b));
    if (rank != 0) return rank;
    final time = (a.ev.allDay ? '' : a.ev.start).compareTo(
      b.ev.allDay ? '' : b.ev.start,
    );
    if (time != 0) return time;
    return a.ev.title.compareTo(b.ev.title);
  }

  /// Reorders [bars] so that, when only [maxBars] of them fit, the ones whose
  /// time has already passed are the ones dropped. Timed occurrences starting
  /// before the current clock time are demoted behind everything else; the
  /// kept set is then put back in its original (start-time) order so the cell
  /// still reads chronologically. All-day/untimed bars are never demoted —
  /// they have no hour to be past.
  static List<CalendarOccurrence> _monthBarsPreferUpcoming(
    List<CalendarOccurrence> bars,
    int maxBars,
  ) {
    if (bars.length <= maxBars) return bars;
    final now = debugNowOverride?.call() ?? DateTime.now();
    final nowHm =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    bool isPast(CalendarOccurrence o) =>
        !o.ev.allDay &&
        o.ev.start.isNotEmpty &&
        o.ev.start.compareTo(nowHm) < 0;
    final upcoming = [
      for (final o in bars)
        if (!isPast(o)) o,
    ];
    if (upcoming.isEmpty || upcoming.length >= bars.length) return bars;
    final shownUpcoming = upcoming.take(maxBars).toList();
    // Any slot the upcoming events leave over goes to the most recent past
    // ones — the 11:00 that just finished beats the 08:00 nobody cares about.
    final past = [
      for (final o in bars.reversed)
        if (isPast(o)) o,
    ];
    final kept = {
      ...shownUpcoming,
      ...past.take(maxBars - shownUpcoming.length),
    };
    return [
      for (final o in bars)
        if (kept.contains(o)) o,
    ];
  }

  /// Every occurrence touching a month page's 42-day grid, bucketed by the
  /// ISO day it should paint on — a multi-day run appears in every cell it
  /// crosses so each cell can draw its own segment of the continuous
  /// ribbon. Memoised per grid (see [_calWeekMemo]).
  Map<String, List<CalendarOccurrence>> _monthOccurrencesByDay(
    List<String> grid,
  ) {
    final ws = grid.first;
    final we = grid.last;
    final sig =
        '${identityHashCode(this)}|$familyId'
        '|${calFilter.join(',')}|${calCatFilter.join(',')}'
        '|${layerFilter.join(',')}';
    final key = '$ws|$we';
    var memo = _calWeekMemo[key];
    if (memo == null || memo.rev != _rev.value || memo.sig != sig) {
      if (_calWeekMemo.length > 24) _calWeekMemo.clear();
      final byDay = <String, List<CalendarOccurrence>>{};
      for (final o in eventOccurrences(ws, we)) {
        var d = o.date.compareTo(ws) < 0 ? ws : o.date;
        final end = o.spanEnd.compareTo(we) > 0 ? we : o.spanEnd;
        while (d.compareTo(end) <= 0) {
          (byDay[d] ??= <CalendarOccurrence>[]).add(o);
          d = _addDaysIso(d, 1);
        }
      }
      for (final list in byDay.values) {
        list.sort(_compareMonthCell);
      }
      memo = (rev: _rev.value, sig: sig, byDay: byDay);
      _calWeekMemo[key] = memo;
    }
    return memo.byDay;
  }

  /// A past month is view-only (design §2a) — its day sheets lose the add
  /// button and the header carries the amber PAST pill.
  bool _calMonthIsPast(String anchor) {
    final d = _parseIso(anchor);
    final now = _parseIso(todayIso());
    return d.year < now.year || (d.year == now.year && d.month < now.month);
  }

  /// Where selection lands after travelling to [anchor]'s month: today when
  /// it IS the current month, otherwise the 1st (design `gPrev`/`gNext`).
  String _calLandingDay(String anchor) {
    final d = _parseIso(anchor);
    final now = _parseIso(todayIso());
    if (d.year == now.year && d.month == now.month) return todayIso();
    return _isoOf(d.year, d.month, 1);
  }

  Widget _calMonth(String anchor) {
    final grid = monthGrid(anchor);
    final curMonth = _parseIso(anchor).month;
    final today = todayIso();
    final byDay = _monthOccurrencesByDay(grid);
    final holidays = holidayDatesBetween(grid.first, grid.last);
    final weeks = [for (var w = 0; w < 6; w++) grid.sublist(w * 7, w * 7 + 7)];

    return Column(
      children: [
        for (var wi = 0; wi < weeks.length; wi++)
          Expanded(
            child: Row(
              children: [
                for (final iso in weeks[wi])
                  Expanded(
                    child: _calMonthCell(
                      iso,
                      curMonth: curMonth,
                      today: today,
                      holiday: holidays.contains(iso),
                      occ: byDay[iso] ?? const <CalendarOccurrence>[],
                    ),
                  ),
              ],
            ),
          ),
        // Month travel is swipe-only — there are deliberately no ‹ › arrows
        // and no Today button in the header (design §2a).
        const Padding(
          key: ValueKey('cal-swipe-hint'),
          padding: EdgeInsets.fromLTRB(0, 5, 0, 4),
          child: Text(
            '‹ swipe to change month ›',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xffb3bcc9),
            ),
          ),
        ),
      ],
    );
  }

  // Measured heights of the pieces a month cell stacks. Each is the widget's
  // own laid-out height (text line + padding + margin), rounded UP where the
  // variants differ, so the fill maths can only ever under-fill — never
  // overflow the cell.
  static const double _kMonthDayNumberH = 24; // 19 dot + 3/2 padding
  static const double _kMonthBarH = 15.2; // 9.2 line + 4 padding + 2 margin
  static const double _kMonthMoreH = 11; // the "+N more" line

  /// The laid-out height of [o]'s banner — the three variants pad differently.
  double _monthBannerHeight(CalendarOccurrence o, String iso) {
    final a = _evAnatomy(o, iso);
    if (a.kind == CalEventKind.birthday) return 15.2; // 9.2 + 2 pad + 4 margin
    if (a.multiDay) return 17.2; // 9.2 + 4 pad + 4 margin
    return 18.2; // 9.2 + 5 pad + 2 top rule + 2 margin
  }

  /// One month day cell: tinted background, the day number, up to two
  /// per-kind bars, "+N more", and an optional bottom banner.
  Widget _calMonthCell(
    String iso, {
    required int curMonth,
    required String today,
    required bool holiday,
    required List<CalendarOccurrence> occ,
  }) {
    final d = _parseIso(iso);
    final ghost = d.month != curMonth;
    final isToday = iso == today;
    final past = !isToday && iso.compareTo(today) < 0;
    // A day off is a day off: a holidays feed's days wear the same warm tint
    // as Saturday and Sunday (#: holidays calendar).
    final weekend = d.weekday >= 6 || holiday;
    final fade = ghost ? .3 : (past ? _calendarFadedOpacity : 1.0);

    // A to-do is always a bar, never a banner — its dotted outline and ▢ are
    // the point, and app to-dos are all-day by nature (design §3a).
    final banners = [
      for (final o in occ)
        if (o.kind != CalEventKind.todo &&
            (o.isBirthday || o.ev.allDay || o.isMultiDay))
          o,
    ];
    final banner = banners.isEmpty ? null : banners.first;
    final bars = [
      for (final o in occ)
        if (o != banner && !banners.contains(o)) o,
    ];

    final bg = ghost
        ? const Color(0xfff7f9fb)
        : past
        ? const Color(0xffe9edf1)
        : isToday
        ? const Color(0xffd7efeb)
        : weekend
        ? const Color(0xfffaf0d6)
        : const Color(0xffe7f5f3);
    final border = isToday
        ? B.primary
        : ghost
        ? const Color(0xffeef1f5)
        : past
        ? const Color(0xffdfe3e8)
        : weekend
        ? const Color(0xffefe3c2)
        : const Color(0xffcfe8e4);

    return GestureDetector(
      key: ValueKey('cal-day-bg-$iso'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Tapping a ghost day travels to its month first, then opens it
        // (design §2a) — it used to open the sheet without travelling.
        if (ghost) update(() => calAnchor = iso);
        setCalSel(iso);
        openDayDetail(iso);
      },
      child: Opacity(
        opacity: ghost ? .75 : 1,
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: isToday ? 1.5 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          // How many bars fit isn't a fixed number: a tall phone's cell holds
          // more rows than a short one's, so the cell measures itself and
          // fills the space it actually has (never past it — an overflowing
          // Column would throw).
          child: LayoutBuilder(
            builder: (context, c) {
              final room =
                  c.maxHeight -
                  _kMonthDayNumberH -
                  (banner == null ? 0 : _monthBannerHeight(banner, iso));
              int fits(double reserve) {
                final usable = room - reserve;
                if (usable < _kMonthBarH) return 0;
                return (usable / _kMonthBarH).floor();
              }

              final hiddenBanners = banners.length - (banner == null ? 0 : 1);
              var shownBars = bars.take(fits(0)).toList();
              var more = hiddenBanners + bars.length - shownBars.length;
              // Only give up a row to "+N more" when something is actually
              // hidden — and re-measure, since that row may cost a bar.
              if (more > 0) {
                shownBars = bars.take(fits(_kMonthMoreH)).toList();
                more = hiddenBanners + bars.length - shownBars.length;
              }
              // `bars` is already in start-time order (_compareMonthCell). When
              // they don't all fit, today's cell sheds the ones whose hour has
              // already gone before it sheds what's still coming — a 09:00
              // that's over is worth less than an 18:00 that isn't.
              if (isToday && shownBars.length < bars.length) {
                shownBars = _monthBarsPreferUpcoming(
                  bars,
                  shownBars.length,
                ).take(shownBars.length).toList();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _calDayNumber(
                    iso,
                    d.day,
                    isToday: isToday,
                    ghost: ghost,
                    past: past,
                  ),
                  if (banner != null)
                    Opacity(opacity: fade, child: _calMonthBanner(banner, iso)),
                  for (final o in shownBars)
                    Opacity(opacity: fade, child: _calMonthBar(o, iso)),
                  if (more > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Text(
                        '+$more more',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: B.muted,
                        ),
                      ),
                    ),
                  const Spacer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _calDayNumber(
    String iso,
    int day, {
    required bool isToday,
    required bool ghost,
    required bool past,
  }) {
    return Container(
      key: ValueKey('cal-day-$iso'),
      alignment: Alignment.center,
      padding: const EdgeInsets.only(top: 3, bottom: 2),
      child: Container(
        width: 19,
        height: 19,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isToday ? B.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isToday
                ? Colors.white
                : ghost
                ? const Color(0xffc3ccd6)
                : past
                ? const Color(0xffb3bcc9)
                : B.text,
          ),
        ),
      ),
    );
  }

  /// A single timed/to-do/imported bar inside a month cell (design §3a).
  Widget _calMonthBar(CalendarOccurrence o, String iso) {
    final a = _evAnatomy(o, iso);
    final isTodo = a.kind == CalEventKind.todo;
    final isImported = a.kind == CalEventKind.imported;
    // Imported bars are no longer a fixed dark grey, so the ink has to follow
    // whatever the category colour is rather than assuming white reads on it.
    final ink = isTodo ? a.color : contrastOn(a.color);
    return Container(
      key: ValueKey('cal-bar-${o.ev.id}-$iso'),
      margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
      padding: EdgeInsets.symmetric(horizontal: 3, vertical: isTodo ? 1 : 2),
      decoration: BoxDecoration(
        color: isTodo
            ? Colors.white
            : isImported
            ? null
            : a.color,
        gradient: isImported ? importedStripes(a.color) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      foregroundDecoration: isTodo
          ? _DottedBoxDecoration(color: a.color, radius: 4, width: 1.5)
          : null,
      // A categorised event leads with its category's glyph — the one mark on
      // the bar that says what the event IS. It replaces the ↻ that used to
      // prefix every single recurring occurrence.
      child: _monthLabel(
        a.barLabel,
        category: a.category,
        ink: ink,
        strike: a.done,
      ),
    );
  }

  /// The cell's bottom banner: a birthday ribbon, a continuous multi-day
  /// ribbon (rounded only at the real run ends, flush mid-run so adjacent
  /// cells touch), or an all-day strip with a top rule in its colour.
  Widget _calMonthBanner(CalendarOccurrence o, String iso) {
    final a = _evAnatomy(o, iso);
    if (a.kind == CalEventKind.birthday) {
      return Container(
        key: ValueKey('cal-banner-${o.ev.id}-$iso'),
        margin: const EdgeInsets.fromLTRB(2, 2, 2, 2),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: kBirthdayCream,
          border: Border.all(color: kBirthdayAmber.withValues(alpha: .33)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '\u{1F382} ${a.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 8,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: kBirthdayInk,
          ),
        ),
      );
    }
    if (a.multiDay) {
      final runStart = o.date == iso;
      final runEnd = o.spanEnd == iso;
      final fg = contrastOn(a.color);
      return Container(
        key: ValueKey('cal-banner-${o.ev.id}-$iso'),
        margin: EdgeInsets.fromLTRB(runStart ? 2 : 0, 2, runEnd ? 2 : 0, 2),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: a.color,
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(runStart ? 4 : 0),
            right: Radius.circular(runEnd ? 4 : 0),
          ),
        ),
        // The title paints once, on the run's first visible day; the rest
        // of the ribbon stays blank so it reads as one continuous strip.
        child: _monthLabel(
          runStart ? a.barTitle : ' ',
          category: runStart ? a.category : null,
          ink: fg,
        ),
      );
    }
    return Container(
      key: ValueKey('cal-banner-${o.ev.id}-$iso'),
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(3, 2, 3, 3),
      decoration: BoxDecoration(
        color: a.color.withValues(alpha: .15),
        border: Border(top: BorderSide(color: a.color, width: 2)),
      ),
      child: _monthLabel(
        a.barTitle,
        category: a.category,
        ink: a.color,
        strike: a.done,
      ),
    );
  }

  /// The label every month bar/banner paints: the event's category glyph (when
  /// it has one) hard against the name, then the name itself. The glyph is
  /// exactly one text line tall, so adding it never changes a row's height —
  /// see the `_kMonth*H` constants the cell fills against.
  Widget _monthLabel(
    String text, {
    required EventCategory? category,
    required Color ink,
    bool strike = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (category != null) ...[
          categoryGlyph(category, size: 9.2, iconColor: ink),
          const SizedBox(width: 2),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 8,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: ink,
              decoration: strike
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- agenda
  /// Agenda mode (design §2a): a week strip clamped to the shown month,
  /// then the selected day's events grouped under fixed-order section
  /// headers. Horizontal swipe changes the MONTH, not the week.
  Widget _calAgenda() {
    final today = todayIso();
    final dayOcc = eventOccurrences(agendaDay, agendaDay)
      ..sort(_compareAgendaOccurrences);
    final count = dayOcc.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _weekStripPager(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          agendaDay == today
                              ? 'Today · ${_agendaHeadingIso(agendaDay)}'
                              : _agendaHeadingIso(agendaDay),
                          key: const ValueKey('cal-agenda-day-heading'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: B.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        count == 0 ? '' : '$count event${count > 1 ? 's' : ''}',
                        key: const ValueKey('cal-agenda-day-count'),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: B.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                _agendaDaySections(agendaDay, dayOcc),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '‹ swipe to change month ›',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xffb3bcc9),
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

  int _compareAgendaOccurrences(CalendarOccurrence a, CalendarOccurrence b) {
    final time = (a.ev.allDay ? '' : a.ev.start).compareTo(
      b.ev.allDay ? '' : b.ev.start,
    );
    if (time != 0) return time;
    return a.ev.title.compareTo(b.ev.title);
  }

  /// Mon-Sun day-picker strip for the week containing [agendaDay],
  /// **clamped to that day's month** — days belonging to a neighbouring
  /// month render as empty slots rather than travelling by week. A single
  /// teal dot marks a day with any event under the current filters.
  /// Swiping the strip pages by MONTH (design §2a).
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
          final nextAnchor = _addMonthsIso(agendaDay, offset);
          if (calWeekPageController.hasClients) {
            calWeekPageController.jumpToPage(_calendarPageCenter);
          }
          update(() {
            final landing = _calLandingDay(nextAnchor);
            calAnchor = landing;
            agendaDay = landing;
            calSel = landing;
          });
        },
        itemBuilder: (context, index) {
          final offset = index - _calendarPageCenter;
          final day = offset == 0
              ? agendaDay
              : _calLandingDay(_addMonthsIso(agendaDay, offset));
          return _weekStrip(_startOfWeekIso(day), day);
        },
      ),
    );
  }

  Widget _weekStrip(String weekStart, String anchorDay) {
    final today = todayIso();
    final month = _parseIso(anchorDay).month;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i != 0) const SizedBox(width: 6),
            Expanded(
              child: Builder(
                builder: (_) {
                  final iso = _addDaysIso(weekStart, i);
                  // Clamped: the strip never shows a neighbouring month's
                  // days, so swiping can only mean "change month".
                  if (_parseIso(iso).month != month) {
                    return const SizedBox(height: 60);
                  }
                  return _weekStripCell(iso, i, today);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weekStripCell(String iso, int weekdayIdx, String today) {
    final selected = iso == agendaDay;
    final isToday = iso == today;
    final past = iso.compareTo(today) < 0;
    final d = _parseIso(iso);
    final hasEvents = eventOccurrences(iso, iso).isNotEmpty;
    final ink = selected
        ? B.deep
        : past
        ? const Color(0xffb3bcc9)
        : B.text;
    return GestureDetector(
      key: ValueKey('cal-week-strip-$iso'),
      onTap: () => update(() {
        agendaDay = iso;
        calSel = iso;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffe7f5f3) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kWeekdayLetters[weekdayIdx],
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: ink.withValues(alpha: .7),
              ),
            ),
            const SizedBox(height: 2),
            Container(
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
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isToday ? Colors.white : ink,
                ),
              ),
            ),
            const SizedBox(height: 3),
            // One teal dot for "this day has something", not one dot per
            // layer in layer colours (design §2a).
            SizedBox(
              height: 5,
              child: hasEvents
                  ? Container(
                      key: ValueKey('cal-week-strip-dot-$iso'),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: selected ? B.deep : B.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// The agenda's section headers, in one fixed order for every day
  /// (design §2a): the layers and their categories first, then Birthdays,
  /// then Imported.
  List<({String id, String keyId, String label, Color color, Widget swatch})>
  _agendaSectionOrder() {
    final layers = calendarLayers.isEmpty
        ? kDefaultCalendarLayers()
        : calendarLayers;
    final out =
        <
          ({String id, String keyId, String label, Color color, Widget swatch})
        >[];
    Widget swatchFor(Color color, Widget child) => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Center(child: child),
    );
    final birthdays = (
      id: 'kind:birthday',
      keyId: 'birthday',
      label: 'Birthdays',
      color: kBirthdayAmber,
      swatch: swatchFor(
        kBirthdayAmber,
        const Text('\u{1F382}', style: TextStyle(fontSize: 11)),
      ),
    );
    for (final layer in layers) {
      if (!layerFilter.contains(layer.id)) continue;
      // Design order is "… Family, Birthdays, To-Dos, Imported": birthdays
      // land just before the to-do layer, or at the end if there isn't one.
      if (layer.id == kLayerTask) out.add(birthdays);
      out.add((
        id: 'layer:${layer.id}',
        keyId: layer.id,
        label: layer.label,
        color: layer.color,
        swatch: swatchFor(
          layer.color,
          glyphTile(
            size: 13,
            radius: 4,
            picture: layer.picture,
            emoji: layer.emoji,
            emojiSize: 11,
            fallback: ic(layer.icon, size: 11, sw: 2.3, color: layer.color),
          ),
        ),
      ));
      for (final c in eventCategories) {
        if (c.layerId != layer.id) continue;
        out.add((
          id: 'cat:${c.id}',
          keyId: c.id,
          label: c.name,
          color: c.color,
          swatch: swatchFor(
            c.color,
            categoryGlyph(c, size: 12, iconColor: c.color),
          ),
        ));
      }
    }
    if (!out.contains(birthdays)) out.add(birthdays);
    out.add((
      id: 'kind:imported',
      keyId: 'imported',
      label: 'Imported',
      color: B.soft2,
      swatch: swatchFor(
        B.soft2,
        const Text(
          '\u21E9',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: B.soft2,
          ),
        ),
      ),
    ));
    return out;
  }

  /// Which section an occurrence belongs to — kind wins over layer so a
  /// birthday, a to-do and an imported event always land in their own
  /// section whatever layer they were filed under.
  String _agendaSectionIdFor(CalendarOccurrence o) {
    switch (o.kind) {
      case CalEventKind.birthday:
        return 'kind:birthday';
      case CalEventKind.imported:
        return 'kind:imported';
      case CalEventKind.todo:
      case CalEventKind.appointment:
        return o.ev.category != null
            ? 'cat:${o.ev.category}'
            : 'layer:${o.layer}';
    }
  }

  Widget _agendaSectionHeader(
    ({String id, String keyId, String label, Color color, Widget swatch}) sec,
    String date,
  ) {
    return Container(
      key: ValueKey('agenda-layer-header-${sec.keyId}-$date'),
      padding: const EdgeInsets.only(top: 12, bottom: 7),
      child: Row(
        children: [
          sec.swatch,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sec.label,
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

  /// A single day's occurrences under fixed-order section headers. Sections
  /// with nothing in them are simply not shown; a day with nothing at all
  /// gets the calm empty copy.
  Widget _agendaDaySections(String date, List<CalendarOccurrence> dayOcc) {
    if (dayOcc.isEmpty) {
      return Padding(
        key: const ValueKey('cal-agenda-empty'),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            layerFilter.isEmpty
                ? 'No layers enabled — turn one on to see its agenda.'
                : 'Nothing scheduled — enjoy the calm.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: B.muted,
            ),
          ),
        ),
      );
    }
    final grouped = <String, List<CalendarOccurrence>>{};
    for (final o in dayOcc) {
      (grouped[_agendaSectionIdFor(o)] ??= <CalendarOccurrence>[]).add(o);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final sec in _agendaSectionOrder())
          if (grouped[sec.id] case final rows? when rows.isNotEmpty) ...[
            _agendaSectionHeader(sec, date),
            for (final o in rows) ...[
              _evRowFull(o, iso: date),
              if (o != rows.last) const SizedBox(height: 7),
            ],
          ],
      ],
    );
  }

  // ------------------------------------------------- event display anatomy
  // One rule set for every calendar surface (epic #343, design §3a): the
  // month cell bar, the agenda/day-sheet row and the kitchen pill are three
  // projections of the SAME resolved anatomy — kind, category colour,
  // category icon, recurrence, run length and attendees. No surface may
  // introduce its own colour or wording; add it here instead.

  /// Everything a surface needs to paint [o] on the day [iso].
  _EvAnatomy _evAnatomy(CalendarOccurrence o, String iso) {
    final ev = o.ev;
    final kind = o.kind;
    final col = evColor(ev);
    final cat = catById(ev.category);
    final layer = layerDefFor(o.layer);
    final label = cat?.name ?? layer?.label ?? 'Appointments';
    final recurring = ev.recur != 'none';
    final multi = o.isMultiDay;

    final when = switch (kind) {
      CalEventKind.todo => 'Due this day',
      CalEventKind.birthday => 'Every year',
      _ when multi => 'Day ${o.runIndexOn(iso)} of ${o.runLength}',
      _ when ev.allDay => 'All day',
      _ => ev.start.isEmpty ? 'All day' : ev.start,
    };
    final chip = switch (kind) {
      CalEventKind.todo => 'Due',
      CalEventKind.birthday => 'Yearly',
      _ when multi => '${o.runIndexOn(iso)} / ${o.runLength}',
      _ when ev.allDay => 'All day',
      _ => ev.start.isEmpty ? 'All day' : ev.start,
    };

    final buf = StringBuffer(ev.title);
    if (recurring) buf.write(' ↻');
    if (kind == CalEventKind.imported) buf.write(' ⇩');
    final bare = StringBuffer(ev.title);
    if (kind == CalEventKind.imported) bare.write(' ⇩');

    return _EvAnatomy(
      kind: kind,
      color: col,
      category: cat,
      layer: layer,
      title: buf.toString(),
      barTitle: bare.toString(),
      sub:
          '$when · $label'
          '${kind == CalEventKind.imported ? ' · read-only' : ''}',
      when: when,
      chip: chip,
      done: o.done,
      past: iso.compareTo(todayIso()) < 0,
      recurring: recurring,
      multiDay: multi,
    );
  }

  /// The small square glyph box every full row leads with.
  Widget _evIconBox(
    _EvAnatomy a,
    CalendarOccurrence o, {
    double size = 26,
    VoidCallback? onToggleDone,
  }) {
    switch (a.kind) {
      case CalEventKind.todo:
        // An empty checkbox square — tickable in place (design §3a).
        return GestureDetector(
          key: ValueKey('event-check-${o.ev.id}-${o.date}'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _toggleOccurrenceDone(o);
            onToggleDone?.call();
          },
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: a.color, width: 2),
            ),
            child: a.done ? Icon(Icons.check, size: 12, color: a.color) : null,
          ),
        );
      case CalEventKind.birthday:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: kBirthdayAmber.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Center(
            child: Text('\u{1F382}', style: TextStyle(fontSize: 13)),
          ),
        );
      case CalEventKind.imported:
        final importedInk = contrastOn(a.color);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: importedInk.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              '\u21E9',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: importedInk,
              ),
            ),
          ),
        );
      case CalEventKind.appointment:
        final fg = contrastOn(a.color);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fg.withValues(alpha: .25),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: a.category != null
                ? categoryGlyph(a.category!, size: size * .58, iconColor: fg)
                : glyphTile(
                    size: size * .62,
                    radius: 6,
                    picture: a.layer?.picture,
                    emoji: a.layer?.emoji,
                    emojiSize: size * .5,
                    fallback: Center(
                      child: ic(
                        a.layer?.icon ?? 'cal',
                        size: size * .5,
                        sw: 2.2,
                        color: fg,
                      ),
                    ),
                  ),
          ),
        );
    }
  }

  /// The row's surface: solid colour / dotted white / cream / stripes.
  BoxDecoration _evRowDecoration(_EvAnatomy a, {double radius = 13}) {
    switch (a.kind) {
      case CalEventKind.todo:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        );
      case CalEventKind.birthday:
        return BoxDecoration(
          color: kBirthdayCream,
          border: Border.all(color: kBirthdayAmber.withValues(alpha: .33)),
          borderRadius: BorderRadius.circular(radius),
        );
      case CalEventKind.imported:
        return BoxDecoration(
          gradient: importedStripes(a.color),
          borderRadius: BorderRadius.circular(radius),
        );
      case CalEventKind.appointment:
        return BoxDecoration(
          color: a.color,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: a.color.withValues(alpha: .35),
              blurRadius: 18,
              spreadRadius: -12,
              offset: const Offset(0, 8),
            ),
          ],
        );
    }
  }

  (Color title, Color sub) _evRowInk(_EvAnatomy a) {
    switch (a.kind) {
      case CalEventKind.todo:
        return (a.color, B.muted);
      case CalEventKind.birthday:
        return (kBirthdayInk, kBirthdaySubInk);
      case CalEventKind.imported:
        final ink = contrastOn(a.color);
        return (ink, ink.withValues(alpha: .8));
      case CalEventKind.appointment:
        final fg = contrastOn(a.color);
        return (fg, fg.withValues(alpha: .8));
    }
  }

  /// THE full agenda/day-sheet row for any occurrence of any kind — the
  /// design's `evRowFull()`. Every other surface is a projection of this.
  Widget _evRowFull(
    CalendarOccurrence o, {
    String? iso,
    bool popSheetFirst = false,
    String rowKeyPrefix = 'agenda-appt',
    VoidCallback? onToggleDone,
  }) {
    final day = iso ?? o.date;
    final a = _evAnatomy(o, day);
    final (titleInk, subInk) = _evRowInk(a);
    final ev = o.ev;
    return Builder(
      builder: (context) {
        void openTap() {
          if (popSheetFirst) Navigator.of(context).pop();
          openEventView(ev.id, o.date);
        }

        return Opacity(
          opacity: (a.done || a.past) ? _calendarFadedOpacity : 1,
          child: GestureDetector(
            key: ValueKey('$rowKeyPrefix-${ev.id}-${o.date}'),
            onTap: openTap,
            child: Container(
              key: ValueKey('$rowKeyPrefix-surface-${ev.id}-${o.date}'),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: _evRowDecoration(a),
              foregroundDecoration: a.kind == CalEventKind.todo
                  ? _DottedBoxDecoration(color: a.color, radius: 13, width: 2)
                  : null,
              child: Row(
                children: [
                  KeyedSubtree(
                    key: ValueKey('$rowKeyPrefix-ico-${ev.id}-${o.date}'),
                    child: _evIconBox(a, o, onToggleDone: onToggleDone),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: titleInk,
                            decoration: a.done
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          a.sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: subInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ev.attendees.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    KeyedSubtree(
                      key: ValueKey('agenda-attendees-${ev.id}-${o.date}'),
                      child: _attendeeStack(ev.attendees, 20),
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

  /// Compact single-line projection of [_evRowFull] used by the kitchen wall
  /// (#341): a fixed-width leading chip so titles align down a column, then
  /// the category icon + title.
  Widget _evPill(
    CalendarOccurrence o, {
    String? iso,
    String keyPrefix = 'kitchen-pill',
    VoidCallback? onTap,
  }) {
    final day = iso ?? o.date;
    final a = _evAnatomy(o, day);
    final (titleInk, _) = _evRowInk(a);
    final chipInk = switch (a.kind) {
      CalEventKind.todo => a.color,
      CalEventKind.birthday => kBirthdayInk,
      CalEventKind.imported => contrastOn(a.color),
      CalEventKind.appointment => contrastOn(a.color),
    };
    final chipBg = switch (a.kind) {
      CalEventKind.todo => a.color.withValues(alpha: .08),
      CalEventKind.birthday => kBirthdayAmber.withValues(alpha: .13),
      _ => Colors.white.withValues(alpha: .25),
    };
    return Opacity(
      opacity: (a.done || a.past) ? _calendarFadedOpacity : 1,
      child: GestureDetector(
        key: ValueKey('$keyPrefix-${o.ev.id}-${o.date}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: _evRowDecoration(a, radius: 11),
          foregroundDecoration: a.kind == CalEventKind.todo
              ? _DottedBoxDecoration(color: a.color, radius: 11, width: 2)
              : null,
          child: Row(
            children: [
              // Fixed-width so titles align down a column — but it gives
              // way rather than overflowing in a very narrow one.
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      a.chip,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: chipInk,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (a.kind == CalEventKind.todo) ...[
                Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: a.color, width: 2),
                  ),
                ),
                const SizedBox(width: 6),
              ] else if (a.kind == CalEventKind.birthday) ...[
                const Text('\u{1F382}', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
              ] else if (a.category != null) ...[
                categoryGlyph(a.category!, size: 13, iconColor: titleInk),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: titleInk,
                    decoration: a.done
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
  }

  // ---------------------------------------------------------------- card
  Widget _eventCard(
    CalendarOccurrence o, {
    String? iso,
    bool popSheetFirst = false,
    VoidCallback? onToggleDone,
  }) => _evRowFull(
    o,
    iso: iso,
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

/// A dotted rounded-rect border painted as a [foregroundDecoration] — the
/// to-do kind's outline on every calendar surface (design §3a: "dashed
/// outline + a real checkbox"), from month-cell bars to agenda rows and
/// kitchen pills.
class _DottedBoxDecoration extends Decoration {
  const _DottedBoxDecoration({
    required this.color,
    required this.radius,
    this.width = 1.5,
  });

  final Color color;
  final double radius;
  final double width;
  double get strokeWidth => width;
  double get dashWidth => width * 1.2;
  double get gapWidth => width * 1.3;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DottedBoxPainter(this);
}

class _DottedBoxPainter extends BoxPainter {
  _DottedBoxPainter(this.decoration);
  final _DottedBoxDecoration decoration;

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
