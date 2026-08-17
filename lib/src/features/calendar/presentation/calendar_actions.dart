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
    this.isTask = false,
    this.isContent = false,
  }) : spanEnd = spanEnd ?? date;
  final CalendarEvent ev;

  /// First day of this occurrence.
  final String date;

  /// Last day of this occurrence — equal to [date] unless this is a
  /// multi-day span (`ev.endDate`).
  final String spanEnd;
  final bool imported;

  /// True when this occurrence is a task's due date (issue #199) rather
  /// than a real or imported calendar event. Task occurrences are
  /// read-only apart from their checkbox, but keep their assignee visible.
  final bool isTask;

  /// True when this occurrence is a content-creation task (a [TaskList]
  /// with `kind: 'content'`) rather than a household chore.
  final bool isContent;

  /// Which calendar layer this occurrence belongs to — one of
  /// `appt|task|content` — used by the layer-toggle filter.
  String get layer => isContent ? 'content' : (isTask ? 'task' : 'appt');

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

String _addMonthsIso(String iso, int n) {
  final d = _parseIso(iso);
  final total = d.month - 1 + n;
  final y = d.year + total ~/ 12;
  final m = total % 12 + 1;
  final lastDay = DateTime.utc(y, m + 1, 0).day;
  return _isoOf(y, m, d.day > lastDay ? lastDay : d.day);
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
  if (ev.recur == 'daily') return _addDaysIso(current, 1);
  if (ev.recur == 'weekly') return _addDaysIso(current, 7);
  if (ev.recur == 'monthly') return _addMonthsIso(current, 1);
  if (ev.recur == 'yearly') return _addMonthsIso(current, 12);
  if (ev.recur != 'custom') return null;

  final every = _customRepeatEvery(ev);
  final unit = _customRepeatUnit(ev);
  if (unit == 'day') return _addDaysIso(current, every);
  if (unit == 'month') return _addMonthsIso(current, every);
  if (unit == 'year') return _addMonthsIso(current, 12 * every);

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
  var guard = 0;
  while (d.compareTo(rangeEnd) <= 0 &&
      d.compareTo(repeatEnd) <= 0 &&
      guard < maxOccurrences) {
    if (d.compareTo(rangeStart) >= 0 && !ev.exceptions.contains(d)) {
      dates.add(d);
    }
    final next = _nextRecurringDate(ev, d);
    if (next == null || next.compareTo(d) <= 0) break;
    d = next;
    guard++;
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

  /// Builds the read-only [CalendarEvent] used to render/view a task's due
  /// date on the calendar (issue #199), keyed by the composite
  /// `'task_${list.id}_${task.id}'` id. Has no [category], so [evColor]
  /// resolves its colour from the assignee's member colour, falling back
  /// to the list's own colour when unassigned.
  CalendarEvent taskSyntheticEvent(TaskList list, ListTask task) {
    return CalendarEvent(
      id: 'task_${list.id}_${task.id}',
      title: task.title,
      allDay: true,
      date: task.due!,
      color: list.color,
      attendees: task.assignee != null ? [task.assignee!] : const [],
      recur: task.recur,
      recurEvery: task.recurEvery,
      recurUnit: task.recurUnit,
      recurWeekdays: task.recurWeekdays,
      exceptions: task.exceptions,
      reminder: 'none',
      createdBy: list.name,
    );
  }

  Color evColor(CalendarEvent ev) {
    final category = catById(ev.category);
    if (category != null) return category.color;
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
    final apptLayerOn = layerFilter.contains('appt');

    for (final ev in apptLayerOn ? events : const <CalendarEvent>[]) {
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
          out.add(CalendarOccurrence(ev: ev, date: ev.date, spanEnd: spanEnd));
        }
        continue;
      }

      for (final d in recurringEventDates(ev, rangeStart, rangeEnd)) {
        out.add(CalendarOccurrence(ev: ev, date: d));
      }
    }

    // Imported calendars are read-only and have no direct attendees, so when
    // member filters are active we match them via their assigned category.
    for (final cal in apptLayerOn ? importedCalendars : const <ImportedCalendar>[]) {
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

    // Tasks with a due date show up on the calendar coloured by their
    // assignee (issue #199); category filters (tasks have no category)
    // hide them. Recurring tasks (#208) expand like recurring events, and
    // completion is tracked per-occurrence instead of hiding the series.
    for (final list in taskLists) {
      final layerId = list.kind == 'content' ? 'content' : 'task';
      if (!layerFilter.contains(layerId)) continue;
      for (final task in list.tasks) {
        final due = task.due;
        if (due == null || due.isEmpty) continue;
        if (cflt.isNotEmpty) continue;
        if (flt.isNotEmpty &&
            !(task.assignee != null && flt.contains(task.assignee))) {
          continue;
        }
        final synth = taskSyntheticEvent(list, task);
        if (task.recur == 'none') {
          if (task.done) continue;
          if (due.compareTo(rangeStart) >= 0 && due.compareTo(rangeEnd) <= 0) {
            out.add(
              CalendarOccurrence(
                isTask: true,
                isContent: list.kind == 'content',
                date: due,
                ev: synth,
              ),
            );
          }
          continue;
        }
        for (final d in recurringEventDates(synth, rangeStart, rangeEnd)) {
          if (task.isDoneOn(d)) continue;
          out.add(
            CalendarOccurrence(
              isTask: true,
              isContent: list.kind == 'content',
              date: d,
              ev: synth,
            ),
          );
        }
      }
    }
    return out;
  }

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

  /// Looks up an occurrence's id across real, imported, and task-derived
  /// events. Real events are mutable; imported and task ones are
  /// synthesized read-only and can be viewed but never edited/deleted.
  /// [taskListId] is set (to the owning [TaskList.id]) only when [isTask].
  ({CalendarEvent? ev, bool imported, bool isTask, String? taskListId})
  eventOrImportedById(String id) {
    final real = eventById(id);
    if (real != null) {
      return (ev: real, imported: false, isTask: false, taskListId: null);
    }
    for (final cal in importedCalendars) {
      for (final e in cal.events) {
        if ('${cal.id}_${e.id}' == id) {
          return (
            ev: importedSyntheticEvent(cal, e),
            imported: true,
            isTask: false,
            taskListId: null,
          );
        }
      }
    }
    for (final list in taskLists) {
      for (final task in list.tasks) {
        if ('task_${list.id}_${task.id}' == id) {
          return (
            ev: taskSyntheticEvent(list, task),
            imported: false,
            isTask: true,
            taskListId: list.id,
          );
        }
      }
    }
    return (ev: null, imported: false, isTask: false, taskListId: null);
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
  }) {
    final wasEditing = id != null;
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
    );
  }

  void saveRecurringEventScoped({
    required String id,
    required String scope,
    required String occurrenceDate,
    required CalendarEvent edited,
  }) {
    CalendarEvent? rescheduleOriginal;
    CalendarEvent? rescheduleNew;
    mutate(() {
      final i = events.indexWhere((x) => x.id == id);
      if (i < 0) return;
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
  }

  /// `scope == 'one'` removes only the occurrence on [date] (recorded as an
  /// exception on a recurring event); `scope == 'future'` keeps occurrences
  /// before [date]; `scope == 'all'` deletes the series.
  void deleteEvent(String id, String scope, [String? date]) {
    var removedSeries = false;
    CalendarEvent? updated;
    mutate(() {
      final ev = eventById(id);
      if (ev == null) return;
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
  }

  // ---------------------------------------------------------- categories
  void openCategory(EventCategory? cat) {
    _showSheet((ctx) => _CategorySheet(state: this, category: cat));
  }

  void saveCategory({
    String? id,
    required String name,
    required Color color,
    required String icon,
    String? emoji,
    String? picture,
    required List<String> members,
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
    final due = [
      for (final c in importedCalendars)
        if (c.provider == 'ics' && c.autoSync && (c.url ?? '').isNotEmpty) c.id,
    ];
    for (final id in due) {
      final err = await refreshImport(id, silent: true);
      if (err != null) debugPrint('[calendar] auto-sync $id failed: $err');
    }
  }
}
