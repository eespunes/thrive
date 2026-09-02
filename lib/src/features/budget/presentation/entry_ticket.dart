part of 'package:family_money_management_app/main.dart';

/// The money entry ticket editor (epic: replace `_ExpenseSheet`), mirroring
/// `Finance entry options.dc.html` option 1b: the editor's top half IS the
/// entry — a WYSIWYG ticket card whose block chip, badges, amount, account
/// and card are all tappable — and one tray below edits whichever element
/// was tapped. Same visual grammar as the calendar ticket editor (#286).

const List<String> _kEntryTrays = ['block', 'day', 'repeat', 'account', 'card'];

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

  String _tray = 'day';

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

  void _openTray(String tray) {
    if (!_kEntryTrays.contains(tray) || _tray == tray) return;
    setState(() => _tray = tray);
    logAnalyticsEvent('entry_tray_opened', {'tray': tray});
  }

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

  /// A small ticket badge, same grammar as the calendar ticket's `_badge`.
  Widget _badge(
    Key key,
    String label,
    VoidCallback onTap, {
    Color? fg,
    Color? bg,
    Color? borderCol,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg ?? const Color(0xfff8fafc),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderCol ?? B.line),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: fg ?? B.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ticket() {
    final w = entryWords(_kind);
    final b = _block;
    final cap = _capInfo;
    final acc = s.accByKey(_account);
    final cardGone = _cardId != null && s.cards.every((c) => c.id != _cardId);
    final card = s.cards.where((c) => c.id == _cardId).firstOrNull;
    final r = _day == null
        ? null
        : resolveMoneyDay(_day!, _shift, s.year, s.monthIdx);
    final dayBadge = _day == null
        ? 'Unscheduled'
        : r!.movedFrom != null
        ? '${ordinal(_day!)} → ${ordinal(r.day)}'
        : ordinal(_day!);
    final repeatBadge = !_recurring
        ? 'One-off'
        : _recurEvery == 1
        ? '↻ Monthly'
        : _recurEvery == 12
        ? '↻ Yearly'
        : '↻ Every $_recurEvery mo';
    final amountLen = _amount.text.length;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: B.line),
            boxShadow: cardShadow(),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border(top: BorderSide(color: b.tone, width: 6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // Block chip — reopens the picker anytime = move (#294).
                  GestureDetector(
                    key: const ValueKey('entry-tab-block'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openTray('block'),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: b.tone.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: b.tone,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              b.title,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: b.tone,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _badge(
                    const ValueKey('entry-badge-repeat'),
                    repeatBadge,
                    () => _openTray('repeat'),
                  ),
                  const SizedBox(width: 6),
                  _badge(
                    const ValueKey('entry-badge-day'),
                    dayBadge,
                    () => _openTray('day'),
                  ),
                ],
              ),
              // Hero amount (#287) — shrinks for very large amounts.
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Row(
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
              ),
              if (entryAmountError(_amount.text) != null &&
                  _amount.text.trim().isNotEmpty)
                Text(
                  entryAmountError(_amount.text)!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: B.red,
                  ),
                ),
              TextField(
                key: const ValueKey('entry-payee'),
                controller: _payee,
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: w.payeePh,
                ),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                  color: B.ink,
                ),
              ),
              const SizedBox(height: 2),
              TextField(
                key: const ValueKey('entry-label'),
                controller: _label,
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Note or subcategory',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: B.soft2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('entry-tab-account'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openTray('account'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: acc.color,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          alignment: Alignment.center,
                          child: glyphTile(
                            size: 22,
                            radius: 99,
                            picture: acc.picture,
                            emoji: acc.emoji,
                            emojiSize: 12,
                            fallback: Text(
                              acc.initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${w.accHead} ${acc.short}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Card badge hidden for income (#286).
                  if (_kind != 'income')
                    _badge(
                      const ValueKey('entry-badge-card'),
                      cardGone
                          ? '⚠ Card deleted'
                          : card != null
                          ? '💳 ${card.name}'
                          : '+ Card',
                      () => _openTray('card'),
                      fg: cardGone ? const Color(0xff9a5b13) : null,
                      bg: cardGone ? B.orangeSoft : null,
                      borderCol: cardGone ? const Color(0xfffed7aa) : null,
                    ),
                ],
              ),
              // Perforation with the live cap meter (#287).
              Container(
                margin: const EdgeInsets.only(top: 11),
                padding: const EdgeInsets.fromLTRB(0, 9, 0, 9),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Color(0xffe2e7ee),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (_capInfo.show) ...[
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
                      Text(
                        cap.short,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: cap.col,
                        ),
                      ),
                    ] else if (cap.alt != null)
                      Expanded(
                        child: Text(
                          cap.alt!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: B.muted,
                          ),
                        ),
                      ),
                    const Spacer(),
                    const Text(
                      'THRIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: Color(0xffcbd5e1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Paid stamp (#296): dashed "Mark paid" → solid rotated "PAID ✓".
        Positioned(
          top: 44,
          right: 14,
          child: Transform.rotate(
            angle: 6 * math.pi / 180,
            child: GestureDetector(
              key: const ValueKey('entry-stamp'),
              onTap: () {
                if (s.isClosed()) {
                  s.flash(
                    '${kMonthsEn[s.monthIdx]} is closed — the flag can’t change',
                  );
                  return;
                }
                setState(() => _paid = !_paid);
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 34),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _paid ? const Color(0xfff0fdf4) : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: _paid
                        ? const Color(0xff16a34a)
                        : const Color(0xffcbd5e1),
                    width: 2,
                    style: _paid ? BorderStyle.solid : BorderStyle.none,
                  ),
                ),
                foregroundDecoration: _paid
                    ? null
                    : BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: const Color(0xffcbd5e1),
                          width: 2,
                        ),
                      ),
                child: Text(
                  _paid
                      ? '${entryWords(_kind).paid.toUpperCase()} ✓'
                      : 'Mark ${entryWords(_kind).paid.toLowerCase()}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                    color: _paid
                        ? const Color(0xff16a34a)
                        : B.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
        // The sealed stamp (#298).
        if (_closed)
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: -5 * math.pi / 180,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xfffffdf5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xffb8a262),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '${kMonthsEn[s.monthIdx].toUpperCase()} · CLOSED',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: Color(0xff8a7538),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
              _tray = 'day';
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

  Widget _tray_() {
    final w = entryWords(_kind);
    final child = switch (_tray) {
      'repeat' => _trayRepeat(),
      'account' => _trayAccount(),
      'card' => _trayCard(),
      'block' => _trayBlock(),
      _ => _trayDay(),
    };
    final titles = {
      'day': '${w.dayHead} — which day of the month?',
      'repeat': 'Does it repeat?',
      'account': w.accHead,
      'card': 'Discount card',
      'block': 'Block',
    };
    final reason = _reason;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: B.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titles[_tray]!.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
              color: B.muted,
            ),
          ),
          const SizedBox(height: 10),
          child,
          if (reason != null && !_closed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: B.amberText,
                ),
              ),
            ),
        ],
      ),
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
        _ticket(),
        _tray_(),
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
              '🔒 ${kMonthsEn[s.monthIdx]} is closed — this ticket is a snapshot. Reopen the month from Money to edit.',
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
          sub: _editing ? null : 'Tap the ticket to shape it',
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
