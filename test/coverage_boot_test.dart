import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_money_management_app/main.dart' as app;

import 'helpers.dart';

void main() {
  testWidgets('main boots the app shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      await app.main();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('debug controller exercises auth and family actions', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: false);
    expect(find.text('Welcome back'), findsOneWidget);

    expect(
      await app.thriveDebug.signInWithEmail(
        email: 'tom@example.com',
        password: 'secret1',
        register: true,
        name: 'Tom Tester',
      ),
      isNull,
    );
    await tester.pumpAndSettle();
    expect(app.thriveDebug.user?.email, 'tom@example.com');
    expect(find.text('Overview'), findsOneWidget);

    expect(await app.thriveDebug.signInWithGoogle(), isNull);
    await tester.pumpAndSettle();
    expect(app.thriveDebug.user?.provider, 'google');

    app.thriveDebug.saveProfile('Tom T', null, Colors.blue);
    await tester.pumpAndSettle();
    expect(app.thriveDebug.user?.name, 'Tom T');

    expect(app.thriveDebug.amOwner(), isTrue);
    expect(app.thriveDebug.memberPill('owner', 'active').label, 'Owner');
    expect(app.thriveDebug.memberPill('member', 'invited').label, 'Invited');

    app.thriveDebug.renameFamily('Parents');
    await tester.pumpAndSettle();
    expect(app.thriveDebug.curFamily()?.name, 'Parents');

    app.thriveDebug.inviteMember('Lisa', 'lisa@example.com');
    await tester.pumpAndSettle();
    final invited = app.thriveDebug.curFamily()!.members.firstWhere(
      (m) => m.status == 'invited',
    );

    app.thriveDebug.editMember(invited.id, 'Lisa L', 'lisa2@example.com');
    app.thriveDebug.toggleMemberRole(invited.id);
    await tester.pumpAndSettle();
    final edited = app.thriveDebug.curFamily()!.members.firstWhere(
      (m) => m.id == invited.id,
    );
    expect(edited.name, 'Lisa L');
    expect(edited.email, 'lisa2@example.com');
    expect(edited.role, 'owner');

    app.thriveDebug.createFamily('Beach house');
    await tester.pumpAndSettle();
    final beachId = app.thriveDebug.familyId;
    expect(app.thriveDebug.families.length, 2);

    app.thriveDebug.switchFamily('fam_main');
    await tester.pumpAndSettle();
    expect(app.thriveDebug.familyId, 'fam_main');

    app.thriveDebug.deleteFamily(beachId);
    await tester.pumpAndSettle();
    expect(app.thriveDebug.families.length, 1);

    app.thriveDebug.removeMember(invited.id);
    await tester.pumpAndSettle();
    expect(
      app.thriveDebug.curFamily()!.members.any((m) => m.id == invited.id),
      isFalse,
    );

    app.thriveDebug.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
