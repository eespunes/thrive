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
    final outstanding = eventOccurrences(today, today).where(
      (o) =>
          (o.layer == 'task' || o.layer == 'content') &&
          o.ev.attendees.contains(memberId),
    ).length;
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
              child: members.isEmpty
                  ? const Center(
                      child: Text(
                        'No family members yet',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
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
            ),
          ],
        ),
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
    final occ =
        state.eventOccurrences(today, today).where(
          (o) => o.ev.attendees.contains(member.id),
        ).toList()
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
                    onPointerUp: (_) =>
                        Future.microtask(onOccurrenceChanged),
                    child: ListView.separated(
                      key: ValueKey('kitchen-list-${member.id}'),
                      itemCount: occ.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => state._eventCard(occ[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Star/progress badge showing completed-vs-total tasks/content for a
/// member today — computed live, no persisted state.
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
    final allDone = total > 0 && completed == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: allDone ? color.withValues(alpha: .14) : B.faint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            allDone ? Icons.star : Icons.star_border,
            size: 18,
            color: allDone ? color : B.muted,
          ),
          const SizedBox(width: 6),
          Text(
            '$completed/$total today',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: allDone ? color : B.soft2,
            ),
          ),
        ],
      ),
    );
  }
}
