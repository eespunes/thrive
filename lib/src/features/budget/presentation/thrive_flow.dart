part of 'package:family_money_management_app/main.dart';

/// A single money movement on a day of the Money calendar — an income or
/// expense item resolved onto a real day via the weekend rule. Ported from
/// the design's `flowRow` row shape.
class _FlowRow {
  _FlowRow({
    required this.kind,
    required this.id,
    required this.label,
    required this.amount,
    required this.done,
    required this.account,
    required this.color,
    required this.icon,
    this.emoji,
    this.picture,
    required this.group,
    this.catKey,
    required this.day,
    this.movedFrom,
  });

  /// `'in'` for income, `'out'` for expenses.
  final String kind;
  final String id;
  final String label;
  final double amount;

  /// `received` for income, `paid` for expenses.
  final bool done;
  final String account;
  final Color color;
  final String icon;
  final String? emoji;
  final String? picture;

  /// The owning category/block title, shown as `Category · Account`.
  final String group;

  /// The owning block's key, needed to toggle/edit the item.
  final String? catKey;

  /// The day-of-month this row actually lands on, after the weekend rule.
  final int day;

  /// The original marker day, if the weekend rule moved it; else `null`.
  final int? movedFrom;

  bool get isIncome => kind == 'in';
}

/// One day of the visible month: the money in/out that lands on it and the
/// running balance after it. Ported from the design's `flowModel().days[i]`.
class _FlowDay {
  _FlowDay({required this.day, required this.iso});

  final int day;
  final String iso;
  final List<_FlowRow> inRows = [];
  final List<_FlowRow> outRows = [];
  double inSum = 0;
  double outSum = 0;
  double net = 0;
  double bal = 0;

  bool get hasItems => inRows.isNotEmpty || outRows.isNotEmpty;
}

/// The whole Money calendar screen model for the visible month — every day
/// of the month plus the projection derived from it. Ported from the
/// design's `flowModel()`.
class _FlowModel {
  _FlowModel({
    required this.compute,
    required this.days,
    required this.dim,
    required this.open,
    required this.end,
    required this.low,
    required this.today,
    required this.overdue,
    required this.unscheduled,
    required this.inSum,
    required this.outSum,
    required this.unSum,
  });

  final _Compute compute;
  final List<_FlowDay> days;
  final int dim;
  final double open;
  final double end;
  final ({int day, double bal}) low;

  /// Day-of-month if the visible month is the current month, else `null`.
  final int? today;
  final List<_FlowRow> overdue;
  final List<_FlowRow> unscheduled;
  final double inSum, outSum, unSum;

  bool get closed => compute.closed;
}

/// The Money calendar screen (issue #199): a month-scoped view of money that
/// has a date — a running-balance projection, a calendar/timeline of every
/// in/out, and the items that still need a day. Ported from the design's
/// `renderFlow()` / `flowModel()` / `flow*()` methods.
extension _ThriveFlow on _ThriveHomeState {
  // --------------------------------------------------------------- helpers
  /// Day-of-month if the visible month/year is today's, else `null`. Mirrors
  /// `todayDay()`.
  int? _flowTodayDay() {
    final d = DateTime.now();
    return (d.year == year && d.month - 1 == monthIdx) ? d.day : null;
  }

  /// Whether the visible month is entirely in the past. Mirrors
  /// `monthIsPast()`.
  bool _flowMonthIsPast() {
    final d = DateTime.now();
    return (year * 12 + monthIdx) < (d.year * 12 + (d.month - 1));
  }

  /// Start balance on the 1st of month [mIdx] (defaults to the visible
  /// month). Mirrors `openBal(mi)`.
  double openBal([int? mIdx]) =>
      data[year]?[kMonthKeys[mIdx ?? monthIdx]]?.open ?? 0;

  void saveOpenBal(String raw) {
    final v = parseNum(raw);
    ensureYear(year);
    mutate(() {
      data[year]![kMonthKeys[monthIdx]]!.open = v;
    }, () => flash('Start balance saved'));
  }

  // ---------------------------------------------------------------- model
  /// Builds everything the Money calendar renders from the visible month.
  /// Mirrors `flowModel()`.
  _FlowModel flowModel() {
    final c = compute(monthIdx);
    final dim = daysInMonthOf(year, monthIdx);
    final days = [
      for (int i = 1; i <= dim; i++)
        _FlowDay(day: i, iso: _flowIso(year, monthIdx, i)),
    ];
    final unscheduled = <_FlowRow>[];

    for (final b in c.blocks) {
      for (final r in b.items) {
        final it = r.item;
        // The sheet import has several €0 placeholder rows — they carry no
        // real money movement, so skip them entirely (issue #199).
        if (it.amount == 0) continue;
        final parsed = dayNumFromMarker(it.marker);
        // Income with no marker lands on the 1st rather than being dropped
        // (it's still real, dated money) — expenses with no marker are
        // genuinely dateless and go to the unscheduled list below.
        final dv = b.isIncome ? (parsed ?? 1) : parsed;
        final row = _FlowRow(
          kind: b.isIncome ? 'in' : 'out',
          id: it.id,
          label: it.label.trim().isNotEmpty ? it.label.trim() : it.payee,
          amount: it.amount,
          done: it.paid,
          account: it.account,
          color: b.tone,
          icon: b.icon,
          emoji: b.emoji,
          picture: b.picture,
          group: b.title,
          catKey: b.key,
          day: dv ?? 0,
          movedFrom: null,
        );
        if (dv == null) {
          unscheduled.add(row);
          continue;
        }
        final resolved = resolveMoneyDay(dv, it.shift, year, monthIdx);
        final placed = _FlowRow(
          kind: row.kind,
          id: row.id,
          label: row.label,
          amount: row.amount,
          done: row.done,
          account: row.account,
          color: row.color,
          icon: row.icon,
          emoji: row.emoji,
          picture: row.picture,
          group: row.group,
          catKey: row.catKey,
          day: resolved.day,
          movedFrom: resolved.movedFrom,
        );
        final day = days[resolved.day - 1];
        if (b.isIncome) {
          day.inRows.add(placed);
          day.inSum += it.amount;
        } else {
          day.outRows.add(placed);
          day.outSum += it.amount;
        }
      }
    }

    final open = openBal();
    var bal = open;
    var low = (day: 1, bal: double.infinity);
    for (final d in days) {
      d.inRows.sort((a, b) => b.amount.compareTo(a.amount));
      d.outRows.sort((a, b) => b.amount.compareTo(a.amount));
      d.net = d.inSum - d.outSum;
      bal += d.net;
      d.bal = bal;
      if (bal < low.bal) low = (day: d.day, bal: bal);
    }

    final today = _flowTodayDay();
    final past = _flowMonthIsPast();
    final overdue = <_FlowRow>[];
    for (final d in days) {
      if (past || (today != null && d.day <= today)) {
        overdue.addAll(d.outRows.where((r) => !r.done));
      }
    }

    return _FlowModel(
      compute: c,
      days: days,
      dim: dim,
      open: open,
      end: bal,
      low: low,
      today: today,
      overdue: overdue,
      unscheduled: unscheduled,
      inSum: days.fold(0, (a, d) => a + d.inSum),
      outSum: days.fold(0, (a, d) => a + d.outSum),
      unSum: unscheduled.fold(0, (a, r) => a + r.amount),
    );
  }

  // ------------------------------------------------------------- sub-header
  Widget _buildFlowSubHeader() {
    final now = DateTime.now();
    final onNow = year == now.year && monthIdx == now.month - 1;
    final todayBtn = onNow
        ? null
        : GestureDetector(
            key: const ValueKey('flow-today-btn'),
            onTap: () => update(() {
              year = now.year;
              monthIdx = now.month - 1;
              swipedId = null;
            }),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: B.soft,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: B.primary),
              ),
              child: Center(
                child: ic('cal', size: 16, sw: 2.3, color: B.deep),
              ),
            ),
          );

    Widget vseg(String icon, String val) {
      final active = flowView == val;
      return GestureDetector(
        key: ValueKey('flow-view-$val'),
        onTap: () => update(() => flowView = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 34,
          height: 30,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .12),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: ic(
              icon,
              size: 17,
              sw: 2.2,
              color: active ? B.primary : const Color(0xff8995a6),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (todayBtn != null) ...[todayBtn, const SizedBox(width: 8)],
        Container(
          decoration: BoxDecoration(
            color: const Color(0xffe8ecf2),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [vseg('cal', 'calendar'), vseg('list', 'timeline')],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- screen
  Widget _buildFlow() {
    final f = flowModel();
    final locked = f.closed;
    final timeline = flowView == 'timeline';
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => update(() => swipedId = null),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
        children: [
          if (locked) _closedBanner(),
          _flowSummary(f),
          ?_flowAlert(f, locked),
          timeline ? _flowTimeline(f, locked) : _flowCalendar(f),
          if (!timeline) ?_flowNext(f, locked),
          ?_flowUnscheduled(f, locked),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- summary
  Widget _flowSummary(_FlowModel f) {
    final bad = f.low.bal < 0;
    final tight = !bad && f.low.bal < 300;
    const badTone = Color(0xfffda4af);
    const tightTone = Color(0xfffcd34d);
    const okTone = Color(0xff6ee7b7);
    final tone = bad ? badTone : (tight ? tightTone : okTone);
    final label = bad ? 'Goes negative' : (tight ? 'Gets tight' : 'Stays positive');

    Widget stat(String lab, String val, Color col) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lab.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
              color: Color(0x8cffffff),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            val,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: col,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: B.ink,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0f172a).withValues(alpha: .35),
            blurRadius: 34,
            spreadRadius: -22,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'LOWEST POINT THIS MONTH',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .6,
                        color: Color(0x8cffffff),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        eur(f.low.bal, cents: false),
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.6,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Text(
                      'on the ${ordinal(f.low.day)} \u00b7 ends at ${eur(f.end, cents: false)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xb3ffffff),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ic(bad ? 'bell' : 'trend', size: 12, sw: 2.4, color: tone),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: tone,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: _flowChart(f),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              stat('Money in', '+${eur(f.inSum, cents: false)}', okTone),
              stat('Money out', '\u2212${eur(f.outSum, cents: false)}', badTone),
              GestureDetector(
                key: const ValueKey('flow-start-btn'),
                onTap: openOpenBalSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'START',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                          color: Color(0x8cffffff),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            eur(f.open, cents: false),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 5),
                          ic('edit', size: 11, sw: 2.4, color: const Color(0x99ffffff)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flowChart(_FlowModel f) {
    return SizedBox(
      height: 64,
      width: double.infinity,
      child: CustomPaint(painter: _FlowChartPainter(f)),
    );
  }

  // ---------------------------------------------------------------- alert
  Widget? _flowAlert(_FlowModel f, bool locked) {
    if (locked || f.overdue.isEmpty) return null;
    final sum = f.overdue.fold<double>(0, (a, r) => a + r.amount);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: GestureDetector(
        key: const ValueKey('flow-overdue-banner'),
        onTap: () => update(() => flowView = 'timeline'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: B.amberSoft,
            border: Border.all(color: B.amberLine),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: ic('clock', size: 16, sw: 2.3, color: B.amberText),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${f.overdue.length} payment${f.overdue.length > 1 ? 's' : ''} past their date',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: B.amberText,
                      ),
                    ),
                    Text(
                      '${eur(sum, cents: false)} not ticked off yet',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: B.amberText,
                      ),
                    ),
                  ],
                ),
              ),
              ic('cright', size: 16, sw: 2.4, color: B.amberText),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- row
  Widget _flowRow(_FlowRow r, {required bool locked, int? day}) {
    final acc = accByKey(r.account);
    final isIn = r.isIncome;
    return GestureDetector(
      key: ValueKey('flow-row-${r.kind}-${r.id}'),
      onTap: locked || r.catKey == null
          ? null
          : () => openExpenseSheet(mode: 'edit', cat: r.catKey!, id: r.id),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: B.faint)),
        ),
        child: Row(
          children: [
            if (day != null) ...[
              SizedBox(
                width: 22,
                child: Text(
                  '$day',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: B.soft2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: r.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: glyphTile(
                size: 28,
                radius: 9,
                picture: r.picture,
                emoji: r.emoji,
                emojiSize: 15,
                fallback: Center(
                  child: ic(
                    isIn ? 'wallet3' : r.icon,
                    size: 15,
                    sw: 2.2,
                    color: r.color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    r.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: B.ink,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '${r.group} \u00b7 ${acc.short}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: B.muted,
                          ),
                        ),
                      ),
                      if (r.movedFrom != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: B.soft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ic('repeat', size: 9, sw: 2.6, color: B.deep),
                              const SizedBox(width: 3),
                              Text(
                                'from ${ordinal(r.movedFrom!)}',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: B.deep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isIn ? '+' : '\u2212'}${eur(r.amount, cents: false)}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isIn ? B.green : B.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: locked || r.catKey == null
                  ? null
                  : () => isIn
                        ? toggleReceived(r.id)
                        : togglePaid(r.catKey!, r.id),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: r.done ? B.green : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: r.done ? B.green : const Color(0xffd6dde7),
                    width: 1.6,
                  ),
                ),
                child: r.done
                    ? Center(
                        child: ic('check', size: 14, sw: 3, color: Colors.white),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowTile(String label, String val, Color col) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: B.faint,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
            val,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: col,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );

  // ------------------------------------------------------------- calendar
  Widget _flowCalendar(_FlowModel f) {
    const wk = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final off = (DateTime(year, monthIdx + 1, 1).weekday - 1) % 7;
    var maxFlow = 1.0;
    for (final d in f.days) {
      maxFlow = math.max(maxFlow, math.max(d.inSum, d.outSum));
    }
    final past = _flowMonthIsPast();

    Widget bar(double v, Color col) {
      final frac = v <= 0 ? 0.0 : math.max(0.16, (v / maxFlow)).clamp(0.0, 1.0);
      return SizedBox(
        height: 3,
        child: v <= 0
            ? null
            : Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(
                    decoration: BoxDecoration(
                      color: col,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
      );
    }

    final cells = <Widget>[
      for (int i = 0; i < off; i++) const SizedBox(),
      for (final d in f.days)
        Builder(
          builder: (context) {
            final isToday = f.today == d.day;
            final overdue =
                d.outRows.any((r) => !r.done) &&
                (past || (f.today != null && d.day <= f.today!));
            return GestureDetector(
              key: ValueKey('flow-day-${d.day}'),
              onTap: () => openFlowDaySheet(d.day),
              child: Container(
                height: 54,
                padding: const EdgeInsets.fromLTRB(5, 6, 5, 7),
                decoration: BoxDecoration(
                  color: isToday
                      ? B.soft
                      : (d.net != 0 ? B.faint : Colors.transparent),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: isToday
                        ? B.primary
                        : (overdue
                              ? const Color(0xfffcd9a5)
                              : Colors.transparent),
                  ),
                  boxShadow: isToday
                      ? [
                          BoxShadow(
                            color: B.primary.withValues(alpha: .18),
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isToday ? B.primary : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isToday ? Colors.white : B.ink,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        bar(d.inSum, B.green),
                        const SizedBox(height: 3),
                        bar(d.outSum, B.red),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
    ];

    Widget legend(Color col, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, color: col),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: B.soft2,
          ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: cardShadow(),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (int i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    wk[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: i > 4 ? B.muted : B.soft2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            childAspectRatio: .86,
            children: cells,
          ),
          Container(
            margin: const EdgeInsets.only(top: 11),
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: B.faint)),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                legend(B.green, 'Money in'),
                legend(B.red, 'Money out'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xfffffaf2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xfffcd9a5)),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Not ticked off',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: B.soft2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- next
  Widget? _flowNext(_FlowModel f, bool locked) {
    final from = f.today ?? 1;
    final out = <(int, _FlowRow)>[];
    for (final d in f.days) {
      if (d.day < from) continue;
      for (final r in [...d.inRows, ...d.outRows]) {
        if (out.length >= 4) break;
        out.add((d.day, r));
      }
      if (out.length >= 4) break;
    }
    if (out.isEmpty) return null;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'NEXT UP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: B.muted,
              ),
            ),
          ),
          for (final (day, r) in out) _flowRow(r, locked: locked, day: day),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ timeline
  Widget _flowTimeline(_FlowModel f, bool locked) {
    final active = f.days.where((d) => d.hasItems).toList();
    if (active.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: B.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Text(
            'Nothing with a date this month.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: B.muted,
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final d in active) ...[
          _flowDayCard(d, f, locked),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _flowDayCard(_FlowDay d, _FlowModel f, bool locked) {
    final isToday = f.today == d.day;
    final wd = kWeekdaysFull[DateTime(year, monthIdx + 1, d.day).weekday - 1]
        .substring(0, 3)
        .toUpperCase();
    return Container(
      key: ValueKey('flow-timeline-day-${d.day}'),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: isToday ? B.primary : B.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isToday ? B.primary : B.faint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: isToday ? Colors.white : B.ink,
                        ),
                      ),
                      Text(
                        wd,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                          color: (isToday ? Colors.white : B.ink)
                              .withValues(alpha: .72),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${d.net >= 0 ? '+' : '\u2212'}${eur(d.net.abs(), cents: false)}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: d.net >= 0 ? B.green : B.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'Balance after \u00b7 ${eur(d.bal, cents: false)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: B.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: B.soft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: B.deep,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final r in [...d.inRows, ...d.outRows])
            _flowRow(r, locked: locked),
        ],
      ),
    );
  }

  // --------------------------------------------------------- unscheduled
  Widget? _flowUnscheduled(_FlowModel f, bool locked) {
    if (f.unscheduled.isEmpty) return null;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffd8dee8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'NO DATE YET \u00b7 ${f.unscheduled.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                      color: B.muted,
                    ),
                  ),
                ),
                Text(
                  eur(f.unSum, cents: false),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: B.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 1),
            child: Text(
              'Not on the calendar and not in the projection. Tap one to give it a day.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: B.muted,
                height: 1.5,
              ),
            ),
          ),
          for (final r in f.unscheduled) _flowRow(r, locked: locked),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- sheets
  void openFlowDaySheet(int day) {
    _showSheet((ctx) => _FlowDaySheet(state: this, day: day));
  }

  void openOpenBalSheet() {
    _showSheet(monthScoped: true, (ctx) => _OpenBalSheet(state: this));
  }
}

String _flowIso(int year, int monthIdx, int day) =>
    '${year.toString().padLeft(4, '0')}-'
    '${(monthIdx + 1).toString().padLeft(2, '0')}-'
    '${day.toString().padLeft(2, '0')}';

const List<String> kWeekdaysFull = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

// ============================================================ day sheet
class _FlowDaySheet extends StatelessWidget {
  const _FlowDaySheet({required this.state, required this.day});
  final _ThriveHomeState state;
  final int day;

  @override
  Widget build(BuildContext context) {
    final f = state.flowModel();
    final d = f.days[math.min(day, f.dim) - 1];
    final locked = f.closed;
    final rows = [...d.inRows, ...d.outRows];
    final wd = kWeekdaysFull[DateTime(
      state.year,
      state.monthIdx + 1,
      d.day,
    ).weekday - 1];
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(
            context,
            '${ordinal(d.day)} ${kMonthsEn[state.monthIdx]}',
            wd + (f.today == d.day ? ' \u00b7 today' : ''),
          ),
          Row(
            children: [
              state._flowTile('In', '+${eur(d.inSum, cents: false)}', B.green),
              const SizedBox(width: 8),
              state._flowTile(
                'Out',
                '\u2212${eur(d.outSum, cents: false)}',
                B.red,
              ),
              const SizedBox(width: 8),
              state._flowTile(
                'Balance after',
                eur(d.bal, cents: false),
                d.bal < 0 ? B.red : B.ink,
              ),
            ],
          ),
          if (rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Column(
                children: [
                  for (final r in rows) state._flowRow(r, locked: locked),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No money moves on this day.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: B.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ======================================================== open bal sheet
class _OpenBalSheet extends StatefulWidget {
  const _OpenBalSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_OpenBalSheet> createState() => _OpenBalSheetState();
}

class _OpenBalSheetState extends State<_OpenBalSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: _numStr(widget.state.openBal()),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHead(
          context,
          'Start balance',
          '${kMonthsEn[s.monthIdx]} ${s.year}',
        ),
        const Text(
          'What sits on your accounts on the 1st? The projection and the lowest point are counted from here.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: B.soft2,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 14),
        _sheetField(
          'Balance (\u20ac)',
          _sheetInput(_ctrl, hint: '0,00', number: true),
        ),
        _primaryBtn('Save start balance', () {
          s.saveOpenBal(_ctrl.text.trim());
          Navigator.of(context).pop();
        }),
      ],
    );
  }
}

// ============================================================= chart
/// The dark projection card's running-balance line + area, ported from the
/// design's `flowChart()` SVG (line + soft fill, dashed zero line, a today
/// marker, and a dot on the lowest point).
class _FlowChartPainter extends CustomPainter {
  _FlowChartPainter(this.model);
  final _FlowModel model;

  @override
  void paint(Canvas canvas, Size size) {
    final vals = [for (final d in model.days) d.bal];
    if (vals.isEmpty) return;
    final n = vals.length;
    var minV = model.open, maxV = model.open;
    for (final v in vals) {
      minV = math.min(minV, v);
      maxV = math.max(maxV, v);
    }
    final span = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    double x(int i) => n > 1 ? i * size.width / (n - 1) : size.width / 2;
    double y(double v) =>
        size.height - 8 - ((v - minV) / span) * (size.height - 16);

    const lineColor = Color(0xff34d399);

    final linePath = Path()..moveTo(x(0), y(vals[0]));
    for (var i = 1; i < n; i++) {
      linePath.lineTo(x(i), y(vals[i]));
    }

    final areaPath = Path.from(linePath)
      ..lineTo(x(n - 1), size.height)
      ..lineTo(x(0), size.height)
      ..close();

    if (minV < 0 && maxV > 0) {
      final zeroY = y(0);
      final dashPaint = Paint()
        ..color = Colors.white.withValues(alpha: .3)
        ..strokeWidth = 1;
      var dx = 0.0;
      while (dx < size.width) {
        canvas.drawLine(
          Offset(dx, zeroY),
          Offset(math.min(dx + 3, size.width), zeroY),
          dashPaint,
        );
        dx += 7;
      }
    }

    canvas.drawPath(
      areaPath,
      Paint()..color = lineColor.withValues(alpha: .16),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = lineColor,
    );

    if (model.today != null) {
      final tx = x(model.today! - 1);
      canvas.drawLine(
        Offset(tx, 2),
        Offset(tx, size.height),
        Paint()
          ..color = Colors.white.withValues(alpha: .32)
          ..strokeWidth = 1,
      );
    }

    final lowX = x(model.low.day - 1);
    final lowY = y(model.low.bal);
    canvas.drawCircle(
      Offset(lowX, lowY),
      4,
      Paint()
        ..color = model.low.bal < 0
            ? const Color(0xfffda4af)
            : const Color(0xff34d399),
    );
    canvas.drawCircle(
      Offset(lowX, lowY),
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xff0f172a),
    );
  }

  @override
  bool shouldRepaint(covariant _FlowChartPainter old) => old.model != model;
}
