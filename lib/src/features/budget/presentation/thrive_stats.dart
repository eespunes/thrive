part of 'package:family_money_management_app/main.dart';

/// Statistics screen (issue #192) — the "Scorecard" design direction: a
/// gradient net-result hero card, four quick stat tiles, an "in vs out"
/// chart and a "where it went" category breakdown, switchable between
/// Month / Year / All time scopes.

/// Per-(year, month) totals used to build every [_StatsAgg] period. Reuses
/// [catsForMonth] so historical months keep whichever categories/blocks were
/// active in them (closed-month snapshots, temporary one-off categories),
/// matching how the rest of the app treats closed months.
class _StatsMonth {
  _StatsMonth({
    required this.year,
    required this.monthIdx,
    required this.income,
    required this.expenses,
    required this.fixed,
    required this.savings,
    required this.cats,
  });

  final int year;
  final int monthIdx;
  final double income;
  final double expenses;

  /// Sum of `recurring` (issue #191) expense items for this month — used as
  /// a proxy for "fixed" monthly costs vs one-off/flexible spending.
  final double fixed;

  /// Sum of items in blocks flagged [Category.isSavings] for this month —
  /// the actual amount set aside, as opposed to merely unspent income.
  final double savings;
  final Map<String, double> cats;

  double get net => income - expenses;
}

/// Aggregate of one or more [_StatsMonth] entries for a chosen scope
/// (month/year/all time), with an optional [prev] period to compare
/// against and a [trail] of recent points to chart.
class _StatsAgg {
  _StatsAgg({
    required this.months,
    required this.income,
    required this.expenses,
    required this.fixed,
    required this.savings,
    required this.cats,
  });

  final List<_StatsMonth> months;
  final double income;
  final double expenses;
  final double fixed;
  final double savings;
  final Map<String, double> cats;

  _StatsAgg? prev;
  String label = '';
  String prevLabel = '';
  String unit = 'month'; // month | year | all
  List<_StatsMonth> trail = const [];
  List<_StatsAgg> byYear = const [];
  int? yearLabel;

  double get net => income - expenses;

  /// Share of income actually set aside in savings blocks (issue #192 fix —
  /// previously this was leftover `net/income`, not real savings).
  double get rate => income > 0 ? savings / income * 100 : 0;
}

class _StatsCatRow {
  _StatsCatRow({
    required this.key,
    required this.title,
    required this.tone,
    required this.total,
    required this.share,
    required this.delta,
  });

  final String key;
  final String title;
  final Color tone;
  final double total;
  final double share;
  final double? delta;
}

/// Compact "€1,2k" style formatting for secondary labels.
String _kEur(double n) {
  final neg = n < 0;
  n = n.abs();
  String out;
  if (n >= 10000) {
    out = '\u20ac${(n / 1000).round()}k';
  } else if (n >= 1000) {
    out = '\u20ac${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')}k';
  } else {
    out = '\u20ac${n.round()}';
  }
  return neg ? '\u2212$out' : out;
}

String _pctLabel(double n) => '${n > 0 ? '+' : ''}${n.round()}%';

extension _ThriveStats on _ThriveHomeState {
  // ------------------------------------------------------------- data
  List<_StatsMonth> _statsSeries() {
    final years = data.keys.toList()..sort();
    final out = <_StatsMonth>[];
    for (final y in years) {
      final months = data[y];
      if (months == null) continue;
      for (int mi = 0; mi < kMonthKeys.length; mi++) {
        final m = months[kMonthKeys[mi]];
        if (m == null) continue;
        double income = 0, expenses = 0, fixed = 0, savings = 0;
        final catTotals = <String, double>{};
        for (final c in catsForMonth(mi, y)) {
          final items = m.blocks[c.key];
          if (items == null || items.isEmpty) continue;
          double total = 0;
          for (final it in items) {
            total += it.amount;
            if (!c.isIncome && it.recurring) fixed += it.amount;
          }
          if (c.isIncome) {
            income += total;
          } else {
            expenses += total;
            if (c.isSavings) savings += total;
            catTotals[c.key] = (catTotals[c.key] ?? 0) + total;
          }
        }
        out.add(
          _StatsMonth(
            year: y,
            monthIdx: mi,
            income: income,
            expenses: expenses,
            fixed: fixed,
            savings: savings,
            cats: catTotals,
          ),
        );
      }
    }
    return out;
  }

  _StatsAgg _aggStats(List<_StatsMonth> months) {
    double income = 0, expenses = 0, fixed = 0, savings = 0;
    final cats = <String, double>{};
    for (final m in months) {
      income += m.income;
      expenses += m.expenses;
      fixed += m.fixed;
      savings += m.savings;
      m.cats.forEach((k, v) => cats[k] = (cats[k] ?? 0) + v);
    }
    return _StatsAgg(
      months: months,
      income: income,
      expenses: expenses,
      fixed: fixed,
      savings: savings,
      cats: cats,
    );
  }

  /// All-time series, trimmed to the real, meaningful window: starts at the
  /// first month with any recorded activity (so pre-created empty years
  /// don't count) and ends at the current calendar month (so empty
  /// pre-created future months don't inflate the range either).
  List<_StatsMonth> _statsAllTimeSeries() {
    final full = _statsSeries();
    final now = DateTime.now();
    final capOrd = _monthOrd(now.year, now.month - 1);
    var trimmed = full
        .where((m) => _monthOrd(m.year, m.monthIdx) <= capOrd)
        .toList();
    final firstIdx = trimmed.indexWhere((m) => m.income > 0 || m.expenses > 0);
    if (firstIdx > 0) trimmed = trimmed.sublist(firstIdx);
    return trimmed;
  }

  double? _statsChangePct(double cur, double? prev) {
    if (prev == null || prev == 0) return null;
    return (cur - prev) / prev.abs() * 100;
  }

  /// Builds the aggregate for the currently selected [statsMode] scope.
  _StatsAgg _statsPeriod() {
    if (statsMode == 'year') {
      final series = _statsSeries();
      final cur = series.where((m) => m.year == year).toList();
      final prevList = series.where((m) => m.year == year - 1).toList();
      final p = _aggStats(cur)
        ..prev = prevList.isNotEmpty ? _aggStats(prevList) : null
        ..label = '$year'
        ..prevLabel = '${year - 1}'
        ..unit = 'year'
        ..trail = cur;
      return p;
    }

    if (statsMode == 'all') {
      final trimmed = _statsAllTimeSeries();
      final years = trimmed.map((m) => m.year).toSet().toList()..sort();
      final p = _aggStats(trimmed)
        ..prev = null
        ..label = years.isEmpty
            ? 'All time'
            : (years.length == 1
                  ? '${years.first}'
                  : '${years.first} \u2013 ${years.last}')
        ..unit = 'all'
        ..trail = trimmed
        ..byYear = years
            .map(
              (yy) =>
                  _aggStats(trimmed.where((m) => m.year == yy).toList())
                    ..yearLabel = yy,
            )
            .toList();
      return p;
    }

    // month (default)
    final series = _statsSeries();
    final cur = series
        .where((m) => m.year == year && m.monthIdx == monthIdx)
        .toList();
    final pmi = monthIdx == 0 ? 11 : monthIdx - 1;
    final py = monthIdx == 0 ? year - 1 : year;
    final prevList = series
        .where((m) => m.year == py && m.monthIdx == pmi)
        .toList();
    final upTo = _monthOrd(year, monthIdx);
    var trail = series
        .where((m) => _monthOrd(m.year, m.monthIdx) <= upTo)
        .toList();
    if (trail.length > 6) trail = trail.sublist(trail.length - 6);
    final p = _aggStats(cur)
      ..prev = prevList.isNotEmpty ? _aggStats(prevList) : null
      ..label = '${kMonthsEn[monthIdx]} $year'
      ..prevLabel = kMonthsEn[pmi]
      ..unit = 'month'
      ..trail = trail;
    return p;
  }

  /// Average per-month income/expenses/net for a period, used for the
  /// year/all-time "≈ €x per month" subtitles.
  ({double income, double expenses, double net}) _statsPerMonth(_StatsAgg p) {
    final n = p.months.isEmpty ? 1 : p.months.length;
    return (income: p.income / n, expenses: p.expenses / n, net: p.net / n);
  }

  List<_StatsCatRow> _statsCatRows(_StatsAgg p) {
    final total = p.expenses <= 0 ? 1.0 : p.expenses;
    final rows = <_StatsCatRow>[];
    for (final c in cats) {
      if (c.isIncome) continue;
      final amt = p.cats[c.key] ?? 0;
      if (amt <= 0.5) continue;
      final prevAmt = p.prev?.cats[c.key];
      final delta = (prevAmt != null && prevAmt > 0)
          ? (amt - prevAmt) / prevAmt * 100
          : null;
      rows.add(
        _StatsCatRow(
          key: c.key,
          title: c.title,
          tone: c.tone,
          total: amt,
          share: amt / total * 100,
          delta: delta,
        ),
      );
    }
    rows.sort((a, b) => b.total.compareTo(a.total));
    return rows;
  }

  /// Groups charted by the "In vs out" card: 6-month trail for month scope,
  /// the current year's months for year scope, or one point per year for
  /// all-time (fixes the source design's bug of charting a single month).
  List<StatsChartPoint> _statsChartPoints(_StatsAgg p) {
    if (p.unit == 'all') {
      return p.byYear
          .map(
            (a) => (
              label: '${a.yearLabel}',
              income: a.income,
              expenses: a.expenses,
              hi: a.yearLabel == year,
            ),
          )
          .toList();
    }
    final months = p.unit == 'year' ? p.months : p.trail;
    return months
        .map(
          (m) => (
            label: kMonthsShort[m.monthIdx],
            income: m.income,
            expenses: m.expenses,
            hi: p.unit == 'year'
                ? m.monthIdx == monthIdx
                : m.year == year && m.monthIdx == monthIdx,
          ),
        )
        .toList();
  }

  // ------------------------------------------------------------- widgets
  Widget _buildStats() {
    final p = _statsPeriod();
    final rows = _statsCatRows(p);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
      children: [
        _statsHero(p),
        const SizedBox(height: 11),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _statsIncomeTile(p)),
            const SizedBox(width: 11),
            Expanded(child: _statsSpendingTile(p)),
          ],
        ),
        const SizedBox(height: 11),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _statsRateTile(p)),
            const SizedBox(width: 11),
            Expanded(child: _statsFixedTile(p)),
          ],
        ),
        const SizedBox(height: 11),
        _statsInOutChart(p),
        const SizedBox(height: 11),
        _statsCatGrid(p, rows),
        if (p.unit == 'all' && p.byYear.isNotEmpty) ...[
          const SizedBox(height: 11),
          _statsYearRows(p),
        ],
      ],
    );
  }

  Widget? _statsDeltaChip(
    double? v, {
    required bool invert,
    bool dark = false,
  }) {
    if (v == null) return null;
    final good = invert ? v <= 0 : v >= 0;
    final up = v >= 0;
    final bg = dark
        ? (good ? const Color(0x2922C77C) : const Color(0x2EE2526A))
        : (good ? B.greenSoft : B.redSoft);
    final fg = dark
        ? (good ? const Color(0xff54d99a) : const Color(0xffff8fa3))
        : (good ? B.greenText : B.red);
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 7, 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ic(up ? 'trend' : 'down', size: 11, sw: 2.6, color: fg),
          const SizedBox(width: 3),
          Text(
            _pctLabel(v),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsHero(_StatsAgg p) {
    final dNet = _statsChangePct(p.net, p.prev?.net);
    final trail = p.trail;
    double tMax = 1;
    for (final m in trail) {
      tMax = math.max(tMax, m.net.abs());
    }
    final subtitle = p.unit == 'month'
        ? 'vs ${p.prevLabel} ${eur(p.prev?.net ?? 0, cents: false)}'
        : '\u2248 ${eur(_statsPerMonth(p).net, cents: false)} per month';
    final trailCaption = p.unit == 'month'
        ? 'LAST 6 MONTHS'
        : p.unit == 'year'
        ? 'MONTH BY MONTH'
        : '${trail.length} MONTHS';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff0FA08E), Color(0xff0B7F74), Color(0xff1684B4)],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0B7F74).withValues(alpha: .5),
            blurRadius: 34,
            offset: const Offset(0, 18),
            spreadRadius: -22,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (p.unit == 'all'
                    ? 'NET OVER ${p.byYear.length} YEARS'
                    : 'NET RESULT'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Color(0xffcdf3ea),
                ),
              ),
              if (dNet != null)
                _statsDeltaChip(dNet, invert: false, dark: true)!,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            eur(p.net, cents: false),
            style: const TextStyle(
              fontSize: 33,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xffcdf3ea),
            ),
          ),
          const SizedBox(height: 14),
          if (trail.isNotEmpty) ...[
            SizedBox(
              height: 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < trail.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final barH = math.max(
                            3.0,
                            trail[i].net.abs() / tMax * 36,
                          );
                          final selected =
                              statsHeroSelIdx == i && statsHeroSelFor == p.unit;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => update(() {
                              if (selected) {
                                statsHeroSelIdx = null;
                                statsHeroSelFor = null;
                              } else {
                                statsHeroSelIdx = i;
                                statsHeroSelFor = p.unit;
                              }
                            }),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.bottomCenter,
                              children: [
                                Container(
                                  height: barH,
                                  decoration: BoxDecoration(
                                    color: trail[i].net >= 0
                                        ? Colors.white.withValues(
                                            alpha: i == trail.length - 1
                                                ? 1
                                                : .45,
                                          )
                                        : const Color(0xffff9fb0).withValues(
                                            alpha: i == trail.length - 1
                                                ? 1
                                                : .45,
                                          ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                if (selected)
                                  Positioned(
                                    bottom: barH + 6,
                                    child: _statsHeroBubble(trail[i]),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              trailCaption,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .6,
                color: Color(0xff9fd8cf),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Small tooltip-style bubble shown above a tapped hero sparkline bar,
  /// with that month's label and net result (issue #192 follow-up).
  Widget _statsHeroBubble(_StatsMonth m) {
    final label = '${kMonthsShort[m.monthIdx]} ${m.year}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: B.ink,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xffcbd5e1),
            ),
          ),
          Text(
            eur(m.net, cents: false),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsTile({
    required String label,
    required String val,
    required String sub,
    double? delta,
    required String icon,
    required Color color,
    required bool invert,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(child: ic(icon, size: 12, sw: 2.4, color: color)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                    color: B.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            val,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  sub,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: B.muted,
                  ),
                ),
              ),
              if (delta != null) ...[
                const SizedBox(width: 6),
                _statsDeltaChip(delta, invert: invert)!,
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsIncomeTile(_StatsAgg p) => _statsTile(
    label: 'Income',
    val: eur(p.income, cents: false),
    sub: p.unit == 'month'
        ? 'this month'
        : '${_kEur(_statsPerMonth(p).income)}/mo',
    delta: _statsChangePct(p.income, p.prev?.income),
    icon: 'wallet',
    color: B.green,
    invert: false,
  );

  Widget _statsSpendingTile(_StatsAgg p) => _statsTile(
    label: 'Spending',
    val: eur(p.expenses, cents: false),
    sub: p.unit == 'month'
        ? 'this month'
        : '${_kEur(_statsPerMonth(p).expenses)}/mo',
    delta: _statsChangePct(p.expenses, p.prev?.expenses),
    icon: 'cart',
    color: B.red,
    invert: true,
  );

  Widget _statsRateTile(_StatsAgg p) => _statsTile(
    label: 'Savings rate',
    val: '${p.rate.round()}%',
    sub: 'of income kept',
    delta: p.prev == null ? null : p.rate - p.prev!.rate,
    icon: 'gauge',
    color: B.primary,
    invert: false,
  );

  Widget _statsFixedTile(_StatsAgg p) => _statsTile(
    label: 'Fixed costs',
    val: eur(p.fixed, cents: false),
    sub: p.expenses > 0
        ? '${(p.fixed / p.expenses * 100).round()}% locked in'
        : 'locked in',
    delta: null,
    icon: 'lock',
    color: const Color(0xff1E7FB5),
    invert: false,
  );

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: B.soft2,
        ),
      ),
    ],
  );

  Widget _statsInOutChart(_StatsAgg p) {
    final points = _statsChartPoints(p);
    final caption = p.unit == 'month'
        ? 'Last 6 months'
        : p.unit == 'year'
        ? 'Every month of ${p.label}'
        : 'Per year';
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'In vs out',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    caption,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: B.muted,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _legendDot(B.green, 'In'),
                  const SizedBox(width: 11),
                  _legendDot(B.red, 'Out'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Not enough data yet.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: B.muted,
                ),
              ),
            )
          else
            AspectRatio(
              aspectRatio: 340 / 136,
              child: CustomPaint(painter: _InOutChartPainter(points)),
            ),
        ],
      ),
    );
  }

  Widget _statsCatTile(_StatsAgg p, _StatsCatRow c) {
    final n = math.min(8, p.trail.length);
    final series = n == 0
        ? const <double>[]
        : p.trail
              .sublist(p.trail.length - n)
              .map((m) => m.cats[c.key] ?? 0)
              .toList();
    double mx = 1;
    for (final v in series) {
      mx = math.max(mx, v);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.tone,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: B.soft2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            eur(c.total, cents: false),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${c.share.round()}% of spending',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: B.muted,
                ),
              ),
              if (c.delta != null)
                Text(
                  _pctLabel(c.delta!),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: c.delta! > 0 ? B.red : B.greenText,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          if (series.isNotEmpty)
            SizedBox(
              height: 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < series.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      child: Container(
                        height: math.max(2.0, series[i] / mx * 22),
                        decoration: BoxDecoration(
                          color: c.tone.withValues(
                            alpha: i == series.length - 1 ? 1 : .28,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statsCatGrid(_StatsAgg p, List<_StatsCatRow> rows) {
    final tiles = <Widget>[];
    for (int i = 0; i < rows.length; i += 2) {
      final a = rows[i];
      final b = i + 1 < rows.length ? rows[i + 1] : null;
      tiles.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _statsCatTile(p, a)),
            const SizedBox(width: 11),
            Expanded(child: b != null ? _statsCatTile(p, b) : const SizedBox()),
          ],
        ),
      );
      if (i + 2 < rows.length) tiles.add(const SizedBox(height: 11));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'WHERE IT WENT',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: B.muted,
              ),
            ),
            Text(
              eur(p.expenses, cents: false),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: B.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No expenses recorded yet.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: B.muted,
              ),
            ),
          )
        else
          Column(children: tiles),
      ],
    );
  }

  Widget _statsYearRows(_StatsAgg p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 4, 15, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Year by year',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
          ),
          for (final a in p.byYear.reversed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: B.faint)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${a.yearLabel}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${_kEur(a.income)} in \u00b7 ${_kEur(a.expenses)} out',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: B.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    eur(a.net, cents: false),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: a.net >= 0 ? B.greenText : B.red,
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${a.rate.round()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: B.muted,
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
}
