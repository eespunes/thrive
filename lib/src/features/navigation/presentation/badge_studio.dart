part of 'package:family_money_management_app/main.dart';

/// Badge studio (#324, `Settings v2.dc.html`): the ONE shared design for all
/// six full-screen editors (category, member, imported feed, calendar layer,
/// account, budget block) plus the list conventions their sub-screens share.
///
/// Everything here is deliberately decoupled from `_ThriveHomeState`: the
/// widgets take plain values and callbacks (`onToast` instead of `flash`,
/// `onPickPhoto` instead of the image-picker plumbing), so each editor issue
/// can wire them to real state while tests mount them directly.
// ------------------------------------------------------------------ route

/// Pushes a full-screen badge-studio page (editors are full screens, not
/// popups — smaller interactions stay bottom sheets).
Future<T?> pushBadgeStudio<T>(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: builder));
}

// --------------------------------------------------------------- scaffold

/// Full-screen editor scaffold: ‹ back header (title + subtitle), scrolling
/// form body, and the sticky footer — save pinned to the true bottom (the
/// content fades under it), tinted in the badge colour and disabled grey
/// until valid; delete as a red text link UNDER save, never beside it.
class BadgeStudioScaffold extends StatelessWidget {
  const BadgeStudioScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.accent,
    required this.saveLabel,
    required this.saveEnabled,
    required this.onSave,
    this.deleteLabel,
    this.onDelete,
    this.onBack,
    required this.children,
  });

  final String title;
  final String? subtitle;

  /// The item's colour — it tints its own editor (stage + save button).
  final Color accent;
  final String saveLabel;
  final bool saveEnabled;
  final VoidCallback onSave;

  /// Descriptive red link under save, e.g. "Delete layer — its events move
  /// to another layer". Hidden when null (e.g. min-1 guard or a new item).
  final String? deleteLabel;
  final VoidCallback? onDelete;

  /// Defaults to popping the route.
  final VoidCallback? onBack;
  final List<Widget> children;

  static const Color _pageBg = Color(0xfff8fafc);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            studioBackHeader(
              title: title,
              subtitle: subtitle,
              onBack: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        // Room for the sticky footer so the last field can
                        // scroll clear of it.
                        deleteLabel != null ? 132 : 96,
                      ),
                      children: children,
                    ),
                  ),
                  Positioned(left: 0, right: 0, bottom: 0, child: _footer()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      // Content fades under the footer, per the design's
      // `linear-gradient(#f8fafc00,#f8fafc 30%)`.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00f8fafc), _pageBg],
          stops: [0, .3],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            key: const ValueKey('studio-save'),
            behavior: HitTestBehavior.opaque,
            onTap: saveEnabled ? onSave : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: saveEnabled ? accent : const Color(0xffe2e8f0),
                borderRadius: BorderRadius.circular(13),
                boxShadow: saveEnabled
                    ? [
                        BoxShadow(
                          color: accent,
                          blurRadius: 26,
                          spreadRadius: -14,
                          offset: const Offset(0, 12),
                        ),
                      ]
                    : const [],
              ),
              child: Text(
                saveLabel,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: saveEnabled
                      ? contrastOn(accent)
                      : B.muted,
                ),
              ),
            ),
          ),
          if (deleteLabel != null)
            GestureDetector(
              key: const ValueKey('studio-delete'),
              behavior: HitTestBehavior.opaque,
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 13, 11, 2),
                child: Text(
                  deleteLabel!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: B.red,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The studio's standard sub-screen header: ‹ back button + title/subtitle.
Widget studioBackHeader({
  required String title,
  String? subtitle,
  required VoidCallback onBack,
  Widget? trailing,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    child: Row(
      children: [
        GestureDetector(
          key: const ValueKey('studio-back'),
          behavior: HitTestBehavior.opaque,
          onTap: onBack,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: B.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: ic('cleft', size: 16, sw: 2.4, color: B.text)),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                  color: B.ink,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: B.muted,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    ),
  );
}

// ------------------------------------------------------------ badge stage

/// The badge stage at the top of every editor: a 96px circular badge tinted
/// in the item's colour with the item's name written on it (inline editable,
/// in that colour). Tapping the badge opens the photo picker; the "type an
/// emoji" link opens a free input that accepts ANY OS emoji, multi-codepoint
/// included — there are no fixed emoji grids anywhere.
class BadgeStage extends StatefulWidget {
  const BadgeStage({
    super.key,
    required this.color,
    required this.name,
    required this.onName,
    this.emoji,
    this.picture,
    this.fallbackGlyph = '🏷',
    this.namePlaceholder = 'Name it…',
    required this.onEmoji,
    required this.onPickPhoto,
    this.onToast,
  });

  final Color color;
  final String name;
  final ValueChanged<String> onName;

  /// Current emoji glyph; ignored while [picture] is set.
  final String? emoji;

  /// Base64 picture — replaces the emoji on the badge when set.
  final String? picture;

  /// Shown when there is no picture and no emoji yet.
  final String fallbackGlyph;
  final String namePlaceholder;
  final ValueChanged<String> onEmoji;

  /// Tap on the badge — the caller opens its photo picker here.
  final VoidCallback onPickPhoto;
  final ValueChanged<String>? onToast;

  @override
  State<BadgeStage> createState() => _BadgeStageState();
}

class _BadgeStageState extends State<BadgeStage> {
  late final TextEditingController _name = TextEditingController(
    text: widget.name,
  );
  final TextEditingController _emoji = TextEditingController();
  bool _emojiOpen = false;

  @override
  void didUpdateWidget(BadgeStage old) {
    super.didUpdateWidget(old);
    if (widget.name != old.name && widget.name != _name.text) {
      _name.text = widget.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    super.dispose();
  }

  void _toast(String msg) => widget.onToast?.call(msg);

  /// Applies the typed emoji. Any single OS emoji is fine — flag/skin-tone/
  /// ZWJ sequences span many code units, so short inputs are kept whole and
  /// longer ones fall back to the first grapheme (mirrors the design's
  /// `mkApply`).
  void _applyEmoji() {
    final v = _emoji.text.trim();
    if (v.isEmpty) {
      _toast('Type an emoji first — any one your keyboard has');
      return;
    }
    final g = v.length <= 8 ? v : v.characters.first;
    widget.onEmoji(g);
    setState(() {
      _emojiOpen = false;
      _emoji.clear();
    });
    _toast('Emoji set');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.withValues(alpha: .13),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
          child: Column(
            children: [
              GestureDetector(
                key: const ValueKey('badge-stage-badge'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.onPickPhoto,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                    boxShadow: [
                      BoxShadow(
                        color: c,
                        blurRadius: 36,
                        spreadRadius: -16,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _badgeFace(),
                ),
              ),
              TextField(
                key: const ValueKey('badge-stage-name'),
                controller: _name,
                onChanged: widget.onName,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 8),
                  hintText: widget.namePlaceholder,
                  hintStyle: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                    color: c.withValues(alpha: .45),
                  ),
                ),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                  color: c,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'tap the badge for a picture · ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: B.muted,
                      ),
                    ),
                    GestureDetector(
                      key: const ValueKey('badge-stage-emoji-link'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        _emojiOpen = !_emojiOpen;
                        _emoji.clear();
                      }),
                      child: const Text(
                        'type an emoji',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: B.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_emojiOpen)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: B.primary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      key: const ValueKey('badge-stage-emoji-input'),
                      controller: _emoji,
                      onSubmitted: (_) => _applyEmoji(),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 11,
                        ),
                        hintText: 'Type any emoji — your keyboard has them all',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: B.muted,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  key: const ValueKey('badge-stage-emoji-use'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _applyEmoji,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: B.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Use',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _badgeFace() {
    final pic = widget.picture;
    if (pic != null && pic.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(pic),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      } catch (_) {
        // Broken payloads fall back to the glyph below.
      }
    }
    final glyph = (widget.emoji?.isNotEmpty ?? false)
        ? widget.emoji!
        : widget.fallbackGlyph;
    return Center(child: Text(glyph, style: const TextStyle(fontSize: 42)));
  }
}

// -------------------------------------------------------- counting confirm

/// The counting confirm sheet under every delete link: the message spells
/// out what the item takes with it ("It takes its 4 lines with it…") so the
/// caller counts the consequences before the red button.
Future<void> showCountingConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required VoidCallback onConfirm,
  bool danger = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x73101828),
    builder: (ctx) => Container(
      // Keep the confirm buttons clear of the Android system navigation bar.
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        20 + MediaQuery.of(ctx).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xffe2e8f0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -.3,
              color: B.ink,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 12),
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: B.muted,
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('counting-confirm-go'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: danger ? B.red : B.primary,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                confirmLabel,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('counting-confirm-cancel'),
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(ctx).pop(),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(12, 14, 12, 2),
              child: Text(
                'Cancel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: B.soft2,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// -------------------------------------------------------- list conventions

/// Standard sub-screen chrome (#324): ‹ back header, intro line, rows, an
/// optional footnote, and the add pattern — a name input + Add at the bottom
/// that creates the item with defaults; the caller then immediately opens
/// its editor from [onAdd].
class SettingsSubScreen extends StatefulWidget {
  const SettingsSubScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.intro,
    required this.children,
    this.footnote,
    this.addPlaceholder,
    this.addLabel = 'Add',
    this.onAdd,
    this.emptyAddHint = 'Type a name first',
    this.onBack,
    this.onToast,
    this.sync,
    this.offline,
  });

  final String title;
  final String? subtitle;

  /// Write-status pill in the header (#283): "Saving… → Saved ✓", or
  /// "Queued — offline" while disconnected. Null hides the slot.
  final foundation.ValueListenable<SettingsSyncStatus?>? sync;

  /// When it reports true, the amber offline strip renders under the header.
  final foundation.ValueListenable<bool>? offline;

  /// The one-liner under the header explaining the screen.
  final String? intro;
  final List<Widget> children;
  final String? footnote;

  /// When set, the add row (input + [addLabel]) renders under the rows.
  final String? addPlaceholder;
  final String addLabel;
  final ValueChanged<String>? onAdd;
  final String emptyAddHint;
  final VoidCallback? onBack;
  final ValueChanged<String>? onToast;

  @override
  State<SettingsSubScreen> createState() => _SettingsSubScreenState();
}

class _SettingsSubScreenState extends State<SettingsSubScreen> {
  final TextEditingController _add = TextEditingController();

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _add.text.trim();
    if (name.isEmpty) {
      widget.onToast?.call(widget.emptyAddHint);
      return;
    }
    _add.clear();
    widget.onAdd?.call(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BadgeStudioScaffold._pageBg,
      body: SafeArea(
        child: Column(
          children: [
            studioBackHeader(
              title: widget.title,
              subtitle: widget.subtitle,
              onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
              trailing: widget.sync == null
                  ? null
                  : ValueListenableBuilder<SettingsSyncStatus?>(
                      valueListenable: widget.sync!,
                      builder: (context, status, _) => status == null
                          ? const SizedBox.shrink()
                          : settingsSyncPill(status),
                    ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                children: [
                  if (widget.offline != null)
                    ValueListenableBuilder<bool>(
                      valueListenable: widget.offline!,
                      builder: (context, off, _) => off
                          ? settingsOfflineBanner()
                          : const SizedBox.shrink(),
                    ),
                  if (widget.intro != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                      child: Text(
                        widget.intro!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: B.muted,
                        ),
                      ),
                    ),
                  ...widget.children,
                  if (widget.addPlaceholder != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: B.line),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                key: const ValueKey('list-add-input'),
                                controller: _add,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 11,
                                  ),
                                  hintText: widget.addPlaceholder,
                                  hintStyle: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: B.muted,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: B.ink,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            key: const ValueKey('list-add-button'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _submit,
                            child: Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: B.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.addLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.footnote != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
                      child: Text(
                        widget.footnote!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: B.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------- hold-drag reorder

/// Drag-start listener with the studio's ~0.3s hold (the SDK's delayed
/// listener is fixed at 500ms).
class HoldDragStartListener extends ReorderableDragStartListener {
  const HoldDragStartListener({
    super.key,
    required super.child,
    required super.index,
    this.delay = const Duration(milliseconds: 300),
  });

  final Duration delay;

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(delay: delay, debugOwner: this);
  }
}

/// Hold-and-drag reorder list (#324): a ~0.3s press lifts the row (shadow +
/// 1.02 scale), reordering is live while dragging, and dropping toasts
/// "Order saved for the whole family". A plain tap still reaches the row's
/// own onTap (i.e. opens the editor). Used by Calendar layers, Accounts and
/// Budget blocks.
class HoldDragList extends StatelessWidget {
  const HoldDragList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
    this.onToast,
    this.spacing = 6,
  });

  final int itemCount;

  /// Must return a row for index [i]; it is wrapped in the keyed hold-drag
  /// listener, so the row itself needs no key.
  final Widget Function(BuildContext context, int i) itemBuilder;

  /// Called with the final (from → to) indices after a drop.
  final void Function(int from, int to) onReorder;
  final ValueChanged<String>? onToast;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: itemCount,
      proxyDecorator: (child, index, animation) => Transform.scale(
        scale: 1.02,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 12,
          shadowColor: const Color(0x73101828),
          child: child,
        ),
      ),
      // onReorderItem already adjusts `to` for the lifted row.
      onReorderItem: (from, to) {
        if (to != from) onReorder(from, to);
        onToast?.call('Order saved for the whole family');
      },
      itemBuilder: (ctx, i) => HoldDragStartListener(
        key: ValueKey('hold-drag-$i'),
        index: i,
        child: Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: itemBuilder(ctx, i),
        ),
      ),
    );
  }
}
