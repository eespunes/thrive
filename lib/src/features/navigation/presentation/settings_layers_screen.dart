part of 'package:family_money_management_app/main.dart';

/// Calendar layers sub-screen + layer studio (#327, `Settings v2.dc.html`):
/// one row per layer with a visibility toggle (min-1 guard), hold-and-drag
/// reorder, add-by-label, and a full-screen badge-studio editor whose delete
/// moves the layer's events to another layer.
extension _ThriveLayersScreen on _ThriveHomeState {
  void openCalendarLayersScreen() {
    pushSettingsPage<void>((_) => _CalendarLayersScreen(state: this));
  }

  /// Palette for layer/category/import/badge editors: the calendar identity
  /// colours, with [current] prepended when it isn't part of the palette
  /// (legacy data can carry any colour).
  List<Color> badgePaletteWith(Color current) => [
    if (!kCatColors.contains(current)) current,
    ...kCatColors,
  ];

  /// Visibility toggle with the audible min-1 guard (#327):
  /// `toggleLayerFilter` alone would just silently ignore the tap.
  void toggleLayerVisibilityGuarded(String id) {
    final on = layerFilter.contains(id);
    final onCount = calendarLayers
        .where((l) => layerFilter.contains(l.id))
        .length;
    if (on && onCount <= 1) {
      flash('At least one layer stays on');
      return;
    }
    toggleLayerFilter(id);
  }

  /// Moves the layer at [from] to [to] in the shared display order.
  void reorderCalendarLayers(int from, int to) {
    mutate(() {
      final l = calendarLayers.removeAt(from);
      calendarLayers.insert(to, l);
    });
  }
}

class _CalendarLayersScreen extends StatelessWidget {
  const _CalendarLayersScreen({required this.state});
  final _ThriveHomeState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) {
        final layers = s.calendarLayers;
        return SettingsSubScreen(
          title: 'Calendar layers',
          subtitle: 'Appointments, to-dos & content',
          intro:
              'Toggle or add layers — hold a row and drag to rearrange. '
              'A switched-off layer hides from the calendar; nothing is '
              'deleted.',
          footnote:
              'Deleting a layer (inside its editor) moves its events to '
              'another layer.',
          addPlaceholder: 'New layer label…',
          emptyAddHint: 'Type a label first',
          onToast: s.flash,
          onAdd: (name) {
            s.addCalendarLayer(
              label: name,
              icon: 'cal',
              color: kCatColors[(layers.length + 3) % kCatColors.length],
            );
            s.flash('"$name" added');
          },
          children: [
            HoldDragList(
              itemCount: layers.length,
              onReorder: s.reorderCalendarLayers,
              onToast: s.flash,
              itemBuilder: (context, i) {
                final l = layers[i];
                return SettingsListRow(
                  rowKey: ValueKey('layers-row-${l.id}'),
                  leading: settingsBadgeTile(
                    color: l.color,
                    picture: l.picture,
                    emoji: l.emoji,
                    icon: l.icon,
                  ),
                  label: l.label,
                  toggle: s.layerFilter.contains(l.id),
                  toggleKey: ValueKey('layers-toggle-${l.id}'),
                  onToggle: () => s.toggleLayerVisibilityGuarded(l.id),
                  onTap: () => s.pushSettingsPage<void>(
                    (_) => _LayerStudio(state: s, layerId: l.id),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Full-screen layer editor (badge studio): label, badge, colour; delete
/// (min-1 guard) moves its events to another layer.
class _LayerStudio extends StatefulWidget {
  const _LayerStudio({required this.state, required this.layerId});
  final _ThriveHomeState state;
  final String layerId;

  @override
  State<_LayerStudio> createState() => _LayerStudioState();
}

class _LayerStudioState extends State<_LayerStudio> {
  late String _label;
  String? _emoji;
  String? _picture;
  late Color _color;

  _ThriveHomeState get s => widget.state;

  @override
  void initState() {
    super.initState();
    final l = s.layerDefFor(widget.layerId);
    _label = l?.label ?? '';
    _emoji = l?.emoji;
    _picture = l?.picture;
    _color = l?.color ?? B.primary;
  }

  void _save() {
    final l = s.layerDefFor(widget.layerId);
    if (l == null) return;
    s.updateCalendarLayer(
      id: l.id,
      label: _label,
      icon: l.icon,
      emoji: _emoji,
      picture: _picture,
      color: _color,
    );
    s.flash('Layer saved');
    Navigator.of(context).maybePop();
  }

  void _delete() {
    final l = s.layerDefFor(widget.layerId);
    if (l == null) return;
    final n = s.events
        .where((e) => !e.kitchenOrigin && e.layerId == l.id)
        .length;
    showCountingConfirmSheet(
      context,
      title: 'Delete "${l.label}"?',
      message: n == 0
          ? 'It has no events — it just disappears from the calendar.'
          : (n == 1
                ? 'It takes its 1 event with it — it moves to another layer.'
                : 'It takes its $n events with it — they move to another '
                      'layer.'),
      confirmLabel: 'Delete layer',
      onConfirm: () {
        s.removeCalendarLayer(l.id);
        Navigator.of(context).maybePop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = s.calendarLayers.length > 1;
    return BadgeStudioScaffold(
      title: 'Edit layer',
      subtitle: 'Label, colour & glyph',
      accent: _color,
      saveLabel: 'Save layer',
      saveEnabled: _label.trim().isNotEmpty,
      onSave: _save,
      deleteLabel: canDelete
          ? 'Delete layer — its events move to another layer'
          : null,
      onDelete: canDelete ? _delete : null,
      children: [
        BadgeStage(
          color: _color,
          name: _label,
          onName: (v) => setState(() => _label = v),
          emoji: _emoji,
          picture: _picture,
          fallbackGlyph: '🗂',
          namePlaceholder: 'Name it… e.g. Workouts',
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
