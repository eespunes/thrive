part of 'package:family_money_management_app/main.dart';

/// The unified Lists module (#159/#155/#156): the "all lists" hub plus the
/// to-do and shopping detail screens, ported from the design's
/// `renderLists()` / `taskListDetail()` / `shopDetail()`.
extension _ThriveListScreens on _ThriveHomeState {
  FamilyMember? _memberById(String? id) {
    if (id == null) return null;
    for (final m in curFamily()?.members ?? const <FamilyMember>[]) {
      if (m.id == id) return m;
    }
    return null;
  }

  Widget _memberAvatar(String? memberId, {double size = 24}) {
    final m = _memberById(memberId);
    if (m == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: B.faint,
          borderRadius: BorderRadius.circular(size / 2),
        ),
      );
    }
    return avatarNode(
      photo: m.photo,
      initials: m.initials,
      color: m.color,
      size: size,
      radius: size / 2,
      fs: size * 0.42,
    );
  }

  /// (label, color) for a due date relative to today, mirrors `dueLabel()`.
  (String, Color)? _dueLabel(String? due) {
    if (due == null || due.isEmpty) return null;
    final d = DateTime.tryParse(due);
    if (d == null) return null;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final diff = DateTime(d.year, d.month, d.day).difference(todayDate).inDays;
    if (diff < 0) return ('Overdue', B.red);
    if (diff == 0) return ('Today', B.amberText);
    if (diff == 1) return ('Tomorrow', B.soft2);
    return ('${kMonthsShort[d.month - 1]} ${d.day}', B.soft2);
  }

  // ---------------------------------------------------------------- hub
  Widget _buildListsHub() {
    final tl = openList();
    if (tl != null) return _taskListDetail(tl);
    final sl = openShop();
    if (sl != null) return _shopDetail(sl);

    final filterMe = taskFilter == 'me';
    if (taskLists.isEmpty && shoppingLists.isEmpty) {
      return _emptyState(
        icon: 'list',
        title: 'No lists yet',
        sub: 'Create a to-do or shopping list the whole family can see.',
        actionLabel: 'New list',
        onAction: openNewListSheet,
      );
    }

    final cards = <Widget>[];
    for (final list in taskLists) {
      final tasks = filterMe
          ? list.tasks.where((t) => t.assignee == 'me').toList()
          : list.tasks;
      if (filterMe && tasks.isEmpty) continue;
      cards.add(_taskListCard(list, tasks));
    }
    if (!filterMe) {
      for (final list in shoppingLists) {
        cards.add(_shopListCard(list));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        if (cards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nothing assigned to you yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: B.muted,
              ),
            ),
          )
        else
          for (final c in cards)
            Padding(padding: const EdgeInsets.only(bottom: 11), child: c),
        _addButton('New list', B.primary, openNewListSheet),
      ],
    );
  }

  Widget _taskListCard(TaskList list, List<ListTask> tasks) {
    final open = tasks.where((t) => !t.done).length;
    final done = tasks.length - open;
    final preview = tasks.where((t) => !t.done).take(3).toList();
    return _SwipeRow(
      key: ValueKey('tasklist-${list.id}'),
      open: swipedId == list.id,
      onOpenChanged: (o) => update(() => swipedId = o ? list.id : null),
      onDelete: () => askDelete(
        list.name,
        'This list and all its tasks will be removed.',
        () => deleteTaskList(list.id),
      ),
      borderRadius: 16,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openTaskListDetail(list.id),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: B.line),
            borderRadius: BorderRadius.circular(16),
            boxShadow: cardShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: list.color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: glyphTile(
                      size: 34,
                      radius: 10,
                      picture: list.picture,
                      emoji: list.emoji,
                      emojiSize: 18,
                      fallback: Center(
                        child: ic(
                          'tasklist',
                          size: 17,
                          sw: 2.1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                list.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: B.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: B.soft,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'TO-DO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .4,
                                  color: B.deep,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$open open${done > 0 ? ' · $done done' : ''}',
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
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final t in preview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xffcdd5df),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: B.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _shopListCard(ShoppingList list) {
    final left = list.items.where((i) => !i.checked).length;
    final preview = list.items
        .where((i) => !i.checked)
        .take(3)
        .map((i) => i.name)
        .join(', ');
    return _SwipeRow(
      key: ValueKey('shoplist-${list.id}'),
      open: swipedId == list.id,
      onOpenChanged: (o) => update(() => swipedId = o ? list.id : null),
      onDelete: () => askDelete(
        list.name,
        'This list will be removed.',
        () => deleteShopList(list.id),
      ),
      borderRadius: 16,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openShopListDetail(list.id),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: B.line),
            borderRadius: BorderRadius.circular(16),
            boxShadow: cardShadow(),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xffd97706),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: glyphTile(
                  size: 34,
                  radius: 10,
                  picture: list.picture,
                  emoji: list.emoji,
                  emojiSize: 18,
                  fallback: Center(
                    child: ic('cart', size: 17, sw: 2.1, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            list.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: B.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xfffef3e2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'SHOPPING',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .4,
                              color: Color(0xffb45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      left > 0
                          ? '$left to buy${preview.isNotEmpty ? ' · $preview' : ''}'
                          : 'All bought',
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
      ),
    );
  }

  // ---------------------------------------------------------- todo detail
  Widget _taskListDetail(TaskList l) {
    final open = l.tasks.where((t) => !t.done).toList()
      ..sort((a, b) => (a.due ?? '9999').compareTo(b.due ?? '9999'));
    final done = l.tasks.where((t) => t.done).toList();

    Widget row(ListTask t) {
      final dl = _dueLabel(t.due);
      final completer = t.done ? _memberById(t.completedBy) : null;
      final inner = Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: B.line),
        ),
        child: Row(
          children: [
            GestureDetector(
              key: ValueKey('task-check-${t.id}'),
              onTap: () => toggleTask(l.id, t.id),
              child: Container(
                width: 23,
                height: 23,
                decoration: BoxDecoration(
                  color: t.done ? B.primary : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: t.done ? B.primary : const Color(0xffcdd5df),
                    width: 2,
                  ),
                ),
                child: t.done
                    ? Center(
                        child: ic(
                          'check',
                          size: 14,
                          sw: 3,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: GestureDetector(
                onTap: () => openTaskSheet(t, l.id),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: t.done ? B.muted : B.ink,
                        decoration: t.done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (dl != null && !t.done)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ic('clock', size: 11, sw: 2.3, color: dl.$2),
                          const SizedBox(width: 3),
                          Text(
                            dl.$1,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: dl.$2,
                            ),
                          ),
                        ],
                      )
                    else if (t.done && completer != null)
                      Text(
                        'Done by ${completer.name}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: B.soft2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _memberAvatar(t.assignee, size: 27),
          ],
        ),
      );
      return _SwipeRow(
        key: ValueKey('task-${t.id}'),
        open: swipedId == t.id,
        onOpenChanged: (o) => update(() => swipedId = o ? t.id : null),
        onDelete: () => askDelete(
          t.title,
          'This task will be removed from ${l.name}.',
          () => deleteTask(l.id, t.id),
        ),
        borderRadius: 13,
        child: inner,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        if (open.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 10, 4, 4),
            child: Text(
              'No open tasks — all done here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: B.muted,
              ),
            ),
          )
        else
          for (final t in open)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: row(t)),
        if (done.isNotEmpty) ...[
          _secLabel('Completed · ${done.length}'),
          for (final t in done)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: row(t)),
        ],
        const SizedBox(height: 6),
        _addButton('Add task', B.primary, () => openTaskSheet(null, l.id)),
      ],
    );
  }

  Widget _secLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 9),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
          color: B.soft2,
        ),
      ),
    );
  }

  // ------------------------------------------------------- shopping detail
  Widget _shopDetail(ShoppingList l) {
    final todo = l.items.where((i) => !i.checked).toList();
    final bought = l.items.where((i) => i.checked).toList();

    Widget row(ShopItem it) {
      final inner = Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: B.line),
        ),
        child: Row(
          children: [
            GestureDetector(
              key: ValueKey('shop-check-${it.id}'),
              onTap: () => toggleShop(l.id, it.id),
              child: Container(
                width: 23,
                height: 23,
                decoration: BoxDecoration(
                  color: it.checked ? B.primary : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: it.checked ? B.primary : const Color(0xffcdd5df),
                    width: 2,
                  ),
                ),
                child: it.checked
                    ? Center(
                        child: ic(
                          'check',
                          size: 14,
                          sw: 3,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                it.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: it.checked ? B.muted : B.ink,
                  decoration: it.checked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
            _memberAvatar(it.addedBy, size: 22),
            if (!it.checked) ...[
              const SizedBox(width: 8),
              _qtyBtn('−', () => shopQty(l.id, it.id, -1), B.soft2),
              SizedBox(
                width: 20,
                child: Text(
                  '${it.qty}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: B.ink,
                  ),
                ),
              ),
              _qtyBtn('+', () => shopQty(l.id, it.id, 1), B.primary),
            ],
          ],
        ),
      );
      return _SwipeRow(
        key: ValueKey('shop-${it.id}'),
        open: swipedId == it.id,
        onOpenChanged: (o) => update(() => swipedId = o ? it.id : null),
        onDelete: () => askDelete(
          it.name,
          'Remove this item from ${l.name}.',
          () => deleteShopItem(l.id, it.id),
        ),
        borderRadius: 13,
        child: inner,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        _ShopQuickAdd(
          key: ValueKey('shop-quickadd-${l.id}'),
          state: this,
          listId: l.id,
        ),
        const SizedBox(height: 14),
        if (todo.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Nothing to buy. Add an item above.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: B.muted,
              ),
            ),
          )
        else
          for (final it in todo)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: row(it)),
        if (bought.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 18, 2, 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'BOUGHT · ${bought.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                      color: B.soft2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => clearBoughtItems(l.id),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: B.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final it in bought)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: row(it)),
        ],
      ],
    );
  }

  Widget _qtyBtn(String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          border: Border.all(color: B.line),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// The shopping list's quick-add input. A dedicated `StatefulWidget` so its
/// `TextEditingController` survives rebuilds of the surrounding list (e.g.
/// when checking an item off flashes a toast) instead of being recreated —
/// and dropping whatever the user was mid-typing — on every parent rebuild.
class _ShopQuickAdd extends StatefulWidget {
  const _ShopQuickAdd({super.key, required this.state, required this.listId});
  final _ThriveHomeState state;
  final String listId;

  @override
  State<_ShopQuickAdd> createState() => _ShopQuickAddState();
}

class _ShopQuickAddState extends State<_ShopQuickAdd> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    widget.state.addShopItem(widget.listId, _ctrl.text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            focusNode: widget.state.shopQuickAddFocus,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: B.ink,
            ),
            decoration: InputDecoration(
              hintText: 'Add item & press enter…',
              hintStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: B.muted,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: B.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: B.primary),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _submit,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: B.primary,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: ic('plus', size: 20, sw: 2.6, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
