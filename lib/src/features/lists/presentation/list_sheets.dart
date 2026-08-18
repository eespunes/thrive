part of 'package:family_money_management_app/main.dart';

const List<Color> _kListColors = [
  Color(0xff0E9A8D),
  Color(0xff1684B4),
  Color(0xff0f9d6a),
  Color(0xffd97706),
  Color(0xff7c3aed),
  Color(0xffe11d48),
];

/// "New list" sheet — choose to-do or shopping, name, colour (to-do only).
/// Ported from the design's `sheetNewList()`.
class _NewListSheet extends StatefulWidget {
  const _NewListSheet({required this.state, this.initialKind = 'todo'});
  final _ThriveHomeState state;
  final String initialKind;

  @override
  State<_NewListSheet> createState() => _NewListSheetState();
}

class _NewListSheetState extends State<_NewListSheet> {
  late String _kind;
  late final TextEditingController _name;
  Color _color = _kListColors.first;
  String? _emoji;
  String? _picture;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopping = _kind == 'shopping';
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
          _sheetHead(context, 'New list', 'To-do or shopping'),
          Row(
            children: [
              kindBtn('todo', 'tasklist', 'To-do'),
              const SizedBox(width: 10),
              kindBtn('shopping', 'cart', 'Shopping'),
            ],
          ),
          const SizedBox(height: 15),
          _sheetField(
            'List name',
            _sheetInput(
              _name,
              hint: shopping ? 'e.g. Supermarket' : 'e.g. Household',
              onChanged: (_) => setState(() {}),
            ),
          ),
          _sheetField(
            'Icon',
            _GlyphPicker(
              emoji: _emoji,
              picture: _picture,
              onChanged: ({String? emoji, String? picture}) => setState(() {
                _emoji = emoji;
                _picture = picture;
              }),
            ),
          ),
          if (!shopping)
            _sheetField(
              'Color',
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final c in _kListColors)
                    GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(11),
                          border: _color == c
                              ? Border.all(color: B.ink, width: 2)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          _primaryBtn('Create list', () {
            if (shopping) {
              widget.state.saveShopList(
                _name.text,
                emoji: _emoji,
                picture: _picture,
              );
            } else {
              widget.state.saveTaskList(
                _name.text,
                _color,
                emoji: _emoji,
                picture: _picture,
              );
            }
            Navigator.of(context).pop();
          }, enabled: valid),
        ],
      ),
    );
  }
}

/// "New task" / "Edit task" sheet — title, assignee, due date. Ported from
/// the design's `sheetTaskEdit()`.
class _TaskEditSheet extends StatefulWidget {
  const _TaskEditSheet({required this.state, required this.listId, this.task});
  final _ThriveHomeState state;
  final String listId;
  final ListTask? task;

  @override
  State<_TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<_TaskEditSheet> {
  late final TextEditingController _title;
  String? _assignee;
  bool _hasDue = false;
  String _due = todayIso();
  late String _recur;
  late int _recurEvery;
  late String _recurUnit;
  late List<int> _recurWeekdays;

  bool get _editing => widget.task != null;

  int _isoWeekday(String iso) =>
      (DateTime.tryParse(iso) ?? DateTime.now()).weekday;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _assignee = t?.assignee;
    _hasDue = (t?.due ?? '').isNotEmpty;
    _due = t?.due ?? todayIso();
    _recur = t?.recur ?? 'none';
    _recurEvery = t?.recurEvery ?? 1;
    _recurUnit = t?.recurUnit ?? 'week';
    _recurWeekdays = (t?.recurWeekdays ?? const <int>[]).toList();
    if (_recurWeekdays.isEmpty &&
        (_recur == 'weekly' || (_recur == 'custom' && _recurUnit == 'week'))) {
      _recurWeekdays = [_isoWeekday(_due)];
    }
  }

  bool get _showWeekdayPicker =>
      _recur == 'weekly' || (_recur == 'custom' && _recurUnit == 'week');

  Widget _recurChipRow(
    List<(String, String)> opts,
    String value,
    ValueChanged<String> onPick,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (k, label) in opts) ...[
            GestureDetector(
              key: ValueKey('task-recur-$k'),
              onTap: () => onPick(k),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: value == k ? B.soft : Colors.white,
                  border: Border.all(color: value == k ? B.primary : B.line),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: value == k ? B.deep : B.soft2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }

  Widget _recurNumberChipRow(
    List<int> opts,
    int value,
    ValueChanged<int> onPick,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in opts) ...[
            GestureDetector(
              key: ValueKey('task-recur-every-$option'),
              onTap: () => onPick(option),
              child: Container(
                width: 38,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == option ? B.soft : Colors.white,
                  border: Border.all(
                    color: value == option ? B.primary : B.line,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$option',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: value == option ? B.deep : B.soft2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }

  Widget _recurWeekdayPicker() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var weekday = 1; weekday <= 7; weekday++) ...[
            GestureDetector(
              key: ValueKey('task-recur-weekday-$weekday'),
              onTap: () => setState(() {
                if (_recurWeekdays.contains(weekday)) {
                  if (_recurWeekdays.length > 1) {
                    _recurWeekdays.remove(weekday);
                  }
                } else {
                  _recurWeekdays.add(weekday);
                  _recurWeekdays.sort();
                }
              }),
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _recurWeekdays.contains(weekday)
                      ? B.soft
                      : Colors.white,
                  border: Border.all(
                    color: _recurWeekdays.contains(weekday)
                        ? B.primary
                        : B.line,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  kWeekdayLetters[weekday - 1],
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _recurWeekdays.contains(weekday) ? B.deep : B.soft2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.state.curFamily()?.members ?? const <FamilyMember>[];
    final valid = _title.text.trim().isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(context, _editing ? 'Edit task' : 'New task'),
          _sheetField(
            'Task',
            _sheetInput(
              _title,
              hint: 'e.g. Take out the bins',
              onChanged: (_) => setState(() {}),
            ),
          ),
          _sheetField(
            'Assigned to',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in members)
                  GestureDetector(
                    onTap: () => setState(() => _assignee = m.id),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(5, 5, 11, 5),
                      decoration: BoxDecoration(
                        color: _assignee == m.id ? B.soft : Colors.white,
                        border: Border.all(
                          color: _assignee == m.id ? B.primary : B.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          widget.state.avatarNode(
                            photo: m.photo,
                            emoji: m.emoji,
                            initials: m.initials,
                            color: m.color,
                            size: 22,
                            radius: 11,
                            fs: 10,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _assignee == m.id ? B.deep : B.soft2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _toggleRow(
            'Due date',
            _hasDue,
            () => setState(() => _hasDue = !_hasDue),
            activeColor: B.primary,
          ),
          if (_hasDue) ...[
            const SizedBox(height: 13),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(_due) ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    _due =
                        '${picked.year.toString().padLeft(4, '0')}-'
                        '${picked.month.toString().padLeft(2, '0')}-'
                        '${picked.day.toString().padLeft(2, '0')}';
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: B.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    ic('cal', size: 15, sw: 2.2, color: B.primary),
                    const SizedBox(width: 8),
                    Text(
                      _due,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: B.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 13),
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              'REPEAT',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: B.muted,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: _recurChipRow(
              const [
                ('none', 'None'),
                ('daily', 'Daily'),
                ('weekly', 'Weekly'),
                ('monthly', 'Monthly'),
                ('yearly', 'Yearly'),
                ('custom', 'Custom'),
              ],
              _recur,
              (v) => setState(() {
                _recur = v;
                if (_showWeekdayPicker && _recurWeekdays.isEmpty) {
                  _recurWeekdays = [_isoWeekday(_due)];
                }
              }),
            ),
          ),
          if (_recur != 'none') ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                'EVERY',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .3,
                  color: B.muted,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: _recurNumberChipRow(
                const [1, 2, 3, 4, 5, 6],
                _recurEvery,
                (v) => setState(() => _recurEvery = v),
              ),
            ),
            if (_recur == 'custom') ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: _recurChipRow(
                  const [
                    ('day', 'Days'),
                    ('week', 'Weeks'),
                    ('month', 'Months'),
                    ('year', 'Years'),
                  ],
                  _recurUnit,
                  (v) => setState(() {
                    _recurUnit = v;
                    if (_showWeekdayPicker && _recurWeekdays.isEmpty) {
                      _recurWeekdays = [_isoWeekday(_due)];
                    }
                  }),
                ),
              ),
            ],
            if (_showWeekdayPicker) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  'ON DAYS',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                    color: B.muted,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: _recurWeekdayPicker(),
              ),
            ],
          ],
          _primaryBtn(_editing ? 'Save task' : 'Add task', () {
            widget.state.saveTask(
              listId: widget.listId,
              id: widget.task?.id,
              title: _title.text,
              assignee: _assignee,
              due: _hasDue ? _due : null,
              recur: _recur,
              recurEvery: _recurEvery,
              recurUnit: _recurUnit,
              recurWeekdays: _recurWeekdays,
            );
            Navigator.of(context).pop();
          }, enabled: valid),
          if (_editing)
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                widget.state.askDelete(
                  _title.text,
                  'This task will be removed.',
                  () => widget.state.deleteTask(widget.listId, widget.task!.id),
                );
              },
              child: const Padding(
                padding: EdgeInsets.fromLTRB(0, 13, 0, 2),
                child: Text(
                  'Delete task',
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
