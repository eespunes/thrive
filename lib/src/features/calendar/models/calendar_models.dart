part of 'package:family_money_management_app/main.dart';

/// A shared family calendar event, mirrors the design's event shape.
class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    this.allDay = false,
    required this.date,
    this.endDate = '',
    this.start = '',
    this.end = '',
    this.location = '',
    this.notes = '',
    this.category,
    required this.color,
    List<String>? attendees,
    this.reminder = '1h',
    this.recur = 'none',
    this.recurEvery = 1,
    this.recurUnit = 'week',
    List<int>? recurWeekdays,
    this.createdBy,
    List<String>? exceptions,
    this.layerId = 'appt',
    this.done = false,
    Map<String, bool>? doneDates,
    this.kitchenOrigin = false,
    this.picture,
  }) : attendees = attendees ?? <String>['me'],
       recurWeekdays = recurWeekdays ?? <int>[],
       exceptions = exceptions ?? <String>[],
       doneDates = doneDates ?? <String, bool>{};

  String id;
  String title;
  bool allDay;

  /// ISO `YYYY-MM-DD` first occurrence date.
  String date;

  /// ISO `YYYY-MM-DD` last day of a multi-day span when [recur] is `'none'`,
  /// or the inclusive repeat-until date for recurring events.
  String endDate;

  /// `HH:MM`, empty when [allDay] is true.
  String start;
  String end;
  String location;
  String notes;

  /// [EventCategory.id] this event belongs to, or `null`.
  String? category;
  Color color;

  /// Family member ids attending.
  List<String> attendees;

  /// `none` | `at` | `5m` | `15m` | `30m` | `1h` | `2h` | `1d` | `2d`.
  String reminder;

  /// `none` | `daily` | `weekly` | `monthly` | `yearly` | `custom`.
  String recur;

  /// Custom repeat interval. Meaningful when [recur] is `'custom'`.
  int recurEvery;

  /// Custom repeat unit: `day` | `week` | `month` | `year`.
  String recurUnit;

  /// ISO weekday numbers (1=Mon .. 7=Sun) for custom weekly repeats.
  List<int> recurWeekdays;

  String? createdBy;

  /// ISO dates removed from a recurring series (single-occurrence deletes).
  List<String> exceptions;

  /// The [CalendarLayerDef.id] this event belongs to — `appt` (the default,
  /// preserving pre-layers behaviour), `task`, `content`, or any custom
  /// layer id. Every layer's items are just [CalendarEvent]s tagged with a
  /// [layerId]; the calendar reads this field directly instead of
  /// synthesizing task/content occurrences from `TaskList`/`ListTask`.
  String layerId;

  /// Completion state for a non-recurring task-like event (any layer, not
  /// just `task`). For a recurring event, completion is tracked
  /// per-occurrence in [doneDates] instead — this field is ignored in that
  /// case. Meaningless for plain appointments but harmless.
  bool done;

  /// ISO date -> completed, for occurrence completion of a recurring
  /// task-like event. Mirrors `ListTask.doneDates`.
  Map<String, bool> doneDates;

  /// True only for events created directly on the Kitchen dashboard's
  /// quick-add sheet (as opposed to the phone's event editor). Kitchen-origin
  /// items show a remove (×) control on the dashboard and can be deleted from
  /// there; phone-created items cannot (they're edited/removed from the
  /// phone's calendar instead). Purely a UI/permission flag — kitchen-origin
  /// events are otherwise ordinary [CalendarEvent]s, so they render on the
  /// phone's Agenda/Month views exactly like any other to-do/content item.
  bool kitchenOrigin;

  /// Optional base64 photo for this item's Kitchen-dashboard picture-mode
  /// tile (set by a parent after the item is created; see [_GlyphPicker]'s
  /// picture-encoding pattern). Unused in text mode.
  String? picture;

  /// Whether the occurrence on [iso] is completed. Falls back to [done] for
  /// non-recurring events so old data with only a `done` flag keeps working.
  bool isDoneOn(String iso) =>
      recur == 'none' ? done : (doneDates[iso] ?? false);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'allDay': allDay,
    'date': date,
    if (endDate.isNotEmpty) 'endDate': endDate,
    'start': start,
    'end': end,
    'location': location,
    'notes': notes,
    if (category != null) 'category': category,
    'color': color.toARGB32(),
    'attendees': attendees,
    'reminder': reminder,
    'recur': recur,
    if (recurEvery != 1) 'recurEvery': recurEvery,
    if (recurUnit != 'week') 'recurUnit': recurUnit,
    if (recurWeekdays.isNotEmpty) 'recurWeekdays': recurWeekdays,
    if (createdBy != null) 'createdBy': createdBy,
    'exceptions': exceptions,
    if (layerId != 'appt') 'layerId': layerId,
    'done': done,
    if (doneDates.isNotEmpty) 'doneDates': doneDates,
    if (kitchenOrigin) 'kitchenOrigin': kitchenOrigin,
    if (picture != null) 'picture': picture,
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
    id: (j['id'] ?? uid()).toString(),
    title: (j['title'] ?? 'Untitled').toString(),
    allDay: j['allDay'] == true,
    date: (j['date'] ?? todayIso()).toString(),
    endDate: (j['endDate'] ?? '').toString(),
    start: (j['start'] ?? '').toString(),
    end: (j['end'] ?? '').toString(),
    location: (j['location'] ?? '').toString(),
    notes: (j['notes'] ?? '').toString(),
    category: j['category']?.toString(),
    color: Color((j['color'] as num?)?.toInt() ?? 0xff1684B4),
    attendees: [
      for (final a in (j['attendees'] as List? ?? ['me'])) a.toString(),
    ],
    reminder: (j['reminder'] ?? '1h').toString(),
    recur: (j['recur'] ?? 'none').toString(),
    recurEvery: ((j['recurEvery'] as num?)?.toInt() ?? 1).clamp(1, 999),
    recurUnit: (j['recurUnit'] ?? 'week').toString(),
    recurWeekdays: [
      for (final d in (j['recurWeekdays'] as List? ?? const []))
        if ((d as num?)?.toInt() case final weekday?
            when weekday >= 1 && weekday <= 7)
          weekday,
    ],
    createdBy: j['createdBy']?.toString(),
    exceptions: [
      for (final e in (j['exceptions'] as List? ?? [])) e.toString(),
    ],
    layerId: (j['layerId'] as String?)?.isNotEmpty == true
        ? j['layerId'] as String
        : 'appt',
    done: j['done'] == true,
    doneDates: {
      for (final entry in (j['doneDates'] as Map? ?? {}).entries)
        entry.key.toString(): entry.value == true,
    },
    kitchenOrigin: j['kitchenOrigin'] == true,
    picture: (j['picture'] as String?)?.isNotEmpty == true
        ? j['picture'] as String
        : null,
  );
}

/// An event category — drives colour/icon tinting across the calendar.
class EventCategory {
  EventCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.emoji,
    this.picture,
    List<String>? members,
    this.layerId = 'appt',
  }) : members = members ?? <String>[];

  String id;
  String name;
  Color color;

  /// The [CalendarLayerDef.id] this category is scoped to — categories are
  /// layer-scoped, so the event editor only offers categories whose
  /// [layerId] matches the event's selected layer. Defaults to `appt` for
  /// backward compatibility with categories saved before layer-scoping.
  String layerId;

  /// Legacy stroke-icon name, rendered only as the fallback when no
  /// [emoji]/[picture] is set (matches the budget block picker, issue #131).
  String icon;

  /// Optional emoji shown instead of the icon.
  String? emoji;

  /// Optional base64 picture shown instead of the emoji/icon.
  String? picture;

  /// Family member ids typically assigned to events of this category.
  List<String> members;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.toARGB32(),
    'icon': icon,
    if (emoji != null) 'emoji': emoji,
    if (picture != null) 'picture': picture,
    'members': members,
    if (layerId != 'appt') 'layerId': layerId,
  };

  factory EventCategory.fromJson(Map<String, dynamic> j) => EventCategory(
    id: (j['id'] ?? uid()).toString(),
    name: (j['name'] ?? 'Category').toString(),
    color: Color((j['color'] as num?)?.toInt() ?? 0xff7c3aed),
    icon: (j['icon'] ?? 'briefcase').toString(),
    emoji: (j['emoji'] as String?)?.isNotEmpty == true ? j['emoji'] : null,
    picture: (j['picture'] as String?)?.isNotEmpty == true
        ? j['picture']
        : null,
    members: [for (final m in (j['members'] as List? ?? [])) m.toString()],
    layerId: (j['layerId'] as String?)?.isNotEmpty == true
        ? j['layerId'] as String
        : 'appt',
  );
}

/// A user-customizable calendar layer definition — drives the calendar's
/// layer-toggle chips/sections, the Agenda view's section order, week-strip
/// dots and Month-view bar colours. The 3 built-ins (`appt`/`task`/
/// `content`) are [core] — they can be toggled/reordered but not deleted.
/// Order in [Workspace.calendarLayers] IS the display order (mirrors the
/// design's `layerDefs`/`moveLayer`).
class CalendarLayerDef {
  CalendarLayerDef({
    required this.id,
    required this.label,
    required this.icon,
    this.emoji,
    this.picture,
    required this.color,
    this.core = false,
  });

  String id;
  String label;

  /// Legacy stroke-icon name, rendered only as the fallback when no
  /// [emoji]/[picture] is set (matches [EventCategory.icon]).
  String icon;

  /// Optional emoji shown instead of the icon.
  String? emoji;

  /// Optional base64 picture shown instead of the emoji/icon.
  String? picture;
  Color color;

  /// True for the 3 built-in layers (`appt`/`task`/`content`), which can be
  /// toggled/reordered but never deleted.
  bool core;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'icon': icon,
    if (emoji != null) 'emoji': emoji,
    if (picture != null) 'picture': picture,
    'color': color.toARGB32(),
    'core': core,
  };

  factory CalendarLayerDef.fromJson(Map<String, dynamic> j) => CalendarLayerDef(
    id: (j['id'] ?? uid()).toString(),
    label: (j['label'] ?? 'Layer').toString(),
    icon: (j['icon'] ?? 'cal').toString(),
    emoji: (j['emoji'] as String?)?.isNotEmpty == true ? j['emoji'] : null,
    picture: (j['picture'] as String?)?.isNotEmpty == true
        ? j['picture']
        : null,
    color: Color((j['color'] as num?)?.toInt() ?? 0xff475569),
    core: j['core'] == true,
  );
}

/// The 3 built-in calendar layers, in their original order/colours — used
/// both as the seed for brand-new workspaces and to backfill any legacy
/// workspace saved before layers became customizable (see
/// `Workspace.fromJson`).
List<CalendarLayerDef> kDefaultCalendarLayers() => [
  CalendarLayerDef(
    id: 'appt',
    label: 'Appointments',
    icon: 'cal',
    color: B.primary,
    core: true,
  ),
  CalendarLayerDef(
    id: 'task',
    label: 'To-Dos',
    icon: 'check',
    color: const Color(0xff2563eb),
    core: true,
  ),
  CalendarLayerDef(
    id: 'content',
    label: 'Content',
    icon: 'camera',
    color: const Color(0xffdb2777),
    core: true,
  ),
];

/// A single read-only event inside an [ImportedCalendar].
class ImportedCalendarEvent {
  ImportedCalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    this.allDay = false,
    this.start = '',
    this.end = '',
    this.location = '',
    this.notes = '',
  });

  String id;
  String title;
  String date;
  bool allDay;
  String start;
  String end;
  String location;

  /// Feed-provided details (e.g. an ICS `DESCRIPTION`, such as a fotmob
  /// fixture's competition name/match link).
  String notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date,
    'allDay': allDay,
    'start': start,
    'end': end,
    if (location.isNotEmpty) 'location': location,
    if (notes.isNotEmpty) 'notes': notes,
  };

  factory ImportedCalendarEvent.fromJson(Map<String, dynamic> j) =>
      ImportedCalendarEvent(
        id: (j['id'] ?? uid()).toString(),
        title: (j['title'] ?? 'Imported event').toString(),
        date: (j['date'] ?? todayIso()).toString(),
        allDay: j['allDay'] == true,
        start: (j['start'] ?? '').toString(),
        end: (j['end'] ?? '').toString(),
        location: (j['location'] ?? '').toString(),
        notes: (j['notes'] ?? '').toString(),
      );
}

/// A read-only imported external calendar (Google / Apple / ICS).
class ImportedCalendar {
  ImportedCalendar({
    required this.id,
    required this.name,
    required this.provider,
    required this.color,
    this.category,
    this.visible = true,
    this.url,
    this.autoSync = true,
    this.includeLocation = true,
    this.includeDescription = true,
    this.reminder = '1h',
    List<ImportedCalendarEvent>? events,
  }) : events = events ?? <ImportedCalendarEvent>[];

  String id;
  String name;

  /// `google` | `apple` | `ics`.
  String provider;
  Color color;

  /// [EventCategory.id] this import is tagged with, or `null`.
  String? category;
  bool visible;

  /// Source feed URL for `ics` imports (e.g. an ecal.com `.ics` link), used
  /// to re-sync. `null` for `google`/`apple` account-based imports.
  String? url;

  /// Whether this import re-fetches [url] automatically on app open/resume.
  /// Only meaningful when [url] is set.
  bool autoSync;

  /// Whether the feed's `LOCATION`/`DESCRIPTION` are kept on [events] (e.g. a
  /// sports feed's venue and competition/match link) or stripped on import.
  bool includeLocation;
  bool includeDescription;

  /// `none` | `at` | `5m` | `15m` | `30m` | `1h` | `2h` | `1d` | `2d` — applied
  /// to every occurrence from this feed, since imported events don't have
  /// their own per-event reminder field.
  String reminder;
  List<ImportedCalendarEvent> events;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'provider': provider,
    'color': color.toARGB32(),
    if (category != null) 'category': category,
    'visible': visible,
    if (url != null) 'url': url,
    'autoSync': autoSync,
    'includeLocation': includeLocation,
    'includeDescription': includeDescription,
    'reminder': reminder,
    'events': events.map((e) => e.toJson()).toList(),
  };

  factory ImportedCalendar.fromJson(Map<String, dynamic> j) => ImportedCalendar(
    id: (j['id'] ?? uid()).toString(),
    name: (j['name'] ?? 'Imported calendar').toString(),
    provider: (j['provider'] ?? 'ics').toString(),
    color: Color((j['color'] as num?)?.toInt() ?? 0xff475569),
    category: j['category']?.toString(),
    visible: j['visible'] != false,
    url: (j['url'] as String?)?.isNotEmpty == true ? j['url'] as String : null,
    autoSync: j['autoSync'] != false,
    includeLocation: j['includeLocation'] != false,
    includeDescription: j['includeDescription'] != false,
    reminder: (j['reminder'] ?? '1h').toString(),
    events: [
      for (final e in (j['events'] as List? ?? []))
        ImportedCalendarEvent.fromJson(Map<String, dynamic>.from(e as Map)),
    ],
  );
}
