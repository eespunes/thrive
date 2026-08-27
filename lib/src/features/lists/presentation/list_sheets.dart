part of 'package:family_money_management_app/main.dart';

/// Sticky-note paper: (paper, tape) pairs from the fridge-door design
/// (`Lists options.dc.html` option 7a).
const List<(Color, Color)> _kNotePapers = [
  (Color(0xfffff8c4), Color(0xffffd6a5)),
  (Color(0xffdcefff), Color(0xffb5d8f5)),
  (Color(0xffffe3d3), Color(0xfff5c6a5)),
  (Color(0xffe2f4e0), Color(0xffbcd9b8)),
  (Color(0xfffde2ec), Color(0xfff2b8cf)),
  (Color(0xffececec), Color(0xffd4d4d4)),
];

/// Stable paper for a list: its chosen `color` when it matches a paper,
/// otherwise a deterministic pick from its id — never random per build.
int _paperIndexFor(String id, Color? color) {
  if (color != null) {
    for (var i = 0; i < _kNotePapers.length; i++) {
      if (_kNotePapers[i].$1.toARGB32() == color.toARGB32()) return i;
    }
  }
  return id.hashCode.abs() % _kNotePapers.length;
}

const List<double> _kNoteRotations = [-1.2, 0.9, -0.5, 1.1];

double _rotationFor(String id) =>
    _kNoteRotations[id.hashCode.abs() % _kNoteRotations.length];

/// Pill chip shared by the sheets (due / assignee pickers).
Widget _listChip(
  String label,
  bool active,
  VoidCallback onTap, {
  Key? key,
  Widget? leading,
}) {
  return GestureDetector(
    key: key,
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: EdgeInsets.fromLTRB(leading != null ? 5 : 13, 5, 13, 5),
      decoration: BoxDecoration(
        color: active ? B.soft : Colors.white,
        border: Border.all(
          color: active ? B.primary : B.line,
          width: active ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 6)],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? B.deep : B.soft2,
            ),
          ),
        ],
      ),
    ),
  );
}

/// "Pin a new note" / "Edit note" sheet (#305/#306): name, kind (create
/// only), paper colour, and — when editing — the visible unpin action.
class _NoteSheet extends StatefulWidget {
  const _NoteSheet({
    required this.state,
    this.initialKind = 'todo',
    this.taskList,
    this.shopList,
  });
  final _ThriveHomeState state;
  final String initialKind;
  final TaskList? taskList;
  final ShoppingList? shopList;

  bool get editing => taskList != null || shopList != null;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late String _kind;
  late final TextEditingController _name;
  late int _paper;

  @override
  void initState() {
    super.initState();
    _kind = widget.shopList != null
        ? 'shopping'
        : widget.taskList != null
        ? 'todo'
        : widget.initialKind;
    _name = TextEditingController(
      text: widget.taskList?.name ?? widget.shopList?.name ?? '',
    );
    _paper = widget.taskList != null
        ? _paperIndexFor(widget.taskList!.id, widget.taskList!.color)
        : widget.shopList != null
        ? _paperIndexFor(widget.shopList!.id, widget.shopList!.color)
        : 0;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final s = widget.state;
    final paper = _kNotePapers[_paper].$1;
    if (widget.taskList != null) {
      s.renameTaskList(widget.taskList!.id, _name.text, paper);
    } else if (widget.shopList != null) {
      s.renameShopList(widget.shopList!.id, _name.text, paper);
    } else if (_kind == 'shopping') {
      s.saveShopList(_name.text, color: paper);
    } else {
      s.saveTaskList(_name.text, paper);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final valid = _name.text.trim().isNotEmpty;

    Widget kindBtn(String k, String icon, String label) {
      final active = _kind == k;
      final tint = k == 'shopping' ? const Color(0xffd97706) : B.primary;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _kind = k),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: active ? B.soft : Colors.white,
              border: Border.all(color: active ? B.primary : B.line),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: active ? tint : B.faint,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: ic(
                      icon,
                      size: 19,
                      sw: 2.1,
                      color: active ? Colors.white : B.soft2,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: active ? B.deep : B.soft2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(
            context,
            editing ? 'Edit “${_name.text.trim()}”' : 'Pin a new note',
            editing ? null : 'It goes up for the whole family',
          ),
          if (!editing) ...[
            Row(
              children: [
                kindBtn('todo', 'tasklist', 'To-dos'),
                const SizedBox(width: 10),
                kindBtn('shopping', 'cart', 'Shopping'),
              ],
            ),
            const SizedBox(height: 15),
          ],
          _sheetField(
            'Note title',
            _sheetInput(
              _name,
              hint: _kind == 'shopping' ? 'e.g. Supermarket' : 'e.g. Household',
              onChanged: (_) => setState(() {}),
            ),
          ),
          _sheetField(
            'Paper',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _kNotePapers.length; i++)
                  GestureDetector(
                    key: ValueKey('note-paper-$i'),
                    onTap: () => setState(() => _paper = i),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _kNotePapers[i].$1,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _paper == i
                              ? B.ink
                              : Colors.black.withValues(alpha: .08),
                          width: _paper == i ? 2.5 : 1,
                        ),
                      ),
                      child: _paper == i
                          ? Center(
                              child: ic('check', size: 14, sw: 3, color: B.ink),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          _primaryBtn(
            editing ? 'Save the note' : 'Pin it to the door',
            _save,
            enabled: valid,
          ),
          if (editing) ...[
            const SizedBox(height: 15),
            // Visible, never adjacent to save, replaces hidden swipe-delete.
            GestureDetector(
              key: const ValueKey('note-unpin'),
              onTap: () {
                Navigator.of(context).pop();
                widget.state.askUnpinNote(
                  taskList: widget.taskList,
                  shopList: widget.shopList,
                );
              },
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: B.redLine),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Text(
                  'Unpin this note…',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: B.red,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Line edit sheet (#315): tap a line's text to rename it, move its due,
/// hand it to someone (incl. Anyone), or cross it off — no confirm, a
/// 4-second Undo instead. Grocery lines get the same sheet minus due and
/// assignee. Also serves as the "New task" sheet for the quick-add flows.
class _LineEditSheet extends StatefulWidget {
  const _LineEditSheet({
    required this.state,
    required this.listId,
    this.task,
    this.shopItem,
  });
  final _ThriveHomeState state;
  final String listId;
  final ListTask? task;
  final ShopItem? shopItem;

  bool get isShop => shopItem != null;

  @override
  State<_LineEditSheet> createState() => _LineEditSheetState();
}

class _LineEditSheetState extends State<_LineEditSheet> {
  late final TextEditingController _title;
  String? _assignee;
  String? _due;

  bool get _editing => widget.task != null || widget.shopItem != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.task?.title ?? widget.shopItem?.name ?? '',
    );
    _assignee = widget.task?.assignee;
    _due = widget.task?.due ?? (_editing ? null : endOfWeekIso());
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.isShop) {
      widget.state.renameShopItem(
        widget.listId,
        widget.shopItem!.id,
        _title.text,
      );
    } else {
      widget.state.saveTask(
        listId: widget.listId,
        id: widget.task?.id,
        title: _title.text,
        assignee: _assignee,
        due: _due,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final members = s.curFamily()?.members ?? const <FamilyMember>[];
    final valid = _title.text.trim().isNotEmpty;
    final dueChips = <(String, String?)>[
      ('Today', todayIso()),
      ('Tomorrow', _listIso(DateTime.now().add(const Duration(days: 1)))),
      ('This week', endOfWeekIso()),
      ('Someday', null),
    ];

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(
            context,
            widget.isShop
                ? 'Edit item'
                : _editing
                ? 'Edit task'
                : 'New task',
          ),
          _sheetField(
            widget.isShop ? 'Item' : 'Task',
            _sheetInput(
              _title,
              hint: widget.isShop ? 'e.g. Milk' : 'e.g. Take out the bins',
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (!widget.isShop) ...[
            _sheetField(
              'Due',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, iso) in dueChips)
                    _listChip(
                      label,
                      _due == iso,
                      () => setState(() => _due = iso),
                      key: ValueKey('line-due-$label'),
                    ),
                ],
              ),
            ),
            _sheetField(
              'Who’s on it',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _listChip(
                    'Anyone',
                    _assignee == null,
                    () => setState(() => _assignee = null),
                    key: const ValueKey('line-who-anyone'),
                  ),
                  for (final m in members)
                    _listChip(
                      m.name,
                      _assignee == m.id,
                      () => setState(() => _assignee = m.id),
                      leading: s.avatarNode(
                        photo: m.photo,
                        emoji: m.emoji,
                        initials: m.initials,
                        color: m.color,
                        size: 22,
                        radius: 11,
                        fs: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 13),
          _primaryBtn(_editing ? 'Save' : 'Add task', _save, enabled: valid),
          if (_editing)
            GestureDetector(
              key: const ValueKey('line-crossoff'),
              onTap: () {
                Navigator.of(context).pop();
                if (widget.isShop) {
                  s.crossOffShopItem(widget.listId, widget.shopItem!.id);
                } else {
                  s.crossOffTask(widget.listId, widget.task!.id);
                }
              },
              child: const Padding(
                padding: EdgeInsets.fromLTRB(0, 13, 0, 2),
                child: Text(
                  'Cross it off the note',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: B.red,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Who's on it?" sheet (#316): member chips with live open-task loads
/// across all task notes (for fairness), plus "Anyone — first to grab it".
class _AssignSheet extends StatelessWidget {
  const _AssignSheet({
    required this.state,
    required this.listId,
    required this.taskId,
  });
  final _ThriveHomeState state;
  final String listId;
  final String taskId;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final task = s.openListById(listId)?.tasks.where((t) => t.id == taskId);
    final t = task != null && task.isNotEmpty ? task.first : null;
    final members = s.curFamily()?.members ?? const <FamilyMember>[];

    int loadOf(String memberId) {
      var n = 0;
      for (final l in s.taskLists) {
        n += l.tasks.where((x) => !x.done && x.assignee == memberId).length;
      }
      return n;
    }

    void pick(String? memberId) {
      Navigator.of(context).pop();
      s.assignTask(listId, taskId, memberId);
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetHead(context, 'Who’s on it?', t?.title),
          for (final m in members)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                key: ValueKey('assign-${m.id}'),
                onTap: () => pick(m.id),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: t?.assignee == m.id ? B.soft : Colors.white,
                    border: Border.all(
                      color: t?.assignee == m.id ? B.primary : B.line,
                      width: t?.assignee == m.id ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      s.avatarNode(
                        photo: m.photo,
                        emoji: m.emoji,
                        initials: m.initials,
                        color: m.color,
                        size: 30,
                        radius: 15,
                        fs: 11,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          m.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: B.ink,
                          ),
                        ),
                      ),
                      Text(
                        '${loadOf(m.id)} open',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: B.soft2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          GestureDetector(
            key: const ValueKey('assign-anyone'),
            onTap: () => pick(null),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t?.assignee == null ? B.soft : Colors.white,
                border: Border.all(
                  color: t?.assignee == null
                      ? B.primary
                      : const Color(0xffcfd8e3),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Anyone — first to grab it',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: t?.assignee == null ? B.deep : B.soft2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
