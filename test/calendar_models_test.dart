import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

void main() {
  group('CalendarEvent', () {
    test('toJson/fromJson round-trips every field', () {
      final ev = CalendarEvent(
        id: 'e1',
        title: 'Team lunch',
        allDay: true,
        date: '2026-03-01',
        endDate: '2026-03-03',
        start: '12:00',
        end: '13:00',
        location: 'Cafe',
        notes: 'Bring cash',
        category: 'cat1',
        color: kEventColors[2],
        attendees: ['me', 'partner'],
        reminder: '1d',
        recur: 'weekly',
        createdBy: 'me',
        exceptions: ['2026-03-08'],
        layerId: 'task',
        done: true,
        doneDates: {'2026-03-08': true},
      );

      final restored = CalendarEvent.fromJson(ev.toJson());

      expect(restored.id, ev.id);
      expect(restored.title, ev.title);
      expect(restored.allDay, ev.allDay);
      expect(restored.date, ev.date);
      expect(restored.endDate, ev.endDate);
      expect(restored.start, ev.start);
      expect(restored.end, ev.end);
      expect(restored.location, ev.location);
      expect(restored.notes, ev.notes);
      expect(restored.category, ev.category);
      expect(restored.color, ev.color);
      expect(restored.attendees, ev.attendees);
      expect(restored.reminder, ev.reminder);
      expect(restored.recur, ev.recur);
      expect(restored.createdBy, ev.createdBy);
      expect(restored.exceptions, ev.exceptions);
      expect(restored.layerId, ev.layerId);
      expect(restored.done, ev.done);
      expect(restored.doneDates, ev.doneDates);
    });

    test('fromJson falls back to defaults for a bare/empty map', () {
      final restored = CalendarEvent.fromJson({});

      expect(restored.title, 'Untitled');
      expect(restored.allDay, false);
      expect(restored.start, '');
      expect(restored.end, '');
      expect(restored.location, '');
      expect(restored.notes, '');
      expect(restored.category, null);
      expect(restored.attendees, ['me']);
      expect(restored.reminder, '1h');
      expect(restored.recur, 'none');
      expect(restored.createdBy, null);
      expect(restored.exceptions, isEmpty);
      expect(restored.layerId, 'appt');
      expect(restored.done, false);
      expect(restored.doneDates, isEmpty);
    });

    test('fromJson defaults a missing/empty layerId to appt for backward '
        'compatibility with pre-layers events', () {
      expect(CalendarEvent.fromJson({'layerId': ''}).layerId, 'appt');
      expect(CalendarEvent.fromJson({'layerId': 'content'}).layerId, 'content');
    });

    test('isDoneOn falls back to done for a non-recurring event and reads '
        'doneDates for a recurring one', () {
      final oneOff = CalendarEvent(
        id: 'e1',
        title: 't',
        date: '2026-03-01',
        color: kEventColors[0],
        done: true,
      );
      expect(oneOff.isDoneOn('2026-03-01'), true);

      final recurring = CalendarEvent(
        id: 'e2',
        title: 't',
        date: '2026-03-01',
        color: kEventColors[0],
        recur: 'weekly',
        doneDates: {'2026-03-08': true},
      );
      expect(recurring.isDoneOn('2026-03-08'), true);
      expect(recurring.isDoneOn('2026-03-15'), false);
    });
  });

  group('EventCategory', () {
    test('toJson/fromJson round-trips every field', () {
      final cat = EventCategory(
        id: 'c1',
        name: 'Sports',
        color: kCatColors[1],
        icon: 'whistle',
        emoji: '⚽️',
        picture: 'data:image/png;base64,AAAA',
        members: ['m1', 'm2'],
        layerId: 'task',
      );

      final restored = EventCategory.fromJson(cat.toJson());

      expect(restored.id, cat.id);
      expect(restored.name, cat.name);
      expect(restored.color, cat.color);
      expect(restored.icon, cat.icon);
      expect(restored.emoji, cat.emoji);
      expect(restored.picture, cat.picture);
      expect(restored.members, cat.members);
      expect(restored.layerId, cat.layerId);
    });

    test('fromJson falls back to defaults for a bare/empty map', () {
      final restored = EventCategory.fromJson({});

      expect(restored.name, 'Category');
      expect(restored.icon, 'briefcase');
      expect(restored.emoji, null);
      expect(restored.picture, null);
      expect(restored.members, isEmpty);
      expect(restored.layerId, 'appt');
    });

    test('fromJson defaults a missing/empty layerId to appt so legacy '
        'categories become appt-scoped', () {
      expect(EventCategory.fromJson({'layerId': ''}).layerId, 'appt');
      expect(EventCategory.fromJson({'layerId': 'content'}).layerId, 'content');
    });

    test('fromJson treats an empty emoji/picture string as unset', () {
      final restored = EventCategory.fromJson({'emoji': '', 'picture': ''});

      expect(restored.emoji, null);
      expect(restored.picture, null);
    });
  });

  group('ImportedCalendarEvent', () {
    test('toJson/fromJson round-trips every field', () {
      final ev = ImportedCalendarEvent(
        id: 'ie1',
        title: 'Ajax - PSV',
        date: '2026-04-01',
        allDay: false,
        start: '18:00',
        end: '20:00',
        location: 'Johan Cruijff ArenA',
        notes: 'Eredivisie',
      );

      final restored = ImportedCalendarEvent.fromJson(ev.toJson());

      expect(restored.id, ev.id);
      expect(restored.title, ev.title);
      expect(restored.date, ev.date);
      expect(restored.allDay, ev.allDay);
      expect(restored.start, ev.start);
      expect(restored.end, ev.end);
      expect(restored.location, ev.location);
      expect(restored.notes, ev.notes);
    });

    test('fromJson falls back to defaults for a bare/empty map', () {
      final restored = ImportedCalendarEvent.fromJson({});

      expect(restored.title, 'Imported event');
      expect(restored.allDay, false);
      expect(restored.start, '');
      expect(restored.end, '');
      expect(restored.location, '');
      expect(restored.notes, '');
    });

    test('toJson omits empty location/notes', () {
      final ev = ImportedCalendarEvent(
        id: 'ie1',
        title: 'x',
        date: '2026-04-01',
      );
      final j = ev.toJson();
      expect(j.containsKey('location'), false);
      expect(j.containsKey('notes'), false);
    });
  });

  group('ImportedCalendar', () {
    test('toJson/fromJson round-trips every field', () {
      final cal = ImportedCalendar(
        id: 'cal1',
        name: 'Ajax fixtures',
        provider: 'ics',
        color: kImportProviders['ics']!.$2,
        category: 'cat1',
        visible: false,
        url: 'https://example.com/ajax.ics',
        autoSync: false,
        includeLocation: false,
        includeDescription: false,
        events: [
          ImportedCalendarEvent(id: 'ie1', title: 'x', date: '2026-04-01'),
        ],
      );

      final restored = ImportedCalendar.fromJson(cal.toJson());

      expect(restored.id, cal.id);
      expect(restored.name, cal.name);
      expect(restored.provider, cal.provider);
      expect(restored.color, cal.color);
      expect(restored.category, cal.category);
      expect(restored.visible, cal.visible);
      expect(restored.url, cal.url);
      expect(restored.autoSync, cal.autoSync);
      expect(restored.includeLocation, cal.includeLocation);
      expect(restored.includeDescription, cal.includeDescription);
      expect(restored.events, hasLength(1));
      expect(restored.events.first.id, 'ie1');
    });

    test('fromJson falls back to defaults for a bare/empty map', () {
      final restored = ImportedCalendar.fromJson({});

      expect(restored.name, 'Imported calendar');
      expect(restored.provider, 'ics');
      expect(restored.category, null);
      expect(restored.visible, true);
      expect(restored.url, null);
      expect(restored.autoSync, true);
      expect(restored.includeLocation, true);
      expect(restored.includeDescription, true);
      expect(restored.events, isEmpty);
    });

    test('an empty url string is treated as unset', () {
      final restored = ImportedCalendar.fromJson({'url': ''});
      expect(restored.url, null);
    });
  });
}
