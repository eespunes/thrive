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
    final picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (ctx) => _TimeInputDialog(
        title: isStart ? 'Start time' : 'End time',
        initial: TimeOfDay(
          hour: int.tryParse(parts.elementAtOrNull(0) ?? '') ?? 9,
          minute: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0,
        ),
      ),
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
    final day = _fmtDay(_date);
    if (_recur == 'none' && _multiDay && _endDate != _date) {
      return '$day → ${_fmtDay(_endDate)}';
    }
    if (_allDay) return '$day · all day';
    return '$day · $_start–$_end';
  }

  /// A small ticket badge, per the design's `tBadge`: radius 8, no icon.
  /// The 44px hit area wraps a visually compact pill.
  Widget _badge(Key key, String label, Color fg, Color bg, VoidCallback onTap) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  /// The layer tab, per the design's `tKindTabStyle`: a bordered pill whose
  /// border lights up while its tray is open; on to-dos it takes the ticket
  /// colour.
  Widget _layerPill(String label, bool paper, Color col, Color fg) {
    final border = paper
        ? col
        : (_tray == 'kind' ? fg : fg.withValues(alpha: .45));
    return GestureDetector(
      key: const ValueKey('ticket-tab-layer'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openTray('kind'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          decoration: BoxDecoration(
            color: paper
                ? col.withValues(alpha: .12)
                : fg.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: paper ? col : fg,
            ),
          ),
        ),
      ),
    );
  }

  /// The design's day stamp: "Thu 27-08".
  String _fmtDay(String iso) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final d = _parseIso(iso);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${wd[d.weekday - 1]} ${two(d.day)}-${two(d.month)}';
  }

  /// The repeat badge's wording, per the design: "Once", "Weekly on
  /// Thursday", or the repeat phrase without its "Repeats " prefix.
  String _repeatBadgeLabel() {
    if (_recur == 'none') return 'Once';
    if (_recur == 'weekly') {
      const names = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return 'Weekly on ${names[_parseIso(_date).weekday - 1]}';
    }
    final phrase = repeatPhrase(_draft()).replaceFirst('Repeats ', '');
    return phrase[0].toUpperCase() + phrase.substring(1);
  }

  /// The reminder badge's wording, per the design: "Remind 1h".
  String _reminderBadgeLabel() {
    if (_reminder == 'none') return 'No reminder';
    if (_reminder == 'at') return 'Remind on time';
    return 'Remind $_reminder';
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
    final badgeBg = paper ? B.faint : fg.withValues(alpha: .18);
    final badgeFg = paper ? B.soft2 : fg;
    final members = s.curFamily()?.members ?? const <FamilyMember>[];
    final attending = [
      for (final m in members)
        if (_attendees.contains(m.id)) m,
    ];

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(paper ? 26 : 16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Layer tab (top-left) + repeat/reminder badges (top-right).
              Row(
                children: [
                  _layerPill(
                    '${paper ? 'To-do · ' : ''}${layer?.label ?? 'Appointments'}',
                    paper,
                    col,
                    fg,
                  ),
                  const Spacer(),
                  Flexible(
                    child: _badge(
                      const ValueKey('ticket-badge-repeat'),
                      _repeatBadgeLabel(),
                      badgeFg,
                      badgeBg,
                      () => _openTray('repeat'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: _badge(
                      const ValueKey('ticket-badge-reminder'),
                      _reminderBadgeLabel(),
                      badgeFg,
                      badgeBg,
                      () => _openTray('reminder'),
                    ),
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
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: _done ? col : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: col, width: 2.5),
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
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      minLines: 1,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                        color: paper && _done ? fg.withValues(alpha: .55) : fg,
                        decoration: paper && _done
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: fg,
                      ),
                      cursorColor: fg,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: paper
                            ? 'What needs doing?'
                            : 'Tap to name it…',
                        hintStyle: TextStyle(
                          fontSize: 21,
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
                  child: Text(
                    '${_whenLine()} · tap to change',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: soft,
                    ),
                  ),
                ),
              ),
              // People + category + colour row.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: GestureDetector(
                      key: const ValueKey('ticket-people'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openTray('people'),
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: 44,
                          minWidth: 44,
                        ),
                        alignment: Alignment.centerLeft,
                        child: attending.isEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Nobody yet · tap to invite',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: badgeFg,
                                  ),
                                ),
                              )
                            : SizedBox(
                                height: 32,
                                width: 20.0 * attending.length + 12,
                                child: Stack(
                                  children: [
                                    for (final (i, m) in attending.indexed)
                                      Positioned(
                                        left: 20.0 * i,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: .8,
                                              ),
                                              width: 2,
                                            ),
                                          ),
                                          child: s.avatarNode(
                                            photo: m.photo,
                                            emoji: m.emoji,
                                            initials: m.initials,
                                            color: m.color,
                                            size: 28,
                                            radius: 14,
                                            fs: 10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _badge(
                      const ValueKey('ticket-category'),
                      cat?.name ?? 'No category',
                      badgeFg,
                      badgeBg,
                      () => _openTray('category'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    key: const ValueKey('ticket-colour'),
                    onTap: () => _openTray('colour'),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      // The design's rainbow dot: a picker affordance, not the
                      // current colour (the whole ticket already shows that).
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: paper ? col : Colors.white,
                            width: 2.5,
                          ),
                          gradient: const SweepGradient(
                            colors: [
                              Color(0xff7c3aed),
                              Color(0xff0f9d6a),
                              Color(0xffd97706),
                              Color(0xffe11d48),
                              Color(0xff7c3aed),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Perforated stub (#263): full-bleed dashed rule, place/notes, mark.
        Padding(
          padding: const EdgeInsets.only(top: 13),
          child: SizedBox(
            height: 2,
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  for (var i = 0; i < (constraints.maxWidth / 9).floor(); i++)
                    Container(
                      width: 5,
                      height: 2,
                      margin: const EdgeInsets.only(right: 4),
                      color: paper
                          ? const Color(0xffe2ded0)
                          : fg.withValues(alpha: .35),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(paper ? 26 : 16, 0, 16, 6),
          child: GestureDetector(
            key: const ValueKey('ticket-place'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _openTray('place'),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                            if (_location.text.trim().isNotEmpty)
                              _location.text.trim(),
                            if (_notes.text.trim().isNotEmpty)
                              _notes.text.trim(),
                          ].join(' · ').isEmpty
                          ? 'Add a place or notes'
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
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: paper
                          ? col.withValues(alpha: .9)
                          : fg.withValues(alpha: .6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (paper) {
      // The to-do "paper card" (#265): off-white, dashed outline in the
      // ticket colour, solid colour spine on the left.
      return Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xfffffdf6),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x800f172a),
                  offset: Offset(0, 16),
                  blurRadius: 34,
                  spreadRadius: -24,
                ),
              ],
            ),
            child: body,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DashedRectPainter(color: col, radius: 20, inset: 1),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: col,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
            ),
          ),
        ],
      );
    }
    // The event ticket: the colour under a soft 150° light-to-shade wash,
    // floating on its own colour's shadow (the design's `tTicketStyle`).
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: .16), col),
            Color.alphaBlend(
              const Color(0xff0f172a).withValues(alpha: .14),
              col,
            ),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: col.withValues(alpha: .6),
            offset: const Offset(0, 20),
            blurRadius: 40,
            spreadRadius: -22,
          ),
        ],
      ),
      child: body,
    );
  }

  // --------------------------------------------------------------- trays

  /// A tray chip, per the design's `chip(on, color)`: a pill that fills
  /// solid (teal, or [onColor]) when selected. The 44px hit area wraps a
  /// visually compact pill.
  Widget _chip(
    Key? key,
    String label,
    bool on,
    VoidCallback onTap, {
    Color? onColor,
  }) {
    final fill = onColor ?? B.primary;
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // Vertical padding pads the hit area to ~44px without letting the
      // pill expand to the Wrap's full width.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? fill : Colors.white,
            border: Border.all(color: on ? fill : B.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: on ? contrastOn(fill) : B.soft2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _trayKind() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The design's segmented control: grey track, white active segment.
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xffe8ecf2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _kindSegment(
                  const ValueKey('event-kind-event'),
                  'Event',
                  !_todo,
                  () => setState(() => _todo = false),
                ),
              ),
              Expanded(
                child: _kindSegment(
                  const ValueKey('event-kind-todo'),
                  'To-do',
                  _todo,
                  () => setState(() => _todo = true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final layer in s.calendarLayers)
              _layerChip(
                ValueKey('event-layer-${layer.id}'),
                layer.label,
                layer.color,
                _layerId == layer.id,
                () => setState(() => _setLayerId(layer.id)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _kindSegment(Key key, String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: on
              ? const [
                  BoxShadow(
                    color: Color(0x1f101828),
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: on ? B.primary : const Color(0xff8995a6),
          ),
        ),
      ),
    );
  }

  /// A layer chip, per the design: a pill with the layer's colour dot,
  /// tinted in the layer colour while selected.
  Widget _layerChip(
    Key key,
    String label,
    Color color,
    bool on,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: .12) : Colors.white,
            border: Border.all(color: on ? color : B.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: on ? color : B.soft2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A grey input-look box, per the design's date/time inputs.
  Widget _whenBox(
    Key? key,
    String value,
    VoidCallback onTap, {
    bool white = false,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: white ? Colors.white : B.page,
          border: Border.all(color: B.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: B.ink,
          ),
        ),
      ),
    );
  }

  /// The design's small track toggle (42×25, teal when on).
  Widget _trackToggle(bool on, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 42,
          height: 25,
          padding: const EdgeInsets.all(2.5),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: on ? B.primary : const Color(0xffcfd6df),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _trayWhen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date · start · end · All-day, on one line per the design.
        Row(
          children: [
            Expanded(
              flex: 7,
              child: _whenBox(null, _displayDateIso(_date), _pickDate),
            ),
            if (!_allDay) ...[
              const SizedBox(width: 7),
              Expanded(
                flex: 4,
                child: _whenBox(
                  const ValueKey('event-time-start'),
                  _start,
                  () => _pickTime(true),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                flex: 4,
                child: _whenBox(
                  const ValueKey('event-time-end'),
                  _end,
                  () => _pickTime(false),
                ),
              ),
            ],
            const SizedBox(width: 7),
            _chip(
              null,
              'All-day',
              _allDay,
              () => setState(() => _allDay = !_allDay),
            ),
          ],
        ),
        const SizedBox(height: 9),
        if (_recur == 'none')
          // The design's Multi-day box: label, end date, track toggle. The
          // whole row toggles, not just the track.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              _multiDay = !_multiDay;
              if (!_multiDay) _endDate = _date;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: B.page,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Multi-day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: B.text,
                      ),
                    ),
                  ),
                  if (_multiDay) ...[
                    _whenBox(
                      null,
                      _displayDateIso(_endDate),
                      _pickEndDate,
                      white: true,
                    ),
                    const SizedBox(width: 10),
                  ],
                  _trackToggle(
                    _multiDay,
                    () => setState(() {
                      _multiDay = !_multiDay;
                      if (!_multiDay) _endDate = _date;
                    }),
                  ),
                ],
              ),
            ),
          )
        else
          const Text(
            'Multi-day is off while the event repeats',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: B.muted,
            ),
          ),
      ],
    );
  }

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
          _chip(ValueKey('event-cat-${c.id}'), c.name, _category == c.id, () {
            setState(() {
              // Coupling (#266): category sets colour + replaces attendees
              // with the category's members (even if that's nobody).
              _category = c.id;
              _color = c.color;
              _attendees = c.members.toList();
            });
          }, onColor: _category == c.id ? c.color : null),
        GestureDetector(
          key: const ValueKey('event-new-category'),
          onTap: () {
            Navigator.of(context).pop();
            s.openCategory(null, layerId: _layerId);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: CustomPaint(
                painter: const _DashedRectPainter(
                  color: Color(0xffcfd8e3),
                  radius: 13,
                  inset: -6,
                ),
                child: const Text(
                  '+ New',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: B.primary,
                  ),
                ),
              ),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 11, 4),
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
                      size: 22,
                      radius: 11,
                      fs: 8,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      m.name,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _attendees.contains(m.id) ? B.deep : B.soft2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _trayColour() {
    final cat = s.catById(_category);
    if (cat != null) {
      // Coupling (#266): the colour tray shows a locked swatch in a grey box
      // when the category owns the colour.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: B.page,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: cat.color,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                "The ticket takes the category's colour",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: B.soft2,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _ColorPickerPanel(
      selected: _color,
      onChanged: (c) => setState(() => _color = c),
    );
  }

  /// The design's `bigBtn`: a full-width bordered button pair.
  Widget _bigBtn(Key key, String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: on ? B.soft : Colors.white,
          border: Border.all(color: on ? B.primary : B.line, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: on ? B.deep : B.soft2,
          ),
        ),
      ),
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
        Expanded(child: _bigBtn(noKey, noLabel, !yes, () => onPick(false))),
        const SizedBox(width: 8),
        Expanded(child: _bigBtn(yesKey, yesLabel, yes, () => onPick(true))),
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
          // Ends row, per the design: label · date box · hint.
          Row(
            children: [
              const Text(
                'Ends',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: B.text,
                ),
              ),
              const SizedBox(width: 9),
              _whenBox(
                const ValueKey('event-repeat-end-date'),
                _repeatEndDate.isEmpty
                    ? 'Never'
                    : _displayDateIso(_repeatEndDate),
                _pickRepeatEndDate,
              ),
              if (_repeatEndDate.isEmpty) ...[
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Never, unless set',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: B.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
        ],
        Container(
          key: const ValueKey('ticket-repeat-summary'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: B.page,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            repeatPhrase(_draft()),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: B.soft2,
            ),
          ),
        ),
      ],
    );
  }

  /// A weekday circle, per the design: small, solid teal when selected,
  /// centred in a 44px hit area.
  Widget _dayCircle(String label, bool on) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? B.primary : Colors.white,
          border: Border.all(color: on ? B.primary : B.line),
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: on ? Colors.white : B.soft2,
          ),
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
                ('5m', '5 min'),
                ('15m', '15 min'),
                ('30m', '30 min'),
                ('1h', '1 hour'),
                ('2h', '2 hours'),
                ('1d', '1 day'),
                ('2d', '2 days'),
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
              child: Container(
                key: const ValueKey('ticket-ring-line'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: B.page,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ring,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: B.soft2,
                  ),
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
    final layerLabel = s.calendarLayers
        .where((l) => l.id == _layerId)
        .firstOrNull
        ?.label;
    final titles = {
      'kind': 'Kind & layer',
      'when': 'When',
      'category': layerLabel == null ? 'Category' : 'Category · $layerLabel',
      'people': 'People',
      'colour': s.catById(_category) != null
          ? 'Colour (from category)'
          : 'Colour',
      'reminder': 'Reminder',
      'repeat': 'Repeat',
      'place': 'Place & notes',
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: B.line),
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
          _editing ? 'Edit the ticket' : 'New event',
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

/// Hour/minute entry dialog replacing the Material time picker's input mode:
/// tapping the hour or the minute selects its whole value, so typing digits
/// simply overwrites — no deleting first. Two digits in the hour auto-advance
/// to the minute; values clamp to 0–23 / 0–59.
class _TimeInputDialog extends StatefulWidget {
  const _TimeInputDialog({required this.title, required this.initial});
  final String title;
  final TimeOfDay initial;

  @override
  State<_TimeInputDialog> createState() => _TimeInputDialogState();
}

class _TimeInputDialogState extends State<_TimeInputDialog> {
  late final TextEditingController _hour;
  late final TextEditingController _minute;
  final FocusNode _hourFocus = FocusNode();
  final FocusNode _minuteFocus = FocusNode();

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    _hour = TextEditingController(text: _two(widget.initial.hour));
    _minute = TextEditingController(text: _two(widget.initial.minute));
    // Select-all whenever a field gains focus, so digits overwrite.
    _hourFocus.addListener(() {
      if (_hourFocus.hasFocus) _selectAll(_hour);
    });
    _minuteFocus.addListener(() {
      if (_minuteFocus.hasFocus) _selectAll(_minute);
    });
  }

  void _selectAll(TextEditingController c) {
    c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
  }

  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  int _clamped(TextEditingController c, int max) =>
      (int.tryParse(c.text) ?? 0).clamp(0, max);

  void _confirm() {
    Navigator.of(
      context,
    ).pop(TimeOfDay(hour: _clamped(_hour, 23), minute: _clamped(_minute, 59)));
  }

  Widget _digits(
    Key key,
    TextEditingController c,
    FocusNode focus,
    int max, {
    ValueChanged<String>? onChanged,
    bool autofocus = false,
  }) {
    return SizedBox(
      width: 76,
      child: TextField(
        key: key,
        controller: c,
        focusNode: focus,
        autofocus: autofocus,
        onTap: () => _selectAll(c),
        onChanged: onChanged,
        onSubmitted: (_) => _confirm(),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: B.ink,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: B.page,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: B.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: B.primary, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: B.ink,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _digits(
                  const ValueKey('time-input-hour'),
                  _hour,
                  _hourFocus,
                  23,
                  autofocus: true,
                  // Two digits typed → jump straight to the minute.
                  onChanged: (v) {
                    if (v.length == 2) _minuteFocus.requestFocus();
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: B.soft2,
                    ),
                  ),
                ),
                _digits(
                  const ValueKey('time-input-minute'),
                  _minute,
                  _minuteFocus,
                  59,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('time-input-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: B.soft2,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  key: const ValueKey('time-input-ok'),
                  onPressed: _confirm,
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: B.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
