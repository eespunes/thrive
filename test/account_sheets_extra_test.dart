import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

Future<void> _openFamily(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('profile-avatar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('profile-family-fam_main')));
  await tester.pumpAndSettle();
}

Future<void> _submitField(
  WidgetTester tester,
  Finder field,
  String text,
  TextInputAction action,
) async {
  await tester.showKeyboard(field);
  await tester.enterText(field, text);
  await tester.pump();
  await tester.testTextInput.receiveAction(action);
  await tester.pump();
}

void main() {
  testWidgets('invite card submits from the keyboard and can be cancelled', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openFamily(tester);

    // Keyboard flow: name "next" hops to email, email "done" sends.
    await tester.tap(find.byKey(const ValueKey('family-invite')));
    await tester.pumpAndSettle();
    await _submitField(
      tester,
      find.byType(TextField).at(1),
      'Lisa Janssen',
      TextInputAction.next,
    );
    await _submitField(
      tester,
      find.byType(TextField).at(2),
      'lisa@email.com',
      TextInputAction.done,
    );
    await tester.pumpAndSettle();
    expect(find.text('Invited'), findsOneWidget);

    // Cancel path.
    await tester.tap(find.byKey(const ValueKey('family-invite')));
    await tester.pumpAndSettle();
    expect(find.text('Send invite'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Send invite'), findsNothing);
  });

  testWidgets('add-member-without-email card submits from the keyboard', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openFamily(tester);

    // Cancel path.
    await tester.tap(find.byKey(const ValueKey('family-add-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-member-save')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('family-add-member')));
    await tester.pumpAndSettle();
    await _submitField(
      tester,
      find.byType(TextField).last,
      'Emma',
      TextInputAction.done,
    );
    await tester.pumpAndSettle();
    expect(find.text('Emma'), findsOneWidget);
  });

  testWidgets('edit-member sheet submits from the keyboard', (tester) async {
    await pumpApp(tester);
    await _openFamily(tester);
    await tester.tap(find.byKey(const ValueKey('family-invite')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Lisa Janssen');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(2), 'lisa@email.com');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('invite-send')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lisa Janssen').last);
    await tester.pumpAndSettle();
    expect(find.text('Edit member'), findsOneWidget);
    await _submitField(
      tester,
      find.byType(TextField).first,
      'Lisa B',
      TextInputAction.next,
    );
    await _submitField(
      tester,
      find.byType(TextField).last,
      'lisab@email.com',
      TextInputAction.done,
    );
    await tester.pumpAndSettle();
    expect(find.text('Member updated'), findsOneWidget);
  });

  testWidgets('family sheet "New" chip opens the create-family sheet', (
    tester,
  ) async {
    await pumpApp(tester);
    // The switcher row only renders with more than one family.
    await thriveDebug.createFamily('Beach house');
    await tester.pumpAndSettle();
    await _openFamily(tester);
    await tester.ensureVisible(find.text('New'));
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(find.text('Create a family'), findsOneWidget);
  });

  testWidgets(
    'create-family sheet: username validation notes and keyboard submit',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-new-family')));
      await tester.pumpAndSettle();

      // Auto-suggest with an unusable base clears the username field.
      await tester.enterText(find.byType(TextField).first, '!!');
      await tester.pump(const Duration(milliseconds: 500));

      // Name "next" hops to the username field, suggesting a handle.
      await _submitField(
        tester,
        find.byType(TextField).first,
        'Beach house',
        TextInputAction.next,
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Too-short handle shows the format note.
      await tester.enterText(find.byType(TextField).at(1), 'ab');
      await tester.pump();
      expect(find.text('3–24 letters, numbers, - or _'), findsOneWidget);

      // Clearing it falls back to the suggestion path.
      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.pump(const Duration(milliseconds: 500));

      // Valid handle, "next" hops to password, "done" submits.
      await _submitField(
        tester,
        find.byType(TextField).at(1),
        'beach-house',
        TextInputAction.next,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await _submitField(
        tester,
        find.byType(TextField).at(2),
        'secret123',
        TextInputAction.done,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Create a family'), findsNothing);
      expect(
        thriveDebug.families.where((f) => f.name == 'Beach house'),
        hasLength(1),
      );
    },
  );

  testWidgets('join-family sheet submits from the keyboard', (tester) async {
    await pumpApp(tester, prefs: joinableFamilyPrefs());
    await tester.tap(find.byKey(const ValueKey('profile-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-join-family')));
    await tester.pumpAndSettle();
    expect(find.text('Join a family'), findsOneWidget);

    await _submitField(
      tester,
      find.byType(TextField).first,
      'vanderberg',
      TextInputAction.next,
    );
    await _submitField(
      tester,
      find.byType(TextField).last,
      'demo',
      TextInputAction.done,
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(
      thriveDebug.families.where((f) => f.name == 'van der Berg family'),
      hasLength(1),
    );
  });

  testWidgets('profile edit can be cancelled', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('profile-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-edit')));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsNothing);
  });

  testWidgets(
    'a broken profile photo falls back to initials and can be removed',
    (tester) async {
      await pumpApp(
        tester,
        prefs: {
          'flutter.thrive.user': json.encode({
            'name': 'Eva Janssen',
            'email': 'eva.janssen@gmail.com',
            'initials': 'EJ',
            'provider': 'password',
            'photo': 'not-valid-base64!!!',
          }),
        },
      );
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      // Email-account badge (non-Google provider).
      expect(find.text('Email account'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profile-edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove'), findsNothing);
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profile updated'), findsOneWidget);
    },
  );

  testWidgets('member studio recolours a member with unique-per-family dots', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await tester.tap(find.byKey(const ValueKey('nav-more')));
    await tester.pumpAndSettle();
    await tapHubRow(tester, 'planning', 'more-memcolors');

    Color myColor() =>
        thriveDebug.curFamily()!.members.firstWhere((m) => m.id == 'me').color;
    final before = myColor();
    final taken = thriveDebug
        .curFamily()!
        .members
        .where((m) => m.id != 'me')
        .map((m) => m.color)
        .toSet();

    await tester.tap(find.byKey(const ValueKey('memcolors-row-me')));
    await tester.pumpAndSettle();
    expect(find.text('Edit member'), findsOneWidget);

    // Pick the first free colour dot, save, and the member row updates
    // everywhere.
    final free = kMemberColors.firstWhere(
      (c) => c != before && !taken.contains(c),
    );
    await tester.ensureVisible(
      find.byKey(ValueKey('badge-color-${free.toARGB32()}')),
    );
    await tester.tap(
      find.byKey(ValueKey('badge-color-${free.toARGB32()}')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(myColor(), free);

    // A colour worn by someone else is dimmed and only toasts.
    if (taken.isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('memcolors-row-me')));
      await tester.pumpAndSettle();
      final takenColor = taken.first;
      await tester.ensureVisible(
        find.byKey(ValueKey('badge-color-${takenColor.toARGB32()}')),
      );
      await tester.tap(
        find.byKey(ValueKey('badge-color-${takenColor.toARGB32()}')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(thriveDebug.toast, 'That colour is taken in this family');
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();
      expect(myColor(), free);
    }
  });
}
