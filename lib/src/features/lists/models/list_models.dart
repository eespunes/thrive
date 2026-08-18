part of 'package:family_money_management_app/main.dart';

/// A to-do task inside a [TaskList]. Mirrors the design's task shape.
class ListTask {
  ListTask({
    required this.id,
    required this.title,
    this.done = false,
    this.assignee,
    this.due,
    this.createdBy,
    this.completedBy,
    this.recur = 'none',
    this.recurEvery = 1,
    this.recurUnit = 'week',
    List<int>? recurWeekdays,
    List<String>? exceptions,
    Map<String, bool>? doneDates,
  }) : recurWeekdays = recurWeekdays ?? <int>[],
       exceptions = exceptions ?? <String>[],
       doneDates = doneDates ?? <String, bool>{};

  String id;
  String title;

  /// Completion state for a non-recurring task. For a recurring task
  /// (`recur != 'none'`), completion is tracked per-occurrence in
  /// [doneDates] instead — this field is ignored in that case.
  bool done;

  /// Family member id this task is assigned to, or `null` for unassigned.
  String? assignee;

  /// ISO `YYYY-MM-DD` due date, or `null` for no due date. For recurring
  /// tasks this is the first occurrence date.
  String? due;
  String? createdBy;

  /// Family member id who checked the task off, cleared when un-checked.
  String? completedBy;

  /// Recurrence, mirroring [CalendarEvent]: `none|daily|weekly|monthly|yearly|custom`.
  String recur;
  int recurEvery;

  /// `day|week|month|year`, only meaningful when [recur] is `custom`.
  String recurUnit;

  /// ISO weekdays (1=Mon..7=Sun), only meaningful for weekly/custom-weekly.
  List<int> recurWeekdays;

  /// ISO dates removed from a recurring series (per-occurrence delete).
  List<String> exceptions;

  /// ISO date -> completed, for occurrence completion of a recurring task.
  Map<String, bool> doneDates;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'done': done,
    if (assignee != null) 'assignee': assignee,
    if (due != null) 'due': due,
    if (createdBy != null) 'createdBy': createdBy,
    if (completedBy != null) 'completedBy': completedBy,
    if (recur != 'none') 'recur': recur,
    if (recur != 'none') 'recurEvery': recurEvery,
    if (recur != 'none') 'recurUnit': recurUnit,
    if (recurWeekdays.isNotEmpty) 'recurWeekdays': recurWeekdays,
    if (exceptions.isNotEmpty) 'exceptions': exceptions,
    if (doneDates.isNotEmpty) 'doneDates': doneDates,
  };

  factory ListTask.fromJson(Map<String, dynamic> j) => ListTask(
    id: (j['id'] ?? uid()).toString(),
    title: (j['title'] ?? '').toString(),
    done: j['done'] == true,
    assignee: j['assignee']?.toString(),
    due: (j['due']?.toString().isNotEmpty ?? false)
        ? j['due'].toString()
        : null,
    createdBy: j['createdBy']?.toString(),
    completedBy: j['completedBy']?.toString(),
    recur: (j['recur'] as String?)?.isNotEmpty == true ? j['recur'] : 'none',
    recurEvery: ((j['recurEvery'] as num?)?.toInt() ?? 1).clamp(1, 999),
    recurUnit: (j['recurUnit'] as String?)?.isNotEmpty == true
        ? j['recurUnit']
        : 'week',
    recurWeekdays: [
      for (final w in (j['recurWeekdays'] as List? ?? [])) (w as num).toInt(),
    ],
    exceptions: [
      for (final e in (j['exceptions'] as List? ?? [])) e.toString(),
    ],
    doneDates: {
      for (final entry in (j['doneDates'] as Map? ?? {}).entries)
        entry.key.toString(): entry.value == true,
    },
  );

  /// Whether the occurrence on [iso] is completed. Falls back to [done] for
  /// non-recurring tasks so old data with only a `done` flag keeps working.
  bool isDoneOn(String iso) =>
      recur == 'none' ? done : (doneDates[iso] ?? false);
}

/// A shared to-do list — the `TO-DO` list type in the unified Lists module.
class TaskList {
  TaskList({
    required this.id,
    required this.name,
    required this.color,
    this.emoji,
    this.picture,
    this.kind = 'chore',
    List<ListTask>? tasks,
  }) : tasks = tasks ?? <ListTask>[];

  String id;
  String name;
  Color color;

  /// Optional emoji shown instead of the default 'tasklist' icon.
  String? emoji;

  /// Optional base64 picture shown instead of the emoji/icon.
  String? picture;

  /// `chore` (household to-dos, the default) or `content` (content-creation
  /// schedule — filming/editing/posting). Both render as the calendar's
  /// task-style cards, distinguished only by which layer they belong to.
  String kind;

  List<ListTask> tasks;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.toARGB32(),
    if (emoji != null) 'emoji': emoji,
    if (picture != null) 'picture': picture,
    if (kind != 'chore') 'kind': kind,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };

  factory TaskList.fromJson(Map<String, dynamic> j) => TaskList(
    id: (j['id'] ?? uid()).toString(),
    name: (j['name'] ?? 'New list').toString(),
    color: Color((j['color'] as num?)?.toInt() ?? 0xff0E9A8D),
    emoji: (j['emoji'] as String?)?.isNotEmpty == true ? j['emoji'] : null,
    picture: (j['picture'] as String?)?.isNotEmpty == true
        ? j['picture']
        : null,
    kind: (j['kind'] as String?) == 'content' ? 'content' : 'chore',
    tasks: [
      for (final t in (j['tasks'] as List? ?? []))
        ListTask.fromJson(Map<String, dynamic>.from(t as Map)),
    ],
  );
}

/// An item inside a [ShoppingList]. Mirrors the design's shopping item shape.
class ShopItem {
  ShopItem({
    required this.id,
    required this.name,
    this.qty = 1,
    this.checked = false,
    this.addedBy,
  });

  String id;
  String name;
  int qty;
  bool checked;

  /// Family member id who added this item.
  String? addedBy;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'qty': qty,
    'checked': checked,
    if (addedBy != null) 'addedBy': addedBy,
  };

  factory ShopItem.fromJson(Map<String, dynamic> j) => ShopItem(
    id: (j['id'] ?? uid()).toString(),
    name: (j['name'] ?? '').toString(),
    qty: ((j['qty'] as num?)?.toInt() ?? 1).clamp(1, 9999),
    checked: j['checked'] == true,
    addedBy: j['addedBy']?.toString(),
  );
}

/// A shared shopping list — the `SHOPPING` list type in the unified Lists
/// module.
class ShoppingList {
  ShoppingList({
    required this.id,
    required this.name,
    this.emoji,
    this.picture,
    List<ShopItem>? items,
  }) : items = items ?? <ShopItem>[];

  String id;
  String name;

  /// Optional emoji shown instead of the default 'cart' icon.
  String? emoji;

  /// Optional base64 picture shown instead of the emoji/icon.
  String? picture;

  List<ShopItem> items;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (emoji != null) 'emoji': emoji,
    if (picture != null) 'picture': picture,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory ShoppingList.fromJson(Map<String, dynamic> j) => ShoppingList(
    id: (j['id'] ?? uid()).toString(),
    name: (j['name'] ?? 'New list').toString(),
    emoji: (j['emoji'] as String?)?.isNotEmpty == true ? j['emoji'] : null,
    picture: (j['picture'] as String?)?.isNotEmpty == true
        ? j['picture']
        : null,
    items: [
      for (final i in (j['items'] as List? ?? []))
        ShopItem.fromJson(Map<String, dynamic>.from(i as Map)),
    ],
  );
}
