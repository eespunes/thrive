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
    pushSettingsPage<void>(
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
          s.pushSettingsPage<void>(
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
                onTap: () => s.pushSettingsPage<void>(
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
    Navigator.of(context).maybePop();
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
    return BadgeStudioScaffold(
      title: editing ? 'Edit category' : 'New category',
      subtitle: 'Colour, icon, layer & assigned people',
      accent: _color,
      saveLabel: editing ? 'Save category' : 'Add category',
      saveEnabled: _name.trim().isNotEmpty,
      onSave: _save,
      deleteLabel: editing ? 'Delete category — events keep their times' : null,
      onDelete: editing ? _delete : null,
      children: [
        BadgeStage(
          color: _color,
          name: _name,
          onName: (v) => setState(() => _name = v),
          emoji: _emoji,
          picture: _picture,
          fallbackGlyph: '🏷',
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
        studioSectionLabel('Layer'),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final l in s.calendarLayers)
                studioChip(
                  key: ValueKey('cat-layer-${l.id}'),
                  label: l.emoji != null ? '${l.emoji} ${l.label}' : l.label,
                  selected: _layerId == l.id,
                  onTap: () => setState(() => _layerId = l.id),
                ),
            ],
          ),
        ),
        studioSectionLabel('Assigned people'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in activeMembers)
                studioChip(
                  key: ValueKey('cat-person-${m.id}'),
                  label: _members.contains(m.id)
                      ? '✓ ${m.name.split(' ').first}'
                      : m.name.split(' ').first,
                  selected: _members.contains(m.id),
                  onTap: () => setState(() {
                    if (!_members.remove(m.id)) _members.add(m.id);
                  }),
                ),
            ],
          ),
        ),
        BadgeColorRow(
          colors: s.badgePaletteWith(_color),
          selected: _color,
          onPick: (c) => setState(() => _color = c),
          onToast: s.flash,
        ),
      ],
    );
  }
}
