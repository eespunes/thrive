import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

void main() {
  group('FamilyMember', () {
    test('copy() reproduces every field on an independent instance', () {
      final original = FamilyMember(
        id: 'm1',
        name: 'Eva Janssen',
        email: 'eva@email.com',
        initials: 'EJ',
        color: kMemberColors[1],
        uid: 'uid-123',
        photo: 'data:image/png;base64,AAAA',
        role: 'owner',
        status: 'invited',
      );

      final clone = original.copy();

      expect(clone.id, original.id);
      expect(clone.name, original.name);
      expect(clone.email, original.email);
      expect(clone.initials, original.initials);
      expect(clone.color, original.color);
      expect(clone.uid, original.uid);
      expect(clone.photo, original.photo);
      expect(clone.role, original.role);
      expect(clone.status, original.status);

      // Mutating the clone must not leak back into the original.
      clone.name = 'Changed';
      clone.role = 'member';
      expect(original.name, 'Eva Janssen');
      expect(original.role, 'owner');
    });

    test('fromJson fills sensible defaults when fields are missing', () {
      final m = FamilyMember.fromJson(const {});

      // A missing id is backfilled with a freshly generated, non-empty id.
      expect(m.id, isNotEmpty);
      expect(m.name, '');
      expect(m.email, '');
      expect(m.initials, '?');
      expect(m.color, isA<Color>());
      expect(m.uid, isNull);
      expect(m.photo, isNull);
      expect(m.role, 'member');
      expect(m.status, 'active');
    });

    test('fromJson derives initials from the name when absent', () {
      final m = FamilyMember.fromJson(const {'name': 'Tom van der Berg'});
      expect(m.initials, 'TV');
    });
  });

  group('AppUser', () {
    test('round-trips through toJson/fromJson including an optional color', () {
      final user = AppUser(
        name: 'Sophie',
        email: 'sophie@email.com',
        initials: 'S',
        provider: 'google',
        photo: 'p',
        color: kMemberColors[2],
      );

      final restored = AppUser.fromJson(user.toJson());

      expect(restored.name, 'Sophie');
      expect(restored.email, 'sophie@email.com');
      expect(restored.initials, 'S');
      expect(restored.provider, 'google');
      expect(restored.photo, 'p');
      expect(restored.color, kMemberColors[2]);
    });

    test(
      'fromJson defaults the provider and leaves color null when absent',
      () {
        final restored = AppUser.fromJson(const {
          'name': 'No Color',
          'email': 'nc@email.com',
        });
        expect(restored.provider, 'email');
        expect(restored.color, isNull);
        expect(restored.initials, 'NC');
      },
    );
  });

  group('Workspace calendarLayers (issue #203-#211)', () {
    test('a brand-new workspace starts with zero calendar layers', () {
      final ws = Workspace(accounts: const [], cats: const [], data: const {});
      expect(ws.calendarLayers, isEmpty);
    });

    test('Workspace.empty() (a newly created family) has zero layers', () {
      expect(Workspace.empty().calendarLayers, isEmpty);
    });

    test('fromJson backfills the 3 legacy built-ins only when the '
        'calendarLayers key is completely absent (pre-layers save)', () {
      final ws = Workspace.fromJson({
        'accounts': [],
        'cats': [],
        'data': <String, dynamic>{},
        // No 'calendarLayers' key at all.
      });
      expect(ws.calendarLayers.map((l) => l.id), ['appt', 'task', 'content']);
    });

    test('fromJson respects an explicitly-empty saved calendarLayers list '
        'instead of re-seeding the 3 built-ins', () {
      final ws = Workspace.fromJson({
        'accounts': [],
        'cats': [],
        'data': <String, dynamic>{},
        'calendarLayers': [],
      });
      expect(ws.calendarLayers, isEmpty);
    });

    test(
      'fromJson round-trips a non-empty saved calendarLayers list as-is',
      () {
        final ws = Workspace.fromJson({
          'accounts': [],
          'cats': [],
          'data': <String, dynamic>{},
          'calendarLayers': [
            CalendarLayerDef(
              id: 'custom',
              label: 'Custom',
              icon: 'star',
              color: kMemberColors[0],
            ).toJson(),
          ],
        });
        expect(ws.calendarLayers.map((l) => l.id), ['custom']);
      },
    );

    test(
      'fromJson defaults the kitchen wall layer filter from saved layers',
      () {
        final ws = Workspace.fromJson({
          'accounts': [],
          'cats': [],
          'data': <String, dynamic>{},
          'calendarLayers': [
            CalendarLayerDef(
              id: 'task',
              label: 'To-Dos',
              icon: 'check',
              color: kMemberColors[0],
              core: true,
            ).toJson(),
            CalendarLayerDef(
              id: 'custom',
              label: 'Custom',
              icon: 'star',
              color: kMemberColors[1],
            ).toJson(),
          ],
        });

        expect(ws.kitchenLayerFilter, ['task', 'custom']);
      },
    );

    test('kitchen wall layer filter round-trips explicitly', () {
      final ws = Workspace(
        accounts: const [],
        cats: const [],
        data: const {},
        kitchenLayerFilter: const ['content'],
      );

      expect(Workspace.fromJson(ws.toJson()).kitchenLayerFilter, ['content']);
    });
  });

  group('CalendarEvent kitchen-origin items', () {
    test('round-trip with no calendar layer assigned', () {
      final event = CalendarEvent(
        id: 'k1',
        title: 'Kitchen only',
        allDay: true,
        date: '2026-08-19',
        color: kMemberColors[0],
        attendees: const ['kid'],
        layerId: '',
        kitchenOrigin: true,
        emoji: '⭐',
      );

      final restored = CalendarEvent.fromJson(event.toJson());

      expect(restored.kitchenOrigin, isTrue);
      expect(restored.layerId, '');
      expect(restored.emoji, '⭐');
    });
  });
}
