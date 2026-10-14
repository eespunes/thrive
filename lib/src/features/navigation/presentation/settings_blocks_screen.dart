part of 'package:family_money_management_app/main.dart';

/// Budget blocks sub-screen + block studio (#329, `Settings v2.dc.html`):
/// one row per block ("Withdraws/Receives · limit € N · counts as savings",
/// amber "Aug 2026 only" value), hold-and-drag reorder, add-then-open, plus
/// the "Warn near block limits" toggle (nudge at 90% of a budget).
extension _ThriveBlocksScreen on _ThriveHomeState {
  void openBudgetBlocksScreen() {
    pushSettingsPage<void>((_) => _BudgetBlocksScreen(state: this));
  }

  void reorderBlocks(int from, int to) {
    mutate(() {
      final c = cats.removeAt(from);
      cats.insert(to, c);
    });
  }

  void toggleBudgetLimitWarn() {
    mutate(
      () => budgetLimitWarn = !budgetLimitWarn,
      () => flash(
        budgetLimitWarn
            ? 'You’ll get a nudge at 90% of a budget'
            : 'Limit warnings off',
      ),
    );
  }

  /// The 90%-of-cap nudge (#329): called after an entry save; toasts when
  /// the block's planned total crosses 90% of this month's cap.
  void maybeWarnNearBlockLimit(String catKey) {
    if (!budgetLimitWarn) return;
    final m = cur();
    final cap = m?.caps[catKey];
    if (m == null || cap == null || cap <= 0) return;
    final total = (m.blocks[catKey] ?? const <ExpenseItem>[]).fold<double>(
      0,
      (acc, it) => acc + it.amount,
    );
    if (total < cap * 0.9) return;
    final cat = catByKey(catKey);
    final pct = (total / cap * 100).round();
    flash('⚠ ${cat?.title ?? 'Block'} is at $pct% of its ${eur(cap)} limit');
  }

  /// Counts this workspace's open-month entries inside block [key].
  int entriesInBlock(String key) {
    var n = 0;
    for (final yr in data.keys) {
      for (final mk in kMonthKeys) {
        final m = data[yr]![mk];
        if (m == null || m.closed) continue;
        n += (m.blocks[key] ?? const <ExpenseItem>[]).length;
      }
    }
    return n;
  }

  /// The block entries migrate into when [key] is deleted: the first
  /// remaining block with the same money direction, else the first remaining.
  Category? blockDeleteFallback(String key) {
    final cat = catByKey(key);
    final remaining = cats.where((c) => c.key != key).toList();
    if (remaining.isEmpty) return null;
    return remaining
            .where((c) => c.isIncome == (cat?.isIncome ?? false))
            .firstOrNull ??
        remaining.first;
  }

  /// Deletes block [key], moving its open-month entries into
  /// [blockDeleteFallback] — closed months keep their history (#329
  /// "its entries move elsewhere", vs. the legacy sheet which dropped them).
  void deleteBlockMigrating(String key) {
    if (cats.length <= 1) return;
    final fallback = blockDeleteFallback(key);
    if (fallback == null) return;
    update(() => cats.removeWhere((c) => c.key == key));
    _persist();
    mutate(() {
      for (final yr in data.keys) {
        for (final mk in kMonthKeys) {
          final m = data[yr]![mk];
          if (m == null || m.closed) continue;
          final moving = m.blocks.remove(key);
          if (moving != null && moving.isNotEmpty) {
            m.blocks
                .putIfAbsent(fallback.key, () => <ExpenseItem>[])
                .addAll(moving);
          }
          m.caps.remove(key);
        }
      }
    }, () => flash('Block deleted — entries moved to ${fallback.title}'));
  }
}

class _BudgetBlocksScreen extends StatelessWidget {
  const _BudgetBlocksScreen({required this.state});
  final _ThriveHomeState state;

  String _subFor(_ThriveHomeState s, Category c) {
    final cap = s.cur()?.caps[c.key];
    return [
      c.isIncome ? 'Receives' : 'Withdraws',
      if (!c.isIncome && cap != null && cap > 0) 'limit ${eur(cap)}',
      if (c.isSavings) 'counts as savings',
    ].join(' · ');
  }

  String _valFor(Category c) {
    final applies = c.temporary
        ? '${kMonthsShort[c.ownerMonthIdx ?? 0]} ${c.ownerYear ?? ''} only'
        : 'Every month';
    return c.hasUntil ? '$applies · end dates' : applies;
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) => SettingsSubScreen(
        sync: s.syncStatus,
        offline: s.netOffline,
        title: 'Budget blocks',
        subtitle: 'The columns of the monthly budget',
        intro:
            'The columns of the monthly budget — hold a row and drag to '
            'rearrange, tap to edit.',
        addPlaceholder: 'New block name…',
        emptyAddHint: 'Type a name first',
        onToast: s.flash,
        onAdd: (name) {
          s.saveBlock(
            'add',
            null,
            title: name,
            icon: 'folder',
            tone: kCatPalette[s.cats.length % kCatPalette.length],
            hasUntil: false,
            temporary: false,
            capRaw: '',
          );
          final c = s.cats.lastOrNull;
          if (c == null) return;
          s.openEditorSheet<void>(
            (_) => _BlockStudio(state: s, blockKey: c.key),
          );
        },
        children: [
          HoldDragList(
            itemCount: s.cats.length,
            onReorder: s.reorderBlocks,
            onToast: s.flash,
            itemBuilder: (context, i) {
              final c = s.cats[i];
              return SettingsListRow(
                rowKey: ValueKey('blocks-row-${c.key}'),
                leading: settingsBadgeTile(
                  color: c.tone,
                  picture: c.picture,
                  emoji: c.emoji,
                  icon: c.icon,
                ),
                label: c.title,
                sub: _subFor(s, c),
                value: _valFor(c),
                warnVal: c.temporary,
                onTap: () => s.openEditorSheet<void>(
                  (_) => _BlockStudio(state: s, blockKey: c.key),
                ),
              );
            },
          ),
          SettingsListRow(
            rowKey: const ValueKey('blocks-warn-toggle'),
            label: 'Warn near block limits',
            sub: 'A nudge at 90% of a budget',
            toggle: s.budgetLimitWarn,
            onToggle: s.toggleBudgetLimitWarn,
          ),
        ],
      ),
    );
  }
}

/// Full-screen block editor (badge studio): money direction, applies-to,
/// optional monthly limit, end-date & savings toggles, badge, colour.
class _BlockStudio extends StatefulWidget {
  const _BlockStudio({required this.state, required this.blockKey});
  final _ThriveHomeState state;
  final String blockKey;

  @override
  State<_BlockStudio> createState() => _BlockStudioState();
}

class _BlockStudioState extends State<_BlockStudio> {
  late String _title;
  String? _emoji;
  String? _picture;
  late Color _tone;
  late bool _isIncome;
  late bool _temporary;
  late bool _hasUntil;
  late bool _isSavings;
  late final TextEditingController _cap;
  late String _icon;

  _ThriveHomeState get s => widget.state;

  Category? get _cat =>
      s.cats.where((c) => c.key == widget.blockKey).firstOrNull;

  @override
  void initState() {
    super.initState();
    final c = _cat;
    _title = c?.title ?? '';
    _emoji = c?.emoji;
    _picture = c?.picture;
    _tone = c?.tone ?? kCatPalette.first;
    _isIncome = c?.isIncome ?? false;
    _temporary = c?.temporary ?? false;
    _hasUntil = c?.hasUntil ?? false;
    _isSavings = c?.isSavings ?? false;
    final cap = s.cur()?.caps[widget.blockKey];
    _cap = TextEditingController(
      text: cap == null || cap <= 0 ? '' : cap.toStringAsFixed(0),
    );
    _icon = c?.icon ?? 'folder';
  }

  @override
  void dispose() {
    _cap.dispose();
    super.dispose();
  }

  void _save() {
    s.saveBlock(
      'edit',
      widget.blockKey,
      title: _title,
      icon: _icon,
      tone: _tone,
      hasUntil: !_isIncome && _hasUntil,
      temporary: _temporary,
      capRaw: _isIncome ? '' : _cap.text.trim(),
      emoji: _emoji,
      picture: _picture,
      isIncome: _isIncome,
      isSavings: !_isIncome && _isSavings,
    );
    Navigator.of(context).maybePop();
  }

  void _delete() {
    final c = _cat;
    if (c == null) return;
    final n = s.entriesInBlock(c.key);
    final fallback = s.blockDeleteFallback(c.key);
    showCountingConfirmSheet(
      context,
      title: 'Delete ${c.title}?',
      message: n == 0
          ? 'It has no entries in open months. Closed months keep their '
                'history.'
          : 'Its $n open-month entr${n == 1 ? 'y' : 'ies'} move to '
                '${fallback?.title ?? 'another block'}. Closed months keep '
                'their history.',
      confirmLabel: 'Delete block',
      onConfirm: () {
        s.deleteBlockMigrating(c.key);
        Navigator.of(context).maybePop();
      },
    );
  }

  String get _monthLabel {
    final c = _cat;
    final mIdx = (c?.temporary ?? false)
        ? (c!.ownerMonthIdx ?? s.monthIdx)
        : s.monthIdx;
    final yr = (c?.temporary ?? false) ? (c!.ownerYear ?? s.year) : s.year;
    return '${kMonthsEn[mIdx]} $yr';
  }

  bool get _capInvalid {
    final t = _cap.text.trim();
    return !_isIncome && t.isNotEmpty && !RegExp(r'^\d[\d.,\s]*$').hasMatch(t);
  }

  String get _summary {
    final cap = _isIncome || _capInvalid ? 0.0 : parseNum(_cap.text);
    return '${_isIncome ? 'Receives money' : 'Withdraws money'} · '
        '${_temporary ? '${kMonthsEn[s.monthIdx]} only' : 'every month'}'
        '${cap > 0 ? ' · limit ${eur(cap)}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = s.cats.length > 1;
    return EditorSheet(
      title: 'Edit block',
      summary: _summary,
      confirmLabel: 'Save block',
      blockedReason: _title.trim().isEmpty
          ? 'Give it a name first'
          : (_capInvalid ? 'Limit: numbers only' : null),
      onConfirm: _save,
      deleteLabel: canDelete
          ? 'Delete block — its entries move elsewhere'
          : null,
      onDelete: canDelete ? _delete : null,
      confirmKey: const ValueKey('studio-save'),
      deleteKey: const ValueKey('studio-delete'),
      children: [
        EdBadgeHeader(
          color: _tone,
          name: _title,
          onName: (v) => setState(() => _title = v),
          picks: kEditorPicks['block']!,
          emoji: _emoji,
          picture: _picture,
          fallbackFace: '📦',
          namePlaceholder: 'Name it… e.g. Kids',
          onEmoji: (g) => setState(() {
            _emoji = g;
            _picture = null;
          }),
          onPickPhoto: () async {
            final p = await s.pickBadgePhoto();
            if (p != null && mounted) setState(() => _picture = p);
          },
          onToast: s.flash,
        ),
        EdSection(
          label: 'Money direction',
          child: Row(
            children: [
              Expanded(
                child: edChoiceTile(
                  key: const ValueKey('block-dir-out'),
                  leading: const Text('🛒', style: TextStyle(fontSize: 20)),
                  label: 'Withdraws',
                  sub: 'Costs & payments',
                  selected: !_isIncome,
                  onTap: () => setState(() => _isIncome = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: edChoiceTile(
                  key: const ValueKey('block-dir-in'),
                  leading: const Text('👛', style: TextStyle(fontSize: 20)),
                  label: 'Receives',
                  sub: 'Salary & income',
                  selected: _isIncome,
                  onTap: () => setState(() {
                    _isIncome = true;
                    _hasUntil = false;
                    _isSavings = false;
                  }),
                ),
              ),
            ],
          ),
        ),
        EdSection(
          label: 'Applies to',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EdSegmented<String>(
                keyPrefix: 'block-applies',
                options: const [
                  ('every', 'Every month'),
                  ('month', 'This month only'),
                ],
                value: _temporary ? 'month' : 'every',
                onChanged: (v) => setState(() => _temporary = v == 'month'),
              ),
              if (_temporary) ...[
                const SizedBox(height: 8),
                edNotice(
                  'Only appears in $_monthLabel. Add recurring items inside '
                  'the block when costs should continue into later months.',
                ),
              ],
            ],
          ),
        ),
        if (!_isIncome) ...[
          EdSection(
            label: 'Monthly limit',
            hint: 'Optional',
            child: edBoxedInput(
              key: const ValueKey('block-limit'),
              controller: _cap,
              hint: 'No limit',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              prefix: Text(
                '€',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.tc.soft2,
                ),
              ),
            ),
          ),
          edGroup([
            edToggleRow(
              key: const ValueKey('block-enddate'),
              label: 'Track end date',
              sub: 'For loans & debts with a payoff date',
              value: _hasUntil,
              boxed: false,
              onTap: () => setState(() => _hasUntil = !_hasUntil),
            ),
            edToggleRow(
              key: const ValueKey('block-savings'),
              label: 'Counts as savings',
              sub: 'Include this block in your savings statistics',
              value: _isSavings,
              boxed: false,
              onTap: () => setState(() => _isSavings = !_isSavings),
            ),
          ]),
        ],
        edColourSection(_tone, (c) => setState(() => _tone = c)),
      ],
    );
  }
}
