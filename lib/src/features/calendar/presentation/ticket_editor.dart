part of 'package:family_money_management_app/main.dart';

/// The event editor (design "Event & finance editors" 1a): a scroll of
/// labelled white cards — one card per decision, chips instead of dropdowns,
/// delete at the very end — above which a pinned "How it will look" strip
/// paints the draft with the calendar's own month, agenda and kitchen
/// builders. Same anatomy as the category editor and the import studio.
///
/// It replaces the WYSIWYG ticket: colour and layer are still judged from a
/// live preview, but nothing is hidden behind a tray any more.

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
  /// Opens the event editor — the single event-editing surface.
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
  late bool _birthday;
  late bool _done;
  bool _endManuallySet = false;

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
    _birthday = e?.birthday ?? false;
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
    allDay: _allDay || _birthday,
    birthday: _birthday,
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
      allDay: _allDay || _birthday,
      birthday: _birthday,
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
      doneDates: widget.event == null ? null : Map.of(widget.event!.doneDates),
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

  // ------------------------------------------------------------- preview

  /// The draft as a throwaway event, so the preview can paint it with the
  /// SAME builders the calendar uses. Never saved, never added to `events` —
  /// its id is deliberately unlike any real one so the strip can't collide
  /// with the grid behind the sheet.
  CalendarEvent _previewEvent() => CalendarEvent(
    id: 'editor-preview',
    title: _title.text.trim().isEmpty
        ? (_titlePlaceholder())
        : _title.text.trim(),
    allDay: _allDay || _birthday,
    birthday: _birthday,
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
    layerId: _layerId,
    todo: _todo,
    done: _todo && _done,
  );

  String _titlePlaceholder() => _todo ? 'Your to-do' : 'Your event';

  /// The pinned "How it will look" strip: the real month bar, agenda row and
  /// kitchen pill, rebuilt on every tap below. It is the only thing the
  /// design pins, because colour, layer and kind are the choices you can't
  /// judge from their own control.
  Widget _previewStrip() {
    final o = CalendarOccurrence(ev: _previewEvent(), date: _date);
    final day = _parseIso(_date).day;
    return Container(
      key: const ValueKey('event-editor-preview'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          studioSectionLabel(
            'How it will look',
            padding: const EdgeInsets.only(bottom: 8),
          ),
          // The strip mirrors the calendar; it is never a way INTO it.
          IgnorePointer(
            child: Column(
              children: [
                _previewRow(
                  'Month',
                  Container(
                    width: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xffdfe5ee)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.only(top: 2, bottom: 3),
                    child: Column(
                      children: [
                        Text(
                          '$day',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: B.ink,
                          ),
                        ),
                        s._calMonthBar(o, _date),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _previewRow(
                  'Agenda',
                  s._evRowFull(o, rowKeyPrefix: 'event-editor-preview-agenda'),
                ),
                const SizedBox(height: 8),
                _previewRow(
                  'Kitchen',
                  s._evPill(o, keyPrefix: 'event-editor-preview-pill'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, Widget child) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Color(0xffb3bcc9),
            ),
          ),
        ),
        Flexible(child: child),
      ],
    );
  }

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
        // A to-do carries a done state; the ticket used to preview it with a
        // checkbox on the card. With the ticket gone it lives here, next to
        // the switch that made it a to-do, and the preview strip above still
        // shows what done looks like.
        if (_todo) ...[
          const SizedBox(height: 4),
          studioToggleRow(
            key: const ValueKey('event-done'),
            label: 'Already done',
            sub: 'Ticks it off the moment you save',
            value: _done,
            onChanged: () => setState(() => _done = !_done),
            boxed: false,
          ),
        ],
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
            const SizedBox(width: 7),
            // Birthdays/anniversaries are their own display kind on every
            // calendar surface (#339) — cream + cake, never a time.
            KeyedSubtree(
              key: const ValueKey('event-kind-birthday'),
              child: _chip(null, 'Birthday', _birthday, () {
                setState(() {
                  _birthday = !_birthday;
                  if (_birthday) _allDay = true;
                });
              }),
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
            s.openNewCategoryStudio(layerId: _layerId);
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
                "The event takes the category's colour",
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

  /// One labelled white card in the editor's scroll — the design's shape,
  /// the same one the category editor and the import studio already use.
  Widget _card(String id, String title, Widget child) => KeyedSubtree(
    key: ValueKey('event-card-$id'),
    child: studioCard(title: title, children: [child]),
  );

  String get _categoryCardTitle {
    final layer = s.calendarLayers
        .where((l) => l.id == _layerId)
        .firstOrNull
        ?.label;
    return layer == null ? 'Category' : 'Category · $layer';
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
          sub: _editing
              ? 'One card per decision'
              : 'One card per decision — nothing hidden',
          onConfirm: _submit,
          confirmEnabled: valid,
        ),
        // The preview is pinned above the scroll: it answers every tap made
        // below it, so it has to stay on screen while you make them.
        _previewStrip(),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                studioTextField(
                  key: const ValueKey('event-title'),
                  controller: _title,
                  hint: _todo ? 'What needs doing?' : 'What is it?',
                  onChanged: (_) => setState(() {}),
                  capitalization: TextCapitalization.sentences,
                ),
                _card('kind', 'Kind & layer', _trayKind()),
                _card('category', _categoryCardTitle, _trayCategory()),
                _card('when', 'When', _trayWhen()),
                _card('repeat', 'Repeat', _trayRepeat()),
                _card('reminder', 'Reminder', _trayReminder()),
                _card('people', 'People', _trayPeople()),
                _card(
                  'colour',
                  s.catById(_category) != null
                      ? 'Colour (from category)'
                      : 'Colour',
                  _trayColour(),
                ),
                _card('place', 'Place & notes', _trayPlace()),
                if (_editing)
                  GestureDetector(
                    key: const ValueKey('ticket-delete'),
                    onTap: _delete,
                    child: Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 6),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xfffecaca)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _todo ? 'Delete to-do' : 'Delete event',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
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
