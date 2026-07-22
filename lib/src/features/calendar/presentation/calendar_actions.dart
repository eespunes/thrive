part of 'package:family_money_management_app/main.dart';

/// An event occurrence on a given date — either a real [CalendarEvent]
/// (possibly a recurrence instance) or an imported (read-only) event
/// surfaced through a synthetic [CalendarEvent] for uniform rendering.
class CalendarOccurrence {
  CalendarOccurrence({
    required this.ev,
    required this.date,
    String? spanEnd,
    this.imported = false,
  }) : spanEnd = spanEnd ?? date;
  final CalendarEvent ev;

  /// First day of this occurrence.
  final String date;

  /// Last day of this occurrence — equal to [date] unless this is a
  /// multi-day span (`ev.endDate`).
  final String spanEnd;
  final bool imported;

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
      radius: size / 2,
      picture: c.picture,
      emoji: c.emoji,
      emojiSize: size * 0.62,
      fallback: Center(
        child: ic(c.icon, size: size * 0.66, sw: 2.2, color: iconColor),
      ),
    ),
  );
}

const List<Color> kEventColors = [
  Color(0xff1684B4),
  Color(0xff0E9A8D),
  Color(0xff0f9d6a),
  Color(0xffd97706),
  Color(0xff7c3aed),
  Color(0xffe11d48),
];

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
  Color(0xff1684B4),
  Color(0xff0f9d6a),
  Color(0xffe11d48),
  Color(0xffd97706),
  Color(0xff0E9A8D),
  Color(0xff0d9488),
  Color(0xff475569),
];

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

String _prettyDateIso(String iso) {
  final d = _parseIso(iso);
  return '${kMonthsEn[d.month - 1]} ${d.day}, ${d.year}';
}

String _shortDateIso(String iso) {
  final d = _parseIso(iso);
  return '${kMonthsShort[d.month - 1]} ${d.day}';
}

String _monthTitleIso(String iso) {
  final d = _parseIso(iso);
  return '${kMonthsEn[d.month - 1]} ${d.year}';
}

/// Parses `HH:MM` into minutes-since-midnight; empty/invalid → 0.
int _toMinutes(String hhmm) {
  if (hhmm.isEmpty) return 0;
  final parts = hhmm.split(':');
  if (parts.length != 2) return 0;
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}

String _weekRangeIso(String weekStartIso) {
  final start = _parseIso(weekStartIso);
  final end = _parseIso(_addDaysIso(weekStartIso, 6));
  if (start.month == end.month) {
    return '${kMonthsShort[start.month - 1]} ${start.day}–${end.day}';
  }
  return '${kMonthsShort[start.month - 1]} ${start.day} – '
      '${kMonthsShort[end.month - 1]} ${end.day}';
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
      attendees: const [],
      recur: 'none',
      createdBy: cal.name,
    );
  }

  Color evColor(CalendarEvent ev) => catById(ev.category)?.color ?? ev.color;

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

    for (final ev in events) {
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

      var d = ev.date;
      var guard = 0;
      while (d.compareTo(rangeEnd) <= 0 && guard < 900) {
        if (d.compareTo(rangeStart) >= 0 && !ev.exceptions.contains(d)) {
          out.add(CalendarOccurrence(ev: ev, date: d));
        }
        if (ev.recur == 'daily') {
          d = _addDaysIso(d, 1);
        } else if (ev.recur == 'weekly') {
          d = _addDaysIso(d, 7);
        } else if (ev.recur == 'monthly') {
          d = _addMonthsIso(d, 1);
        } else if (ev.recur == 'yearly') {
          d = _addMonthsIso(d, 12);
        } else {
          break;
        }
        guard++;
      }
    }

    // Imported calendars are read-only and hidden when a person filter is
    // active (they have no attendees), matching the design.
    if (flt.isEmpty) {
      for (final cal in importedCalendars) {
        if (!cal.visible) continue;
        if (cflt.isNotEmpty && !cflt.contains(cal.category)) continue;
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

  void calStep(int dir) {
    update(() {
      calAnchor = (calView == 'week' || calView == 'family')
          ? _addDaysIso(calAnchor, 7 * dir)
          : _addMonthsIso(calAnchor, dir);
    });
  }

  void calToday() {
    update(() {
      calAnchor = todayIso();
      calSel = todayIso();
    });
  }

  void setCalView(String v) => update(() => calView = v);
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

  /// Overlap-aware column packing for Week-view timed events on a single
  /// day: assigns each occurrence a `col`/`cols` (total columns in its
  /// overlap cluster) so overlapping blocks split the day column's width.
  List<({CalendarOccurrence o, int col, int cols})> packTimedColumns(
    List<CalendarOccurrence> timed,
  ) {
    final starts = [for (final o in timed) _toMinutes(o.ev.start)];
    final ends = [
      for (final o in timed)
        _toMinutes(o.ev.end.isNotEmpty ? o.ev.end : o.ev.start),
    ];
    final cols = List<int>.filled(timed.length, 0);
    final active = <(int col, int end)>[];
    for (var i = 0; i < timed.length; i++) {
      active.removeWhere((a) => a.$2 <= starts[i]);
      var col = 0;
      final used = active.map((a) => a.$1).toSet();
      while (used.contains(col)) {
        col++;
      }
      cols[i] = col;
      active.add((col, ends[i]));
    }
    final total = List<int>.filled(timed.length, 1);
    for (var i = 0; i < timed.length; i++) {
      var m = cols[i] + 1;
      for (var j = 0; j < timed.length; j++) {
        if (starts[j] < ends[i] && ends[j] > starts[i]) {
          m = m > cols[j] + 1 ? m : cols[j] + 1;
        }
      }
      total[i] = m;
    }
    // Normalize each overlap cluster to the same column count.
    for (var i = 0; i < timed.length; i++) {
      var m = total[i];
      for (var j = 0; j < timed.length; j++) {
        if (starts[j] < ends[i] && ends[j] > starts[i]) {
          m = m > total[j] ? m : total[j];
        }
      }
      total[i] = m;
    }
    return [
      for (var i = 0; i < timed.length; i++)
        (o: timed[i], col: cols[i], cols: total[i]),
    ];
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

  /// Looks up an occurrence's id across both real and imported events. Real
  /// events are mutable; imported ones are synthesized read-only and can be
  /// viewed but never edited/deleted.
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
    List<String>? exceptions,
    String? createdBy,
  }) {
    final wasEditing = id != null;
    mutate(() {
      final ev = CalendarEvent(
        id: id ?? uid(),
        title: title.trim().isEmpty ? 'Untitled' : title.trim(),
        allDay: allDay,
        date: date,
        endDate: recur == 'none' ? endDate : '',
        start: allDay ? '' : start,
        end: allDay ? '' : end,
        location: location.trim(),
        notes: notes.trim(),
        category: category,
        color: color,
        attendees: attendees.isEmpty ? ['me'] : attendees,
        reminder: reminder,
        recur: recur,
        createdBy: createdBy ?? 'me',
        exceptions: exceptions ?? const [],
      );
      final i = events.indexWhere((x) => x.id == ev.id);
      if (i >= 0) {
        events[i] = ev;
      } else {
        events.add(ev);
      }
    }, () => flash(wasEditing ? 'Event updated' : 'Event added'));
  }

  /// `scope == 'one'` removes only the occurrence on [date] (recorded as an
  /// exception on a recurring event); `scope == 'all'` deletes the event.
  void deleteEvent(String id, String scope, [String? date]) {
    mutate(() {
      final ev = eventById(id);
      if (ev == null) return;
      if (scope == 'one' && ev.recur != 'none' && date != null) {
        ev.exceptions = [...ev.exceptions, date];
      } else {
        events.removeWhere((x) => x.id == id);
      }
    }, () => flash('Event deleted'));
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
  void openCalendarManageSheet() {
    _showSheet((ctx) => _CalendarManageSheet(state: this));
  }

  void openImportCalendarSheet() {
    _showSheet((ctx) => _ImportCalendarSheet(state: this));
  }

  /// Imports a calendar from an ICS/web-link feed at [url] (e.g. an ecal.com
  /// or other calendar-subscription link, RFC 5545) — the only supported
  /// import source; Google/Apple account sync is out of scope (#161).
  /// Returns a user-facing error message, or `null` on success.
  Future<String?> saveImport({
    required String name,
    required String url,
    String? category,
    bool autoSync = true,
    bool includeLocation = true,
    bool includeDescription = true,
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
            color: kImportProviders['ics']!.$2,
            category: category,
            url: url.trim(),
            autoSync: autoSync,
            includeLocation: includeLocation,
            includeDescription: includeDescription,
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
