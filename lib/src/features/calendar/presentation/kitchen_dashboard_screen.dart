part of 'package:family_money_management_app/main.dart';

/// Kitchen-tablet dashboard (Calendar Layers design): a landscape,
/// large-touch-target full-screen view with one column per family member
/// showing today's chores/content alongside a left-rail appointment schedule.
/// Stars, picture-mode overrides, and kitchen-origin items persist on the
/// shared [_ThriveHomeState].
extension _ThriveKitchenDashboard on _ThriveHomeState {
  void openKitchenDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _KitchenDashboardScreen(state: this)),
    );
  }

  /// Whether [ev] is due — or, if recurring, has an occurrence — on [iso].
  bool _kitchenEventDueOn(CalendarEvent ev, String iso) {
    if (ev.recur == 'none') return ev.date == iso;
    return recurringEventDates(ev, iso, iso).isNotEmpty;
  }

  // ------------------------------------------------------------ settings

  /// Toggles the wall-tablet Kitchen dashboard globally. When disabled, the
  /// calendar view switcher shows a re-enable prompt instead of opening it.
  void toggleKitchenEnabled() {
    mutate(() => kitchenEnabled = !kitchenEnabled);
  }

  void openKitchenWallSettings() {
    _showSheet((ctx) => _KitchenWallSettingsSheet(state: this));
  }

  /// Whether [memberId]'s column renders large photo tiles instead of
  /// text/checkbox rows. Missing memberId defaults to `false`.
  bool pictureModeFor(String memberId) => picMembers[memberId] ?? false;

  void togglePictureModeFor(String memberId) {
    mutate(() => picMembers[memberId] = !pictureModeFor(memberId));
  }

  bool kitchenLayerVisible(String layerId) =>
      kitchenLayerFilter.contains(layerId);

  void toggleKitchenWallLayer(String layerId) {
    mutate(() {
      if (kitchenLayerFilter.contains(layerId)) {
        final visibleCount = _kitchenWallLayers(
          this,
        ).where((l) => kitchenLayerFilter.contains(l.id)).length;
        if (visibleCount <= 1) return;
        kitchenLayerFilter.remove(layerId);
      } else {
        kitchenLayerFilter.add(layerId);
      }
    });
  }

  // --------------------------------------------------------- star rewards

  /// Current star count (0-5) for [memberId]. Missing memberId means 0.
  int starsFor(String memberId) => starsMap[memberId] ?? 0;

  /// Rating-style tap: setting the filled count up to [count] (1-5), except
  /// tapping the already-filled top star again clears one back down (e.g.
  /// 5 -> 4). Clamped to 0-5.
  void setMemberStars(String memberId, int count) {
    mutate(() {
      final current = starsMap[memberId] ?? 0;
      final next = current == count ? count - 1 : count;
      starsMap[memberId] = next.clamp(0, 5);
    });
  }

  /// Claims the 5/5 reward, resetting the member's stars back to 0. Only
  /// meaningful (and only ever called from the UI) at 5/5.
  void claimMemberReward(String memberId) {
    mutate(() => starsMap[memberId] = 0, () => flash('Reward claimed'));
  }

  // ------------------------------------------------------------ quick add

  /// Creates a kitchen-origin [CalendarEvent] (a chore/content item, never
  /// an appointment) due today.
  void createKitchenItem({
    required String title,
    required String assignee,
    String? picture,
    String? emoji,
  }) {
    mutate(() {
      final member = _memberById(assignee);
      events.add(
        CalendarEvent(
          id: uid(),
          title: title.trim().isEmpty ? 'Picture item' : title.trim(),
          allDay: true,
          date: todayIso(),
          color: member?.color ?? B.primary,
          attendees: [assignee],
          layerId: '',
          todo: true,
          createdBy: myId,
          kitchenOrigin: true,
          picture: picture,
          emoji: emoji,
        ),
      );
    }, () => flash('Added'));
  }

  /// Attaches/clears a picture-mode emoji or photo on a kitchen-origin item.
  void setKitchenItemGlyph(String id, {String? emoji, String? picture}) {
    mutate(() {
      final ev = eventById(id);
      if (ev == null || !ev.kitchenOrigin) return;
      ev.emoji = emoji;
      ev.picture = picture;
    });
  }

  /// Deletes a kitchen-origin item. A no-op for phone-created events — those
  /// are only editable/removable from the phone's calendar.
  void deleteKitchenItem(String id) {
    final ev = eventById(id);
    if (ev == null || !ev.kitchenOrigin) return;
    mutate(() => events.removeWhere((x) => x.id == id));
  }

  /// Completed-vs-total task/content count for [memberId] on [iso]
  /// (defaults to today), for the column header/progress indicator.
  ({int completed, int total}) kitchenMemberProgress(
    String memberId, [
    String? iso,
  ]) {
    final today = iso ?? todayIso();
    final occ = kitchenMemberOccurrences(memberId, today);
    return (completed: occ.where((o) => o.done).length, total: occ.length);
  }

  List<CalendarOccurrence> kitchenMemberOccurrences(
    String memberId,
    String iso,
  ) {
    final out = <CalendarOccurrence>[];
    for (final ev in events) {
      if (!ev.kitchenOrigin) {
        if (ev.layerId == 'appt') continue;
        if (!kitchenLayerVisible(ev.layerId)) continue;
      }
      if (!ev.attendees.contains(memberId)) continue;
      if (!_kitchenEventDueOn(ev, iso)) continue;
      if (ev.recur == 'none') {
        final spanEnd =
            ev.endDate.isNotEmpty && ev.endDate.compareTo(ev.date) > 0
            ? ev.endDate
            : ev.date;
        out.add(
          CalendarOccurrence(
            ev: ev,
            date: iso,
            spanEnd: spanEnd,
            done: ev.done,
          ),
        );
      } else {
        out.add(CalendarOccurrence(ev: ev, date: iso, done: ev.isDoneOn(iso)));
      }
    }
    out.sort(
      (a, b) => (a.ev.allDay ? '' : a.ev.start).compareTo(
        b.ev.allDay ? '' : b.ev.start,
      ),
    );
    return out;
  }

  List<CalendarOccurrence> kitchenAppointmentOccurrences(String iso) {
    final out = <CalendarOccurrence>[];
    for (final ev in events) {
      if (ev.kitchenOrigin) continue;
      final scheduleLike =
          ev.layerId == 'appt' || (!ev.allDay && ev.start.isNotEmpty);
      if (!scheduleLike) continue;
      if (!kitchenLayerVisible(ev.layerId)) continue;
      if (ev.recur == 'none') {
        final spanEnd =
            ev.endDate.isNotEmpty && ev.endDate.compareTo(ev.date) > 0
            ? ev.endDate
            : ev.date;
        if (spanEnd.compareTo(iso) >= 0 &&
            ev.date.compareTo(iso) <= 0 &&
            !ev.exceptions.contains(ev.date)) {
          out.add(CalendarOccurrence(ev: ev, date: ev.date, spanEnd: spanEnd));
        }
        continue;
      }
      for (final d in recurringEventDates(ev, iso, iso)) {
        out.add(CalendarOccurrence(ev: ev, date: d));
      }
    }
    for (final cal in importedCalendars) {
      if (!cal.visible) continue;
      for (final e in cal.events) {
        if (e.date == iso) {
          out.add(
            CalendarOccurrence(
              imported: true,
              date: e.date,
              ev: importedSyntheticEvent(cal, e),
            ),
          );
        }
      }
    }
    out.sort(
      (a, b) => (a.ev.allDay ? '' : a.ev.start).compareTo(
        b.ev.allDay ? '' : b.ev.start,
      ),
    );
    return out;
  }
}

List<CalendarLayerDef> _kitchenWallLayers(_ThriveHomeState state) {
  final layers = state.calendarLayers.toList();
  if (layers.isNotEmpty) return layers;
  return kDefaultCalendarLayers();
}

CalendarLayerDef? _kitchenLayerDefFor(_ThriveHomeState state, String id) {
  for (final layer in _kitchenWallLayers(state)) {
    if (layer.id == id) return layer;
  }
  return null;
}

class _KitchenWallSettingsSheet extends StatefulWidget {
  const _KitchenWallSettingsSheet({required this.state});

  final _ThriveHomeState state;

  @override
  State<_KitchenWallSettingsSheet> createState() =>
      _KitchenWallSettingsSheetState();
}

class _KitchenWallSettingsSheetState extends State<_KitchenWallSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final members = state.curFamily()?.members ?? const <FamilyMember>[];
    final layers = _kitchenWallLayers(state);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(
            context,
            'Kitchen wall settings',
            'Layers and picture mode',
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Visible layers',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: B.ink,
              ),
            ),
          ),
          for (final layer in layers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: B.line),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: layer.color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: glyphTile(
                        size: 34,
                        radius: 10,
                        picture: layer.picture,
                        emoji: layer.emoji,
                        emojiSize: 18,
                        fallback: const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        layer.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: B.ink,
                        ),
                      ),
                    ),
                    Switch(
                      key: ValueKey('kitchen-wall-layer-${layer.id}'),
                      value: state.kitchenLayerVisible(layer.id),
                      onChanged: (_) {
                        state.toggleKitchenWallLayer(layer.id);
                        setState(() {});
                      },
                      activeTrackColor: layer.color,
                    ),
                  ],
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              'Picture mode',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: B.ink,
              ),
            ),
          ),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'No family members yet.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: B.muted,
                ),
              ),
            )
          else
            for (final member in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: B.line),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      state.avatarNode(
                        photo: member.photo,
                        emoji: member.emoji,
                        initials: member.initials,
                        color: member.color,
                        size: 34,
                        radius: 17,
                        fs: 13,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              member.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: B.ink,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'Picture mode',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: B.soft2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        key: ValueKey('kitchen-wall-picmode-${member.id}'),
                        value: state.pictureModeFor(member.id),
                        onChanged: (_) {
                          state.togglePictureModeFor(member.id);
                          setState(() {});
                        },
                        activeTrackColor: member.color,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Full-screen kitchen-tablet dashboard: one column per family member, each
/// showing today's chores/content as kitchen-specific text or picture tiles
/// under an avatar/name header with stars and completion progress.
class _KitchenDashboardScreen extends StatefulWidget {
  const _KitchenDashboardScreen({required this.state});

  final _ThriveHomeState state;

  @override
  State<_KitchenDashboardScreen> createState() =>
      _KitchenDashboardScreenState();
}

class _KitchenDashboardScreenState extends State<_KitchenDashboardScreen> {
  _ThriveHomeState get state => widget.state;

  @override
  void initState() {
    super.initState();
    unawaited(_lockLandscapeOrientation());
  }

  @override
  void dispose() {
    unawaited(_lockPortraitOrientation());
    super.dispose();
  }

  /// The dashboard is pushed as its own route below the shared
  /// [_ThriveHomeState] in the widget tree, so its `setState`-driven
  /// rebuilds (via `mutate()`/`update()`) don't reach this route on their
  /// own. Re-deriving every occurrence/progress value from the same shared,
  /// mutated-in-place `events` on a local `setState()` after
  /// each checkbox tap keeps this screen live without any state of its own.
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final members = state.curFamily()?.members ?? const <FamilyMember>[];
    final today = todayIso();

    return Scaffold(
      key: const ValueKey('kitchen-dashboard'),
      backgroundColor: const Color(0xff111318),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xfff4f6f9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _KitchenLeftPanel(
                        key: const ValueKey('kitchen-left-panel'),
                        state: state,
                      ),
                      Container(width: 1, color: B.line),
                      const SizedBox(width: 14),
                      Expanded(
                        child: members.isEmpty
                            ? const Center(
                                child: Text(
                                  'No family members yet',
                                  style: TextStyle(
                                    color: B.muted,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final m in members)
                                    Expanded(
                                      child: _KitchenMemberColumn(
                                        key: ValueKey('kitchen-column-${m.id}'),
                                        state: state,
                                        member: m,
                                        today: today,
                                        onOccurrenceChanged: _refresh,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  key: const ValueKey('kitchen-dashboard-close'),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: B.line),
                    ),
                    child: const Center(
                      child: Icon(Icons.close, color: B.soft2, size: 18),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: GestureDetector(
                  key: const ValueKey('kitchen-quick-add-fab'),
                  onTap: () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      barrierColor: const Color(0x73101828),
                      builder: (ctx) => Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(ctx).viewInsets.bottom,
                        ),
                        child: _SheetShell(
                          child: _KitchenQuickAddSheet(
                            state: state,
                            members: members,
                          ),
                        ),
                      ),
                    );
                    _refresh();
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: B.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: B.primary.withValues(alpha: .45),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Left panel of the wall-tablet dashboard: today's date plus a scrollable
/// schedule for today and the next six days. Past days are intentionally not
/// shown; to-dos/content live exclusively in the member columns on the right.
const List<String> kKitchenWeekdaysShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String kitchenMainDateLabel(DateTime d) =>
    '${kKitchenWeekdaysShort[d.weekday - 1]}, ${ordinal(d.day)} '
    '${kMonthsEn[d.month - 1]}';

String kitchenScheduleDateLabel(DateTime d, {required bool isToday}) {
  if (isToday) return 'Today';
  final weekday = kKitchenWeekdaysShort[d.weekday - 1];
  final day = ordinal(d.day);
  if (d.day == 1) return '$weekday, $day ${kMonthsEn[d.month - 1]}';
  return '$weekday $day';
}

class _KitchenLeftPanel extends StatelessWidget {
  const _KitchenLeftPanel({super.key, required this.state});

  final _ThriveHomeState state;

  @override
  Widget build(BuildContext context) {
    final today = todayIso();
    final days = [for (var i = 0; i < 7; i++) _addDaysIso(today, i)];
    final d = _parseIso(today);

    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _weekNumberLabelIso(today).toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
              color: B.muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            kitchenMainDateLabel(d),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: B.ink,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'WEEKLY SCHEDULE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
              color: B.soft2,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              key: const ValueKey('kitchen-week-schedule'),
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < days.length; i++)
                  _dayGroup(
                    days[i],
                    today,
                    showWeekBreak:
                        i > 0 &&
                        _weekNumberLabelIso(days[i]) !=
                            _weekNumberLabelIso(days[i - 1]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayGroup(String iso, String today, {required bool showWeekBreak}) {
    final appts = state.kitchenAppointmentOccurrences(iso);
    final isToday = iso == today;
    final d = _parseIso(iso);
    final dayLabel = kitchenScheduleDateLabel(d, isToday: isToday);
    return Padding(
      key: ValueKey('kitchen-day-group-$iso'),
      padding: EdgeInsets.only(top: showWeekBreak ? 4 : 0, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showWeekBreak) ...[
            Text(
              _weekNumberLabelIso(iso).toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: .3,
                color: B.ink,
              ),
            ),
            const SizedBox(height: 7),
          ],
          Text(
            dayLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
              color: isToday ? B.primary : B.muted,
            ),
          ),
          const SizedBox(height: 6),
          if (appts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'No events yet',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: B.muted,
                ),
              ),
            )
          else
            for (final o in appts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _KitchenScheduleRow(state: state, occurrence: o),
              ),
        ],
      ),
    );
  }
}

class _KitchenScheduleRow extends StatelessWidget {
  const _KitchenScheduleRow({required this.state, required this.occurrence});

  final _ThriveHomeState state;
  final CalendarOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final ev = occurrence.ev;
    final category = state.catById(ev.category);
    final color = state.evColor(ev);
    final time = ev.allDay
        ? 'All day'
        : '${ev.start}${ev.end.isNotEmpty ? ' - ${ev.end}' : ''}';
    return Container(
      key: ValueKey('kitchen-schedule-row-${ev.id}-${occurrence.date}'),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  time,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: .9),
                  ),
                ),
              ),
              if (category != null)
                Container(
                  key: ValueKey('kitchen-schedule-category-${ev.id}'),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .24),
                    ),
                  ),
                  child: Center(
                    child: categoryGlyph(
                      category,
                      size: 18,
                      iconColor: contrastOn(color),
                    ),
                  ),
                )
              else
                _KitchenScheduleAttendees(
                  key: ValueKey('kitchen-schedule-attendees-${ev.id}'),
                  state: state,
                  memberIds: ev.attendees,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ev.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _KitchenScheduleAttendees extends StatelessWidget {
  const _KitchenScheduleAttendees({
    super.key,
    required this.state,
    required this.memberIds,
  });

  final _ThriveHomeState state;
  final List<String> memberIds;

  @override
  Widget build(BuildContext context) {
    final members = [
      for (final id in memberIds.take(3)) ?state._memberById(id),
    ];
    if (members.isEmpty) return const SizedBox.shrink();
    const size = 24.0;
    return SizedBox(
      width: size + (members.length - 1) * size * .58,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < members.length; i++)
            Positioned(
              left: i * size * .58,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: state.avatarNode(
                  photo: members[i].photo,
                  emoji: members[i].emoji,
                  initials: members[i].initials,
                  color: members[i].color,
                  size: size - 4,
                  radius: (size - 4) / 2,
                  fs: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KitchenMemberColumn extends StatelessWidget {
  const _KitchenMemberColumn({
    super.key,
    required this.state,
    required this.member,
    required this.today,
    required this.onOccurrenceChanged,
  });

  final _ThriveHomeState state;
  final FamilyMember member;
  final String today;

  /// Called after any tap on the column's content — cheap to call on every
  /// tap (not just the checkbox's) since it only triggers a `setState()` on
  /// the dashboard route to re-derive occurrences/progress from the shared,
  /// already-mutated `events` (see [_KitchenDashboardScreenState._refresh]).
  final VoidCallback onOccurrenceChanged;

  @override
  Widget build(BuildContext context) {
    final occ = state.kitchenMemberOccurrences(member.id, today);
    final progress = state.kitchenMemberProgress(member.id, today);

    return Container(
      margin: const EdgeInsets.only(right: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: B.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              state.avatarNode(
                photo: member.photo,
                emoji: member.emoji,
                initials: member.initials,
                color: member.color,
                size: 32,
                radius: 16,
                fs: 13,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  member.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: B.ink,
                  ),
                ),
              ),
              Text(
                '${progress.completed}/${progress.total}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: member.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _KitchenStarRow(
            key: ValueKey('kitchen-stars-${member.id}'),
            state: state,
            memberId: member.id,
            onChanged: onOccurrenceChanged,
          ),
          const SizedBox(height: 7),
          _KitchenProgressBadge(
            key: ValueKey('kitchen-progress-${member.id}'),
            completed: progress.completed,
            total: progress.total,
            color: member.color,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: occ.isEmpty
                ? Center(
                    child: Text(
                      'Nothing today.',
                      style: TextStyle(color: B.muted, fontSize: 13),
                    ),
                  )
                : state.pictureModeFor(member.id)
                ? GridView.builder(
                    key: ValueKey('kitchen-grid-${member.id}'),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                    itemCount: occ.length,
                    itemBuilder: (context, i) => _KitchenPictureTile(
                      key: ValueKey('kitchen-pic-tile-${occ[i].ev.id}'),
                      state: state,
                      occ: occ[i],
                      color:
                          _kitchenLayerDefFor(state, occ[i].layer)?.color ??
                          member.color,
                      onChanged: onOccurrenceChanged,
                    ),
                  )
                : ListView.separated(
                    key: ValueKey('kitchen-list-${member.id}'),
                    padding: EdgeInsets.zero,
                    itemCount: occ.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 7),
                    itemBuilder: (context, i) => _KitchenTextTile(
                      state: state,
                      occ: occ[i],
                      member: member,
                      onChanged: onOccurrenceChanged,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _KitchenTextTile extends StatelessWidget {
  const _KitchenTextTile({
    required this.state,
    required this.occ,
    required this.member,
    required this.onChanged,
  });

  final _ThriveHomeState state;
  final CalendarOccurrence occ;
  final FamilyMember member;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ev = occ.ev;
    final layer = _kitchenLayerDefFor(state, occ.layer);
    final accent = layer?.color ?? member.color;
    final done = occ.done;
    final isContent = occ.layer == 'content';

    void toggle() {
      state._toggleOccurrenceDone(occ);
      onChanged();
    }

    return Opacity(
      opacity: done ? .58 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: toggle,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: done ? B.faint : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isContent && !done ? accent : B.line,
                  width: isContent && !done ? 1.5 : 1,
                  style: isContent ? BorderStyle.solid : BorderStyle.solid,
                ),
              ),
              foregroundDecoration: isContent && !done
                  ? _DashedBoxDecoration(color: accent, radius: 14)
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        key: ValueKey('event-check-${ev.id}-${occ.date}'),
                        onTap: toggle,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done ? accent : Colors.white,
                            border: Border.all(
                              color: done ? accent : B.line,
                              width: 2.5,
                            ),
                          ),
                          child: done
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                      if (isContent) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: ic(
                              layer?.icon ?? 'camera',
                              size: 13,
                              sw: 2.1,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ev.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: done ? B.muted : B.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (layer != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ic(layer.icon, size: 9.5, sw: 2.4, color: accent),
                              const SizedBox(width: 4),
                              Text(
                                layer.label,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (ev.recur != 'none')
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: B.soft,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ic('repeat', size: 9.5, sw: 2.6, color: B.deep),
                              const SizedBox(width: 3),
                              Text(
                                ev.recur,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: B.deep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (ev.kitchenOrigin)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                key: ValueKey('kitchen-remove-${ev.id}'),
                onTap: () {
                  state.deleteKitchenItem(ev.id);
                  onChanged();
                },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: B.line),
                    boxShadow: [
                      BoxShadow(
                        color: B.ink.withValues(alpha: .12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 13, color: B.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 5-star behavior row (independent of chore/task completion). Tapping a
/// star sets the filled count up to that star (rating-style); tapping the
/// already-filled top star again clears one back down. At 5/5, a "claim
/// reward" affordance replaces the row.
class _KitchenStarRow extends StatelessWidget {
  const _KitchenStarRow({
    super.key,
    required this.state,
    required this.memberId,
    required this.onChanged,
  });

  final _ThriveHomeState state;
  final String memberId;

  /// Called after every star tap / reward claim — see
  /// [_KitchenMemberColumn.onOccurrenceChanged]: cheap to call, and needed
  /// here because star taps mutate shared state directly (not through the
  /// occurrence-list's [Listener]), so without this the pushed dashboard
  /// route wouldn't otherwise pick up the change.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final stars = state.starsFor(memberId);
    final full = stars >= 5;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: full ? const Color(0xfffff7ed) : B.faint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: full ? const Color(0xfff5d78e) : B.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  key: ValueKey('kitchen-star-$memberId-$i'),
                  onTap: () {
                    state.setMemberStars(memberId, i);
                    onChanged();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: Icon(
                      i <= stars ? Icons.star : Icons.star_border,
                      size: 13,
                      color: i <= stars ? const Color(0xffe8a827) : B.muted,
                    ),
                  ),
                ),
            ],
          ),
          if (full) ...[
            const SizedBox(height: 6),
            GestureDetector(
              key: ValueKey('kitchen-claim-$memberId'),
              onTap: () {
                state.claimMemberReward(memberId);
                onChanged();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xffe8a827),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.card_giftcard, size: 15, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        'Claim reward!',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Large square glyph tile for picture-mode columns (pre-readers): just a
/// photo/emoji with a checkmark overlay to mark done — no text. A
/// kitchen-origin item without a glyph yet shows a placeholder instead so a
/// parent can tap it to attach one.
class _KitchenPictureTile extends StatelessWidget {
  const _KitchenPictureTile({
    super.key,
    required this.state,
    required this.occ,
    required this.color,
    required this.onChanged,
  });

  final _ThriveHomeState state;
  final CalendarOccurrence occ;
  final Color color;
  final VoidCallback onChanged;

  Future<void> _openGlyphPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x73101828),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _SheetShell(
          child: _KitchenItemGlyphSheet(state: state, event: occ.ev),
        ),
      ),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final ev = occ.ev;
    final done = occ.done;
    final hasGlyph =
        (ev.picture?.isNotEmpty ?? false) || (ev.emoji?.isNotEmpty ?? false);
    return Opacity(
      opacity: done ? .55 : 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: ValueKey('kitchen-pic-set-${ev.id}'),
            onTap: ev.kitchenOrigin ? () => _openGlyphPicker(context) : null,
            child: Container(
              decoration: BoxDecoration(
                color: B.faint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: done ? color : B.line, width: 2),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest.shortestSide;
                  return glyphTile(
                    size: size,
                    radius: 16,
                    picture: ev.picture,
                    emoji: ev.emoji,
                    emojiSize: 42,
                    fallback: Center(
                      child: Icon(
                        hasGlyph ? Icons.edit : Icons.add_photo_alternate,
                        color: B.muted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 6,
            child: GestureDetector(
              key: ValueKey('kitchen-pic-check-${ev.id}'),
              onTap: () {
                state._toggleOccurrenceDone(occ);
                onChanged();
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: done ? color : Colors.white.withValues(alpha: .92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: B.ink.withValues(alpha: .22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check,
                  color: done ? Colors.white : color,
                  size: 18,
                ),
              ),
            ),
          ),
          if (ev.kitchenOrigin)
            Positioned(
              top: 6,
              left: 6,
              child: GestureDetector(
                key: ValueKey('kitchen-remove-${ev.id}'),
                onTap: () {
                  state.deleteKitchenItem(ev.id);
                  onChanged();
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .92),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 13, color: B.muted),
                ),
              ),
            ),
          if (ev.kitchenOrigin)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                key: ValueKey('kitchen-pic-edit-${ev.id}'),
                onTap: () => _openGlyphPicker(context),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .92),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 13, color: B.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KitchenItemGlyphSheet extends StatefulWidget {
  const _KitchenItemGlyphSheet({required this.state, required this.event});

  final _ThriveHomeState state;
  final CalendarEvent event;

  @override
  State<_KitchenItemGlyphSheet> createState() => _KitchenItemGlyphSheetState();
}

class _KitchenItemGlyphSheetState extends State<_KitchenItemGlyphSheet> {
  late String? _emoji;
  late String? _picture;

  @override
  void initState() {
    super.initState();
    _emoji = widget.event.emoji;
    _picture = widget.event.picture;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(context, 'Task picture', 'Emoji or picture'),
          _sheetField(
            'Emoji or picture',
            _GlyphPicker(
              emoji: _emoji,
              picture: _picture,
              onChanged: ({String? emoji, String? picture}) {
                setState(() {
                  _emoji = emoji;
                  _picture = picture;
                });
                widget.state.setKitchenItemGlyph(
                  widget.event.id,
                  emoji: emoji,
                  picture: picture,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating "+" quick-add sheet: title/image plus a single assignee. Creates
/// an independent kitchen-origin [CalendarEvent] due today via
/// [_ThriveKitchenDashboard.createKitchenItem].
class _KitchenQuickAddSheet extends StatefulWidget {
  const _KitchenQuickAddSheet({required this.state, required this.members});

  final _ThriveHomeState state;
  final List<FamilyMember> members;

  @override
  State<_KitchenQuickAddSheet> createState() => _KitchenQuickAddSheetState();
}

class _KitchenQuickAddSheetState extends State<_KitchenQuickAddSheet> {
  final _title = TextEditingController();
  String? _assignee;
  String? _emoji;
  String? _picture;

  @override
  void initState() {
    super.initState();
    _assignee = widget.members.isNotEmpty ? widget.members.first.id : null;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _selectedMemberUsesPictures =>
      _assignee != null && widget.state.pictureModeFor(_assignee!);

  @override
  Widget build(BuildContext context) {
    final pictureMode = _selectedMemberUsesPictures;
    final hasGlyph =
        (_picture?.isNotEmpty ?? false) || (_emoji?.isNotEmpty ?? false);
    final valid =
        _assignee != null &&
        (pictureMode ? hasGlyph : _title.text.trim().isNotEmpty);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(context, 'Add item', 'Shows up in their column today.'),
          if (pictureMode)
            _sheetField(
              'Emoji or picture',
              KeyedSubtree(
                key: const ValueKey('kitchen-add-image'),
                child: _GlyphPicker(
                  emoji: _emoji,
                  picture: _picture,
                  onChanged: ({String? emoji, String? picture}) {
                    setState(() {
                      _emoji = emoji;
                      _picture = picture;
                    });
                  },
                ),
              ),
            )
          else
            _sheetField(
              'Title',
              _sheetInput(
                _title,
                hint: 'e.g. Feed the cat',
                onChanged: (_) => setState(() {}),
              ),
            ),
          _sheetField(
            'Assignee',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in widget.members)
                  GestureDetector(
                    key: ValueKey('kitchen-add-assignee-${m.id}'),
                    onTap: () => setState(() {
                      _assignee = m.id;
                      if (!widget.state.pictureModeFor(m.id)) {
                        _emoji = null;
                        _picture = null;
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(5, 5, 11, 5),
                      decoration: BoxDecoration(
                        color: _assignee == m.id ? B.soft : Colors.white,
                        border: Border.all(
                          color: _assignee == m.id ? B.primary : B.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          widget.state.avatarNode(
                            photo: m.photo,
                            emoji: m.emoji,
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
                              color: _assignee == m.id ? B.deep : B.soft2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _primaryBtn('Add', () {
            widget.state.createKitchenItem(
              title: _title.text,
              assignee: _assignee!,
              emoji: _emoji,
              picture: _picture,
            );
            Navigator.of(context).pop();
          }, enabled: valid),
        ],
      ),
    );
  }
}

/// Thin rounded progress bar for completed-vs-total chores/content today.
class _KitchenProgressBadge extends StatelessWidget {
  const _KitchenProgressBadge({
    super.key,
    required this.completed,
    required this.total,
    required this.color,
  });

  final int completed;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 7,
        child: Stack(
          children: [
            Container(color: B.faint),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
