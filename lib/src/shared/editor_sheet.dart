part of 'package:family_money_management_app/main.dart';

/// The ONE editor language (#399, `docs/design/Editors.dc.html`): every
/// create/edit form — finance entry, category, calendar layer, member,
/// account, budget block, monthly limit, list, meal and wallet card — is a
/// bottom sheet with the same anatomy:
///
/// * a grab handle and a `Cancel | title + subtitle` header,
/// * a scrolling body of sections 18px apart, ending in an outlined red
///   delete button when the item exists,
/// * a pinned footer: a one-line plain-language summary above the confirm
///   button. While the form is incomplete the confirm button is greyed and
///   says WHY ("Give it a name first") instead of being silently dead.
///
/// Every colour comes from the app colour module ([B]).

/// Opens [builder] as an editor sheet. When [toast] is given, the app toast
/// is re-hosted above the sheet so feedback raised while it is open (e.g.
/// "Emoji set") is not hidden behind the scrim.
Future<T?> showEditorSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  ValueNotifier<String?>? toast,
  Widget Function(String msg)? toastBuilder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.tc.scrim,
    builder: (ctx) {
      final sheet = Builder(builder: builder);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: toast == null || toastBuilder == null
            ? sheet
            : Stack(
                children: [
                  sheet,
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 44,
                    child: IgnorePointer(
                      child: ValueListenableBuilder<String?>(
                        valueListenable: toast,
                        builder: (context, msg, _) => msg == null
                            ? const SizedBox.shrink()
                            : Center(child: toastBuilder(msg)),
                      ),
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

extension _ThriveEditorSheets on _ThriveHomeState {
  /// Opens an editor sheet with the app toast hosted above it. With
  /// [monthScoped] it refuses to open on a closed month.
  Future<T?> openEditorSheet<T>(
    WidgetBuilder builder, {
    bool monthScoped = false,
  }) async {
    if (monthScoped && isClosed()) {
      showError('Month is closed');
      return null;
    }
    update(() => swipedId = null);
    return showEditorSheet<T>(
      context,
      builder,
      toast: _toastNotifier,
      toastBuilder: _buildToast,
    );
  }

  /// A member's round avatar for editor people rows.
  Widget editorAvatar(FamilyMember m, double size) => avatarNode(
    photo: m.photo,
    emoji: m.emoji,
    initials: m.initials,
    color: m.color,
    size: size,
    radius: size / 2,
    fs: size * .34,
  );
}

// ------------------------------------------------------------------ shell

class EditorSheet extends StatelessWidget {
  const EditorSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.pinned,
    this.summary,
    this.confirmLabel = 'Save',
    this.blockedReason,
    this.onConfirm,
    this.destructiveConfirm = false,
    this.deleteLabel,
    this.onDelete,
    this.onCancel,
    this.showFooter = true,
    this.confirmKey = const ValueKey('editor-confirm'),
    this.deleteKey = const ValueKey('editor-delete'),
    this.cancelKey = const ValueKey('editor-cancel'),
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Optional strip pinned between the header and the scrolling body (the
  /// event editor's Event/To-do switch), so it stays on screen while
  /// scrolling.
  final Widget? pinned;

  /// One-line plain-language read-back shown above the confirm button.
  final String? summary;
  final String confirmLabel;

  /// When set the confirm button is disabled and shows this text instead.
  final String? blockedReason;
  final VoidCallback? onConfirm;

  /// "Remove limit" / "Clear dinner": a white button with red text.
  final bool destructiveConfirm;
  final String? deleteLabel;
  final VoidCallback? onDelete;

  /// Defaults to popping the sheet.
  final VoidCallback? onCancel;
  final bool showFooter;
  final Key confirmKey;
  final Key deleteKey;
  final Key cancelKey;

  @override
  Widget build(BuildContext context) {
    final body = <Widget>[];
    for (final c in children) {
      if (body.isNotEmpty) body.add(const SizedBox(height: 18));
      body.add(c);
    }
    if (deleteLabel != null && onDelete != null) {
      if (body.isNotEmpty) body.add(const SizedBox(height: 18));
      body.add(_deleteButton());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight * .94
            : MediaQuery.of(context).size.height * .94;
        return Container(
          constraints: BoxConstraints(maxHeight: maxH),
          decoration: BoxDecoration(
            color: context.tc.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              if (pinned != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: pinned,
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    showFooter
                        ? 20
                        : 20 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: body,
                  ),
                ),
              ),
              if (showFooter) _footer(context),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: context.tc.handle,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      key: cancelKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: onCancel ?? () => Navigator.of(context).maybePop(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.tc.soft2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.2,
                          color: context.tc.ink,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.tc.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 72),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final blocked = blockedReason != null;
    final bg = blocked
        ? context.tc.faint
        : destructiveConfirm
        ? Colors.white
        : context.tc.primary;
    final bd = blocked
        ? context.tc.faint
        : destructiveConfirm
        ? context.tc.redLine
        : context.tc.primary;
    final fg = blocked
        ? context.tc.placeholder
        : destructiveConfirm
        ? context.tc.red
        : Colors.white;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.tc.surface,
        border: Border(top: BorderSide(color: context.tc.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (summary != null && summary!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                summary!,
                key: const ValueKey('editor-summary'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.tc.soft2,
                ),
              ),
            ),
          GestureDetector(
            key: confirmKey,
            behavior: HitTestBehavior.opaque,
            onTap: blocked ? null : onConfirm,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: bd, width: 1.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                blockedReason ?? confirmLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deleteButton() {
    return GestureDetector(
      key: deleteKey,
      behavior: HitTestBehavior.opaque,
      onTap: onDelete,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ThriveColors.current.surface,
          border: Border.all(color: ThriveColors.current.redLine, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          deleteLabel!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: ThriveColors.current.red,
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- sections

/// A labelled section: bold label, optional muted hint on the right.
class EdSection extends StatelessWidget {
  const EdSection({
    super.key,
    required this.label,
    this.hint,
    required this.child,
    this.gap = 8,
  });

  final String label;
  final String? hint;
  final Widget child;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: context.tc.text,
                ),
              ),
            ),
            if (hint != null)
              Text(
                hint!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.tc.muted,
                ),
              ),
          ],
        ),
        SizedBox(height: gap),
        child,
      ],
    );
  }
}

/// A tinted one-line notice (series info, weekend question, temporary).
Widget edNotice(String text, {Key? key, Color? bg, Color? fg, Color? border}) {
  return Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: (bg ?? ThriveColors.current.amberSoft),
      borderRadius: BorderRadius.circular(12),
      border: border == null ? null : Border.all(color: border),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: (fg ?? ThriveColors.current.amberText),
      ),
    ),
  );
}

// ------------------------------------------------------------ segmented

class EdSegmented<T> extends StatelessWidget {
  const EdSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.keyPrefix,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.tc.track,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final (v, label) in options)
            Expanded(
              child: GestureDetector(
                key: keyPrefix == null ? null : ValueKey('$keyPrefix-$v'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  constraints: const BoxConstraints(minHeight: 38),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? context.tc.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: v == value
                        ? const [
                            BoxShadow(
                              color: B.segShadow,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : const [],
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: v == value ? context.tc.ink : context.tc.segIdle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- chips

/// Solid chip: fills with [tone] (default primary) when selected.
Widget edChip({
  Key? key,
  required String label,
  required bool selected,
  required VoidCallback onTap,
  Color? tone,
  Widget? leading,
  bool small = false,
}) {
  final f = tone ?? ThriveColors.current.primary;
  return _edChipBase(
    key: key,
    label: label,
    onTap: onTap,
    bg: selected ? f : Colors.white,
    bd: selected ? f : ThriveColors.current.line,
    fg: selected ? contrastOn(f) : ThriveColors.current.soft2,
    leading: leading,
    small: small,
  );
}

/// Soft chip: mint fill and primary border when selected.
Widget edSoftChip({
  Key? key,
  required String label,
  required bool selected,
  required VoidCallback onTap,
  Widget? leading,
  bool small = false,
  bool expand = false,
}) {
  return _edChipBase(
    key: key,
    label: label,
    onTap: onTap,
    bg: selected ? ThriveColors.current.soft : Colors.white,
    bd: selected ? ThriveColors.current.primary : ThriveColors.current.line,
    fg: selected ? ThriveColors.current.deep : ThriveColors.current.text,
    leading: leading,
    small: small,
    expand: expand,
  );
}

Widget _edChipBase({
  Key? key,
  required String label,
  required VoidCallback onTap,
  required Color bg,
  required Color bd,
  required Color fg,
  Widget? leading,
  bool small = false,
  bool expand = false,
}) {
  return GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: BoxConstraints(minHeight: expand ? 44 : (small ? 36 : 40)),
      padding: EdgeInsets.fromLTRB(
        leading != null ? 11 : (small ? 12 : 14),
        6,
        small ? 12 : 14,
        6,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: bd, width: 1.5),
        borderRadius: BorderRadius.circular(expand ? 12 : 999),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: small ? 12 : 12.5,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Wrap of chips with the design's 7px gap.
Widget edChipWrap(List<Widget> chips, {double gap = 7}) =>
    Wrap(spacing: gap, runSpacing: gap, children: chips);

/// A big two-up choice tile (block money direction, list kind).
Widget edChoiceTile({
  Key? key,
  required Widget leading,
  required String label,
  String? sub,
  required bool selected,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? ThriveColors.current.soft
            : ThriveColors.current.surface,
        border: Border.all(
          color: selected
              ? ThriveColors.current.primary
              : ThriveColors.current.line,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? ThriveColors.current.deep
                        : ThriveColors.current.text,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: ThriveColors.current.muted,
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

// --------------------------------------------------------------- toggle

class EdSwitch extends StatelessWidget {
  const EdSwitch({super.key, required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 42,
      height: 25,
      padding: const EdgeInsets.all(2.5),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? context.tc.primary : context.tc.toggleOff,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: context.tc.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: B.segShadow, blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }
}

/// A label/sub row with a switch. [boxed] draws its own bordered card;
/// otherwise it's a row inside an [edGroup] ([divider] adds the top rule).
Widget edToggleRow({
  Key? key,
  required String label,
  String? sub,
  required bool value,
  required VoidCallback onTap,
  bool boxed = true,
  bool divider = false,
}) {
  return GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      constraints: BoxConstraints(minHeight: boxed ? 56 : 54),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: boxed
          ? BoxDecoration(
              color: ThriveColors.current.surface,
              border: Border.all(color: ThriveColors.current.line, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            )
          : BoxDecoration(
              border: divider
                  ? Border(top: BorderSide(color: ThriveColors.current.line))
                  : null,
            ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ThriveColors.current.ink,
                  ),
                ),
                if (sub != null && sub.isNotEmpty)
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ThriveColors.current.muted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          EdSwitch(on: value),
        ],
      ),
    ),
  );
}

// --------------------------------------------------------------- inputs

/// A bordered group of stacked rows/inputs separated by hairlines.
Widget edGroup(List<Widget> rows, {double radius = 14}) {
  return Container(
    decoration: BoxDecoration(
      color: ThriveColors.current.surface,
      border: Border.all(color: ThriveColors.current.line, width: 1.5),
      borderRadius: BorderRadius.circular(radius),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          i == 0
              ? rows[i]
              : DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: ThriveColors.current.line),
                    ),
                  ),
                  child: rows[i],
                ),
      ],
    ),
  );
}

TextStyle _edInputStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  color: ThriveColors.current.ink,
);

TextStyle _edHintStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: ThriveColors.current.placeholder,
);

/// Borderless input for use inside an [edGroup].
Widget edBareInput({
  Key? key,
  required TextEditingController controller,
  required String hint,
  ValueChanged<String>? onChanged,
  TextInputType? keyboardType,
  TextCapitalization capitalization = TextCapitalization.none,
  double letterSpacing = 0,
  int maxLines = 1,
  bool autofocus = false,
}) {
  return TextField(
    key: key,
    controller: controller,
    onChanged: onChanged,
    keyboardType: keyboardType,
    textCapitalization: capitalization,
    maxLines: maxLines,
    minLines: 1,
    autofocus: autofocus,
    decoration: InputDecoration(
      isDense: true,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.all(14),
      hintText: hint,
      hintStyle: _edHintStyle,
    ),
    style: _edInputStyle.copyWith(letterSpacing: letterSpacing),
  );
}

/// Standalone bordered input (member email, account short label).
Widget edBoxedInput({
  Key? key,
  required TextEditingController controller,
  required String hint,
  ValueChanged<String>? onChanged,
  TextInputType? keyboardType,
  int? maxLength,
  Widget? prefix,
}) {
  return Container(
    padding: EdgeInsets.only(left: prefix != null ? 14 : 0),
    decoration: BoxDecoration(
      color: ThriveColors.current.surface,
      border: Border.all(color: ThriveColors.current.line, width: 1.5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        if (prefix != null) ...[prefix, const SizedBox(width: 8)],
        Expanded(
          child: TextField(
            key: key,
            controller: controller,
            onChanged: onChanged,
            keyboardType: keyboardType,
            inputFormatters: maxLength == null
                ? null
                : [LengthLimitingTextInputFormatter(maxLength)],
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: prefix != null ? 0 : 14,
                vertical: 13,
              ),
              hintText: hint,
              hintStyle: _edHintStyle,
            ),
            style: _edInputStyle,
          ),
        ),
      ],
    ),
  );
}

/// The big centred amount (finance entry, monthly limit).
Widget edBigAmount({
  Key? key,
  required TextEditingController controller,
  required String prefix,
  required Color color,
  Color? prefixColor,
  String hint = '0,00',
  ValueChanged<String>? onChanged,
  String? caption,
  Color? captionColor,
}) {
  final style = TextStyle(
    fontSize: controller.text.length > 9 ? 30 : 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    color: color,
  );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              prefix,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: prefixColor ?? color,
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 190,
              child: TextField(
                key: key,
                controller: controller,
                onChanged: onChanged,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: style.copyWith(
                    color: ThriveColors.current.amountEmpty,
                  ),
                ),
                style: style,
              ),
            ),
          ],
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              caption,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: (captionColor ?? ThriveColors.current.muted),
              ),
            ),
          ),
      ],
    ),
  );
}

// --------------------------------------------------------------- people

/// "Who it's for" row: 44px avatars, dimmed when not selected, ringed with
/// a ✓ badge when selected, first name underneath.
Widget edPeopleRow({
  required List<FamilyMember> members,
  required Set<String> selected,
  required ValueChanged<String> onToggle,
  required Widget Function(FamilyMember m, double size) avatar,
  String keyPrefix = 'person',
}) {
  return Wrap(
    spacing: 14,
    runSpacing: 10,
    children: [
      for (final m in members)
        GestureDetector(
          key: ValueKey('$keyPrefix-${m.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onToggle(m.id),
          child: SizedBox(
            width: 52,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: selected.contains(m.id) ? 1 : .35,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: selected.contains(m.id)
                              ? [
                                  BoxShadow(color: m.color, spreadRadius: 4),
                                  const BoxShadow(
                                    color: Colors.white,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: avatar(m, 44),
                      ),
                    ),
                    if (selected.contains(m.id))
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ThriveColors.current.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: ic(
                            'check',
                            size: 9,
                            sw: 3.4,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  m.name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected.contains(m.id)
                        ? ThriveColors.current.ink
                        : ThriveColors.current.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

// ------------------------------------------------------------ badge head

/// The badge header shared by the category, layer, member, account and
/// block editors: an 80px rounded badge in the item's colour, the name
/// underlined in that colour, and a scrolling row of quick emoji picks
/// followed by "+" (type any emoji) and "Photo".
class EdBadgeHeader extends StatefulWidget {
  const EdBadgeHeader({
    super.key,
    required this.color,
    required this.name,
    required this.onName,
    required this.picks,
    required this.emoji,
    this.picture,
    required this.onEmoji,
    required this.onPickPhoto,
    this.fallbackFace = '🏷',
    this.initialsPick = false,
    this.namePlaceholder = 'Name it…',
    this.onToast,
  });

  final Color color;
  final String name;
  final ValueChanged<String> onName;
  final List<String> picks;
  final String? emoji;
  final String? picture;

  /// Called with the chosen emoji, or `null` for the "Aa" initials pick.
  final ValueChanged<String?> onEmoji;
  final VoidCallback onPickPhoto;

  /// Face shown without picture/emoji (initials for members).
  final String fallbackFace;

  /// Adds the leading "Aa" pick (members: show initials).
  final bool initialsPick;
  final String namePlaceholder;
  final ValueChanged<String>? onToast;

  @override
  State<EdBadgeHeader> createState() => _EdBadgeHeaderState();
}

class _EdBadgeHeaderState extends State<EdBadgeHeader> {
  late final TextEditingController _name = TextEditingController(
    text: widget.name,
  );
  final TextEditingController _emoji = TextEditingController();
  bool _emojiOpen = false;

  @override
  void didUpdateWidget(EdBadgeHeader old) {
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

  /// Any OS emoji works — flag/skin-tone/ZWJ sequences span many code
  /// units, so short inputs are kept whole and longer ones fall back to the
  /// first grapheme.
  void _applyEmoji() {
    final v = _emoji.text.trim();
    if (v.isEmpty) {
      widget.onToast?.call('Type an emoji first — any one your keyboard has');
      return;
    }
    widget.onEmoji(v.length <= 8 ? v : v.characters.first);
    setState(() {
      _emojiOpen = false;
      _emoji.clear();
    });
    widget.onToast?.call('Emoji set');
  }

  bool get _hasPicture => widget.picture != null && widget.picture!.isNotEmpty;

  Widget _face() {
    if (_hasPicture) {
      try {
        return Image.memory(
          base64Decode(widget.picture!),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      } catch (_) {
        // Broken payloads fall back to the glyph below.
      }
    }
    final e = widget.emoji;
    final face = (e != null && e.isNotEmpty) ? e : widget.fallbackFace;
    return Center(
      child: Text(
        face,
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: contrastOn(widget.color),
        ),
      ),
    );
  }

  Widget _pickTile(String label, bool on, VoidCallback onTap, {Key? key}) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? context.tc.soft : context.tc.surface,
          border: Border.all(
            color: on ? context.tc.primary : context.tc.line,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: context.tc.text,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final e = widget.emoji;
    final picks = [
      if (e != null && e.isNotEmpty && !widget.picks.contains(e)) e,
      ...widget.picks,
    ];
    final named = widget.name.trim().isNotEmpty;
    return Column(
      children: [
        const SizedBox(height: 4),
        GestureDetector(
          key: const ValueKey('badge-stage-badge'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPickPhoto,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 80,
            height: 80,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: c,
                  blurRadius: 24,
                  spreadRadius: -10,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _face(),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: named ? c : context.tc.line, width: 2),
            ),
          ),
          child: TextField(
            key: const ValueKey('badge-stage-name'),
            controller: _name,
            onChanged: widget.onName,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
              hintText: widget.namePlaceholder,
              hintStyle: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                letterSpacing: -.4,
                color: context.tc.placeholder,
              ),
            ),
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
              color: context.tc.ink,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            children: [
              if (widget.initialsPick) ...[
                _pickTile(
                  'Aa',
                  !_hasPicture && (e == null || e.isEmpty),
                  () => widget.onEmoji(null),
                  key: const ValueKey('badge-pick-initials'),
                ),
                const SizedBox(width: 6),
              ],
              for (final p in picks) ...[
                _pickTile(
                  p,
                  !_hasPicture && e == p,
                  () => widget.onEmoji(p),
                  key: ValueKey('badge-pick-$p'),
                ),
                const SizedBox(width: 6),
              ],
              _pickTile(
                '+',
                _emojiOpen,
                () => setState(() {
                  _emojiOpen = !_emojiOpen;
                  _emoji.clear();
                }),
                key: const ValueKey('badge-stage-emoji-link'),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                key: const ValueKey('badge-photo'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.onPickPhoto,
                child: CustomPaint(
                  painter: _EdDashedPainter(color: context.tc.dash, radius: 13),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        ic(
                          'camera',
                          size: 14,
                          sw: 2.2,
                          color: context.tc.soft2,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Photo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: context.tc.soft2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_emojiOpen)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.tc.surface,
                      border: Border.all(color: context.tc.primary, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      key: const ValueKey('badge-stage-emoji-input'),
                      controller: _emoji,
                      autofocus: true,
                      onSubmitted: (_) => _applyEmoji(),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 12,
                        ),
                        hintText: 'Type any emoji',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.tc.placeholder,
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
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.tc.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Use',
                      style: TextStyle(
                        fontSize: 13,
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
}

class _EdDashedPainter extends CustomPainter {
  _EdDashedPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(.75),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_EdDashedPainter old) =>
      old.color != color || old.radius != radius;
}

/// One editor colour section: "Colour" + the app's single colour selector
/// (Palette / RGB-Hex tabs, [_ColorPickerPanel]), folded behind its title.
Widget edColourSection(
  Color selected,
  ValueChanged<Color> onChanged, {
  String label = 'Colour',
}) {
  return EdColourFold(label: label, selected: selected, onChanged: onChanged);
}

/// A colour section whose Palette / RGB-Hex selector stays folded away until
/// its title is tapped. The title row shows the current colour as a swatch.
class EdColourFold extends StatefulWidget {
  const EdColourFold({
    super.key,
    this.label = 'Colour',
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  State<EdColourFold> createState() => _EdColourFoldState();
}

class _EdColourFoldState extends State<EdColourFold> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          key: const ValueKey('colour-toggle'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: context.tc.text,
                    ),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: widget.selected,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.tc.line),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _open ? .5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: ic(
                    'cdown',
                    size: 18,
                    sw: 2.4,
                    color: context.tc.placeholder,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 6),
          _ColorPickerPanel(
            selected: widget.selected,
            onChanged: widget.onChanged,
          ),
        ],
      ],
    );
  }
}

/// Quick emoji picks per badge editor (`PICKS` in the design).
const Map<String, List<String>> kEditorPicks = {
  'category': ['🏷', '💼', '📚', '⚽', '❤️', '👨‍👩‍👧', '🎉', '✈️', '🦷', '🎵'],
  'layer': ['📅', '✅', '📸', '⭐', '🎯', '🧹', '🎓', '🏃'],
  'member': ['🦊', '🐻', '🦄', '⚽', '🎨', '🌸', '🚀', '🐱'],
  'account': ['🏦', '💳', '👛', '💶', '🐷', '🏠', '💼'],
  'block': ['📦', '🛒', '🏠', '🧸', '🚗', '📺', '💡', '🐷', '🎁', '🍽'],
};
