import 'dart:convert';

import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    accountMeta
      ..clear()
      ..addAll(defaultAccountMeta);
    categoryMeta
      ..clear()
      ..addAll(defaultCategoryMeta);
  });

  testWidgets('renders the family budget dashboard', (tester) async {
    await pumpFamilyApp(tester, state: stateWithJune({'income': []}));

    expect(find.text('Huishoudboekje'), findsNothing);
    expect(find.text('June'), findsWidgets);
    expect(find.text('2026'), findsWidgets);
    expect(
      find.text('${greetingForHour(DateTime.now().hour)}, Eva'),
      findsOneWidget,
    );
    expect(find.text('Sum Up'), findsWidgets);
    expect(find.text('Statistics'), findsOneWidget);
  });

  testWidgets('desktop toolbar shows Thrive brand', (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFamilyApp(tester, state: stateWithJune({'income': []}));

    expect(find.text('Thrive'), findsOneWidget);
    expect(find.text('Huishoudboekje'), findsNothing);
  });

  testWidgets('month and year header fits on narrow phones', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFamilyApp(tester, state: stateWithJune({'income': []}));

    expect(find.text('June'), findsWidgets);
    expect(find.text('2026'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copy month lives inside settings', (tester) async {
    await pumpFamilyApp(tester, state: stateWithJune({'income': []}));

    expect(find.text('Copy one month to another'), findsNothing);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Month tools'), findsOneWidget);
    expect(find.text('Copy one month to another'), findsOneWidget);
  });

  testWidgets('statistics screen shows monthly and yearly tabs', (
    tester,
  ) async {
    await pumpFamilyApp(tester, state: stateWithJune(juneWithIncome()));

    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Month summary'), findsOneWidget);

    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();

    expect(find.text('Year summary'), findsOneWidget);
    expect(find.text('Monthly expenses'), findsOneWidget);
  });

  testWidgets('delete confirmation protects income from accidental removal', (
    tester,
  ) async {
    await pumpFamilyApp(tester, state: stateWithJune(juneWithIncome()));

    await tester.scrollUntilVisible(
      find.text('Tap to show 1 item'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tap to show 1 item'));
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete income'));
    await tester.pumpAndSettle();
    expect(find.text('Delete income?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete income'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Salary'), findsNothing);
    expect(find.text('Add income'), findsWidgets);
  });

  testWidgets('quick expense entry uses OS text fields and saves a new item', (
    tester,
  ) async {
    await pumpFamilyApp(tester, state: stateWithJune({'income': []}));

    await tester.tap(find.text('Log an expense').last);
    await tester.pumpAndSettle();
    expect(find.text('Pick a category'), findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New item'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(3));
    await tester.enterText(find.byType(TextField).first, 'Coffee');
    await tester.enterText(find.byType(TextField).last, '12,50');
    await tester.pump();

    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    expect(find.text('Logged € 12,50'), findsOneWidget);
  });

  testWidgets('income expected and actual values can be edited', (
    tester,
  ) async {
    await pumpFamilyApp(tester, state: stateWithJune(juneWithIncome()));

    await tester.scrollUntilVisible(
      find.text('Tap to show 1 item'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tap to show 1 item'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit income'));
    await tester.pumpAndSettle();
    expect(find.text('Edit income'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '1200');
    await tester.enterText(find.byType(TextField).at(1), '900');
    await tester.tap(find.text('Save income'));
    await tester.pumpAndSettle();

    expect(find.text('Expected € 1.200,00'), findsOneWidget);
    expect(find.text('€ 900,00'), findsWidgets);
  });

  testWidgets('expense payment date and debt end date can be edited', (
    tester,
  ) async {
    await pumpFamilyApp(tester, state: stateWithJune(juneWithDebt()));

    await tester.scrollUntilVisible(
      find.text('Tap to show 1 item'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tap to show 1 item'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit item'));
    await tester.pumpAndSettle();
    expect(find.text('DEBT END DATE'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '25');
    await tester.enterText(find.byType(TextField).at(2), '12-27');
    await tester.ensureVisible(find.text('Save item'));
    await tester.tap(find.text('Save item'));
    await tester.pumpAndSettle();

    expect(find.text('25'), findsOneWidget);
    expect(find.text('12-27'), findsOneWidget);
  });
}

Future<void> pumpFamilyApp(
  WidgetTester tester, {
  Map<String, dynamic>? state,
}) async {
  SharedPreferences.setMockInitialValues(
    state == null ? {} : {savedStateKey: jsonEncode(state)},
  );

  await tester.pumpWidget(const FamilyMoneyApp());
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Map<String, dynamic> stateWithJune(Map<String, dynamic> june) {
  return {
    'year': 2026,
    'monthIndex': 5,
    'years': {
      '2026': {'Juni': june},
    },
  };
}

Map<String, dynamic> juneWithIncome() {
  return {
    'income': [
      {
        'label': 'Salary',
        'expected': 1000,
        'actual': 1000,
        'received': true,
        'account': 'eva',
      },
    ],
  };
}

Map<String, dynamic> juneWithDebt() {
  return {
    'income': [],
    'debt': [
      {
        'label': 'Loan',
        'day': '15',
        'amount': 100,
        'paid': false,
        'account': 'shared',
        'until': '08-26',
      },
    ],
  };
}
