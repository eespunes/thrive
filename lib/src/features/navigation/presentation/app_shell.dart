part of 'package:family_money_management_app/main.dart';

/// Top-level nav tab keys, as validated on restore. Mirrors the design's
/// `renderNav()` items plus the "More" sub-screens (`weekly`, `finsettings`)
/// that keep the More tab highlighted (`isActive` in `renderNav()`).
const Set<String> kValidTabs = {
  'home',
  'calendar',
  'lists',
  'finance',
  'more',
  'weekly',
  'finsettings',
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

  bool _navActive(String key) =>
      key == tab ||
      (key == 'more' && const {'more', 'weekly', 'finsettings'}.contains(tab));

  Widget _buildNav() {
    const items = [
      ('home', 'Home', 'home'),
      ('calendar', 'Calendar', 'cal'),
      ('lists', 'Lists', 'list'),
      ('finance', 'Finance', 'wallet'),
      ('more', 'More', 'menu'),
    ];
    return SafeArea(
      top: false,
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
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            for (final (key, label, icon) in items)
              Expanded(
                child: GestureDetector(
                  key: ValueKey('nav-$key'),
                  onTap: () => goTab(key),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 9, 0, 5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ic(
                          icon,
                          size: 22,
                          sw: _navActive(key) ? 2.3 : 1.9,
                          color: _navActive(key)
                              ? B.primary
                              : const Color(0xff9aa6b4),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: _navActive(key)
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: _navActive(key)
                                ? B.primary
                                : const Color(0xff9aa6b4),
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
    );
  }

  /// Quick-Add FAB. Only shown on `home`/`calendar`/`lists`, matching the
  /// design's `renderFab(tab)` map. On `lists` it opens the right sheet for
  /// whatever's currently in view (mirrors `renderFab`'s `lists` handler);
  /// `home`/`calendar` aren't built yet (#158/#152/#153), so they still
  /// surface a "coming soon" toast — real quick-add flows are tracked in
  /// #162.
  Widget? _buildFab() {
    if (!const {'home', 'calendar', 'lists'}.contains(tab)) return null;
    return Positioned(
      right: 18,
      bottom: 92,
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
      flash('Quick-Add is coming soon');
      return;
    }
    final shop = openShop();
    if (shop != null) {
      shopQuickAddFocus.requestFocus();
      return;
    }
    final list = openList();
    if (list != null) {
      openTaskSheet(null, list.id);
      return;
    }
    openNewListSheet();
  }

  /// Title/subtitle for tabs other than `finance` (which keeps its own
  /// month/stats header). Mirrors `tabMeta(tab)`.
  (String, String) _tabMeta(String t) {
    switch (t) {
      case 'home':
        return ('Hi, ${firstName()}', prettyToday());
      case 'calendar':
        return ('Calendar', _monthTitleIso(calAnchor));
      case 'lists':
        final tl = openList();
        if (tl != null) {
          final open = tl.tasks.where((x) => !x.done).length;
          return (tl.name, '$open open · ${tl.tasks.length} total');
        }
        final sl = openShop();
        if (sl != null) {
          final left = sl.items.where((x) => !x.checked).length;
          return (
            sl.name,
            '$left to buy · ${sl.items.length} item${sl.items.length == 1 ? '' : 's'}',
          );
        }
        final n = taskLists.length + shoppingLists.length;
        return ('Lists', '$n list${n == 1 ? '' : 's'}');
      case 'weekly':
        return ('Weekly plan', 'Coming soon');
      case 'finsettings':
        return ('Finance settings', 'Accounts, blocks & tools');
      case 'more':
        return ('More', 'Tools & settings');
      default:
        return ('Thrive', '');
    }
  }

  /// Sub-header row for non-finance tabs. `finsettings` shows a back-to-More
  /// row; `lists` shows a back-to-"All lists" row when a list is open, else
  /// the all/assigned-to-me filter — mirroring `tabSubHeader(tab)`.
  Widget? _tabSubHeader(String t) {
    if (t == 'finsettings') {
      return _backRow('More', () => goTab('more'));
    }
    if (t == 'calendar') {
      return _calSubHeader();
    }
    if (t == 'lists') {
      if (openShop() != null || openList() != null) {
        return _backRow('All lists', closeListDetail);
      }
      return _segRow(
        const [('all', 'All lists'), ('me', 'Assigned to me')],
        taskFilter,
        setTaskFilter,
      );
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
        return _buildWeeklyPlaceholder();
      case 'finsettings':
        return _buildSettings();
      case 'more':
        return _buildMore();
      default:
        return const SizedBox.shrink();
    }
  }

  /// A generic "← label" pill button, used for the finsettings → More
  /// back row (and reusable by future sub-screens). Mirrors `backRow()`.
  Widget _backRow(String label, VoidCallback onBack) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        key: const ValueKey('back-row'),
        onTap: onBack,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: B.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ic('back', size: 16, sw: 2.2, color: B.soft2),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: B.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The "More" hub — rows match `renderMore()` exactly (icon, title,
  /// subtitle, order). Family/Profile reuse the existing sheets unchanged;
  /// Lists/Weekly/Finance settings switch tabs; Calendars & categories opens
  /// a placeholder sheet (#160/#161 aren't built yet).
  Widget _buildMore() {
    final rows = [
      (
        'more-lists',
        'list',
        'Lists',
        'To-do & shopping lists',
        () => goTab('lists'),
      ),
      (
        'more-weekly',
        'moon',
        'Weekly plan',
        'Meals for the week',
        () => goTab('weekly'),
      ),
      (
        'more-calmanage',
        'cal',
        'Calendars & categories',
        'Imports, colours & icons',
        openCalendarManageSheet,
      ),
      (
        'more-family',
        'users',
        curFamily()?.name ?? 'Family',
        'Members, roles & sharing',
        openFamilySheet,
      ),
      (
        'more-finsettings',
        'gear',
        'Finance settings',
        'Accounts, blocks & tools',
        () => goTab('finsettings'),
      ),
      (
        'more-profile',
        'users',
        'Your profile',
        'Account & families',
        openProfileSheet,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          for (final (key, icon, title, sub, onTap) in rows) ...[
            _moreRow(key, icon, title, sub, onTap),
            if (key != rows.last.$1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _moreRow(
    String key,
    String icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      key: ValueKey(key),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: B.line),
          borderRadius: BorderRadius.circular(14),
          boxShadow: cardShadow(),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: B.soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: ic(icon, size: 18, sw: 2.1, color: B.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
                    ),
                  ),
                  Text(
                    sub,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: B.soft2,
                    ),
                  ),
                ],
              ),
            ),
            ic('cright', size: 17, sw: 2.2, color: B.muted),
          ],
        ),
      ),
    );
  }
}
