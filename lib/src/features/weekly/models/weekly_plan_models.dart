part of 'package:family_money_management_app/main.dart';

/// One day's meal plan (breakfast/lunch/dinner) and shared note in the
/// weekly plan. Keyed by its ISO `YYYY-MM-DD` date in [Workspace.weeklyPlan].
class DayPlan {
  DayPlan({
    required this.dateIso,
    this.breakfast,
    this.lunch,
    this.dinner,
    this.note,
  });

  String dateIso;
  String? breakfast;
  String? lunch;
  String? dinner;
  String? note;

  /// Whether this day has no meals and no note — safe to drop from the map.
  bool get isEmpty =>
      (breakfast?.isEmpty ?? true) &&
      (lunch?.isEmpty ?? true) &&
      (dinner?.isEmpty ?? true) &&
      (note?.isEmpty ?? true);

  DayPlan copy() => DayPlan(
    dateIso: dateIso,
    breakfast: breakfast,
    lunch: lunch,
    dinner: dinner,
    note: note,
  );

  Map<String, dynamic> toJson() => {
    'dateIso': dateIso,
    if (breakfast != null) 'breakfast': breakfast,
    if (lunch != null) 'lunch': lunch,
    if (dinner != null) 'dinner': dinner,
    if (note != null) 'note': note,
  };

  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
    dateIso: (j['dateIso'] ?? '').toString(),
    breakfast: (j['breakfast']?.toString().isNotEmpty ?? false)
        ? j['breakfast'].toString()
        : null,
    lunch: (j['lunch']?.toString().isNotEmpty ?? false)
        ? j['lunch'].toString()
        : null,
    dinner: (j['dinner']?.toString().isNotEmpty ?? false)
        ? j['dinner'].toString()
        : null,
    note: (j['note']?.toString().isNotEmpty ?? false)
        ? j['note'].toString()
        : null,
  );
}
