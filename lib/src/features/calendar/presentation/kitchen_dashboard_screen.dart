part of 'package:family_money_management_app/main.dart';

/// Kitchen-tablet dashboard (Calendar Layers design): a landscape,
/// high-contrast, large-touch-target full-screen view with one column per
/// family member showing today's schedule across all three calendar layers
/// (appointments/to-dos/content) plus a live completed-vs-total "star"
/// progress indicator. No persisted state of its own — everything here is
/// computed on the fly from the shared [_ThriveHomeState] (`events`,
/// `eventOccurrences`).
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
  /// "Kitchen dashboard" row hides from More (see `_ThriveMoreScreen`).
  void toggleKitchenEnabled() {
    mutate(() => kitchenEnabled = !kitchenEnabled);
  }

  /// Whether [memberId]'s column renders large photo tiles instead of
  /// text/checkbox rows. Missing memberId defaults to `false`.
  bool pictureModeFor(String memberId) => picMembers[memberId] ?? false;

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
  /// an appointment) due today, visible immediately both on this dashboard
  /// and — since to-dos/content are just [CalendarEvent]s — on the phone's
  /// Agenda/Month views.
  void createKitchenItem({
    required String title,
    required String assignee,
    required String layerId,
  }) {
    mutate(() {
      events.add(
        CalendarEvent(
          id: uid(),
          title: title.trim().isEmpty ? 'Untitled' : title.trim(),
          allDay: true,
          date: todayIso(),
          color: layerDefFor(layerId)?.color ?? B.primary,
          attendees: [assignee],
          layerId: layerId,
          createdBy: myId,
          kitchenOrigin: true,
        ),
      );
    }, () => flash('Added'));
  }

  /// Attaches/clears a picture-mode photo on a kitchen-origin item.
  void setKitchenItemPicture(String id, String? picture) {
    mutate(() {
      final ev = eventById(id);
      if (ev == null || !ev.kitchenOrigin) return;
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
  /// (defaults to today), for the star/progress indicator. `total` includes
  /// both what's already done (`completed`) and what's still outstanding —
  /// [eventOccurrences] no longer excludes done occurrences (issue:
  /// calendar layers done-but-visible), so `outstanding` explicitly filters
  /// them back out here to avoid double-counting.
  ({int completed, int total}) kitchenMemberProgress(
    String memberId, [
    String? iso,
  ]) {
    final today = iso ?? todayIso();
    var completed = 0;
    for (final ev in events) {
      if (ev.layerId == 'appt') continue;
      if (!ev.attendees.contains(memberId)) continue;
      if (!_kitchenEventDueOn(ev, today)) continue;
      if (ev.isDoneOn(today)) completed++;
    }
    final outstanding = eventOccurrences(today, today)
        .where(
          (o) =>
              o.layer != 'appt' && o.ev.attendees.contains(memberId) && !o.done,
        )
        .length;
    return (completed: completed, total: completed + outstanding);
  }
}

/// Full-screen kitchen-tablet dashboard: one column per family member, each
/// showing today's occurrences as tiles (reusing the calendar's existing
/// appt/task/content card styling via [_ThriveCalendarScreens._eventCard])
/// under a large avatar/name header with a completed-vs-total star badge.
class _KitchenDashboardScreen extends StatefulWidget {
  const _KitchenDashboardScreen({required this.state});

  final _ThriveHomeState state;

  @override
  State<_KitchenDashboardScreen> createState() =>
      _KitchenDashboardScreenState();
}

class _KitchenDashboardScreenState extends State<_KitchenDashboardScreen> {
  _ThriveHomeState get state => widget.state;

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
      backgroundColor: B.ink,
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('kitchen-quick-add-fab'),
        backgroundColor: B.primary,
        onPressed: () async {
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
                child: _KitchenQuickAddSheet(state: state, members: members),
              ),
            ),
          );
          _refresh();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('kitchen-dashboard-close'),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _prettyDateIso(today),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KitchenLeftPanel(
                      key: const ValueKey('kitchen-left-panel'),
                      state: state,
                    ),
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: Colors.white.withValues(alpha: .16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: members.isEmpty
                          ? const Center(
                              child: Text(
                                'No family members yet',
                                style: TextStyle(
                                  color: Colors.white,
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
          ],
        ),
      ),
    );
  }
}

/// Left panel of the wall-tablet dashboard: "Week of" header plus a
/// scrollable list of this week's day-groups, each showing that day's
/// appointment-layer occurrences only (`tabletApp()`'s left column in the
/// Calendar Layers design) — to-dos/content live exclusively in the member
/// columns on the right.
class _KitchenLeftPanel extends StatelessWidget {
  const _KitchenLeftPanel({super.key, required this.state});

  final _ThriveHomeState state;

  @override
  Widget build(BuildContext context) {
    final today = todayIso();
    final weekStart = _startOfWeekIso(today);
    final days = [for (var i = 0; i < 7; i++) _addDaysIso(weekStart, i)];
    final d = _parseIso(today);

    return SizedBox(
      width: 230,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WEEK OF',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${d.day} ${kMonthsEn[d.month - 1]}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'WEEKLY SCHEDULE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              key: const ValueKey('kitchen-week-schedule'),
              children: [for (final iso in days) _dayGroup(iso, today)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayGroup(String iso, String today) {
    final appts =
        state
            .eventOccurrences(iso, iso)
            .where((o) => o.layer == 'appt')
            .toList()
          ..sort(
            (a, b) => (a.ev.allDay ? '' : a.ev.start).compareTo(
              b.ev.allDay ? '' : b.ev.start,
            ),
          );
    if (appts.isEmpty) return const SizedBox.shrink();

    final isToday = iso == today;
    final d = _parseIso(iso);
    final weekday = kWeekdayLetters[d.weekday - 1];
    return Padding(
      key: ValueKey('kitchen-day-group-$iso'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${isToday ? 'Today · ' : ''}$weekday ${d.day}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
              color: isToday ? B.primary : Colors.white54,
            ),
          ),
          const SizedBox(height: 6),
          for (final o in appts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: state._apptAgendaRow(o),
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
    // Right-panel member columns show today's to-do/content occurrences
    // only — appointments now live exclusively in the left week panel
    // (Calendar Layers design: `kColumn()` filters to `task`/`content`).
    final occ =
        state
            .eventOccurrences(today, today)
            .where(
              (o) =>
                  o.ev.attendees.contains(member.id) &&
                  o.layer != 'appt' &&
                  !o.done,
            )
            .toList()
          ..sort(
            (a, b) => (a.ev.allDay ? '' : a.ev.start).compareTo(
              b.ev.allDay ? '' : b.ev.start,
            ),
          );
    final progress = state.kitchenMemberProgress(member.id, today);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: member.color, width: 2.5),
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
                size: 48,
                radius: 24,
                fs: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  member.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: member.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _KitchenStarRow(
            key: ValueKey('kitchen-stars-${member.id}'),
            state: state,
            memberId: member.id,
            onChanged: onOccurrenceChanged,
          ),
          const SizedBox(height: 10),
          _KitchenProgressBadge(
            key: ValueKey('kitchen-progress-${member.id}'),
            completed: progress.completed,
            total: progress.total,
            color: member.color,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: occ.isEmpty
                ? Center(
                    child: Text(
                      'Nothing scheduled today',
                      style: TextStyle(color: B.muted, fontSize: 13),
                    ),
                  )
                : state.pictureModeFor(member.id)
                ? GridView.builder(
                    key: ValueKey('kitchen-grid-${member.id}'),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                    itemCount: occ.length,
                    itemBuilder: (context, i) => _KitchenPictureTile(
                      key: ValueKey('kitchen-pic-tile-${occ[i].ev.id}'),
                      state: state,
                      occ: occ[i],
                      color: member.color,
                      onChanged: onOccurrenceChanged,
                    ),
                  )
                : Listener(
                    // A raw pointer listener (rather than a GestureDetector)
                    // so it observes every tap inside the list — including
                    // the checkbox `_eventCard` renders for task/content
                    // tiles — without competing for the tap in the gesture
                    // arena. The checkbox's own `onTap` (in `_eventCard`)
                    // mutates `events` synchronously, so by the time this
                    // pointer-up fires the mutation has already happened;
                    // the microtask just lets that handler run first.
                    onPointerUp: (_) => Future.microtask(onOccurrenceChanged),
                    child: ListView.separated(
                      key: ValueKey('kitchen-list-${member.id}'),
                      itemCount: occ.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => Stack(
                        children: [
                          occ[i].layer != 'task'
                              ? state._contentAgendaRow(
                                  occ[i],
                                  checkColor: member.color,
                                  showAvatar: false,
                                )
                              : state._taskAgendaRow(
                                  occ[i],
                                  checkColor: member.color,
                                  showAvatar: false,
                                ),
                          if (occ[i].ev.kitchenOrigin)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                key: ValueKey('kitchen-remove-${occ[i].ev.id}'),
                                onTap: () {
                                  state.deleteKitchenItem(occ[i].ev.id);
                                  onOccurrenceChanged();
                                },
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: B.line),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 13,
                                    color: B.muted,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
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
    if (stars >= 5) {
      return GestureDetector(
        key: ValueKey('kitchen-claim-$memberId'),
        onTap: () {
          state.claimMemberReward(memberId);
          onChanged();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xfffff7ed),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xfffdba74)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.card_giftcard, size: 16, color: Color(0xffea580c)),
              SizedBox(height: 2),
              Text(
                'Claim reward!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xffea580c),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            key: ValueKey('kitchen-star-$memberId-$i'),
            onTap: () {
              state.setMemberStars(memberId, i);
              onChanged();
            },
            child: Icon(
              i <= stars ? Icons.star : Icons.star_border,
              size: 16,
              color: i <= stars ? const Color(0xfff59e0b) : B.faint,
            ),
          ),
      ],
    );
  }
}

/// Large square photo tile for picture-mode columns (pre-readers): just a
/// photo with a checkmark overlay to mark done — no text. A kitchen-origin
/// item without a photo yet shows a placeholder instead so a parent can tap
/// it to attach one.
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

  // coverage:ignore-start
  Future<void> _pickPhoto() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      state.setKitchenItemPicture(occ.ev.id, base64Encode(bytes));
      onChanged();
    } catch (_) {
      /* ignore an unreadable image */
    }
  }
  // coverage:ignore-end

  @override
  Widget build(BuildContext context) {
    final ev = occ.ev;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          key: ValueKey('kitchen-pic-set-${ev.id}'),
          onTap: ev.kitchenOrigin ? _pickPhoto : null,
          child: Container(
            decoration: BoxDecoration(
              color: B.faint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 2),
              image: ev.picture != null
                  ? DecorationImage(
                      image: MemoryImage(base64Decode(ev.picture!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: ev.picture == null
                ? const Center(child: Icon(Icons.image, color: B.muted))
                : null,
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(Icons.check, color: color, size: 18),
            ),
          ),
        ),
        if (ev.kitchenOrigin)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              key: ValueKey('kitchen-remove-${ev.id}'),
              onTap: () {
                state.deleteKitchenItem(ev.id);
                onChanged();
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 13, color: B.muted),
              ),
            ),
          ),
      ],
    );
  }
}

/// Floating "+" quick-add sheet: title, assignee (member picker), and type
/// (any non-`appt` layer — appointments aren't chore/content tiles). Creates
/// a kitchen-origin [CalendarEvent] due today via
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
  String? _layerId;

  @override
  void initState() {
    super.initState();
    _assignee = widget.members.isNotEmpty ? widget.members.first.id : null;
    final layers = widget.state.calendarLayers.where((l) => l.id != 'appt');
    _layerId = layers.isNotEmpty ? layers.first.id : null;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layers = widget.state.calendarLayers
        .where((l) => l.id != 'appt')
        .toList();
    final valid =
        _title.text.trim().isNotEmpty && _assignee != null && _layerId != null;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(context, 'Add item', 'Shows up in their column today.'),
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
                    onTap: () => setState(() => _assignee = m.id),
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
          _sheetField(
            'Type',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in layers)
                  GestureDetector(
                    key: ValueKey('kitchen-add-layer-${l.id}'),
                    onTap: () => setState(() => _layerId = l.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _layerId == l.id ? B.soft : Colors.white,
                        border: Border.all(
                          color: _layerId == l.id ? B.primary : B.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _layerId == l.id ? B.deep : B.soft2,
                        ),
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
              layerId: _layerId!,
            );
            Navigator.of(context).pop();
          }, enabled: valid),
        ],
      ),
    );
  }
}

/// Progress indicator showing completed-vs-total tasks/content for a member
/// today — computed live, no persisted state. Mirrors `kColumn()`'s header:
/// a row of 3 stars (filled up to `min(completed, 3)`) plus a "$done/$total"
/// fraction count, and a thin rounded percentage-fill bar underneath.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  i < completed ? Icons.star : Icons.star_border,
                  size: 14,
                  color: i < completed ? color : B.muted,
                ),
              ),
            const Spacer(),
            Text(
              '$completed/$total',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
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
        ),
      ],
    );
  }
}
