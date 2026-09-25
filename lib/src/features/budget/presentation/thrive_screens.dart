part of 'package:family_money_management_app/main.dart';

class _FinanceListRow {
  const _FinanceListRow({
    required this.id,
    required this.day,
    required this.label,
    required this.subtitle,
    required this.amount,
    required this.done,
    required this.isIncome,
    required this.isSavings,
    required this.color,
    required this.icon,
    required this.catKey,
    this.emoji,
    this.picture,
  });

  final String id;
  final int? day;
  final String label;
  final String subtitle;
  final double amount;
  final bool done;
  final bool isIncome;
  final bool isSavings;
  final Color color;
  final String icon;
  final String catKey;
  final String? emoji;
  final String? picture;
}

extension _ThriveScreens on _ThriveHomeState {
  Widget _buildOverview() {
    final c = compute(monthIdx);
    final envelopes = c.expenseBlocks.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.closed) _closedBanner(),
        if (envelopes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: B.line),
            ),
            child: const Text(
              'No envelopes yet. Add categories or entries to see this month at a glance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: B.muted,
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                Text(
                  '${envelopes.length} envelopes'.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                    color: B.soft2,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Tap an envelope for its items',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: B.muted,
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 118,
            ),
            itemCount: envelopes.length,
            itemBuilder: (context, index) => _buildEnvelopeCard(envelopes[index]),
          ),
        ],
      ],
    );
  }

  Widget _closedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: B.ink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: ic('lock', size: 16, sw: 2.2, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Month closed',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Locked — read only',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xccffffff),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: reopenMonth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Reopen',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: B.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvelopeCard(_BlockCompute block) {
    final stateColor = _envelopeStateColor(block);
    final fillColor = _envelopeFillColor(block);
    final fillFactor = block.cap == null || block.cap == 0
        ? 0.0
        : block.capFraction.clamp(0.0, 1.0).toDouble();
    final delta = _envelopeDelta(block);
    return GestureDetector(
      key: ValueKey('envelope-${block.key}'),
      onTap: () => openEnvelopeSheet(block.key),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: block.overCap ? B.red : B.line),
          boxShadow: cardShadow(),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (fillFactor > 0)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: math.max(.08, fillFactor),
                    alignment: Alignment.bottomCenter,
                    child: ColoredBox(color: fillColor),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _categoryGlyph(block, size: 24, radius: 8),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          block.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: B.ink,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    eur(block.total, cents: false),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                      color: block.overCap ? B.red : B.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    delta.$1,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: delta.$2,
                    ),
                  ),
                ],
              ),
            ),
            if (block.cap != null && block.cap! > 0)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${(block.total / block.cap! * 100).round()}%',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: stateColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  (String, Color) _envelopeDelta(_BlockCompute block) {
    if (block.overCap) {
      return ('over by ${eur(block.total - block.cap!, cents: false)}', B.red);
    }
    if (block.settled) return ('all paid', B.greenText);
    if (block.cap == null || block.cap == 0) return ('No limit set', B.muted);
    final left = math.max(0, block.cap! - block.total);
    final nearCap = block.total / block.cap! >= .85;
    return (
      '${eur(left, cents: false)} left',
      nearCap ? B.amberText : B.muted,
    );
  }

  Color _envelopeStateColor(_BlockCompute block) {
    if (block.overCap) return B.red;
    if (block.cap != null && block.cap! > 0 && block.total / block.cap! >= .85) {
      return B.amber;
    }
    return B.primary;
  }

  Color _envelopeFillColor(_BlockCompute block) {
    if (block.overCap) return const Color(0x22dc2626);
    if (block.cap != null && block.cap! > 0 && block.total / block.cap! >= .85) {
      return const Color(0x26d97706);
    }
    return const Color(0x1f0E9A8D);
  }

  Widget _buildListTab() {
    final c = compute(monthIdx);
    final rows = _monthListRows(c);
    double paidTotal = 0;
    double openTotal = 0;
    for (final row in rows) {
      if (!row.isIncome && row.done) paidTotal += row.amount;
      if (!row.isIncome && !row.done) openTotal += row.amount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.closed) _closedBanner(),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: B.line),
          ),
          child: Row(
            children: [
              _summaryTile('Items', '${rows.length}', B.ink),
              const SizedBox(width: 8),
              _summaryTile('Paid total', eur(paidTotal, cents: false), B.greenText),
              const SizedBox(width: 8),
              _summaryTile('Open total', eur(openTotal, cents: false), B.amberText),
            ],
          ),
        ),
        if (rows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: B.line),
            ),
            child: const Text(
              'No items in this month yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: B.muted,
              ),
            ),
          )
        else
          ..._buildListSections(rows, c.closed),
      ],
    );
  }

  List<Widget> _buildListSections(List<_FinanceListRow> rows, bool locked) {
    final out = <Widget>[];
    int? currentDay;
    List<_FinanceListRow> bucket = [];

    void flush() {
      if (bucket.isEmpty) return;
      final day = currentDay;
      final label = day == null
          ? 'No date'
          : '$day ${kMonthsEn[monthIdx]} · ${kWeekdaysFull[DateTime(year, monthIdx + 1, day).weekday - 1].substring(0, 3)}';
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 7),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: B.ink,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Divider(height: 1, thickness: 1, color: B.line),
              ),
            ],
          ),
        ),
      );
      out.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: B.line),
          ),
          child: Column(
            children: [
              for (int i = 0; i < bucket.length; i++)
                _buildListRow(bucket[i], locked, topBorder: i > 0),
            ],
          ),
        ),
      );
      bucket = [];
    }

    for (final row in rows) {
      if (row.day != currentDay) {
        flush();
        currentDay = row.day;
      }
      bucket.add(row);
    }
    flush();
    return out;
  }

  Widget _buildListRow(_FinanceListRow row, bool locked, {required bool topBorder}) {
    final canTap = !locked;
    final label = row.isIncome
        ? (row.done ? 'In' : 'Pending')
        : row.isSavings
        ? (row.done ? 'Saved' : 'Open')
        : (row.done ? 'Paid' : 'Open');
    return GestureDetector(
      onTap: canTap
          ? () => row.isIncome
                ? toggleReceived(row.id)
                : togglePaid(row.catKey, row.id)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          border: topBorder ? const Border(top: BorderSide(color: B.faint)) : null,
        ),
        child: Row(
          children: [
            _listGlyph(row),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: B.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: B.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${row.isIncome ? '+' : '−'}${eur(row.amount)}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: row.isIncome ? B.greenText : B.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 9),
            _statusPill(
              row.done,
              label,
              onTap: canTap
                  ? () => row.isIncome
                        ? toggleReceived(row.id)
                        : togglePaid(row.catKey, row.id)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _listGlyph(_FinanceListRow row) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: row.color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: glyphTile(
        size: 28,
        radius: 9,
        picture: row.picture,
        emoji: row.emoji,
        emojiSize: 14,
        fallback: Center(
          child: ic(
            row.isIncome ? 'wallet3' : row.icon,
            size: 14,
            sw: 2.1,
            color: row.color,
          ),
        ),
      ),
    );
  }

  List<_FinanceListRow> _monthListRows(_Compute c) {
    final rows = <_FinanceListRow>[];
    for (final block in c.blocks) {
      for (final row in block.items) {
        final item = row.item;
        rows.add(
          _FinanceListRow(
            id: item.id,
            day: item.day ?? dayNumFromMarker(item.marker),
            label: item.label.trim().isNotEmpty
                ? item.label.trim()
                : (item.payee.trim().isNotEmpty ? item.payee.trim() : block.title),
            subtitle: block.title,
            amount: item.amount,
            done: item.paid,
            isIncome: block.isIncome,
            isSavings: block.isSavings,
            color: block.tone,
            icon: block.icon,
            emoji: block.emoji,
            picture: block.picture,
            catKey: block.key,
          ),
        );
      }
    }
    rows.sort((a, b) {
      final dayCmp = (a.day ?? 99).compareTo(b.day ?? 99);
      if (dayCmp != 0) return dayCmp;
      return b.amount.compareTo(a.amount);
    });
    return rows;
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: B.faint,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
                color: B.muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryGlyph(
    _BlockCompute block, {
    required double size,
    required double radius,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: block.bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: glyphTile(
        size: size,
        radius: radius,
        picture: block.picture,
        emoji: block.emoji,
        emojiSize: size * .55,
        fallback: Center(
          child: ic(block.icon, size: size * .62, sw: 2, color: block.tone),
        ),
      ),
    );
  }

  Widget _statusPill(bool on, String label, {VoidCallback? onTap}) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: on ? B.greenSoft : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: on ? B.greenLine : const Color(0xffe5e7eb)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (on) ...[
            ic('check', size: 12, sw: 2.8, color: B.greenText),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: on ? B.greenText : B.muted,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return GestureDetector(onTap: onTap, child: pill);
  }

  Widget _bar(
    double frac,
    Color color, {
    double height = 6,
    Color track = B.track,
  }) {
    final f = frac.isNaN ? 0.0 : frac.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: double.infinity,
        height: height,
        color: track,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: f,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}
