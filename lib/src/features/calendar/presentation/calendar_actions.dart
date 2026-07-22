part of 'package:family_money_management_app/main.dart';

/// An event occurrence on a given date — either a real [CalendarEvent]
/// (possibly a recurrence instance) or an imported (read-only) event
/// surfaced through a synthetic [CalendarEvent] for uniform rendering.
class CalendarOccurrence {
  CalendarOccurrence({
    required this.ev,
    required this.date,
    this.imported = false,
  });
  final CalendarEvent ev;
  final String date;
  final bool imported;
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

  /// Expands recurring events (minus their `exceptions`) and appends visible
  /// imported-calendar events, within `[rangeStart, rangeEnd]` (inclusive,
  /// ISO dates), honouring the active member/category filters. Mirrors the
  /// design's `eventOccurrences()`.
  List<CalendarOccurrence> eventOccurrences(
    String rangeStart,
    String rangeEnd,
  ) {
    final out = <CalendarOccurrence>[];
    final flt = calFilter;
    final cflt = calCatFilter;

    for (final ev in events) {
      if (flt != null && !ev.attendees.contains(flt)) continue;
      if (cflt != null && ev.category != cflt) continue;
      void push(String d) {
        if (d.compareTo(rangeStart) >= 0 &&
            d.compareTo(rangeEnd) <= 0 &&
            !ev.exceptions.contains(d)) {
          out.add(CalendarOccurrence(ev: ev, date: d));
        }
      }

      if (ev.recur == 'none') {
        push(ev.date);
        continue;
      }
      var d = ev.date;
      var guard = 0;
      while (d.compareTo(rangeEnd) <= 0 && guard < 900) {
        push(d);
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
    if (flt == null) {
      for (final cal in importedCalendars) {
        if (!cal.visible) continue;
        if (cflt != null && cal.category != cflt) continue;
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
      calAnchor = calView == 'week'
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
  void setCalFilter(String? memberId) => update(() => calFilter = memberId);
  void setCalCatFilter(String? catId) =>
      update(() => calCatFilter = calCatFilter == catId ? null : catId);

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
