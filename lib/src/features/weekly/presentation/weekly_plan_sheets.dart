part of 'package:family_money_management_app/main.dart';

/// The whole-day editor (#498, `Meal Plan.dc.html` 2a): dinner with its
/// favourite heart and library search (#499), ingredients, breakfast, lunch
/// and note. Everything is a draft until the header's Save; Cancel, back and
/// tapping outside ask before throwing edits away.
class _DayEditorSheet extends StatefulWidget {
  const _DayEditorSheet({
    required this.state,
    required this.dateIso,
    required this.initial,
  });

  final _ThriveHomeState state;
  final String dateIso;
  final DayPlan initial;

  @override
  State<_DayEditorSheet> createState() => _DayEditorSheetState();
}

class _DayEditorSheetState extends State<_DayEditorSheet> {
  late final _dinner = TextEditingController(text: widget.initial.dinner);
  late final _minutes = TextEditingController(
    text: widget.initial.dinnerMinutes?.toString() ?? '',
  );
  late final _breakfast = TextEditingController(text: widget.initial.breakfast);
  late final _lunch = TextEditingController(text: widget.initial.lunch);
  late final _note = TextEditingController(text: widget.initial.note);
  final _query = TextEditingController();
  final _newIng = TextEditingController();
  late List<String> _ings = [...widget.initial.ingredients];

  _ThriveHomeState get s => widget.state;

  @override
  void dispose() {
    for (final c in [
      _dinner,
      _minutes,
      _breakfast,
      _lunch,
      _note,
      _query,
      _newIng,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  DayPlan get _draft => DayPlan(
    dateIso: widget.dateIso,
    dinner: _dinner.text,
    breakfast: _breakfast.text,
    lunch: _lunch.text,
    note: _note.text,
    ingredients: _ings,
    dinnerMinutes: int.tryParse(_minutes.text.trim()),
  );

  bool get _dirty => !jsonEquals(
    cleanDayPlan(widget.dateIso, _draft).toJson(),
    cleanDayPlan(widget.dateIso, widget.initial).toJson(),
  );

  String get _title {
    final d = DateTime.tryParse(widget.dateIso);
    if (d == null) return widget.dateIso;
    return '${_kWeekdaysLong[d.weekday - 1]} ${d.day} '
        '${kMonthsShort[d.month - 1]}';
  }

  void _addIngredient() {
    final v = _newIng.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _ings = cleanIngredients([..._ings, v]);
      _newIng.clear();
    });
  }

  void _pick(SavedMeal m) => setState(() {
    _dinner.text = m.name;
    _ings = [...m.ingredients];
    _minutes.text = m.minutes?.toString() ?? '';
  });

  void _toggleFavourite() {
    final name = _dinner.text.trim();
    if (name.isEmpty) return;
    s.toggleFavouriteMeal(
      name,
      _ings,
      minutes: int.tryParse(_minutes.text.trim()),
    );
    setState(() {});
  }

  void _clearDay() => setState(() {
    for (final c in [_dinner, _minutes, _breakfast, _lunch, _note]) {
      c.clear();
    }
    _ings = [];
  });

  void _save() {
    s.saveDayPlan(widget.dateIso, _draft);
    Navigator.of(context).pop();
  }

  Future<void> _confirmDiscard() async {
    final nav = Navigator.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x610f172a),
      isScrollControlled: true,
      builder: (ctx) => _DiscardSheet(
        title: 'Discard changes?',
        body:
            'Your edits to ${_weekdayLong(widget.dateIso)} haven’t been '
            'saved.',
        primary: 'Discard changes',
        secondary: 'Keep editing',
        onConfirm: () {
          Navigator.of(ctx).pop();
          nav.pop();
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  TextStyle get _label => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: .4,
    color: context.tc.muted,
  );
  TextStyle get _hint => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: context.tc.placeholder,
  );
  TextStyle get _field => TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: context.tc.ink,
  );

  Widget _head(String label, [String? hint, Color? color]) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Expanded(
        child: Text(
          label,
          style: _label.copyWith(color: color ?? context.tc.muted),
        ),
      ),
      if (hint != null) Text(hint, style: _hint),
    ],
  );

  InputDecoration _plain(String hint, {TextStyle? style}) =>
      InputDecoration.collapsed(
        hintText: hint,
        hintStyle: (style ?? _field).copyWith(color: context.tc.placeholder),
      );

  BoxDecoration get _box => BoxDecoration(
    color: context.tc.faint,
    border: Border.all(color: context.tc.line),
    borderRadius: BorderRadius.circular(12),
  );

  @override
  Widget build(BuildContext context) {
    final dirty = _dirty;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: EditorSheet(
        title: _title,
        subtitle: 'Whole day · shared with family',
        headerConfirmLabel: 'Save',
        showFooter: false,
        onConfirm: _save,
        confirmKey: const ValueKey('day-save'),
        cancelKey: const ValueKey('day-cancel'),
        deleteLabel: 'Clear this day',
        deleteKey: const ValueKey('day-clear'),
        onDelete: _clearDay,
        children: [
          _dinnerSection(),
          _favouritesSection(),
          _ingredientsSection(),
          _breakfastLunchSection(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _head('NOTE'),
              const SizedBox(height: 9),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: _box.copyWith(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  key: const ValueKey('day-note'),
                  controller: _note,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  style: _field.copyWith(fontWeight: FontWeight.w600),
                  decoration: _plain('Anything the family should know…'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dinnerSection() {
    final name = _dinner.text.trim();
    final fav = s.isFavouriteMeal(name);
    final big = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -.4,
      color: context.tc.ink,
    );
    final heart = Opacity(
      opacity: name.isEmpty ? .45 : 1,
      child: GestureDetector(
        key: const ValueKey('day-fav'),
        behavior: HitTestBehavior.opaque,
        onTap: _toggleFavourite,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: fav ? context.tc.orangeSoft : context.tc.surface,
            border: Border.all(
              color: fav ? const Color(0xfffed7aa) : context.tc.line,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _heartIcon(
                filled: fav,
                color: fav ? context.tc.orangeText : context.tc.text,
              ),
              const SizedBox(width: 6),
              Text(
                fav ? 'Favourite' : 'Save',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: fav ? context.tc.orangeText : context.tc.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head('DINNER', null, context.tc.orangeText),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: name.isEmpty ? context.tc.line : context.tc.primary,
                width: 2,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
                  child: TextField(
                    key: const ValueKey('day-dinner'),
                    controller: _dinner,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.sentences,
                    style: big,
                    decoration: _plain(
                      'e.g. Pasta with tomato sauce',
                      style: big,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(padding: const EdgeInsets.only(bottom: 8), child: heart),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ic('clock', size: 14, sw: 2, color: context.tc.soft2),
            const SizedBox(width: 6),
            Text(
              'Time to make',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.tc.soft2,
              ),
            ),
            const Spacer(),
            Container(
              width: 92,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.centerLeft,
              decoration: _box,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('day-minutes'),
                      controller: _minutes,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      onChanged: (_) => setState(() {}),
                      style: _field,
                      decoration: _plain('—'),
                    ),
                  ),
                  Text('min', style: _hint),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _favouritesSection() {
    final library = s.savedMeals;
    final q = _query.text.trim();
    final hits = searchSavedMeals(library, q);
    final dinnerKey = mealKey(_dinner.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(
          'PICK FROM FAVOURITES',
          q.isEmpty ? '${library.length} saved' : '${hits.length} found',
        ),
        const SizedBox(height: 9),
        Container(
          height: 42,
          padding: const EdgeInsets.only(left: 12, right: 9),
          decoration: _box,
          child: Row(
            children: [
              ic('search', size: 15, sw: 2, color: context.tc.muted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('day-fav-search'),
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  style: _field,
                  decoration: _plain('Search by name or ingredient'),
                ),
              ),
              if (_query.text.isNotEmpty)
                GestureDetector(
                  key: const ValueKey('day-fav-search-clear'),
                  onTap: () => setState(_query.clear),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: context.tc.line,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: ic(
                        'x',
                        size: 10,
                        sw: 2.8,
                        color: context.tc.soft2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (q.isNotEmpty) ...[
          const SizedBox(height: 9),
          Container(
            key: const ValueKey('day-fav-results'),
            constraints: const BoxConstraints(maxHeight: 166),
            decoration: BoxDecoration(
              border: Border.all(color: context.tc.line),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: hits.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    child: Text(
                      'No favourites match “$q”',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: context.tc.soft2,
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (int i = 0; i < hits.length; i++)
                        _favRow(
                          hits[i],
                          i,
                          mealKey(hits[i].meal.name) == dinnerKey,
                        ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  Widget _favRow(SavedMealHit hit, int i, bool selected) {
    final m = hit.meal;
    final meta = hit.ingredient != null
        ? 'Contains ${hit.ingredient!.toLowerCase()}'
        : [
            '${m.ingredients.length} ingredient'
                '${m.ingredients.length == 1 ? '' : 's'}',
            if (m.minutes != null) '${m.minutes} min',
          ].join(' · ');
    return GestureDetector(
      key: ValueKey('day-fav-hit-${m.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _pick(m),
      child: Container(
        constraints: const BoxConstraints(minHeight: 55),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? context.tc.orangeSoft : context.tc.surface,
          border: i == 0
              ? null
              : Border(top: BorderSide(color: context.tc.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? context.tc.orangeText : context.tc.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.tc.soft2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              selected ? 'Selected' : 'Use',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: selected ? context.tc.orangeText : context.tc.deep,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ingredientsSection() {
    final fromLibrary = savedMealNamed(s.savedMeals, _dinner.text) != null;
    final hint = fromLibrary
        ? 'Filled in from your library'
        : _ings.isNotEmpty
        ? '${_ings.length} item${_ings.length == 1 ? '' : 's'}'
        : 'Optional';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head('INGREDIENTS', hint),
        if (_ings.isNotEmpty) ...[
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in _ings)
                Container(
                  key: ValueKey('day-ing-$g'),
                  padding: const EdgeInsets.fromLTRB(11, 4, 4, 4),
                  decoration: BoxDecoration(
                    color: context.tc.faint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(g, style: _field.copyWith(fontSize: 12.5)),
                      GestureDetector(
                        key: ValueKey('day-ing-remove-$g'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            setState(() => _ings = [..._ings]..remove(g)),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: Center(
                            child: ic(
                              'x',
                              size: 10,
                              sw: 2.6,
                              color: context.tc.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: _box,
                child: TextField(
                  key: const ValueKey('day-ing-new'),
                  controller: _newIng,
                  onChanged: (_) => setState(() {}),
                  // Keeps focus after Enter so the next one can be typed.
                  onEditingComplete: _addIngredient,
                  style: _field,
                  decoration: _plain('Add ingredient'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              key: const ValueKey('day-ing-add'),
              onTap: _addIngredient,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.tc.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: ic('plus', size: 16, sw: 2.4, color: context.tc.deep),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _breakfastLunchSection() {
    Widget row(String label, TextEditingController c, String key) => Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.tc.soft2,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              key: ValueKey(key),
              controller: c,
              onChanged: (_) => setState(() {}),
              style: _field,
              decoration: _plain('Not planned'),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head('BREAKFAST & LUNCH'),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: context.tc.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              row('Breakfast', _breakfast, 'day-breakfast'),
              Divider(height: 1, thickness: 1, color: context.tc.line),
              row('Lunch', _lunch, 'day-lunch'),
            ],
          ),
        ),
      ],
    );
  }
}

/// The favourite heart, outlined or filled.
Widget _heartIcon({required bool filled, required Color color}) {
  final hex =
      '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';
  return SvgPicture.string(
    '<svg width="14" height="14" viewBox="0 0 16 16" '
    'xmlns="http://www.w3.org/2000/svg"><path d="M8 13.5S2.5 10 2.5 6.2'
    'A2.7 2.7 0 0 1 8 5a2.7 2.7 0 0 1 5.5 1.2C13.5 10 8 13.5 8 13.5z" '
    'fill="${filled ? hex : 'none'}" stroke="$hex" stroke-width="1.8" '
    'stroke-linejoin="round"/></svg>',
    width: 14,
    height: 14,
  );
}
