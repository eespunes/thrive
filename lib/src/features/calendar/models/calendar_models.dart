part of 'package:family_money_management_app/main.dart';

/// A shared family calendar event, mirrors the design's event shape.
class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    this.allDay = false,
    required this.date,
    this.start = '',
    this.end = '',
    this.location = '',
    this.notes = '',
    this.category,
    required this.color,
    List<String>? attendees,
    this.reminder = '1h',
    this.recur = 'none',
    this.createdBy,
    List<String>? exceptions,
  }) : attendees = attendees ?? <String>['me'],
       exceptions = exceptions ?? <String>[];

  String id;
  String title;
  bool allDay;

  /// ISO `YYYY-MM-DD` first occurrence date.
  String date;

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

  /// `none` | `at` | `1h` | `1d`.
  String reminder;

  /// `none` | `daily` | `weekly` | `monthly` | `yearly`.
  String recur;
  String? createdBy;

  /// ISO dates removed from a recurring series (single-occurrence deletes).
  List<String> exceptions;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'allDay': allDay,
    'date': date,
    'start': start,
    'end': end,
    'location': location,
    'notes': notes,
    if (category != null) 'category': category,
    'color': color.toARGB32(),
    'attendees': attendees,
    'reminder': reminder,
    'recur': recur,
    if (createdBy != null) 'createdBy': createdBy,
    'exceptions': exceptions,
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
    id: (j['id'] ?? uid()).toString(),
    title: (j['title'] ?? 'Untitled').toString(),
    allDay: j['allDay'] == true,
    date: (j['date'] ?? todayIso()).toString(),
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
    createdBy: j['createdBy']?.toString(),
    exceptions: [
      for (final e in (j['exceptions'] as List? ?? [])) e.toString(),
    ],
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
  }) : members = members ?? <String>[];

  String id;
  String name;
  Color color;

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
  );
}

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
    'events': events.map((e) => e.toJson()).toList(),
  };

  factory ImportedCalendar.fromJson(Map<String, dynamic> j) =>
      ImportedCalendar(
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
        events: [
          for (final e in (j['events'] as List? ?? []))
            ImportedCalendarEvent.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );
}
