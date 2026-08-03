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
class _EventEditSheet extends StatefulWidget {
  const _EventEditSheet({required this.state, required this.date, this.event});
  final _ThriveHomeState state;
  final String date;
  final CalendarEvent? event;

  @override
  State<_EventEditSheet> createState() => _EventEditSheetState();
}

class _EventEditSheetState extends State<_EventEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  late bool _allDay;
  late bool _multiDay;
  late String _date;
  late String _endDate;
  late String _repeatEndDate;
  late String _start;
  late String _end;
  String? _category;
  late Color _color;
  late List<String> _attendees;
  late String _reminder;
  late String _recur;
  late int _recurEvery;
  late String _recurUnit;
  late List<int> _recurWeekdays;
  bool _endManuallySet = false;

  bool get _editing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _title = TextEditingController(text: e?.title ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _allDay = e?.allDay ?? false;
    _date = e?.date ?? widget.date;
    _recur = e?.recur ?? 'none';
    _multiDay = _recur == 'none' && e?.endDate.isNotEmpty == true;
    _endDate = _multiDay ? e!.endDate : _date;
    _repeatEndDate = _recur != 'none' ? (e?.endDate ?? '') : '';
    _start = e?.start.isNotEmpty == true ? e!.start : '09:00';
    _end = e?.end.isNotEmpty == true ? e!.end : '10:00';
    _category = e?.category;
    _color = e?.color ?? kEventColors.first;
    _attendees = (e?.attendees ?? const ['me']).toList();
    _reminder = e?.reminder ?? '1h';
    _recurEvery = e?.recurEvery ?? 1;
    _recurUnit = e?.recurUnit ?? 'week';
    _recurWeekdays = (e?.recurWeekdays ?? const <int>[]).toList();
    if (_recurWeekdays.isEmpty) _recurWeekdays = [_parseIso(_date).weekday];
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseIso(_date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _date = _isoOfDate(picked);
      if (_endDate.compareTo(_date) < 0) _endDate = _date;
      if (_repeatEndDate.isNotEmpty && _repeatEndDate.compareTo(_date) < 0) {
        _repeatEndDate = _date;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseIso(_endDate),
      firstDate: _parseIso(_date),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = _isoOfDate(picked));
  }

  Future<void> _pickRepeatEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseIso(
        _repeatEndDate.isNotEmpty ? _repeatEndDate : _date,
      ),
      firstDate: _parseIso(_date),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _repeatEndDate = _isoOfDate(picked));
  }

  Future<void> _pickTime(bool isStart) async {
    final cur = isStart ? _start : _end;
    final parts = cur.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.elementAtOrNull(0) ?? '') ?? 9,
      minute: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isStart) {
        _start = formatted;
        if (!_editing && !_endManuallySet) {
          _end = defaultCalendarEndTimeForStart(formatted);
        }
      } else {
        _end = formatted;
        _endManuallySet = true;
      }
    });
  }

  Widget _timeField(String label, String value, VoidCallback onTap) {
    return _sheetField(
      label,
      GestureDetector(
        key: ValueKey('event-time-${label.toLowerCase()}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: B.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: B.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipRow(
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

  Widget _numberChipRow(List<int> opts, int value, ValueChanged<int> onPick) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in opts) ...[
            GestureDetector(
              key: ValueKey('event-custom-every-$option'),
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

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final members = s.curFamily()?.members ?? const <FamilyMember>[];
    final categories = s.eventCategories;
    final valid = _title.text.trim().isNotEmpty;

    void submit() {
      final edited = CalendarEvent(
        id: widget.event?.id ?? uid(),
        title: _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim(),
        allDay: _allDay,
        date: _date,
        endDate: _recur != 'none'
            ? _repeatEndDate
            : (_multiDay ? _endDate : ''),
        start: _allDay ? '' : _start,
        end: _allDay ? '' : _end,
        location: _location.text.trim(),
        notes: _notes.text.trim(),
        category: _category,
        color: s.catById(_category)?.color ?? _color,
        attendees: _attendees.isEmpty ? ['me'] : _attendees,
        reminder: _reminder,
        recur: _recur,
        recurEvery: _recurEvery,
        recurUnit: _recurUnit,
        recurWeekdays: _recurWeekdays,
        exceptions: widget.event?.exceptions,
        createdBy: widget.event?.createdBy,
      );
      if (_editing && widget.event?.recur != 'none') {
        Navigator.of(context).pop();
        s._showSheet(
          (ctx) => _RecurEditScopeSheet(
            state: s,
            eventId: widget.event!.id,
            date: widget.date,
            edited: edited,
          ),
        );
        return;
      }
      s.saveEvent(
        id: widget.event?.id,
        title: edited.title,
        allDay: edited.allDay,
        date: edited.date,
        endDate: edited.endDate,
        start: edited.start,
        end: edited.end,
        location: edited.location,
        notes: edited.notes,
        category: edited.category,
        color: edited.color,
        attendees: edited.attendees,
        reminder: edited.reminder,
        recur: edited.recur,
        recurEvery: edited.recurEvery,
        recurUnit: edited.recurUnit,
        recurWeekdays: edited.recurWeekdays,
        exceptions: widget.event?.exceptions,
        createdBy: widget.event?.createdBy,
      );
      Navigator.of(context).pop();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHeadWithTick(
          context,
          _editing ? 'Edit event' : 'New event',
          onConfirm: submit,
          confirmEnabled: valid,
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          _sheetField(
            'Title',
            _sheetInput(
              _title,
              hint: 'e.g. Dentist appointment',
              onChanged: (_) => setState(() {}),
            ),
          ),
          _toggleRow(
            'All-day',
            _allDay,
            () => setState(() => _allDay = !_allDay),
            activeColor: B.primary,
          ),
          const SizedBox(height: 13),
          _sheetField(
            'Date',
            GestureDetector(
              onTap: _pickDate,
              child: Container(
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
                      _displayDateIso(_date),
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
          ),
          if (_recur == 'none') ...[
            _toggleRow(
              'Multi-day',
              _multiDay,
              () => setState(() {
                _multiDay = !_multiDay;
                if (!_multiDay) _endDate = _date;
              }),
              activeColor: B.primary,
            ),
            const SizedBox(height: 13),
            if (_multiDay)
              _sheetField(
                'Ends',
                GestureDetector(
                  onTap: _pickEndDate,
                  child: Container(
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
                          _displayDateIso(_endDate),
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
              ),
          ],
          if (!_allDay)
            Row(
              children: [
                Expanded(
                  child: _timeField('Start', _start, () => _pickTime(true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _timeField('End', _end, () => _pickTime(false)),
                ),
              ],
            ),
          _sheetField(
            'Location',
            _sheetInput(
              _location,
              hint: 'Optional',
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              'CATEGORY',
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _category = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _category == null ? B.soft : Colors.white,
                        border: Border.all(
                          color: _category == null ? B.primary : B.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'None',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _category == null ? B.deep : B.soft2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  for (final c in categories) ...[
                    GestureDetector(
                      key: ValueKey('event-cat-${c.id}'),
                      onTap: () => setState(() {
                        _category = c.id;
                        _color = c.color;
                        for (final mid in c.members) {
                          if (!_attendees.contains(mid)) _attendees.add(mid);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _category == c.id ? c.color : Colors.white,
                          border: Border.all(
                            color: _category == c.id ? c.color : B.line,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            categoryGlyph(
                              c,
                              size: 14,
                              iconColor: _category == c.id
                                  ? Colors.white
                                  : c.color,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              c.name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: _category == c.id
                                    ? Colors.white
                                    : B.soft2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  GestureDetector(
                    key: const ValueKey('event-new-category'),
                    onTap: () {
                      Navigator.of(context).pop();
                      s.openCategory(null);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: B.line,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ic('plus', size: 13, sw: 2.5, color: B.primary),
                          const SizedBox(width: 3),
                          const Text(
                            'New',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: B.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
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
            padding: const EdgeInsets.only(bottom: 13),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in members)
                  GestureDetector(
                    key: ValueKey('event-att-${m.id}'),
                    onTap: () => setState(() {
                      if (_attendees.contains(m.id)) {
                        _attendees.remove(m.id);
                      } else {
                        _attendees.add(m.id);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(5, 5, 11, 5),
                      decoration: BoxDecoration(
                        color: _attendees.contains(m.id)
                            ? B.soft
                            : Colors.white,
                        border: Border.all(
                          color: _attendees.contains(m.id) ? B.primary : B.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          s.avatarNode(
                            photo: m.photo,
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
                              color: _attendees.contains(m.id)
                                  ? B.deep
                                  : B.soft2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              _category != null ? 'COLOUR (FROM CATEGORY)' : 'COLOUR',
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
            child: Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final c
                    in _category == null
                        ? kEventColors
                        : [s.catById(_category)?.color ?? _color])
                  GestureDetector(
                    onTap: _category == null
                        ? () => setState(() => _color = c)
                        : null,
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
          if (_category == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: _MoreColorsToggle(
                quickColors: kEventColors,
                selected: _color,
                onChanged: (c) => setState(() => _color = c),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              'REMINDER',
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
            child: _chipRow(
              const [
                ('none', 'No reminder'),
                ('at', 'On time'),
                ('5m', '5 min before'),
                ('15m', '15 min before'),
                ('30m', '30 min before'),
                ('1h', '1 hour before'),
                ('2h', '2 hours before'),
                ('1d', '1 day before'),
                ('2d', '2 days before'),
              ],
              _reminder,
              (v) => setState(() => _reminder = v),
            ),
          ),
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
            child: _chipRow(
              const [
                ('none', 'Never'),
                ('daily', 'Daily'),
                ('weekly', 'Weekly'),
                ('monthly', 'Monthly'),
                ('yearly', 'Yearly'),
                ('custom', 'Custom'),
              ],
              _recur,
              (v) => setState(() {
                _recur = v;
                if (_recur != 'none') {
                  _multiDay = false;
                  if (_repeatEndDate.isNotEmpty &&
                      _repeatEndDate.compareTo(_date) < 0) {
                    _repeatEndDate = _date;
                  }
                } else {
                  _repeatEndDate = '';
                  if (!_multiDay) _endDate = _date;
                }
              }),
            ),
          ),
          if (_recur == 'custom') ...[
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
              child: _numberChipRow(
                const [1, 2, 3, 4, 5, 6],
                _recurEvery,
                (v) => setState(() => _recurEvery = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: _chipRow(
                const [
                  ('day', 'Days'),
                  ('week', 'Weeks'),
                  ('month', 'Months'),
                  ('year', 'Years'),
                ],
                _recurUnit,
                (v) => setState(() => _recurUnit = v),
              ),
            ),
            if (_recurUnit == 'week') ...[
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
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var weekday = 1; weekday <= 7; weekday++) ...[
                        GestureDetector(
                          key: ValueKey('event-custom-weekday-$weekday'),
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
                                color: _recurWeekdays.contains(weekday)
                                    ? B.deep
                                    : B.soft2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
          if (_recur != 'none')
            _sheetField(
              'Repeat ends',
              GestureDetector(
                key: const ValueKey('event-repeat-end-date'),
                onTap: _pickRepeatEndDate,
                child: Container(
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
                        _repeatEndDate.isEmpty
                            ? 'Never'
                            : _displayDateIso(_repeatEndDate),
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
            ),
          _sheetField(
            'Notes',
            _sheetInput(_notes, hint: 'Optional notes', maxLines: 3),
          ),
          if (_editing)
            GestureDetector(
              onTap: () {
                final ev = s.eventById(widget.event!.id);
                Navigator.of(context).pop();
                if (ev != null && ev.recur != 'none') {
                  s._showSheet(
                    (ctx) => _RecurDeleteSheet(
                      state: s,
                      eventId: ev.id,
                      date: _date,
                    ),
                  );
                } else {
                  s.askDelete(
                    _title.text,
                    'This event will be permanently removed.',
                    () => s.deleteEvent(widget.event!.id, 'all'),
                  );
                }
              },
              child: const Padding(
                padding: EdgeInsets.fromLTRB(0, 13, 0, 2),
                child: Text(
                  'Delete event',
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
          ),
        ),
      ],
    );
  }
}

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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: cat.color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  categoryGlyph(cat, size: 15, iconColor: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    cat.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
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

/// "Calendars & categories" — categories + imported calendars management,
/// ported from `sheetCalManage()`. Replaces the #160/#161 placeholder.
class _CalendarManageSheet extends StatefulWidget {
  const _CalendarManageSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_CalendarManageSheet> createState() => _CalendarManageSheetState();
}

class _CalendarManageSheetState extends State<_CalendarManageSheet> {
  final Set<String> _syncing = {};

  Future<void> _sync(ImportedCalendar c) async {
    if (_syncing.contains(c.id)) return;
    setState(() => _syncing.add(c.id));
    final err = await widget.state.refreshImport(c.id);
    if (!mounted) return;
    setState(() => _syncing.remove(c.id));
    if (err != null) widget.state.showError(err);
  }

  Widget _importFieldChip({
    required String key,
    required String label,
    required bool on,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: ValueKey(key),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: on ? B.soft : Colors.white,
          border: Border.all(color: on ? B.primary : B.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ic(
              on ? 'check' : 'x',
              size: 9,
              sw: 2.8,
              color: on ? B.primary : B.muted,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: on ? B.primary : B.muted,
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
    final cats = s.eventCategories;
    final imps = s.importedCalendars;
    final members = s.curFamily()?.members ?? const <FamilyMember>[];

    Widget markedRow({
      required Key key,
      required Key markerKey,
      required Color color,
      required Widget child,
    }) {
      return Container(
        key: key,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: B.line),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(key: markerKey, width: 4, color: color),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: child,
            ),
          ],
        ),
      );
    }

    Widget catRow(EventCategory c) {
      final inner = GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
          s.openCategory(c);
        },
        behavior: HitTestBehavior.opaque,
        child: markedRow(
          key: ValueKey('cat-style-${c.id}'),
          markerKey: ValueKey('cat-marker-${c.id}'),
          color: c.color,
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: categoryGlyph(c, size: 32, iconColor: Colors.white),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: B.ink,
                      ),
                    ),
                    Text(
                      c.members.isEmpty
                          ? 'No one assigned'
                          : '${c.members.length} member${c.members.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: B.soft2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      return _SwipeRow(
        key: ValueKey('cat-${c.id}'),
        open: s.swipedId == 'cat-${c.id}',
        onOpenChanged: (o) =>
            s.update(() => s.swipedId = o ? 'cat-${c.id}' : null),
        onDelete: () => s.askDelete(
          c.name,
          'Events keep their times but lose this category.',
          () {
            s.deleteCategory(c.id);
            setState(() {});
          },
        ),
        borderRadius: 13,
        child: inner,
      );
    }

    Widget impRow(ImportedCalendar c) {
      final providerLabel = kImportProviders[c.provider]?.$1 ?? c.provider;
      final category = s.catById(c.category);
      final rowColor = category?.color ?? c.color;
      final eventLabel =
          '${c.events.length} event${c.events.length == 1 ? '' : 's'}';
      final inner = GestureDetector(
        key: ValueKey('imp-edit-${c.id}'),
        onTap: () {
          Navigator.of(context).pop();
          s.openEditImportCalendarSheet(c);
        },
        behavior: HitTestBehavior.opaque,
        child: markedRow(
          key: ValueKey('imp-style-${c.id}'),
          markerKey: ValueKey('imp-marker-${c.id}'),
          color: rowColor,
          child: Row(
            children: [
              Container(
                key: ValueKey('imp-visual-${c.id}'),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rowColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: category == null
                    ? Center(
                        child: ic(
                          'download',
                          size: 16,
                          sw: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : categoryGlyph(
                        category,
                        size: 32,
                        iconColor: Colors.white,
                      ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: B.ink,
                      ),
                    ),
                    Text(
                      '${category == null ? '' : '${category.name} · '}'
                      '$providerLabel · $eventLabel',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: B.soft2,
                      ),
                    ),
                    if (c.url != null && c.url!.isNotEmpty)
                      GestureDetector(
                        key: ValueKey('imp-autosync-${c.id}'),
                        onTap: () {
                          s.toggleImportAutoSync(c.id);
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ic(
                                c.autoSync ? 'check' : 'x',
                                size: 11,
                                sw: 2.6,
                                color: c.autoSync ? B.primary : B.muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                c.autoSync
                                    ? 'Auto-syncs on open'
                                    : 'Auto-sync off',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.autoSync ? B.primary : B.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (c.url != null && c.url!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _importFieldChip(
                              key: 'imp-loc-${c.id}',
                              label: 'Location',
                              on: c.includeLocation,
                              onTap: () {
                                s.toggleImportField(c.id, location: true);
                                setState(() {});
                              },
                            ),
                            _importFieldChip(
                              key: 'imp-desc-${c.id}',
                              label: 'Description',
                              on: c.includeDescription,
                              onTap: () {
                                s.toggleImportField(c.id, location: false);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                key: ValueKey('imp-settings-${c.id}'),
                onTap: () {
                  Navigator.of(context).pop();
                  s.openEditImportCalendarSheet(c);
                },
                child: Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: B.line),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: ic('edit', size: 16, sw: 2.2, color: B.deep),
                  ),
                ),
              ),
              if (c.url != null && c.url!.isNotEmpty) ...[
                GestureDetector(
                  key: ValueKey('imp-sync-${c.id}'),
                  onTap: _syncing.contains(c.id) ? null : () => _sync(c),
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: B.line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: _syncing.contains(c.id)
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: B.deep,
                              ),
                            )
                          : ic('repeat', size: 16, sw: 2.2, color: B.deep),
                    ),
                  ),
                ),
              ],
              GestureDetector(
                key: ValueKey('imp-toggle-${c.id}'),
                onTap: () {
                  s.toggleImportVisible(c.id);
                  setState(() {});
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c.visible ? B.soft : Colors.white,
                    border: Border.all(color: B.line),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: ic(
                      c.visible ? 'eye' : 'eyeoff',
                      size: 16,
                      sw: 2.2,
                      color: c.visible ? B.deep : B.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return _SwipeRow(
        key: ValueKey('imp-${c.id}'),
        open: s.swipedId == 'imp-${c.id}',
        onOpenChanged: (o) =>
            s.update(() => s.swipedId = o ? 'imp-${c.id}' : null),
        onDelete: () => s.askDelete(
          c.name,
          'This imported calendar and its events will be removed.',
          () {
            s.deleteImport(c.id);
            setState(() {});
          },
        ),
        borderRadius: 13,
        child: inner,
      );
    }

    Widget memberColourRow(FamilyMember m) {
      return Container(
        key: ValueKey('cal-member-colour-${m.id}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: B.line),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          children: [
            Row(
              children: [
                s._memberAvatar(m.id, size: 28),
                const SizedBox(width: 10),
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
              ],
            ),
            const SizedBox(height: 9),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (
                    var colorIndex = 0;
                    colorIndex < kCatColors.length;
                    colorIndex++
                  ) ...[
                    Builder(
                      builder: (_) {
                        final color = kCatColors[colorIndex];
                        final blocked = !s.isCalendarIdentityColorAvailable(
                          color,
                          exceptMemberId: m.id,
                        );
                        return GestureDetector(
                          key: ValueKey(
                            'cal-member-colour-${m.id}-$colorIndex',
                          ),
                          onTap: blocked
                              ? null
                              : () {
                                  s.setMemberColor(m.id, color);
                                  setState(() {});
                                },
                          child: Opacity(
                            opacity: blocked ? .28 : 1,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: m.color == color
                                      ? B.ink
                                      : Colors.white,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x140f172a),
                                    blurRadius: 5,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: blocked
                                  ? Center(
                                      child: ic(
                                        'x',
                                        size: 11,
                                        sw: 2.8,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 9),
            _MoreColorsToggle(
              quickColors: kCatColors,
              selected: m.color,
              onChanged: (color) {
                if (!s.isCalendarIdentityColorAvailable(
                  color,
                  exceptMemberId: m.id,
                )) {
                  return;
                }
                s.setMemberColor(m.id, color);
                setState(() {});
              },
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(
            context,
            'Calendars & categories',
            'Colours, icons & imports',
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 9),
            child: Text(
              'CATEGORIES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: Color(0xff64748b),
              ),
            ),
          ),
          if (cats.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'No categories yet.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: B.muted,
                ),
              ),
            )
          else
            for (final c in cats)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: catRow(c),
              ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _addButtonForSheet('New category', () {
              Navigator.of(context).pop();
              s.openCategory(null);
            }),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 20, bottom: 9),
            child: Text(
              'FAMILY MEMBER COLOURS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: Color(0xff64748b),
              ),
            ),
          ),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'No members yet.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: B.muted,
                ),
              ),
            )
          else
            for (final m in members) memberColourRow(m),
          const Padding(
            padding: EdgeInsets.only(top: 20, bottom: 9),
            child: Text(
              'IMPORTED CALENDARS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: Color(0xff64748b),
              ),
            ),
          ),
          if (imps.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'Nothing imported yet.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: B.muted,
                ),
              ),
            )
          else
            for (final c in imps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: impRow(c),
              ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _addButtonForSheet('Import a calendar', () {
              Navigator.of(context).pop();
              s.openImportCalendarSheet();
            }, icon: 'download'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ic('cleft', size: 13, sw: 2.4, color: B.muted),
                const SizedBox(width: 6),
                const Text(
                  'Swipe left to delete',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: B.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addButtonForSheet(
    String label,
    VoidCallback onTap, {
    String icon = 'plus',
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: B.line, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ic(icon, size: 15, sw: 2.4, color: B.primary),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: B.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "New category" / "Edit category" sheet, ported from `sheetCategory()`.
class _CategorySheet extends StatefulWidget {
  const _CategorySheet({required this.state, this.category});
  final _ThriveHomeState state;
  final EventCategory? category;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _name;
  late Color _color;
  late String _icon;
  String? _emoji;
  String? _picture;
  late List<String> _members;

  bool get _editing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _name = TextEditingController(text: c?.name ?? '');
    _color =
        c?.color ??
        widget.state.firstAvailableCalendarIdentityColor(
          fallback: kCatColors.first,
        );
    _icon = c?.icon ?? kCatIconsList.first;
    _emoji = c?.emoji;
    _picture = c?.picture;
    _members = (c?.members ?? const <String>[]).toList();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final members = s.curFamily()?.members ?? const <FamilyMember>[];
    final valid = _name.text.trim().isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(context, _editing ? 'Edit category' : 'New category'),
          _sheetField(
            'Name',
            _sheetInput(
              _name,
              hint: 'e.g. Work',
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              'COLOUR',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: B.muted,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final c in kCatColors)
                  Builder(
                    builder: (_) {
                      final blocked = !s.isCalendarIdentityColorAvailable(
                        c,
                        exceptCategoryId: widget.category?.id,
                      );
                      return GestureDetector(
                        key: ValueKey('cat-colour-${c.toARGB32()}'),
                        onTap: blocked
                            ? null
                            : () => setState(() => _color = c),
                        child: Opacity(
                          opacity: blocked ? .28 : 1,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(10),
                              border: _color == c
                                  ? Border.all(color: B.ink, width: 2)
                                  : null,
                            ),
                            child: blocked
                                ? Center(
                                    child: ic(
                                      'x',
                                      size: 13,
                                      sw: 2.6,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _MoreColorsToggle(
              quickColors: kCatColors,
              selected: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
          ),
          _sheetField(
            'Emoji or picture',
            _GlyphPicker(
              emoji: _emoji,
              picture: _picture,
              onChanged: ({String? emoji, String? picture}) {
                _emoji = emoji;
                _picture = picture;
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              'ASSIGNED PEOPLE',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: B.muted,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in members)
                  GestureDetector(
                    key: ValueKey('cat-member-${m.id}'),
                    onTap: () => setState(() {
                      if (_members.contains(m.id)) {
                        _members.remove(m.id);
                      } else {
                        _members.add(m.id);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(5, 5, 11, 5),
                      decoration: BoxDecoration(
                        color: _members.contains(m.id) ? B.soft : Colors.white,
                        border: Border.all(
                          color: _members.contains(m.id) ? B.primary : B.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          s.avatarNode(
                            photo: m.photo,
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
                              color: _members.contains(m.id) ? B.deep : B.soft2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _primaryBtn(_editing ? 'Save category' : 'Add category', () {
            s.saveCategory(
              id: widget.category?.id,
              name: _name.text,
              color: _color,
              icon: _icon,
              emoji: _emoji,
              picture: _picture,
              members: _members,
            );
            Navigator.of(context).pop();
            s.openCalendarManageSheet();
          }, enabled: valid),
          if (_editing)
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                s.askDelete(
                  _name.text,
                  'Events keep their times but lose this category.',
                  () {
                    s.deleteCategory(widget.category!.id);
                    s.openCalendarManageSheet();
                  },
                );
              },
              child: const Padding(
                padding: EdgeInsets.fromLTRB(0, 13, 0, 2),
                child: Text(
                  'Delete category',
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

/// "Import a calendar" sheet, ported from `sheetImportCal()`.
class _ImportCalendarSheet extends StatefulWidget {
  const _ImportCalendarSheet({required this.state, this.calendar});
  final _ThriveHomeState state;
  final ImportedCalendar? calendar;

  @override
  State<_ImportCalendarSheet> createState() => _ImportCalendarSheetState();
}

class _ImportCalendarSheetState extends State<_ImportCalendarSheet> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  String? _category;
  late Color _color;
  late bool _visible;
  bool _busy = false;
  bool _autoSync = true;
  bool _includeLocation = true;
  bool _includeDescription = true;

  bool get _editing => widget.calendar != null;

  @override
  void initState() {
    super.initState();
    final cal = widget.calendar;
    _name = TextEditingController(text: cal?.name ?? '');
    _url = TextEditingController(text: cal?.url ?? '');
    _category = cal?.category;
    _color = cal?.color ?? kImportProviders['ics']!.$2;
    _visible = cal?.visible ?? true;
    _autoSync = cal?.autoSync ?? true;
    _includeLocation = cal?.includeLocation ?? true;
    _includeDescription = cal?.includeDescription ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final s = widget.state;
    setState(() => _busy = true);
    final err = _editing
        ? await s.updateImport(
            id: widget.calendar!.id,
            name: _name.text,
            category: _category,
            color: _color,
            visible: _visible,
            url: _url.text,
            autoSync: _autoSync,
            includeLocation: _includeLocation,
            includeDescription: _includeDescription,
          )
        : await s.saveImport(
            name: _name.text,
            category: _category,
            color: _color,
            url: _url.text,
            autoSync: _autoSync,
            includeLocation: _includeLocation,
            includeDescription: _includeDescription,
          );
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop();
      s.openCalendarManageSheet();
      return;
    }
    setState(() => _busy = false);
    s.showError(err);
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: B.line),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: B.soft2,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: B.primary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final cats = s.eventCategories;
    final valid = _url.text.trim().isNotEmpty;
    final category = s.catById(_category);
    final displayColor = category?.color ?? _color;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(
            context,
            _editing ? 'Edit imported calendar' : 'Import a calendar',
            _editing
                ? 'Update this calendar subscription'
                : 'Bring in an external ICS calendar link',
          ),
          _sheetField(
            'Calendar URL',
            _sheetInput(
              _url,
              hint: 'https://…/calendar.ics',
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _toggleRow(
              title: 'Keep it updated automatically',
              subtitle: 'Re-syncs this link whenever you open the app',
              value: _autoSync,
              onChanged: (v) => setState(() => _autoSync = v),
            ),
          ),
          if (_editing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _toggleRow(
                title: 'Show this calendar',
                subtitle: 'Display its imported events in the calendar',
                value: _visible,
                onChanged: (v) => setState(() => _visible = v),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _toggleRow(
              title: 'Import location',
              subtitle: 'e.g. a match venue or event address',
              value: _includeLocation,
              onChanged: (v) => setState(() => _includeLocation = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: _toggleRow(
              title: 'Import description',
              subtitle: 'e.g. a competition name or extra feed details',
              value: _includeDescription,
              onChanged: (v) => setState(() => _includeDescription = v),
            ),
          ),
          _sheetField(
            'Name (optional)',
            _sheetInput(
              _name,
              hint: 'e.g. Kids · School',
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              'ASSIGN A CATEGORY (OPTIONAL)',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: B.muted,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _category = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _category == null ? B.soft : Colors.white,
                      border: Border.all(
                        color: _category == null ? B.primary : B.line,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'None',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _category == null ? B.deep : B.soft2,
                      ),
                    ),
                  ),
                ),
                for (final c in cats)
                  GestureDetector(
                    onTap: () => setState(() => _category = c.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _category == c.id ? c.color : Colors.white,
                        border: Border.all(
                          color: _category == c.id ? c.color : B.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          categoryGlyph(
                            c,
                            size: 14,
                            iconColor: _category == c.id
                                ? Colors.white
                                : c.color,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            c.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _category == c.id ? Colors.white : B.soft2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_category == null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                'COLOUR',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .3,
                  color: B.muted,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final color in kCatColors)
                    GestureDetector(
                      key: ValueKey('imp-colour-${color.toARGB32()}'),
                      onTap: () => setState(() => _color = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                          border: displayColor == color
                              ? Border.all(color: B.ink, width: 2)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: _MoreColorsToggle(
                quickColors: kCatColors,
                selected: displayColor,
                onChanged: (color) => setState(() => _color = color),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Text(
                '${category?.name ?? 'The category'} controls this calendar colour.',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: B.muted,
                  height: 1.5,
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'Imported events are read-only and shown with a download tag.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: B.muted,
                height: 1.5,
              ),
            ),
          ),
          _primaryBtn(
            _busy
                ? (_editing ? 'Saving…' : 'Importing…')
                : (_editing ? 'Save calendar' : 'Import calendar'),
            _busy ? null : _submit,
            enabled: valid && !_busy,
          ),
        ],
      ),
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

/// Week picker used by Week/Family calendar views. It browses one month at a
/// time and jumps `calAnchor` to the selected week's Monday.
class _CalWeekPickerSheet extends StatefulWidget {
  const _CalWeekPickerSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_CalWeekPickerSheet> createState() => _CalWeekPickerSheetState();
}

class _CalWeekPickerSheetState extends State<_CalWeekPickerSheet> {
  late String _monthAnchor;

  @override
  void initState() {
    super.initState();
    final current = _parseIso(widget.state.calAnchor);
    _monthAnchor = _isoOf(current.year, current.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final month = _parseIso(_monthAnchor);
    final monthStart = _isoOf(month.year, month.month, 1);
    final monthEnd = _isoOf(month.year, month.month + 1, 0);
    final selectedWeek = _startOfWeekIso(s.calAnchor);
    final thisWeek = _startOfWeekIso(todayIso());
    final weeks = <String>[];
    var cursor = _startOfWeekIso(monthStart);
    while (cursor.compareTo(monthEnd) <= 0) {
      weeks.add(cursor);
      cursor = _addDaysIso(cursor, 7);
    }

    Widget monthBtn(String icon, int delta) {
      return GestureDetector(
        key: ValueKey('cal-week-month-$icon'),
        onTap: () =>
            setState(() => _monthAnchor = _addMonthsIso(_monthAnchor, delta)),
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

    Widget weekRow(String weekStart) {
      final weekEnd = _addDaysIso(weekStart, 6);
      final selected = weekStart == selectedWeek;
      final current = weekStart == thisWeek;
      return GestureDetector(
        key: ValueKey('cal-pick-week-$weekStart'),
        onTap: () {
          s.update(() {
            s.calAnchor = weekStart;
            s.calSel = weekStart;
            s.calWeekTimelineCentered = false;
          });
          Navigator.of(context).pop();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? B.primary : Colors.white,
            border: Border.all(color: selected ? B.primary : B.line),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_shortDateIso(weekStart)} – ${_shortDateIso(weekEnd)}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : B.ink,
                  ),
                ),
              ),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: .18)
                        : B.soft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'This week',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : B.deep,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHead(context, 'Jump to a week'),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              monthBtn('cleft', -1),
              Expanded(
                child: Text(
                  _monthTitleIso(_monthAnchor),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: B.ink,
                  ),
                ),
              ),
              monthBtn('cright', 1),
            ],
          ),
        ),
        for (final weekStart in weeks) weekRow(weekStart),
        const SizedBox(height: 10),
        _primaryBtn('Jump to this week', () {
          s.calToday();
          s.update(() => s.calWeekTimelineCentered = false);
          Navigator.of(context).pop();
        }),
      ],
    );
  }
}

/// View-switcher sheet — Month/Week/Family/Agenda, ported from `viewSheet()`.
class _ViewPickerSheet extends StatelessWidget {
  const _ViewPickerSheet({required this.state});
  final _ThriveHomeState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHead(context, 'View'),
        for (final (value, label, icon) in kCalViews)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Builder(
              builder: (_) {
                final on = state.calView == value;
                return GestureDetector(
                  key: ValueKey('cal-view-$value'),
                  onTap: () {
                    state.setCalView(value);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
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
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: on ? B.deep : B.ink,
                            ),
                          ),
                        ),
                        if (on)
                          ic('check', size: 19, sw: 2.6, color: B.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
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
                _chip(
                  key: ValueKey('cal-filter-cat-${c.id}'),
                  leading: categoryGlyph(c, size: 15, iconColor: c.color),
                  label: c.name,
                  on: s.calCatFilter.contains(c.id),
                  color: c.color,
                  onTap: () => setState(() => s.toggleCalCategoryFilter(c.id)),
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
class _DayDetailSheet extends StatelessWidget {
  const _DayDetailSheet({required this.state, required this.iso});
  final _ThriveHomeState state;
  final String iso;

  @override
  Widget build(BuildContext context) {
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
                state._eventCard(o),
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
