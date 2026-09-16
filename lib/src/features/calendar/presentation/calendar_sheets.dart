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

/// "Go to month" (design §2a): a 2-column grid of month cards carrying the
/// month's event count under the current filters, plus a full-width
/// gradient "Jump to today". Tapping a card travels there — selecting today
/// for the current month, the 1st otherwise — and closes.
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
    final today = _parseIso(todayIso());

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
        _sheetHead(context, 'Go to month'),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
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
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.6,
          children: [
            for (var m = 1; m <= 12; m++)
              Builder(
                builder: (_) {
                  final on = m == cur.month && _year == cur.year;
                  final isNow = m == today.month && _year == today.year;
                  final past =
                      _year < today.year ||
                      (_year == today.year && m < today.month);
                  final first = _isoOf(_year, m, 1);
                  final last = _isoOf(_year, m, DateTime(_year, m + 1, 0).day);
                  final count = s.eventOccurrences(first, last).length;
                  final sub = count == 0
                      ? 'Nothing yet'
                      : '$count event${count > 1 ? 's' : ''}'
                            '${past ? ' · past' : ''}';
                  return GestureDetector(
                    key: ValueKey('cal-pick-month-$_year-$m'),
                    onTap: () {
                      s.update(() {
                        s.calAnchor = first;
                        final landing = s._calLandingDay(first);
                        s.calSel = landing;
                        s.agendaDay = landing;
                      });
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(13, 10, 11, 10),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: on ? const Color(0xffe7f5f3) : Colors.white,
                        border: Border.all(
                          color: on ? B.primary : B.line,
                          width: on ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${kMonthsEn[m - 1]} $_year'
                            '${isNow ? ' · now' : ''}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: on ? B.deep : B.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sub,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: on
                                  ? B.deep
                                  : past
                                  ? B.amberText
                                  : B.muted,
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
        const SizedBox(height: 16),
        GestureDetector(
          key: const ValueKey('cal-jump-today'),
          onTap: () {
            s.calToday();
            s.update(() => s.agendaDay = todayIso());
            Navigator.of(context).pop();
          },
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 50),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff12b3a4), B.primary, B.deep],
                stops: [0.0, .55, 1.0],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Text(
              'Jump to today',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "What do you want to see?" (design §2a) — three chip groups: Layers,
/// Categories (the appointment layers' categories) and Members. Chips are ON
/// by default; switched off they grey out, strike through their label and
/// dim their colour dot. Filters are per-user, never family-wide, and apply
/// live to the month, the agenda, the day sheets and the kitchen wall alike
/// through the shared [_ThriveCalendarActions.passes] gate.
class _CalFilterSheet extends StatefulWidget {
  const _CalFilterSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_CalFilterSheet> createState() => _CalFilterSheetState();
}

class _CalFilterSheetState extends State<_CalFilterSheet> {
  Widget _chip({
    Key? key,
    Widget? leading,
    required Widget dot,
    required String label,
    required bool on,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: EdgeInsets.fromLTRB(leading != null ? 5 : 11, 8, 13, 8),
        decoration: BoxDecoration(
          color: on ? color.withValues(alpha: .08) : Colors.white,
          border: Border.all(color: on ? color : B.line, width: 1.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) leading else dot,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: on ? color : B.muted,
                decoration: on
                    ? TextDecoration.none
                    : TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(Color color, bool on) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: color.withValues(alpha: on ? 1 : .35),
      shape: BoxShape.circle,
    ),
  );

  Widget _group(String title, List<Widget> chips) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
            color: B.muted,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Wrap(spacing: 6, runSpacing: 6, children: chips),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final members = s.curFamily()?.members ?? const <FamilyMember>[];
    final layers = s.calendarLayers.isEmpty
        ? kDefaultCalendarLayers()
        : s.calendarLayers;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'What do you want to see?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                  color: B.ink,
                ),
              ),
            ),
            GestureDetector(
              key: const ValueKey('cal-filter-clear'),
              onTap: () => setState(s.showAllCalFilters),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: B.faint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Show all',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: B.soft2,
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
        _group('LAYERS', [
          for (final layer in layers)
            Builder(
              builder: (_) {
                final on = s.layerFilter.contains(layer.id);
                return _chip(
                  key: ValueKey('cal-filter-layer-${layer.id}'),
                  dot: _colorDot(layer.color, on),
                  label: layer.label,
                  on: on,
                  color: layer.color,
                  onTap: () => setState(() => s.toggleLayerFilter(layer.id)),
                );
              },
            ),
        ]),
        _group('CATEGORIES', [
          for (final c in s.eventCategories)
            if (s.layerFilter.contains(c.layerId))
              Builder(
                builder: (_) {
                  final on = s.calCategoryOn(c.id);
                  return _chip(
                    key: ValueKey('cal-filter-cat-${c.id}'),
                    dot: _colorDot(c.color, on),
                    label: c.name,
                    on: on,
                    color: c.color,
                    onTap: () =>
                        setState(() => s.toggleCalCategoryFilter(c.id)),
                  );
                },
              ),
        ]),
        _group('MEMBERS', [
          for (final m in members)
            Builder(
              builder: (_) {
                final on = s.calMemberOn(m.id);
                return _chip(
                  key: ValueKey('cal-filter-member-${m.id}'),
                  leading: Opacity(
                    opacity: on ? 1 : .35,
                    child: s._memberAvatar(m.id, size: 22),
                  ),
                  dot: _colorDot(m.color, on),
                  label: m.name,
                  on: on,
                  color: m.color,
                  onTap: () => setState(() => s.toggleCalMemberFilter(m.id)),
                );
              },
            ),
        ]),
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text(
            'Categories live inside their layer. Events for several people '
            'stay visible while any of them is on. Filters apply to the '
            'month, the agenda, the day sheets and the kitchen wall — only '
            'for you, not the family.',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              height: 1.5,
              color: B.muted,
            ),
          ),
        ),
        _primaryBtn('Done', () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// One day's events (design §2a `daySheet`): the day's title with its event
/// count, full agenda rows from the shared builder, and — for today and
/// future days only — a dashed "＋ Add on this day". A past day is
/// view-only and says so.
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
      ..sort(state._compareAgendaOccurrences);
    final today = todayIso();
    final isToday = iso == today;
    final isPast = iso.compareTo(today) < 0;

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
                    _daySheetTitleIso(iso),
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
                            ? 'Free day'
                            : '${evs.length} event'
                                  '${evs.length > 1 ? 's' : ''}'),
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: Text(
                'Nothing planned — enjoy the calm.',
                key: ValueKey('day-sheet-empty'),
                style: TextStyle(
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
                  iso: iso,
                  popSheetFirst: true,
                  onToggleDone: () => setState(() {}),
                ),
                if (o != evs.last) const SizedBox(height: 9),
              ],
            ],
          ),
        const SizedBox(height: 14),
        if (isPast)
          Container(
            key: const ValueKey('day-sheet-past-notice'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xfff6efdb),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Text(
              'This day is in the past — view only.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xff8a7734),
              ),
            ),
          )
        else
          GestureDetector(
            key: const ValueKey('day-sheet-add'),
            onTap: () {
              Navigator.of(context).pop();
              state.openEvent(null, iso);
            },
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              foregroundDecoration: const _DottedBoxDecoration(
                color: B.primary,
                radius: 14,
                width: 1.5,
              ),
              child: const Text(
                '＋ Add on this day',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: B.deep,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
