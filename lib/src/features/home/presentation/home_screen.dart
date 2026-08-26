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

const double _kHomeTaskRowHeight = 56;

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
