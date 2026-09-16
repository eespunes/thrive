part of 'package:family_money_management_app/main.dart';

/// The sections a person can put in their bottom bar (design `Nav options`
/// 1f / 2a–2c). Home and More are not here: Home is fixed at the left and
/// More is fixed at the right, holding whatever wasn't picked.
///
/// `(key, label, icon)`. The key is the `tab` value, so a picked section is
/// simply a tab that the bar happens to show.
const List<(String, String, String)> kNavSections = [
  ('calendar', 'Calendar', 'calmonth'),
  ('lists', 'Lists', 'list'),
  ('finance', 'Money', 'wallet'),
  ('weekly', 'Meal plan', 'cup'),
];

/// How many of [kNavSections] the bar holds. Home + 3 picks + More = 5, the
/// bar the app has always had — customisation changes WHICH three, never how
/// many, so the bar's shape is the same for everyone.
const int kNavPickCount = 3;

/// What everyone starts with: today's bar, so a fresh install is never asked
/// to configure anything (the design's "sensible defaults matter").
const List<String> kDefaultNavTabs = ['calendar', 'lists', 'finance'];

extension _ThriveNavTabs on _ThriveHomeState {
  /// The three sections this person's bar shows, always valid: unknown or
  /// duplicate keys are dropped and the list is topped up from the defaults,
  /// so a stale or hand-edited value can never produce a short bar.
  List<String> get navPickedTabs => sanitiseNavTabs(navTabs);

  /// Sections that didn't make the bar. They are not lost — More lists them.
  List<String> get navMoreSections => [
    for (final (key, _, _) in kNavSections)
      if (!navPickedTabs.contains(key)) key,
  ];

  void setNavTabs(List<String> picked) {
    // `_persist()` writes the per-user state locally and, when the account is
    // cloud-backed, pushes the user doc — the same path layerFilter takes.
    update(() => navTabs = sanitiseNavTabs(picked));
    unawaited(_persist());
  }

  /// Adds or removes a section, keeping the picked list exactly
  /// [kNavPickCount] long: picking a fourth drops the oldest pick, so the
  /// editor never has to refuse a tap or leave the bar short.
  void toggleNavTab(String key) {
    final picked = navPickedTabs.toList();
    if (picked.contains(key)) {
      picked.remove(key);
    } else {
      picked.add(key);
      while (picked.length > kNavPickCount) {
        picked.removeAt(0);
      }
    }
    setNavTabs(picked);
  }

  /// Moves a picked section from [oldIndex] to [newIndex], where newIndex is
  /// already adjusted for the removal (ReorderableListView.onReorderItem).
  void moveNavTab(int oldIndex, int newIndex) {
    final picked = navPickedTabs.toList();
    if (oldIndex < 0 || oldIndex >= picked.length) return;
    final moved = picked.removeAt(oldIndex);
    picked.insert(newIndex.clamp(0, picked.length), moved);
    setNavTabs(picked);
  }

  /// The badge on a tab: a count of what is waiting for THIS person, or null
  /// for a section that has nothing to nag about. Deliberately only the two
  /// sections with a real "needs you" number — a badge that just counts
  /// what exists teaches people to ignore badges.
  int? navTabBadge(String key) {
    switch (key) {
      case 'lists':
        var open = 0;
        for (final l in taskLists) {
          open += l.tasks
              .where(
                (t) => !t.done && (t.assignee == myId || t.assignee == null),
              )
              .length;
        }
        return open == 0 ? null : open;
      case 'finance':
        final c = compute(monthIdx);
        var unpaid = 0;
        for (final b in c.blocks) {
          if (b.isIncome) continue;
          unpaid += b.items.where((r) => !r.item.paid).length;
        }
        return unpaid == 0 ? null : unpaid;
      default:
        return null;
    }
  }

  (String, String) navSectionMeta(String key) {
    for (final (k, label, icon) in kNavSections) {
      if (k == key) return (label, icon);
    }
    return (key, 'menu');
  }

  void openNavTabEditor() {
    logAnalyticsEvent('nav_tab_editor_opened', const {});
    _showSheet((ctx) => _NavTabEditorSheet(state: this));
  }
}

/// Keeps a picked-tab list valid: known sections only, no duplicates, capped
/// at [kNavPickCount] and topped up from [kDefaultNavTabs] when short. Used
/// on every read, so nothing downstream has to defend itself.
List<String> sanitiseNavTabs(List<String>? raw) {
  final known = {for (final (k, _, _) in kNavSections) k};
  final out = <String>[];
  for (final key in raw ?? const <String>[]) {
    if (known.contains(key) && !out.contains(key)) out.add(key);
    if (out.length == kNavPickCount) break;
  }
  for (final key in kDefaultNavTabs) {
    if (out.length == kNavPickCount) break;
    if (!out.contains(key)) out.add(key);
  }
  return out;
}

/// The tab editor (design 2c): "Your tab bar · pick 3". Home is fixed, the
/// picked sections drag to reorder, and the unpicked ones read "In More" so
/// it is obvious nothing has been thrown away.
class _NavTabEditorSheet extends StatefulWidget {
  const _NavTabEditorSheet({required this.state});

  final _ThriveHomeState state;

  @override
  State<_NavTabEditorSheet> createState() => _NavTabEditorSheetState();
}

class _NavTabEditorSheetState extends State<_NavTabEditorSheet> {
  _ThriveHomeState get s => widget.state;

  Widget _row({
    required Key key,
    required String label,
    required Widget trailing,
    bool picked = true,
    bool fixed = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: picked ? 1 : .75,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xffe5e9ef)),
            ),
            foregroundDecoration: picked
                ? null
                : _DottedBoxDecoration(
                    color: const Color(0xffd3dae2),
                    radius: 11,
                    width: 1,
                  ),
            child: Row(
              children: [
                ic(
                  'grip',
                  size: 13,
                  sw: 2.4,
                  color: fixed || !picked
                      ? const Color(0xffcbd5e1)
                      : const Color(0xff94a3b8),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: picked ? B.ink : const Color(0xff64748b),
                    ),
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w800,
      letterSpacing: .4,
      color: Color(0xff94a3b8),
    ),
  );

  Widget _tick() => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: B.primary,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Center(child: ic('check', size: 12, sw: 3, color: Colors.white)),
  );

  @override
  Widget build(BuildContext context) {
    final picked = s.navPickedTabs;
    final unpicked = s.navMoreSections;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sheetHead(
          context,
          'Your tab bar',
          'Pick $kNavPickCount · drag to reorder',
        ),
        studioSectionLabel('Your tab bar · pick $kNavPickCount'),
        _row(
          key: const ValueKey('nav-edit-home'),
          label: 'Home',
          fixed: true,
          trailing: _tag('Fixed'),
        ),
        // Reorder only applies to the picked rows — an unpicked section has
        // no position in the bar to drag.
        ReorderableListView(
          key: const ValueKey('nav-edit-picked'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          // onReorderItem hands over the index AFTER the removal, so the
          // insert is a plain move — no off-by-one to correct.
          onReorderItem: (oldIndex, newIndex) {
            s.moveNavTab(oldIndex, newIndex);
            setState(() {});
          },
          children: [
            for (var i = 0; i < picked.length; i++)
              ReorderableDragStartListener(
                key: ValueKey('nav-edit-${picked[i]}'),
                index: i,
                child: _row(
                  key: ValueKey('nav-edit-row-${picked[i]}'),
                  label: s.navSectionMeta(picked[i]).$1,
                  onTap: () {
                    s.toggleNavTab(picked[i]);
                    setState(() {});
                  },
                  trailing: _tick(),
                ),
              ),
          ],
        ),
        for (final key in unpicked)
          _row(
            key: ValueKey('nav-edit-$key'),
            label: s.navSectionMeta(key).$1,
            picked: false,
            onTap: () {
              s.toggleNavTab(key);
              setState(() {});
            },
            trailing: _tag('In More'),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(
            'Pick $kNavPickCount of ${kNavSections.length} · unpicked '
            'sections stay one tap away in More',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xff94a3b8),
            ),
          ),
        ),
      ],
    );
  }
}
