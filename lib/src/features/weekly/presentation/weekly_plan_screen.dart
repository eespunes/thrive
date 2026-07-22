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

const List<(String, String, String)> _kMealSlots = [
  ('breakfast', 'coffee', 'Breakfast'),
  ('lunch', 'sun', 'Lunch'),
  ('dinner', 'moon', 'Dinner'),
];

/// The weekly meal plan (#157): a Mon–Sun grid with breakfast/lunch/dinner
/// slots and a per-day note, ported from the design's `renderWeekly()` /
/// `weekSubHeader()`.
extension _ThriveWeeklyPlanScreen on _ThriveHomeState {
  /// Monday of the week `weekOffset` weeks from the current one.
  DateTime _weekStart() {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final monday = base.subtract(Duration(days: base.weekday - 1));
    return monday.add(Duration(days: 7 * weekOffset));
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Sub-header shown under the "Weekly plan" title: prev/next week nav plus
  /// the visible date range, mirrors `weekSubHeader()`.
  Widget _weekSubHeader() {
    final start = _weekStart();
    final end = start.add(const Duration(days: 6));
    final sameMonth = start.month == end.month;
    final range = sameMonth
        ? '${kMonthsShort[start.month - 1]} ${start.day}–${end.day}'
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
    return Row(
      children: [
        stepBtn('cleft', () => shiftWeek(-1), 'week-prev'),
        Expanded(
          child: Text(
            range,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: B.ink,
            ),
          ),
        ),
        stepBtn('cright', () => shiftWeek(1), 'week-next'),
      ],
    );
  }

  Widget _buildWeeklyPlan() {
    final start = _weekStart();
    final today = todayIso();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        for (int i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: _dayCard(start.add(Duration(days: i)), i, today),
          ),
      ],
    );
  }

  Widget _dayCard(DateTime date, int weekdayIdx, String todayIso) {
    final dateIso = _iso(date);
    final isToday = dateIso == todayIso;
    final day = weeklyPlan[dateIso];
    return Container(
      key: ValueKey('weekday-$dateIso'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isToday ? B.primary : B.line),
        boxShadow: cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_kWeekdaysShort[weekdayIdx]} ${date.day}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: B.ink,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: B.soft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'TODAY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4,
                      color: B.deep,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          for (final (slot, icon, label) in _kMealSlots)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _mealRow(dateIso, slot, icon, label, day),
            ),
          _noteRow(dateIso, day),
        ],
      ),
    );
  }

  Widget _mealRow(
    String dateIso,
    String slot,
    String icon,
    String label,
    DayPlan? day,
  ) {
    final value = switch (slot) {
      'breakfast' => day?.breakfast,
      'lunch' => day?.lunch,
      'dinner' => day?.dinner,
      _ => null,
    };
    return GestureDetector(
      key: ValueKey('meal-$dateIso-$slot'),
      behavior: HitTestBehavior.opaque,
      onTap: () => openMealSheet(dateIso, slot, label, value),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: B.soft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(child: ic(icon, size: 15, sw: 2.1, color: B.primary)),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 66,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: B.soft2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value?.isNotEmpty ?? false) ? value! : 'Add $label',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: (value?.isNotEmpty ?? false) ? B.ink : B.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteRow(String dateIso, DayPlan? day) {
    final note = day?.note;
    return GestureDetector(
      key: ValueKey('note-$dateIso'),
      behavior: HitTestBehavior.opaque,
      onTap: () => openNoteSheet(dateIso, note),
      child: Container(
        margin: const EdgeInsets.only(top: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: B.faint,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            ic('edit', size: 13, sw: 2.1, color: B.soft2),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                (note?.isNotEmpty ?? false) ? note! : 'Add a note',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: (note?.isNotEmpty ?? false) ? B.text : B.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void openMealSheet(
    String dateIso,
    String slot,
    String label,
    String? current,
  ) {
    _showSheet(
      (ctx) => _MealEditSheet(
        state: this,
        dateIso: dateIso,
        slot: slot,
        label: label,
        initial: current ?? '',
      ),
    );
  }

  void openNoteSheet(String dateIso, String? current) {
    _showSheet(
      (ctx) => _DayNoteSheet(
        state: this,
        dateIso: dateIso,
        initial: current ?? '',
      ),
    );
  }
}
