import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'
    show EmojiPicker;
import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> _openJoinSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('profile-avatar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('profile-join-family')));
  await tester.pumpAndSettle();
}

/// The glyph picker no longer has a free-form field; an emoji is chosen
/// through the in-app picker that opens from the + tile. The Recents tab
/// starts empty, so we hop to Smileys (tab 1) and tap its first emoji (😀).
Future<String> _pickEmoji(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('glyph-pick-emoji')));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Tab).at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('😀').first);
  await tester.pumpAndSettle();
  return '😀';
}

void main() {
  group('issue #132 — demo family removed', () {
    testWidgets('the join sheet no longer advertises the demo family', (
      tester,
    ) async {
      await pumpApp(tester);
      await _openJoinSheet(tester);
      expect(find.text('Join a family'), findsWidgets);
      expect(find.text('Demo: vanderberg / demo'), findsNothing);
    });

    testWidgets('the demo family is not auto-seeded for joining', (
      tester,
    ) async {
      // No registry seed: the built-in van der Berg demo no longer exists.
      await pumpApp(tester);
      await _openJoinSheet(tester);
      await tester.enterText(find.byType(TextField).at(0), 'vanderberg');
      await tester.enterText(find.byType(TextField).at(1), 'demo');
      await tester.tap(find.text('Join family'));
      await tester.pumpAndSettle();
      expect(find.text('No family found with that username'), findsOneWidget);
    });
  });

  group('issue #133 — leaving a family', () {
    testWidgets('a member can leave a family they joined', (tester) async {
      await pumpApp(tester, prefs: joinableFamilyPrefs());
      // Join the seeded family as a regular member.
      await _openJoinSheet(tester);
      await tester.enterText(find.byType(TextField).at(0), 'vanderberg');
      await tester.enterText(find.byType(TextField).at(1), 'demo');
      await tester.tap(find.text('Join family'));
      await tester.pumpAndSettle();
      expect(find.text('Joined van der Berg family'), findsOneWidget);

      final fid = thriveDebug.familyId;
      // Open the joined family's sheet.
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('profile-family-$fid')));
      await tester.pumpAndSettle();

      // A member sees the leave button but not the (owner-only) delete button.
      expect(find.byKey(const ValueKey('family-leave')), findsOneWidget);
      expect(find.byKey(const ValueKey('family-delete')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('family-leave')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave').last);
      await tester.pumpAndSettle();

      expect(find.text('Left van der Berg family'), findsOneWidget);
      expect(thriveDebug.families.any((f) => f.id == fid), isFalse);
    });

    testWidgets('an owner leaving hands ownership to another member', (
      tester,
    ) async {
      await pumpApp(tester);
      final fam = thriveDebug.curFamily()!;
      // The seeded family has me as owner plus one active member.
      expect(fam.members.any((m) => m.id == 'me' && m.role == 'owner'), isTrue);
      expect(
        fam.members.any(
          (m) => m.id != 'me' && m.role == 'member' && m.status == 'active',
        ),
        isTrue,
      );

      thriveDebug.leaveFamily(fam.id);
      await tester.pumpAndSettle();

      // My membership is gone and exactly one remaining member is now owner.
      expect(fam.members.any((m) => m.id == 'me'), isFalse);
      expect(fam.members.where((m) => m.role == 'owner').length, 1);
      // That was my only family, so the onboarding gate returns.
      expect(find.text('One last step'), findsOneWidget);
    });

    testWidgets('an owner of a multi-member family also sees delete', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-family-fam_main')));
      await tester.pumpAndSettle();

      // Owner of fam_main (which has an active member) sees both buttons; the
      // leave button is rendered above the delete button. The owner can always
      // delete a family — even their only one (issue #133 follow-up).
      expect(find.byKey(const ValueKey('family-leave')), findsOneWidget);
      expect(find.byKey(const ValueKey('family-delete')), findsOneWidget);
    });

    testWidgets('an owner can delete their only family back to onboarding', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-family-fam_main')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('family-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      // No families remain, so the create/join onboarding gate returns.
      expect(thriveDebug.families, isEmpty);
      expect(find.text('One last step'), findsOneWidget);
    });
  });

  group('issue #131 — emoji / picture for accounts & blocks', () {
    testWidgets(
      'budget block sheet replaces the icon grid with emoji picking',
      (tester) async {
        await pumpApp(tester);
        await goToTab(tester, 'settings');
        await tester.tap(find.text('Add budget block'));
        await tester.pumpAndSettle();
        expect(find.text('New budget block'), findsOneWidget);

        // The legacy icon field is gone; the emoji/picture picker replaces it.
        // Field labels render upper-cased.
        expect(find.text('ICON'), findsNothing);
        expect(find.text('EMOJI OR PICTURE'), findsOneWidget);
        expect(find.byKey(const ValueKey('glyph-upload')), findsOneWidget);

        // Name the block and pick an emoji from the in-app picker, then create
        // it. The preset icon grid and the old free-form field are both gone.
        await tester.enterText(find.byType(TextField).at(0), 'Games');
        await tester.pump();
        final emoji = await _pickEmoji(tester);
        await tester.tap(find.text('Create block'));
        await tester.pumpAndSettle();

        // The chosen emoji renders for the new block.
        expect(find.text('Games'), findsWidgets);
        expect(find.text(emoji), findsWidgets);
      },
    );

    testWidgets('tapping the + tile opens the in-app emoji picker', (
      tester,
    ) async {
      await pumpApp(tester);
      await goToTab(tester, 'settings');
      await tester.tap(find.text('Add budget block'));
      await tester.pumpAndSettle();

      expect(find.byType(EmojiPicker), findsNothing);
      await tester.tap(find.byKey(const ValueKey('glyph-pick-emoji')));
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPicker), findsOneWidget);
    });

    testWidgets('account sheet offers emoji selection above the name', (
      tester,
    ) async {
      await pumpApp(tester);
      await goToTab(tester, 'settings');
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      expect(find.text('EMOJI OR PICTURE'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'Travel fund');
      await tester.pump();
      final emoji = await _pickEmoji(tester);
      await tester.tap(find.text('Add account').last);
      await tester.pumpAndSettle();

      expect(find.text('Travel fund'), findsWidgets);
      expect(find.text(emoji), findsWidgets);
    });

    testWidgets('editing an account can set an emoji', (tester) async {
      await pumpApp(tester);
      await goToTab(tester, 'settings');
      await tester.tap(find.byKey(const ValueKey('acc-edit-eva')));
      await tester.pumpAndSettle();
      expect(find.text('Edit account'), findsOneWidget);
      final emoji = await _pickEmoji(tester);
      await tester.tap(find.text('Save account'));
      await tester.pumpAndSettle();
      expect(find.text(emoji), findsWidgets);
    });

    testWidgets('editing a block can set an emoji', (tester) async {
      await pumpApp(tester);
      await goToTab(tester, 'settings');
      await tester.tap(find.byKey(const ValueKey('blk-edit-home')));
      await tester.pumpAndSettle();
      expect(find.text('Edit block'), findsOneWidget);
      final emoji = await _pickEmoji(tester);
      await tester.tap(find.text('Save block'));
      await tester.pumpAndSettle();
      expect(find.text(emoji), findsWidgets);
    });

    testWidgets('the glyph picker can clear a chosen emoji', (tester) async {
      await pumpApp(tester);
      await goToTab(tester, 'settings');
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      await _pickEmoji(tester);
      expect(find.byKey(const ValueKey('glyph-clear')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('glyph-clear')));
      await tester.pump();
      expect(find.byKey(const ValueKey('glyph-clear')), findsNothing);
    });

    testWidgets('glyphTile renders an uploaded picture over the fallback', (
      tester,
    ) async {
      const png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
          '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: glyphTile(
                size: 40,
                radius: 8,
                picture: png,
                fallback: const Text('FB'),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('FB'), findsNothing);
    });

    testWidgets('glyphTile renders a data-url picture over the fallback', (
      tester,
    ) async {
      const png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
          '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: glyphTile(
                size: 40,
                radius: 8,
                picture: 'data:image/png;base64,$png',
                fallback: const Text('FB'),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('FB'), findsNothing);
    });

    test('Category and Account persist emoji/picture across JSON', () {
      final c = Category(
        key: 'k',
        title: 'T',
        icon: 'folder',
        marker: 'date',
        tone: const Color(0xff2563eb),
        bg: const Color(0xffeeeeee),
        emoji: '🎮',
      );
      final cBack = Category.fromJson(c.toJson());
      expect(cBack.emoji, '🎮');
      expect(cBack.picture, isNull);

      final a = Account(
        key: 'k',
        name: 'N',
        short: 'S',
        initials: 'NS',
        color: const Color(0xff000000),
        picture: 'BASE64DATA',
      );
      final aBack = Account.fromJson(a.toJson());
      expect(aBack.picture, 'BASE64DATA');
      expect(aBack.emoji, isNull);
    });
  });
}
