import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

void main() {
  group('ListTask', () {
    test('round-trips through toJson/fromJson with every field set', () {
      final t = ListTask(
        id: 't1',
        title: 'Take out bins',
        done: true,
        assignee: 'm1',
        due: '2026-08-30',
        createdBy: 'me',
        completedBy: 'm1',
      );

      final restored = ListTask.fromJson(t.toJson());

      expect(restored.id, 't1');
      expect(restored.title, 'Take out bins');
      expect(restored.done, isTrue);
      expect(restored.assignee, 'm1');
      expect(restored.due, '2026-08-30');
      expect(restored.createdBy, 'me');
      expect(restored.completedBy, 'm1');
    });

    test('due only survives in the yyyy-mm-dd shape', () {
      expect(ListTask.fromJson(const {'due': '2026-08-30'}).due, '2026-08-30');
      // Calendar-era shapes (epoch ints, labels) are dropped, not crashed on.
      expect(ListTask.fromJson(const {'due': 1756500000000}).due, isNull);
      expect(ListTask.fromJson(const {'due': 'tomorrow'}).due, isNull);
    });

    test('fromJson fills sensible defaults when fields are missing', () {
      final t = ListTask.fromJson(const {});
      expect(t.id, isNotEmpty);
      expect(t.title, '');
      expect(t.done, isFalse);
      expect(t.assignee, isNull);
      expect(t.createdBy, isNull);
      expect(t.completedBy, isNull);
    });

    test('fromJson ignores legacy due/recurrence fields from old data '
        'instead of crashing', () {
      final t = ListTask.fromJson(const {
        'id': 't1',
        'title': 'Legacy task',
        'due': '2026-08-01',
        'recur': 'weekly',
        'recurEvery': 2,
        'recurUnit': 'day',
        'recurWeekdays': [2, 4],
        'exceptions': ['2026-08-08'],
        'doneDates': {'2026-08-01': true},
      });
      expect(t.id, 't1');
      expect(t.title, 'Legacy task');
    });
  });

  group('TaskList', () {
    test('round-trips through toJson/fromJson including nested tasks', () {
      final list = TaskList(
        id: 'l1',
        name: 'Household',
        color: kMemberColors[1],
        emoji: '🧹',
        tasks: [ListTask(id: 't1', title: 'Vacuum')],
      );

      final restored = TaskList.fromJson(list.toJson());

      expect(restored.id, 'l1');
      expect(restored.name, 'Household');
      expect(restored.color, kMemberColors[1]);
      expect(restored.emoji, '🧹');
      expect(restored.tasks, hasLength(1));
      expect(restored.tasks.first.title, 'Vacuum');
    });

    test('round-trips a picture', () {
      final list = TaskList(
        id: 'l1',
        name: 'Household',
        color: kMemberColors[1],
        picture: 'base64==',
      );
      final restored = TaskList.fromJson(list.toJson());
      expect(restored.picture, 'base64==');
    });

    test('fromJson fills sensible defaults when fields are missing', () {
      final list = TaskList.fromJson(const {});
      expect(list.id, isNotEmpty);
      expect(list.name, 'New list');
      expect(list.color, isA<Color>());
      expect(list.tasks, isEmpty);
    });
  });

  group('ShopItem', () {
    test('round-trips through toJson/fromJson with every field set', () {
      final item = ShopItem(
        id: 'i1',
        name: 'Milk',
        qty: 3,
        checked: true,
        addedBy: 'me',
      );

      final restored = ShopItem.fromJson(item.toJson());

      expect(restored.id, 'i1');
      expect(restored.name, 'Milk');
      expect(restored.qty, 3);
      expect(restored.checked, isTrue);
      expect(restored.addedBy, 'me');
    });

    test('fromJson defaults and clamps quantity when missing/invalid', () {
      final item = ShopItem.fromJson(const {});
      expect(item.id, isNotEmpty);
      expect(item.name, '');
      expect(item.qty, 1);
      expect(item.checked, isFalse);
      expect(item.addedBy, isNull);

      final zero = ShopItem.fromJson(const {'qty': 0});
      expect(zero.qty, 1);
    });
  });

  group('ShoppingList', () {
    test('round-trips through toJson/fromJson including nested items', () {
      final list = ShoppingList(
        id: 's1',
        name: 'Supermarket',
        items: [ShopItem(id: 'i1', name: 'Eggs')],
      );

      final restored = ShoppingList.fromJson(list.toJson());

      expect(restored.id, 's1');
      expect(restored.name, 'Supermarket');
      expect(restored.items, hasLength(1));
      expect(restored.items.first.name, 'Eggs');
    });

    test('fromJson fills sensible defaults when fields are missing', () {
      final list = ShoppingList.fromJson(const {});
      expect(list.id, isNotEmpty);
      expect(list.name, 'New list');
      expect(list.items, isEmpty);
    });
  });

  group('DayPlan', () {
    test('round-trips through toJson/fromJson with every field set', () {
      final day = DayPlan(
        dateIso: '2026-08-01',
        breakfast: 'Oats',
        lunch: 'Salad',
        dinner: 'Pasta',
        note: 'Bring cake',
      );

      final restored = DayPlan.fromJson(day.toJson());

      expect(restored.dateIso, '2026-08-01');
      expect(restored.breakfast, 'Oats');
      expect(restored.lunch, 'Salad');
      expect(restored.dinner, 'Pasta');
      expect(restored.note, 'Bring cake');
      expect(day.isEmpty, isFalse);
    });

    test('fromJson treats empty strings as null, and isEmpty is true', () {
      final day = DayPlan.fromJson(const {
        'dateIso': '2026-08-02',
        'breakfast': '',
        'lunch': '',
        'dinner': '',
        'note': '',
      });
      expect(day.breakfast, isNull);
      expect(day.lunch, isNull);
      expect(day.dinner, isNull);
      expect(day.note, isNull);
      expect(day.isEmpty, isTrue);
    });

    test('fromJson fills sensible defaults when fields are missing', () {
      final day = DayPlan.fromJson(const {});
      expect(day.dateIso, '');
      expect(day.breakfast, isNull);
      expect(day.isEmpty, isTrue);
    });
  });

  group('meal plan 2a (#495)', () {
    test('an old day record reads and writes back unchanged', () {
      const old = {'dateIso': '2026-08-01', 'dinner': 'Pasta', 'note': 'Hi'};
      final day = DayPlan.fromJson(old);
      expect(day.ingredients, isEmpty);
      expect(day.dinnerMinutes, isNull);
      expect(day.toJson(), old);
    });

    test('ingredients and time to make round-trip', () {
      final day = DayPlan(
        dateIso: '2026-08-01',
        dinner: 'Curry',
        ingredients: ['Chicken', 'Rice'],
        dinnerMinutes: 35,
      );
      final back = DayPlan.fromJson(day.toJson());
      expect(back.ingredients, ['Chicken', 'Rice']);
      expect(back.dinnerMinutes, 35);
      expect(DayPlan(dateIso: 'x', ingredients: ['Rice']).isEmpty, isFalse);
    });

    test('SavedMeal round-trips', () {
      final m = SavedMeal(
        id: 'm1',
        name: 'Curry',
        ingredients: ['Chicken'],
        minutes: 30,
      );
      final back = SavedMeal.fromJson(m.toJson());
      expect(back.id, 'm1');
      expect(back.name, 'Curry');
      expect(back.ingredients, ['Chicken']);
      expect(back.minutes, 30);
      expect(SavedMeal(id: 'm2', name: 'Soup').toJson(), {
        'id': 'm2',
        'name': 'Soup',
      });
    });

    test('cleanIngredients trims, drops blanks and case-insensitive dupes', () {
      expect(cleanIngredients([' Rice ', '', 'rice', 'Peas', 'PEAS']), [
        'Rice',
        'Peas',
      ]);
    });

    test('cleanDayPlan drops ingredients and time without a dinner', () {
      final day = cleanDayPlan(
        '2026-08-01',
        DayPlan(
          dateIso: '',
          dinner: '  ',
          lunch: ' Soup ',
          ingredients: ['Rice'],
          dinnerMinutes: 20,
        ),
      );
      expect(day.dateIso, '2026-08-01');
      expect(day.dinner, isNull);
      expect(day.lunch, 'Soup');
      expect(day.ingredients, isEmpty);
      expect(day.dinnerMinutes, isNull);
    });

    final library = [
      SavedMeal(id: '1', name: 'Chicken curry', ingredients: ['Rice']),
      SavedMeal(id: '2', name: 'Fried rice', ingredients: ['Eggs']),
      SavedMeal(id: '3', name: 'Pizza', ingredients: ['Dough', 'Basmati rice']),
    ];

    test('search matches names first, then ingredients', () {
      expect(searchSavedMeals(library, '  '), isEmpty);
      final hits = searchSavedMeals(library, 'RICE');
      expect(hits.map((h) => h.meal.id).toSet(), {'1', '2', '3'});
      final byId = {for (final h in hits) h.meal.id: h.ingredient};
      expect(byId['2'], isNull); // name match
      expect(byId['1'], 'Rice');
      expect(byId['3'], 'Basmati rice');
      expect(searchSavedMeals(library, 'zzz'), isEmpty);
    });

    test('savedMealNamed ignores case and spacing', () {
      expect(savedMealNamed(library, ' pizza ')?.id, '3');
      expect(savedMealNamed(library, ''), isNull);
    });

    test('Groceries detection is case-insensitive and skips ticked lines', () {
      final other = ShoppingList(id: 'a', name: 'Hardware');
      final groceries = ShoppingList(
        id: 'g',
        name: 'groceries',
        items: [
          ShopItem(id: '1', name: 'TOMATOES'),
          ShopItem(id: '2', name: 'Pasta', checked: true),
        ],
      );
      expect(groceriesListOf([other, groceries]), groceries);
      expect(groceriesListOf([other]), other);
      expect(groceriesListOf([]), isNull);
      expect(groceryLineFor(groceries, 'tomatoes')?.id, '1');
      expect(groceryLineFor(groceries, 'pasta'), isNull);
      expect(missingGroceries(groceries, ['Tomatoes', 'Pasta', 'Basil']), [
        'Pasta',
        'Basil',
      ]);
      expect(missingGroceries(null, ['Basil']), ['Basil']);
    });
  });
}
