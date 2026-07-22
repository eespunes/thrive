part of 'package:family_money_management_app/main.dart';

/// Global "Quick-Add" chooser (#162) — offered by the FAB on tabs that don't
/// already have a smarter direct-to-editor shortcut (`calendar` opens the
/// event editor directly, `lists` opens whatever list/shop editor is in
/// view). From `home` (and any other tab) it shows this chooser so the user
/// can add an event, task, or shopping item from anywhere.
extension _ThriveQuickAdd on _ThriveHomeState {
  void openQuickAddSheet() {
    _showSheet((ctx) => _QuickAddSheet(state: this));
  }

  /// Opens the task sheet for a to-do list the user picks. If there's
  /// exactly one list it's used directly; with none yet, prompts to create
  /// one first — mirroring the Lists hub's own empty state.
  void quickAddTask() {
    void addTo(String id) {
      goTab('lists');
      openTaskListDetail(id);
      openTaskSheet(null, id);
    }

    if (taskLists.isEmpty) {
      goTab('lists');
      openNewListSheet('todo');
      return;
    }
    if (taskLists.length == 1) {
      addTo(taskLists.first.id);
      return;
    }
    _showSheet(
      (ctx) => _PickListSheet(
        title: 'Add a task',
        sub: 'Which list should it go on?',
        items: [for (final l in taskLists) (l.id, l.name)],
        onPick: addTo,
      ),
    );
  }

  /// Same idea as [quickAddTask], for shopping lists — lands on the picked
  /// list's detail screen with the quick-add field focused.
  void quickAddShopItem() {
    void addTo(String id) {
      goTab('lists');
      openShopListDetail(id);
      shopQuickAddFocus.requestFocus();
    }

    if (shoppingLists.isEmpty) {
      goTab('lists');
      openNewListSheet('shopping');
      return;
    }
    if (shoppingLists.length == 1) {
      addTo(shoppingLists.first.id);
      return;
    }
    _showSheet(
      (ctx) => _PickListSheet(
        title: 'Add a shopping item',
        sub: 'Which list should it go on?',
        items: [for (final l in shoppingLists) (l.id, l.name)],
        onPick: addTo,
      ),
    );
  }
}

/// "What would you like to add?" chooser — Event / Task / Shopping item.
class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet({required this.state});
  final _ThriveHomeState state;

  Widget _row(
    BuildContext context,
    Key key,
    String icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
                    ),
                  ),
                  Text(
                    sub,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHead(context, 'What would you like to add?', null),
        _row(
          context,
          const ValueKey('quickadd-event'),
          'cal',
          'Event',
          'Add to the family calendar',
          () => state.openEvent(null),
        ),
        _row(
          context,
          const ValueKey('quickadd-task'),
          'tasklist',
          'Task',
          'Assign a to-do',
          state.quickAddTask,
        ),
        _row(
          context,
          const ValueKey('quickadd-shopping'),
          'cart',
          'Shopping item',
          'Add to a list',
          state.quickAddShopItem,
        ),
      ],
    );
  }
}

/// Small "which list?" picker used when quick-adding a task or shopping item
/// and more than one list of that kind exists.
class _PickListSheet extends StatelessWidget {
  const _PickListSheet({
    required this.title,
    required this.sub,
    required this.items,
    required this.onPick,
  });

  final String title;
  final String sub;
  final List<(String, String)> items;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHead(context, title, sub),
        for (final (id, name) in items)
          GestureDetector(
            key: ValueKey('pick-list-$id'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).pop();
              onPick(id);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: B.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: B.ink,
                      ),
                    ),
                  ),
                  ic('cright', size: 16, sw: 2.2, color: B.muted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
