part of 'package:family_money_management_app/main.dart';

/// Quantity spelled into an add-line ("5x milk", "milk x5", "5 milk"),
/// capped at 99 (#304). Returns the cleaned name and quantity.
(String, int) parseQtyLine(String raw) {
  var qty = 1;
  var name = raw;
  var m =
      RegExp(r'^(\d+)\s*[x×]?\s+(.+)$', caseSensitive: false).firstMatch(raw) ??
      RegExp(r'^(\d+)[x×]\s*(.+)$', caseSensitive: false).firstMatch(raw);
  if (m != null) {
    qty = int.tryParse(m.group(1)!) ?? 1;
    name = m.group(2)!;
  } else {
    m = RegExp(r'^(.+?)\s*[x×]\s*(\d+)$', caseSensitive: false).firstMatch(raw);
    if (m != null) {
      name = m.group(1)!;
      qty = int.tryParse(m.group(2)!) ?? 1;
    }
  }
  name = name.trim();
  if (name.isNotEmpty) {
    name = name[0].toUpperCase() + name.substring(1);
  }
  return (name, qty.clamp(1, 99));
}

String _listIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The coming Sunday — what the "This week" due chip means, and the default
/// due for a task added straight on a note (#304).
String endOfWeekIso() {
  final now = DateTime.now();
  return _listIso(now.add(Duration(days: 7 - now.weekday)));
}

/// Days from today to [iso]; negative = overdue.
int dueDiffDays(String iso) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime.tryParse(iso) ?? today;
  return DateTime(d.year, d.month, d.day).difference(today).inDays;
}

/// The note's small due caption: Today / Tomorrow / weekday, "Yesterday" or
/// "Overdue" once passed, "Someday" when there's no date (#303).
String dueLabel(String? iso) {
  if (iso == null) return 'Someday';
  final diff = dueDiffDays(iso);
  if (diff == -1) return 'Yesterday';
  if (diff < 0) return 'Overdue';
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff <= 6) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(DateTime.tryParse(iso) ?? DateTime.now()).weekday - 1];
  }
  return 'Next week';
}

/// Mutations for the fridge-door Lists module (epic #302–#319). All list
/// state lives on the active family's [Workspace] (`taskLists` /
/// `shoppingLists`), so these ride the same `mutate()` → persist →
/// (optional) cloud-sync pipeline as the budget mutations. The wall's view
/// state (sort, folded notes) is per-member and lives in SharedPreferences
/// instead (#317/#318).
extension _ThriveListActions on _ThriveHomeState {
  /// The wall has no detail screens any more; "opening" a list from a home
  /// widget or deep link just makes sure its note is unfolded, and marks it
  /// so the wall attaches the shared quick-add focus node to it.
  void openTaskListDetail(String id) => update(() {
    foldedNotes.remove(id);
    openTaskList = null;
    openShopList = null;
    swipedId = null;
  });

  void openShopListDetail(String id) => update(() {
    foldedNotes.remove(id);
    openTaskList = null;
    openShopList = id;
    swipedId = null;
  });

  void setTaskFilter(String v) => update(() => taskFilter = v);

  // ------------------------------------------------- per-member wall prefs
  String get _listPrefsKey => 'thrive.lists.view.$myId';

  /// Lazily loads this member's sort + folded-notes preferences. Called from
  /// the wall's build; re-runs when the signed-in member changes.
  void ensureListPrefs() {
    if (_listPrefsLoadedFor == myId) return;
    _listPrefsLoadedFor = myId;
    unawaited(() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_listPrefsKey);
      if (raw == null || !mounted) return;
      try {
        final j = json.decode(raw) as Map<String, dynamic>;
        update(() {
          final s = (j['sort'] ?? 'list').toString();
          listSort = const ['list', 'due', 'who'].contains(s) ? s : 'list';
          foldedNotes
            ..clear()
            ..addAll([for (final id in (j['folded'] as List? ?? [])) '$id']);
        });
      } catch (_) {
        // A corrupt blob just means default view state.
      }
    }());
  }

  void _saveListPrefs() {
    unawaited(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _listPrefsKey,
        json.encode({'sort': listSort, 'folded': foldedNotes.toList()}),
      );
    }());
  }

  void setListSort(String v) {
    update(() => listSort = v);
    _saveListPrefs();
  }

  void toggleNoteFolded(String listId) {
    update(() {
      if (!foldedNotes.remove(listId)) foldedNotes.add(listId);
    });
    _saveListPrefs();
  }

  // ------------------------------------------------------------- to-do
  void openNewListSheet([String kind = 'todo']) {
    _showSheet((ctx) => _NoteSheet(state: this, initialKind: kind));
  }

  void openEditNoteSheet({TaskList? taskList, ShoppingList? shopList}) {
    _showSheet(
      (ctx) => _NoteSheet(state: this, taskList: taskList, shopList: shopList),
    );
  }

  void openTaskSheet(ListTask? task, String listId) {
    _showSheet(
      (ctx) => _LineEditSheet(state: this, task: task, listId: listId),
    );
  }

  void openShopItemSheet(ShopItem item, String listId) {
    _showSheet(
      (ctx) => _LineEditSheet(state: this, shopItem: item, listId: listId),
    );
  }

  void openAssignSheet(String listId, String taskId) {
    _showSheet(
      (ctx) => _AssignSheet(state: this, listId: listId, taskId: taskId),
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
    }, () => flash('Pinned — the whole family sees it'));
  }

  void renameTaskList(String listId, String name, Color color) {
    mutate(() {
      final l = openListById(listId);
      if (l == null) return;
      l.name = name.trim().isEmpty ? l.name : name.trim();
      l.color = color;
    }, () => flash('Note updated'));
  }

  void saveTask({
    required String listId,
    String? id,
    required String title,
    String? assignee,
    String? due,
  }) {
    final wasEditing = id != null;
    mutate(() {
      final l = openListById(listId);
      if (l == null) return;
      if (id != null) {
        for (final t in l.tasks) {
          if (t.id == id) {
            t.title = title.trim().isEmpty ? 'Untitled' : title.trim();
            t.assignee = assignee;
            t.due = due;
            break;
          }
        }
      } else {
        l.tasks.add(
          ListTask(
            id: uid(),
            title: title.trim().isEmpty ? 'Untitled' : title.trim(),
            assignee: assignee,
            due: due,
            createdBy: myId,
          ),
        );
      }
    }, () => flash(wasEditing ? 'Saved' : 'Task added'));
  }

  /// A line written straight onto the note: unassigned ("Anyone"), due "This
  /// week" (#304).
  void addTaskLine(String listId, String title) {
    final t = title.trim();
    if (t.isEmpty) return;
    mutate(() {
      final l = openListById(listId);
      l?.tasks.add(
        ListTask(id: uid(), title: t, due: endOfWeekIso(), createdBy: myId),
      );
    });
  }

  /// Ticking an unassigned task claims it for the ticker (#303/#316).
  void toggleTask(String listId, String taskId) {
    var claimed = false;
    mutate(
      () {
        final l = openListById(listId);
        if (l == null) return;
        for (final t in l.tasks) {
          if (t.id == taskId) {
            t.done = !t.done;
            t.completedBy = t.done ? myId : null;
            if (t.done && t.assignee == null) {
              t.assignee = myId;
              claimed = true;
            }
            break;
          }
        }
      },
      () {
        if (claimed) flash('Ticked & claimed — nice one');
      },
    );
  }

  /// "Who's on it?" pick (#316). [memberId] null hands the task back to
  /// Anyone.
  void assignTask(String listId, String taskId, String? memberId) {
    String? prev;
    mutate(
      () {
        final l = openListById(listId);
        if (l == null) return;
        for (final t in l.tasks) {
          if (t.id == taskId) {
            prev = t.assignee;
            t.assignee = memberId;
            break;
          }
        }
      },
      () {
        if (memberId == null) {
          flash('Up for grabs — first to tick it claims it');
        } else if (memberId != prev) {
          final m = _memberById(memberId);
          // There's no cross-device push channel yet, so the nudge is the
          // synced avatar change; the copy still sets the expectation.
          flash('Handed to ${m?.name ?? 'them'} — they’ll get a nudge');
        }
      },
    );
  }

  /// "Cross it off the note": no confirm dialog, a 4-second Undo restores
  /// the line at its original index with all fields intact (#315).
  void crossOffTask(String listId, String taskId) {
    final l = openListById(listId);
    if (l == null) return;
    final idx = l.tasks.indexWhere((t) => t.id == taskId);
    if (idx < 0) return;
    final removed = l.tasks[idx];
    mutate(() => l.tasks.removeAt(idx));
    flashUndo('“${removed.title}” crossed off', () {
      mutate(() {
        final again = openListById(listId);
        again?.tasks.insert(math.min(idx, again.tasks.length), removed);
      });
    });
  }

  void deleteTaskList(String listId) {
    mutate(() {
      taskLists.removeWhere((l) => l.id == listId);
    }, () => flash('Note unpinned'));
    update(() => openTaskList = null);
  }

  TaskList? openListById(String id) {
    for (final l in taskLists) {
      if (l.id == id) return l;
    }
    return null;
  }

  // ----------------------------------------------------------- shopping
  void saveShopList(
    String name, {
    Color? color,
    String? emoji,
    String? picture,
  }) {
    mutate(() {
      shoppingLists.add(
        ShoppingList(
          id: uid(),
          name: name.trim().isEmpty ? 'New list' : name.trim(),
          color: color,
          emoji: emoji,
          picture: picture,
        ),
      );
    }, () => flash('Pinned — the whole family sees it'));
  }

  void renameShopList(String listId, String name, Color? color) {
    mutate(() {
      final l = shopListById(listId);
      if (l == null) return;
      l.name = name.trim().isEmpty ? l.name : name.trim();
      l.color = color;
    }, () => flash('Note updated'));
  }

  /// Parses "5x milk" / "milk x5" / "5 milk"; an existing open item with the
  /// same name (case-insensitive) gets its count bumped instead of a
  /// duplicate line (#304).
  void addShopItem(String listId, String name) {
    final raw = name.trim();
    if (raw.isEmpty) return;
    final (nm, qty) = parseQtyLine(raw);
    if (nm.isEmpty) return;
    mutate(() {
      final l = shopListById(listId);
      if (l == null) return;
      for (final it in l.items) {
        if (!it.checked && it.name.toLowerCase() == nm.toLowerCase()) {
          it.qty = math.min(99, it.qty + qty);
          return;
        }
      }
      l.items.insert(0, ShopItem(id: uid(), name: nm, qty: qty, addedBy: myId));
    });
  }

  void renameShopItem(String listId, String itemId, String name) {
    mutate(() {
      final l = shopListById(listId);
      if (l == null) return;
      for (final it in l.items) {
        if (it.id == itemId) {
          it.name = name.trim().isEmpty ? it.name : name.trim();
          break;
        }
      }
    }, () => flash('Saved'));
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

  /// The − ×N ＋ stepper (#319): 1–99; − at ×1 crosses the line off with the
  /// same Undo toast as the edit sheet's cross-off.
  void shopQty(String listId, String itemId, int delta) {
    final l = shopListById(listId);
    if (l == null) return;
    final idx = l.items.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;
    final it = l.items[idx];
    if (delta < 0 && it.qty <= 1) {
      crossOffShopItem(listId, itemId);
      return;
    }
    mutate(() => it.qty = (it.qty + delta).clamp(1, 99));
  }

  void crossOffShopItem(String listId, String itemId) {
    final l = shopListById(listId);
    if (l == null) return;
    final idx = l.items.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;
    final removed = l.items[idx];
    mutate(() => l.items.removeAt(idx));
    flashUndo('“${removed.name}” crossed off', () {
      mutate(() {
        final again = shopListById(listId);
        again?.items.insert(math.min(idx, again.items.length), removed);
      });
    });
  }

  void deleteShopList(String listId) {
    mutate(() {
      shoppingLists.removeWhere((l) => l.id == listId);
    }, () => flash('Note unpinned'));
    update(() => openShopList = null);
  }

  ShoppingList? shopListById(String id) {
    for (final l in shoppingLists) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Unpin confirm: counts what goes with the note (#306).
  void askUnpinNote({TaskList? taskList, ShoppingList? shopList}) {
    final name = taskList?.name ?? shopList?.name ?? '';
    final n = taskList?.tasks.length ?? shopList?.items.length ?? 0;
    askDelete(
      name,
      'It takes its $n line${n == 1 ? '' : 's'} with it — and it comes off '
      'the door for the whole family.',
      () => taskList != null
          ? deleteTaskList(taskList.id)
          : deleteShopList(shopList!.id),
      confirmLabel: 'Unpin',
    );
  }
}
