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
        if (homeEditMode) _homeHiddenLine(),
      ],
    );
  }

  /// Slim board header under the shell greeting. View mode: the pencil
  /// (design 2b). Edit mode: "Drag to reorder · only you see this" plus the
  /// teal "Done" pill (design 1a).
  Widget _homeBoardHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            // View mode shows no caption — today's date already lives in the
            // shell greeting right above, so repeating it here read twice.
            homeEditMode ? 'Drag to reorder · only you see this' : '',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xff94a0b0),
            ),
          ),
        ),
        if (homeEditMode)
          GestureDetector(
            key: const ValueKey('home-edit-toggle'),
            onTap: () => setHomeEditMode(false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: B.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ic('check', size: 14, sw: 2.4, color: Colors.white),
                  const SizedBox(width: 6),
                  const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GestureDetector(
            key: const ValueKey('home-edit-toggle'),
            onTap: () => setHomeEditMode(true),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: B.line),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: ic('edit', size: 16, sw: 2.2, color: B.soft2),
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

  /// Edit mode (issue #236), as in the design's 1a mock: the widgets stay
  /// rendered in place with a dashed outline, a red × badge, and a SIZE
  /// chip; drag anywhere to reorder.
  Widget _homeBoardEditList() {
    final board = effectiveHomeBoard();
    return ReorderableListView.builder(
      key: const ValueKey('home-edit-list'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorderItem: reorderHomeWidget,
      proxyDecorator: (child, index, animation) => child,
      itemCount: board.length,
      itemBuilder: (context, index) {
        final entry = board[index];
        final def = homeWidgetDef(entry.widgetId)!;
        return Padding(
          key: ValueKey('home-edit-${entry.widgetId}-$index'),
          padding: const EdgeInsets.only(top: 12, right: 6),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The live widget, inert while editing; tapping it opens its
              // options when it has any.
              GestureDetector(
                key: ValueKey('home-edit-opts-$index'),
                behavior: HitTestBehavior.opaque,
                onTap: _homeWidgetHasOptions(entry.widgetId)
                    ? () => openHomeWidgetOptions(index)
                    : null,
                child: IgnorePointer(child: buildHomeWidget(entry, index)),
              ),
              // Dashed edit outline.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DashedRectPainter(
                      color: const Color(0xffcbd5e1),
                      radius: 18,
                      inset: 5,
                    ),
                  ),
                ),
              ),
              // Size chip (issue #238) — only when more sizes exist.
              if (def.sizes.length > 1)
                Positioned(
                  right: 10,
                  top: 10,
                  child: GestureDetector(
                    key: ValueKey('home-size-$index'),
                    onTap: () => cycleHomeWidgetSize(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: B.line),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'SIZE ${entry.size.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .3,
                          color: Color(0xff94a0b0),
                        ),
                      ),
                    ),
                  ),
                ),
              // Red × remove badge (design 1a).
              Positioned(
                top: -8,
                right: -6,
                child: GestureDetector(
                  key: ValueKey('home-remove-$index'),
                  onTap: () => removeHomeWidget(index),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: B.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '\u00d7',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// "Hidden: A \u00b7 B \u00b7 C" — widgets not on the board (design 1a).
  Widget _homeHiddenLine() {
    final placed = {for (final e in effectiveHomeBoard()) e.widgetId};
    final hidden = [
      for (final d in offeredHomeWidgets())
        if (!placed.contains(d.id)) d.title,
    ];
    if (hidden.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        'Hidden: ${hidden.take(3).join(' \u00b7 ')}'
        '${hidden.length > 3 ? ' \u00b7 +${hidden.length - 3}' : ''}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Color(0xff94a0b0),
        ),
      ),
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

/// Dashed rounded-rect outline used by the board's edit mode (design 1a).
class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({
    required this.color,
    required this.radius,
    required this.inset,
  });
  final Color color;
  final double radius;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      ),
      Radius.circular(radius - inset),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) =>
      old.color != color || old.radius != radius || old.inset != inset;
}
