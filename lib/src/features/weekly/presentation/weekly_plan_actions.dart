part of 'package:family_money_management_app/main.dart';

/// Mutations for the weekly meal plan (#157, redesign epic #500). Meals,
/// notes, the saved-meal library and the Groceries ticks all live on the
/// active family's [Workspace], so these ride the same `mutate()` → persist
/// → cloud-sync pipeline as Lists.
extension _ThriveWeeklyPlanActions on _ThriveHomeState {
  DayPlan? dayPlan(String dateIso) => weeklyPlan[dateIso];

  void setMeal(String dateIso, String slot, String value) {
    if (childBlocked(kChildMealPlanReadOnly)) return;
    mutate(() {
      final trimmed = value.trim();
      final day = weeklyPlan.putIfAbsent(
        dateIso,
        () => DayPlan(dateIso: dateIso),
      );
      switch (slot) {
        case 'breakfast':
          day.breakfast = trimmed.isEmpty ? null : trimmed;
          break;
        case 'lunch':
          day.lunch = trimmed.isEmpty ? null : trimmed;
          break;
        case 'dinner':
          day.dinner = trimmed.isEmpty ? null : trimmed;
          // The ingredients belong to the dinner: no dinner, no ingredients.
          if (trimmed.isEmpty) {
            day.ingredients = [];
            day.dinnerMinutes = null;
          }
          break;
      }
      if (day.isEmpty) weeklyPlan.remove(dateIso);
    });
  }

  /// Saves the day editor's [draft] over the whole day (#498). An empty
  /// draft ("Clear this day" + Save) removes the day.
  void saveDayPlan(String dateIso, DayPlan draft) {
    if (childBlocked(kChildMealPlanReadOnly)) return;
    final day = cleanDayPlan(dateIso, draft);
    final label = _weekdayLong(dateIso);
    mutate(() {
      if (day.isEmpty) {
        weeklyPlan.remove(dateIso);
      } else {
        weeklyPlan[dateIso] = day;
      }
    }, () => flash(day.isEmpty ? '$label cleared' : '$label saved'));
  }

  /// Whether [name] is in the family's saved-meal library.
  bool isFavouriteMeal(String? name) =>
      savedMealNamed(savedMeals, name) != null;

  /// The heart next to the dinner field (#499): saves [name] with its
  /// current [ingredients] to the library, or removes it when it's there.
  /// Returns whether the dish is a favourite afterwards.
  bool toggleFavouriteMeal(
    String name,
    List<String> ingredients, {
    int? minutes,
  }) {
    final n = name.trim();
    if (n.isEmpty || childBlocked(kChildMealPlanReadOnly)) {
      return isFavouriteMeal(n);
    }
    final existing = savedMealNamed(savedMeals, n);
    mutate(
      () {
        if (existing != null) {
          savedMeals.remove(existing);
        } else {
          savedMeals.add(
            SavedMeal(
              id: uid(),
              name: n,
              ingredients: cleanIngredients(ingredients),
              minutes: minutes,
            ),
          );
        }
      },
      () => flash(
        existing != null ? 'Removed from favourites' : 'Saved to favourites',
      ),
    );
    return existing == null;
  }

  /// The family's Groceries list, created on first use.
  ShoppingList _ensureGroceries() {
    final l = groceriesListOf(shoppingLists);
    if (l != null) return l;
    final created = ShoppingList(
      id: uid(),
      name: 'Groceries',
      color: B.paperGreen,
      createdBy: myId,
    );
    shoppingLists.add(created);
    return created;
  }

  void _putOnGroceries(ShoppingList list, String ingredient) {
    final k = mealKey(ingredient);
    for (final it in list.items) {
      // A crossed-off line is brought back instead of duplicated.
      if (mealKey(it.name) == k) {
        it.checked = false;
        return;
      }
    }
    list.items.add(ShopItem(id: uid(), name: ingredient.trim(), addedBy: myId));
  }

  /// Ticks [ingredient] onto Groceries, or takes it off again (#497).
  void toggleIngredientOnGroceries(String ingredient) {
    if (childBlocked(kChildMealPlanReadOnly)) return;
    final line = groceryLineFor(groceriesListOf(shoppingLists), ingredient);
    mutate(() {
      final list = _ensureGroceries();
      if (line != null) {
        list.items.remove(line);
      } else {
        _putOnGroceries(list, ingredient);
      }
    });
  }

  /// "Add N missing to Groceries" (#497): every ingredient not on the list
  /// yet is added once. Returns how many were added.
  int addMissingToGroceries(List<String> ingredients) {
    if (childBlocked(kChildMealPlanReadOnly)) return 0;
    final missing = cleanIngredients(
      missingGroceries(groceriesListOf(shoppingLists), ingredients),
    );
    if (missing.isEmpty) {
      flash('Already on Groceries');
      return 0;
    }
    mutate(() {
      final list = _ensureGroceries();
      for (final i in missing) {
        _putOnGroceries(list, i);
      }
    }, () => flash('Added ${missing.length} to Groceries'));
    return missing.length;
  }

  void shiftWeek(int delta) => update(() {
    weekOffset += delta;
    final sel = DateTime.tryParse(mealDaySel ?? '');
    if (sel != null) mealDaySel = _isoDate(_addDays(sel, 7 * delta));
  });

  void selectMealDay(String dateIso) => update(() => mealDaySel = dateIso);
}
