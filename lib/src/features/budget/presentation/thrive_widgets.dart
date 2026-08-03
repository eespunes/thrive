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
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(11),
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

  final Color selected;
  final ValueChanged<Color> onChanged;

  List<List<Color>> _rows() => List.generate(5, (row) {
    final lightness = 0.38 + row * 0.09;
    final saturation = 0.9 - row * 0.07;
    return List.generate(8, (col) {
      final hue = ((360 / 8) * col + (row.isOdd ? 22.5 : 0)) % 360;
      return HSLColor.fromAHSL(
        1,
        hue,
        saturation.clamp(0.55, 0.92),
        lightness.clamp(0.34, 0.78),
      ).toColor();
    });
  });

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          Padding(
            padding: EdgeInsets.only(left: i.isOdd ? 22 : 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in rows[i])
                  _ColorSwatchTile(
                    color: color,
                    selected: selected.toARGB32() == color.toARGB32(),
                    onTap: () => onChanged(color),
                    size: 40,
                  ),
              ],
            ),
          ),
          if (i != rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _BudgetColorPicker extends StatefulWidget {
  const _BudgetColorPicker({
    required this.quickColors,
    required this.selected,
    required this.onChanged,
  });

  final List<Color> quickColors;
  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  State<_BudgetColorPicker> createState() => _BudgetColorPickerState();
}

class _BudgetColorPickerState extends State<_BudgetColorPicker> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.quickColors.any(
      (c) => c.toARGB32() == widget.selected.toARGB32(),
    );
  }

  @override
  void didUpdateWidget(covariant _BudgetColorPicker oldWidget) {
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
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final col in widget.quickColors)
              _ColorSwatchTile(
                color: col,
                selected: widget.selected.toARGB32() == col.toARGB32(),
                onTap: () => widget.onChanged(col),
              ),
          ],
        ),
        const SizedBox(height: 11),
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
                    'More colors',
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
          _GradientColorPicker(
            selected: widget.selected,
            onChanged: widget.onChanged,
          ),
        ],
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
