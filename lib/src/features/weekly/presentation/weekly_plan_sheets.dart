part of 'package:family_money_management_app/main.dart';

/// "Edit meal" sheet — a single free-text field for one meal slot on one
/// day. Ported from the design's weekly-plan meal editor.
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
          _sheetHead(context, widget.label),
          _sheetField(
            '',
            _sheetInput(
              _ctrl,
              hint: 'e.g. Pasta with tomato sauce',
              onChanged: (_) => setState(() {}),
            ),
          ),
          _primaryBtn('Save', () {
            widget.state.setMeal(widget.dateIso, widget.slot, _ctrl.text);
            Navigator.of(context).pop();
          }),
          if (widget.initial.isNotEmpty)
            GestureDetector(
              onTap: () {
                widget.state.clearMeal(widget.dateIso, widget.slot);
                Navigator.of(context).pop();
              },
              child: const Padding(
                padding: EdgeInsets.fromLTRB(0, 13, 0, 2),
                child: Text(
                  'Clear',
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
