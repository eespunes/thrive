part of 'package:family_money_management_app/main.dart';

/// Kitchen wall sub-page (#281, `Settings v2.dc.html`): per-layer show/hide
/// toggles with an audible min-1 guard, and per active member the photo-tile
/// vs colour-tile toggle plus the 0–5 reward-star stepper. The wall's master
/// on/off lives on the calendar's view switcher, not here.
extension _ThriveKitchenScreen on _ThriveHomeState {
  void openKitchenWallScreen() {
    pushSettingsPage<void>((_) => _KitchenWallScreen(state: this));
  }

  /// Wall-layer toggle with the audible min-1 guard (#281):
  /// `toggleKitchenWallLayer` alone silently ignores the last-layer tap.
  void toggleKitchenWallLayerGuarded(String id) {
    final visible = kitchenLayerFilter.contains(id);
    final visibleCount = _kitchenWallLayers(
      this,
    ).where((l) => kitchenLayerFilter.contains(l.id)).length;
    if (visible && visibleCount <= 1) {
      flash('At least one layer stays visible');
      return;
    }
    toggleKitchenWallLayer(id);
  }

  /// −/+ reward-star stepper (clamped 0–5).
  void stepMemberStars(String memberId, int delta) {
    mutate(() {
      starsMap[memberId] = ((starsMap[memberId] ?? 0) + delta).clamp(0, 5);
    });
  }
}

class _KitchenWallScreen extends StatelessWidget {
  const _KitchenWallScreen({required this.state});
  final _ThriveHomeState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) {
        final layers = _kitchenWallLayers(s);
        final members = (s.curFamily()?.members ?? const <FamilyMember>[])
            .where((m) => m.status == 'active')
            .toList();
        return SettingsSubScreen(
          title: 'Kitchen wall',
          subtitle: 'The shared tablet screen',
          intro:
              'Layers and picture mode for the shared tablet. The wall’s '
              'on/off switch lives on the calendar’s view switcher — it’s '
              '${s.kitchenEnabled ? 'on' : 'off'} right now.',
          footnote:
              'At least one layer stays visible. Photo tile uses the '
              'member’s picture instead of their colour; stars are the '
              'reward tracker (0–5).',
          onToast: s.flash,
          children: [
            for (final l in layers)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SettingsListRow(
                  rowKey: ValueKey('kitchen-layer-${l.id}'),
                  leading: settingsBadgeTile(
                    color: l.color,
                    picture: l.picture,
                    emoji: l.emoji,
                    icon: l.icon,
                  ),
                  label: '${l.label} layer',
                  toggle: s.kitchenLayerFilter.contains(l.id),
                  toggleKey: ValueKey('kitchen-layer-toggle-${l.id}'),
                  onToggle: () => s.toggleKitchenWallLayerGuarded(l.id),
                ),
              ),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SettingsListRow(
                  rowKey: ValueKey('kitchen-member-${m.id}'),
                  leading: s.avatarNode(
                    photo: m.photo,
                    emoji: m.emoji,
                    initials: m.initials,
                    color: m.color,
                    size: 30,
                    radius: 15,
                    fs: 12,
                  ),
                  label: m.name,
                  sub:
                      '${s.pictureModeFor(m.id) ? 'Photo tile' : 'Colour tile'}'
                      ' · reward stars',
                  toggle: s.pictureModeFor(m.id),
                  toggleKey: ValueKey('kitchen-picmode-${m.id}'),
                  onToggle: () => s.togglePictureModeFor(m.id),
                  stars: s.starsFor(m.id),
                  starsKeyPrefix: 'kitchen-stars-${m.id}',
                  onStarsMinus: () => s.stepMemberStars(m.id, -1),
                  onStarsPlus: () => s.stepMemberStars(m.id, 1),
                ),
              ),
          ],
        );
      },
    );
  }
}
