part of 'package:family_money_management_app/main.dart';

/// Categories sub-screen + category studio (#325, `Settings v2.dc.html`):
/// one row per category (badge, name, "layer · N members"), add-then-open,
/// and a full-screen editor with layer chips (single-select) and assigned
/// people chips (multi-select). Delete keeps the events' times.
extension _ThriveCategoriesScreen on _ThriveHomeState {
  void openCategoriesScreen() {
    pushSettingsPage<void>((_) => _CategoriesScreen(state: this));
  }

  /// Create-a-category entry for other flows (e.g. the event ticket's
  /// "+ New" chip): opens the studio in create mode, scoped to [layerId].
  void openNewCategoryStudio({required String layerId}) {
    openEditorSheet<void>(
      (_) => _CategoryStudio(state: this, categoryId: null, layerId: layerId),
    );
  }
}

class _CategoriesScreen extends StatelessWidget {
  const _CategoriesScreen({required this.state});
  final _ThriveHomeState state;

  String _subFor(_ThriveHomeState s, EventCategory c) {
    final layer = s.layerDefFor(c.layerId)?.label ?? 'Appointments';
    final n = c.members.length;
    return n == 0
        ? '$layer · no one assigned'
        : '$layer · $n member${n == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) => SettingsSubScreen(
        sync: s.syncStatus,
        offline: s.netOffline,
        onOfflineTap: s.openPendingChangesScreen,
        title: 'Categories',
        subtitle: 'Colours & icons across the calendar',
        intro: 'Colours & icons used across the calendar. Tap one to edit it.',
        addPlaceholder: 'New category name…',
        emptyAddHint: 'Type a name first',
        onToast: s.flash,
        onAdd: (name) {
          final id = uid();
          s.saveCategory(
            id: id,
            name: name,
            color: s.firstAvailableCalendarIdentityColor(),
            icon: 'tag',
            members: <String>[],
            layerId: s.calendarLayers.firstOrNull?.id ?? kLayerAppt,
          );
          s.openEditorSheet<void>(
            (_) => _CategoryStudio(state: s, categoryId: id),
          );
        },
        children: [
          for (final c in s.eventCategories)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SettingsListRow(
                rowKey: ValueKey('cats-row-${c.id}'),
                leading: settingsBadgeTile(
                  color: c.color,
                  picture: c.picture,
                  emoji: c.emoji,
                  icon: c.icon,
                ),
                label: c.name,
                sub: _subFor(s, c),
                onTap: () => s.openEditorSheet<void>(
                  (_) => _CategoryStudio(state: s, categoryId: c.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen category editor (badge studio): name, badge, colour, layer
/// chips (one of the calendar layers) and assigned-people chips.
class _CategoryStudio extends StatefulWidget {
  const _CategoryStudio({
    required this.state,
    required this.categoryId,
    this.layerId,
  });
  final _ThriveHomeState state;

  /// `null` means create mode: the category only exists once saved.
  final String? categoryId;

  /// Starting layer for create mode.
  final String? layerId;

  @override
  State<_CategoryStudio> createState() => _CategoryStudioState();
}

class _CategoryStudioState extends State<_CategoryStudio> {
  late String _name;
  String? _emoji;
  String? _picture;
  late Color _color;
  late String _layerId;
  late List<String> _members;
  late String _icon;

  _ThriveHomeState get s => widget.state;

  EventCategory? get _cat => widget.categoryId == null
      ? null
      : s.eventCategories.where((c) => c.id == widget.categoryId).firstOrNull;

  @override
  void initState() {
    super.initState();
    final c = _cat;
    _name = c?.name ?? '';
    _emoji = c?.emoji;
    _picture = c?.picture;
    _color = c?.color ?? s.firstAvailableCalendarIdentityColor();
    _layerId =
        c?.layerId ??
        widget.layerId ??
        (s.calendarLayers.firstOrNull?.id ?? kLayerAppt);
    _members = List<String>.from(c?.members ?? const <String>[]);
    _icon = c?.icon ?? 'tag';
  }

  void _save() {
    s.saveCategory(
      id: widget.categoryId,
      name: _name,
      color: _color,
      icon: _icon,
      emoji: _emoji,
      picture: _picture,
      members: _members,
      layerId: _layerId,
    );
    Navigator.of(context).pop();
  }

  void _delete() {
    final c = _cat;
    if (c == null) return;
    final n = s.events.where((e) => e.category == c.id).length;
    showCountingConfirmSheet(
      context,
      title: 'Delete "${c.name}"?',
      message: n == 0
          ? 'Nothing uses this badge yet — it just disappears.'
          : (n == 1
                ? 'Its 1 event keeps its time — it just loses the badge.'
                : 'Its $n events keep their times — they just lose the '
                      'badge.'),
      confirmLabel: 'Delete category',
      onConfirm: () {
        s.deleteCategory(c.id);
        Navigator.of(context).maybePop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeMembers = (s.curFamily()?.members ?? const <FamilyMember>[])
        .where((m) => m.status == 'active')
        .toList();
    final editing = widget.categoryId != null;
    final layer = s.layerDefFor(_layerId)?.label ?? 'Appointments';
    final n = _members.length;
    return EditorSheet(
      title: editing ? 'Edit category' : 'New category',
      headerConfirmLabel: 'Save',
      showFooter: false,
      isDirty: _cat == null
          ? _name.trim().isNotEmpty || _emoji != null || _picture != null
          : _name != _cat!.name ||
                _emoji != _cat!.emoji ||
                _picture != _cat!.picture ||
                _color != _cat!.color ||
                _layerId != _cat!.layerId ||
                !foundation.listEquals(_members, _cat!.members),
      subtitle:
          '$layer · ${n == 0 ? 'nobody assigned' : '$n ${n == 1 ? 'person' : 'people'}'}',
      confirmLabel: editing ? 'Save category' : 'Add category',
      blockedReason: _name.trim().isEmpty ? 'Give it a name first' : null,
      onConfirm: _save,
      deleteLabel: editing ? 'Delete category — events keep their times' : null,
      onDelete: editing ? _delete : null,
      confirmKey: const ValueKey('studio-save'),
      deleteKey: const ValueKey('studio-delete'),
      children: [
        EdBadgeHeader(
          color: _color,
          name: _name,
          onName: (v) => setState(() => _name = v),
          picks: kEditorPicks['category']!,
          emoji: _emoji,
          picture: _picture,
          namePlaceholder: 'Name it… e.g. Work',
          onEmoji: (g) => setState(() {
            _emoji = g;
            _picture = null;
          }),
          onPickPhoto: () async {
            final p = await s.pickBadgePhoto();
            if (p != null && mounted) setState(() => _picture = p);
          },
          onToast: s.flash,
        ),
        EdSection(
          label: 'Calendar layer',
          hint: 'Where its events live',
          child: edChipWrap([
            for (final l in s.calendarLayers)
              edChip(
                key: ValueKey('cat-layer-${l.id}'),
                label: l.label,
                leading: l.emoji == null
                    ? null
                    : Text(l.emoji!, style: const TextStyle(fontSize: 14)),
                selected: _layerId == l.id,
                tone: l.color,
                onTap: () => setState(() => _layerId = l.id),
              ),
          ]),
        ),
        if (activeMembers.isNotEmpty)
          EdSection(
            label: "Who it's usually for",
            hint: 'Added to new events',
            gap: 12,
            child: edPeopleRow(
              members: activeMembers,
              selected: _members.toSet(),
              keyPrefix: 'cat-person',
              avatar: s.editorAvatar,
              onToggle: (id) => setState(() {
                if (!_members.remove(id)) _members.add(id);
              }),
            ),
          ),
        edColourSection(_color, (c) => setState(() => _color = c)),
      ],
    );
  }
}
