import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

/// Opens the family management page (#275) from the More hub.
Future<void> _openFamily(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-more')));
  await tester.pumpAndSettle();
  await tapHubRow(tester, 'family', 'more-member-me');
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
  testWidgets('invite sheet adds an invited member by email', (tester) async {
    await pumpApp(tester);
    await _openFamily(tester);

    await tester.tap(find.byKey(const ValueKey('family-invite-share')));
    await tester.pumpAndSettle();
    // Empty email only toasts.
    await tester.tap(find.byKey(const ValueKey('iv-add-email')));
    await tester.pumpAndSettle();
    expect(find.text('Type their email first'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('iv-email')),
      'lisa@email.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('iv-add-email')));
    await tester.pumpAndSettle();
    expect(
      find.text('Added as invited — remember to share the join details'),
      findsOneWidget,
    );
    final lisa = thriveDebug.curFamily()!.members.firstWhere(
      (m) => m.email == 'lisa@email.com',
    );
    expect(lisa.status, 'invited');
    expect(lisa.name, 'lisa');
  });

  testWidgets('invite sheet adds a login-less member', (tester) async {
    await pumpApp(tester);
    await _openFamily(tester);

    await tester.tap(find.byKey(const ValueKey('family-add-loginless')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('iv-add-ll')));
    await tester.pumpAndSettle();
    expect(find.text('Type a name first'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('iv-ll-name')), 'Emma');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('iv-add-ll')));
    await tester.pumpAndSettle();
    expect(find.text('Emma added'), findsOneWidget);
    final emma = thriveDebug.curFamily()!.members.firstWhere(
      (m) => m.name == 'Emma',
    );
    expect(emma.uid, isNull);
    expect(emma.status, 'active');
    expect(emma.email, isEmpty);
  });

  testWidgets('member studio edits a member from the actions sheet', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openFamily(tester);
    thriveDebug.inviteMember('Lisa Janssen', 'lisa@email.com');
    await tester.pumpAndSettle();
    final lisaId = thriveDebug
        .curFamily()!
        .members
        .firstWhere((m) => m.name == 'Lisa Janssen')
        .id;

    await tester.tap(find.byKey(ValueKey('fam-member-$lisaId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ma-edit')));
    await tester.pumpAndSettle();
    expect(find.text('Edit member'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('member-email')),
      'lisab@email.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(find.text('Member saved — updated everywhere'), findsOneWidget);
    expect(
      thriveDebug.curFamily()!.members.firstWhere((m) => m.id == lisaId).email,
      'lisab@email.com',
    );
  });

  testWidgets('profile family row switches the active family', (tester) async {
    await pumpApp(tester);
    await thriveDebug.createFamily('Beach house');
    await tester.pumpAndSettle();
    final beachId = thriveDebug.families
        .firstWhere((f) => f.name == 'Beach house')
        .id;
    // Currently on Beach house; the profile row switches back to fam_main.
    await tester.tap(find.byKey(const ValueKey('profile-avatar')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('profile-family-$beachId')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-family-fam_main')));
    await tester.pumpAndSettle();
    expect(thriveDebug.familyId, 'fam_main');
    expect(find.textContaining('Switched to'), findsOneWidget);
  });

  testWidgets(
    'create-family sheet: username validation notes and keyboard submit',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-new-family')));
      await tester.pumpAndSettle();

      final nfName = find.byKey(const ValueKey('nf-name'));
      final nfUser = find.byKey(const ValueKey('nf-username'));
      final nfPw = find.byKey(const ValueKey('nf-password'));

      // Auto-suggest with an unusable base clears the username field.
      await tester.enterText(nfName, '!!');
      await tester.pump(const Duration(milliseconds: 500));

      // Name "next" hops to the username field, suggesting a handle.
      await _submitField(tester, nfName, 'Beach house', TextInputAction.next);
      await tester.pump(const Duration(milliseconds: 500));

      // Too-short handle shows the format note.
      await tester.enterText(nfUser, 'ab');
      await tester.pump();
      expect(find.text('3–24 letters, numbers, - or _'), findsOneWidget);

      // Clearing it falls back to the suggestion path.
      await tester.enterText(nfUser, '');
      await tester.pump(const Duration(milliseconds: 500));

      // Valid handle, "next" hops to password, "done" submits.
      await _submitField(tester, nfUser, 'beach-house', TextInputAction.next);
      await tester.pump(const Duration(milliseconds: 500));
      await _submitField(tester, nfPw, 'secret123', TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nf-name')), findsNothing);
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
    expect(find.text('Join a family'), findsWidgets);

    await _submitField(
      tester,
      find.byKey(const ValueKey('jf-username')),
      'vanderberg',
      TextInputAction.next,
    );
    await _submitField(
      tester,
      find.byKey(const ValueKey('jf-password')),
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

  testWidgets('profile name saves explicitly, not per keystroke', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('profile-avatar')));
    await tester.pumpAndSettle();
    // No Save button until the field is dirty.
    expect(find.byKey(const ValueKey('profile-name-save')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('profile-name-input')),
      'Eva Smit',
    );
    await tester.pump();
    // Typing alone never writes.
    expect(thriveDebug.user!.name, 'Eva Janssen');
    await tester.tap(find.byKey(const ValueKey('profile-name-save')));
    await tester.pumpAndSettle();
    expect(thriveDebug.user!.name, 'Eva Smit');
    expect(
      find.text('Name saved — mirrored to your member rows'),
      findsOneWidget,
    );
    // The name mirrors onto the member row too (#274).
    expect(
      thriveDebug.curFamily()!.members.firstWhere((m) => m.id == 'me').name,
      'Eva Smit',
    );
  });

  testWidgets(
    'a broken profile photo falls back and can be removed from the page',
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
      // Non-Google provider pill.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-provider-pill')),
          matching: find.text('Email'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('profile-photo-remove')));
      await tester.pumpAndSettle();
      expect(find.text('Photo removed — back to initials'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-photo-remove')), findsNothing);
      expect(thriveDebug.user!.photo, isNull);
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

    await tester.tap(find.byKey(const ValueKey('memcolors-row-me')));
    await tester.pumpAndSettle();
    expect(find.text('Edit member'), findsOneWidget);

    // Pick a colour via the hex field, save, and the member row updates
    // everywhere.
    final free = kMemberColors.firstWhere((c) => c != before);
    final freeHex = (free.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    await tester.tap(find.text('RGB / Hex'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('hex-color-input')),
      freeHex,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pumpAndSettle();
    expect(myColor(), free);
  });
}
