part of 'package:family_money_management_app/main.dart';

/// Renders the visual chosen for an account or budget block (issue #131): an
/// uploaded [picture] (base64) wins, then an [emoji], otherwise [fallback]
/// (a legacy stroke icon or a colored initials tile). The result fills a
/// [size]×[size] box clipped to [radius] (pass `size / 2` for a circle).
Widget glyphTile({
  required double size,
  required double radius,
  String? picture,
  String? emoji,
  double? emojiSize,
  required Widget fallback,
}) {
  if (picture != null && picture.isNotEmpty) {
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          base64Decode(picture),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    } catch (_) {
      /* fall through to emoji / fallback */
    }
  }
  if (emoji != null && emoji.isNotEmpty) {
    return Center(
      child: Text(emoji, style: TextStyle(fontSize: emojiSize ?? size * 0.56)),
    );
  }
  return fallback;
}

class _ColorSwatchTile extends StatelessWidget {
  const _ColorSwatchTile({
    required this.color,
    required this.selected,
    required this.onTap,
    this.size = 38,
    this.fillWidth = false,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double size;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: fillWidth ? double.infinity : size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(9),
          border: selected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: selected
              ? [BoxShadow(color: color, blurRadius: 0, spreadRadius: 2)]
              : null,
        ),
        child: selected
            ? Center(child: ic('check', size: 16, sw: 3, color: Colors.white))
            : null,
      ),
    );
  }
}

class _GradientColorPicker extends StatelessWidget {
  const _GradientColorPicker({required this.selected, required this.onChanged});

  static const int _cols = 9;

  final Color selected;
  final ValueChanged<Color> onChanged;

  /// A clean, aligned grid mirroring the reference design: a grayscale row
  /// (white → black) on top, followed by hue rows that fade from soft/pastel
  /// to deep/saturated — no staggered columns, so swatches line up neatly.
  List<List<Color>> _rows() {
    final grayscale = List.generate(_cols, (col) {
      final t = col / (_cols - 1);
      return Color.lerp(const Color(0xffffffff), const Color(0xff000000), t)!;
    });
    final hueRows = List.generate(5, (row) {
      final lightness = 0.82 - row * 0.15;
      final saturation = 0.55 + row * 0.09;
      return List.generate(_cols, (col) {
        final hue = (360 / _cols) * col;
        return HSLColor.fromAHSL(
          1,
          hue,
          saturation.clamp(0.45, 0.95),
          lightness.clamp(0.22, 0.86),
        ).toColor();
      });
    });
    return [grayscale, ...hueRows];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          Row(
            children: [
              for (final color in rows[i]) ...[
                Expanded(
                  child: _ColorSwatchTile(
                    color: color,
                    selected: selected.toARGB32() == color.toARGB32(),
                    onTap: () => onChanged(color),
                    size: 32,
                    fillWidth: true,
                  ),
                ),
                if (color != rows[i].last) const SizedBox(width: 6),
              ],
            ],
          ),
          if (i != rows.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _BudgetColorPicker extends StatelessWidget {
  const _BudgetColorPicker({
    required this.quickColors,
    required this.selected,
    required this.onChanged,
  });

  final List<Color> quickColors;
  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return _MoreColorsToggle(
      quickColors: quickColors,
      selected: selected,
      onChanged: onChanged,
    );
  }
}

/// A reveal button that expands into the two-tab colour picker described in
/// issue #189 (a structured colour grid + an RGB/hex slider panel), used to
/// offer colours beyond a feature's curated quick palette (e.g. for calendar
/// events, categories, and family members, in addition to budget
/// accounts/blocks). Starts expanded if [selected] isn't one of
/// [quickColors].
class _MoreColorsToggle extends StatefulWidget {
  const _MoreColorsToggle({
    required this.quickColors,
    required this.selected,
    required this.onChanged,
  });

  final List<Color> quickColors;
  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  State<_MoreColorsToggle> createState() => _MoreColorsToggleState();
}

class _MoreColorsToggleState extends State<_MoreColorsToggle> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.quickColors.any(
      (c) => c.toARGB32() == widget.selected.toARGB32(),
    );
  }

  @override
  void didUpdateWidget(covariant _MoreColorsToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.quickColors.any(
      (c) => c.toARGB32() == widget.selected.toARGB32(),
    )) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: B.faint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: B.line),
            ),
            child: Row(
              children: [
                ic('sliders', size: 15, sw: 2.2, color: B.deep),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Colors',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: B.deep,
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: _expanded ? math.pi : 0,
                  child: ic('down', size: 14, sw: 2.2, color: B.soft2),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          _ColorPickerPanel(
            selected: widget.selected,
            onChanged: widget.onChanged,
          ),
        ],
      ],
    );
  }
}

/// Two-tab colour picker (issue #189): a structured palette grid and an
/// RGB/hex slider panel, mirroring the design's "more colors" popover minus
/// its free-form gradient spectrum pad. Used by [_MoreColorsToggle] so it's
/// shared uniformly across Calendar and Finance colour pickers.
class _ColorPickerPanel extends StatefulWidget {
  const _ColorPickerPanel({required this.selected, required this.onChanged});

  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  State<_ColorPickerPanel> createState() => _ColorPickerPanelState();
}

class _ColorPickerPanelState extends State<_ColorPickerPanel> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: B.faint,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ColorPickerTabBtn(
                  label: 'Palette',
                  icon: 'grid',
                  active: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _ColorPickerTabBtn(
                  label: 'RGB / Hex',
                  icon: 'sliders',
                  active: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: B.line),
          ),
          child: _tab == 0
              ? _GradientColorPicker(
                  selected: widget.selected,
                  onChanged: widget.onChanged,
                )
              : _RgbHexColorPicker(
                  selected: widget.selected,
                  onChanged: widget.onChanged,
                ),
        ),
      ],
    );
  }
}

class _ColorPickerTabBtn extends StatelessWidget {
  const _ColorPickerTabBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ic(icon, size: 13, sw: 2.2, color: active ? B.deep : B.soft2),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? B.deep : B.soft2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A slim horizontal slider with a filled track (used for the RGB channel
/// bars and the opacity/brightness bar in the design reference).
class _ChannelSlider extends StatelessWidget {
  const _ChannelSlider({
    super.key,
    required this.value,
    required this.max,
    required this.trackGradient,
    required this.onChanged,
  });

  final double value;
  final double max;
  final Gradient trackGradient;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fraction = (value / max).clamp(0.0, 1.0);
        void handle(Offset local) {
          final v = (local.dx / width).clamp(0.0, 1.0) * max;
          onChanged(v);
        }

        return GestureDetector(
          onPanDown: (d) => handle(d.localPosition),
          onPanUpdate: (d) => handle(d.localPosition),
          onTapDown: (d) => handle(d.localPosition),
          child: SizedBox(
            height: 24,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: trackGradient,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Positioned(
                  left: (fraction * (width - 20)).clamp(0.0, width - 20),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: B.line, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .18),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// RGB channel sliders + hex input + opacity bar, mirroring the right-most
/// panel in the issue #189 reference image. Alpha is intentionally kept at
/// full opacity for callers whose colour model has no alpha channel, but the
/// slider still lets a user preview intermediate values before committing.
class _RgbHexColorPicker extends StatefulWidget {
  const _RgbHexColorPicker({required this.selected, required this.onChanged});

  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  State<_RgbHexColorPicker> createState() => _RgbHexColorPickerState();
}

class _RgbHexColorPickerState extends State<_RgbHexColorPicker> {
  late int _r;
  late int _g;
  late int _b;
  late double _opacity;
  late TextEditingController _hex;
  late TextEditingController _rCtrl;
  late TextEditingController _gCtrl;
  late TextEditingController _bCtrl;

  @override
  void initState() {
    super.initState();
    _syncFromColor(widget.selected);
    _hex = TextEditingController(text: _hexOf(_r, _g, _b));
    _rCtrl = TextEditingController(text: '$_r');
    _gCtrl = TextEditingController(text: '$_g');
    _bCtrl = TextEditingController(text: '$_b');
  }

  @override
  void didUpdateWidget(covariant _RgbHexColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected.toARGB32() != widget.selected.toARGB32()) {
      _syncFromColor(widget.selected);
      _hex.text = _hexOf(_r, _g, _b);
      _rCtrl.text = '$_r';
      _gCtrl.text = '$_g';
      _bCtrl.text = '$_b';
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    _rCtrl.dispose();
    _gCtrl.dispose();
    _bCtrl.dispose();
    super.dispose();
  }

  void _syncFromColor(Color c) {
    _r = (c.r * 255).round();
    _g = (c.g * 255).round();
    _b = (c.b * 255).round();
    _opacity = c.a;
  }

  String _hexOf(int r, int g, int b) =>
      '${r.toRadixString(16).padLeft(2, '0')}'
              '${g.toRadixString(16).padLeft(2, '0')}'
              '${b.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

  void _emit() {
    widget.onChanged(Color.fromRGBO(_r, _g, _b, _opacity == 0 ? 1 : _opacity));
  }

  /// Updates a channel from the slider drag or from typing a number directly
  /// into its field. [fromField] skips rewriting that field's text so the
  /// caret position/typed text isn't clobbered mid-edit.
  void _setChannel({int? r, int? g, int? b, bool fromField = false}) {
    setState(() {
      _r = r ?? _r;
      _g = g ?? _g;
      _b = b ?? _b;
      _hex.text = _hexOf(_r, _g, _b);
      if (!fromField || r == null) _rCtrl.text = '$_r';
      if (!fromField || g == null) _gCtrl.text = '$_g';
      if (!fromField || b == null) _bCtrl.text = '$_b';
    });
    _emit();
  }

  void _setOpacity(double v) {
    setState(() => _opacity = v);
    _emit();
  }

  void _applyHex(String value) {
    final cleaned = value.replaceAll('#', '').trim();
    if (cleaned.length != 6) return;
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return;
    setState(() {
      _r = (parsed >> 16) & 0xff;
      _g = (parsed >> 8) & 0xff;
      _b = parsed & 0xff;
      _rCtrl.text = '$_r';
      _gCtrl.text = '$_g';
      _bCtrl.text = '$_b';
    });
    _emit();
  }

  /// Applies a value typed directly into an RGB field's OS keyboard input,
  /// clamping to the valid 0-255 channel range.
  void _applyChannelText(String channel, String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    final clamped = parsed.clamp(0, 255);
    switch (channel) {
      case 'r':
        _setChannel(r: clamped, fromField: true);
        break;
      case 'g':
        _setChannel(g: clamped, fromField: true);
        break;
      case 'b':
        _setChannel(b: clamped, fromField: true);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = Color.fromRGBO(_r, _g, _b, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rgbRow(
          'RED',
          _r,
          _rCtrl,
          LinearGradient(
            colors: [
              Color.fromRGBO(0, _g, _b, 1),
              Color.fromRGBO(255, _g, _b, 1),
            ],
          ),
          (v) => _setChannel(r: v.round()),
          (v) => _applyChannelText('r', v),
        ),
        const SizedBox(height: 10),
        _rgbRow(
          'GREEN',
          _g,
          _gCtrl,
          LinearGradient(
            colors: [
              Color.fromRGBO(_r, 0, _b, 1),
              Color.fromRGBO(_r, 255, _b, 1),
            ],
          ),
          (v) => _setChannel(g: v.round()),
          (v) => _applyChannelText('g', v),
        ),
        const SizedBox(height: 10),
        _rgbRow(
          'BLUE',
          _b,
          _bCtrl,
          LinearGradient(
            colors: [
              Color.fromRGBO(_r, _g, 0, 1),
              Color.fromRGBO(_r, _g, 255, 1),
            ],
          ),
          (v) => _setChannel(b: v.round()),
          (v) => _applyChannelText('b', v),
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Text(
              'HEX COLOR #',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: B.primary,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 96,
              child: TextField(
                key: const ValueKey('hex-color-input'),
                controller: _hex,
                textAlign: TextAlign.right,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                ],
                onSubmitted: _applyHex,
                onChanged: (v) {
                  if (v.length == 6) _applyHex(v);
                },
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: B.ink,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: B.line),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Text(
              'OPACITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: B.muted,
              ),
            ),
            const Spacer(),
            Text(
              '${(_opacity * 100).round()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: B.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _ChannelSlider(
          value: _opacity,
          max: 1,
          trackGradient: LinearGradient(
            colors: [current.withValues(alpha: 0), current],
          ),
          onChanged: _setOpacity,
        ),
      ],
    );
  }

  Widget _rgbRow(
    String label,
    int value,
    TextEditingController controller,
    Gradient trackGradient,
    ValueChanged<double> onChanged,
    ValueChanged<String> onTextChanged, {
    Key? key,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
              color: B.muted,
            ),
          ),
        ),
        Expanded(
          child: _ChannelSlider(
            key: key,
            value: value.toDouble(),
            max: 255,
            trackGradient: trackGradient,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          height: 30,
          child: TextField(
            key: ValueKey('${label.toLowerCase()}-channel-input'),
            controller: controller,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            maxLength: 3,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: B.ink,
            ),
            decoration: const InputDecoration(
              counterText: '',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              border: OutlineInputBorder(),
            ),
            onChanged: onTextChanged,
            onSubmitted: onTextChanged,
          ),
        ),
      ],
    );
  }
}

/// A row that reveals a red "Delete" action when swiped right-to-left,
/// mirroring the design's `swipeWrap`. Tapping the action triggers [onDelete].
class _SwipeRow extends StatefulWidget {
  const _SwipeRow({
    required Key key,
    required this.child,
    required this.onDelete,
    required this.open,
    required this.onOpenChanged,
    this.topBorder = false,
    this.borderRadius = 0,
  }) : super(key: key);

  final Widget child;
  final VoidCallback onDelete;
  final bool open;
  final ValueChanged<bool> onOpenChanged;
  final bool topBorder;

  /// Matches [child]'s own corner radius so the sliding red "Delete" panel
  /// stays clipped to the same rounded shape — otherwise it either peeks
  /// out from behind the child's rounded corners at rest, or shows sharp
  /// corners of its own once revealed.
  final double borderRadius;

  @override
  State<_SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<_SwipeRow>
    with SingleTickerProviderStateMixin {
  static const double _actionWidth = 84;
  double _dx = 0;

  @override
  void didUpdateWidget(covariant _SwipeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open && !widget.open) {
      setState(() => _dx = 0);
    } else if (widget.open && _dx == 0) {
      setState(() => _dx = -_actionWidth);
    }
  }

  void _onMove(double delta) {
    setState(() {
      _dx = (_dx + delta).clamp(-_actionWidth, 0.0);
    });
  }

  void _onEnd(DragEndDetails d) {
    final open = _dx < -_actionWidth / 2;
    setState(() => _dx = open ? -_actionWidth : 0);
    widget.onOpenChanged(open);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.topBorder
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: B.faint)),
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: _actionWidth,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  color: B.red,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ic('trash', size: 16, sw: 2.2, color: Colors.white),
                      const SizedBox(height: 3),
                      const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GestureDetector(
              onHorizontalDragUpdate: (d) => _onMove(d.primaryDelta ?? 0),
              onHorizontalDragEnd: _onEnd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1),
                transform: Matrix4.translationValues(_dx, 0, 0),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Donut chart painter for the monthly "Spending by category" card.
class _DonutPainter extends CustomPainter {
  _DonutPainter(this.cats, this.total);
  final List<_BlockCompute> cats;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 140;
    final center = Offset(70 * scale, 70 * scale);
    final radius = 46 * scale;
    final strokeWidth = 16 * scale;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = B.track;
    canvas.drawCircle(center, radius, track);

    double start = -math.pi / 2;
    for (final b in cats) {
      final frac = b.total / total;
      final sweep = frac * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = b.tone;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.cats != cats || old.total != total;
}

/// Income vs Expenses paired-bar chart for the yearly stats.
class _BarsPainter extends CustomPainter {
  _BarsPainter(this.months, this.monthIdx);
  final List<_Compute> months;
  final int monthIdx;

  @override
  void paint(Canvas canvas, Size size) {
    const vbW = 320.0, vbH = 150.0;
    final sx = size.width / vbW;
    final sy = size.height / vbH;
    const pad = 22.0;
    const bw = 8.0;
    final gap = (vbW - pad * 2) / 12;
    double maxV = 1;
    for (final m in months) {
      maxV = math.max(maxV, math.max(m.expIncome, m.totalBudget));
    }

    final axis = Paint()
      ..color = B.line
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(pad * sx, (vbH - 22) * sy),
      Offset((vbW - pad) * sx, (vbH - 22) * sy),
      axis,
    );

    TextStyle textStyleBase(Color color) =>
        TextStyle(fontSize: 8 * sx, fontWeight: FontWeight.w700, color: color);

    for (int i = 0; i < months.length; i++) {
      final m = months[i];
      final x = pad + gap * i + gap / 2;
      final ih = (m.expIncome / maxV) * (vbH - 30);
      final eh = (m.totalBudget / maxV) * (vbH - 30);
      final active = i == monthIdx;

      final incomePaint = Paint()
        ..color = B.green.withValues(alpha: active ? 1 : .85);
      _roundRect(
        canvas,
        (x - bw - 1) * sx,
        (vbH - 22 - ih) * sy,
        bw * sx,
        ih * sy,
        2 * sx,
        incomePaint,
      );

      final expPaint = Paint()
        ..color = const Color(0xffe2526a).withValues(alpha: active ? 1 : .8);
      _roundRect(
        canvas,
        (x + 1) * sx,
        (vbH - 22 - eh) * sy,
        bw * sx,
        eh * sy,
        2 * sx,
        expPaint,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: kMonthsShort[i][0],
          style: textStyleBase(active ? B.ink : B.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x * sx - tp.width / 2, (vbH - 12) * sy));
    }
  }

  void _roundRect(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    double r,
    Paint paint,
  ) {
    if (h <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.monthIdx != monthIdx || old.months != months;
}

/// Savings-rate area + line chart for the yearly stats.
class _SavingsPainter extends CustomPainter {
  _SavingsPainter(this.rates, this.monthIdx);
  final List<double> rates;
  final int monthIdx;

  @override
  void paint(Canvas canvas, Size size) {
    const vbW = 320.0, vbH = 120.0;
    final sx = size.width / vbW;
    final sy = size.height / vbH;
    const pad = 14.0;
    final stepX = (vbW - pad * 2) / 11;
    final zeroY = vbH / 2;
    double rMax = 0.4;
    for (final r in rates) {
      rMax = math.max(rMax, r.abs());
    }

    final pts = <Offset>[];
    for (int i = 0; i < rates.length; i++) {
      final x = pad + stepX * i;
      final y = zeroY - (rates[i] / rMax) * (vbH / 2 - 14);
      pts.add(Offset(x * sx, y * sy));
    }

    // zero line
    final dash = Paint()
      ..color = B.line
      ..strokeWidth = 1;
    _dashedLine(
      canvas,
      Offset(pad * sx, zeroY * sy),
      Offset((vbW - pad) * sx, zeroY * sy),
      dash,
    );

    // area
    final area = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      area.lineTo(p.dx, p.dy);
    }
    area.lineTo(pts.last.dx, zeroY * sy);
    area.lineTo(pts.first.dx, zeroY * sy);
    area.close();
    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          B.primary.withValues(alpha: .28),
          B.primary.withValues(alpha: .02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(area, areaPaint);

    // line
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * sx
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = B.primary,
    );

    // points + labels
    for (int i = 0; i < pts.length; i++) {
      final active = i == monthIdx;
      canvas.drawCircle(
        pts[i],
        (active ? 3.5 : 2) * sx,
        Paint()..color = active ? B.deep : B.primary,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: kMonthsShort[i][0],
          style: TextStyle(
            fontSize: 8 * sx,
            fontWeight: FontWeight.w700,
            color: B.muted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pts[i].dx - tp.width / 2, (vbH - 10) * sy));
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashW = 3.0, gap = 3.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    double dist = 0;
    while (dist < total) {
      final start = a + dir * dist;
      final end = a + dir * math.min(dist + dashW, total);
      canvas.drawLine(start, end, paint);
      dist += dashW + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _SavingsPainter old) =>
      old.monthIdx != monthIdx || old.rates != rates;
}
