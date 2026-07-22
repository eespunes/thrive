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
  });

  String id;
  String title;
  bool done;

  /// Family member id this task is assigned to, or `null` for unassigned.
  String? assignee;

  /// ISO `YYYY-MM-DD` due date, or `null` for no due date.
  String? due;
  String? createdBy;

  /// Family member id who checked the task off, cleared when un-checked.
  String? completedBy;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'done': done,
    if (assignee != null) 'assignee': assignee,
    if (due != null) 'due': due,
    if (createdBy != null) 'createdBy': createdBy,
    if (completedBy != null) 'completedBy': completedBy,
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
  );
}

/// A shared to-do list — the `TO-DO` list type in the unified Lists module.
class TaskList {
  TaskList({
    required this.id,
    required this.name,
    required this.color,
    List<ListTask>? tasks,
  }) : tasks = tasks ?? <ListTask>[];

  String id;
  String name;
  Color color;
  List<ListTask> tasks;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.toARGB32(),
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };

  factory TaskList.fromJson(Map<String, dynamic> j) => TaskList(
    id: (j['id'] ?? uid()).toString(),
    name: (j['name'] ?? 'New list').toString(),
    color: Color((j['color'] as num?)?.toInt() ?? 0xff0E9A8D),
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
  ShoppingList({required this.id, required this.name, List<ShopItem>? items})
    : items = items ?? <ShopItem>[];

  String id;
  String name;
  List<ShopItem> items;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory ShoppingList.fromJson(Map<String, dynamic> j) => ShoppingList(
    id: (j['id'] ?? uid()).toString(),
    name: (j['name'] ?? 'New list').toString(),
    items: [
      for (final i in (j['items'] as List? ?? []))
        ShopItem.fromJson(Map<String, dynamic>.from(i as Map)),
    ],
  );
}
