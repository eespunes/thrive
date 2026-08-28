part of 'package:family_money_management_app/main.dart';

/// Shared plumbing for the Settings v2 sub-screens (#325–#329, #276, #281,
/// #282, `Settings v2.dc.html`): the studio page wrapper (which re-hosts the
/// app toast above pushed full-screen routes), the standard list row, chips,
/// toggle rows and the photo-picking helper every badge editor reuses.
extension _ThriveSettingsShared on _ThriveHomeState {
  /// Pushes a settings page full screen, re-rendering the global toast pill
  /// on top of it (the home Scaffold's own toast sits BELOW pushed routes).
  Future<T?> pushSettingsPage<T>(WidgetBuilder builder) {
    return pushBadgeStudio<T>(
      context,
      (ctx) => Stack(
        children: [
          Positioned.fill(child: Builder(builder: builder)),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            // The pill is purely informative — never swallow taps meant for
            // the save/delete footer underneath it.
            child: IgnorePointer(
              child: ValueListenableBuilder<String?>(
                valueListenable: _toastNotifier,
                builder: (context, msg, _) => msg == null
                    ? const SizedBox.shrink()
                    : Center(child: _buildToast(msg)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // coverage:ignore-start
  /// Opens the gallery picker and returns the picked image as base64 (the
  /// same plumbing as the profile sheet), or `null` when cancelled/failed.
  Future<String?> pickBadgePhoto() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 82,
      );
      if (file == null) return null;
      return base64Encode(await file.readAsBytes());
    } catch (_) {
      showError('Could not load image');
      return null;
    }
  }
  // coverage:ignore-end
}

/// The standard settings-list row (`Settings v2.dc.html` `row()`): grey
/// rounded row with a leading badge, label/sub, an optional right-side value
/// pill (amber when [warnVal], green when [goodVal]), chevron, and optional
/// trailing toggle / star stepper plus a quick-chips strip underneath.
class SettingsListRow extends StatelessWidget {
  const SettingsListRow({
    super.key,
    this.rowKey,
    this.leading,
    required this.label,
    this.sub,
    this.value,
    this.warnVal = false,
    this.goodVal = false,
    this.onTap,
    this.noChev = false,
    this.toggle,
    this.toggleKey,
    this.onToggle,
    this.stars,
    this.starsKeyPrefix,
    this.onStarsMinus,
    this.onStarsPlus,
    this.actions = const <Widget>[],
  });

  final Key? rowKey;
  final Widget? leading;
  final String label;
  final String? sub;
  final String? value;
  final bool warnVal;
  final bool goodVal;
  final VoidCallback? onTap;
  final bool noChev;

  /// Trailing 42×25 track toggle when non-null.
  final bool? toggle;
  final Key? toggleKey;
  final VoidCallback? onToggle;

  /// Reward-star stepper (kitchen wall) when non-null.
  final int? stars;

  /// Prefix for the −/+ button keys, so rows stay individually testable.
  final String? starsKeyPrefix;
  final VoidCallback? onStarsMinus;
  final VoidCallback? onStarsPlus;

  /// Quick chips rendered under the row (imported calendars).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final core = GestureDetector(
      key: rowKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? onToggle,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: B.page,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 9)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
                    ),
                  ),
                  if (sub != null && sub!.isNotEmpty)
                    Text(
                      sub!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff8a96a8),
                      ),
                    ),
                ],
              ),
            ),
            if (value != null && value!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: warnVal
                      ? B.amberSoft
                      : (goodVal ? B.greenSoft : const Color(0xffe8ecf2)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  value!,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: warnVal
                        ? B.amberText
                        : (goodVal ? B.greenText : B.soft2),
                  ),
                ),
              ),
            ],
            if (onTap != null && !noChev) ...[
              const SizedBox(width: 4),
              ic('cright', size: 14, sw: 2.2, color: const Color(0xffc2cad6)),
            ],
          ],
        ),
      ),
    );

    final trailing = <Widget>[
      if (toggle != null) ...[
        const SizedBox(width: 8),
        _StudioToggle(key: toggleKey, on: toggle!, onTap: onToggle),
      ],
      if (stars != null) ...[
        const SizedBox(width: 6),
        _StarStepper(
          stars: stars!,
          keyPrefix: starsKeyPrefix,
          onMinus: onStarsMinus,
          onPlus: onStarsPlus,
        ),
      ],
    ];

    final row = trailing.isEmpty
        ? core
        : Row(
            children: [
              Expanded(child: core),
              ...trailing,
            ],
          );
    if (actions.isEmpty) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 4),
          child: Wrap(spacing: 5, runSpacing: 5, children: actions),
        ),
      ],
    );
  }
}

/// The design's small track toggle (42×25, teal when on).
class _StudioToggle extends StatelessWidget {
  const _StudioToggle({super.key, required this.on, this.onTap});
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 42,
          height: 25,
          padding: const EdgeInsets.all(2.5),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: on ? B.primary : const Color(0xffcfd6df),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// −/★ n/+ reward-star stepper (kitchen wall, clamped 0–5 by the caller).
class _StarStepper extends StatelessWidget {
  const _StarStepper({
    required this.stars,
    this.keyPrefix,
    this.onMinus,
    this.onPlus,
  });
  final int stars;
  final String? keyPrefix;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  Widget _btn(Key key, String glyph, VoidCallback? onTap) => GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        glyph,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: B.text,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(ValueKey('${keyPrefix ?? 'star'}-minus'), '−', onMinus),
        Container(
          constraints: const BoxConstraints(minWidth: 30),
          alignment: Alignment.center,
          child: Text(
            '★ $stars',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: B.amberText,
            ),
          ),
        ),
        _btn(ValueKey('${keyPrefix ?? 'star'}-plus'), '+', onPlus),
      ],
    );
  }
}

/// A 34px rounded glyph tile for list rows: colour background with picture/
/// emoji, falling back to a stroke icon (or [fallbackText]).
Widget settingsBadgeTile({
  required Color color,
  String? picture,
  String? emoji,
  String? icon,
  String? fallbackText,
  double size = 34,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(11),
    ),
    clipBehavior: Clip.antiAlias,
    child: glyphTile(
      size: size,
      radius: 11,
      picture: picture,
      emoji: emoji,
      emojiSize: size * .5,
      fallback: Center(
        child: fallbackText != null
            ? Text(
                fallbackText,
                style: TextStyle(
                  color: contrastOn(color),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              )
            : ic(icon ?? 'folder', size: 16, sw: 2.2, color: contrastOn(color)),
      ),
    ),
  );
}

/// UPPERCASE section label inside a badge-studio form.
Widget studioSectionLabel(String label, {EdgeInsets? padding}) => Padding(
  padding: padding ?? const EdgeInsets.only(bottom: 6, top: 2),
  child: Text(
    label.toUpperCase(),
    style: const TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: .4,
      color: B.muted,
    ),
  ),
);

/// A selectable chip; when [tone] is set the chip tints in that colour when
/// selected (category chips in the feed editor carry the category tint).
Widget studioChip({
  Key? key,
  required String label,
  required bool selected,
  required VoidCallback onTap,
  Color? tone,
  bool expand = false,
}) {
  final t = tone ?? B.primary;
  final chip = GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      constraints: BoxConstraints(minHeight: expand ? 42 : 34),
      alignment: expand ? Alignment.center : null,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? t.withValues(alpha: .12) : Colors.white,
        border: Border.all(
          color: selected ? t : const Color(0xffe2e7ee),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: selected ? t : const Color(0xff475569),
        ),
      ),
    ),
  );
  return chip;
}

/// A white toggle row inside a badge-studio form card.
Widget studioToggleRow({
  Key? key,
  required String label,
  String? sub,
  required bool value,
  required VoidCallback onChanged,
  bool boxed = true,
}) {
  final row = Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: B.ink,
              ),
            ),
            if (sub != null && sub.isNotEmpty)
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff8a96a8),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(width: 9),
      _StudioToggle(on: value, onTap: onChanged),
    ],
  );
  final core = GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onChanged,
    child: boxed
        ? Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xfff8fafc),
              border: Border.all(color: const Color(0xffeef1f5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: row,
          )
        : Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: row),
  );
  return core;
}

/// A bordered text field used inside badge-studio forms.
Widget studioTextField({
  Key? key,
  required TextEditingController controller,
  required String hint,
  ValueChanged<String>? onChanged,
  TextInputType? keyboardType,
  EdgeInsets margin = const EdgeInsets.only(bottom: 10),
}) {
  return Container(
    margin: margin,
    decoration: BoxDecoration(
      color: const Color(0xfff4f6f9),
      border: Border.all(color: B.line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: TextField(
      key: key,
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: B.muted,
        ),
      ),
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: B.ink,
      ),
    ),
  );
}

/// A white grouped card inside a badge-studio form (the feed editor's three
/// cards), with an UPPERCASE heading.
Widget studioCard({required String title, required List<Widget> children}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: B.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        studioSectionLabel(title, padding: const EdgeInsets.only(bottom: 8)),
        ...children,
      ],
    ),
  );
}
