import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

import 'helpers.dart';

void main() {
  test('a detached debug controller throws a StateError', () {
    expect(() => ThriveDebugController().tab, throwsStateError);
  });

  testWidgets('debug facade misc: signInUser, move account/block, errors', (
    tester,
  ) async {
    await pumpApp(tester);

    thriveDebug.signInUser(
      AppUser(
        name: 'Nora',
        email: 'nora@email.com',
        initials: 'N',
        provider: 'password',
      ),
    );
    await tester.pumpAndSettle();
    expect(thriveDebug.user?.name, 'Nora');

    final acc = thriveDebug.accountsForMonth(5).first.key;
    thriveDebug.moveAccount(acc, 1);
    final cat = thriveDebug.catsForMonth(5).firstWhere((c) => !c.isIncome).key;
    thriveDebug.moveBlock(cat, 1);
    await tester.pumpAndSettle();

    thriveDebug.showError('Something went sideways');
    await tester.pumpAndSettle();
    thriveDebug.dismissError();
    await tester.pumpAndSettle();
  });

  testWidgets('restoreV4 falls back when the active family is missing', (
    tester,
  ) async {
    await pumpApp(tester);
    thriveDebug.restoreV4({
      'year': 2026,
      'monthIdx': 5,
      'screen': 'settings',
      'familyId': 'ghost',
      'families': const [],
      'workspaces': {'fam_x': Workspace.empty().toJson()},
    });
    await tester.pumpAndSettle();
    expect(thriveDebug.familyId, 'fam_x');
    // Legacy 'settings' screen routes to the More hub, whose Money rows now
    // open the Settings v2 sub-screens.
    expect(thriveDebug.tab, 'more');
  });

  testWidgets('askDelete with a custom confirm label can be cancelled', (
    tester,
  ) async {
    await pumpApp(tester);
    var confirmed = false;
    thriveDebug.askDelete(
      'Thing',
      'It will be gone.',
      () => confirmed = true,
      confirmLabel: 'Remove',
    );
    await tester.pumpAndSettle();
    expect(find.text('Remove'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);
  });
}
