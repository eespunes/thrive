part of 'package:family_money_management_app/main.dart';

const List<String> _kWeekdaysFull = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const double _kHomeTodayEventRowHeight = 66;
const double _kHomeTodayEventGap = 8;
const double _kHomeTaskRowHeight = 56;
const double _kHomeTaskGap = 0;

/// The Home dashboard (#158): today's events, tasks due soon, a shopping
/// glance, tonight's dinner and the projected balance. Ported from the
/// design's `renderHome()` / `homeCard()` / `glanceCard()` / `miniTaskRow()`.
///
/// Today's events, tasks, shopping, today's dinner (#157) and
/// projected balance are all real.
extension _ThriveHomeScreen on _ThriveHomeState {
  String firstName() {
    final name = user?.name.trim() ?? '';
    if (name.isEmpty) return 'there';
    final first = name.split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'there' : first;
  }

  String prettyToday() {
    final now = DateTime.now();
    return '${_kWeekdaysFull[now.weekday - 1]}, ${now.day} ${kMonthsEn[now.month - 1]}';
  }

  Widget _buildHomeDashboard() {
    final myTaskAssignees = _homeCurrentUserMemberIds();
    final openTasks = <(TaskList, ListTask)>[];
    for (final l in taskLists) {
      for (final t in l.tasks) {
        if (!t.done && myTaskAssignees.contains(t.assignee)) {
          openTasks.add((l, t));
        }
      }
    }
    final c = compute(monthIdx);
    final todayEvents = _homeTodayEvents();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        _homeCard(
          title: "Today's events",
          icon: 'cal',
          onOpen: () => goTab('calendar'),
          body: todayEvents.isEmpty
              ? _emptyRow('Nothing scheduled — enjoy the calm.')
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: _homeTodayEventsViewportHeight(todayEvents),
                  ),
                  child: SingleChildScrollView(
                    key: const ValueKey('home-today-events-scroll'),
                    child: Column(
                      key: const ValueKey('home-today-events-list'),
                      children: [
                        for (var i = 0; i < todayEvents.length; i++) ...[
                          SizedBox(
                            height: _kHomeTodayEventRowHeight,
                            child: _apptAgendaRow(
                              todayEvents[i],
                              rowKeyPrefix: 'home-event',
                            ),
                          ),
                          if (i != todayEvents.length - 1)
                            const SizedBox(height: _kHomeTodayEventGap),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
        _homeCard(
          title: 'Open tasks',
          icon: 'tasklist',
          onOpen: () => goTab('lists'),
          body: openTasks.isEmpty
              ? _emptyRow('All caught up. Nice work!')
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: _homeTaskViewportHeight(openTasks),
                  ),
                  child: SingleChildScrollView(
                    key: const ValueKey('home-tasks-scroll'),
                    child: Column(
                      key: const ValueKey('home-tasks-list'),
                      children: [
                        for (var i = 0; i < openTasks.length; i++) ...[
                          SizedBox(
                            height: _kHomeTaskRowHeight,
                            child: _miniTaskRow(
                              openTasks[i].$1,
                              openTasks[i].$2,
                              border: i > 0,
                            ),
                          ),
                          if (i != openTasks.length - 1)
                            const SizedBox(height: _kHomeTaskGap),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _glanceCard(
                    title: 'Shopping',
                    icon: 'cart',
                    onOpen: () => goTab('lists'),
                    body: shoppingLists.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'No lists yet',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: B.muted,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final l in shoppingLists.take(2))
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: B.text,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: B.soft,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${l.items.where((i) => !i.checked).length}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: B.primary,
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
                const SizedBox(width: 12),
                Expanded(
                  child: _glanceCard(
                    title: "Today's dinner",
                    icon: 'moon',
                    onOpen: () => goTab('weekly'),
                    body: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        dayPlan(todayIso())?.dinner ?? 'Not planned',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: B.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: () => goTab('finance'),
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: B.grad,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: B.primary.withValues(alpha: .45),
                  blurRadius: 30,
                  spreadRadius: -16,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PROJECTED BALANCE · ${kMonthsEn[monthIdx].toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                          color: Colors.white.withValues(alpha: .85),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        eur(c.balance),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${eur(c.stillToPay)} still to pay',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: .9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: ic('cright', size: 22, sw: 2.4, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _homeCard({
    required String title,
    required String icon,
    required VoidCallback onOpen,
    required Widget body,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: B.soft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: ic(icon, size: 16, sw: 2.1, color: B.primary),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: B.ink,
                      ),
                    ),
                  ),
                  ic('cright', size: 17, sw: 2.2, color: B.muted),
                ],
              ),
            ),
          ),
          body,
        ],
      ),
    );
  }

  Widget _glanceCard({
    required String title,
    required String icon,
    required VoidCallback onOpen,
    required Widget body,
  }) {
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: B.line),
          borderRadius: BorderRadius.circular(18),
          boxShadow: cardShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: B.soft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: ic(icon, size: 14, sw: 2.1, color: B.primary),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: B.soft2,
                  ),
                ),
              ],
            ),
            body,
          ],
        ),
      ),
    );
  }

  Widget _emptyRow(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: B.muted,
      ),
    ),
  );

  double _homeTodayEventsViewportHeight(List<CalendarOccurrence> events) {
    final visibleRows = events.length < 3 ? events.length : 3;
    final visibleGaps = visibleRows > 0 ? visibleRows - 1 : 0;
    return visibleRows * _kHomeTodayEventRowHeight +
        visibleGaps * _kHomeTodayEventGap;
  }

  double _homeTaskViewportHeight(List<(TaskList, ListTask)> tasks) {
    final visibleRows = tasks.length < 3 ? tasks.length : 3;
    final visibleGaps = visibleRows > 0 ? visibleRows - 1 : 0;
    return visibleRows * _kHomeTaskRowHeight + visibleGaps * _kHomeTaskGap;
  }

  List<CalendarOccurrence> _homeTodayEvents() {
    final today = todayIso();
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    return (eventOccurrences(today, today)..sort(_compareAgendaOccurrences))
        .where((o) => _homeOccurrenceIsNotPast(o, today, nowMinutes))
        .toList();
  }

  bool _homeOccurrenceIsNotPast(
    CalendarOccurrence occurrence,
    String today,
    int nowMinutes,
  ) {
    final ev = occurrence.ev;
    if (occurrence.isMultiDay && occurrence.spanEnd.compareTo(today) > 0) {
      return true;
    }
    if (ev.allDay) return true;
    final compareTime = ev.end.isNotEmpty ? ev.end : ev.start;
    final eventMinutes = _homeTimeToMinutes(compareTime);
    if (eventMinutes == null) return true;
    return eventMinutes >= nowMinutes;
  }

  Set<String> _homeCurrentUserMemberIds() {
    final ids = <String>{myId, 'me'};
    final email = user?.email.trim().toLowerCase() ?? '';
    if (email.isNotEmpty) ids.add(email);
    for (final member in curFamily()?.members ?? const <FamilyMember>[]) {
      final memberEmail = member.email.trim().toLowerCase();
      if (member.id == myId ||
          member.uid == myId ||
          (email.isNotEmpty && memberEmail == email)) {
        ids.add(member.id);
        if (member.uid != null && member.uid!.trim().isNotEmpty) {
          ids.add(member.uid!.trim());
        }
        if (memberEmail.isNotEmpty) ids.add(memberEmail);
      }
    }
    return ids;
  }

  int? _homeTimeToMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  Widget _miniTaskRow(TaskList list, ListTask t, {required bool border}) {
    return Container(
      decoration: BoxDecoration(
        border: border ? const Border(top: BorderSide(color: B.faint)) : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => toggleTask(list.id, t.id),
            child: Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                color: t.done ? B.primary : Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: t.done ? B.primary : const Color(0xffcdd5df),
                  width: 2,
                ),
              ),
              child: t.done
                  ? Center(
                      child: ic('check', size: 13, sw: 3, color: Colors.white),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                goTab('lists');
                openTaskListDetail(list.id);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: B.ink,
                    ),
                  ),
                  Text(
                    list.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: B.soft2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _memberAvatar(t.assignee, size: 24),
        ],
      ),
    );
  }
}
