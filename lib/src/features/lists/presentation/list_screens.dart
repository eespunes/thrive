part of 'package:family_money_management_app/main.dart';

const Color _kInkOnPaper = Color(0xff2c2920);
const Color _kFadedOnPaper = Color(0x45000000);
const Color _kOverdueOnPaper = Color(0xffc2410c);

const TextStyle _kNoteTitleStyle = TextStyle(
  fontFamily: 'Caveat',
  fontVariations: [FontVariation('wght', 700)],
  fontSize: 23,
  height: 1,
  color: Color(0xff333333),
);

TextStyle _lineTextStyle(bool done) => TextStyle(
  fontFamily: 'Caveat',
  fontVariations: const [FontVariation('wght', 600)],
  fontSize: 19,
  height: 1.15,
  color: done ? _kFadedOnPaper : _kInkOnPaper,
  decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
  decorationThickness: 2,
);

/// The Lists tab as a fridge door (epic #302–#319): one scrolling wall of
/// taped-up sticky notes — every line lives on its note; there are no
/// detail screens. One tap zone per verb: checkbox ticks, text edits,
/// avatar assigns, ✎ edits the note.
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
      emoji: m.emoji,
      initials: m.initials,
      color: m.color,
      size: size,
      radius: size / 2,
      fs: size * 0.42,
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

  // ---------------------------------------------------------------- wall
  Widget _buildListsHub() {
    ensureListPrefs();
    final filterMe = taskFilter == 'me';

    if (taskLists.isEmpty && shoppingLists.isEmpty) {
      return _emptyState(
        icon: 'list',
        title: 'Nothing on the door yet',
        sub: 'Pin a to-do or shopping note the whole family can see.',
        actionLabel: 'Pin a new note',
        onAction: openNewListSheet,
      );
    }

    // Deferred row builders so ListView.builder only materialises what's
    // on screen — a wall can hold 10+ notes with 50-line notes (#309).
    final rows = <Widget Function()>[() => _sortChips()];
    var anyNote = false;
    for (final list in taskLists) {
      final tasks = filterMe
          ? list.tasks
                .where((t) => t.assignee == myId || t.assignee == null)
                .toList()
          : list.tasks;
      // Under "Just me" a note with none of my (or up-for-grabs) lines
      // hides entirely (#307).
      if (filterMe && tasks.isEmpty) continue;
      anyNote = true;
      rows.add(
        () => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: _taskNote(list, tasks),
        ),
      );
    }
    if (!filterMe) {
      for (final list in shoppingLists) {
        anyNote = true;
        rows.add(
          () => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _shopNote(list),
          ),
        );
      }
    }
    if (!anyNote) {
      rows.add(
        () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Nothing with your name on it — or up for grabs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: B.muted,
            ),
          ),
        ),
      );
    }
    rows.add(() => _pinNewButton());

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      itemCount: rows.length,
      itemBuilder: (context, i) => rows[i](),
    );
  }

  /// List order / By due / By person — a per-member preference; shopping
  /// notes ignore it (#317).
  Widget _sortChips() {
    Widget chip(String key, String label) {
      final on = listSort == key;
      return GestureDetector(
        key: ValueKey('lists-sort-$key'),
        onTap: () => setListSort(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? B.ink : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: on ? null : Border.all(color: const Color(0xffdde3ea)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : B.soft2,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          chip('list', 'List order'),
          const SizedBox(width: 7),
          chip('due', 'By due'),
          const SizedBox(width: 7),
          chip('who', 'By person'),
        ],
      ),
    );
  }

  Widget _pinNewButton() {
    return GestureDetector(
      key: const ValueKey('pin-new-note'),
      onTap: openNewListSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffc9d0da), width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '＋ pin a new note',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Caveat',
            fontVariations: [FontVariation('wght', 700)],
            fontSize: 20,
            color: B.soft2,
          ),
        ),
      ),
    );
  }

  /// Done lines always sink; open lines follow the member's sort (#317).
  List<ListTask> _sortedTasks(List<ListTask> tasks) {
    final open = tasks.where((t) => !t.done).toList();
    final done = tasks.where((t) => t.done).toList();
    if (listSort == 'due') {
      // ISO dates sort lexicographically; no due ("Someday") last. Stable:
      // List.sort isn't guaranteed stable, so decorate with the index.
      final idx = {for (var i = 0; i < open.length; i++) open[i]: i};
      open.sort((a, b) {
        final c = (a.due ?? '9999').compareTo(b.due ?? '9999');
        return c != 0 ? c : idx[a]!.compareTo(idx[b]!);
      });
    } else if (listSort == 'who') {
      final members = curFamily()?.members ?? const <FamilyMember>[];
      final ord = {for (var i = 0; i < members.length; i++) members[i].id: i};
      final idx = {for (var i = 0; i < open.length; i++) open[i]: i};
      open.sort((a, b) {
        final c = (a.assignee != null ? (ord[a.assignee] ?? 998) : 999)
            .compareTo(b.assignee != null ? (ord[b.assignee] ?? 998) : 999);
        return c != 0 ? c : idx[a]!.compareTo(idx[b]!);
      });
    }
    return open + done;
  }

  Widget _taskNote(TaskList list, List<ListTask> tasks) {
    final openCount = tasks.where((t) => !t.done).length;
    return _noteShell(
      listId: list.id,
      color: list.color,
      title: list.name,
      count: openCount > 0 ? '$openCount left' : 'done!',
      onEdit: () => openEditNoteSheet(taskList: list),
      lines: [for (final t in _sortedTasks(tasks)) _taskLine(list, t)],
      addLine: _NoteAddLine(
        key: ValueKey('note-add-${list.id}'),
        hint: 'add a line…',
        onAdd: (v) => addTaskLine(list.id, v),
      ),
    );
  }

  Widget _shopNote(ShoppingList list) {
    final openCount = list.items.where((i) => !i.checked).length;
    final rows = list.items.where((i) => !i.checked).toList()
      ..addAll(list.items.where((i) => i.checked));
    return _noteShell(
      listId: list.id,
      color: list.color,
      title: list.name,
      count: openCount > 0 ? '$openCount to buy' : 'done!',
      onEdit: () => openEditNoteSheet(shopList: list),
      lines: [for (final it in rows) _shopLine(list, it)],
      addLine: _NoteAddLine(
        key: ValueKey('note-add-${list.id}'),
        hint: 'add — try “5x milk”',
        focusNode: list.id == openShopList ? shopQuickAddFocus : null,
        onAdd: (v) => addShopItem(list.id, v),
      ),
    );
  }

  /// The sticky note: tape, stable per-list rotation and paper, header with
  /// fold arrow + ✎, lines, and the in-place add-line (#302/#318).
  Widget _noteShell({
    required String listId,
    required Color? color,
    required String title,
    required String count,
    required VoidCallback onEdit,
    required List<Widget> lines,
    required Widget addLine,
  }) {
    final (paper, tape) = _kNotePapers[_paperIndexFor(listId, color)];
    final folded = foldedNotes.contains(listId);

    final note = Container(
      key: ValueKey('note-$listId'),
      margin: const EdgeInsets.only(top: 8),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, folded ? 12 : 14, 14, 12),
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff3f3a2e).withValues(alpha: .35),
            blurRadius: 22,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                key: ValueKey('note-fold-$listId'),
                onTap: () => toggleNoteFolded(listId),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                  child: ic(
                    folded ? 'cright' : 'cdown',
                    size: 16,
                    sw: 2.4,
                    color: const Color(0x66000000),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: _kNoteTitleStyle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                  color: Color(0x66000000),
                ),
              ),
              GestureDetector(
                key: ValueKey('note-edit-$listId'),
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
                  child: ic(
                    'edit',
                    size: 15,
                    sw: 2,
                    color: const Color(0x66000000),
                  ),
                ),
              ),
            ],
          ),
          if (!folded) ...[
            const SizedBox(height: 4),
            ...lines,
            const SizedBox(height: 6),
            addLine,
          ],
        ],
      ),
    );

    return Transform.rotate(
      angle: _rotationFor(listId) * math.pi / 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          note,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: -2 * math.pi / 180,
                child: Container(
                  width: 70,
                  height: 18,
                  decoration: BoxDecoration(
                    color: tape.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineCheckbox({
    required Key key,
    required bool done,
    required bool round,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // 20px box inside a ≥44px tap zone (#303).
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: done ? const Color(0xff3f3a2e) : Colors.transparent,
            borderRadius: BorderRadius.circular(round ? 99 : 6),
            border: Border.all(color: const Color(0x33000000), width: 2),
          ),
          child: done
              ? Center(child: ic('check', size: 11, sw: 3, color: Colors.white))
              : null,
        ),
      ),
    );
  }

  Widget _taskLine(TaskList list, ListTask t) {
    final m = _memberById(t.assignee);
    final overdue = !t.done && t.due != null && dueDiffDays(t.due!) < 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _lineCheckbox(
          key: ValueKey('task-check-${t.id}'),
          done: t.done,
          round: false,
          onTap: () => toggleTask(list.id, t.id),
        ),
        Expanded(
          child: GestureDetector(
            key: ValueKey('task-text-${t.id}'),
            onTap: () => openTaskSheet(t, list.id),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(t.title, style: _lineTextStyle(t.done)),
            ),
          ),
        ),
        if (!t.done) ...[
          const SizedBox(width: 6),
          Text(
            dueLabel(t.due).toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
              color: overdue ? _kOverdueOnPaper : _kFadedOnPaper,
            ),
          ),
        ],
        const SizedBox(width: 4),
        // The avatar is the assignment button: initials when assigned, a
        // dashed ＋ when up for grabs (#316).
        GestureDetector(
          key: ValueKey('task-assign-${t.id}'),
          onTap: () => openAssignSheet(list.id, t.id),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 9, 0, 9),
            child: m != null
                ? avatarNode(
                    photo: m.photo,
                    emoji: m.emoji,
                    initials: m.initials,
                    color: m.color,
                    size: 26,
                    radius: 13,
                    fs: 9,
                    opacity: t.done ? .55 : 1,
                  )
                : Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: const Color(0x40000000),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '＋',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0x60000000),
                          height: 1,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _shopLine(ShoppingList list, ShopItem it) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _lineCheckbox(
          key: ValueKey('shop-check-${it.id}'),
          done: it.checked,
          round: true,
          onTap: () => toggleShop(list.id, it.id),
        ),
        Expanded(
          child: GestureDetector(
            key: ValueKey('shop-text-${it.id}'),
            onTap: () => openShopItemSheet(it, list.id),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(it.name, style: _lineTextStyle(it.checked)),
            ),
          ),
        ),
        if (it.checked)
          Text(
            '×${it.qty}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _kFadedOnPaper,
            ),
          )
        else ...[
          _qtyBtn(
            key: ValueKey('shop-minus-${it.id}'),
            label: '−',
            onTap: () => shopQty(list.id, it.id, -1),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '×${it.qty}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: _kInkOnPaper,
              ),
            ),
          ),
          _qtyBtn(
            key: ValueKey('shop-plus-${it.id}'),
            label: '＋',
            onTap: () => shopQty(list.id, it.id, 1),
          ),
        ],
      ],
    );
  }

  Widget _qtyBtn({
    required Key key,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // 22px glyph inside a ≥44px zone (#319).
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x33000000)),
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _kInkOnPaper,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// The note's in-place handwriting input. A dedicated `StatefulWidget` so
/// its `TextEditingController` survives rebuilds of the surrounding wall
/// (toasts, ticks) instead of dropping what the user was mid-typing.
class _NoteAddLine extends StatefulWidget {
  const _NoteAddLine({
    super.key,
    required this.hint,
    required this.onAdd,
    this.focusNode,
  });
  final String hint;
  final ValueChanged<String> onAdd;
  final FocusNode? focusNode;

  @override
  State<_NoteAddLine> createState() => _NoteAddLineState();
}

class _NoteAddLineState extends State<_NoteAddLine> {
  final _ctrl = TextEditingController();
  final _ownFocus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _ownFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    widget.onAdd(v);
    _ctrl.clear();
    // Keep focus for rapid entry (#304).
    (widget.focusNode ?? _ownFocus).requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x30000000), width: 1.5),
              ),
            ),
            child: TextField(
              controller: _ctrl,
              focusNode: widget.focusNode ?? _ownFocus,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: TextStyle(
                fontFamily: 'Caveat',
                fontVariations: const [FontVariation('wght', 600)],
                fontSize: 18,
                color: _kInkOnPaper,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: const TextStyle(
                  fontFamily: 'Caveat',
                  fontVariations: [FontVariation('wght', 600)],
                  fontSize: 17,
                  color: Color(0x40000000),
                ),
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _submit,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xff3f3a2e),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: ic('plus', size: 14, sw: 2.6, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
