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
}
