part of 'package:family_money_management_app/main.dart';

/// An event occurrence on a given date — either a real [CalendarEvent]
/// (possibly a recurrence instance), an imported (read-only) event, or a
/// task's due date (also read-only), each surfaced through a synthetic
/// [CalendarEvent] for uniform rendering.
class CalendarOccurrence {
  CalendarOccurrence({
    required this.ev,
    required this.date,
    String? spanEnd,
    this.imported = false,
    this.done = false,
  }) : spanEnd = spanEnd ?? date;
  final CalendarEvent ev;

  /// First day of this occurrence.
  final String date;

  /// Last day of this occurrence — equal to [date] unless this is a
  /// multi-day span (`ev.endDate`).
  final String spanEnd;
  final bool imported;

  /// True when the underlying to-do/content-style event (or, for a
  /// recurring event, this specific occurrence date) has been marked done.
  /// A done occurrence is still returned/rendered — never filtered out —
  /// with a done visual treatment applied by the caller (strikethrough
  /// title + faded opacity), mirroring how completed tasks used to behave
  /// in Lists before Lists was decoupled from the calendar. Always false
  /// for plain appointments and imported events.
  final bool done;

  /// Which calendar layer this occurrence belongs to — [ev.layerId]
  /// directly (`appt`, `task`, `content`, or any custom layer id) — used
  /// by the layer-toggle filter and to pick this occurrence's visuals.
  String get layer => ev.layerId;

  /// True when this occurrence is a to-do event, regardless of calendar
  /// layer. Such occurrences get a tappable done checkbox instead of
  /// appointment-only chrome. Never true for imported (read-only) events.
  bool get isTask => !imported && ev.todo;

  /// True when this occurrence is a to-do belonging to any layer other
  /// than the default `task`/`appt` layers (e.g. `content` or a custom
  /// layer) — drives the "content-style" dashed-border card treatment.
  bool get isContent => isTask && layer != kLayerTask;

  bool get isMultiDay => spanEnd.compareTo(date) > 0;
}

/// Renders a category's visual (issue: match the budget block emoji/picture
/// picker) — an uploaded [EventCategory.picture] wins, then
/// [EventCategory.emoji], otherwise the legacy stroke [EventCategory.icon].
/// Fills a fixed [size]x[size] box so it drops into icon-badge slots.
Widget categoryGlyph(
  EventCategory c, {
  required double size,
  required Color iconColor,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: glyphTile(
      size: size,
      radius: size / 3.2,
      picture: c.picture,
      emoji: c.emoji,
      emojiSize: size * 0.62,
      fallback: Center(
        child: ic(c.icon, size: size * 0.66, sw: 2.2, color: iconColor),
      ),
    ),
  );
}

const List<String> kCatIconsList = [
  'briefcase',
  'book',
  'whistle',
  'heart',
  'users',
  'cal',
  'home',
  'cart',
  'flag',
  'sun',
  'moon',
  'note',
  'bell',
  'star',
];

const List<Color> kCatColors = [
  Color(0xff7c3aed),
  Color(0xff9333ea),
  Color(0xff1684B4),
  Color(0xff2563eb),
  Color(0xff0891b2),
  Color(0xff0f9d6a),
  Color(0xff16a34a),
  Color(0xff65a30d),
  Color(0xffe11d48),
  Color(0xffdb2777),
  Color(0xffd97706),
  Color(0xffea580c),
  Color(0xffca8a04),
  Color(0xff0E9A8D),
  Color(0xff0d9488),
  Color(0xff0f766e),
  Color(0xff4f46e5),
  Color(0xffbe123c),
  Color(0xffb45309),
  Color(0xff475569),
  Color(0xff334155),
];

const List<Color> kEventColors = kCatColors;

/// (label, colour) for each import provider. `google`/`apple` account sync
/// isn't implemented (#161) — ICS/web-link is the only real import path.
const Map<String, (String, Color)> kImportProviders = {
  'ics': ('ICS / web link', Color(0xff0d9488)),
};

// ------------------------------------------------------------- date utils
DateTime _parseIso(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return DateTime.now();
  return DateTime.utc(
    int.tryParse(parts[0]) ?? 2026,
    int.tryParse(parts[1]) ?? 1,
    int.tryParse(parts[2]) ?? 1,
  );
}

String _isoOf(int y, int m, int d) {
  final dt = DateTime.utc(y, m, d);
  return '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

String _isoOfDate(DateTime d) => _isoOf(d.year, d.month, d.day);

String _addDaysIso(String iso, int n) =>
    _isoOfDate(_parseIso(iso).add(Duration(days: n)));

/// [anchorDay] is the day-of-month to aim for in the target month (clamped to
/// that month's length). Recurrence walks pass the series' original
/// day-of-month here so a clamp never compounds (Jan 31 → Feb 28 → Mar 31,
/// not Mar 28 forever).
String _addMonthsIso(String iso, int n, {int? anchorDay}) {
  final d = _parseIso(iso);
  final total = d.month - 1 + n;
  // Use floor division so negative offsets correctly roll the year
  // backward (Dart's `~/` truncates toward zero, not floor).
  final y = d.year + (total < 0 ? (total - 11) ~/ 12 : total ~/ 12);
  final m = total % 12 + 1;
  final lastDay = DateTime.utc(y, m + 1, 0).day;
  final day = anchorDay ?? d.day;
  return _isoOf(y, m, day > lastDay ? lastDay : day);
}

/// Monday-first start of the ISO week containing [iso].
String _startOfWeekIso(String iso) {
  final d = _parseIso(iso);
  final weekday = d.weekday; // 1=Mon .. 7=Sun
  return _addDaysIso(iso, -(weekday - 1));
}

const List<String> kWeekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String _displayDateIso(String iso) {
  final d = _parseIso(iso);
  return '${d.day.toString().padLeft(2, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.year.toString().padLeft(4, '0')}';
}

String _prettyDateIso(String iso) {
  return _displayDateIso(iso);
}

String _shortDateIso(String iso) {
  return _displayDateIso(iso);
}

/// "Week 22" — used for the Agenda view's header subtitle instead of the
/// selected day's weekday/date, per ISO-8601 week numbering (weeks start on
/// Monday; week 1 is the week containing the year's first Thursday).
String _weekNumberLabelIso(String iso) {
  final d = _parseIso(iso); // UTC
  final thursday = d.add(Duration(days: 4 - d.weekday));
  // Keep both endpoints in UTC: mixing a local Jan 1 with the UTC [thursday]
  // makes `inDays` truncate and shifts the week number for UTC+X users.
  final firstDayOfYear = DateTime.utc(thursday.year, 1, 1);
  final weekNumber =
      ((thursday.difference(firstDayOfYear).inDays) / 7).floor() + 1;
  return 'Week $weekNumber';
}

@visibleForTesting
String weekNumberLabelForTest(String iso) => _weekNumberLabelIso(iso);

String _monthTitleIso(String iso) {
  final d = _parseIso(iso);
  return '${kMonthsEn[d.month - 1]} ${d.year}';
}

String _weekRangeIso(String weekStartIso) {
  final weekEndIso = _addDaysIso(weekStartIso, 6);
  return '${_displayDateIso(weekStartIso)} – ${_displayDateIso(weekEndIso)}';
}

int _customRepeatEvery(CalendarEvent ev) =>
    ev.recurEvery < 1 ? 1 : ev.recurEvery;

String _customRepeatUnit(CalendarEvent ev) {
  return switch (ev.recurUnit) {
    'day' || 'week' || 'month' || 'year' => ev.recurUnit,
    _ => 'week',
  };
}

List<int> _customRepeatWeekdays(CalendarEvent ev) {
  final days = {
    for (final day in ev.recurWeekdays)
      if (day >= 1 && day <= 7) day,
  }.toList()..sort();
  return days.isEmpty ? [_parseIso(ev.date).weekday] : days;
}

String? _nextRecurringDate(CalendarEvent ev, String current) {
  // Month-based steps aim for the series' original day-of-month rather than
  // the previous occurrence's, so a short-month clamp doesn't stick (see
  // `_addMonthsIso`).
  final anchorDay = _parseIso(ev.date).day;
  if (ev.recur == 'daily') return _addDaysIso(current, 1);
  if (ev.recur == 'weekly') return _addDaysIso(current, 7);
  if (ev.recur == 'monthly') return _addMonthsIso(current, 1, anchorDay: anchorDay);
  if (ev.recur == 'yearly') return _addMonthsIso(current, 12, anchorDay: anchorDay);
  if (ev.recur != 'custom') return null;

  final every = _customRepeatEvery(ev);
  final unit = _customRepeatUnit(ev);
  if (unit == 'day') return _addDaysIso(current, every);
  if (unit == 'month') return _addMonthsIso(current, every, anchorDay: anchorDay);
  if (unit == 'year') return _addMonthsIso(current, 12 * every, anchorDay: anchorDay);

  final weekdays = _customRepeatWeekdays(ev);
  var cursor = current;
  for (var guard = 0; guard < 3700; guard++) {
    cursor = _addDaysIso(cursor, 1);
    final cursorDate = _parseIso(cursor);
    if (!weekdays.contains(cursorDate.weekday)) continue;
    final originWeek = _parseIso(_startOfWeekIso(ev.date));
    final cursorWeek = _parseIso(_startOfWeekIso(cursor));
    final weeksSince = cursorWeek.difference(originWeek).inDays ~/ 7;
    if (weeksSince >= 0 && weeksSince % every == 0) return cursor;
  }
  return null;
}

List<String> recurringEventDates(
  CalendarEvent ev,
  String rangeStart,
  String rangeEnd, {
  int maxOccurrences = 900,
}) {
  if (ev.recur == 'none') return const [];
  final repeatEnd = ev.endDate.isNotEmpty ? ev.endDate : rangeEnd;
  final dates = <String>[];
  var d = ev.date;
  // Fixed day-interval recurrences (daily/weekly/custom "every N days") can
  // jump straight to the last occurrence on/before [rangeStart] instead of
  // stepping one occurrence at a time from the series start — an old series
  // would otherwise burn the whole iteration budget before reaching the
  // viewed range and silently vanish from it.
  final stepDays = switch (ev.recur) {
    'daily' => 1,
    'weekly' => 7,
    'custom' when _customRepeatUnit(ev) == 'day' => _customRepeatEvery(ev),
    _ => null,
  };
  if (stepDays != null && d.compareTo(rangeStart) < 0) {
    final behind = _parseIso(rangeStart).difference(_parseIso(d)).inDays;
    final skippedSteps = behind ~/ stepDays;
    if (skippedSteps > 0) d = _addDaysIso(d, skippedSteps * stepDays);
  }
  // [maxOccurrences] caps *emitted* dates; the separate iteration ceiling
  // covers month/year series that still walk pre-range occurrences, while
  // guarding against a next-date computation that fails to advance.
  var iterations = 0;
  while (d.compareTo(rangeEnd) <= 0 &&
      d.compareTo(repeatEnd) <= 0 &&
      dates.length < maxOccurrences &&
      iterations < 100000) {
    if (d.compareTo(rangeStart) >= 0 && !ev.exceptions.contains(d)) {
      dates.add(d);
    }
    final next = _nextRecurringDate(ev, d);
    if (next == null || next.compareTo(d) <= 0) break;
    d = next;
    iterations++;
  }
  return dates;
}

/// Strips location/description off imported events per an import's prefs
/// (e.g. skip a sports feed's venue or competition/match-link text).
List<ImportedCalendarEvent> _applyImportPrefs(
  List<ImportedCalendarEvent> events, {
  required bool includeLocation,
  required bool includeDescription,
}) {
  if (includeLocation && includeDescription) return events;
  for (final e in events) {
    if (!includeLocation) e.location = '';
    if (!includeDescription) e.notes = '';
  }
  return events;
}

extension _ThriveCalendarActions on _ThriveHomeState {
  EventCategory? catById(String? id) {
    if (id == null) return null;
    for (final c in eventCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Builds the read-only [CalendarEvent] used to render/view an imported
  /// occurrence, keyed by the composite `'${cal.id}_${e.id}'` id.
  CalendarEvent importedSyntheticEvent(
    ImportedCalendar cal,
    ImportedCalendarEvent e,
  ) {
    final cat = catById(cal.category);
    return CalendarEvent(
      id: '${cal.id}_${e.id}',
      title: e.title,
      allDay: e.allDay,
      date: e.date,
      start: e.start,
      end: e.end,
      location: e.location,
      notes: e.notes,
      category: cal.category,
      color: cat?.color ?? cal.color,
      attendees: cat?.members ?? const [],
      recur: 'none',
      reminder: cal.reminder,
      createdBy: cal.name,
    );
  }

  Color evColor(CalendarEvent ev) {
    final category = catById(ev.category);
    if (category != null) return category.color;
    if (ev.color != kEventColors.first) return ev.color;
    for (final memberId in ev.attendees) {
      final member = _memberById(memberId);
      if (member != null) return member.color;
    }
    return ev.color;
  }

  Set<int> usedCalendarIdentityColorValues({
    String? exceptCategoryId,
    String? exceptMemberId,
  }) {
    return {
      for (final c in eventCategories)
        if (c.id != exceptCategoryId) c.color.toARGB32(),
      for (final m in curFamily()?.members ?? const <FamilyMember>[])
        if (m.id != exceptMemberId) m.color.toARGB32(),
    };
  }

  bool isCalendarIdentityColorAvailable(
    Color color, {
    String? exceptCategoryId,
    String? exceptMemberId,
  }) {
    return true;
  }

  Color firstAvailableCalendarIdentityColor({
    Color? fallback,
    String? exceptCategoryId,
    String? exceptMemberId,
  }) {
    final used = usedCalendarIdentityColorValues(
      exceptCategoryId: exceptCategoryId,
      exceptMemberId: exceptMemberId,
    );
    for (final color in kCatColors) {
      if (!used.contains(color.toARGB32())) return color;
    }
    return fallback ?? kCatColors.first;
  }

  /// Expands recurring events (minus their `exceptions`), keeps multi-day
  /// spans as a single occurrence, and appends visible imported-calendar
  /// events — all overlapping `[rangeStart, rangeEnd]` (inclusive, ISO
  /// dates) and honouring the active member/category filters. Mirrors the
  /// design's `eventOccurrences()`.
  List<CalendarOccurrence> eventOccurrences(
    String rangeStart,
    String rangeEnd,
  ) {
    final out = <CalendarOccurrence>[];
    final flt = calFilter;
    final cflt = calCatFilter;

    // Every layer's items — appointments, to-dos, content, or any custom
    // layer — are just [CalendarEvent]s tagged with [CalendarEvent.layerId];
    // a to-do/content-style event that's been completed (`isDoneOn`) STAYS
    // in view (never filtered out, like a deleted event would be) — it's
    // tagged `done: true` instead, so the caller can render it with a done
    // visual treatment (strikethrough + faded) while keeping the
    // checkbox/tap-to-toggle interaction available.
    for (final ev in events) {
      if (ev.kitchenOrigin) continue;
      if (!layerFilter.contains(ev.layerId)) continue;
      if (flt.isNotEmpty && !ev.attendees.any(flt.contains)) continue;
      if (cflt.isNotEmpty && !cflt.contains(ev.category)) continue;

      if (ev.recur == 'none') {
        final spanEnd =
            ev.endDate.isNotEmpty && ev.endDate.compareTo(ev.date) > 0
            ? ev.endDate
            : ev.date;
        if (spanEnd.compareTo(rangeStart) >= 0 &&
            ev.date.compareTo(rangeEnd) <= 0 &&
            !ev.exceptions.contains(ev.date)) {
          out.add(
            CalendarOccurrence(
              ev: ev,
              date: ev.date,
              spanEnd: spanEnd,
              done: ev.todo && ev.done,
            ),
          );
        }
        continue;
      }

      for (final d in recurringEventDates(ev, rangeStart, rangeEnd)) {
        out.add(
          CalendarOccurrence(ev: ev, date: d, done: ev.todo && ev.isDoneOn(d)),
        );
      }
    }

    // Imported calendars are read-only and have no direct attendees, so when
    // member filters are active we match them via their assigned category.
    for (final cal
        in layerFilter.contains(kLayerAppt)
            ? importedCalendars
            : const <ImportedCalendar>[]) {
      if (!cal.visible) continue;
      if (cflt.isNotEmpty && !cflt.contains(cal.category)) continue;
      if (flt.isNotEmpty) {
        final cat = catById(cal.category);
        if (cat == null || !cat.members.any(flt.contains)) continue;
      }
      for (final e in cal.events) {
        if (e.date.compareTo(rangeStart) >= 0 &&
            e.date.compareTo(rangeEnd) <= 0) {
          out.add(
            CalendarOccurrence(
              imported: true,
              date: e.date,
              ev: importedSyntheticEvent(cal, e),
            ),
          );
        }
      }
    }
    return out;
  }

  /// Looks up a [CalendarLayerDef] by id, or `null` if it no longer exists
  /// (e.g. stale data referencing a deleted layer).
  CalendarLayerDef? layerDefFor(String id) {
    for (final l in calendarLayers) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Appends a new enabled-by-default calendar layer (mirrors the design's
  /// `addLayer()`).
  ///
  /// If this is the workspace's very FIRST layer ever (i.e. [calendarLayers]
  /// was empty beforehand), every existing [CalendarEvent]/[EventCategory]
  /// is retroactively reassigned to it. This matters for families whose data
  /// predates layers entirely — their events/categories only carry the
  /// model's implicit `'appt'` fallback [layerId], which no longer
  /// corresponds to any real [CalendarLayerDef] once a brand-new workspace
  /// starts with zero layers — so nothing becomes orphaned/invisible the
  /// moment layers go from "doesn't exist as a concept" to "exists" (mirrors
  /// [removeCalendarLayer]'s reassign-on-delete logic below).
  void addCalendarLayer({
    required String label,
    required String icon,
    String? emoji,
    String? picture,
    required Color color,
  }) {
    mutate(() {
      final wasEmpty = calendarLayers.isEmpty;
      final id = uid();
      calendarLayers.add(
        CalendarLayerDef(
          id: id,
          label: label.trim().isEmpty ? 'Layer' : label.trim(),
          icon: icon,
          emoji: emoji,
          picture: picture,
          color: color,
        ),
      );
      layerFilter.add(id);
      kitchenLayerFilter.add(id);
      if (wasEmpty) {
        for (final ev in events) {
          if (ev.kitchenOrigin) continue;
          ev.layerId = id;
        }
        for (final cat in eventCategories) {
          cat.layerId = id;
        }
      }
    }, () => flash('Layer added'));
  }

  /// Updates an existing layer's label/icon/emoji/picture/colour in place
  /// (tapped from its row, mirroring how tapping a category opens it for
  /// editing) — a no-op if [id] no longer exists.
  void updateCalendarLayer({
    required String id,
    required String label,
    required String icon,
    String? emoji,
    String? picture,
    required Color color,
  }) {
    final def = layerDefFor(id);
    if (def == null) return;
    mutate(() {
      def.label = label.trim().isEmpty ? 'Layer' : label.trim();
      def.icon = icon;
      def.emoji = emoji;
      def.picture = picture;
      def.color = color;
    });
  }

  /// Swaps the layer at [id]'s position with the adjacent one in
  /// [direction] (-1 = up, +1 = down); a no-op at either end (mirrors the
  /// design's `moveLayer()`).
  void moveCalendarLayer(String id, int direction) => mutate(() {
    final i = calendarLayers.indexWhere((l) => l.id == id);
    if (i < 0) return;
    final j = i + direction;
    if (j < 0 || j >= calendarLayers.length) return;
    final tmp = calendarLayers[i];
    calendarLayers[i] = calendarLayers[j];
    calendarLayers[j] = tmp;
  });

  bool canDeleteCalendarLayer(CalendarLayerDef layer) => true;

  String _calendarLayerDeleteFallback(String deletedId) {
    final remaining = [
      for (final layer in calendarLayers)
        if (layer.id != deletedId) layer.id,
    ];
    if (remaining.contains(kLayerTask)) return kLayerTask;
    if (remaining.contains(kLayerAppt)) return kLayerAppt;
    if (remaining.isNotEmpty) return remaining.first;
    return kLayerAppt;
  }

  /// Removes a deletable layer, reassigning any [CalendarEvent]/
  /// [EventCategory] pointing at it to the best remaining layer first, so
  /// nothing is left referencing a deleted layer.
  void removeCalendarLayer(String id) {
    final def = layerDefFor(id);
    if (def == null || !canDeleteCalendarLayer(def)) return;
    final fallbackLayerId = _calendarLayerDeleteFallback(id);
    mutate(() {
      for (final ev in events) {
        if (ev.kitchenOrigin) continue;
        if (ev.layerId == id) ev.layerId = fallbackLayerId;
      }
      for (final cat in eventCategories) {
        if (cat.layerId == id) cat.layerId = fallbackLayerId;
      }
      calendarLayers.removeWhere((l) => l.id == id);
      layerFilter.remove(id);
      kitchenLayerFilter.remove(id);
    }, () => flash('Layer deleted'));
  }

  /// Toggles a calendar layer's visibility. [CalendarLayerDef] itself only
  /// defines which layers exist plus their order/colour/icon/label —
  /// [layerFilter] membership is the single source of truth for whether a
  /// layer is currently visible (reuses [toggleLayerFilter]'s "can't
  /// disable the last layer" guard).
  void toggleCalendarLayerEnabled(String id) => toggleLayerFilter(id);

  /// The 42-cell (6x7) month grid starting on the Monday on/before the 1st.
  List<String> monthGrid(String anchor) {
    final d = _parseIso(anchor);
    final first = _isoOf(d.year, d.month, 1);
    final start = _startOfWeekIso(first);
    return [for (var i = 0; i < 42; i++) _addDaysIso(start, i)];
  }

  void calToday() {
    update(() {
      calAnchor = todayIso();
      calSel = todayIso();
    });
  }

  void setCalView(String v) => update(() {
    calView = v;
  });
  void setCalSel(String iso) => update(() => calSel = iso);

  /// Toggles a calendar layer (`appt|task|content`) on/off in [layerFilter].
  /// At least one layer must stay enabled — a tap that would empty the list
  /// (removing the last remaining layer) is ignored.
  void toggleLayerFilter(String layerId) => mutate(() {
    if (layerFilter.contains(layerId)) {
      if (layerFilter.length <= 1) return;
      layerFilter.remove(layerId);
      calCatFilter.removeWhere((catId) => catById(catId)?.layerId == layerId);
    } else {
      layerFilter.add(layerId);
    }
  });

  void toggleCalMemberFilter(String memberId) => update(() {
    if (!calFilter.remove(memberId)) calFilter.add(memberId);
  });
  void toggleCalCategoryFilter(String catId) => update(() {
    if (!calCatFilter.remove(catId)) calCatFilter.add(catId);
  });
  void clearCalFilters() => update(() {
    calFilter = [];
    calCatFilter = [];
  });
  int calFilterCount() => calFilter.length + calCatFilter.length;

  void openCalMonthPicker() {
    _showSheet((ctx) => _CalMonthPickerSheet(state: this));
  }

  void openCalPeriodPicker() {
    openCalMonthPicker();
  }

  void openViewPicker() {
    _showSheet((ctx) => _ViewPickerSheet(state: this));
  }

  void openCalFilterSheet() {
    _showSheet((ctx) => _CalFilterSheet(state: this));
  }

  void openDayDetail(String iso) {
    _showSheet((ctx) => _DayDetailSheet(state: this, iso: iso));
  }

  /// Greedy lane-packing for a Month-view week row: multi-day/longest
  /// occurrences first, capped at [maxLanes]; anything beyond that is
  /// counted per-day into the returned overflow map (day index 0-6 → count).
  ({List<List<CalendarOccurrence?>> lanes, Map<int, int> overflow})
  packWeekLanes(
    List<CalendarOccurrence> occ,
    String weekStart,
    String weekEnd, {
    int maxLanes = 4,
  }) {
    final items = <({CalendarOccurrence o, int cs, int ce})>[];
    for (final o in occ) {
      final cs = o.date.compareTo(weekStart) < 0
          ? 0
          : _parseIso(o.date).difference(_parseIso(weekStart)).inDays;
      final ce = o.spanEnd.compareTo(weekEnd) > 0
          ? 6
          : _parseIso(o.spanEnd).difference(_parseIso(weekStart)).inDays;
      items.add((o: o, cs: cs, ce: ce));
    }
    items.sort((a, b) {
      final aMulti = a.o.isMultiDay;
      final bMulti = b.o.isMultiDay;
      if (aMulti != bMulti) return aMulti ? -1 : 1;
      final aSpan = a.ce - a.cs;
      final bSpan = b.ce - b.cs;
      if (aSpan != bSpan) return bSpan - aSpan;
      return (a.o.ev.start).compareTo(b.o.ev.start);
    });

    final lanes = <List<CalendarOccurrence?>>[];
    final overflow = <int, int>{};
    for (final it in items) {
      var placed = false;
      for (final lane in lanes) {
        var free = true;
        for (var c = it.cs; c <= it.ce; c++) {
          if (lane[c] != null) {
            free = false;
            break;
          }
        }
        if (free) {
          for (var c = it.cs; c <= it.ce; c++) {
            lane[c] = it.o;
          }
          placed = true;
          break;
        }
      }
      if (!placed) {
        if (lanes.length < maxLanes) {
          final lane = List<CalendarOccurrence?>.filled(7, null);
          for (var c = it.cs; c <= it.ce; c++) {
            lane[c] = it.o;
          }
          lanes.add(lane);
        } else {
          for (var c = it.cs; c <= it.ce; c++) {
            overflow[c] = (overflow[c] ?? 0) + 1;
          }
        }
      }
    }
    return (lanes: lanes, overflow: overflow);
  }

  // -------------------------------------------------------------- events
  void openEvent(CalendarEvent? ev, [String? date]) {
    _showSheet(
      (ctx) => _EventEditSheet(state: this, event: ev, date: date ?? calSel),
    );
  }

  void openEventView(String id, String date) {
    _showSheet((ctx) => _EventViewSheet(state: this, eventId: id, date: date));
  }

  CalendarEvent? eventById(String id) {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Looks up an occurrence's id across real and imported events. Real
  /// events (of any layer — appointment, to-do, content, or custom) are
  /// mutable; imported ones are synthesized read-only and can be viewed but
  /// never edited/deleted.
  ({CalendarEvent? ev, bool imported}) eventOrImportedById(String id) {
    final real = eventById(id);
    if (real != null) return (ev: real, imported: false);
    for (final cal in importedCalendars) {
      for (final e in cal.events) {
        if ('${cal.id}_${e.id}' == id) {
          return (ev: importedSyntheticEvent(cal, e), imported: true);
        }
      }
    }
    return (ev: null, imported: false);
  }

  /// Toggles completion of a to-do/content occurrence tapped from its
  /// calendar checkbox (Month bar or Agenda/day-detail card). No-op for
  /// non-task occurrences (appointments/imported events have no checkbox).
  /// Non-recurring events flip [CalendarEvent.done]; recurring events flip
  /// only the tapped occurrence's date in [CalendarEvent.doneDates].
  void _toggleOccurrenceDone(CalendarOccurrence o) {
    if (!o.isTask) return;
    toggleEventDone(o.ev.id, o.date);
  }

  /// Toggles a [CalendarEvent]'s completion state directly — non-recurring
  /// events flip [CalendarEvent.done], recurring events flip only the
  /// occurrence on [dateIso] in [CalendarEvent.doneDates].
  void toggleEventDone(String id, String dateIso) {
    var changed = false;
    mutate(() {
      final ev = eventById(id);
      if (ev == null) return;
      if (ev.recur == 'none') {
        ev.done = !ev.done;
      } else {
        ev.doneDates[dateIso] = !(ev.doneDates[dateIso] ?? false);
      }
      changed = true;
    });
    if (changed) _syncDeviceCalendar();
  }

  void saveEvent({
    String? id,
    required String title,
    required bool allDay,
    required String date,
    String endDate = '',
    required String start,
    required String end,
    required String location,
    required String notes,
    String? category,
    required Color color,
    required List<String> attendees,
    required String reminder,
    required String recur,
    int recurEvery = 1,
    String recurUnit = 'week',
    List<int> recurWeekdays = const [],
    List<String>? exceptions,
    String? createdBy,
    String layerId = kLayerAppt,
    bool todo = false,
    bool done = false,
    Map<String, bool>? doneDates,
  }) {
    final wasEditing = id != null;
    final existing = id == null ? null : eventById(id);
    CalendarEvent? saved;
    mutate(() {
      final effectiveColor = catById(category)?.color ?? color;
      final ev = CalendarEvent(
        id: id ?? uid(),
        title: title.trim().isEmpty ? 'Untitled' : title.trim(),
        allDay: allDay,
        date: date,
        endDate: endDate,
        start: allDay ? '' : start,
        end: allDay ? '' : end,
        location: location.trim(),
        notes: notes.trim(),
        category: category,
        color: effectiveColor,
        attendees: attendees,
        reminder: reminder,
        recur: recur,
        recurEvery: recurEvery,
        recurUnit: recurUnit,
        recurWeekdays: recurWeekdays,
        createdBy: createdBy ?? myId,
        exceptions: exceptions ?? const [],
        layerId: layerId,
        todo: todo,
        done: done,
        doneDates: doneDates,
        kitchenOrigin: existing?.kitchenOrigin ?? false,
        picture: existing?.picture,
        emoji: existing?.emoji,
      );
      final i = events.indexWhere((x) => x.id == ev.id);
      if (i >= 0) {
        events[i] = ev;
      } else {
        events.add(ev);
      }
      saved = ev;
    }, () => flash(wasEditing ? 'Event updated' : 'Event added'));
    if (saved != null) {
      NotificationService.instance.scheduleEventReminder(saved!);
      _syncDeviceCalendar();
    }
  }

  CalendarEvent _eventCopyWith(
    CalendarEvent ev, {
    String? id,
    String? title,
    bool? allDay,
    String? date,
    String? endDate,
    String? start,
    String? end,
    String? location,
    String? notes,
    String? category,
    Color? color,
    List<String>? attendees,
    String? reminder,
    String? recur,
    int? recurEvery,
    String? recurUnit,
    List<int>? recurWeekdays,
    String? createdBy,
    List<String>? exceptions,
    String? layerId,
    bool? todo,
    bool? done,
    Map<String, bool>? doneDates,
  }) {
    return CalendarEvent(
      id: id ?? ev.id,
      title: title ?? ev.title,
      allDay: allDay ?? ev.allDay,
      date: date ?? ev.date,
      endDate: endDate ?? ev.endDate,
      start: start ?? ev.start,
      end: end ?? ev.end,
      location: location ?? ev.location,
      notes: notes ?? ev.notes,
      category: category ?? ev.category,
      color: color ?? ev.color,
      attendees: attendees ?? ev.attendees,
      reminder: reminder ?? ev.reminder,
      recur: recur ?? ev.recur,
      recurEvery: recurEvery ?? ev.recurEvery,
      recurUnit: recurUnit ?? ev.recurUnit,
      recurWeekdays: recurWeekdays ?? ev.recurWeekdays,
      createdBy: createdBy ?? ev.createdBy,
      exceptions: exceptions ?? ev.exceptions,
      layerId: layerId ?? ev.layerId,
      todo: todo ?? ev.todo,
      done: done ?? ev.done,
      doneDates: doneDates ?? Map<String, bool>.from(ev.doneDates),
      kitchenOrigin: ev.kitchenOrigin,
      picture: ev.picture,
      emoji: ev.emoji,
    );
  }

  void saveRecurringEventScoped({
    required String id,
    required String scope,
    required String occurrenceDate,
    required CalendarEvent edited,
  }) {
    var changed = false;
    CalendarEvent? rescheduleOriginal;
    CalendarEvent? rescheduleNew;
    mutate(() {
      final i = events.indexWhere((x) => x.id == id);
      if (i < 0) return;
      changed = true;
      final original = events[i];
      if (scope == 'one') {
        events[i] = _eventCopyWith(
          original,
          exceptions: {...original.exceptions, occurrenceDate}.toList(),
        );
        final oneOff = _eventCopyWith(
          edited,
          id: uid(),
          date: occurrenceDate,
          endDate: '',
          recur: 'none',
          exceptions: const [],
          createdBy: original.createdBy,
        );
        events.add(oneOff);
        rescheduleOriginal = events[i];
        rescheduleNew = oneOff;
      } else if (scope == 'future') {
        if (occurrenceDate == original.date) {
          events[i] = edited;
          rescheduleOriginal = edited;
          return;
        }
        final previousDate = _addDaysIso(occurrenceDate, -1);
        events[i] = _eventCopyWith(original, endDate: previousDate);
        final future = _eventCopyWith(
          edited,
          id: uid(),
          date: occurrenceDate,
          exceptions: const [],
          createdBy: original.createdBy,
        );
        events.add(future);
        rescheduleOriginal = events[i];
        rescheduleNew = future;
      } else {
        events[i] = edited;
        rescheduleOriginal = edited;
      }
    }, () => flash('Event updated'));
    if (rescheduleOriginal != null) {
      NotificationService.instance.scheduleEventReminder(rescheduleOriginal!);
    }
    if (rescheduleNew != null) {
      NotificationService.instance.scheduleEventReminder(rescheduleNew!);
    }
    if (changed) _syncDeviceCalendar();
  }

  /// `scope == 'one'` removes only the occurrence on [date] (recorded as an
  /// exception on a recurring event); `scope == 'future'` keeps occurrences
  /// before [date]; `scope == 'all'` deletes the series.
  void deleteEvent(String id, String scope, [String? date]) {
    var changed = false;
    var removedSeries = false;
    CalendarEvent? updated;
    mutate(() {
      final ev = eventById(id);
      if (ev == null) return;
      changed = true;
      if (scope == 'one' && ev.recur != 'none' && date != null) {
        ev.exceptions = {...ev.exceptions, date}.toList();
        updated = ev;
      } else if (scope == 'future' && ev.recur != 'none' && date != null) {
        if (date == ev.date) {
          events.removeWhere((x) => x.id == id);
          removedSeries = true;
        } else {
          ev.endDate = _addDaysIso(date, -1);
          updated = ev;
        }
      } else {
        events.removeWhere((x) => x.id == id);
        removedSeries = true;
      }
    }, () => flash('Event deleted'));
    if (removedSeries) {
      NotificationService.instance.cancelEventReminder(id);
    } else if (updated != null) {
      NotificationService.instance.scheduleEventReminder(updated!);
    }
    if (changed) _syncDeviceCalendar();
  }

  // ---------------------------------------------------------- categories
  void openCategory(EventCategory? cat, {String layerId = kLayerAppt}) {
    _showSheet(
      (ctx) => _CategorySheet(state: this, category: cat, layerId: layerId),
    );
  }

  void openCalendarLayer(CalendarLayerDef layer) {
    _showSheet((ctx) => _LayerSheet(state: this, layer: layer));
  }

  void saveCategory({
    String? id,
    required String name,
    required Color color,
    required String icon,
    String? emoji,
    String? picture,
    required List<String> members,
    String layerId = kLayerAppt,
  }) {
    final wasEditing = id != null;
    if (!isCalendarIdentityColorAvailable(color, exceptCategoryId: id)) {
      flash('That colour is already used');
      return;
    }
    mutate(() {
      final cat = EventCategory(
        id: id ?? uid(),
        name: name.trim().isEmpty ? 'Category' : name.trim(),
        color: color,
        icon: icon,
        emoji: emoji,
        picture: picture,
        members: members,
        layerId: layerId,
      );
      final i = eventCategories.indexWhere((x) => x.id == cat.id);
      if (i >= 0) {
        eventCategories[i] = cat;
      } else {
        eventCategories.add(cat);
      }
      for (final event in events) {
        if (event.category == cat.id) event.color = cat.color;
      }
    }, () => flash(wasEditing ? 'Category updated' : 'Category added'));
  }

  void deleteCategory(String id) {
    mutate(() {
      eventCategories.removeWhere((c) => c.id == id);
      for (final e in events) {
        if (e.category == id) e.category = null;
      }
    }, () => flash('Category deleted'));
  }

  // -------------------------------------------------------------- imports
  void openCalendarManageSheet({
    _CalManageMode mode = _CalManageMode.categories,
  }) {
    _showSheet((ctx) => _CalendarManageSheet(state: this, mode: mode));
  }

  void openImportCalendarSheet() {
    _showSheet((ctx) => _ImportCalendarSheet(state: this));
  }

  void openEditImportCalendarSheet(ImportedCalendar calendar) {
    _showSheet((ctx) => _ImportCalendarSheet(state: this, calendar: calendar));
  }

  /// Imports a calendar from an ICS/web-link feed at [url] (e.g. an ecal.com
  /// or other calendar-subscription link, RFC 5545) — the only supported
  /// import source; Google/Apple account sync is out of scope (#161).
  /// Returns a user-facing error message, or `null` on success.
  Future<String?> saveImport({
    required String name,
    required String url,
    String? category,
    Color? color,
    bool autoSync = true,
    bool includeLocation = true,
    bool includeDescription = true,
    String reminder = '1h',
  }) async {
    final calName = name.trim().isEmpty
        ? kImportProviders['ics']!.$1
        : name.trim();

    List<ImportedCalendarEvent> events;
    try {
      events = await fetchIcsEvents(url);
    } on IcsImportException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('[calendar] ics import failed: $e');
      return 'Could not import that calendar';
    }

    mutate(
      () {
        importedCalendars.add(
          ImportedCalendar(
            id: uid(),
            name: calName,
            provider: 'ics',
            color: color ?? kImportProviders['ics']!.$2,
            category: category,
            url: url.trim(),
            autoSync: autoSync,
            includeLocation: includeLocation,
            includeDescription: includeDescription,
            reminder: reminder,
            events: _applyImportPrefs(
              events,
              includeLocation: includeLocation,
              includeDescription: includeDescription,
            ),
          ),
        );
      },
      () => flash(
        'Calendar imported (${events.length} event${events.length == 1 ? '' : 's'})',
      ),
    );
    return null;
  }

  Future<String?> updateImport({
    required String id,
    required String name,
    required String url,
    required String? category,
    required Color color,
    required bool visible,
    required bool autoSync,
    required bool includeLocation,
    required bool includeDescription,
    String reminder = '1h',
  }) async {
    ImportedCalendar? cal;
    for (final c in importedCalendars) {
      if (c.id == id) cal = c;
    }
    if (cal == null) return 'Calendar not found';

    final trimmedUrl = url.trim();
    final urlChanged = (cal.url ?? '') != trimmedUrl;
    List<ImportedCalendarEvent>? fetchedEvents;
    if (urlChanged) {
      try {
        fetchedEvents = await fetchIcsEvents(trimmedUrl);
      } on IcsImportException catch (e) {
        return e.message;
      } catch (e) {
        debugPrint('[calendar] ics import update failed: $e');
        return 'Could not update that calendar';
      }
    }

    mutate(
      () {
        final resolvedCal = cal!;
        resolvedCal.name = name.trim().isEmpty
            ? kImportProviders[resolvedCal.provider]?.$1 ?? 'Imported calendar'
            : name.trim();
        resolvedCal.color = color;
        resolvedCal.category = category;
        resolvedCal.visible = visible;
        resolvedCal.url = trimmedUrl.isEmpty ? null : trimmedUrl;
        resolvedCal.autoSync = autoSync;
        resolvedCal.includeLocation = includeLocation;
        resolvedCal.includeDescription = includeDescription;
        resolvedCal.reminder = reminder;
        resolvedCal.events = _applyImportPrefs(
          fetchedEvents ?? resolvedCal.events,
          includeLocation: includeLocation,
          includeDescription: includeDescription,
        );
      },
      () => flash(
        fetchedEvents == null
            ? 'Calendar settings updated'
            : 'Calendar updated (${fetchedEvents.length} event${fetchedEvents.length == 1 ? '' : 's'})',
      ),
    );
    return null;
  }

  void toggleImportVisible(String id) {
    mutate(() {
      for (final c in importedCalendars) {
        if (c.id == id) c.visible = !c.visible;
      }
    });
  }

  void toggleImportAutoSync(String id) {
    mutate(() {
      for (final c in importedCalendars) {
        if (c.id == id) c.autoSync = !c.autoSync;
      }
    });
  }

  /// Toggles whether a calendar's events keep their feed-provided location or
  /// description, stripping (or, on the next sync, re-fetching) accordingly.
  void toggleImportField(String id, {required bool location}) {
    mutate(() {
      for (final c in importedCalendars) {
        if (c.id != id) continue;
        if (location) {
          c.includeLocation = !c.includeLocation;
        } else {
          c.includeDescription = !c.includeDescription;
        }
        c.events = _applyImportPrefs(
          c.events,
          includeLocation: c.includeLocation,
          includeDescription: c.includeDescription,
        );
      }
    });
  }

  void deleteImport(String id) {
    mutate(() {
      importedCalendars.removeWhere((c) => c.id == id);
    }, () => flash('Calendar removed'));
  }

  /// Re-fetches an `ics` import's feed and replaces its events. Returns a
  /// user-facing error message, or `null` on success. Pass [silent] for
  /// background syncs that shouldn't show a toast on success.
  Future<String?> refreshImport(String id, {bool silent = false}) async {
    ImportedCalendar? cal;
    for (final c in importedCalendars) {
      if (c.id == id) cal = c;
    }
    final url = cal?.url;
    if (cal == null || url == null || url.isEmpty) {
      return 'This calendar has no link to sync';
    }
    final resolvedCal = cal;

    List<ImportedCalendarEvent> events;
    try {
      events = await fetchIcsEvents(url);
    } on IcsImportException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('[calendar] ics refresh failed: $e');
      return 'Could not sync that calendar';
    }

    mutate(
      () {
        resolvedCal.events = _applyImportPrefs(
          events,
          includeLocation: resolvedCal.includeLocation,
          includeDescription: resolvedCal.includeDescription,
        );
      },
      silent
          ? null
          : () => flash(
              'Calendar synced (${events.length} event${events.length == 1 ? '' : 's'})',
            ),
    );
    return null;
  }

  /// Silently re-syncs every `ics` import with [ImportedCalendar.autoSync] on,
  /// meant to run on app open/resume so subscribed calendars (e.g. a sports
  /// team's schedule) stay current without the user having to remember to
  /// tap "sync". Failures are logged, not surfaced, so one bad feed doesn't
  /// interrupt app startup.
  Future<void> syncDueImports() async {
    final now = DateTime.now();
    final due = [
      for (final c in importedCalendars)
        if (c.provider == 'ics' &&
            c.autoSync &&
            (c.url ?? '').isNotEmpty &&
            (_lastAutoSync[c.id] == null ||
                now.difference(_lastAutoSync[c.id]!) >= _autoSyncInterval))
          c,
    ];
    if (due.isEmpty) return;

    // Fetch every due feed concurrently (each has its own 20s timeout), then
    // apply all results in a single mutate so app open/resume persists state
    // once instead of once per feed.
    final results = await Future.wait([
      for (final c in due)
        fetchIcsEvents(c.url!).then<Object>(
          (events) => events,
          onError: (Object e) =>
              e is IcsImportException ? e.message : 'Could not sync that calendar',
        ),
    ]);

    final synced = <ImportedCalendar, List<ImportedCalendarEvent>>{};
    for (var i = 0; i < due.length; i++) {
      final result = results[i];
      if (result is List<ImportedCalendarEvent>) {
        synced[due[i]] = result;
        _lastAutoSync[due[i].id] = now;
      } else {
        debugPrint('[calendar] auto-sync ${due[i].id} failed: $result');
      }
    }
    if (synced.isEmpty) return;

    mutate(() {
      synced.forEach((cal, events) {
        cal.events = _applyImportPrefs(
          events,
          includeLocation: cal.includeLocation,
          includeDescription: cal.includeDescription,
        );
      });
    });
  }
}

/// In-memory record of when each `ics` import last auto-synced this app
/// session, so open/resume doesn't re-fetch feeds more than once per
/// [_autoSyncInterval].
final Map<String, DateTime> _lastAutoSync = {};
const Duration _autoSyncInterval = Duration(hours: 1);
