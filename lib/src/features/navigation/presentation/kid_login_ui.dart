part of 'package:family_money_management_app/main.dart';

/// Shared pieces of the kid-accounts design (`Kid Accounts.dc.html`):
/// notices, key/value rows, action rows, consequence lists, the locked /
/// busy toggle, the password field with strength meter, and the sheet that
/// becomes a centred dialog on wide (web) layouts.

const double _kKidWideBreakpoint = 720;

bool _kidWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= _kKidWideBreakpoint;

/// A bottom sheet on phones, a centred dialog on wide screens.
Future<T?> showKidSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext ctx, StateSetter setSheet) builder,
  bool dismissible = true,
}) {
  Widget body(BuildContext ctx) =>
      StatefulBuilder(builder: (c, set) => builder(c, set));
  if (_kidWide(context)) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: const Color(0x73101828),
      builder: (ctx) => Dialog(
        backgroundColor: context.tc.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: SingleChildScrollView(child: body(ctx)),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x73101828),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          20 + MediaQuery.of(ctx).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: context.tc.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SingleChildScrollView(
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
                    color: context.tc.pick(
                      const Color(0xffe2e8f0),
                      context.tc.line,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              body(ctx),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget kidSheetTitle(String title, [String? body]) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: -.3,
        color: ThriveColors.current.ink,
      ),
    ),
    if (body != null)
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 3, 0, 12),
        child: Text(
          body,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: ThriveColors.current.muted,
            height: 1.35,
          ),
        ),
      )
    else
      const SizedBox(height: 12),
  ],
);

enum KidTone { teal, amber, red, grey }

({Color bg, Color line, Color fg}) _kidToneColors(KidTone t) => switch (t) {
  KidTone.teal => (
    bg: ThriveColors.current.soft,
    line: const Color(0xffc4e8e2),
    fg: ThriveColors.current.deep,
  ),
  KidTone.amber => (
    bg: ThriveColors.current.amberSoft,
    line: ThriveColors.current.amberLine,
    fg: ThriveColors.current.amberText,
  ),
  KidTone.red => (
    bg: ThriveColors.current.redSoft,
    line: ThriveColors.current.redLine,
    fg: ThriveColors.current.red,
  ),
  KidTone.grey => (
    bg: ThriveColors.current.faint,
    line: ThriveColors.current.line,
    fg: ThriveColors.current.soft2,
  ),
};

/// An inline notice box (teal info, amber offline, red error).
Widget kidNotice(
  String text, {
  Key? key,
  KidTone tone = KidTone.teal,
  String? title,
  String icon = 'shield',
  EdgeInsets margin = const EdgeInsets.only(top: 4, bottom: 8),
}) {
  final c = _kidToneColors(tone);
  return Container(
    key: key,
    margin: margin,
    padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
    decoration: BoxDecoration(
      color: c.bg,
      border: Border.all(color: c.line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: ic(icon, size: 14, sw: 2.2, color: c.fg),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: c.fg,
                  ),
                ),
              Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.fg,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A small status pill (Admin / Managed / Pending).
Widget kidPill(String label, {KidTone tone = KidTone.grey, Key? key}) {
  final c = _kidToneColors(tone);
  return Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.bg,
      border: Border.all(color: c.line),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label == 'Pending') ...[
          ic('clock', size: 10, sw: 2.4, color: c.fg),
          const SizedBox(width: 3),
        ],
        if (label == 'Admin') ...[
          ic('shield', size: 10, sw: 2.4, color: c.fg),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: c.fg,
          ),
        ),
      ],
    ),
  );
}

/// Key/value row (Method, Email, Last sign-in, Status).
Widget studioInfoRow(
  String label, {
  String? value,
  Widget? trailing,
  Key? key,
}) {
  return Padding(
    key: key,
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: ThriveColors.current.muted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child:
                trailing ??
                Text(
                  value ?? '',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ThriveColors.current.ink,
                  ),
                ),
          ),
        ),
      ],
    ),
  );
}

/// A tappable action inside the login card (Reset password, Remove login…).
Widget kidActionRow({
  required Key key,
  required String label,
  String? sub,
  required String icon,
  required VoidCallback? onTap,
  bool danger = false,
}) {
  final fg = onTap == null
      ? ThriveColors.current.muted
      : (danger ? ThriveColors.current.red : ThriveColors.current.ink);
  return GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ThriveColors.current.track)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: danger
                  ? ThriveColors.current.redSoft
                  : ThriveColors.current.faint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: ic(
                icon,
                size: 13,
                sw: 2.2,
                color: danger
                    ? ThriveColors.current.red
                    : ThriveColors.current.text,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: ThriveColors.current.muted,
                    ),
                  ),
              ],
            ),
          ),
          ic('cright', size: 13, sw: 2.2, color: ThriveColors.current.muted),
        ],
      ),
    ),
  );
}

enum ConsequenceKind { lose, keep, gets }

/// Lose (red ×), keep (green ✓) or gets (teal ✓) list on access sheets.
Widget kidConsequenceList(
  String head,
  List<String> items, {
  ConsequenceKind kind = ConsequenceKind.keep,
}) {
  final (fg, glyph) = switch (kind) {
    ConsequenceKind.lose => (ThriveColors.current.red, 'x'),
    ConsequenceKind.keep => (ThriveColors.current.green, 'check'),
    ConsequenceKind.gets => (ThriveColors.current.primary, 'check'),
  };
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        studioSectionLabel(head),
        for (final it in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              children: [
                ic(glyph, size: 13, sw: 2.6, color: fg),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    it,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ThriveColors.current.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// The primary (or danger) full-width button with a busy label.
Widget kidButton({
  required Key key,
  required String label,
  required VoidCallback? onTap,
  bool busy = false,
  String? busyLabel,
  bool danger = false,
  bool secondary = false,
}) {
  final enabled = onTap != null && !busy;
  final bg = secondary
      ? Colors.white
      : (!enabled && !busy
            ? ThriveColors.current.pick(
                const Color(0xffe2e8f0),
                ThriveColors.current.line,
              )
            : (danger
                  ? ThriveColors.current.red
                  : ThriveColors.current.primary));
  final fg = secondary
      ? ThriveColors.current.text
      : (!enabled && !busy ? ThriveColors.current.muted : Colors.white);
  return GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: enabled ? onTap : null,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: secondary ? Border.all(color: ThriveColors.current.line) : null,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            busy ? (busyLabel ?? label) : label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget kidCancelLink(BuildContext ctx, {String label = 'Cancel', Key? key}) =>
    GestureDetector(
      key: key ?? const ValueKey('kid-sheet-cancel'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(ctx).pop(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 2),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: ThriveColors.current.soft2,
          ),
        ),
      ),
    );

/// The Kid toggle: a plain toggle row, or locked with a one-line reason, or
/// a spinner + status while the change saves.
Widget kidToggleRow({
  required Key key,
  required String label,
  required String sub,
  required bool value,
  required VoidCallback onChanged,
  String? disabledReason,
  String? busyText,
}) {
  if (disabledReason == null && busyText == null) {
    return studioToggleRow(
      key: key,
      label: label,
      sub: sub,
      value: value,
      onChanged: onChanged,
    );
  }
  return Container(
    key: key,
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: ThriveColors.current.pick(
        const Color(0xfff8fafc),
        ThriveColors.current.rowOpen,
      ),
      border: Border.all(color: ThriveColors.current.track),
      borderRadius: BorderRadius.circular(12),
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
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: disabledReason != null
                      ? ThriveColors.current.muted
                      : ThriveColors.current.ink,
                ),
              ),
              Row(
                children: [
                  if (disabledReason != null) ...[
                    ic(
                      'lock',
                      size: 10,
                      sw: 2.4,
                      color: ThriveColors.current.muted,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      disabledReason ?? busyText!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: ThriveColors.current.pick(
                          const Color(0xff8a96a8),
                          ThriveColors.current.placeholder,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        if (busyText != null)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ThriveColors.current.primary,
            ),
          )
        else
          Opacity(
            opacity: .45,
            child: Container(
              width: 42,
              height: 25,
              padding: const EdgeInsets.all(3),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value
                    ? ThriveColors.current.primary
                    : ThriveColors.current.pick(
                        const Color(0xffcbd5e1),
                        ThriveColors.current.toggleOff,
                      ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  color: ThriveColors.current.surface,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// A labelled field with an optional helper / error line.
Widget kidField({
  required String label,
  required Widget field,
  String? helper,
  String? error,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        studioSectionLabel(label),
        field,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              error,
              key: const ValueKey('kid-field-error'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ThriveColors.current.red,
              ),
            ),
          )
        else if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              helper,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: ThriveColors.current.muted,
              ),
            ),
          ),
      ],
    ),
  );
}

/// Masked password input with show/hide, a Generate chip and the strength
/// meter underneath.
class KidPasswordField extends StatefulWidget {
  const KidPasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.error,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final String? error;
  final VoidCallback? onChanged;

  @override
  State<KidPasswordField> createState() => _KidPasswordFieldState();
}

class _KidPasswordFieldState extends State<KidPasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final pw = widget.controller.text;
    final st = passwordStrength(pw);
    final filled = switch (st) {
      PasswordStrength.weak => 1,
      PasswordStrength.okay => 2,
      PasswordStrength.good => 3,
      PasswordStrength.strong => 4,
    };
    final tone = switch (st) {
      PasswordStrength.weak => context.tc.red,
      PasswordStrength.okay => context.tc.amber,
      _ => context.tc.green,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        studioSectionLabel(widget.label),
        Container(
          decoration: BoxDecoration(
            color: context.tc.page,
            border: Border.all(
              color: widget.error != null ? context.tc.red : context.tc.line,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('kid-password'),
                  controller: widget.controller,
                  obscureText: !_show,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) {
                    setState(() {});
                    widget.onChanged?.call();
                  },
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: context.tc.ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 12,
                    ),
                    hintText: 'At least 10 characters',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.tc.muted,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                key: const ValueKey('kid-password-show'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _show = !_show),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ic(
                    _show ? 'eyeoff' : 'eye',
                    size: 16,
                    sw: 2.2,
                    color: context.tc.soft2,
                  ),
                ),
              ),
              GestureDetector(
                key: const ValueKey('kid-password-generate'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.controller.text = generateKidPassword();
                  setState(() => _show = true);
                  widget.onChanged?.call();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.tc.soft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Generate',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: context.tc.deep,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (pw.isNotEmpty || widget.error != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i < filled ? tone : context.tc.track,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.error ??
                '${passwordStrengthLabel(st)} · ${passwordStrengthHint(st)}',
            key: const ValueKey('kid-password-strength'),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: widget.error != null ? context.tc.red : tone,
            ),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}

/// Short date like "12 Oct".
String kidShortDate(int? millis) {
  if (millis == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${d.day} ${months[d.month - 1]}';
}

/// "Today, 14:05" / "12 Oct" / "Never" for the last sign-in row.
String kidLastSignIn(int? millis) {
  if (millis == null) return 'Never';
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return 'Today, $hh:$mm';
  }
  return kidShortDate(millis);
}
