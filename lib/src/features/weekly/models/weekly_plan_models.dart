part of 'package:family_money_management_app/main.dart';

/// One day's meal plan (breakfast/lunch/dinner) and shared note in the
/// weekly plan. Keyed by its ISO `YYYY-MM-DD` date in [Workspace.weeklyPlan].
///
/// The dinner carries its own [ingredients] (order kept, epic #500) and an
/// optional time to make. Both are only serialized when set, so a day saved
/// before they existed round-trips to exactly the same record.
class DayPlan {
  DayPlan({
    required this.dateIso,
    this.breakfast,
    this.lunch,
    this.dinner,
    this.note,
    List<String>? ingredients,
    this.dinnerMinutes,
  }) : ingredients = ingredients ?? <String>[];

  String dateIso;
  String? breakfast;
  String? lunch;
  String? dinner;
  String? note;

  /// The dinner's ingredients, in the order they were added.
  List<String> ingredients;

  /// Minutes the dinner takes to make, when known.
  int? dinnerMinutes;

  /// Whether this day has no meals, ingredients and note — safe to drop
  /// from the map.
  bool get isEmpty =>
      (breakfast?.isEmpty ?? true) &&
      (lunch?.isEmpty ?? true) &&
      (dinner?.isEmpty ?? true) &&
      (note?.isEmpty ?? true) &&
      ingredients.isEmpty;

  DayPlan copy() => DayPlan(
    dateIso: dateIso,
    breakfast: breakfast,
    lunch: lunch,
    dinner: dinner,
    note: note,
    ingredients: [...ingredients],
    dinnerMinutes: dinnerMinutes,
  );

  Map<String, dynamic> toJson() => {
    'dateIso': dateIso,
    if (breakfast != null) 'breakfast': breakfast,
    if (lunch != null) 'lunch': lunch,
    if (dinner != null) 'dinner': dinner,
    if (note != null) 'note': note,
    if (ingredients.isNotEmpty) 'ingredients': [...ingredients],
    if (dinnerMinutes != null) 'dinnerMinutes': dinnerMinutes,
  };

  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
    dateIso: (j['dateIso'] ?? '').toString(),
    breakfast: _nonEmpty(j['breakfast']),
    lunch: _nonEmpty(j['lunch']),
    dinner: _nonEmpty(j['dinner']),
    note: _nonEmpty(j['note']),
    ingredients: cleanIngredients(j['ingredients']),
    dinnerMinutes: _positiveMinutes(j['dinnerMinutes']),
  );
}

/// A dish in the family's saved-meal library (favourites, #495): its name
/// and ingredients, shared with every family member.
class SavedMeal {
  SavedMeal({
    required this.id,
    required this.name,
    List<String>? ingredients,
    this.minutes,
  }) : ingredients = ingredients ?? <String>[];

  String id;
  String name;
  List<String> ingredients;
  int? minutes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (ingredients.isNotEmpty) 'ingredients': [...ingredients],
    if (minutes != null) 'minutes': minutes,
  };

  factory SavedMeal.fromJson(Map<String, dynamic> j) => SavedMeal(
    id: (j['id'] ?? uid()).toString(),
    name: (j['name'] ?? '').toString().trim(),
    ingredients: cleanIngredients(j['ingredients']),
    minutes: _positiveMinutes(j['minutes']),
  );
}

/// [draft] as it is saved on [dateIso]: fields trimmed (blank → unset),
/// ingredients de-duplicated, and no ingredients or time without a dinner.
DayPlan cleanDayPlan(String dateIso, DayPlan draft) {
  String? clean(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  final dinner = clean(draft.dinner);
  return DayPlan(
    dateIso: dateIso,
    breakfast: clean(draft.breakfast),
    lunch: clean(draft.lunch),
    dinner: dinner,
    note: clean(draft.note),
    ingredients: dinner == null ? [] : cleanIngredients(draft.ingredients),
    dinnerMinutes: dinner == null ? null : draft.dinnerMinutes,
  );
}

String? _nonEmpty(Object? v) {
  final s = v?.toString();
  return (s?.isNotEmpty ?? false) ? s : null;
}

int? _positiveMinutes(Object? v) {
  final n = v is num ? v.toInt() : int.tryParse('${v ?? ''}');
  return n != null && n > 0 ? n : null;
}

/// Case-insensitive key used to match dish and ingredient names.
String mealKey(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Trimmed, non-empty ingredient names from [raw], first occurrence of each
/// (case-insensitive) kept, in order.
List<String> cleanIngredients(Object? raw) {
  final out = <String>[];
  final seen = <String>{};
  for (final x in raw is List ? raw : const []) {
    final s = '${x ?? ''}'.trim();
    if (s.isNotEmpty && seen.add(mealKey(s))) out.add(s);
  }
  return out;
}

/// The library entry named [name] (case-insensitive), if any.
SavedMeal? savedMealNamed(List<SavedMeal> library, String? name) {
  final k = mealKey(name ?? '');
  if (k.isEmpty) return null;
  for (final m in library) {
    if (mealKey(m.name) == k) return m;
  }
  return null;
}

/// One favourites search hit: the meal and, when it matched on an
/// ingredient rather than its name, that ingredient.
typedef SavedMealHit = ({SavedMeal meal, String? ingredient});

/// Favourites matching [query] on dish name or any ingredient
/// (case-insensitive substring), library order kept. A blank query returns
/// nothing — the list only appears once the user types.
List<SavedMealHit> searchSavedMeals(List<SavedMeal> library, String query) {
  final q = mealKey(query);
  if (q.isEmpty) return const [];
  return [
    for (final m in library)
      if (mealKey(m.name).contains(q))
        (meal: m, ingredient: null)
      else if (m.ingredients.any((i) => mealKey(i).contains(q)))
        (
          meal: m,
          ingredient: m.ingredients.firstWhere((i) => mealKey(i).contains(q)),
        ),
  ];
}

// --------------------------------------------------------------- groceries

/// The shopping list meal ingredients go to: the one called "Groceries"
/// (case-insensitive), else the first shopping list. Null when the family has
/// no shopping list yet.
ShoppingList? groceriesListOf(List<ShoppingList> lists) {
  for (final l in lists) {
    if (mealKey(l.name) == 'groceries') return l;
  }
  return lists.isEmpty ? null : lists.first;
}

/// The still-to-buy line on [list] for [ingredient] (case-insensitive name
/// match), if any. Crossed-off lines don't count — they were bought already.
ShopItem? groceryLineFor(ShoppingList? list, String ingredient) {
  final k = mealKey(ingredient);
  for (final it in list?.items ?? const <ShopItem>[]) {
    if (!it.checked && mealKey(it.name) == k) return it;
  }
  return null;
}

/// The [ingredients] not yet on [list].
List<String> missingGroceries(ShoppingList? list, List<String> ingredients) => [
  for (final i in ingredients)
    if (groceryLineFor(list, i) == null) i,
];
