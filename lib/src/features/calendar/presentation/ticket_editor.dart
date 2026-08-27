part of 'package:family_money_management_app/main.dart';

/// The ticket event editor (epic: replace `_EventEditSheet`), mirroring
/// `Add event options.dc.html` option 2d with the Repeat/Reminder
/// interaction from option 2a of `Repeat & reminder options.dc.html`
/// (docs/design/): the editor's top half IS the event — a WYSIWYG ticket
/// card — and one tray below edits whichever ticket element was tapped.

const List<String> _kTicketTrays = [
  'kind',
  'when',
  'category',
  'people',
  'colour',
  'reminder',
  'repeat',
  'place',
];

/// Plain-language repeat summary (#267) — the same phrase month/agenda rows
/// render, so the tray's summary and the calendar always agree.
String repeatPhrase(CalendarEvent ev) {
  const weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const nthNames = ['first', 'second', 'third', 'fourth', 'last'];
  String days(List<int> ds) {
    final names = [for (final d in ds) weekdayNames[d - 1]];
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    return '${names.sublist(0, names.length - 1).join(', ')} & ${names.last}';
  }

  switch (ev.recur) {
    case 'none':
      return 'Happens once';
    case 'daily':
      return 'Repeats every day';
    case 'weekly':
      return 'Repeats every week';
    case 'monthly':
      if (ev.monthlyMode == 'nthWeekday') {
        return 'Repeats every ${nthNames[ev.monthlyNth.clamp(1, 5) - 1]} '
            '${weekdayNames[ev.monthlyWeekday.clamp(1, 7) - 1]}';
      }
      return 'Repeats every month on the same date';
    case 'yearly':
      return 'Repeats every year';
    case 'custom':
      final every = ev.recurEvery < 1 ? 1 : ev.recurEvery;
      if (ev.recurUnit == 'week') {
        final on = days(_customRepeatWeekdays(ev));
        final base = every == 1 ? 'every week' : 'every $every weeks';
        return 'Repeats $base${on.isEmpty ? '' : ' on $on'}';
      }
      final unit = switch (ev.recurUnit) {
        'day' => every == 1 ? 'day' : 'days',
        'month' => every == 1 ? 'month' : 'months',
        'year' => every == 1 ? 'year' : 'years',
        _ => 'weeks',
      };
      return 'Repeats every ${every == 1 ? unit : '$every $unit'}';
  }
  return 'Happens once';
}

/// When the reminder will ring for [ev] (#268): "Rings 17:00 · Fri 28-08",
/// or "Rings the evening before" for all-day events.
String reminderRingLine(CalendarEvent ev) {
  if (ev.reminder == 'none') return '';
  if (ev.allDay || ev.start.isEmpty) return 'Rings the evening before';
  final parts = ev.start.split(':');
  final date = _parseIso(ev.date);
  var at = DateTime(
    date.year,
    date.month,
    date.day,
    int.tryParse(parts.elementAtOrNull(0) ?? '') ?? 9,
    int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0,
  );
  at = at.subtract(switch (ev.reminder) {
    'at' => Duration.zero,
    '5m' => const Duration(minutes: 5),
    '15m' => const Duration(minutes: 15),
    '30m' => const Duration(minutes: 30),
    '1h' => const Duration(hours: 1),
    '2h' => const Duration(hours: 2),
    '1d' => const Duration(days: 1),
    '2d' => const Duration(days: 2),
    _ => Duration.zero,
  });
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String two(int v) => v.toString().padLeft(2, '0');
  return 'Rings ${two(at.hour)}:${two(at.minute)} · ${wd[at.weekday - 1]} '
      '${two(at.day)}-${two(at.month)}';
}

extension _ThriveTicketEditor on _ThriveHomeState {
  /// Opens the ticket editor (#270 — the single event-editing surface).
  void openTicketEditor(CalendarEvent? ev, [String? date]) {
    _showSheet(
      (ctx) => _TicketEditorSheet(state: this, event: ev, date: date ?? calSel),
    );
  }
}

class _TicketEditorSheet extends StatefulWidget {
  const _TicketEditorSheet({
    required this.state,
    required this.date,
    this.event,
  });
  final _ThriveHomeState state;
  final String date;
  final CalendarEvent? event;

  @override
  State<_TicketEditorSheet> createState() => _TicketEditorSheetState();
}

class _TicketEditorSheetState extends State<_TicketEditorSheet> {
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
  late String _monthlyMode;
  late int _monthlyNth;
  late int _monthlyWeekday;
  late String _layerId;
  late bool _todo;
  late bool _done;
  bool _endManuallySet = false;

  String _tray = 'kind';

  bool get _editing => widget.event != null;

  _ThriveHomeState get s => widget.state;

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
    _attendees = widget.event == null
        ? <String>[]
        : (e?.attendees ?? const <String>[]).toList();
    _reminder = e?.reminder ?? '1h';
    _recurEvery = e?.recurEvery ?? 1;
    _recurUnit = e?.recurUnit ?? 'week';
    _recurWeekdays = (e?.recurWeekdays ?? const <int>[]).toList();
    if (_recurWeekdays.isEmpty) _recurWeekdays = [_parseIso(_date).weekday];
    _monthlyMode = e?.monthlyMode ?? 'date';
    _monthlyNth = e?.monthlyNth ?? 1;
    _monthlyWeekday = e?.monthlyWeekday ?? _parseIso(_date).weekday;
    _layerId = e?.layerId ?? kLayerAppt;
    _todo = e?.todo ?? false;
    _done = e?.isDoneOn(widget.date) ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ helpers

  Color get _effColor => s.catById(_category)?.color ?? _color;

  void _openTray(String tray) {
    if (!_kTicketTrays.contains(tray) || _tray == tray) return;
    setState(() => _tray = tray);
    logAnalyticsEvent('ticket_tray_opened', {'tray': tray});
  }

  /// Coupling rule (#266): a layer change clears foreign-layer categories.
  void _setLayerId(String layerId) {
    _layerId = layerId;
    if (_category != null && s.catById(_category)?.layerId != layerId) {
      _category = null;
    }
  }

  /// The repeat state as a throwaway event, for summary/badge phrasing.
  CalendarEvent _draft() => CalendarEvent(
    id: widget.event?.id ?? 'draft',
    title: _title.text,
    allDay: _allDay,
    date: _date,
    start: _allDay ? '' : _start,
    end: _allDay ? '' : _end,
    color: _effColor,
    reminder: _reminder,
    recur: _recur,
    recurEvery: _recurEvery,
    recurUnit: _recurUnit,
    recurWeekdays: _recurWeekdays,
    monthlyMode: _monthlyMode,
    monthlyNth: _monthlyNth,
    monthlyWeekday: _monthlyWeekday,
  );

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
      // Coupling (#266): date moves clamp multi-day end and repeat-ends.
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
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.elementAtOrNull(0) ?? '') ?? 9,
        minute: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0,
      ),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isStart) {
        _start = formatted;
        // Coupling (#266): start auto-sets end +1h on new events until the
        // end is touched.
        if (!_editing && !_endManuallySet) {
          _end = defaultCalendarEndTimeForStart(formatted);
        }
      } else {
        _end = formatted;
        _endManuallySet = true;
      }
    });
  }

  void _submit() {
    final edited = CalendarEvent(
      id: widget.event?.id ?? uid(),
      title: _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim(),
      allDay: _allDay,
      date: _date,
      endDate: _recur != 'none' ? _repeatEndDate : (_multiDay ? _endDate : ''),
      start: _allDay ? '' : _start,
      end: _allDay ? '' : _end,
      location: _location.text.trim(),
      notes: _notes.text.trim(),
      category: _category,
      color: _effColor,
      attendees: _attendees,
      reminder: _reminder,
      recur: _recur,
      recurEvery: _recurEvery,
      recurUnit: _recurUnit,
      recurWeekdays: _recurWeekdays,
      monthlyMode: _recur == 'monthly' ? _monthlyMode : 'date',
      monthlyNth: _monthlyNth,
      monthlyWeekday: _monthlyWeekday,
      exceptions: widget.event?.exceptions,
      createdBy: widget.event?.createdBy,
      layerId: _layerId,
      todo: _todo,
      done: _todo && _recur == 'none' ? _done : (widget.event?.done ?? false),
      doneDates: widget.event?.doneDates,
    );
    if (_todo && _recur != 'none' && widget.event != null) {
      edited.doneDates[widget.date] = _done;
    }
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
      monthlyMode: edited.monthlyMode,
      monthlyNth: edited.monthlyNth,
      monthlyWeekday: edited.monthlyWeekday,
      exceptions: widget.event?.exceptions,
      createdBy: widget.event?.createdBy,
      layerId: edited.layerId,
      todo: edited.todo,
      done: edited.done,
      doneDates: edited.doneDates,
    );
    Navigator.of(context).pop();
  }

  void _delete() {
    final ev = widget.event == null ? null : s.eventById(widget.event!.id);
    Navigator.of(context).pop();
    if (ev == null) return;
    if (ev.recur != 'none') {
      s._showSheet(
        (ctx) => _RecurDeleteSheet(state: s, eventId: ev.id, date: _date),
      );
    } else {
      s.askDelete(
        _title.text,
        'This event will be permanently removed.',
        () => s.deleteEvent(ev.id, 'all'),
      );
    }
  }

  // -------------------------------------------------------------- ticket

  /// The when-line as the design writes it: date · times / all day / span.
  String _whenLine() {
    final day = _displayDateIso(_date);
    if (_recur == 'none' && _multiDay && _endDate != _date) {
      return '$day → ${_displayDateIso(_endDate)}';
    }
    if (_allDay) return '$day · all day';
    return '$day · $_start – $_end';
  }

  Widget _badge(
    Key key,
    String icon,
    String label,
    Color fg,
    Color bg,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ic(icon, size: 13, sw: 2.4, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The WYSIWYG ticket (#263) — every element opens its tray. To-dos
  /// transform to the paper card (#265).
  Widget _ticket() {
    final cat = s.catById(_category);
    final col = _effColor;
    final paper = _todo;
    final fg = paper ? B.ink : contrastOn(col);
    final soft = paper ? B.soft2 : fg.withValues(alpha: .85);
    final layer = s.calendarLayers.where((l) => l.id == _layerId).firstOrNull;
    final badgeBg = paper ? B.faint : fg.withValues(alpha: .16);
    final badgeFg = paper ? B.soft2 : fg;
    final members = s.curFamily()?.members ?? const <FamilyMember>[];
    final attending = [
      for (final m in members)
        if (_attendees.contains(m.id)) m,
    ];

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Layer tab (top-left) + repeat/reminder badges (top-right).
        Row(
          children: [
            _badge(
              const ValueKey('ticket-tab-layer'),
              layer?.icon ?? 'cal',
              (layer?.label ?? 'Appointments').toUpperCase(),
              badgeFg,
              badgeBg,
              () => _openTray('kind'),
            ),
            const Spacer(),
            _badge(
              const ValueKey('ticket-badge-repeat'),
              'repeat',
              _recur == 'none' ? 'ONCE' : 'REPEATS',
              badgeFg,
              badgeBg,
              () => _openTray('repeat'),
            ),
            const SizedBox(width: 6),
            _badge(
              const ValueKey('ticket-badge-reminder'),
              'bell',
              _reminder == 'none'
                  ? 'NO DING'
                  : calendarReminderLabel(_reminder).toUpperCase(),
              badgeFg,
              badgeBg,
              () => _openTray('reminder'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Title, typed directly on the card (#263); to-dos get the live
        // checkbox previewing done (#265).
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (paper)
              GestureDetector(
                key: const ValueKey('ticket-check'),
                onTap: () => setState(() => _done = !_done),
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: _done ? col : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _done ? col : const Color(0xffcdd5df),
                      width: 2,
                    ),
                  ),
                  child: _done
                      ? Center(
                          child: ic(
                            'check',
                            size: 15,
                            sw: 3,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
            Expanded(
              child: TextField(
                controller: _title,
                onChanged: (_) => setState(() {}),
                maxLines: 2,
                minLines: 1,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                  color: fg,
                  decoration: paper && _done
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: fg,
                ),
                cursorColor: fg,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: paper ? 'What needs doing?' : 'Give it a name',
                  hintStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                    color: soft.withValues(alpha: .6),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // When-line.
        GestureDetector(
          key: const ValueKey('ticket-when'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _openTray('when'),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                ic('clock', size: 14, sw: 2.3, color: soft),
                const SizedBox(width: 6),
                Text(
                  _whenLine(),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: soft,
                  ),
                ),
              ],
            ),
          ),
        ),
        // People + category + colour row.
        Row(
          children: [
            GestureDetector(
              key: const ValueKey('ticket-people'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _openTray('people'),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                alignment: Alignment.centerLeft,
                child: attending.isEmpty
                    ? Text(
                        'Who\'s going?',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: soft,
                        ),
                      )
                    : SizedBox(
                        height: 26,
                        width: 18.0 * attending.length + 8,
                        child: Stack(
                          children: [
                            for (final (i, m) in attending.indexed)
                              Positioned(
                                left: 18.0 * i,
                                child: s.avatarNode(
                                  photo: m.photo,
                                  emoji: m.emoji,
                                  initials: m.initials,
                                  color: m.color,
                                  size: 26,
                                  radius: 13,
                                  fs: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
            const Spacer(),
            _badge(
              const ValueKey('ticket-category'),
              cat != null ? cat.icon : 'tag',
              cat?.name.toUpperCase() ?? 'NO CATEGORY',
              badgeFg,
              badgeBg,
              () => _openTray('category'),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              key: const ValueKey('ticket-colour'),
              onTap: () => _openTray('colour'),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: paper ? B.line : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Perforated stub (#263): dashed rule, place/notes line, mark.
        SizedBox(
          height: 14,
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                for (var i = 0; i < (constraints.maxWidth / 9).floor(); i++)
                  Container(
                    width: 5,
                    height: 2,
                    margin: const EdgeInsets.only(right: 4),
                    color: paper
                        ? const Color(0xffd8dee7)
                        : fg.withValues(alpha: .35),
                  ),
              ],
            ),
          ),
        ),
        GestureDetector(
          key: const ValueKey('ticket-place'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _openTray('place'),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                ic('mappin', size: 13, sw: 2.3, color: soft),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                          if (_location.text.trim().isNotEmpty)
                            _location.text.trim(),
                          if (_notes.text.trim().isNotEmpty) _notes.text.trim(),
                        ].join(' · ').isEmpty
                        ? 'Add a place or a note'
                        : [
                            if (_location.text.trim().isNotEmpty)
                              _location.text.trim(),
                            if (_notes.text.trim().isNotEmpty)
                              _notes.text.trim(),
                          ].join(' · '),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: soft,
                    ),
                  ),
                ),
                Text(
                  paper ? 'TO-DO' : 'THRIVE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: soft.withValues(alpha: .7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (paper) {
      // The to-do "paper card" (#265): off-white, dashed outline, colour
      // spine on the left.
      return Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 14, 14, 8),
            decoration: BoxDecoration(
              color: const Color(0xfffdfcf7),
              borderRadius: BorderRadius.circular(18),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xffd8dee7), width: 2),
            ),
            child: body,
          ),
          Positioned(
            left: 0,
            top: 10,
            bottom: 10,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: col,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: col,
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [col, Color.lerp(col, const Color(0xff0f172a), .22)!],
        ),
        boxShadow: cardShadow(),
      ),
      child: body,
    );
  }

  // --------------------------------------------------------------- trays

  Widget _chip(
    Key? key,
    String label,
    bool on,
    VoidCallback onTap, {
    Color? onColor,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? (onColor ?? B.soft) : Colors.white,
          border: Border.all(color: on ? (onColor ?? B.primary) : B.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: on
                ? (onColor != null ? contrastOn(onColor) : B.deep)
                : B.text,
          ),
        ),
      ),
    );
  }

  Widget _trayKind() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                key: const ValueKey('event-kind-event'),
                onTap: () => setState(() => _todo = false),
                child: _kindTile('cal', 'Event', !_todo),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                key: const ValueKey('event-kind-todo'),
                onTap: () => setState(() => _todo = true),
                child: _kindTile('check', 'To-do', _todo),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'LAYER',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
            color: B.muted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final layer in s.calendarLayers)
              _chip(
                ValueKey('event-layer-${layer.id}'),
                layer.label,
                _layerId == layer.id,
                () => setState(() => _setLayerId(layer.id)),
                onColor: _layerId == layer.id ? layer.color : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _kindTile(String icon, String label, bool on) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? B.primary : Colors.white,
        border: Border.all(color: on ? B.primary : B.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ic(icon, size: 16, sw: 2.3, color: on ? Colors.white : B.soft2),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: on ? Colors.white : B.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(Key? key, String label, String value, VoidCallback onTap) {
    return _sheetField(
      label,
      GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border.all(color: B.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ic('cal', size: 15, sw: 2.2, color: B.primary),
              const SizedBox(width: 8),
              Text(
                value,
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
    );
  }

  Widget _trayWhen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggleRow(
          'All-day',
          _allDay,
          () => setState(() => _allDay = !_allDay),
          activeColor: B.primary,
        ),
        const SizedBox(height: 12),
        _dateField(null, 'Date', _displayDateIso(_date), _pickDate),
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
          const SizedBox(height: 12),
          if (_multiDay)
            _dateField(null, 'Ends', _displayDateIso(_endDate), _pickEndDate),
        ] else
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Multi-day is off while the event repeats',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: B.muted,
              ),
            ),
          ),
        if (!_allDay)
          Row(
            children: [
              Expanded(
                child: _sheetField(
                  'Start',
                  GestureDetector(
                    key: const ValueKey('event-time-start'),
                    onTap: () => _pickTime(true),
                    child: _timeBox(_start),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _sheetField(
                  'End',
                  GestureDetector(
                    key: const ValueKey('event-time-end'),
                    onTap: () => _pickTime(false),
                    child: _timeBox(_end),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _timeBox(String value) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: 13),
    alignment: Alignment.centerLeft,
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
  );

  Widget _trayCategory() {
    final categories = s.eventCategories
        .where((c) => c.layerId == _layerId)
        .toList();
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _chip(null, 'None', _category == null, () {
          setState(() => _category = null);
        }),
        for (final c in categories)
          _chip(
            ValueKey('event-cat-${c.id}'),
            c.name,
            _category == c.id,
            () {
              setState(() {
                // Coupling (#266): category sets colour + replaces attendees
                // with the category's members (even if that's nobody).
                _category = c.id;
                _color = c.color;
                _attendees = c.members.toList();
              });
            },
            onColor: _category == c.id ? c.color : null,
          ),
        GestureDetector(
          key: const ValueKey('event-new-category'),
          onTap: () {
            Navigator.of(context).pop();
            s.openCategory(null, layerId: _layerId);
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: B.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ic('plus', size: 13, sw: 2.5, color: B.primary),
                const SizedBox(width: 4),
                const Text(
                  'New',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: B.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _trayPeople() {
    final members = s.curFamily()?.members ?? const <FamilyMember>[];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in members)
          GestureDetector(
            key: ValueKey('event-att-${m.id}'),
            onTap: () => setState(() {
              _attendees.contains(m.id)
                  ? _attendees.remove(m.id)
                  : _attendees.add(m.id);
            }),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
              decoration: BoxDecoration(
                color: _attendees.contains(m.id) ? B.soft : Colors.white,
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
                    emoji: m.emoji,
                    initials: m.initials,
                    color: m.color,
                    size: 26,
                    radius: 13,
                    fs: 10,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    m.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _attendees.contains(m.id) ? B.deep : B.soft2,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _trayColour() {
    final cat = s.catById(_category);
    if (cat != null) {
      // Coupling (#266): the colour tray shows a locked swatch when the
      // category owns the colour.
      return Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cat.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: ic(
                'lock',
                size: 16,
                sw: 2.3,
                color: contrastOn(cat.color),
              ),
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'Colour comes from the category',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: B.soft2,
              ),
            ),
          ),
        ],
      );
    }
    return _MoreColorsToggle(
      quickColors: kEventColors,
      selected: _color,
      onChanged: (c) => setState(() => _color = c),
    );
  }

  Widget _yesNo(
    Key noKey,
    Key yesKey,
    String noLabel,
    String yesLabel,
    bool yes,
    ValueChanged<bool> onPick,
  ) {
    return Row(
      children: [
        Expanded(child: _chip(noKey, noLabel, !yes, () => onPick(false))),
        const SizedBox(width: 8),
        Expanded(child: _chip(yesKey, yesLabel, yes, () => onPick(true))),
      ],
    );
  }

  /// Repeat tray (#267) — design 2a: "Does it happen again?" first.
  Widget _trayRepeat() {
    final repeats = _recur != 'none';
    final weekly =
        _recur == 'weekly' || (_recur == 'custom' && _recurUnit == 'week');
    final monthly = _recur == 'monthly';
    final interval = _recur == 'custom' && _recurUnit == 'week'
        ? _recurEvery
        : 1;
    void setWeekly(int every) {
      setState(() {
        if (every == 1 &&
            _recurWeekdays.length == 1 &&
            _recurWeekdays.single == _parseIso(_date).weekday) {
          _recur = 'weekly';
        } else {
          // Interval > 1 (or multiple days) saves as custom · week · N.
          _recur = 'custom';
          _recurUnit = 'week';
          _recurEvery = every;
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Does it happen again?',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: B.ink,
          ),
        ),
        const SizedBox(height: 8),
        _yesNo(
          const ValueKey('ticket-again-no'),
          const ValueKey('ticket-again-yes'),
          'No, just once',
          'Yes, it repeats',
          repeats,
          (yes) => setState(() {
            if (!yes) {
              _recur = 'none';
              // Coupling (#266): back to Never clears repeat-ends.
              _repeatEndDate = '';
              if (!_multiDay) _endDate = _date;
            } else {
              _recur = 'weekly';
              _recurWeekdays = [_parseIso(_date).weekday];
              // Coupling (#266): repeating disables multi-day.
              _multiDay = false;
              if (_repeatEndDate.isNotEmpty &&
                  _repeatEndDate.compareTo(_date) < 0) {
                _repeatEndDate = _date;
              }
            }
          }),
        ),
        if (repeats) ...[
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                const ValueKey('ticket-cad-daily'),
                'Every day',
                _recur == 'daily',
                () => setState(() => _recur = 'daily'),
              ),
              _chip(
                const ValueKey('ticket-cad-weekly'),
                'Every week',
                weekly,
                () => setWeekly(1),
              ),
              _chip(
                const ValueKey('ticket-cad-monthly'),
                'Every month',
                monthly,
                () => setState(() => _recur = 'monthly'),
              ),
              _chip(
                const ValueKey('ticket-cad-yearly'),
                'Every year',
                _recur == 'yearly',
                () => setState(() => _recur = 'yearly'),
              ),
            ],
          ),
          if (weekly) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (var weekday = 1; weekday <= 7; weekday++)
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
                      setWeekly(interval);
                    }),
                    child: _dayCircle(
                      kWeekdayLetters[weekday - 1],
                      _recurWeekdays.contains(weekday),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in const [1, 2, 3, 4])
                  _chip(
                    ValueKey('event-custom-every-$n'),
                    n == 1 ? 'Every week' : 'Every $n weeks',
                    interval == n,
                    () => setWeekly(n),
                  ),
              ],
            ),
          ],
          if (monthly) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(
                  const ValueKey('ticket-month-date'),
                  'Same date (the ${_parseIso(_date).day}th)',
                  _monthlyMode == 'date',
                  () => setState(() => _monthlyMode = 'date'),
                ),
                _chip(
                  const ValueKey('ticket-month-nth'),
                  'Same weekday (e.g. first Monday)',
                  _monthlyMode == 'nthWeekday',
                  () => setState(() => _monthlyMode = 'nthWeekday'),
                ),
              ],
            ),
            if (_monthlyMode == 'nthWeekday') ...[
              const SizedBox(height: 9),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (n, label) in const [
                    (1, 'First'),
                    (2, 'Second'),
                    (3, 'Third'),
                    (4, 'Fourth'),
                    (5, 'Last'),
                  ])
                    _chip(
                      ValueKey('ticket-nth-$n'),
                      label,
                      _monthlyNth == n,
                      () => setState(() => _monthlyNth = n),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (var weekday = 1; weekday <= 7; weekday++)
                    GestureDetector(
                      key: ValueKey('ticket-nthday-$weekday'),
                      onTap: () => setState(() => _monthlyWeekday = weekday),
                      child: _dayCircle(
                        kWeekdayLetters[weekday - 1],
                        _monthlyWeekday == weekday,
                      ),
                    ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 9),
          _dateField(
            const ValueKey('event-repeat-end-date'),
            'Repeat ends',
            _repeatEndDate.isEmpty ? 'Never' : _displayDateIso(_repeatEndDate),
            _pickRepeatEndDate,
          ),
        ],
        Container(
          key: const ValueKey('ticket-repeat-summary'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: B.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            repeatPhrase(_draft()),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: B.deep,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayCircle(String label, bool on) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? B.soft : Colors.white,
        border: Border.all(color: on ? B.primary : B.line),
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: on ? B.deep : B.soft2,
        ),
      ),
    );
  }

  /// Reminder tray (#268) — design 2a: "Want a heads-up?" first.
  Widget _trayReminder() {
    final remind = _reminder != 'none';
    final ring = reminderRingLine(_draft());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Want a heads-up?',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: B.ink,
          ),
        ),
        const SizedBox(height: 8),
        _yesNo(
          const ValueKey('ticket-rem-no'),
          const ValueKey('ticket-rem-yes'),
          'No thanks',
          'Yes, remind us',
          remind,
          (yes) => setState(() => _reminder = yes ? '1h' : 'none'),
        ),
        if (remind) ...[
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (v, label) in const [
                ('at', 'On time'),
                ('5m', '5 min before'),
                ('15m', '15 min before'),
                ('30m', '30 min before'),
                ('1h', '1 hour before'),
                ('2h', '2 hours before'),
                ('1d', '1 day before'),
                ('2d', '2 days before'),
              ])
                _chip(
                  ValueKey('ticket-rem-$v'),
                  label,
                  _reminder == v,
                  () => setState(() => _reminder = v),
                ),
            ],
          ),
          if (ring.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                ring,
                key: const ValueKey('ticket-ring-line'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: B.deep,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _trayPlace() {
    return Column(
      children: [
        _sheetField(
          'Location',
          _sheetInput(
            _location,
            hint: 'Optional',
            onChanged: (_) => setState(() {}),
          ),
        ),
        _sheetField(
          'Notes',
          _sheetInput(
            _notes,
            hint: 'Optional notes',
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _tray_() {
    final child = switch (_tray) {
      'when' => _trayWhen(),
      'category' => _trayCategory(),
      'people' => _trayPeople(),
      'colour' => _trayColour(),
      'reminder' => _trayReminder(),
      'repeat' => _trayRepeat(),
      'place' => _trayPlace(),
      _ => _trayKind(),
    };
    const titles = {
      'kind': 'Kind & layer',
      'when': 'When',
      'category': 'Category',
      'people': 'People',
      'colour': 'Colour',
      'reminder': 'Reminder',
      'repeat': 'Repeat',
      'place': 'Place & notes',
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: B.page,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titles[_tray]!.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
              color: B.muted,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = _title.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHeadWithTick(
          context,
          _editing ? 'Edit event' : 'New event',
          sub: _editing ? null : 'Tap the ticket to shape it',
          onConfirm: _submit,
          confirmEnabled: valid,
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ticket(),
                _tray_(),
                if (_editing)
                  GestureDetector(
                    key: const ValueKey('ticket-delete'),
                    onTap: _delete,
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(0, 14, 0, 2),
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
