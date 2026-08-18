part of 'package:family_money_management_app/main.dart';

/// Kitchen-tablet dashboard (Calendar Layers design): a landscape,
/// high-contrast, large-touch-target full-screen view with one column per
/// family member showing today's schedule across all three calendar layers
/// (appointments/to-dos/content) plus a live completed-vs-total "star"
/// progress indicator. No persisted state of its own — everything here is
/// computed on the fly from the shared [_ThriveHomeState] (`taskLists`,
/// `events`, `eventOccurrences`).
extension _ThriveKitchenDashboard on _ThriveHomeState {
  void openKitchenDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _KitchenDashboardScreen(state: this)),
    );
  }

  /// Whether [task] (owned by [list]) is due — or, if recurring, has an
  /// occurrence — on [iso].
  bool _kitchenTaskDueOn(TaskList list, ListTask task, String iso) {
    final due = task.due;
    if (due == null || due.isEmpty) return false;
    if (task.recur == 'none') return due == iso;
    return recurringEventDates(
      taskSyntheticEvent(list, task),
      iso,
      iso,
    ).isNotEmpty;
  }

  /// Completed-vs-total task/content count for [memberId] on [iso]
  /// (defaults to today), for the star/progress indicator. `total` includes
  /// both what's already done (`completed`) and what's still outstanding
  /// (surfaced via [eventOccurrences], which already excludes done
  /// occurrences).
  ({int completed, int total}) kitchenMemberProgress(
    String memberId, [
    String? iso,
  ]) {
    final today = iso ?? todayIso();
    var completed = 0;
    for (final list in taskLists) {
      for (final task in list.tasks) {
        if (task.assignee != memberId) continue;
        if (!_kitchenTaskDueOn(list, task, today)) continue;
        if (task.isDoneOn(today)) completed++;
      }
    }
    final outstanding = eventOccurrences(today, today)
        .where(
          (o) =>
              (o.layer == 'task' || o.layer == 'content') &&
              o.ev.attendees.contains(memberId),
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
  /// mutated-in-place `taskLists`/`events` on a local `setState()` after
  /// each checkbox tap keeps this screen live without any state of its own.
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final members = state.curFamily()?.members ?? const <FamilyMember>[];
    final today = todayIso();

    return Scaffold(
      key: const ValueKey('kitchen-dashboard'),
      backgroundColor: B.ink,
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
  /// already-mutated `taskLists` (see [_KitchenDashboardScreenState._refresh]).
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
                  (o.layer == 'task' || o.layer == 'content'),
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
                : Listener(
                    // A raw pointer listener (rather than a GestureDetector)
                    // so it observes every tap inside the list — including
                    // the checkbox `_eventCard` renders for task/content
                    // tiles — without competing for the tap in the gesture
                    // arena. The checkbox's own `onTap` (in `_eventCard`)
                    // mutates `taskLists` synchronously, so by the time this
                    // pointer-up fires the mutation has already happened;
                    // the microtask just lets that handler run first.
                    onPointerUp: (_) => Future.microtask(onOccurrenceChanged),
                    child: ListView.separated(
                      key: ValueKey('kitchen-list-${member.id}'),
                      itemCount: occ.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => occ[i].layer == 'content'
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
                    ),
                  ),
          ),
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
