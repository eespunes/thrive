part of 'package:family_money_management_app/main.dart';

const List<String> _kWeekdaysShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _kWeekdaysLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The meal plan's accent: dinner labels, planned-day dots, favourites.
const Color _kMealAccent = Color(0xffc2410c);

/// [d] moved by [n] calendar days (DST-safe: built from y/m/d, not hours).
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// "Tuesday" for an ISO date.
String _weekdayLong(String dateIso) {
  final d = DateTime.tryParse(dateIso);
  return d == null ? dateIso : _kWeekdaysLong[d.weekday - 1];
}

/// ISO-8601 week number of [d].
int _isoWeekNumber(DateTime d) {
  final thursday = DateTime.utc(d.year, d.month, d.day + 4 - d.weekday);
  return thursday.difference(DateTime.utc(thursday.year)).inDays ~/ 7 + 1;
}

/// The weekly meal plan, 2a redesign (#496, epic #500): a Mon–Sun day strip
/// in the sub-header and, for the picked day, a dinner-first card with its
/// ingredient checklist (#497) plus breakfast / lunch / note tiles. Every
/// tap opens the whole-day editor (#498).
extension _ThriveWeeklyPlanScreen on _ThriveHomeState {
  /// Monday of the week `weekOffset` weeks from the current one.
  DateTime _weekStart() {
    final now = debugNowOverride?.call() ?? DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    return _addDays(base, 1 - base.weekday + 7 * weekOffset);
  }

  String _iso(DateTime d) => _isoDate(d);

  /// The day shown in the card: the picked day when it's in the visible
  /// week, else today when it is, else that week's Monday.
  String mealSelectedDay() {
    final start = _iso(_weekStart());
    final end = _iso(_addDays(_weekStart(), 6));
    bool inWeek(String? iso) =>
        iso != null && iso.compareTo(start) >= 0 && iso.compareTo(end) <= 0;
    if (inWeek(mealDaySel)) return mealDaySel!;
    final today = todayIso();
    return inWeek(today) ? today : start;
  }

  /// Pinned under the tab title: "MEALS · WEEK 42 / October 12–18" with
  /// prev/next, then the seven-day strip.
  Widget _weekSubHeader() {
    final start = _weekStart();
    final end = _addDays(start, 6);
    final range = start.month == end.month
        ? '${kMonthsEn[start.month - 1]} ${start.day}–${end.day}'
        : '${kMonthsShort[start.month - 1]} ${start.day} – '
              '${kMonthsShort[end.month - 1]} ${end.day}';
    Widget stepBtn(String icon, VoidCallback onTap, String key) =>
        GestureDetector(
          key: ValueKey(key),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: B.line),
            ),
            child: Center(child: ic(icon, size: 16, sw: 2.4, color: B.soft2)),
          ),
        );
    final today = todayIso();
    final sel = mealSelectedDay();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MEALS · WEEK ${_isoWeekNumber(start)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4,
                      color: B.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    range,
                    key: const ValueKey('week-range'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                      color: B.ink,
                    ),
                  ),
                ],
              ),
            ),
            stepBtn('cleft', () => shiftWeek(-1), 'week-prev'),
            const SizedBox(width: 6),
            stepBtn('cright', () => shiftWeek(1), 'week-next'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (int i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(child: _dayStripCell(_addDays(start, i), i, sel, today)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _dayStripCell(DateTime date, int i, String sel, String today) {
    final iso = _iso(date);
    final active = iso == sel;
    final planned = weeklyPlan[iso]?.dinner?.isNotEmpty ?? false;
    final fg = active ? Colors.white : B.ink;
    return GestureDetector(
      key: ValueKey('meal-day-$iso'),
      behavior: HitTestBehavior.opaque,
      onTap: () => selectMealDay(iso),
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 9),
        decoration: BoxDecoration(
          color: active ? B.ink : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: active
              ? null
              : Border.all(
                  color: iso == today ? B.primary : B.line,
                  width: iso == today ? 1.5 : 1,
                ),
        ),
        child: Column(
          children: [
            Opacity(
              opacity: .75,
              child: Text(
                _kWeekdaysShort[i],
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .3,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              key: planned ? ValueKey('meal-dot-$iso') : null,
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !planned
                    ? Colors.transparent
                    : active
                    ? const Color(0xfffdba74)
                    : _kMealAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyPlan() {
    final iso = mealSelectedDay();
    final day = weeklyPlan[iso];
    String? v(String? s) => (s?.trim().isEmpty ?? true) ? null : s!.trim();
    final breakfast = v(day?.breakfast);
    final lunch = v(day?.lunch);
    final note = v(day?.note);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        _dinnerCard(iso, day),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _mealTile(iso, 'breakfast', 'BREAKFAST', breakfast),
            ),
            const SizedBox(width: 10),
            Expanded(child: _mealTile(iso, 'lunch', 'LUNCH', lunch)),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          key: const ValueKey('meal-tile-note'),
          behavior: HitTestBehavior.opaque,
          onTap: () => openDayEditor(iso),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xffeef1f5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              note ?? 'Add a note for the family…',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: note != null ? B.text : B.placeholder,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mealTile(String iso, String slot, String label, String? value) {
    return GestureDetector(
      key: ValueKey('meal-tile-$slot'),
      behavior: HitTestBehavior.opaque,
      onTap: () => openDayEditor(iso),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: B.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
                color: B.muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value ?? 'Add $slot',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: value != null ? B.ink : B.placeholder,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dinnerCard(String iso, DayPlan? day) {
    final dinner = day?.dinner?.trim() ?? '';
    final has = dinner.isNotEmpty;
    return Container(
      key: const ValueKey('meal-dinner-card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: B.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73101828),
            blurRadius: 30,
            spreadRadius: -24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'DINNER · ${_weekdayLong(iso).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                    color: _kMealAccent,
                  ),
                ),
              ),
              GestureDetector(
                key: const ValueKey('meal-edit'),
                onTap: () => openDayEditor(iso),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: B.faint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ic('edit', size: 14, sw: 2, color: B.text),
                      const SizedBox(width: 6),
                      const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: B.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (has) ..._plannedDinner(day!, dinner) else _planDinnerButton(iso),
        ],
      ),
    );
  }

  Widget _planDinnerButton(String iso) {
    return GestureDetector(
      key: const ValueKey('meal-plan-dinner'),
      behavior: HitTestBehavior.opaque,
      onTap: () => openDayEditor(iso),
      child: CustomPaint(
        foregroundPainter: const _DashedRRectPainter(
          color: Color(0xfffed7aa),
          radius: 16,
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: B.orangeSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plan dinner',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                  color: _kMealAccent,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Type it, or pick from favourites',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff9a3412),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _plannedDinner(DayPlan day, String dinner) {
    final ings = day.ingredients;
    final groceries = groceriesListOf(shoppingLists);
    final missing = missingGroceries(groceries, ings).length;
    final meta = [
      '${ings.length} ingredient${ings.length == 1 ? '' : 's'}',
      if (day.dinnerMinutes != null) '${day.dinnerMinutes} min',
    ].join(' · ');
    return [
      Text(
        dinner,
        key: const ValueKey('meal-dinner-name'),
        style: const TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w800,
          letterSpacing: -.7,
          height: 1.1,
          color: B.ink,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        meta,
        key: const ValueKey('meal-dinner-meta'),
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: B.soft2,
        ),
      ),
      if (ings.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xfff0f2f6))),
          ),
          child: Column(
            children: [
              for (final ing in ings)
                _ingredientRow(ing, groceryLineFor(groceries, ing) != null),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          key: const ValueKey('meal-groceries-all'),
          behavior: HitTestBehavior.opaque,
          onTap: () => addMissingToGroceries(ings),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: missing > 0 ? B.primary : B.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ic(
                  'cart',
                  size: 16,
                  sw: 2,
                  color: missing > 0 ? Colors.white : B.deep,
                ),
                const SizedBox(width: 8),
                Text(
                  missing > 0
                      ? 'Add $missing missing to Groceries'
                      : 'Everything is on Groceries',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: missing > 0 ? Colors.white : B.deep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  Widget _ingredientRow(String ing, bool onList) {
    return GestureDetector(
      key: ValueKey('meal-ing-$ing'),
      behavior: HitTestBehavior.opaque,
      onTap: () => toggleIngredientOnGroceries(ing),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xfff0f2f6))),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: onList ? B.primary : Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: onList
                    ? null
                    : Border.all(color: const Color(0xffcfd6e0), width: 1.5),
              ),
              child: onList
                  ? Center(
                      child: ic(
                        'check',
                        size: 12,
                        sw: 2.8,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                ing,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: onList ? B.soft2 : B.ink,
                ),
              ),
            ),
            if (onList)
              const Text(
                'On list',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: B.deep,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Opens the whole-day editor (#498) for [dateIso].
  void openDayEditor(String dateIso) {
    if (childBlocked(kChildMealPlanReadOnly)) return;
    openEditorSheet<void>(
      (ctx) => _DayEditorSheet(
        state: this,
        dateIso: dateIso,
        initial: weeklyPlan[dateIso]?.copy() ?? DayPlan(dateIso: dateIso),
      ),
      enableDrag: false,
    );
  }
}
