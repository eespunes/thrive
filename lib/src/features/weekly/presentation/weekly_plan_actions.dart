part of 'package:family_money_management_app/main.dart';

/// Mutations for the weekly meal plan (#157). Meals/notes live on the
/// active family's [Workspace] (`weeklyPlan`), keyed by ISO date, so these
/// ride the same `mutate()` → persist → cloud-sync pipeline as Lists.
extension _ThriveWeeklyPlanActions on _ThriveHomeState {
  DayPlan? dayPlan(String dateIso) => weeklyPlan[dateIso];

  void setMeal(String dateIso, String slot, String value) {
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
          break;
      }
      if (day.isEmpty) weeklyPlan.remove(dateIso);
    });
  }

  void clearMeal(String dateIso, String slot) => setMeal(dateIso, slot, '');

  void setNote(String dateIso, String value) {
    mutate(() {
      final trimmed = value.trim();
      final day = weeklyPlan.putIfAbsent(
        dateIso,
        () => DayPlan(dateIso: dateIso),
      );
      day.note = trimmed.isEmpty ? null : trimmed;
      if (day.isEmpty) weeklyPlan.remove(dateIso);
    });
  }

  void shiftWeek(int delta) => update(() => weekOffset += delta);
}
