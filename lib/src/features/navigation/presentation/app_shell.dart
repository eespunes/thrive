part of 'package:family_money_management_app/main.dart';

/// Top-level nav tab keys, as validated on restore. Every section exists
/// whether or not it is on this person's bar (#365) — unpicking one moves it
/// into More, it never stops being a destination, so a persisted tab stays
/// valid after a bar change instead of falling back to a blank screen.
const Set<String> kValidTabs = {
  'home',
  'calendar',
  'lists',
  'finance',
  'more',
  'weekly',
};

/// The 5-tab bottom nav bar, the Quick-Add FAB, the "More" hub, and the
/// per-tab title/sub-header dispatch — ported from the design's
/// `renderNav()` / `renderFab()` / `renderMore()` / `tabMeta()` / `goTab()`.
extension _ThriveAppShell on _ThriveHomeState {
  /// Switches the active top-level tab. Mirrors `goTab()` in the design.
  void goTab(String t) {
    update(() {
      tab = t;
      swipedId = null;
    });
    _persist();
  }

  bool _navActive(String key) {
    if (key == tab) return true;
    // More is lit for itself AND for any section that isn't on the bar: an
    // unpicked section is reached through More, so More is where you are.
    if (key != 'more') return false;
    if (tab == 'more') return true;
    return kNavSections.any((s) => s.$1 == tab) && !navPickedTabs.contains(tab);
  }

  double _bottomSystemInset(BuildContext context) {
    final media = MediaQuery.of(context);
    return math.max(media.padding.bottom, media.viewPadding.bottom);
  }

  /// The bottom bar (design `Nav options` 2a): Home, the three sections this
  /// person picked, then More. The 1a ergonomics — a 52x34 pill behind the
  /// active icon, always-on labels, a badge slot per tab — apply to whatever
  /// the picks happen to be. Long-pressing anywhere on the bar opens the
  /// editor, which is the only way the bar advertises that it's editable.
  Widget _buildNav() {
    final bottomInset = _bottomSystemInset(context);
    final items = <(String, String, String)>[
      ('home', 'Home', 'home'),
      for (final key in navPickedTabs)
        (key, navSectionMeta(key).$1, navSectionMeta(key).$2),
      ('more', 'More', 'menu'),
    ];
    return GestureDetector(
      key: const ValueKey('app-bottom-nav'),
      onLongPress: openNavTabEditor,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: B.line)),
          boxShadow: [
            BoxShadow(
              color: Color(0x40101828),
              blurRadius: 22,
              spreadRadius: -18,
              offset: Offset(0, -8),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(6, 8, 6, 10 + bottomInset),
        child: Row(
          children: [
            for (final (key, label, icon) in items)
              Expanded(child: _navItem(key, label, icon)),
          ],
        ),
      ),
    );
  }

  Widget _navItem(String key, String label, String icon) {
    final active = _navActive(key);
    final badge = navTabBadge(key);
    final ink = active ? B.primary : const Color(0xff9aa6b4);
    return GestureDetector(
      key: ValueKey('nav-$key'),
      onTap: () => goTab(key),
      onLongPress: openNavTabEditor,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // The pill is the active marker; an inactive tab has no
                  // background at all, so only one thing on the bar is lit.
                  color: active ? B.soft : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: ic(icon, size: 19, sw: active ? 2.3 : 2.1, color: ink),
              ),
              if (badge != null)
                Positioned(
                  top: -3,
                  right: -1,
                  child: Container(
                    key: ValueKey('nav-badge-$key'),
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xffe2554f),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }

  /// Quick-Add FAB. Only shown on `calendar`/`lists`: calendar opens the
  /// event editor directly, and lists opens the right sheet for whatever's
  /// currently in view.
  Widget? _buildFab({double bottomSystemInset = 0}) {
    if (!const {'calendar', 'lists'}.contains(tab)) return null;
    return Positioned(
      right: 18,
      bottom: 92 + bottomSystemInset,
      child: GestureDetector(
        key: const ValueKey('quickadd-fab'),
        onTap: _onFabTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: B.grad,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: B.primary.withValues(alpha: .55),
                blurRadius: 30,
                spreadRadius: -8,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Center(
            child: ic('plus', size: 26, sw: 2.6, color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _onFabTap() {
    if (tab == 'calendar') {
      openEvent(null);
      return;
    }
    if (tab != 'lists') {
      openQuickAddSheet();
      return;
    }
    openNewListSheet();
  }

  /// Title/subtitle for tabs other than `finance` (which keeps its own
  /// month/stats header). Mirrors `tabMeta(tab)`.
  (String, String) _tabMeta(String t) {
    switch (t) {
      case 'home':
        return homeEditMode
            ? ("${firstName()}'s home", 'Only you see this layout')
            : ('Hi, ${firstName()}', prettyToday());
      case 'calendar':
        // The title block IS the month selector (design §2a): "Calendar"
        // over "August 2026 ▾", and "· Agenda" while the agenda is shown.
        return (
          'Calendar',
          _monthTitleIso(calView == 'agenda' ? agendaDay : calAnchor) +
              (calView == 'agenda' ? ' · Agenda' : ''),
        );
      case 'lists':
        // Fridge door (#302): live "4 notes · 7 things to do", recounted
        // under the Just-me filter — unassigned tasks stay everyone's
        // (#307); shopping notes only count under Everyone.
        final mine = taskFilter == 'me';
        var notes = 0;
        var open = 0;
        for (final l in taskLists) {
          final n = l.tasks
              .where(
                (t) =>
                    !t.done &&
                    (!mine || t.assignee == myId || t.assignee == null),
              )
              .length;
          if (!mine || n > 0) notes++;
          open += n;
        }
        if (!mine) {
          for (final l in shoppingLists) {
            notes++;
            open += l.items.where((i) => !i.checked).length;
          }
        }
        return (
          'Lists',
          '$notes note${notes == 1 ? '' : 's'} · '
              '$open thing${open == 1 ? '' : 's'} to do',
        );
      case 'weekly':
        return ('Weekly plan', 'Meals & notes for the week');
      case 'more':
        return ('More', 'Tools & settings');
      default:
        return ('Thrive', '');
    }
  }

  /// Sub-header row for non-finance tabs. `lists` shows a back-to-"All
  /// lists" row when a list is open, else the all/assigned-to-me filter —
  /// mirroring `tabSubHeader(tab)`.
  Widget? _tabSubHeader(String t) {
    if (t == 'lists') {
      return _segRow(
        const [('all', 'Everyone'), ('me', 'Just me')],
        taskFilter,
        setTaskFilter,
      );
    }
    if (t == 'weekly') {
      return _weekSubHeader();
    }
    return null;
  }

  /// A 2-option segmented control, mirrors `segRow()`.
  Widget _segRow(
    List<(String, String)> opts,
    String val,
    ValueChanged<String> onPick,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xffe8ecf2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final (key, label) in opts)
            Expanded(
              child: GestureDetector(
                key: ValueKey('lists-filter-$key'),
                onTap: () => onPick(key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    color: val == key ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: val == key
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .12),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: val == key ? B.primary : const Color(0xff8995a6),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Dispatches to each tab's body. Mirrors `renderTab(tab)`. `finance` is
  /// handled separately in `_buildBody` since it keeps its own
  /// overview/stats sub-navigation.
  Widget _renderTab(String t) {
    switch (t) {
      case 'home':
        return _buildHomeDashboard();
      case 'calendar':
        return _buildCalendar();
      case 'lists':
        return _buildListsHub();
      case 'weekly':
        return _buildWeeklyPlan();
      case 'more':
        return _buildMore();
      default:
        return const SizedBox.shrink();
    }
  }

  // The "More" hub now lives in `more_screen.dart` (`_buildMore()`), which
  // uses the grouped-list style (profile card, `moreGroup`/`moreRow`) rather
  // than the flat per-row cards this file used to render directly.
}
