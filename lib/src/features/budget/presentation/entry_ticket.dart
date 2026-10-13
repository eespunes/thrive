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
    if (childBlocked('Money isn’t available on a kid profile')) return;
    if (cat == null) {
      // Block-less launches (quick add, Money-calendar day) open on the
      // first expense block; the editor's kind + block chips change it.
      final blocks = compute(monthIdx).blocks;
      final first =
          blocks
              .where((b) => _entryKindOf(catByKey(b.key)) == 'expense')
              .firstOrNull ??
          blocks.firstOrNull;
      if (first == null) {
        flash('Add a budget block first');
        return;
      }
      cat = first.key;
    }
    final block = cat;
    openEditorSheet<void>(
      monthScoped: true,
      (ctx) => _EntryTicketSheet(
        state: this,
        cat: block,
        id: id,
        presetDay: presetDay,
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

  // -------------------------------------------------------------- editor

  static const _kindSign = {'expense': '−', 'income': '+', 'savings': '→'};

  /// Expense / Income / Savings: the kind IS the block's direction, so
  /// switching kind moves the entry to a block of that kind (keeping the
  /// current one when it already matches). Income never carries a card.
  void _setKind(String kind) {
    if (kind == _kind) return;
    final blocks = s
        .compute(s.monthIdx)
        .blocks
        .where((b) => s._entryKindOf(s.catByKey(b.key)) == kind)
        .toList();
    if (blocks.isEmpty) {
      s.flash('No ${entryWords(kind).noun} block yet — add one in Settings');
      return;
    }
    setState(() {
      _cat = blocks.first.key;
      if (kind == 'income') _cardId = null;
    });
  }

  Widget _amountHero() {
    final n = parseEntryAmount(_amount.text);
    final err = _amount.text.trim().isEmpty
        ? null
        : entryAmountError(_amount.text);
    final tone = n == null
        ? B.amountEmpty
        : _kind == 'income'
        ? B.green
        : B.ink;
    final cap = _capInfo;
    final capLine = cap.show ? cap.short : cap.alt;
    return Column(
      children: [
        edBigAmount(
          key: const ValueKey('entry-amount'),
          controller: _amount,
          prefix: _kindSign[_kind]!,
          color: tone,
          onChanged: (_) => setState(() {}),
          caption: err ?? 'Amount in euros',
          captionColor: err != null ? B.red : B.muted,
        ),
        if (err == null && capLine != null && capLine.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              capLine,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cap.show ? cap.col : B.muted,
              ),
            ),
          ),
      ],
    );
  }

  Widget _what() {
    final w = entryWords(_kind);
    return EdSection(
      label: 'What is it?',
      hint: 'One of the two is enough',
      child: edGroup([
        edBareInput(
          key: const ValueKey('entry-payee'),
          controller: _payee,
          hint: w.payeePh,
          capitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        edBareInput(
          key: const ValueKey('entry-label'),
          controller: _label,
          hint: 'Note or subcategory',
          capitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
      ]),
    );
  }

  Widget _blockChips() {
    final blocks = s
        .compute(s.monthIdx)
        .blocks
        .where((b) => s._entryKindOf(s.catByKey(b.key)) == _kind)
        .toList();
    return EdSection(
      label: 'Budget block',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          edChipWrap([
            for (final b in blocks)
              edChip(
                key: ValueKey('entry-move-block-${b.key}'),
                label: b.title,
                selected: b.key == _cat,
                tone: b.tone,
                leading: b.emoji != null && b.emoji!.isNotEmpty
                    ? Text(b.emoji!, style: const TextStyle(fontSize: 14))
                    : null,
                onTap: () => setState(() => _cat = b.key),
              ),
          ]),
          if (_editing && _cat != widget.cat)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Moving recounts both caps from ${kMonthsEn[s.monthIdx]} '
                'onward. History stays.',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: B.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- details

  /// Which Details row is open (one at a time).
  String? _open;
  bool _openInit = false;

  static const _wdShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _fmtDay(int d) {
    final dt = DateTime(s.year, s.monthIdx + 1, d);
    return '${_wdShort[dt.weekday - 1]} $d ${kMonthsShortEn[s.monthIdx]}';
  }

  bool _isWeekend(int d) {
    final wd = DateTime(s.year, s.monthIdx + 1, d).weekday;
    return wd == DateTime.saturday || wd == DateTime.sunday;
  }

  String get _dayValue {
    if (_day == null) return 'Unscheduled';
    final dim = daysInMonthOf(s.year, s.monthIdx);
    final d = _day!.clamp(1, dim);
    final r = resolveMoneyDay(_day!, _shift, s.year, s.monthIdx);
    return r.movedFrom != null
        ? 'The ${ordinal(_day!)} · moves to ${_fmtDay(r.day)}'
        : 'The ${ordinal(_day!)} · ${_fmtDay(d)}';
  }

  String get _everyText => _recurEvery == 1
      ? 'every month'
      : _recurEvery == 12
      ? 'every year'
      : 'every $_recurEvery months';

  String get _repeatValue {
    if (!_recurring) return 'One-off — only this ${kMonthsEn[s.monthIdx]}';
    final end = _endOrd == null || _endBad
        ? ''
        : ' · until ${kMonthsShortEn[_endOrd! % 12]} ${_endOrd! ~/ 12}';
    return 'Repeats $_everyText$end';
  }

  String get _accountValue {
    final w = entryWords(_kind);
    final a = s.accountsForMonth(s.monthIdx).where((x) => x.key == _account);
    final name = a.isEmpty ? '—' : a.first.name;
    return '$name · ${_paid ? w.paid : w.unpaid}';
  }

  String get _cardValue {
    final gone = _cardId != null && s.cards.every((c) => c.id != _cardId);
    if (gone) return 'Card deleted';
    final card = s.cards.where((c) => c.id == _cardId).firstOrNull;
    return card?.name ?? 'No card';
  }

  Widget _detailRow({
    required String id,
    required String icon,
    required String label,
    required String value,
    required bool valueSet,
    required Widget tray,
    bool divider = false,
    Color? valueColor,
  }) {
    final open = _open == id;
    return Container(
      decoration: BoxDecoration(
        color: open ? B.rowOpen : Colors.white,
        border: divider ? const Border(top: BorderSide(color: B.line)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            key: ValueKey('entry-section-$id'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = open ? null : id),
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: B.soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ic(icon, size: 16, sw: 2.1, color: B.deep),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: B.ink,
                          ),
                        ),
                        Text(
                          value,
                          key: ValueKey('entry-value-$id'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color:
                                valueColor ??
                                (valueSet ? B.soft2 : B.placeholder),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? .5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: ic('cdown', size: 16, sw: 2.2, color: B.placeholder),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 14),
              child: tray,
            ),
        ],
      ),
    );
  }

  Widget _note(String text, {Color bg = B.page, Color fg = B.soft2}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: fg,
            height: 1.45,
          ),
        ),
      );

  /// Day tray (#288): a real month calendar (Mon-first, weekends muted),
  /// the weekend question (#289) and an explicit Unscheduled chip.
  Widget _trayDay() {
    final dim = daysInMonthOf(s.year, s.monthIdx);
    final lead = DateTime(s.year, s.monthIdx + 1, 1).weekday - 1;
    final r = _day == null
        ? null
        : resolveMoneyDay(_day!, _shift, s.year, s.monthIdx);
    final d = _day?.clamp(1, dim);
    final weekend = d != null && _isWeekend(d);
    final shiftChips = edChipWrap([
      for (final o in [
        ('none', 'Keep the ${ordinal(_day ?? 1)}'),
        ('before', 'Friday before'),
        ('after', 'Monday after'),
      ])
        edChip(
          key: ValueKey('entry-shift-${o.$1}'),
          label: o.$2,
          small: true,
          selected: _shift == o.$1,
          tone: B.amber,
          onTap: () => setState(() => _shift = o.$1),
        ),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final h in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Text(
                  h,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: B.muted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 1.15,
          children: [
            for (int i = 0; i < lead; i++) const SizedBox.shrink(),
            for (int i = 1; i <= dim; i++) _dayCell(i, r),
          ],
        ),
        const SizedBox(height: 8),
        if (_day != null) ...[
          if (weekend)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: B.amberSoft,
                border: Border.all(color: B.amberLine),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The ${ordinal(_day!)} is a '
                    '${DateTime(s.year, s.monthIdx + 1, d).weekday == DateTime.saturday ? 'Saturday' : 'Sunday'}. '
                    'Should it move?',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: B.amberText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  shiftChips,
                ],
              ),
            )
          else ...[
            const Text(
              'If it lands on a weekend in other months',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: B.muted,
              ),
            ),
            const SizedBox(height: 6),
            shiftChips,
          ],
          const SizedBox(height: 8),
        ],
        edSoftChip(
          key: const ValueKey('entry-day-unscheduled'),
          label: _day == null
              ? '✓ Unscheduled — off the calendar'
              : 'Unscheduled — keep it off the calendar',
          selected: _day == null,
          expand: true,
          onTap: () => setState(() {
            _day = _day == null ? 1 : null;
            _reviewDay = false;
          }),
        ),
        const SizedBox(height: 8),
        _note(_dayHint(r)),
      ],
    );
  }

  Widget _dayCell(int i, ({int day, int? movedFrom})? r) {
    final sel = _day == i;
    final resolved = r != null && _day != null && r.day == i && !sel;
    return GestureDetector(
      key: ValueKey('entry-day-$i'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _day = i;
        _reviewDay = false;
      }),
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? B.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: resolved ? Border.all(color: B.primary, width: 1.5) : null,
          ),
          child: Text(
            '$i',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: sel
                  ? Colors.white
                  : resolved
                  ? B.deep
                  : _isWeekend(i)
                  ? B.placeholder
                  : B.ink,
            ),
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
    final dt = DateTime(s.year, s.monthIdx + 1, resolved.day);
    var line =
        'Posts ${_wdShort[dt.weekday - 1]} ${resolved.day} ${kMonthsShortEn[s.monthIdx]}';
    final rawWeekend = _isWeekend(
      _day!.clamp(1, daysInMonthOf(s.year, s.monthIdx)),
    );
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

  /// Repeat tray (#291): One-off/Repeats, the cadence chips and the last
  /// month as a scrolling chip row (Never + the next 12 months).
  Widget _trayRepeat() {
    const cadences = [
      (1, 'Monthly'),
      (2, 'Every 2 months'),
      (3, 'Every 3 months'),
      (12, 'Yearly'),
    ];
    final custom = cadences.every((c) => c.$1 != _recurEvery);
    final endChoices = [for (int i = 1; i <= 12; i++) _anchorOrd + i];
    final endExtra = _endOrd != null && !endChoices.contains(_endOrd)
        ? _endOrd
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: edSoftChip(
                key: const ValueKey('entry-repeat-off'),
                label: 'One-off',
                selected: !_recurring,
                expand: true,
                onTap: () => setState(() => _recurring = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: edSoftChip(
                key: const ValueKey('entry-repeat-on'),
                label: 'Repeats',
                selected: _recurring,
                expand: true,
                // Toggling back on restores the prior cadence and end —
                // they're preserved, never cleared (#291).
                onTap: () => setState(() => _recurring = true),
              ),
            ),
          ],
        ),
        if (_recurring) ...[
          const SizedBox(height: 10),
          edChipWrap([
            for (final c in cadences)
              edChip(
                key: ValueKey('entry-every-${c.$1}'),
                label: c.$2,
                small: true,
                selected: _recurEvery == c.$1,
                onTap: () => setState(() => _recurEvery = c.$1),
              ),
            if (custom)
              edChip(
                key: ValueKey('entry-every-$_recurEvery'),
                label: 'Every $_recurEvery months',
                small: true,
                selected: true,
                onTap: () {},
              ),
          ]),
          const SizedBox(height: 12),
          const Text(
            'LAST MONTH',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
              color: B.muted,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final ord in <int?>[null, ?endExtra, ...endChoices]) ...[
                  edChip(
                    key: ValueKey('entry-month-${ord ?? 'never'}'),
                    label: ord == null
                        ? 'Never'
                        : '${kMonthsShortEn[ord % 12]} ${ord ~/ 12}',
                    small: true,
                    selected: _endOrd == ord,
                    onTap: () => setState(() => _endOrd = ord),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        _note(
          entryRecurSummary(
            recurring: _recurring,
            every: _recurEvery,
            day: _day,
            shift: _shift,
            anchorOrd: _anchorOrd,
            endOrd: _endOrd,
          ),
          bg: _endBad ? B.redSoft : B.page,
          fg: _endBad ? B.red : B.soft2,
        ),
      ],
    );
  }

  bool get _endBad => _endOrd != null && _endOrd! < _anchorOrd;

  /// Account tray (#299): the family's accounts and the paid toggle.
  Widget _trayAccount() {
    final w = entryWords(_kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        edChipWrap([
          for (final a in s.accountsForMonth(s.monthIdx))
            edChip(
              key: ValueKey('entry-acc-${a.key}'),
              label: a.name,
              selected: _account == a.key,
              tone: a.color,
              leading: a.emoji != null && a.emoji!.isNotEmpty
                  ? Text(a.emoji!, style: const TextStyle(fontSize: 14))
                  : null,
              onTap: () => setState(() {
                _account = a.key;
                _accountReassigned = false;
              }),
            ),
        ]),
        const SizedBox(height: 10),
        edToggleRow(
          key: const ValueKey('entry-stamp'),
          label: 'Mark ${w.paid.toLowerCase()}',
          sub: _paid ? '${w.paid} — it counts as settled' : 'Not yet settled',
          value: _paid,
          onTap: () {
            if (_closed) {
              s.flash(
                '${kMonthsEn[s.monthIdx]} is closed — the flag can\u2019t change',
              );
              return;
            }
            setState(() => _paid = !_paid);
          },
        ),
      ],
    );
  }

  /// Card tray (#297): family cards, "No card", "Scan new", and the dangling
  /// deleted-card state with an explicit Unlink.
  Widget _trayCard() {
    final cardGone = _cardId != null && s.cards.every((c) => c.id != _cardId);
    Widget dot(Color c) => Container(
      width: 16,
      height: 11,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(3),
      ),
    );
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
              border: Border.all(color: B.amberLine),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'This card was deleted from the wallet.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: B.orangeText,
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
        edChipWrap([
          edChip(
            key: const ValueKey('entry-card-none'),
            label: 'No card',
            selected: _cardId == null,
            leading: dot(B.barTrack),
            onTap: () => setState(() => _cardId = null),
          ),
          for (final c in s.cards)
            edChip(
              key: ValueKey('entry-card-${c.id}'),
              label: c.name,
              selected: _cardId == c.id,
              leading: dot(c.color),
              onTap: () => setState(() => _cardId = c.id),
            ),
          edChip(
            key: const ValueKey('entry-card-scan'),
            label: '📷 Scan new',
            selected: false,
            onTap: () {
              Navigator.of(context).pop();
              s.openCardScan();
            },
          ),
        ]),
      ],
    );
  }

  Widget _details() {
    final w = entryWords(_kind);
    final cardGone = _cardId != null && s.cards.every((c) => c.id != _cardId);
    return EdSection(
      label: 'Details',
      child: edGroup([
        _detailRow(
          id: 'day',
          icon: 'cal',
          label: w.dayHead,
          value: _dayValue,
          valueSet: _day != null,
          tray: _trayDay(),
        ),
        _detailRow(
          id: 'repeat',
          icon: 'repeat',
          label: 'Repeat',
          value: _repeatValue,
          valueSet: true,
          tray: _trayRepeat(),
          valueColor: _endBad ? B.red : null,
        ),
        _detailRow(
          id: 'account',
          icon: 'wallet',
          label: w.accHead,
          value: _accountValue,
          valueSet: true,
          tray: _trayAccount(),
        ),
        if (_kind != 'income')
          _detailRow(
            id: 'card',
            icon: 'card',
            label: 'Discount card',
            value: _cardValue,
            valueSet: _cardId != null,
            tray: _trayCard(),
            valueColor: cardGone ? B.orangeText : null,
          ),
      ]),
    );
  }

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (member != null) ...[
          s.editorAvatar(member, 20),
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
    );
  }

  String get _summary {
    final n = parseEntryAmount(_amount.text);
    final amt = n != null && !n.isNaN && n > 0 ? n : 0.0;
    return '${_kindSign[_kind]} ${eur(amt)} · ${_block.title} · '
        '${_day == null ? 'unscheduled' : 'the ${ordinal(_day!)}'} · '
        '${_recurring ? _everyText : 'one-off'}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_openInit) {
      _openInit = true;
      _open = _editing ? null : 'day';
    }
    final w = entryWords(_kind);
    final reason = _closed
        ? '${kMonthsEn[s.monthIdx]} is closed'
        : _reason?.replaceFirst(RegExp(r'\.$'), '');
    final form = <Widget>[
      EdSegmented<String>(
        keyPrefix: 'entry-kind',
        options: const [
          ('expense', 'Expense'),
          ('income', 'Income'),
          ('savings', 'Savings'),
        ],
        value: _kind,
        onChanged: _setKind,
      ),
      if (_editing && _recurring && !_closed && !(_item?.exception ?? false))
        edNotice(
          'Part of a series — edits apply ${kMonthsEn[s.monthIdx]} onward, '
          'never backwards.',
          bg: B.infoSoft,
          fg: B.infoText,
          border: B.infoLine,
        ),
      _amountHero(),
      _what(),
      _blockChips(),
      _details(),
      if (_editing || _createdBy != null) _addedBy(),
    ];
    return EditorSheet(
      title: _editing ? 'Edit ${w.noun}' : 'New ${w.noun}',
      subtitle: '${kMonthsEn[s.monthIdx]} ${s.year}',
      summary: _summary,
      confirmLabel: _editing ? 'Save changes' : 'Add ${w.noun}',
      blockedReason: reason,
      onConfirm: _submit,
      deleteLabel: _editing && !_closed ? 'Remove from the budget…' : null,
      onDelete: _delete,
      confirmKey: const ValueKey('sheet-confirm'),
      deleteKey: const ValueKey('entry-delete'),
      children: _closed
          ? [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: B.amberSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🔒 ${kMonthsEn[s.monthIdx].toUpperCase()} · CLOSED — this '
                  'entry is a snapshot. Reopen the month from Money to edit.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: B.amberText,
                  ),
                ),
              ),
              // Sealed (#298): desaturated and inert; Cancel stays live.
              Opacity(
                opacity: .75,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final f in form) ...[f, const SizedBox(height: 18)],
                    ],
                  ),
                ),
              ),
            ]
          : form,
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
