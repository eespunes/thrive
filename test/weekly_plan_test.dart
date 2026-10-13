import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The meal plan, 2a redesign (epic #500): day strip + dinner-first card
/// (#496), ingredient checklist onto Groceries (#497), the whole-day editor
/// (#498) and favourites (#499). The More hub's "Weekly plan" row opens the
/// compact Settings v2 dinner sub-page instead (#282) — covered below.
Future<void> goToWeekly(WidgetTester tester) async {
  thriveDebug.goTab('weekly');
  await tester.pumpAndSettle();
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String get _today => todayIso();
String get _todayName => _weekdays[DateTime.parse(_today).weekday - 1];

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(_key(key), text);
  await tester.pump();
}

/// The Groceries list's open lines matching [name] (case-insensitive).
int _onGroceries(String name) {
  final lists = thriveDebug.shoppingLists.where(
    (l) => l.name.toLowerCase() == 'groceries',
  );
  if (lists.isEmpty) return 0;
  return lists.first.items
      .where((i) => !i.checked && i.name.toLowerCase() == name.toLowerCase())
      .length;
}

void main() {
  testWidgets('week view: day strip, empty dinner card and tiles (#496)', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToWeekly(tester);

    expect(find.textContaining('MEALS · WEEK'), findsOneWidget);
    expect(find.byWidgetPredicate(_isDayCell), findsNWidgets(7));
    expect(_key('meal-day-$_today'), findsOneWidget);
    expect(find.text('DINNER · ${_todayName.toUpperCase()}'), findsOneWidget);
    expect(find.text('Plan dinner'), findsOneWidget);
    expect(find.text('Type it, or pick from favourites'), findsOneWidget);
    expect(find.text('Add breakfast'), findsOneWidget);
    expect(find.text('Add lunch'), findsOneWidget);
    expect(find.text('Add a note for the family…'), findsOneWidget);
    expect(_key('meal-dot-$_today'), findsNothing);
  });

  testWidgets('dots mark days with a dinner; tapping a day selects it', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    final monday = DateTime.parse(
      _today,
    ).subtract(Duration(days: DateTime.parse(_today).weekday - 1));
    final other = _iso(
      monday.add(Duration(days: DateTime.parse(_today).weekday == 3 ? 4 : 2)),
    );
    thriveDebug.saveDayPlan(
      other,
      DayPlan(
        dateIso: other,
        dinner: 'Chicken curry',
        ingredients: ['Chicken', 'Rice', 'Curry paste'],
        dinnerMinutes: 35,
        lunch: 'Soup',
      ),
    );
    await goToWeekly(tester);

    expect(_key('meal-dot-$other'), findsOneWidget);
    expect(_key('meal-dot-$_today'), findsNothing);
    expect(find.text('Plan dinner'), findsOneWidget);

    await _tap(tester, 'meal-day-$other');
    final name = _weekdays[DateTime.parse(other).weekday - 1];
    expect(find.text('DINNER · ${name.toUpperCase()}'), findsOneWidget);
    expect(find.text('Chicken curry'), findsOneWidget);
    expect(find.text('3 ingredients · 35 min'), findsOneWidget);
    expect(find.text('Soup'), findsOneWidget);
    expect(find.text('Add breakfast'), findsOneWidget);
  });

  testWidgets('week navigation moves the range and the picked day', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToWeekly(tester);
    final before = tester.widget<Text>(_key('week-range')).data;

    await _tap(tester, 'week-next');
    expect(tester.widget<Text>(_key('week-range')).data, isNot(before));
    final nextWeek = _iso(DateTime.parse(_today).add(const Duration(days: 7)));
    expect(_key('meal-day-$nextWeek'), findsOneWidget);
    expect(_key('meal-day-$_today'), findsNothing);

    await _tap(tester, 'week-prev');
    expect(tester.widget<Text>(_key('week-range')).data, before);
  });

  testWidgets('day editor saves the whole day only on Save (#498)', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToWeekly(tester);

    await _tap(tester, 'meal-plan-dinner');
    final d = DateTime.parse(_today);
    expect(find.textContaining('$_todayName ${d.day} '), findsOneWidget);
    expect(find.text('Whole day · shared with family'), findsOneWidget);
    expect(find.text('Optional'), findsOneWidget);

    await _type(tester, 'day-dinner', 'Veg stir-fry');
    await _type(tester, 'day-ing-new', 'Peppers');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await _type(tester, 'day-ing-new', 'Rice');
    await _tap(tester, 'day-ing-add');
    // Duplicates (any case) are ignored.
    await _type(tester, 'day-ing-new', 'rice');
    await _tap(tester, 'day-ing-add');
    expect(find.text('2 items'), findsOneWidget);
    await _type(tester, 'day-minutes', '20');
    await _type(tester, 'day-breakfast', 'Oats');
    await _type(tester, 'day-note', 'Football at 6');

    // Still only a draft.
    expect(thriveDebug.weeklyPlan[_today], isNull);

    await _tap(tester, 'day-save');
    final day = thriveDebug.weeklyPlan[_today]!;
    expect(day.dinner, 'Veg stir-fry');
    expect(day.ingredients, ['Peppers', 'Rice']);
    expect(day.dinnerMinutes, 20);
    expect(day.breakfast, 'Oats');
    expect(day.lunch, isNull);
    expect(day.note, 'Football at 6');

    expect(find.text('Veg stir-fry'), findsOneWidget);
    expect(find.text('2 ingredients · 20 min'), findsOneWidget);
    expect(find.text('Oats'), findsOneWidget);
    expect(find.text('Football at 6'), findsOneWidget);
    expect(_key('meal-dot-$_today'), findsOneWidget);

    // Removing an ingredient chip in the editor.
    await _tap(tester, 'meal-tile-lunch');
    await _tap(tester, 'day-ing-remove-Peppers');
    await _tap(tester, 'day-save');
    expect(thriveDebug.weeklyPlan[_today]!.ingredients, ['Rice']);
  });

  testWidgets('Cancel with edits asks before discarding the draft', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToWeekly(tester);

    // Untouched: Cancel just closes.
    await _tap(tester, 'meal-edit');
    await _tap(tester, 'day-cancel');
    expect(_key('day-dinner'), findsNothing);
    expect(find.text('Discard changes?'), findsNothing);

    await _tap(tester, 'meal-edit');
    await _type(tester, 'day-dinner', 'Tacos');
    await _tap(tester, 'day-cancel');
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Tacos'), findsOneWidget);

    await _tap(tester, 'day-cancel');
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(_key('day-dinner'), findsNothing);
    expect(thriveDebug.weeklyPlan[_today], isNull);
    expect(find.text('Plan dinner'), findsOneWidget);
  });

  testWidgets('"Clear this day" only empties the draft until Save', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.saveDayPlan(
      _today,
      DayPlan(
        dateIso: _today,
        dinner: 'Pizza',
        ingredients: ['Dough'],
        breakfast: 'Toast',
        note: 'Movie night',
      ),
    );
    await goToWeekly(tester);

    await _tap(tester, 'meal-edit');
    await _tap(tester, 'day-clear');
    expect(
      tester.widget<TextField>(_key('day-dinner')).controller!.text,
      isEmpty,
    );
    expect(_key('day-ing-Dough'), findsNothing);
    // Not persisted yet.
    expect(thriveDebug.weeklyPlan[_today]?.dinner, 'Pizza');

    await _tap(tester, 'day-save');
    expect(thriveDebug.weeklyPlan[_today], isNull);
    expect(find.text('Plan dinner'), findsOneWidget);
    expect(find.text('Add breakfast'), findsOneWidget);
  });

  testWidgets('ingredients tick onto Groceries without duplicates (#497)', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.saveDayPlan(
      _today,
      DayPlan(
        dateIso: _today,
        dinner: 'Spaghetti bolognese',
        ingredients: ['Pasta', 'Minced beef', 'Tomatoes'],
      ),
    );
    await goToWeekly(tester);
    expect(find.text('Add 3 missing to Groceries'), findsOneWidget);

    await _tap(tester, 'meal-ing-Pasta');
    expect(_onGroceries('Pasta'), 1);
    expect(find.text('On list'), findsOneWidget);
    expect(find.text('Add 2 missing to Groceries'), findsOneWidget);

    // Already on the list under another case: counted as present.
    final groceries = thriveDebug.shoppingLists.firstWhere(
      (l) => l.name.toLowerCase() == 'groceries',
    );
    groceries.items.add(ShopItem(id: 'x-tom', name: 'TOMATOES'));
    await _tap(tester, 'meal-ing-Pasta'); // untick Pasta again
    expect(_onGroceries('Pasta'), 0);
    expect(find.text('Add 2 missing to Groceries'), findsOneWidget);

    await _tap(tester, 'meal-groceries-all');
    expect(_onGroceries('Pasta'), 1);
    expect(_onGroceries('Minced beef'), 1);
    expect(_onGroceries('Tomatoes'), 1);
    expect(find.text('Everything is on Groceries'), findsOneWidget);
    expect(find.text('On list'), findsNWidgets(3));

    // Pressing it again adds nothing.
    await _tap(tester, 'meal-groceries-all');
    expect(_onGroceries('Pasta'), 1);
    expect(_onGroceries('Tomatoes'), 1);
  });

  testWidgets('heart saves / removes the dinner as a favourite (#499)', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    await goToWeekly(tester);
    final before = thriveDebug.savedMeals.length;

    await _tap(tester, 'meal-plan-dinner');
    // Nothing typed yet: the heart does nothing.
    await _tap(tester, 'day-fav');
    expect(thriveDebug.savedMeals.length, before);

    await _type(tester, 'day-dinner', 'Grandma soup');
    await _type(tester, 'day-ing-new', 'Leeks');
    await _tap(tester, 'day-ing-add');
    expect(
      find.descendant(of: _key('day-fav'), matching: find.text('Save')),
      findsOneWidget,
    );
    await _tap(tester, 'day-fav');
    expect(thriveDebug.savedMeals.length, before + 1);
    final saved = thriveDebug.savedMeals.last;
    expect(saved.name, 'Grandma soup');
    expect(saved.ingredients, ['Leeks']);
    expect(
      find.descendant(of: _key('day-fav'), matching: find.text('Favourite')),
      findsOneWidget,
    );

    await _tap(tester, 'day-fav');
    expect(thriveDebug.savedMeals.length, before);
    expect(
      find.descendant(of: _key('day-fav'), matching: find.text('Save')),
      findsOneWidget,
    );
  });

  testWidgets('favourites search by name / ingredient and pick (#499)', (
    tester,
  ) async {
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.savedMeals.clear();
    for (final (n, ings) in [
      ('Chicken curry', ['Chicken', 'Rice', 'Curry paste']),
      ('Spaghetti bolognese', ['Pasta', 'Minced beef']),
      ('Fish & potatoes', ['Cod', 'Potatoes']),
      ('Chicken wraps', ['Chicken', 'Tortillas']),
      ('Chickpea stew', ['Chickpeas', 'Spinach']),
    ]) {
      thriveDebug.toggleFavouriteMeal(n, ings);
    }
    await goToWeekly(tester);
    await _tap(tester, 'meal-plan-dinner');

    // The list only appears once typing.
    expect(find.text('5 saved'), findsOneWidget);
    expect(_key('day-fav-results'), findsNothing);

    await _type(tester, 'day-fav-search', 'rice');
    expect(find.text('1 found'), findsOneWidget);
    expect(find.text('Contains rice'), findsOneWidget);

    await _type(tester, 'day-fav-search', 'zzz');
    expect(find.text('No favourites match “zzz”'), findsOneWidget);

    // Four hits: three rows visible, the rest scrolls.
    await _type(tester, 'day-fav-search', 'chick');
    expect(find.text('3 found'), findsOneWidget);
    await _type(tester, 'day-fav-search', 'c');
    final h = tester.getSize(_key('day-fav-results')).height;
    expect(h, lessThanOrEqualTo(166));
    expect(h, greaterThan(3 * 55 - 1));

    await _type(tester, 'day-fav-search', 'curry');
    await tester.tap(find.text('Chicken curry'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_key('day-dinner')).controller!.text,
      'Chicken curry',
    );
    expect(_key('day-ing-Curry paste'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('Filled in from your library'), findsOneWidget);
    // Picked into the draft only.
    expect(thriveDebug.weeklyPlan[_today], isNull);

    await _tap(tester, 'day-fav-search-clear');
    expect(_key('day-fav-results'), findsNothing);

    await _tap(tester, 'day-save');
    expect(thriveDebug.weeklyPlan[_today]!.ingredients, [
      'Chicken',
      'Rice',
      'Curry paste',
    ]);
    expect(thriveDebug.savedMeals.length, 5);
  });

  testWidgets(
    'More → Weekly plan opens the inline dinner sub-page and autosaves (#282)',
    (tester) async {
      await pumpApp(tester, landOnDefaultTab: true);
      await tester.tap(find.byKey(const ValueKey('nav-more')));
      await tester.pumpAndSettle();
      await tapHubRow(tester, 'planning', 'more-weekly');

      expect(find.text('Weekly plan'), findsWidgets);
      expect(find.textContaining('saves as you go'), findsOneWidget);
      expect(find.byKey(const ValueKey('weekly-dinner-6')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('weekly-dinner-0')),
        'Pizza night',
      );
      await tester.pump();
      expect(
        thriveDebug.weeklyPlan.values.any((d) => d.dinner == 'Pizza night'),
        isTrue,
      );

      // Clearing the field prunes the (now empty) day again.
      await tester.enterText(find.byKey(const ValueKey('weekly-dinner-0')), '');
      await tester.pump();
      expect(
        thriveDebug.weeklyPlan.values.any((d) => d.dinner == 'Pizza night'),
        isFalse,
      );
    },
  );
}

bool _isDayCell(Widget w) =>
    w is GestureDetector &&
    w.key is ValueKey<String> &&
    (w.key as ValueKey<String>).value.startsWith('meal-day-');

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
