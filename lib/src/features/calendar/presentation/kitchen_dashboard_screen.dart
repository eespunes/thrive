part of 'package:family_money_management_app/main.dart';

/// Kitchen-tablet wall (design `Calendar options.dc.html` §4a): a landscape,
/// large-touch-target full-screen view with a fixed weekly-schedule panel on
/// the left and one column per family member — each column listing the
/// member's calendar events above their tickable chores. Stars are EARNED by
/// ticking chores; five of them turn the header into a gold claim button.
/// Stars, picture-mode overrides and kitchen-origin items all live on the
/// shared [_ThriveHomeState], so every change syncs family-wide.
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

  /// The wall's visibility gate: the SAME [passes] semantics as the phone
  /// calendar (layer on, category on, any attendee on), but switched by the
  /// wall's own layer set (#342). Kitchen-origin items are independent of
  /// the phone calendar and carry no layer, so they always pass.
  bool _kitchenPasses(CalendarEvent ev) {
    if (ev.kitchenOrigin) return true;
    return passes(ev, layers: kitchenLayerFilter);
  }

  // ------------------------------------------------------------ settings

  /// Toggles the wall-tablet Kitchen dashboard globally. When disabled, the
  /// calendar view switcher greys the chef button; tapping it re-enables it.
  void toggleKitchenEnabled() {
    mutate(() => kitchenEnabled = !kitchenEnabled);
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
      if (kitchenLayerVisible(layerId)) {
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

  /// Stars are EARNED, not set (#333): the row itself is display-only, and
  /// this moves it by one in either direction, clamped to 0-5.
  void awardMemberStar(String memberId, {required bool earned}) {
    mutate(() {
      final current = starsMap[memberId] ?? 0;
      starsMap[memberId] = (current + (earned ? 1 : -1)).clamp(0, 5);
    });
  }

  /// Claims the 5/5 reward, resetting the member's stars back to 0. Only
  /// meaningful (and only ever called from the UI) at 5/5.
  void claimMemberReward(String memberId) {
    mutate(() => starsMap[memberId] = 0, () => flash('Reward claimed'));
  }

  /// Ticks a wall chore: flips the occurrence and moves the owning member's
  /// star bar with it (completing earns a star, un-completing gives it
  /// back). This is the only place stars change by themselves.
  void kitchenToggleChore(CalendarOccurrence o, String memberId) {
    if (!o.isTask) return;
    final wasDone = o.done;
    toggleEventDone(o.ev.id, o.date);
    awardMemberStar(memberId, earned: !wasDone);
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
    }, () => flash('On the wall — due today'));
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

  /// [memberId]'s tickable chores for [iso] — kitchen-origin items plus any
  /// non-appointment calendar item assigned to them.
  List<CalendarOccurrence> kitchenMemberOccurrences(
    String memberId,
    String iso,
  ) {
    final out = <CalendarOccurrence>[];
    for (final ev in events) {
      if (!ev.kitchenOrigin && ev.layerId == kLayerAppt) continue;
      if (!_kitchenPasses(ev)) continue;
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

  /// [memberId]'s CALENDAR events for [iso] — the group that sits above the
  /// chores in their column (#332), rendered with the app's standard event
  /// anatomy. Anything already listed as a chore is skipped so nothing
  /// appears twice in one column.
  List<CalendarOccurrence> kitchenMemberEventOccurrences(
    String memberId,
    String iso,
  ) {
    final chores = {
      for (final o in kitchenMemberOccurrences(memberId, iso)) o.ev.id,
    };
    final out = <CalendarOccurrence>[
      for (final o in _kitchenDayOccurrences(iso))
        if (!chores.contains(o.ev.id) && o.ev.attendees.contains(memberId)) o,
    ];
    out.sort(_compareAgendaOccurrences);
    return out;
  }

  /// Every real/imported occurrence on [iso] that passes the wall's gate.
  List<CalendarOccurrence> _kitchenDayOccurrences(String iso) {
    final out = <CalendarOccurrence>[];
    for (final ev in events) {
      if (ev.kitchenOrigin) continue;
      if (!_kitchenPasses(ev)) continue;
      if (ev.recur == 'none') {
        final spanEnd =
            ev.endDate.isNotEmpty && ev.endDate.compareTo(ev.date) > 0
            ? ev.endDate
            : ev.date;
        if (spanEnd.compareTo(iso) >= 0 &&
            ev.date.compareTo(iso) <= 0 &&
            !ev.exceptions.contains(ev.date)) {
          out.add(
            CalendarOccurrence(
              ev: ev,
              date: ev.date,
              spanEnd: spanEnd,
              done: ev.todo && ev.done,
            ),
          );
        }
        continue;
      }
      for (final d in recurringEventDates(ev, iso, iso)) {
        out.add(
          CalendarOccurrence(ev: ev, date: d, done: ev.todo && ev.isDoneOn(d)),
        );
      }
    }
    for (final cal in importedCalendars) {
      if (!passesImported(cal, layers: kitchenLayerFilter)) continue;
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
    return out;
  }

  /// The left panel's schedule for [iso]: appointment-like occurrences only
  /// (to-dos live in the member columns), under the wall's layer filters.
  List<CalendarOccurrence> kitchenAppointmentOccurrences(String iso) {
    final out = <CalendarOccurrence>[
      for (final o in _kitchenDayOccurrences(iso))
        if (!o.isTask) o,
    ];
    out.sort(_compareAgendaOccurrences);
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

/// Gold reserved for the 5/5 claim-reward state (design §4a).
const LinearGradient kKitchenGoldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xfff6c344), Color(0xffe8a317)],
);
const Color kKitchenGoldInk = Color(0xff7a5200);
const Color kKitchenTileBg = Color(0xfffafbfc);
const Color kKitchenTileLine = Color(0xffeef1f5);

/// Full-screen kitchen wall: a fixed weekly-schedule panel on the left and
/// one column per family member on the right.
class _KitchenDashboardScreen extends StatefulWidget {
  const _KitchenDashboardScreen({required this.state});

  final _ThriveHomeState state;

  @override
  State<_KitchenDashboardScreen> createState() =>
      _KitchenDashboardScreenState();
}

class _KitchenDashboardScreenState extends State<_KitchenDashboardScreen> {
  _ThriveHomeState get state => widget.state;

  String _toast = '';
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_lockLandscapeOrientation());
    unawaited(_enterFullscreen());
    // A mounted wall reflects other devices' changes live: the shared state
    // bumps `_rev` on every local mutation AND on every cloud snapshot, and
    // this route re-derives everything from it (#337).
    state._rev.addListener(_refresh);
  }

  @override
  void dispose() {
    state._rev.removeListener(_refresh);
    _toastTimer?.cancel();
    unawaited(_lockPortraitOrientation());
    unawaited(_exitFullscreen());
    super.dispose();
  }

  /// The dashboard is pushed as its own route below the shared
  /// [_ThriveHomeState] in the widget tree, so its `setState`-driven
  /// rebuilds (via `mutate()`/`update()`) don't reach this route on their
  /// own. Re-deriving every occurrence/progress value from the same shared,
  /// mutated-in-place `events` on a local `setState()` keeps this screen
  /// live — whether the change came from this tablet or from another
  /// device's cloud snapshot.
  void _refresh() {
    if (mounted) setState(() {});
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toast = '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final members = state.curFamily()?.members ?? const <FamilyMember>[];
    final today = todayIso();

    return Scaffold(
      key: const ValueKey('kitchen-dashboard'),
      // The wall is edge-to-edge: no letterboxing frame around the panel, so
      // the Scaffold itself carries the panel colour and nothing darker can
      // show through at the screen edges.
      backgroundColor: const Color(0xffe8ecf1),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(color: Color(0xffe8ecf1)),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _KitchenLeftPanel(
                      key: const ValueKey('kitchen-left-panel'),
                      state: state,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: members.isEmpty
                          ? const Center(
                              child: Text(
                                'No family members yet',
                                style: TextStyle(color: B.muted, fontSize: 16),
                              ),
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final m in members)
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: m == members.last ? 0 : 12,
                                      ),
                                      child: _KitchenMemberColumn(
                                        key: ValueKey('kitchen-column-${m.id}'),
                                        state: state,
                                        member: m,
                                        today: today,
                                        onOccurrenceChanged: _refresh,
                                        onToast: _showToast,
                                      ),
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
              top: 14,
              right: 14,
              child: GestureDetector(
                key: const ValueKey('kitchen-dashboard-close'),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: B.ink.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: GestureDetector(
                key: const ValueKey('kitchen-quick-add-fab'),
                onTap: () async {
                  await state._showSheet(
                    (ctx) => _KitchenQuickAddSheet(
                      state: state,
                      members: members,
                      onToast: _showToast,
                    ),
                  );
                  _refresh();
                },
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xff12b3a4), B.primary, B.deep],
                      stops: [0.0, .55, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(19),
                    boxShadow: [
                      BoxShadow(
                        color: B.primary.withValues(alpha: .45),
                        blurRadius: 28,
                        spreadRadius: -10,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
            if (_toast.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: Center(
                  child: Container(
                    key: const ValueKey('kitchen-toast'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: B.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _toast,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Immersive fullscreen: the wall hides the status/navigation bars while
  /// mounted so the panel really is edge-to-edge, and the app's normal
  /// chrome comes back when the route pops.
  Future<void> _enterFullscreen() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  Future<void> _exitFullscreen() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

/// Left panel of the wall tablet: week number, today's date, then today and
/// the next six days (past days are never shown), with a thin week-break
/// divider when the ISO week rolls over.
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

    return Container(
      width: 252,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _weekNumberLabelIso(today).toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
              color: B.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            kitchenMainDateLabel(d),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
              color: B.ink,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'WEEKLY SCHEDULE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
              color: B.muted,
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showWeekBreak)
            Padding(
              key: ValueKey('kitchen-week-break-$iso'),
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 2),
              child: Row(
                children: [
                  const Expanded(child: Divider(height: 1, color: B.line)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _weekNumberLabelIso(iso).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                        color: Color(0xffb3bcc9),
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(height: 1, color: B.line)),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.fromLTRB(0, 4, 0, 1),
            padding: EdgeInsets.symmetric(
              horizontal: isToday ? 7 : 2,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: isToday ? const Color(0xffe7f5f3) : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              dayLabel,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isToday ? B.deep : B.muted,
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (appts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 6),
              child: Text(
                'Nothing planned',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xffb3bcc9),
                ),
              ),
            )
          else
            for (final o in appts)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _KitchenScheduleRow(
                  state: state,
                  occurrence: o,
                  iso: iso,
                ),
              ),
        ],
      ),
    );
  }
}

/// One appointment card in the left schedule: category-tinted background, a
/// 3px left rule in the category colour, a white time chip, a single-line
/// title and either the category glyph or up to three attendee avatars.
class _KitchenScheduleRow extends StatelessWidget {
  const _KitchenScheduleRow({
    required this.state,
    required this.occurrence,
    required this.iso,
  });

  final _ThriveHomeState state;
  final CalendarOccurrence occurrence;
  final String iso;

  @override
  Widget build(BuildContext context) {
    final ev = occurrence.ev;
    final category = state.catById(ev.category);
    final color = state.evColor(ev);
    final time = ev.allDay || ev.start.isEmpty ? 'All day' : ev.start;
    return Container(
      key: ValueKey('kitchen-schedule-row-${ev.id}-${occurrence.date}'),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        border: Border(left: BorderSide(color: color, width: 3)),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            constraints: const BoxConstraints(minWidth: 38),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              time,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              ev.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: B.ink,
              ),
            ),
          ),
          if (ev.attendees.isNotEmpty)
            _KitchenScheduleAttendees(
              key: ValueKey('kitchen-schedule-attendees-${ev.id}'),
              state: state,
              memberIds: ev.attendees,
            )
          else if (category != null)
            Padding(
              key: ValueKey('kitchen-schedule-category-${ev.id}'),
              padding: const EdgeInsets.only(left: 4),
              child: categoryGlyph(category, size: 14, iconColor: color),
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
    const size = 18.0;
    return SizedBox(
      width: size + (members.length - 1) * (size - 5),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < members.length; i++)
            Positioned(
              left: i * (size - 5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: state.avatarNode(
                  photo: members[i].photo,
                  emoji: members[i].emoji,
                  initials: members[i].initials,
                  color: members[i].color,
                  size: size - 3,
                  radius: (size - 3) / 2,
                  fs: 7,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One member's column: a 4px top rule in their colour, avatar/name/count
/// header, an animated progress bar, the star bar (or the gold claim
/// button), then their calendar events above their chores.
class _KitchenMemberColumn extends StatelessWidget {
  const _KitchenMemberColumn({
    super.key,
    required this.state,
    required this.member,
    required this.today,
    required this.onOccurrenceChanged,
    required this.onToast,
  });

  final _ThriveHomeState state;
  final FamilyMember member;
  final String today;

  /// Called after any tap on the column's content — cheap to call on every
  /// tap (not just the checkbox's) since it only triggers a `setState()` on
  /// the dashboard route to re-derive occurrences/progress from the shared,
  /// already-mutated `events` (see [_KitchenDashboardScreenState._refresh]).
  final VoidCallback onOccurrenceChanged;
  final void Function(String) onToast;

  @override
  Widget build(BuildContext context) {
    final occ = state.kitchenMemberOccurrences(member.id, today);
    final events = state.kitchenMemberEventOccurrences(member.id, today);
    final progress = state.kitchenMemberProgress(member.id, today);
    final stars = state.starsFor(member.id);
    final canClaim = stars >= 5;
    final pictureMode = state.pictureModeFor(member.id);

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(top: BorderSide(color: member.color, width: 4)),
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
                size: 30,
                radius: 15,
                fs: 11,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  member.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: B.ink,
                  ),
                ),
              ),
              // A narrow column must never render-overflow on a wall
              // tablet: the count scales itself down instead.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${progress.completed}/${progress.total}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: member.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _KitchenProgressBadge(
            key: ValueKey('kitchen-progress-${member.id}'),
            completed: progress.completed,
            total: progress.total,
            color: member.color,
          ),
          const SizedBox(height: 7),
          if (canClaim)
            GestureDetector(
              key: ValueKey('kitchen-claim-${member.id}'),
              onTap: () {
                state.claimMemberReward(member.id);
                onToast('Reward claimed — well earned, ${member.name}! 🎉');
                onOccurrenceChanged();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: kKitchenGoldGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffe8a317).withValues(alpha: .5),
                      blurRadius: 18,
                      spreadRadius: -8,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '🏆 Claim reward!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kKitchenGoldInk,
                    ),
                  ),
                ),
              ),
            )
          else
            _KitchenStarRow(
              key: ValueKey('kitchen-stars-${member.id}'),
              memberId: member.id,
              stars: stars,
            ),
          const SizedBox(height: 8),
          Expanded(
            child: (occ.isEmpty && events.isEmpty)
                ? const Center(
                    child: Text(
                      'Free day 🎈',
                      style: TextStyle(color: B.muted, fontSize: 13),
                    ),
                  )
                : ListView(
                    key: ValueKey('kitchen-list-${member.id}'),
                    padding: EdgeInsets.zero,
                    children: [
                      for (final o in events) ...[
                        state._evPill(
                          o,
                          iso: today,
                          keyPrefix: 'kitchen-event-${member.id}',
                        ),
                        const SizedBox(height: 6),
                      ],
                      // The divider only earns its place when the column
                      // actually has both groups (design §4a).
                      if (events.isNotEmpty && occ.isNotEmpty)
                        Padding(
                          key: ValueKey('kitchen-chores-divider-${member.id}'),
                          padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Divider(
                                  height: 1,
                                  color: kKitchenTileLine,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 7),
                                child: Text(
                                  'CHORES',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .7,
                                    color: Color(0xffc3ccd6),
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(
                                  height: 1,
                                  color: kKitchenTileLine,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (pictureMode)
                        for (final o in occ)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _KitchenPictureTile(
                              key: ValueKey('kitchen-pic-tile-${o.ev.id}'),
                              state: state,
                              occ: o,
                              member: member,
                              onChanged: onOccurrenceChanged,
                              onToast: onToast,
                            ),
                          )
                      else
                        for (final o in occ)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: _KitchenTextTile(
                              state: state,
                              occ: o,
                              member: member,
                              onChanged: onOccurrenceChanged,
                              onToast: onToast,
                            ),
                          ),
                    ],
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
    required this.onToast,
  });

  final _ThriveHomeState state;
  final CalendarOccurrence occ;
  final FamilyMember member;
  final VoidCallback onChanged;
  final void Function(String) onToast;

  @override
  Widget build(BuildContext context) {
    final ev = occ.ev;
    final layer = _kitchenLayerDefFor(state, occ.layer);
    final done = occ.done;

    void toggle() {
      state.kitchenToggleChore(occ, member.id);
      onChanged();
    }

    return GestureDetector(
      onTap: toggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: kKitchenTileBg,
          border: Border.all(color: kKitchenTileLine),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              key: ValueKey('event-check-${ev.id}-${occ.date}'),
              onTap: toggle,
              child: Container(
                width: 22,
                height: 22,
                // ≥44px effective target at arm's length on a tablet.
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? member.color : Colors.white,
                  border: Border.all(
                    color: done ? member.color : const Color(0xffcbd5e1),
                    width: 2,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ev.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: done ? B.muted : B.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (layer != null)
                        _kitchenChip(
                          layer.label,
                          layer.color,
                          layer.color.withValues(alpha: .08),
                        ),
                      if (ev.recur != 'none')
                        _kitchenChip('↻ repeats', B.muted, B.faint),
                    ],
                  ),
                ],
              ),
            ),
            // Only kitchen-created items can be taken off the wall here;
            // app-created items are managed from the phone's calendar.
            if (ev.kitchenOrigin) ...[
              const SizedBox(width: 6),
              GestureDetector(
                key: ValueKey('kitchen-remove-${ev.id}'),
                onTap: () {
                  state.deleteKitchenItem(ev.id);
                  onToast('Taken off the wall');
                  onChanged();
                },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xfff1f5f9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close, size: 13, color: B.muted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _kitchenChip(String label, Color ink, Color bg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
  child: Text(
    label,
    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: ink),
  ),
);

/// Display-only star bar — stars are EARNED by ticking chores (#333), never
/// set by tapping. At 5/5 the column swaps this row for the gold claim
/// button instead.
class _KitchenStarRow extends StatelessWidget {
  const _KitchenStarRow({
    super.key,
    required this.memberId,
    required this.stars,
  });

  final String memberId;
  final int stars;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Padding(
              key: ValueKey('kitchen-star-$memberId-$i'),
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                i <= stars ? Icons.star : Icons.star_border,
                size: 14,
                color: i <= stars ? const Color(0xffe8a827) : B.muted,
              ),
            ),
        ],
      ),
    );
  }
}

/// Picture-mode tile for pre-readers (#335): a big photo with the title
/// small beneath. Tapping ANYWHERE toggles done — done tints the card in the
/// member's colour, greys the image and puts a ✓ badge top-right.
class _KitchenPictureTile extends StatelessWidget {
  const _KitchenPictureTile({
    super.key,
    required this.state,
    required this.occ,
    required this.member,
    required this.onChanged,
    required this.onToast,
  });

  final _ThriveHomeState state;
  final CalendarOccurrence occ;
  final FamilyMember member;
  final VoidCallback onChanged;
  final void Function(String) onToast;

  Future<void> _openGlyphPicker(BuildContext context) async {
    await state._showSheet(
      (ctx) => _KitchenItemGlyphSheet(state: state, event: occ.ev),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final ev = occ.ev;
    final done = occ.done;
    final color = member.color;
    final hasGlyph =
        (ev.picture?.isNotEmpty ?? false) || (ev.emoji?.isNotEmpty ?? false);
    return Stack(
      children: [
        GestureDetector(
          key: ValueKey('kitchen-pic-check-${ev.id}'),
          onTap: () {
            state.kitchenToggleChore(occ, member.id);
            onChanged();
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
            decoration: BoxDecoration(
              color: done ? color.withValues(alpha: .07) : kKitchenTileBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: done ? color : kKitchenTileLine,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: done ? .5 : 1,
                  child: SizedBox(
                    height: 74,
                    child: glyphTile(
                      size: 74,
                      radius: 11,
                      picture: ev.picture,
                      emoji: ev.emoji,
                      emojiSize: 46,
                      fallback: Center(
                        child: Icon(
                          hasGlyph ? Icons.edit : Icons.add_photo_alternate,
                          color: B.muted,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  ev.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: done ? B.muted : B.text,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (done)
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 12, color: Colors.white),
            ),
          ),
        if (ev.kitchenOrigin) ...[
          Positioned(
            top: 7,
            left: 7,
            child: GestureDetector(
              key: ValueKey('kitchen-remove-${ev.id}'),
              onTap: () {
                state.deleteKitchenItem(ev.id);
                onToast('Taken off the wall');
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
          if (!done)
            Positioned(
              bottom: 7,
              right: 7,
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
      ],
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

/// "Add to the wall" (#334): assignee chips tinted in the member's colour,
/// a REQUIRED photo step for picture-mode members (no emoji shortcut — a
/// pre-reader needs a real photo), a title field, and "Add for today".
class _KitchenQuickAddSheet extends StatefulWidget {
  const _KitchenQuickAddSheet({
    required this.state,
    required this.members,
    this.onToast,
  });

  final _ThriveHomeState state;
  final List<FamilyMember> members;
  final void Function(String)? onToast;

  @override
  State<_KitchenQuickAddSheet> createState() => _KitchenQuickAddSheetState();
}

class _KitchenQuickAddSheetState extends State<_KitchenQuickAddSheet> {
  final _title = TextEditingController();
  final _picker = ImagePicker();
  String? _assignee;
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

  bool get _pictureMode =>
      _assignee != null && widget.state.pictureModeFor(_assignee!);

  String get _assigneeName {
    for (final m in widget.members) {
      if (m.id == _assignee) return m.name;
    }
    return 'they';
  }

  // coverage:ignore-start
  Future<void> _takePhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 700,
        maxHeight: 700,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _picture = base64Encode(bytes));
    } catch (_) {
      /* ignore an unreadable image */
    }
  }
  // coverage:ignore-end

  Widget _photoBtn(Key key, String label, ImageSource source) {
    return Expanded(
      child: GestureDetector(
        key: key,
        onTap: () => _takePhoto(source),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kKitchenTileBg,
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundDecoration: const _DottedBoxDecoration(
            color: Color(0xffcbd5e1),
            radius: 14,
            width: 2,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: B.text,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _picture?.isNotEmpty ?? false;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(
            context,
            'Add to the wall',
            'Lands as an all-day kitchen item, due today.',
          ),
          _sheetField(
            'Who is it for?',
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in widget.members)
                  GestureDetector(
                    key: ValueKey('kitchen-add-assignee-${m.id}'),
                    onTap: () => setState(() => _assignee = m.id),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(5, 6, 11, 6),
                      decoration: BoxDecoration(
                        color: _assignee == m.id
                            ? m.color.withValues(alpha: .08)
                            : Colors.white,
                        border: Border.all(
                          color: _assignee == m.id ? m.color : B.line,
                          width: 1.5,
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
                            size: 20,
                            radius: 10,
                            fs: 9,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _assignee == m.id ? m.color : B.soft2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_pictureMode)
            _sheetField(
              'Add a photo — $_assigneeName reads pictures, not words',
              hasPhoto
                  ? Container(
                      key: const ValueKey('kitchen-add-photo-ready'),
                      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                      decoration: BoxDecoration(
                        color: B.soft,
                        border: Border.all(color: B.primary, width: 1.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: glyphTile(
                              size: 44,
                              radius: 9,
                              picture: _picture,
                              emoji: null,
                              emojiSize: 20,
                              fallback: const SizedBox.shrink(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Photo ready ✓',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: B.deep,
                              ),
                            ),
                          ),
                          GestureDetector(
                            key: const ValueKey('kitchen-add-photo-retake'),
                            onTap: () => setState(() => _picture = null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Text(
                                'Retake',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: B.soft2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      key: const ValueKey('kitchen-add-photo-choose'),
                      children: [
                        _photoBtn(
                          const ValueKey('kitchen-add-photo-camera'),
                          '📷 Take a photo',
                          ImageSource.camera,
                        ),
                        const SizedBox(width: 8),
                        _photoBtn(
                          const ValueKey('kitchen-add-photo-library'),
                          '🖼 From library',
                          ImageSource.gallery,
                        ),
                      ],
                    ),
            ),
          _sheetField(
            _pictureMode ? 'Name it (shown under the photo)' : 'Title',
            _sheetInput(
              _title,
              hint: _pictureMode
                  ? 'e.g. Tidy toys'
                  : 'What needs doing? e.g. Set the table',
              onChanged: (_) => setState(() {}),
            ),
          ),
          _primaryBtn('Add for today', () {
            final name = _title.text.trim();
            if (name.isEmpty) {
              widget.onToast?.call('Give it a name first');
              return;
            }
            if (_pictureMode && !hasPhoto) {
              widget.onToast?.call('Add a photo first');
              return;
            }
            widget.state.createKitchenItem(
              title: name,
              assignee: _assignee!,
              picture: _picture,
            );
            widget.onToast?.call('On the wall — due today');
            Navigator.of(context).pop();
          }, enabled: _assignee != null),
        ],
      ),
    );
  }
}

/// Thin rounded progress bar for completed-vs-total chores today, animating
/// as chores get ticked (#336).
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
        height: 5,
        child: Stack(
          children: [
            Container(color: kKitchenTileLine),
            LayoutBuilder(
              builder: (context, constraints) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: constraints.maxWidth * pct,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
