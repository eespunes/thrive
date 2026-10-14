part of 'package:family_money_management_app/main.dart';

/// Meal editor (#399): Breakfast / Lunch / Dinner segment, one big
/// underlined field and the family's recently planned meals as one-tap
/// chips. Switching the slot loads what that slot already holds.
class _MealEditSheet extends StatefulWidget {
  const _MealEditSheet({
    required this.state,
    required this.dateIso,
    required this.slot,
    required this.label,
    required this.initial,
  });

  final _ThriveHomeState state;
  final String dateIso;
  final String slot;
  final String label;
  final String initial;

  @override
  State<_MealEditSheet> createState() => _MealEditSheetState();
}

class _MealEditSheetState extends State<_MealEditSheet> {
  late final TextEditingController _ctrl;
  late String _slot = widget.slot;
  late String _had = widget.initial;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _valueOf(DayPlan? d, String slot) => switch (slot) {
    'breakfast' => d?.breakfast,
    'lunch' => d?.lunch,
    _ => d?.dinner,
  };

  void _switch(String slot) {
    if (slot == _slot) return;
    final v = _valueOf(widget.state.weeklyPlan[widget.dateIso], slot) ?? '';
    setState(() {
      _slot = slot;
      _had = v;
      _ctrl.text = v;
      _ctrl.selection = TextSelection.collapsed(offset: v.length);
    });
  }

  /// Distinct meals already on the plan, newest day first (max 6).
  List<String> _recent() {
    final days = widget.state.weeklyPlan.values.toList()
      ..sort((a, b) => b.dateIso.compareTo(a.dateIso));
    final out = <String>[];
    for (final d in days) {
      for (final m in [d.dinner, d.lunch, d.breakfast]) {
        final t = m?.trim() ?? '';
        if (t.isNotEmpty && !out.contains(t)) out.add(t);
        if (out.length == 6) return out;
      }
    }
    return out;
  }

  String _dateLine() {
    final d = DateTime.tryParse(widget.dateIso);
    if (d == null) return widget.dateIso;
    return '${_kWeekdaysShort[d.weekday - 1]} ${d.day} '
        '${kMonthsShortEn[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final slotLabel = switch (_slot) {
      'breakfast' => 'Breakfast',
      'lunch' => 'Lunch',
      _ => 'Dinner',
    };
    final text = _ctrl.text.trim();
    final clearing = text.isEmpty && _had.isNotEmpty;
    final recent = _recent();
    final s = widget.state;

    return EditorSheet(
      title: slotLabel,
      subtitle: _dateLine(),
      confirmKey: const ValueKey('meal-save'),
      confirmLabel: clearing
          ? 'Clear ${slotLabel.toLowerCase()}'
          : 'Save ${slotLabel.toLowerCase()}',
      destructiveConfirm: clearing,
      blockedReason: text.isEmpty && !clearing ? 'Type a meal first' : null,
      summary: text.isEmpty
          ? null
          : '$slotLabel on ${_dateLine()} · for the whole family',
      onConfirm: () {
        if (clearing) {
          s.clearMeal(widget.dateIso, _slot);
        } else {
          s.setMeal(widget.dateIso, _slot, text);
        }
        Navigator.of(context).pop();
      },
      children: [
        EdSegmented<String>(
          keyPrefix: 'meal-slot',
          options: const [
            ('breakfast', 'Breakfast'),
            ('lunch', 'Lunch'),
            ('dinner', 'Dinner'),
          ],
          value: _slot,
          onChanged: _switch,
        ),
        TextField(
          key: const ValueKey('meal-text'),
          controller: _ctrl,
          autofocus: widget.initial.isEmpty,
          onChanged: (_) => setState(() {}),
          cursorColor: context.tc.primary,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
            color: context.tc.ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
            hintText: 'e.g. Pasta with tomato sauce',
            hintStyle: TextStyle(color: context.tc.placeholder),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: text.isEmpty ? context.tc.line : context.tc.primary,
                width: 2,
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: text.isEmpty ? context.tc.line : context.tc.primary,
                width: 2,
              ),
            ),
          ),
        ),
        if (recent.isNotEmpty)
          EdSection(
            label: 'Recently planned',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in recent)
                  edSoftChip(
                    key: ValueKey('meal-recent-$m'),
                    label: m,
                    selected: text == m,
                    onTap: () => setState(() {
                      _ctrl.text = m;
                      _ctrl.selection = TextSelection.collapsed(
                        offset: m.length,
                      );
                    }),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Day note" sheet — a shared free-text note for one day.
class _DayNoteSheet extends StatefulWidget {
  const _DayNoteSheet({
    required this.state,
    required this.dateIso,
    required this.initial,
  });

  final _ThriveHomeState state;
  final String dateIso;
  final String initial;

  @override
  State<_DayNoteSheet> createState() => _DayNoteSheetState();
}

class _DayNoteSheetState extends State<_DayNoteSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(context, 'Note'),
          _sheetField(
            '',
            _sheetInput(
              _ctrl,
              hint: 'Anything the family should know…',
              onChanged: (_) => setState(() {}),
            ),
          ),
          _primaryBtn('Save', () {
            widget.state.setNote(widget.dateIso, _ctrl.text);
            Navigator.of(context).pop();
          }),
        ],
      ),
    );
  }
}
