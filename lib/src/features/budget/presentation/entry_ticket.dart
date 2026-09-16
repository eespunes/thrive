part of 'package:family_money_management_app/main.dart';

/// The money entry editor (design "Event & finance editors" 1b): the same
/// card language as the event editor, in money vocabulary. A scroll of
/// labelled white cards — one decision each — with the amount as the hero
/// card, stating its effect on the block's cap in words.
///
/// There is no preview strip here: a money entry has no visual form to check,
/// so the cap line is the consequence you read instead. Each card states its
/// own answer next to its label, so the scroll reads as a summary.

/// Parses a EUR amount with comma decimals (#287): `"45,"`, `"45,5"`,
/// `"1.250,00"`. Returns `null` for an empty string and [double.nan] for
/// text that isn't a number.
double? parseEntryAmount(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (!RegExp(r'^-?[\d.]*,?\d*$').hasMatch(s)) return double.nan;
  final n = double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
  return n ?? double.nan;
}

/// Inline amount error (#287) — save is never silently dead. Returns `null`
/// when the amount is valid.
String? entryAmountError(String raw) {
  final n = parseEntryAmount(raw);
  if (n == null) return 'Give it an amount.';
  if (n.isNaN) return 'Numbers only — use a comma for cents.';
  if (n < 0) return "It can't be negative.";
  if (n == 0) {
    return '€0 would be skipped by the calendar — give it a real amount.';
  }
  return null;
}

/// The four adaptive label sets (#286): labels come from the block's
/// direction (`isIncome`/`isSavings`), never from the entry.
({
  String payeePh,
  String dayHead,
  String paid,
  String unpaid,
  String accHead,
  String noun,
})
entryWords(String kind) => (
  payeePh: kind == 'income' ? 'From' : 'Company',
  dayHead: kind == 'income' ? 'Date' : 'Pay day',
  paid: kind == 'income'
      ? 'Received'
      : kind == 'savings'
      ? 'Saved'
      : 'Paid',
  unpaid: kind == 'income'
      ? 'Not received'
      : kind == 'savings'
      ? 'Not saved yet'
      : 'Not paid',
  accHead: kind == 'income'
      ? 'Received into'
      : kind == 'savings'
      ? 'Save from'
      : 'Pay from',
  noun: kind == 'income'
      ? 'income'
      : kind == 'savings'
      ? 'savings'
      : 'expense',
);

/// Month ordinal (year*12+monthIdx) of the series' last real charge given an
/// end month (#291): the last filled cell of the year strip. `null` when the
/// end lies before the anchor.
int? lastChargedMonthOrd(int anchorOrd, int endOrd, int every) {
  if (endOrd < anchorOrd) return null;
  final e = every < 1 ? 1 : every;
  return anchorOrd + ((endOrd - anchorOrd) ~/ e) * e;
}

/// Plain-language repeat summary (#291) — always present under the tray.
String entryRecurSummary({
  required bool recurring,
  required int every,
  required int? day,
  required String shift,
  required int anchorOrd,
  required int? endOrd,
}) {
  final mn = kMonthsEn[anchorOrd % 12];
  if (!recurring) return 'One-off — only this $mn.';
  var s =
      'Repeats ${every == 1
          ? 'every month'
          : every == 12
          ? 'every 12 months (yearly)'
          : 'every $every months'}';
  s += day == null ? ' · unscheduled' : ' on the ${ordinal(day)}';
  final endBad = endOrd != null && endOrd < anchorOrd;
  if (endOrd != null && !endBad) {
    s += ' until ${kMonthsShortEn[endOrd % 12]} ${endOrd ~/ 12}';
  }
  if (shift == 'before' && day != null) {
    s += ' · shifts to the Friday before weekends';
  }
  if (shift == 'after' && day != null) {
    s += ' · shifts to the Monday after weekends';
  }
  if (endBad) {
    return '$s. That end date is before $mn — pick $mn ${anchorOrd ~/ 12} or later.';
  }
  final lo = endOrd == null
      ? null
      : lastChargedMonthOrd(anchorOrd, endOrd, every);
  if (lo != null && lo != endOrd) {
    s += '. Last one lands ${kMonthsShortEn[lo % 12]} ${lo ~/ 12}.';
  } else {
    s += '.';
  }
  return s;
}

const List<String> kMonthsShortEn = [
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

extension _ThriveEntryTicket on _ThriveHomeState {
  String _entryKindOf(Category? c) => c == null
      ? 'expense'
      : c.isIncome
      ? 'income'
      : c.isSavings
      ? 'savings'
      : 'expense';

  /// Opens the entry ticket (#286). Block-less launches (quick add #295,
  /// Money-calendar day #295) show the block picker first (#294); launches
  /// from a block context land straight on the ticket.
  void openEntryTicket({String? cat, String? id, int? presetDay}) {
    if (cat == null) {
      _showSheet(
        monthScoped: true,
        (ctx) => _EntryBlockPickerSheet(state: this, presetDay: presetDay),
      );
      return;
    }
    _showSheet(
      monthScoped: true,
      (ctx) => _EntryTicketSheet(
        state: this,
        cat: cat,
        id: id,
        presetDay: presetDay,
      ),
    );
  }
}

// ==================================================== block picker (#294)
class _EntryBlockPickerSheet extends StatelessWidget {
  const _EntryBlockPickerSheet({required this.state, this.presetDay});
  final _ThriveHomeState state;
  final int? presetDay;

  @override
  Widget build(BuildContext context) {
    final c = state.compute(state.monthIdx);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHead(context, 'Which block does it belong to?', null),
          for (final b in c.blocks)
            _EntryBlockRow(
              key: ValueKey('entry-pick-block-${b.key}'),
              block: b,
              selected: false,
              onTap: () {
                Navigator.of(context).pop();
                state.openEntryTicket(cat: b.key, presetDay: presetDay);
              },
            ),
        ],
      ),
    );
  }
}

/// One block option row: colour dot, name, live cap line.
class _EntryBlockRow extends StatelessWidget {
  const _EntryBlockRow({
    super.key,
    required this.block,
    required this.selected,
    required this.onTap,
  });
  final _BlockCompute block;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = block;
    final capLine = b.isIncome
        ? '${eur(b.total, cents: false)} planned'
        : b.cap != null && b.cap! > 0
        ? '${(b.total / b.cap! * 100).round()}% of ${eur(b.cap, cents: false)}'
        : b.isSavings
        ? '${eur(b.total, cents: false)} saved'
        : '${eur(b.total, cents: false)} planned';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: selected ? B.soft : const Color(0xfff8fafc),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? B.primary : B.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: b.tone,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                b.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: B.ink,
                ),
              ),
            ),
            Text(
              capLine,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: B.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================== the ticket sheet
class _EntryTicketSheet extends StatefulWidget {
  const _EntryTicketSheet({
    required this.state,
    required this.cat,
    this.id,
    this.presetDay,
  });
  final _ThriveHomeState state;
  final String cat;
  final String? id;
  final int? presetDay;

  @override
  State<_EntryTicketSheet> createState() => _EntryTicketSheetState();
}

class _EntryTicketSheetState extends State<_EntryTicketSheet> {
  late final TextEditingController _payee;
  late final TextEditingController _label;
  late final TextEditingController _amount;
  late String _cat;
  int? _day;
  String _shift = 'none';
  bool _paid = false;
  bool _wasPaid = false;
  String _account = '';
  String? _cardId;
  bool _recurring = true;
  int _recurEvery = 1;
  int? _endOrd; // year*12+monthIdx of the repeat end, null = open-ended
  bool _reviewDay = false;
  String? _createdBy;
  String? _createdAt;
  bool _accountReassigned = false;

  bool get _editing => widget.id != null;

  _ThriveHomeState get s => widget.state;

  ExpenseItem? get _item => _editing
      ? (s.cur()?.blocks[_cat] ?? const <ExpenseItem>[])
            .where((x) => x.id == widget.id)
            .firstOrNull
      : null;

  @override
  void initState() {
    super.initState();
    _cat = widget.cat;
    final it = _editing
        ? (s.cur()?.blocks[widget.cat] ?? const <ExpenseItem>[])
              .where((x) => x.id == widget.id)
              .firstOrNull
        : null;
    _payee = TextEditingController(text: it?.payee ?? '');
    _label = TextEditingController(text: it?.label ?? '');
    _amount = TextEditingController(text: it != null ? _numStr(it.amount) : '');
    _day = it != null
        ? (it.day ?? dayNumFromMarker(it.marker))
        : widget.presetDay;
    _shift = it?.shift ?? 'none';
    _paid = it?.paid ?? false;
    _wasPaid = _paid;
    // #299: the family's first account is the default, never a hardcoded
    // "shared".
    final accs = s.accountsForMonth(s.monthIdx);
    _account = it?.account ?? (accs.isNotEmpty ? accs.first.key : '');
    if (it != null && accs.every((a) => a.key != it.account)) {
      // Account deleted elsewhere (#299): entries auto-reassign to the last
      // remaining account — show the resolved chip with a one-time hint.
      _account = accs.isNotEmpty ? accs.last.key : '';
      _accountReassigned = true;
    }
    _cardId = it?.cardId;
    _recurring = it?.recurring ?? true;
    _recurEvery = it?.recurEvery ?? 1;
    final end = normalizeRecurringEndDate(it?.recurEndDate ?? it?.until);
    if (end != null) {
      final p = end.split('-');
      final y = int.tryParse(p[0]);
      final m = p.length > 1 ? int.tryParse(p[1]) : null;
      if (y != null && m != null) _endOrd = y * 12 + m - 1;
    }
    _reviewDay = it?.reviewDay ?? false;
    _createdBy = it?.createdBy;
    _createdAt = it?.createdAt;
  }

  @override
  void dispose() {
    _payee.dispose();
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ helpers

  Category get _block =>
      s.catsForMonth(s.monthIdx).where((c) => c.key == _cat).firstOrNull ??
      s.catByKey(_cat) ??
      defaultIncomeCat();

  String get _kind => s._entryKindOf(_block);

  bool get _closed => s.isClosed();

  int get _anchorOrd => s.year * 12 + s.monthIdx;

  /// Save blocked with a reason, never a dead button (#301).
  String? get _reason {
    final ae = entryAmountError(_amount.text);
    if (ae != null) return ae;
    if (_payee.text.trim().isEmpty && _label.text.trim().isEmpty) {
      return 'Add a company or a note — one is enough.';
    }
    if (_recurring && _endOrd != null && _endOrd! < _anchorOrd) {
      return 'The end date is before ${kMonthsEn[s.monthIdx]} ${s.year}.';
    }
    return null;
  }

  /// The cap impact recomputed live with this amount (#287), matching the
  /// Overview block header's math to the cent: the block's planned total
  /// with the edited amount replacing the stored one.
  ({bool show, int pct, Color col, String short, String? alt}) get _capInfo {
    final b = s
        .compute(s.monthIdx)
        .blocks
        .where((x) => x.key == _cat)
        .firstOrNull;
    final n = parseEntryAmount(_amount.text);
    final amt = (n != null && !n.isNaN && n > 0) ? n : 0.0;
    final orig = _item?.amount ?? 0;
    final total = (b?.total ?? 0) - orig + amt;
    if (b == null || b.isIncome) {
      return (
        show: false,
        pct: 0,
        col: B.muted,
        short: '',
        alt:
            '${kMonthsEn[s.monthIdx]} income so far: '
            '${eur((b?.total ?? 0) - orig + amt, cents: false)}',
      );
    }
    if (b.isSavings && (b.cap == null || b.cap == 0)) {
      return (
        show: false,
        pct: 0,
        col: B.muted,
        short: '',
        alt:
            '${eur(b.total - orig, cents: false)} put aside → '
            '${eur(total, cents: false)} with this',
      );
    }
    if (b.cap == null || b.cap == 0) {
      return (
        show: false,
        pct: 0,
        col: B.muted,
        short: '',
        alt: '${eur(total, cents: false)} planned with this',
      );
    }
    final pct = (total / b.cap! * 100).round();
    final col = pct > 100
        ? B.red
        : pct >= 85
        ? B.amber
        : B.soft2;
    return (
      show: true,
      pct: pct,
      col: col,
      short: '$pct% of ${eur(b.cap, cents: false)}',
      alt: null,
    );
  }

  // --------------------------------------------------------------- save

  void _submit() {
    if (s.isClosed()) {
      // Mid-edit close race (#298): refuse, keep the draft visible.
      setState(() {});
      s.flash('${kMonthsEn[s.monthIdx]} is closed — reopen it from Money');
      return;
    }
    final reason = _reason;
    if (reason != null) {
      s.flash(reason);
      return;
    }
    if (_recurring && _editing) {
      final name = _payee.text.trim().isNotEmpty
          ? _payee.text.trim()
          : _label.text.trim();
      Navigator.of(context).pop();
      s._showSheet(
        monthScoped: true,
        (ctx) => _EntryScopeSheet(
          state: s,
          name: name.isEmpty ? 'this entry' : name,
          deleting: false,
          onScope: (scope) => _persist(scope),
        ),
      );
      return;
    }
    _persist('onward');
    Navigator.of(context).pop();
  }

  void _persist(String scope) {
    final amount = parseEntryAmount(_amount.text) ?? 0;
    if (_editing && _cat != widget.cat) {
      s.moveExpenseBlock(widget.cat, _cat, widget.id!);
    }
    s.saveExpense(
      _editing ? 'edit' : 'add',
      _cat,
      widget.id,
      payee: _payee.text.trim(),
      label: _label.text.trim(),
      amount: amount,
      day: _day,
      paid: _paid,
      account: _account,
      recurring: _recurring,
      recurEvery: _recurEvery,
      recurEndDate: _endOrd == null
          ? null
          : '${(_endOrd! ~/ 12).toString().padLeft(4, '0')}-'
                '${((_endOrd! % 12) + 1).toString().padLeft(2, '0')}-'
                '${daysInMonthOf(_endOrd! ~/ 12, _endOrd! % 12).toString().padLeft(2, '0')}',
      shift: _shift,
      cardId: _cardId,
      scope: scope,
    );
    // #296: marking paid with a linked card logs a card use (existing rule).
    if (_paid && !_wasPaid && _cardId != null) {
      final card = s.cards.where((c) => c.id == _cardId).firstOrNull;
      if (card != null) s.logCardUse(card.id);
    }
  }

  void _delete() {
    final name = _payee.text.trim().isNotEmpty
        ? _payee.text.trim()
        : _label.text.trim();
    Navigator.of(context).pop();
    if (_recurring) {
      s._showSheet(
        monthScoped: true,
        (ctx) => _EntryScopeSheet(
          state: s,
          name: name.isEmpty ? 'this entry' : name,
          deleting: true,
          onScope: (scope) =>
              s.deleteExpense(widget.cat, widget.id!, scope: scope),
        ),
      );
    } else {
      s.askDelete(
        name.isEmpty ? 'this entry' : name,
        'It only ever existed this month.',
        () => s.deleteExpense(widget.cat, widget.id!),
      );
    }
  }

  // -------------------------------------------------------------- ticket

  /// The amount card — the design's hero (1b): the figure itself, its error
  /// line, and what it does to the block's cap stated in words. A money entry
  /// has no visual form to preview, so this card is what the event editor's
  /// preview strip is there: the consequence of what you just typed.
  Widget _amountCard() {
    final cap = _capInfo;
    final amountLen = _amount.text.length;
    final err = entryAmountError(_amount.text);
    return _section(
      'amount',
      'Amount',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '€',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: B.muted,
                ),
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: IntrinsicWidth(
                  child: TextField(
                    key: const ValueKey('entry-amount'),
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '0,00',
                    ),
                    style: TextStyle(
                      fontSize: amountLen > 9 ? 28 : 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: B.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (err != null && _amount.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                err,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: B.red,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                if (cap.show) ...[
                  Container(
                    width: 120,
                    height: 5,
                    decoration: BoxDecoration(
                      color: B.track,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (cap.pct / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cap.col,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      cap.short,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: cap.col,
                      ),
                    ),
                  ),
                ] else if (cap.alt != null)
                  Expanded(
                    child: Text(
                      cap.alt!,
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

  /// Who it is and what it was for. The design's note stands: one of the two
  /// is enough, which is exactly what [_reason] enforces.
  Widget _aboutCard() {
    final w = entryWords(_kind);
    return _section(
      'about',
      w.noun,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          studioTextField(
            key: const ValueKey('entry-payee'),
            controller: _payee,
            hint: w.payeePh,
            onChanged: (_) => setState(() {}),
            capitalization: TextCapitalization.sentences,
            margin: const EdgeInsets.only(bottom: 8),
          ),
          studioTextField(
            key: const ValueKey('entry-label'),
            controller: _label,
            hint: 'Note or subcategory',
            onChanged: (_) => setState(() {}),
            capitalization: TextCapitalization.sentences,
            margin: EdgeInsets.zero,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Text(
              'One of the two is enough.',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: B.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The paid flag, which the ticket wore as a rotated stamp. It sits with
  /// the account that pays, as the design files it.
  Widget _paidRow() {
    final w = entryWords(_kind);
    return studioToggleRow(
      key: const ValueKey('entry-stamp'),
      label: 'Mark ${w.paid.toLowerCase()}',
      sub: _paid ? '${w.paid} — it counts as settled' : 'Not yet settled',
      value: _paid,
      onChanged: () {
        if (_closed) {
          s.flash(
            '${kMonthsEn[s.monthIdx]} is closed — the flag can\u2019t change',
          );
          return;
        }
        setState(() => _paid = !_paid);
      },
    );
  }

  // --------------------------------------------------------------- trays

  Widget _chip(
    Key key,
    String label,
    bool on,
    VoidCallback onTap, {
    Widget? leading,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? B.soft : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? B.primary : B.line, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 6)],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: on ? B.deep : B.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Day tray (#288): a real 1–31 grid, weekends tinted, plus an explicit
  /// Unscheduled row; shift chips (#289) and the resolved-date hint.
  Widget _trayDay() {
    final dim = daysInMonthOf(s.year, s.monthIdx);
    final r = _day == null
        ? null
        : resolveMoneyDay(_day!, _shift, s.year, s.monthIdx);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          children: [for (int i = 1; i <= dim; i++) _dayCell(i, r)],
        ),
        const SizedBox(height: 9),
        GestureDetector(
          key: const ValueKey('entry-day-unscheduled'),
          onTap: () => setState(() {
            _day = _day == null ? 1 : null;
            _reviewDay = false;
          }),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _day == null ? B.soft : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: _day == null
                  ? Border.all(color: B.primary, width: 1.5)
                  : Border.all(color: const Color(0xffcfd8e3)),
            ),
            child: Text(
              _day == null
                  ? '✓ Unscheduled — off the calendar'
                  : 'Unscheduled — keep it off the calendar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _day == null ? B.deep : B.soft2,
              ),
            ),
          ),
        ),
        if (_day != null) ...[
          const SizedBox(height: 9),
          Row(
            children: [
              for (final o in const [
                ('none', 'No shift'),
                ('before', 'Fri before'),
                ('after', 'Mon after'),
              ]) ...[
                if (o.$1 != 'none') const SizedBox(width: 6),
                Expanded(
                  child: _chip(
                    ValueKey('entry-shift-${o.$1}'),
                    o.$2,
                    _shift == o.$1,
                    () => setState(() => _shift = o.$1),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: B.page,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _dayHint(r),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: B.soft2,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayCell(int i, ({int day, int? movedFrom})? r) {
    final wd = DateTime(s.year, s.monthIdx + 1, i).weekday;
    final weekend = wd == DateTime.saturday || wd == DateTime.sunday;
    final sel = _day == i;
    final resolved = r != null && _day != null && r.day == i && !sel;
    return GestureDetector(
      key: ValueKey('entry-day-$i'),
      onTap: () => setState(() {
        _day = i;
        _reviewDay = false;
      }),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel
              ? B.primary
              : weekend
              ? const Color(0xfffdf6e3)
              : const Color(0xfff1f5f9),
          borderRadius: BorderRadius.circular(10),
          border: resolved ? Border.all(color: B.primary, width: 1.5) : null,
        ),
        child: Text(
          '$i',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: sel
                ? Colors.white
                : resolved
                ? B.deep
                : B.text,
          ),
        ),
      ),
    );
  }

  String _dayHint(({int day, int? movedFrom})? r) {
    final mn = kMonthsEn[s.monthIdx];
    if (_day == null) {
      return _kind == 'income'
          ? 'Kept off the calendar, by choice — income no longer silently lands on the 1st. Pick a day to put it in the projection.'
          : 'Kept off the calendar — shown in the “unscheduled” bucket and left out of the balance projection.';
    }
    final resolved = r!;
    const wdShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dt = DateTime(s.year, s.monthIdx + 1, resolved.day);
    var line =
        'Posts ${wdShort[dt.weekday - 1]} ${resolved.day} ${kMonthsShortEn[s.monthIdx]}';
    final wdRaw = DateTime(
      s.year,
      s.monthIdx + 1,
      _day!.clamp(1, daysInMonthOf(s.year, s.monthIdx)),
    ).weekday;
    final rawWeekend = wdRaw == DateTime.saturday || wdRaw == DateTime.sunday;
    if (resolved.movedFrom != null) {
      line += ' — the ${ordinal(_day!)} is a weekend';
    } else if (_shift != 'none' && rawWeekend) {
      line += ' — the shift would leave $mn, so it stays put';
    }
    if (_day! > daysInMonthOf(s.year, s.monthIdx)) {
      line += ' (day $_day clamped into $mn)';
    }
    final f = s.flowModel();
    if (resolved.day >= 1 && resolved.day <= f.days.length) {
      line +=
          ' · ≈ ${eur(f.days[resolved.day - 1].bal, cents: false)} projected that day.';
    } else {
      line += '.';
    }
    if (_day! >= 29) line += ' In shorter months it posts on the last day.';
    if (_reviewDay) {
      line =
          'Migrated: this income was kept on the 1st — confirm the day or unschedule it. $line';
    }
    return line;
  }

  /// Repeat tray (#291): One-off/Repeats, monthly cadences only (a disabled
  /// "Weekly · future" pill reserves the space), and the 12-month year strip.
  Widget _trayRepeat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _chip(
                const ValueKey('entry-repeat-off'),
                'One-off',
                !_recurring,
                () => setState(() => _recurring = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _chip(
                const ValueKey('entry-repeat-on'),
                'Repeats',
                _recurring,
                // Toggling back on restores the prior cadence and end —
                // they're preserved, never cleared (#291).
                () => setState(() => _recurring = true),
              ),
            ),
          ],
        ),
        if (_recurring) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final n in const [1, 2, 3, 6, 12])
                _chip(
                  ValueKey('entry-every-$n'),
                  n == 1
                      ? 'Monthly'
                      : n == 12
                      ? 'Yearly'
                      : 'Every $n',
                  _recurEvery == n,
                  () => setState(() => _recurEvery = n),
                ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(color: B.line),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stepBtn(
                      const ValueKey('entry-every-minus'),
                      '−',
                      () => setState(
                        () => _recurEvery = (_recurEvery - 1).clamp(1, 60),
                      ),
                    ),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$_recurEvery',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: B.text,
                        ),
                      ),
                    ),
                    _stepBtn(
                      const ValueKey('entry-every-plus'),
                      '+',
                      () => setState(
                        () => _recurEvery = (_recurEvery + 1).clamp(1, 60),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xffcfd8e3)),
                ),
                child: const Text(
                  'Weekly · future',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: B.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            childAspectRatio: 1.15,
            children: [
              for (int m = _anchorOrd; m < _anchorOrd + 12; m++) _monthCell(m),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Filled months get the bill. Tap a month to end the series there — tap it again to keep it going.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: B.muted,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _endBad ? B.redSoft : B.page,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            entryRecurSummary(
              recurring: _recurring,
              every: _recurEvery,
              day: _day,
              shift: _shift,
              anchorOrd: _anchorOrd,
              endOrd: _endOrd,
            ),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _endBad ? B.red : B.soft2,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  bool get _endBad => _endOrd != null && _endOrd! < _anchorOrd;

  Widget _stepBtn(Key key, String label, VoidCallback onTap) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xfff1f5f9),
          borderRadius: BorderRadius.circular(99),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xff475569),
          ),
        ),
      ),
    );
  }

  Widget _monthCell(int ord) {
    final hit =
        ((ord - _anchorOrd) % _recurEvery == 0) &&
        (_endOrd == null || ord <= _endOrd!);
    final isEnd = _endOrd == ord;
    final ended = _endOrd != null && ord > _endOrd!;
    final name =
        kMonthsShortEn[ord % 12] +
        ((ord == _anchorOrd || ord % 12 == 0) ? ' ’${(ord ~/ 12) % 100}' : '');
    return GestureDetector(
      key: ValueKey('entry-month-$ord'),
      onTap: () => setState(() => _endOrd = _endOrd == ord ? null : ord),
      child: Container(
        decoration: BoxDecoration(
          color: hit
              ? B.soft
              : ended
              ? const Color(0xfffafbfc)
              : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isEnd
                ? B.ink
                : hit
                ? B.primary
                : B.track,
            width: isEnd ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: ended
                    ? const Color(0xffc3ccd6)
                    : hit
                    ? B.deep
                    : B.soft2,
                decoration: ended ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: hit ? B.primary : const Color(0xffe2e7ee),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Account tray (#299): chips from the family's accounts.
  Widget _trayAccount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_accountReassigned)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Text(
              'The original account was deleted — this entry moved to '
              '${s.accByKey(_account).short}.',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: B.amberText,
              ),
            ),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final a in s.accountsForMonth(s.monthIdx))
              _chip(
                ValueKey('entry-acc-${a.key}'),
                a.short,
                _account == a.key,
                () => setState(() {
                  _account = a.key;
                  _accountReassigned = false;
                }),
                leading: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: a.color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    a.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Card tray (#297): family cards, "No card", "Scan new", and the dangling
  /// deleted-card state with an explicit Unlink.
  Widget _trayCard() {
    final cardGone = _cardId != null && s.cards.every((c) => c.id != _cardId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cardGone)
          Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: B.orangeSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xfffed7aa)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'This card was deleted from the wallet.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff9a5b13),
                    ),
                  ),
                ),
                GestureDetector(
                  key: const ValueKey('entry-card-unlink'),
                  onTap: () => setState(() => _cardId = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: B.ink,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Text(
                      'Unlink',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _chip(
              const ValueKey('entry-card-none'),
              'No card',
              _cardId == null,
              () => setState(() => _cardId = null),
            ),
            for (final c in s.cards)
              _chip(
                ValueKey('entry-card-${c.id}'),
                c.name,
                _cardId == c.id,
                () => setState(() => _cardId = c.id),
                leading: Container(
                  width: 16,
                  height: 11,
                  decoration: BoxDecoration(
                    color: c.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            _chip(const ValueKey('entry-card-scan'), '📷 Scan new', false, () {
              Navigator.of(context).pop();
              s.openCardScan();
            }),
          ],
        ),
      ],
    );
  }

  /// Block tray (#294): move the entry — filtered to the same direction.
  Widget _trayBlock() {
    final c = s.compute(s.monthIdx);
    final blocks = c.blocks
        .where((b) => b.isIncome == _block.isIncome)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in blocks)
          _EntryBlockRow(
            key: ValueKey('entry-move-block-${b.key}'),
            block: b,
            selected: b.key == _cat,
            onTap: () => setState(() {
              _cat = b.key;
              if (s._entryKindOf(s.catByKey(b.key)) == 'income') {
                _cardId = null;
              }
            }),
          ),
        Text(
          'Moving recounts both caps from ${kMonthsEn[s.monthIdx]} onward. History stays.',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: B.muted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// One labelled white card in the editor's scroll — the same shape the
  /// event editor, the category editor and the import studio use.
  Widget _section(String id, String title, Widget child, {String? value}) {
    return Container(
      key: ValueKey('entry-section-$id'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: B.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: studioSectionLabel(
                  title,
                  padding: const EdgeInsets.only(bottom: 8),
                ),
              ),
              // The design's per-card value (1b): the card states its own
              // answer next to its label, so the scroll reads as a summary
              // even before you open anything.
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 8),
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: B.deep,
                    ),
                  ),
                ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  /// The day card's own answer: the chosen day, and where a weekend shift
  /// actually lands it.
  String get _dayValue {
    if (_day == null) return 'Unscheduled';
    final r = resolveMoneyDay(_day!, _shift, s.year, s.monthIdx);
    return r.movedFrom != null
        ? '${ordinal(_day!)} → ${ordinal(r.day)}'
        : ordinal(_day!);
  }

  String get _repeatValue => !_recurring
      ? 'One-off'
      : _recurEvery == 1
      ? '↻ Monthly'
      : _recurEvery == 12
      ? '↻ Yearly'
      : '↻ Every $_recurEvery mo';

  String get _cardValue {
    final gone = _cardId != null && s.cards.every((c) => c.id != _cardId);
    if (gone) return '⚠ Card deleted';
    final card = s.cards.where((c) => c.id == _cardId).firstOrNull;
    return card != null ? '💳 ${card.name}' : '+ Card';
  }

  /// The blocked-save reason, shown where the design puts it: just above the
  /// footer, in amber, never as a dead button.
  Widget _reasonNote(String reason) => Container(
    margin: const EdgeInsets.only(top: 4, bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xfffffbeb),
      border: Border.all(color: const Color(0xfffde68a)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      reason,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: B.amberText,
      ),
    ),
  );

  /// Read-only attribution line (#300): "Added by Erik · 12 Aug" or "—".
  Widget _addedBy() {
    final member = s
        .curFamily()
        ?.members
        .where((m) => m.id == _createdBy)
        .firstOrNull;
    final who = member?.name ?? (_createdBy != null ? 'someone' : '—');
    String when = '';
    if (_createdAt != null) {
      final p = _createdAt!.split('-');
      final m = p.length > 1 ? int.tryParse(p[1]) : null;
      final d = p.length > 2 ? int.tryParse(p[2]) : null;
      if (m != null && d != null) when = ' · $d ${kMonthsShortEn[m - 1]}';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (member != null) ...[
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: member.color,
                borderRadius: BorderRadius.circular(99),
              ),
              alignment: Alignment.center,
              child: Text(
                member.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            'Added by $who$when',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: B.soft2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = entryWords(_kind);
    final title = _editing ? 'Edit ${w.noun}' : 'New ${w.noun}';
    final ready = _reason == null && !_closed;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_editing && _recurring && !_closed && !(_item?.exception ?? false))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xffeef6ff),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffd3e5f8)),
            ),
            child: Text(
              'Part of a series — edits apply ${kMonthsEn[s.monthIdx]} onward, never backwards.',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xff1d4ed8),
              ),
            ),
          ),
        _amountCard(),
        _aboutCard(),
        _section('block', 'Budget block', _trayBlock()),
        _section(
          'day',
          '${entryWords(_kind).dayHead} — which day of the month?',
          _trayDay(),
          value: _dayValue,
        ),
        _section(
          'repeat',
          'Does it repeat?',
          _trayRepeat(),
          value: _repeatValue,
        ),
        _section(
          'account',
          entryWords(_kind).accHead,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_trayAccount(), const SizedBox(height: 6), _paidRow()],
          ),
        ),
        if (_kind != 'income')
          _section('card', 'Discount card', _trayCard(), value: _cardValue),
        if (_reason != null && !_closed) _reasonNote(_reason!),
        if (_editing || _createdBy != null) _addedBy(),
        if (_editing && !_closed)
          GestureDetector(
            key: const ValueKey('entry-delete'),
            onTap: _delete,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Text(
                'Remove from the budget…',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: B.red,
                ),
              ),
            ),
          ),
        if (_closed)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xfff1ebdd),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '🔒 ${kMonthsEn[s.monthIdx].toUpperCase()} · CLOSED — this entry is a '
              'snapshot. Reopen the month from Money to edit.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xff7c6a3c),
              ),
            ),
          ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHeadWithTick(
          context,
          title,
          sub: _editing
              ? 'One card per decision'
              : 'One card per decision — nothing hidden',
          onConfirm: _submit,
          confirmEnabled: ready,
        ),
        Flexible(
          child: SingleChildScrollView(
            // Sealed ticket (#298): desaturated and inert; the header's
            // close button stays live so the user can leave.
            child: _closed
                ? Opacity(opacity: .75, child: IgnorePointer(child: body))
                : body,
          ),
        ),
      ],
    );
  }
}

// ================================================= scope sheets (#292/#293)
class _EntryScopeSheet extends StatelessWidget {
  const _EntryScopeSheet({
    required this.state,
    required this.name,
    required this.deleting,
    required this.onScope,
  });
  final _ThriveHomeState state;
  final String name;
  final bool deleting;
  final ValueChanged<String> onScope;

  @override
  Widget build(BuildContext context) {
    final mn = kMonthsEn[state.monthIdx];
    final yr = state.year;
    Widget option(Key key, String label, String sub, String scope) {
      return GestureDetector(
        key: key,
        onTap: () {
          Navigator.of(context).pop();
          onScope(scope);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: deleting ? const Color(0xfffff5f5) : const Color(0xfff8fafc),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: deleting ? B.redLine : B.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: deleting ? B.red : B.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: deleting ? const Color(0xff9b6b6b) : B.soft2,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sheetHead(
          context,
          deleting ? 'Remove “$name”?' : 'Save changes to “$name”?',
          'Past months are history — they never change.',
        ),
        option(
          const ValueKey('entry-scope-month'),
          deleting ? 'Skip $mn only' : 'Only $mn $yr',
          deleting
              ? 'The series continues next time.'
              : '$mn becomes an exception; the series stays as it was.',
          deleting ? 'skip' : 'month',
        ),
        option(
          const ValueKey('entry-scope-onward'),
          deleting ? '$mn onward — end the series' : '$mn $yr onward',
          deleting
              ? 'Earlier months stay in the books.'
              : 'Rewrites this and future months. Earlier months stay as they were.',
          'onward',
        ),
        GestureDetector(
          key: const ValueKey('entry-scope-cancel'),
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xfff1f5f9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Keep it as it is',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xff475569),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
