part of 'package:family_money_management_app/main.dart';

/// The event editor (design "Event Editor v2"): Event/To-do switch pinned
/// under the header, then the name, category, when and who — the decisions
/// almost every event needs — and an Options group of folded rows (repeat,
/// reminder, location, notes, calendar & colour) for everything else.
/// Colour uses the shared Palette / RGB-Hex selector inside its Options row.

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
    openEditorSheet<void>(
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

  /// The open Options row (repeat/reminder/place/notes/colour), if any.
  String? _expanded;

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
    if (picked != null) _setDate(_isoOfDate(picked));
  }

  /// Moves the event to [iso]. Coupling (#266): a multi-day span keeps its
  /// length, repeat-ends clamp, and date-derived repeat patterns follow.
  void _setDate(String iso) => setState(() {
    final span = _multiDay
        ? _parseIso(_endDate).difference(_parseIso(_date)).inDays
        : 0;
    _date = iso;
    _endDate = _addDaysIso(iso, span < 0 ? 0 : span);
    if (_repeatEndDate.isNotEmpty && _repeatEndDate.compareTo(iso) < 0) {
      _repeatEndDate = iso;
    }
    final weekday = _parseIso(iso).weekday;
    _monthlyNth = _nthOf(iso);
    _monthlyWeekday = weekday;
    if (_recur != 'custom') _recurWeekdays = [weekday];
  });

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
        // Moving the start keeps the duration, like most calendars.
        final duration = _minutes(_end) - _minutes(_start);
        _start = formatted;
        _end = _hhmm(_minutes(formatted) + (duration < 15 ? 15 : duration));
      } else {
        // An end at or before the start snaps to 15 minutes after it.
        _end = _minutes(formatted) <= _minutes(_start)
            ? _hhmm(_minutes(_start) + 15)
            : formatted;
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

  // -------------------------------------------------------------- layout

  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _nthNames = ['first', 'second', 'third', 'fourth', 'last'];

  /// The nth-weekday slot [iso] falls in; days 29+ always count as "last".
  int _nthOf(String iso) {
    final d = _parseIso(iso).day;
    return d > 28 ? 5 : (d + 6) ~/ 7;
  }

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return '$n${switch (n % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    }}';
  }

  String _shortMonth(DateTime d) => kMonthsEn[d.month - 1].substring(0, 3);

  /// The Repeat row's read-back, in the design's "Every …" voice.
  String _repeatLabel() {
    final day = _parseIso(_date);
    switch (_recur) {
      case 'none':
        return "Doesn't repeat";
      case 'daily':
        return 'Every day';
      case 'weekly':
        return 'Every week on ${_weekdayNames[day.weekday - 1]}';
      case 'monthly':
        if (_monthlyMode == 'nthWeekday') {
          return 'Every ${_nthNames[_monthlyNth.clamp(1, 5) - 1]} '
              '${_weekdayNames[_monthlyWeekday.clamp(1, 7) - 1]} of the month';
        }
        return 'Every month on the ${_ordinal(day.day)}';
      case 'yearly':
        return 'Every year on ${day.day} ${_shortMonth(day)}';
    }
    final phrase = repeatPhrase(_draft());
    return phrase.startsWith('Repeats every')
        ? 'E${phrase.substring('Repeats e'.length)}'
        : phrase;
  }

  static int _minutes(String t) {
    final p = t.split(':');
    return (int.tryParse(p.first) ?? 0) * 60 +
        (int.tryParse(p.elementAtOrNull(1) ?? '') ?? 0);
  }

  static String _hhmm(int m) {
    final v = m.clamp(0, 23 * 60 + 59);
    return '${(v ~/ 60).toString().padLeft(2, '0')}:'
        '${(v % 60).toString().padLeft(2, '0')}';
  }

  Widget _caption(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: .4,
      color: context.tc.muted,
    ),
  );

  Widget _dot(Color color, {double size = 9}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  /// A white rounded button holding a date (multi-day end, repeat end).
  Widget _dateButton(Key key, String label, VoidCallback onTap) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.tc.surface,
          border: Border.all(color: context.tc.line, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: context.tc.ink,
          ),
        ),
      ),
    );
  }

  /// The design's small pill (durations, every-N-weeks): solid primary when
  /// selected.
  Widget _pill(Key? key, String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? context.tc.primary : context.tc.surface,
          border: Border.all(color: on ? context.tc.primary : context.tc.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : context.tc.soft2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _boxedField({
    required Key key,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    final style = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: context.tc.ink,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: context.tc.surface,
        border: Border.all(color: context.tc.line, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        key: key,
        controller: controller,
        minLines: maxLines,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
        textCapitalization: TextCapitalization.sentences,
        style: style,
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: style.copyWith(color: context.tc.placeholder),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- title

  Widget _titleRow() {
    final valid = _title.text.trim().isNotEmpty;
    final style = TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w800,
      letterSpacing: -.4,
      color: context.tc.ink,
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: valid ? _effColor : context.tc.line,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          _dot(_effColor, size: 14),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('event-title'),
              controller: _title,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              style: style,
              decoration: InputDecoration.collapsed(
                hintText: _todo ? 'What needs doing?' : 'What’s happening?',
                hintStyle: style.copyWith(color: context.tc.placeholder),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ category

  Widget _catChip({
    Key? key,
    required String label,
    required Color dot,
    required bool on,
    Color? tone,
    required VoidCallback onTap,
  }) {
    final bg = on ? (tone ?? context.tc.faint) : Colors.white;
    final bd = on ? (tone ?? context.tc.toggleOff) : context.tc.line;
    final fg = on
        ? (tone != null ? contrastOn(tone) : context.tc.ink)
        : context.tc.text;
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.fromLTRB(11, 0, 14, 0),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: bd, width: 1.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(on && tone != null ? Colors.white : dot),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChips() {
    final categories = s.eventCategories
        .where((c) => c.layerId == _layerId)
        .toList();
    final chips = <Widget>[
      _catChip(
        key: const ValueKey('event-cat-none'),
        label: 'None',
        dot: context.tc.toggleOff,
        on: _category == null,
        onTap: () => setState(() => _category = null),
      ),
      for (final c in categories)
        _catChip(
          key: ValueKey('event-cat-${c.id}'),
          label: c.name,
          dot: c.color,
          tone: c.color,
          on: _category == c.id,
          onTap: () => setState(() {
            if (_category == c.id) {
              _category = null;
              return;
            }
            // Coupling (#266): category sets colour + replaces attendees
            // with the category's members (even if that's nobody).
            _category = c.id;
            _color = c.color;
            _attendees = c.members.toList();
          }),
        ),
      edSoftChip(
        key: const ValueKey('event-new-category'),
        label: '+ New',
        small: true,
        selected: false,
        onTap: () {
          Navigator.of(context).pop();
          s.openNewCategoryStudio(layerId: _layerId);
        },
      ),
    ];
    // The row scrolls sideways and bleeds to the sheet's edges.
    return LayoutBuilder(
      builder: (context, c) => SizedBox(
        height: 44,
        child: OverflowBox(
          minWidth: c.maxWidth + 32,
          maxWidth: c.maxWidth + 32,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  chips[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- when

  Widget _dayChip(Key key, String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? context.tc.soft : context.tc.surface,
          border: Border.all(
            color: on ? context.tc.primary : context.tc.line,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: on ? context.tc.deep : context.tc.text,
          ),
        ),
      ),
    );
  }

  Widget _timeBox(Key key, String caption, String value, VoidCallback onTap) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.tc.page,
          border: Border.all(color: context.tc.line, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              caption,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: context.tc.muted,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.tc.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _when() {
    final allDay = _allDay || _birthday;
    final today = _isoOfDate(DateTime.now());
    final tomorrow = _addDaysIso(today, 1);
    final other = _date != today && _date != tomorrow;
    final duration = _minutes(_end) - _minutes(_start);
    final repeats = _recur != 'none';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 10,
              child: _dayChip(
                const ValueKey('event-date-today'),
                'Today',
                _date == today,
                () => _setDate(today),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              flex: 10,
              child: _dayChip(
                const ValueKey('event-date-tomorrow'),
                'Tomorrow',
                _date == tomorrow,
                () => _setDate(tomorrow),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              flex: 13,
              child: _dayChip(
                const ValueKey('event-date'),
                other ? _daySheetTitleIso(_date) : 'Pick a day…',
                other,
                _pickDate,
              ),
            ),
          ],
        ),
        if (!allDay) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _timeBox(
                  const ValueKey('event-time-start'),
                  'STARTS',
                  _start,
                  () => _pickTime(true),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '→',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: context.tc.placeholder,
                  ),
                ),
              ),
              Expanded(
                child: _timeBox(
                  const ValueKey('event-time-end'),
                  'ENDS',
                  _end,
                  () => _pickTime(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (m, label) in const [
                (30, '30 min'),
                (60, '1 hour'),
                (90, '1½ hours'),
                (120, '2 hours'),
              ])
                _pill(
                  ValueKey('event-duration-$m'),
                  label,
                  duration == m,
                  () => setState(() => _end = _hhmm(_minutes(_start) + m)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: context.tc.line, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              edToggleRow(
                key: const ValueKey('event-all-day'),
                label: 'All day',
                sub: 'No start or end time',
                value: allDay,
                boxed: false,
                onTap: () => setState(() {
                  if (allDay) {
                    _allDay = false;
                    _birthday = false;
                  } else {
                    _allDay = true;
                  }
                }),
              ),
              // Birthdays/anniversaries are their own display kind on every
              // calendar surface (#339) — cream + cake, never a time.
              if (allDay)
                edToggleRow(
                  key: const ValueKey('event-kind-birthday'),
                  label: 'Birthday or anniversary',
                  sub: 'Shows with a cake, every year',
                  value: _birthday,
                  boxed: false,
                  divider: true,
                  onTap: () => setState(() {
                    _birthday = !_birthday;
                    if (_birthday) {
                      _allDay = true;
                      _recur = 'yearly';
                      _multiDay = false;
                      _endDate = _date;
                    }
                  }),
                ),
              // Coupling (#266): repeating disables multi-day.
              Opacity(
                opacity: repeats ? .5 : 1,
                child: edToggleRow(
                  key: const ValueKey('event-multi-day'),
                  label: 'Multi-day',
                  sub: repeats
                      ? 'Off while the event repeats'
                      : 'Ends on a later day',
                  value: _multiDay && !repeats,
                  boxed: false,
                  divider: true,
                  onTap: repeats ? () {} : _toggleMultiDay,
                ),
              ),
              if (_multiDay && !repeats)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: context.tc.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Last day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.tc.ink,
                          ),
                        ),
                      ),
                      _dateButton(
                        const ValueKey('event-end-date'),
                        _daySheetTitleIso(_endDate),
                        _pickEndDate,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleMultiDay() => setState(() {
    _multiDay = !_multiDay;
    if (!_multiDay) _endDate = _date;
  });

  // -------------------------------------------------------------- people

  Widget _people() {
    final members = s.curFamily()?.members ?? const <FamilyMember>[];
    if (members.isEmpty) {
      return Text(
        'No family members yet',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: context.tc.muted,
        ),
      );
    }
    return edPeopleRow(
      members: members,
      selected: _attendees.toSet(),
      keyPrefix: 'event-att',
      avatar: s.editorAvatar,
      onToggle: (id) => setState(() {
        if (!_attendees.remove(id)) _attendees.add(id);
      }),
    );
  }

  // ------------------------------------------------------------- options

  /// One expandable row of the Options group. Only one row is open at a
  /// time; the whole row (header + body) keeps the `event-card-<id>` key.
  Widget _optionRow({
    required String id,
    required String icon,
    required String label,
    required String value,
    required bool set,
    required Widget Function() body,
    bool first = false,
    Key? valueKey,
  }) {
    final open = _expanded == id;
    return KeyedSubtree(
      key: ValueKey('event-card-$id'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: open ? context.tc.rowOpen : context.tc.surface,
          border: first
              ? null
              : Border(top: BorderSide(color: context.tc.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              key: ValueKey('event-row-$id'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = open ? null : id),
              child: Container(
                constraints: const BoxConstraints(minHeight: 54),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.tc.soft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ic(
                        icon,
                        size: 16,
                        sw: 2.1,
                        color: context.tc.deep,
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
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: context.tc.ink,
                            ),
                          ),
                          Text(
                            value,
                            key: valueKey,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: set
                                  ? context.tc.soft2
                                  : context.tc.placeholder,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? .5 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: ic(
                        'cdown',
                        size: 18,
                        sw: 2.4,
                        color: context.tc.placeholder,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (open)
              Padding(
                key: ValueKey('event-row-$id-open'),
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: body(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _radio(Key key, String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: on ? context.tc.soft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? context.tc.primary : context.tc.toggleOff,
                  width: 2,
                ),
              ),
              child: _dot(
                on ? context.tc.primary : Colors.transparent,
                size: 8,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.tc.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A weekday circle: solid primary when selected, in a 44px hit area.
  Widget _dayCircle(String label, bool on) {
    return SizedBox(
      width: 38,
      height: 44,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? context.tc.primary : context.tc.surface,
            border: Border.all(
              color: on ? context.tc.primary : context.tc.line,
            ),
            shape: BoxShape.circle,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : context.tc.soft2,
            ),
          ),
        ),
      ),
    );
  }

  /// Repeat (#267): one radio list of plain-language patterns.
  Widget _repeatBody() {
    final day = _parseIso(_date);
    final wd = day.weekday;
    final nthWeekday = _recur == 'monthly' && _monthlyMode == 'nthWeekday';
    final nth = nthWeekday ? _monthlyNth : _nthOf(_date);
    final nthDay = nthWeekday ? _monthlyWeekday : wd;
    final options = <(String, String, bool, VoidCallback)>[
      (
        'ticket-again-no',
        "Doesn't repeat",
        _recur == 'none',
        () {
          _recur = 'none';
          // Coupling (#266): back to Never clears repeat-ends.
          _repeatEndDate = '';
        },
      ),
      (
        'ticket-cad-daily',
        'Every day',
        _recur == 'daily',
        () {
          _recur = 'daily';
        },
      ),
      (
        'ticket-cad-weekly',
        'Every week on ${_weekdayNames[wd - 1]}',
        _recur == 'weekly',
        () {
          _recur = 'weekly';
          _recurEvery = 1;
          _recurWeekdays = [wd];
        },
      ),
      (
        'ticket-month-date',
        'Every month on the ${_ordinal(day.day)}',
        _recur == 'monthly' && !nthWeekday,
        () {
          _recur = 'monthly';
          _monthlyMode = 'date';
        },
      ),
      (
        'ticket-month-nth',
        'Every ${_nthNames[nth.clamp(1, 5) - 1]} '
            '${_weekdayNames[nthDay.clamp(1, 7) - 1]} of the month',
        nthWeekday,
        () {
          _recur = 'monthly';
          _monthlyMode = 'nthWeekday';
          _monthlyNth = nth;
          _monthlyWeekday = nthDay;
        },
      ),
      (
        'ticket-cad-yearly',
        'Every year on ${day.day} ${_shortMonth(day)}',
        _recur == 'yearly',
        () {
          _recur = 'yearly';
        },
      ),
      (
        'ticket-cad-custom',
        'Custom days…',
        _recur == 'custom',
        () {
          _recur = 'custom';
          _recurUnit = 'week';
          if (_recurEvery < 1) _recurEvery = 1;
        },
      ),
    ];
    final custom = _recur == 'custom';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (key, label, on, apply) in options) ...[
          _radio(
            ValueKey(key),
            label,
            on,
            () => setState(() {
              apply();
              if (_recur != 'none') {
                // Coupling (#266): repeating disables multi-day.
                _multiDay = false;
                _endDate = _date;
                if (_repeatEndDate.isNotEmpty &&
                    _repeatEndDate.compareTo(_date) < 0) {
                  _repeatEndDate = _date;
                }
              }
            }),
          ),
          const SizedBox(height: 2),
        ],
        if (custom) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.tc.surface,
              border: Border.all(color: context.tc.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _caption('ON THESE DAYS'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var weekday = 1; weekday <= 7; weekday++)
                      GestureDetector(
                        key: ValueKey('event-custom-weekday-$weekday'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() {
                          _recurUnit = 'week';
                          if (_recurWeekdays.contains(weekday)) {
                            if (_recurWeekdays.length > 1) {
                              _recurWeekdays.remove(weekday);
                            }
                          } else {
                            _recurWeekdays.add(weekday);
                            _recurWeekdays.sort();
                          }
                        }),
                        child: _dayCircle(
                          kWeekdayLetters[weekday - 1],
                          _recurWeekdays.contains(weekday),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final n in const [1, 2, 3, 4])
                      _pill(
                        ValueKey('event-custom-every-$n'),
                        n == 1 ? 'Every week' : 'Every $n weeks',
                        _recurEvery == n,
                        () => setState(() {
                          _recurUnit = 'week';
                          _recurEvery = n;
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (_recur != 'none') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Stops repeating',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.tc.text,
                  ),
                ),
              ),
              if (_repeatEndDate.isNotEmpty)
                GestureDetector(
                  key: const ValueKey('event-repeat-never'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _repeatEndDate = ''),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Text(
                      'Never stop',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: context.tc.primary,
                      ),
                    ),
                  ),
                ),
              _dateButton(
                const ValueKey('event-repeat-end-date'),
                _repeatEndDate.isEmpty
                    ? 'Never'
                    : _daySheetTitleIso(_repeatEndDate),
                _pickRepeatEndDate,
              ),
            ],
          ),
        ],
      ],
    );
  }

  static const _reminders = [
    ('none', 'None'),
    ('at', 'At start'),
    ('5m', '5 min'),
    ('15m', '15 min'),
    ('30m', '30 min'),
    ('1h', '1 hour'),
    ('2h', '2 hours'),
    ('1d', '1 day'),
    ('2d', '2 days'),
  ];

  String _reminderLabel() {
    if (_reminder == 'none') return 'No reminder';
    if (_reminder == 'at') return 'At start';
    final label = _reminders.where((r) => r.$1 == _reminder).firstOrNull?.$2;
    return '${label ?? '1 hour'} before';
  }

  /// Reminder (#268): a grid of lead times, then when it will ring.
  Widget _reminderBody() {
    final ring = reminderRingLine(_draft());
    Widget cell(String v, String label) {
      final on = _reminder == v;
      return GestureDetector(
        key: ValueKey(v == 'none' ? 'ticket-rem-no' : 'ticket-rem-$v'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _reminder = v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 42),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? context.tc.soft : context.tc.surface,
            border: Border.all(
              color: on ? context.tc.primary : context.tc.line,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: on ? context.tc.deep : context.tc.text,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < _reminders.length; r += 3) ...[
          if (r > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (var i = r; i < r + 3; i++) ...[
                if (i > r) const SizedBox(width: 6),
                Expanded(
                  child: i < _reminders.length
                      ? cell(_reminders[i].$1, _reminders[i].$2)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
        if (_reminder != 'none' && ring.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            ring,
            key: const ValueKey('ticket-ring-line'),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: context.tc.soft2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _placeBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _boxedField(
          key: const ValueKey('event-location'),
          controller: _location,
          hint: 'Address or place name',
        ),
        // Checking the place is the real one belongs HERE, while you are
        // still typing it — not after saving.
        if (_location.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: edSoftChip(
                key: const ValueKey('event-open-in-maps'),
                label: 'Check it on Google Maps',
                small: true,
                selected: true,
                leading: ic(
                  'mappin',
                  size: 13,
                  sw: 2.2,
                  color: context.tc.deep,
                ),
                onTap: () async {
                  final ok = await openPlaceInMaps(_location.text);
                  if (!ok) s.flash('Could not open Maps on this device');
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _layerChip(CalendarLayerDef layer) {
    final on = _layerId == layer.id;
    return GestureDetector(
      key: ValueKey('event-layer-${layer.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _setLayerId(layer.id)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? layer.color.withValues(alpha: .12) : context.tc.surface,
          border: Border.all(
            color: on ? layer.color : context.tc.line,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            layer.emoji == null
                ? _dot(layer.color)
                : Text(layer.emoji!, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              layer.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: on ? layer.color : context.tc.soft2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calendar & colour: the layer, then the colour. The row itself folds, so
  /// the Palette / RGB-Hex selector shows directly once it is open.
  Widget _lookBody() {
    final cat = s.catById(_category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _caption('CALENDAR'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final l in s.calendarLayers) _layerChip(l)],
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 10),
        _caption('COLOUR'),
        const SizedBox(height: 6),
        // Coupling (#266): the category owns the colour.
        if (cat != null)
          Text(
            'Uses the ${cat.name} colour. '
            'Pick “None” as category to choose your own.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.tc.soft2,
            ),
          )
        else
          _ColorPickerPanel(
            selected: _color,
            onChanged: (c) => setState(() => _color = c),
          ),
      ],
    );
  }

  Widget _options() {
    final cat = s.catById(_category);
    final repeats = _recur != 'none';
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.tc.line, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _optionRow(
              id: 'repeat',
              icon: 'repeat',
              label: 'Repeat',
              value:
                  _repeatLabel() +
                  (repeats && _repeatEndDate.isNotEmpty
                      ? ' · until ${_daySheetTitleIso(_repeatEndDate)}'
                      : ''),
              valueKey: const ValueKey('ticket-repeat-summary'),
              set: repeats,
              first: true,
              body: _repeatBody,
            ),
            _optionRow(
              id: 'reminder',
              icon: 'bell',
              label: 'Reminder',
              value: _reminderLabel(),
              set: _reminder != 'none',
              body: _reminderBody,
            ),
            _optionRow(
              id: 'place',
              icon: 'mappin',
              label: 'Location',
              value: _location.text.trim().isEmpty
                  ? 'Add a place'
                  : _location.text.trim(),
              set: _location.text.trim().isNotEmpty,
              body: _placeBody,
            ),
            _optionRow(
              id: 'notes',
              icon: 'note',
              label: 'Notes',
              value: _notes.text.trim().isEmpty
                  ? 'Add notes'
                  : _notes.text.trim().replaceAll('\n', ' '),
              set: _notes.text.trim().isNotEmpty,
              body: () => _boxedField(
                key: const ValueKey('event-notes'),
                controller: _notes,
                hint: 'Anything to remember?',
                maxLines: 3,
              ),
            ),
            _optionRow(
              id: 'colour',
              icon: 'palette',
              label: 'Calendar & colour',
              value:
                  '$_layerLabel · '
                  '${cat != null ? '${cat.name} colour' : 'custom colour'}',
              set: true,
              body: _lookBody,
            ),
          ],
        ),
      ),
    );
  }

  String get _layerLabel =>
      s.calendarLayers.where((l) => l.id == _layerId).firstOrNull?.label ??
      'Calendar';

  /// "Wed 22 Jul · 09:00–10:00 · Every week on Wednesday".
  String get _summary {
    final multi = _multiDay && _recur == 'none';
    final date = multi
        ? '${_daySheetTitleIso(_date)} – ${_daySheetTitleIso(_endDate)}'
        : _daySheetTitleIso(_date);
    return [
      date,
      _allDay || _birthday ? 'All day' : '$_start–$_end',
      if (_recur != 'none') _repeatLabel(),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final valid = _title.text.trim().isNotEmpty;
    final noun = _todo ? 'to-do' : 'event';
    final cat = s.catById(_category);
    return EditorSheet(
      title: _editing ? 'Edit $noun' : 'New $noun',
      pinned: EdSegmented<String>(
        keyPrefix: 'event-kind',
        options: const [('event', 'Event'), ('todo', 'To-do')],
        value: _todo ? 'todo' : 'event',
        onChanged: (v) => setState(() => _todo = v == 'todo'),
      ),
      summary: _summary,
      confirmLabel: _editing ? 'Save changes' : 'Add $noun',
      blockedReason: valid ? null : 'Give it a name first',
      onConfirm: _submit,
      deleteLabel: _editing ? 'Delete $noun' : null,
      onDelete: _editing ? _delete : null,
      confirmKey: const ValueKey('sheet-confirm'),
      deleteKey: const ValueKey('ticket-delete'),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titleRow(),
            // A to-do carries a done state; it sits right under its name.
            if (_todo) ...[
              const SizedBox(height: 12),
              edToggleRow(
                key: const ValueKey('event-done'),
                label: 'Already done',
                sub: 'Ticks it off the moment you save',
                value: _done,
                onTap: () => setState(() => _done = !_done),
              ),
            ],
          ],
        ),
        KeyedSubtree(
          key: const ValueKey('event-card-category'),
          child: EdSection(
            label: 'Category',
            hint: cat != null ? 'Sets colour & people' : 'Optional',
            child: _categoryChips(),
          ),
        ),
        KeyedSubtree(
          key: const ValueKey('event-card-when'),
          child: EdSection(label: 'When', gap: 10, child: _when()),
        ),
        KeyedSubtree(
          key: const ValueKey('event-card-people'),
          child: EdSection(
            label: "Who's involved",
            hint: _attendees.isEmpty
                ? 'Tap to add'
                : '${_attendees.length} selected',
            child: _people(),
          ),
        ),
        EdSection(label: 'Options', child: _options()),
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
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: context.tc.ink,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: context.tc.page,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.tc.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.tc.primary, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.tc.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: context.tc.ink,
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
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: context.tc.soft2,
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
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: context.tc.soft2,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  key: const ValueKey('time-input-ok'),
                  onPressed: _confirm,
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: context.tc.primary,
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
