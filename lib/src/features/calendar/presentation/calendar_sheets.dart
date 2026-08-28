part of 'package:family_money_management_app/main.dart';

String defaultCalendarEndTimeForStart(String time) {
  final parts = time.split(':');
  final hour = int.tryParse(parts.elementAtOrNull(0) ?? '') ?? 0;
  final minute = int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0;
  final next = (hour * 60 + minute + 60) % (24 * 60);
  return '${(next ~/ 60).toString().padLeft(2, '0')}:'
      '${(next % 60).toString().padLeft(2, '0')}';
}

String calendarReminderLabel(String reminder) {
  return switch (reminder) {
    'none' => 'No reminder',
    'at' => 'On time',
    '5m' => '5 minutes before',
    '15m' => '15 minutes before',
    '30m' => '30 minutes before',
    '1h' => '1 hour before',
    '2h' => '2 hours before',
    '1d' => '1 day before',
    '2d' => '2 days before',
    _ => reminder,
  };
}

String calendarRepeatLabel(CalendarEvent ev) {
  if (ev.recur == 'monthly' && ev.monthlyMode == 'nthWeekday') {
    const nth = ['first', 'second', 'third', 'fourth', 'last'];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return 'every ${nth[ev.monthlyNth.clamp(1, 5) - 1]} '
        '${days[ev.monthlyWeekday.clamp(1, 7) - 1]}';
  }
  if (ev.recur != 'custom') return ev.recur;
  final every = ev.recurEvery < 1 ? 1 : ev.recurEvery;
  final unit = switch (ev.recurUnit) {
    'day' => every == 1 ? 'day' : 'days',
    'month' => every == 1 ? 'month' : 'months',
    'year' => every == 1 ? 'year' : 'years',
    _ => every == 1 ? 'week' : 'weeks',
  };
  final base = every == 1 ? 'every $unit' : 'every $every $unit';
  if (ev.recurUnit != 'week') return base;
  final weekdays = _customRepeatWeekdays(
    ev,
  ).map((day) => kWeekdayLetters[day - 1]).join(', ');
  return '$base on $weekdays';
}

/// "New event" / "Edit event" sheet — title, all-day, date/time, location,
/// category, attendees, colour, reminder, repeat, notes. Ported from the
/// design's `sheetEventEdit()`.
extension _NullableList<T> on List<T> {
  T? elementAtOrNull(int i) => i >= 0 && i < length ? this[i] : null;
}

/// Read-only event detail sheet, ported from `sheetEventView()`.
class _EventViewSheet extends StatelessWidget {
  const _EventViewSheet({
    required this.state,
    required this.eventId,
    required this.date,
  });
  final _ThriveHomeState state;
  final String eventId;
  final String date;

  Widget _metaRow(String icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: B.faint)),
      ),
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
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: B.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = state.eventOrImportedById(eventId);
    final ev = r.ev;
    final imported = r.imported;
    if (ev == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [_sheetHead(context, 'Event', 'Not found')],
      );
    }
    final cat = state.catById(ev.category);
    final creatorId = ev.createdBy;
    final creator = creatorId == null
        ? null
        : (state.curFamily()?.members ?? const <FamilyMember>[]).where(
            (m) => m.id == creatorId,
          );
    final isMultiDay =
        ev.recur == 'none' &&
        ev.endDate.isNotEmpty &&
        ev.endDate.compareTo(ev.date) > 0;
    final dateLabel = isMultiDay
        ? '${_shortDateIso(ev.date)} – ${_shortDateIso(ev.endDate)}'
        : _prettyDateIso(date);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 34,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: state.evColor(ev),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (cat != null) ...[
                        categoryGlyph(
                          cat,
                          size: 20,
                          iconColor: state.evColor(ev),
                        ),
                        const SizedBox(width: 7),
                      ],
                      Expanded(
                        child: Text(
                          ev.title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.3,
                            color: B.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: B.soft2,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: B.faint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: ic('x', size: 17, sw: 2.2, color: B.soft2),
                ),
              ),
            ),
          ],
        ),
        if (cat != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Builder(
              builder: (context) {
                final fg = contrastOn(cat.color);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cat.color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      categoryGlyph(cat, size: 15, iconColor: fg),
                      const SizedBox(width: 6),
                      Text(
                        cat.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              _metaRow(
                'clock',
                ev.allDay
                    ? 'All day'
                    : '${ev.start}${ev.end.isNotEmpty ? ' – ${ev.end}' : ''}',
              ),
              if (ev.location.isNotEmpty) _metaRow('mappin', ev.location),
              if (ev.recur != 'none')
                _metaRow(
                  'repeat',
                  ev.endDate.isEmpty
                      ? 'Repeats ${calendarRepeatLabel(ev)}'
                      : 'Repeats ${calendarRepeatLabel(ev)} until ${_shortDateIso(ev.endDate)}',
                ),
              if (ev.reminder != 'none')
                _metaRow(
                  'bell',
                  'Reminder · ${calendarReminderLabel(ev.reminder).toLowerCase()}',
                ),
              if (ev.notes.isNotEmpty) _metaRow('note', ev.notes),
            ],
          ),
        ),
        if (!imported) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 7),
            child: Text(
              'ATTENDEES',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: B.muted,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in ev.attendees)
                  Container(
                    padding: const EdgeInsets.fromLTRB(4, 4, 11, 4),
                    decoration: BoxDecoration(
                      color: B.soft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        state._memberAvatar(id, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          state._memberById(id)?.name ?? '?',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: B.deep,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (creator != null && creator.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              imported
                  ? 'Imported from ${creator.first.name}'
                  : 'Created by ${creator.first.name}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: B.muted,
              ),
            ),
          ),
        if (imported)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            decoration: BoxDecoration(
              color: B.faint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ic('download', size: 15, sw: 2.2, color: B.soft2),
                const SizedBox(width: 8),
                const Text(
                  'Imported events are read-only',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: B.soft2,
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    state.openEvent(ev, date);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      border: Border.all(color: B.line),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ic('edit', size: 16, sw: 2.2, color: B.soft2),
                        const SizedBox(width: 7),
                        const Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: B.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    if (ev.recur != 'none') {
                      state._showSheet(
                        (ctx) => _RecurDeleteSheet(
                          state: state,
                          eventId: ev.id,
                          date: date,
                        ),
                      );
                    } else {
                      state.askDelete(
                        ev.title,
                        'This event will be permanently removed.',
                        () => state.deleteEvent(ev.id, 'all'),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: B.redSoft,
                      border: Border.all(color: B.redLine),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ic('trash', size: 16, sw: 2.2, color: B.red),
                        const SizedBox(width: 7),
                        const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: B.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _RecurEditScopeSheet extends StatelessWidget {
  const _RecurEditScopeSheet({
    required this.state,
    required this.eventId,
    required this.date,
    required this.edited,
  });
  final _ThriveHomeState state;
  final String eventId;
  final String date;
  final CalendarEvent edited;

  Widget _choice({
    required String key,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return GestureDetector(
      key: ValueKey(key),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: danger ? B.redSoft : Colors.white,
          border: Border.all(color: danger ? B.redLine : B.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: danger ? B.red : B.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: danger ? B.red : B.soft2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    void save(String scope) {
      Navigator.of(context).pop();
      state.saveRecurringEventScoped(
        id: eventId,
        scope: scope,
        occurrenceDate: date,
        edited: edited,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHead(context, 'Save recurring event', 'This event repeats'),
        _choice(
          key: 'recur-edit-one',
          title: 'Save this event only',
          subtitle: 'Just ${_prettyDateIso(date)}',
          onTap: () => save('one'),
        ),
        _choice(
          key: 'recur-edit-future',
          title: 'Save this and future events',
          subtitle: 'This occurrence and everything after it',
          onTap: () => save('future'),
        ),
        _choice(
          key: 'recur-edit-all',
          title: 'Save the whole occurrence',
          subtitle: 'Every occurrence in the series',
          onTap: () => save('all'),
        ),
      ],
    );
  }
}

/// Recurring delete scope picker.
class _RecurDeleteSheet extends StatelessWidget {
  const _RecurDeleteSheet({
    required this.state,
    required this.eventId,
    required this.date,
  });
  final _ThriveHomeState state;
  final String eventId;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHead(context, 'Delete recurring event', 'This event repeats'),
        GestureDetector(
          key: const ValueKey('recur-delete-one'),
          onTap: () {
            Navigator.of(context).pop();
            state.deleteEvent(eventId, 'one', date);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: Border.all(color: B.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delete this event only',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: B.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Just ${_prettyDateIso(date)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: B.soft2,
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          key: const ValueKey('recur-delete-future'),
          onTap: () {
            Navigator.of(context).pop();
            state.deleteEvent(eventId, 'future', date);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: Border.all(color: B.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delete this and future events',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: B.ink,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'This occurrence and everything after it',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: B.soft2,
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          key: const ValueKey('recur-delete-all'),
          onTap: () {
            Navigator.of(context).pop();
            state.deleteEvent(eventId, 'all');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: B.redSoft,
              border: Border.all(color: B.redLine),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delete the whole occurrence',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: B.red,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Every occurrence in the series',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: B.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Month picker — year nav + a 3x4 month grid, ported from the design's
/// `monthSheet()`. Tapping a month jumps `calAnchor` there.
class _CalMonthPickerSheet extends StatefulWidget {
  const _CalMonthPickerSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_CalMonthPickerSheet> createState() => _CalMonthPickerSheetState();
}

class _CalMonthPickerSheetState extends State<_CalMonthPickerSheet> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = _parseIso(widget.state.calAnchor).year;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final cur = _parseIso(s.calAnchor);
    final todayYear = _parseIso(todayIso()).year;
    final todayMonth = _parseIso(todayIso()).month;

    Widget yearBtn(String icon, int dy) {
      return GestureDetector(
        key: ValueKey('cal-year-$icon'),
        onTap: () => setState(() => _year += dy),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: B.line),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(child: ic(icon, size: 17, sw: 2.4, color: B.soft2)),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHead(context, 'Jump to a month'),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              yearBtn('cleft', -1),
              Expanded(
                child: Text(
                  '$_year',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: B.ink,
                  ),
                ),
              ),
              yearBtn('cright', 1),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          childAspectRatio: 1.9,
          children: [
            for (var m = 1; m <= 12; m++)
              Builder(
                builder: (_) {
                  final on = m == cur.month && _year == cur.year;
                  final isNow = m == todayMonth && _year == todayYear;
                  return GestureDetector(
                    key: ValueKey('cal-pick-month-$_year-$m'),
                    onTap: () {
                      s.update(() => s.calAnchor = _isoOf(_year, m, 1));
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: on ? B.primary : Colors.white,
                        border: Border.all(color: on ? B.primary : B.line),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            kMonthsShort[m - 1],
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: on ? Colors.white : B.ink,
                            ),
                          ),
                          if (isNow && !on)
                            Positioned(
                              top: 6,
                              right: 8,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: B.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        _primaryBtn('Jump to today', () {
          s.calToday();
          Navigator.of(context).pop();
        }),
      ],
    );
  }
}

/// View-switcher sheet — Month/Agenda plus the Kitchen dashboard entry point.
class _ViewPickerSheet extends StatelessWidget {
  const _ViewPickerSheet({required this.state});
  final _ThriveHomeState state;

  @override
  Widget build(BuildContext context) {
    Widget row({
      required Key key,
      required String icon,
      required String label,
      String? sub,
      required bool on,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          key: key,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: on ? B.soft : Colors.white,
              border: Border.all(color: on ? B.primary : B.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: on ? B.primary : B.faint,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: ic(
                      icon,
                      size: 17,
                      sw: 2.2,
                      color: on ? Colors.white : B.soft2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: on ? B.deep : B.ink,
                        ),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: B.soft2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (on) ic('check', size: 19, sw: 2.6, color: B.primary),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHead(context, 'View'),
        for (final (value, label, icon) in kCalViews)
          Builder(
            builder: (_) {
              final on = state.calView == value;
              return row(
                key: ValueKey('cal-view-$value'),
                icon: icon,
                label: label,
                on: on,
                onTap: () {
                  state.setCalView(value);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        row(
          key: const ValueKey('cal-view-kitchen-dashboard'),
          icon: 'columns',
          label: 'Kitchen dashboard',
          sub: state.kitchenEnabled
              ? 'Wall-tablet family view'
              : 'Disabled - tap to re-enable',
          on: false,
          onTap: () {
            Navigator.of(context).pop();
            if (state.kitchenEnabled) {
              state.openKitchenDashboard();
            } else {
              state.toggleKitchenEnabled();
            }
          },
        ),
      ],
    );
  }
}

/// Multi-select filter sheet — family members + categories, ported from
/// `filterSheet()`.
class _CalFilterSheet extends StatefulWidget {
  const _CalFilterSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_CalFilterSheet> createState() => _CalFilterSheetState();
}

class _CalFilterSheetState extends State<_CalFilterSheet> {
  Widget _chip({
    Key? key,
    required Widget? leading,
    required String label,
    required bool on,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(leading != null ? 5 : 13, 8, 13, 8),
        decoration: BoxDecoration(
          color: on ? color.withValues(alpha: .12) : Colors.white,
          border: Border.all(color: on ? color : B.line, width: on ? 1.5 : 1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 6)],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: on ? color : B.soft2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final members = s.curFamily()?.members ?? const <FamilyMember>[];
    final count = s.calFilterCount();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Filters',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                  color: B.ink,
                ),
              ),
            ),
            if (count > 0)
              GestureDetector(
                key: const ValueKey('cal-filter-clear'),
                onTap: () => setState(s.clearCalFilters),
                child: const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: B.primary,
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: B.faint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: ic('x', size: 17, sw: 2.2, color: B.soft2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'LAYERS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
            color: B.muted,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Falls back to the 3 built-in layer definitions when
              // [calendarLayers] hasn't been seeded yet (a legacy/new
              // workspace with zero layer definitions) — the filter chips
              // (and `layerFilter`, which already defaults to all 3 ids)
              // must still work even before any layer has been customized.
              for (final layer
                  in s.calendarLayers.isEmpty
                      ? kDefaultCalendarLayers()
                      : s.calendarLayers)
                _chip(
                  key: ValueKey('cal-filter-layer-${layer.id}'),
                  leading: glyphTile(
                    size: 14,
                    radius: 4,
                    picture: layer.picture,
                    emoji: layer.emoji,
                    emojiSize: 12,
                    fallback: ic(
                      layer.icon,
                      size: 14,
                      sw: 2.3,
                      color: s.layerFilter.contains(layer.id)
                          ? layer.color
                          : B.soft2,
                    ),
                  ),
                  label: layer.label,
                  on: s.layerFilter.contains(layer.id),
                  color: layer.color,
                  onTap: () => setState(() => s.toggleLayerFilter(layer.id)),
                ),
            ],
          ),
        ),
        const Text(
          'FAMILY MEMBERS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
            color: B.muted,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in members)
                _chip(
                  key: ValueKey('cal-filter-member-${m.id}'),
                  leading: s._memberAvatar(m.id, size: 22),
                  label: m.name,
                  on: s.calFilter.contains(m.id),
                  color: m.color,
                  onTap: () => setState(() => s.toggleCalMemberFilter(m.id)),
                ),
            ],
          ),
        ),
        const Text(
          'CATEGORIES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
            color: B.muted,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 22),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in s.eventCategories)
                if (s.layerFilter.contains(c.layerId))
                  _chip(
                    key: ValueKey('cal-filter-cat-${c.id}'),
                    leading: categoryGlyph(c, size: 15, iconColor: c.color),
                    label: c.name,
                    on: s.calCatFilter.contains(c.id),
                    color: c.color,
                    onTap: () =>
                        setState(() => s.toggleCalCategoryFilter(c.id)),
                  ),
            ],
          ),
        ),
        _primaryBtn(
          count > 0
              ? 'Show $count filter${count > 1 ? 's' : ''}'
              : 'Show all events',
          () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Full day's events, ported from `daySheet()` — replaces Month view's old
/// inline "selected day" panel; opened by tapping a day number.
class _DayDetailSheet extends StatefulWidget {
  const _DayDetailSheet({required this.state, required this.iso});
  final _ThriveHomeState state;
  final String iso;

  @override
  State<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<_DayDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final iso = widget.iso;
    final evs = state.eventOccurrences(iso, iso)
      ..sort(
        (a, b) => (a.ev.allDay ? '' : a.ev.start).compareTo(
          b.ev.allDay ? '' : b.ev.start,
        ),
      );
    final isToday = iso == todayIso();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _prettyDateIso(iso),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                      color: B.ink,
                    ),
                  ),
                  Text(
                    (isToday ? 'Today · ' : '') +
                        (evs.isEmpty
                            ? 'No events'
                            : '${evs.length} event${evs.length > 1 ? 's' : ''}'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: B.muted,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: B.faint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: ic('x', size: 17, sw: 2.2, color: B.soft2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (evs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: Text(
                'Nothing scheduled for this day.',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: B.muted,
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              for (final o in evs) ...[
                state._eventCard(
                  o,
                  popSheetFirst: true,
                  onToggleDone: () => setState(() {}),
                ),
                if (o != evs.last) const SizedBox(height: 9),
              ],
            ],
          ),
        const SizedBox(height: 14),
        _primaryBtn('Add event for this day', () {
          Navigator.of(context).pop();
          state.openEvent(null, iso);
        }),
      ],
    );
  }
}
