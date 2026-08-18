part of 'package:family_money_management_app/main.dart';

/// Mutations for the unified Lists module (#159/#155/#156), ported from the
/// design's task/shopping methods. All list state lives on the active
/// family's [Workspace] (`taskLists` / `shoppingLists`), so these ride the
/// same `mutate()` → persist → (optional) cloud-sync pipeline as the budget
/// mutations in `thrive_screens.dart`/`account_actions.dart`.
extension _ThriveListActions on _ThriveHomeState {
  TaskList? openList() {
    for (final l in taskLists) {
      if (l.id == openTaskList) return l;
    }
    return null;
  }

  ShoppingList? openShop() {
    for (final l in shoppingLists) {
      if (l.id == openShopList) return l;
    }
    return null;
  }

  void openTaskListDetail(String id) => update(() {
    openTaskList = id;
    swipedId = null;
  });

  void openShopListDetail(String id) => update(() {
    openShopList = id;
    swipedId = null;
  });

  /// Back to the "All lists" hub.
  void closeListDetail() => update(() {
    openTaskList = null;
    openShopList = null;
    swipedId = null;
  });

  void setTaskFilter(String v) => update(() => taskFilter = v);

  // ------------------------------------------------------------- to-do
  void openNewListSheet([String kind = 'todo']) {
    _showSheet((ctx) => _NewListSheet(state: this, initialKind: kind));
  }

  void openTaskSheet(ListTask? task, String listId) {
    _showSheet(
      (ctx) => _TaskEditSheet(state: this, task: task, listId: listId),
    );
  }

  void saveTaskList(
    String name,
    Color color, {
    String? emoji,
    String? picture,
  }) {
    mutate(() {
      taskLists.add(
        TaskList(
          id: uid(),
          name: name.trim().isEmpty ? 'New list' : name.trim(),
          color: color,
          emoji: emoji,
          picture: picture,
        ),
      );
    }, () => flash('List created'));
  }

  void saveTask({
    required String listId,
    String? id,
    required String title,
    String? assignee,
    String? due,
    String recur = 'none',
    int recurEvery = 1,
    String recurUnit = 'week',
    List<int>? recurWeekdays,
  }) {
    final wasEditing = id != null;
    final weekdays = recurWeekdays ?? const <int>[];
    ListTask? saved;
    mutate(() {
      final l = openListById(listId);
      if (l == null) return;
      if (id != null) {
        for (final t in l.tasks) {
          if (t.id == id) {
            t.title = title.trim().isEmpty ? 'Untitled' : title.trim();
            t.assignee = assignee;
            t.due = due;
            t.recur = recur;
            t.recurEvery = recurEvery;
            t.recurUnit = recurUnit;
            t.recurWeekdays = weekdays.toList();
            saved = t;
            break;
          }
        }
      } else {
        final t = ListTask(
          id: uid(),
          title: title.trim().isEmpty ? 'Untitled' : title.trim(),
          assignee: assignee,
          due: due,
          createdBy: myId,
          recur: recur,
          recurEvery: recurEvery,
          recurUnit: recurUnit,
          recurWeekdays: weekdays.toList(),
        );
        l.tasks.add(t);
        saved = t;
      }
    }, () => flash(wasEditing ? 'Task updated' : 'Task added'));
    if (saved != null) {
      if ((saved!.due ?? '').isNotEmpty) {
        NotificationService.instance.scheduleTaskReminder(saved!);
      } else {
        NotificationService.instance.cancelTaskReminder(saved!.id);
      }
    }
  }

  void toggleTask(String listId, String taskId) {
    ListTask? toggled;
    mutate(() {
      final l = openListById(listId);
      if (l == null) return;
      for (final t in l.tasks) {
        if (t.id == taskId) {
          t.done = !t.done;
          t.completedBy = t.done ? myId : null;
          toggled = t;
          break;
        }
      }
    });
    if (toggled == null) return;
    if (toggled!.done) {
      NotificationService.instance.cancelTaskReminder(taskId);
    } else if ((toggled!.due ?? '').isNotEmpty) {
      NotificationService.instance.scheduleTaskReminder(toggled!);
    }
  }

  void deleteTask(String listId, String taskId) {
    mutate(() {
      final l = openListById(listId);
      l?.tasks.removeWhere((t) => t.id == taskId);
    }, () => flash('Task deleted'));
    NotificationService.instance.cancelTaskReminder(taskId);
  }

  void deleteTaskList(String listId) {
    final removedIds = openListById(listId)?.tasks.map((t) => t.id).toList();
    mutate(() {
      taskLists.removeWhere((l) => l.id == listId);
    }, () => flash('List deleted'));
    update(() => openTaskList = null);
    for (final id in removedIds ?? const <String>[]) {
      NotificationService.instance.cancelTaskReminder(id);
    }
  }

  TaskList? openListById(String id) {
    for (final l in taskLists) {
      if (l.id == id) return l;
    }
    return null;
  }

  // ----------------------------------------------------------- shopping
  void saveShopList(String name, {String? emoji, String? picture}) {
    mutate(() {
      shoppingLists.add(
        ShoppingList(
          id: uid(),
          name: name.trim().isEmpty ? 'New list' : name.trim(),
          emoji: emoji,
          picture: picture,
        ),
      );
    }, () => flash('List created'));
  }

  void addShopItem(String listId, String name) {
    final nm = name.trim();
    if (nm.isEmpty) return;
    mutate(() {
      final l = shopListById(listId);
      l?.items.insert(0, ShopItem(id: uid(), name: nm, addedBy: myId));
    });
  }

  void toggleShop(String listId, String itemId) {
    mutate(() {
      final l = shopListById(listId);
      if (l == null) return;
      for (final it in l.items) {
        if (it.id == itemId) {
          it.checked = !it.checked;
          break;
        }
      }
    });
  }

  void shopQty(String listId, String itemId, int delta) {
    mutate(() {
      final l = shopListById(listId);
      if (l == null) return;
      for (final it in l.items) {
        if (it.id == itemId) {
          it.qty = math.max(1, it.qty + delta);
          break;
        }
      }
    });
  }

  void deleteShopItem(String listId, String itemId) {
    mutate(() {
      final l = shopListById(listId);
      l?.items.removeWhere((i) => i.id == itemId);
    });
  }

  void clearBoughtItems(String listId) {
    mutate(() {
      final l = shopListById(listId);
      l?.items.removeWhere((i) => i.checked);
    }, () => flash('Cleared bought items'));
  }

  void deleteShopList(String listId) {
    mutate(() {
      shoppingLists.removeWhere((l) => l.id == listId);
    }, () => flash('List deleted'));
    update(() => openShopList = null);
  }

  ShoppingList? shopListById(String id) {
    for (final l in shoppingLists) {
      if (l.id == id) return l;
    }
    return null;
  }
}
