import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1×1 PNG for photo-badge assertions.
const String kTinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('BadgeStudioScaffold', () {
    testWidgets('save is grey and inert until valid, tinted when valid', (
      tester,
    ) async {
      var saved = 0;
      var enabled = false;
      late StateSetter setOuter;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return BadgeStudioScaffold(
                title: 'Edit block',
                subtitle: 'A column of the monthly budget.',
                accent: const Color(0xffd97706),
                saveLabel: 'Save block',
                saveEnabled: enabled,
                onSave: () => saved++,
                children: const [SizedBox(height: 20)],
              );
            },
          ),
        ),
      );
      expect(find.text('Edit block'), findsOneWidget);
      expect(find.text('A column of the monthly budget.'), findsOneWidget);

      // Disabled: grey, tap does nothing.
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pump();
      expect(saved, 0);
      var box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('studio-save')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (box.decoration as BoxDecoration?)?.color,
        const Color(0xffe2e8f0),
      );

      // Valid: tinted in the badge colour and tappable.
      setOuter(() => enabled = true);
      await tester.pump(const Duration(milliseconds: 200));
      box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('studio-save')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (box.decoration as BoxDecoration?)?.color,
        const Color(0xffd97706),
      );
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      expect(saved, 1);
    });

    testWidgets('pushes full screen; delete link under save opens the counting '
        'confirm; back pops', (tester) async {
      var deleted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => pushBadgeStudio<void>(
                  context,
                  (_) => Builder(
                    builder: (ctx) => BadgeStudioScaffold(
                      title: 'Edit layer',
                      accent: B.primary,
                      saveLabel: 'Save layer',
                      saveEnabled: true,
                      onSave: () {},
                      deleteLabel:
                          'Delete layer — its events move to another layer',
                      onDelete: () => showCountingConfirmSheet(
                        ctx,
                        title: 'Delete "Workouts"?',
                        message:
                            'It takes its 4 events with it — they move to '
                            'another layer.',
                        confirmLabel: 'Delete layer',
                        onConfirm: () => deleted++,
                      ),
                      children: const [SizedBox(height: 10)],
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Edit layer'), findsOneWidget);

      // The counting confirm spells out what the item takes with it.
      await tester.tap(find.byKey(const ValueKey('studio-delete')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'It takes its 4 events with it — they move to another layer.',
        ),
        findsOneWidget,
      );

      // Cancel closes without deleting.
      await tester.tap(find.byKey(const ValueKey('counting-confirm-cancel')));
      await tester.pumpAndSettle();
      expect(deleted, 0);

      // Confirm runs the delete and closes the sheet.
      await tester.tap(find.byKey(const ValueKey('studio-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('counting-confirm-go')));
      await tester.pumpAndSettle();
      expect(deleted, 1);
      expect(find.text('Delete "Workouts"?'), findsNothing);

      // ‹ back pops the editor.
      await tester.tap(find.byKey(const ValueKey('studio-back')));
      await tester.pumpAndSettle();
      expect(find.text('Edit layer'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('BadgeStage', () {
    testWidgets(
      'badge tap opens the photo picker; a picture replaces the emoji',
      (tester) async {
        var picks = 0;
        await tester.pumpWidget(
          harness(
            BadgeStage(
              color: const Color(0xff7c3aed),
              name: 'Family',
              onName: (_) {},
              emoji: '👪',
              onEmoji: (_) {},
              onPickPhoto: () => picks++,
            ),
          ),
        );
        expect(find.text('👪'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('badge-stage-badge')));
        expect(picks, 1);

        // With a picture set, the badge shows the photo instead.
        await tester.pumpWidget(
          harness(
            BadgeStage(
              color: const Color(0xff7c3aed),
              name: 'Family',
              onName: (_) {},
              emoji: '👪',
              picture: kTinyPng,
              onEmoji: (_) {},
              onPickPhoto: () {},
            ),
          ),
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('badge-stage-badge')),
            matching: find.byType(Image),
          ),
          findsOneWidget,
        );
        expect(find.text('👪'), findsNothing);
      },
    );

    testWidgets('inline name edits in the item colour reach onName', (
      tester,
    ) async {
      String? name;
      await tester.pumpWidget(
        harness(
          BadgeStage(
            color: const Color(0xff0E9A8D),
            name: 'Work',
            onName: (v) => name = v,
            emoji: '💼',
            onEmoji: (_) {},
            onPickPhoto: () {},
          ),
        ),
      );
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('badge-stage-name')),
      );
      expect(field.style?.color, const Color(0xff0E9A8D));
      await tester.enterText(
        find.byKey(const ValueKey('badge-stage-name')),
        'Deep work',
      );
      expect(name, 'Deep work');
    });

    testWidgets(
      '"type an emoji" free input accepts any multi-codepoint OS emoji',
      (tester) async {
        final applied = <String>[];
        final toasts = <String>[];
        await tester.pumpWidget(
          harness(
            BadgeStage(
              color: B.primary,
              name: 'Sports',
              onName: (_) {},
              emoji: '⚽',
              onEmoji: applied.add,
              onPickPhoto: () {},
              onToast: toasts.add,
            ),
          ),
        );
        // Closed by default; the link opens the free input — no emoji grids.
        expect(
          find.byKey(const ValueKey('badge-stage-emoji-input')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-link')));
        await tester.pump();

        // Empty input only nudges.
        await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-use')));
        await tester.pump();
        expect(applied, isEmpty);
        expect(toasts, ['Type an emoji first — any one your keyboard has']);

        // A ZWJ family emoji (11 UTF-16 code units) is kept whole.
        await tester.enterText(
          find.byKey(const ValueKey('badge-stage-emoji-input')),
          '👨‍👩‍👧‍👦',
        );
        await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-use')));
        await tester.pump();
        expect(applied, ['👨‍👩‍👧‍👦']);
        expect(toasts.last, 'Emoji set');
        // Applying closes the input again.
        expect(
          find.byKey(const ValueKey('badge-stage-emoji-input')),
          findsNothing,
        );

        // Overlong pastes fall back to the first grapheme.
        await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-link')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('badge-stage-emoji-input')),
          '🦖 rawr rawr',
        );
        await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-use')));
        await tester.pump();
        expect(applied.last, '🦖');
      },
    );
  });

  group('BadgeStage extras', () {
    testWidgets(
      'falls back to the default glyph, mirrors external renames, and the '
      'emoji input submits from the keyboard',
      (tester) async {
        final applied = <String>[];
        var name = 'Cats';
        late StateSetter setOuter;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  setOuter = setState;
                  return BadgeStage(
                    color: B.primary,
                    name: name,
                    onName: (_) {},
                    onEmoji: applied.add,
                    onPickPhoto: () {},
                  );
                },
              ),
            ),
          ),
        );
        // No emoji + no picture → the fallback glyph.
        expect(find.text('🏷'), findsOneWidget);

        // A rename coming from outside the widget lands in the field.
        setOuter(() => name = 'Dogs');
        await tester.pump();
        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('badge-stage-name')),
        );
        expect(field.controller?.text, 'Dogs');

        // The emoji input also applies on keyboard submit.
        await tester.tap(find.byKey(const ValueKey('badge-stage-emoji-link')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('badge-stage-emoji-input')),
          '🐶',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(applied, ['🐶']);
      },
    );
  });

  group('BadgeColorRow', () {
    testWidgets('picks free colours; taken dots only toast', (tester) async {
      const teal = Color(0xff0E9A8D);
      const blue = Color(0xff1684B4);
      const purple = Color(0xff7c3aed);
      Color? picked;
      final toasts = <String>[];
      await tester.pumpWidget(
        harness(
          BadgeColorRow(
            colors: const [teal, blue, purple],
            selected: teal,
            taken: const [purple],
            onPick: (c) => picked = c,
            onToast: toasts.add,
          ),
        ),
      );
      expect(find.text('BADGE COLOUR'), findsOneWidget);
      expect(find.text('✓'), findsOneWidget); // selected
      expect(find.text('×'), findsOneWidget); // taken

      await tester.tap(find.byKey(ValueKey('badge-color-${blue.toARGB32()}')));
      expect(picked, blue);

      await tester.tap(
        find.byKey(ValueKey('badge-color-${purple.toARGB32()}')),
      );
      expect(picked, blue); // unchanged
      expect(toasts, ['That colour is taken in this family']);
    });
  });

  group('SettingsSubScreen', () {
    testWidgets(
      'chrome renders and the add pattern creates then opens the editor',
      (tester) async {
        final toasts = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: SettingsSubScreen(
              title: 'Calendar layers',
              subtitle: 'Appointments, to-dos & content',
              intro: 'Toggle or add layers — hold a row and drag to rearrange.',
              footnote:
                  'Deleting a layer (inside its editor) moves its events to '
                  'another layer.',
              addPlaceholder: 'New layer label…',
              onToast: toasts.add,
              onAdd: (name) {
                // The add pattern: create with defaults, then immediately
                // open the item's editor.
                final ctx = tester.element(find.byType(SettingsSubScreen));
                pushBadgeStudio<void>(
                  ctx,
                  (_) => BadgeStudioScaffold(
                    title: 'Edit layer',
                    subtitle: name,
                    accent: B.primary,
                    saveLabel: 'Save layer',
                    saveEnabled: true,
                    onSave: () {},
                    children: const [SizedBox(height: 8)],
                  ),
                );
              },
              children: const [Text('Appointments'), Text('To-Dos')],
            ),
          ),
        );
        expect(find.text('Calendar layers'), findsOneWidget);
        expect(
          find.text('Toggle or add layers — hold a row and drag to rearrange.'),
          findsOneWidget,
        );
        expect(find.textContaining('moves its events'), findsOneWidget);

        // Empty add only nudges.
        await tester.tap(find.byKey(const ValueKey('list-add-button')));
        await tester.pump();
        expect(toasts, ['Type a name first']);

        // Named add creates and lands in the editor straight away (keyboard
        // submit works just like the Add button).
        await tester.enterText(
          find.byKey(const ValueKey('list-add-input')),
          'Workouts',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('Edit layer'), findsOneWidget);
        expect(find.text('Workouts'), findsOneWidget);

        // Back on the list, the input was cleared.
        await tester.tap(find.byKey(const ValueKey('studio-back')));
        await tester.pumpAndSettle();
        final input = tester.widget<TextField>(
          find.byKey(const ValueKey('list-add-input')),
        );
        expect(input.controller?.text, isEmpty);
      },
    );
  });

  group('HoldDragList', () {
    Widget dragHarness({
      required List<String> items,
      required void Function(int, int) onReorder,
      required ValueChanged<String> onToast,
      required VoidCallback onRowTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: HoldDragList(
            itemCount: items.length,
            onReorder: onReorder,
            onToast: onToast,
            itemBuilder: (context, i) => GestureDetector(
              onTap: onRowTap,
              child: Container(
                height: 48,
                alignment: Alignment.centerLeft,
                color: B.page,
                child: Text(items[i]),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'holding ~0.3s lifts the row and dragging reorders live with a toast',
      (tester) async {
        final items = ['Appointments', 'To-Dos', 'Content'];
        final toasts = <String>[];
        (int, int)? moved;
        await tester.pumpWidget(
          dragHarness(
            items: items,
            onReorder: (a, b) => moved = (a, b),
            onToast: toasts.add,
            onRowTap: () {},
          ),
        );
        final start = tester.getCenter(find.text('Appointments'));
        final gesture = await tester.startGesture(start);
        // The ~0.3s hold lifts the row.
        await tester.pump(const Duration(milliseconds: 350));
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(0, 16));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(moved, (0, 1));
        expect(toasts, ['Order saved for the whole family']);
      },
    );

    testWidgets('a plain tap still opens the row (no drag)', (tester) async {
      var taps = 0;
      var reorders = 0;
      await tester.pumpWidget(
        dragHarness(
          items: const ['Appointments', 'To-Dos'],
          onReorder: (_, _) => reorders++,
          onToast: (_) {},
          onRowTap: () => taps++,
        ),
      );
      await tester.tap(find.text('To-Dos'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(reorders, 0);
    });
  });
}
