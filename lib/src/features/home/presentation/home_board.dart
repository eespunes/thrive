part of 'package:family_money_management_app/main.dart';

/// Home board (epic #223): board state, edit mode and the board renderer.
/// The old fixed home stack is replaced by an ordered, per-member list of
/// widgets ([BoardEntry]) rendered at S/M/L sizes.
extension _ThriveHomeBoard on _ThriveHomeState {
  /// The board to render: the member's own layout, or the default board for
  /// profiles that never edited (issue #235). Kid profiles never render
  /// non-kid-safe widgets, whatever is stored (issue #245).
  List<BoardEntry> effectiveHomeBoard() {
    final board = homeBoard ?? defaultHomeBoard();
    if (!amIKidProfile()) return board;
    return [
      for (final e in board)
        if (homeWidgetDef(e.widgetId)?.kidSafe == true) e,
    ];
  }

  /// Whether the signed-in user's member row is a kid profile (issue #245).
  bool amIKidProfile() {
    final mine = _homeCurrentUserMemberIds();
    return (curFamily()?.members ?? const <FamilyMember>[]).any(
      (m) => mine.contains(m.id) && m.role == 'kid',
    );
  }

  /// Widgets offered in the picker for this member (issue #237/#245): the
  /// kid-safe subset for kids; "Chores & stars" only when the family
  /// actually uses chores.
  List<HomeWidgetDef> offeredHomeWidgets() {
    final kid = amIKidProfile();
    return [
      for (final d in kHomeWidgetCatalog)
        if ((!kid || d.kidSafe) && (d.id != 'chores' || _familyUsesChores())) d,
    ];
  }

  bool _familyUsesChores() =>
      kitchenEnabled ||
      starsMap.isNotEmpty ||
      events.any((e) => e.kitchenOrigin);

  /// First edit copies the currently effective board so the user starts
  /// from what they see, not from an empty list.
  void _touchHomeBoard() => homeBoard ??= effectiveHomeBoard();

  void addHomeWidget(String widgetId) {
    final def = homeWidgetDef(widgetId);
    if (def == null) return;
    update(() {
      _touchHomeBoard();
      homeBoard!.add(BoardEntry(widgetId: widgetId, size: def.sizes.first));
    });
    _schedulePersist();
    logAnalyticsEvent('home_widget_added', {'widget': widgetId});
  }

  void removeHomeWidget(int index) {
    update(() {
      _touchHomeBoard();
      if (index < 0 || index >= homeBoard!.length) return;
      final removed = homeBoard!.removeAt(index);
      logAnalyticsEvent('home_widget_removed', {'widget': removed.widgetId});
    });
    _schedulePersist();
  }

  /// Cycles the entry through the sizes its widget supports (issue #238).
  void cycleHomeWidgetSize(int index) {
    update(() {
      _touchHomeBoard();
      if (index < 0 || index >= homeBoard!.length) return;
      final entry = homeBoard![index];
      final sizes = homeWidgetDef(entry.widgetId)?.sizes ?? const ['m'];
      entry.size = sizes[(sizes.indexOf(entry.size) + 1) % sizes.length];
    });
    _schedulePersist();
  }

  void reorderHomeWidget(int from, int to) {
    update(() {
      _touchHomeBoard();
      if (from < 0 || from >= homeBoard!.length) return;
      final entry = homeBoard!.removeAt(from);
      homeBoard!.insert(to.clamp(0, homeBoard!.length), entry);
    });
    _schedulePersist();
  }

  void setHomeWidgetOptions(int index, Map<String, dynamic> options) {
    update(() {
      _touchHomeBoard();
      if (index < 0 || index >= homeBoard!.length) return;
      homeBoard![index].options = options;
    });
    _schedulePersist();
  }

  void setHomeEditMode(bool on) => update(() => homeEditMode = on);

  // ------------------------------------------------------------ rendering

  Widget _buildHomeDashboard() {
    final board = effectiveHomeBoard();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        _homeBoardHeader(),
        if (homeEditMode)
          _homeBoardEditList()
        else ...[
          ..._homeBoardRows(board),
          if (board.isEmpty) _homeBoardEmptyState(),
        ],
        _homeAddWidgetButton(),
      ],
    );
  }

  /// Slim board header: the app shell already greets the user; this row
  /// only carries the edit-mode toggle (and its "Done" state).
  Widget _homeBoardHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            homeEditMode ? 'Edit your board' : prettyToday(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: B.muted,
            ),
          ),
        ),
        GestureDetector(
          key: const ValueKey('home-edit-toggle'),
          onTap: () => setHomeEditMode(!homeEditMode),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: homeEditMode ? B.primary : Colors.white,
              border: Border.all(color: homeEditMode ? B.primary : B.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: ic(
                homeEditMode ? 'check' : 'edit',
                size: 16,
                sw: 2.3,
                color: homeEditMode ? Colors.white : B.soft2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// View mode: consecutive S entries pair up two per row; M/L span full
  /// width. Long-pressing any widget enters edit mode (issue #236).
  List<Widget> _homeBoardRows(List<BoardEntry> board) {
    final rows = <Widget>[];
    var i = 0;
    Widget wrap(BoardEntry e, int index) => GestureDetector(
      key: ValueKey('home-w-${e.widgetId}-$index'),
      onLongPress: () => setHomeEditMode(true),
      child: buildHomeWidget(e, index),
    );
    while (i < board.length) {
      final e = board[i];
      if (e.size == 's' && e.widgetId != 'divider') {
        final next = i + 1 < board.length ? board[i + 1] : null;
        if (next != null && next.size == 's' && next.widgetId != 'divider') {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: wrap(e, i)),
                    const SizedBox(width: 12),
                    Expanded(child: wrap(next, i + 1)),
                  ],
                ),
              ),
            ),
          );
          i += 2;
          continue;
        }
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(child: wrap(e, i)),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        );
        i++;
        continue;
      }
      rows.add(
        Padding(padding: const EdgeInsets.only(top: 12), child: wrap(e, i)),
      );
      i++;
    }
    return rows;
  }

  Widget _homeBoardEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 10),
      child: Column(
        children: [
          ic('grid', size: 30, sw: 1.8, color: B.muted),
          const SizedBox(height: 10),
          const Text(
            'Your board is empty',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: B.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add a widget to make Home yours.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: B.muted,
            ),
          ),
        ],
      ),
    );
  }

  /// Edit mode (issue #236): one full-width row per entry with a drag
  /// handle (reorder), a size chip (issue #238) and a remove button.
  Widget _homeBoardEditList() {
    final board = effectiveHomeBoard();
    return ReorderableListView.builder(
      key: const ValueKey('home-edit-list'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: reorderHomeWidget,
      itemCount: board.length,
      itemBuilder: (context, index) {
        final entry = board[index];
        final def = homeWidgetDef(entry.widgetId)!;
        final hasOptions = _homeWidgetHasOptions(entry.widgetId);
        return Container(
          key: ValueKey('home-edit-${entry.widgetId}-$index'),
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: B.line),
            borderRadius: BorderRadius.circular(14),
            boxShadow: cardShadow(),
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ic('menu', size: 16, sw: 2.2, color: B.muted),
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: B.soft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: ic(def.icon, size: 15, sw: 2.1, color: B.primary),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: GestureDetector(
                  key: ValueKey('home-edit-opts-$index'),
                  behavior: HitTestBehavior.opaque,
                  onTap: hasOptions ? () => openHomeWidgetOptions(index) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: B.ink,
                        ),
                      ),
                      Text(
                        hasOptions ? 'Tap to configure' : def.sub,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: B.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                key: ValueKey('home-size-$index'),
                onTap: def.sizes.length > 1
                    ? () => cycleHomeWidgetSize(index)
                    : null,
                child: Container(
                  width: 30,
                  height: 26,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: def.sizes.length > 1 ? B.soft : B.faint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      entry.size.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: def.sizes.length > 1 ? B.deep : B.muted,
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                key: ValueKey('home-remove-$index'),
                onTap: () => removeHomeWidget(index),
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: B.redSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: ic('x', size: 13, sw: 2.6, color: B.red),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _homeAddWidgetButton() {
    return GestureDetector(
      key: const ValueKey('home-add-widget'),
      onTap: openHomeWidgetPicker,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: B.primary.withValues(alpha: .5)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ic('plus', size: 15, sw: 2.5, color: B.primary),
            const SizedBox(width: 7),
            const Text(
              'Add a widget',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: B.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
