part of 'package:family_money_management_app/main.dart';

/// Home-board sheets: the "Add a widget" picker (#237) and the per-widget
/// options editor (#239).
extension _ThriveHomeBoardSheets on _ThriveHomeState {
  void openHomeWidgetPicker() {
    _showSheet((ctx) => _HomeWidgetPickerSheet(state: this));
  }

  void openHomeWidgetOptions(int index) {
    final entry = (homeBoard ?? effectiveHomeBoard()).elementAtOrNull(index);
    if (entry == null || !_homeWidgetHasOptions(entry.widgetId)) return;
    _showSheet(
      (ctx) => _HomeWidgetOptionsSheet(state: this, index: index, entry: entry),
    );
  }
}

class _HomeWidgetPickerSheet extends StatefulWidget {
  const _HomeWidgetPickerSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_HomeWidgetPickerSheet> createState() => _HomeWidgetPickerSheetState();
}

class _HomeWidgetPickerSheetState extends State<_HomeWidgetPickerSheet> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final placed = {for (final e in s.effectiveHomeBoard()) e.widgetId};
    final offered = s
        .offeredHomeWidgets()
        .where((d) => _filter == 'all' || d.category == _filter)
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHead(context, 'Add a widget', 'Compose your own Home'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              for (final (k, label) in const [
                ('all', 'All'),
                ('money', 'Money'),
                ('calendar', 'Calendar'),
                ('home', 'Home'),
              ]) ...[
                GestureDetector(
                  key: ValueKey('picker-filter-$k'),
                  onTap: () => setState(() => _filter = k),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _filter == k ? B.soft : Colors.white,
                      border: Border.all(
                        color: _filter == k ? B.primary : B.line,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _filter == k ? B.deep : B.soft2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
              ],
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final def in offered)
                  Builder(
                    builder: (context) {
                      // Dividers may be placed any number of times; every
                      // other widget greys out once it's on the board.
                      final grey =
                          def.id != 'divider' && placed.contains(def.id);
                      return GestureDetector(
                        key: ValueKey('picker-w-${def.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: grey
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                widget.state.addHomeWidget(def.id);
                              },
                        child: Opacity(
                          opacity: grey ? .45 : 1,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: B.line),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: B.soft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: ic(
                                      def.icon,
                                      size: 16,
                                      sw: 2.1,
                                      color: B.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        def.title,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: B.ink,
                                        ),
                                      ),
                                      Text(
                                        grey
                                            ? 'Already on your board'
                                            : def.sub,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: B.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  def.sizes
                                      .map((z) => z.toUpperCase())
                                      .join(' · '),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: B.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Per-widget options (#239): which blocks, which list, whose events, the
/// four quick actions, note/label text. Saved into the board entry.
class _HomeWidgetOptionsSheet extends StatefulWidget {
  const _HomeWidgetOptionsSheet({
    required this.state,
    required this.index,
    required this.entry,
  });
  final _ThriveHomeState state;
  final int index;
  final BoardEntry entry;

  @override
  State<_HomeWidgetOptionsSheet> createState() =>
      _HomeWidgetOptionsSheetState();
}

class _HomeWidgetOptionsSheetState extends State<_HomeWidgetOptionsSheet> {
  late final Map<String, dynamic> _opts = Map<String, dynamic>.from(
    widget.entry.options,
  );
  late final TextEditingController _text = TextEditingController(
    text: (_opts['text'] ?? _opts['label'] ?? '').toString(),
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final id = widget.entry.widgetId;
    if (id == 'family_note') _opts['text'] = _text.text.trim();
    if (id == 'divider') _opts['label'] = _text.text.trim();
    widget.state.setHomeWidgetOptions(widget.index, _opts);
    Navigator.of(context).pop();
  }

  Widget _chip(Key key, String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? B.soft : Colors.white,
          border: Border.all(color: on ? B.primary : B.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: on ? B.deep : B.text,
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final s = widget.state;
    switch (widget.entry.widgetId) {
      case 'budget_blocks':
        final chosen = {
          for (final k in (_opts['blocks'] as List? ?? const [])) k.toString(),
        };
        return _sheetField(
          'Which blocks',
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final c in s.cats.where((c) => !c.isIncome))
                _chip(
                  ValueKey('opt-block-${c.key}'),
                  c.title,
                  chosen.contains(c.key),
                  () {
                    setState(() {
                      chosen.contains(c.key)
                          ? chosen.remove(c.key)
                          : chosen.add(c.key);
                      _opts['blocks'] = chosen.toList();
                    });
                  },
                ),
            ],
          ),
        );
      case 'today':
        return _sheetField(
          'Whose events',
          Row(
            children: [
              _chip(
                const ValueKey('opt-who-everyone'),
                'Everyone',
                _opts['who'] != 'me',
                () => setState(() => _opts['who'] = 'everyone'),
              ),
              const SizedBox(width: 7),
              _chip(
                const ValueKey('opt-who-me'),
                'Just me',
                _opts['who'] == 'me',
                () => setState(() => _opts['who'] = 'me'),
              ),
            ],
          ),
        );
      case 'tasks':
        return _sheetField(
          '',
          _toggleRow(
            'Only my tasks',
            _opts['onlyMine'] == true,
            () => setState(() => _opts['onlyMine'] = _opts['onlyMine'] != true),
            activeColor: B.primary,
          ),
        );
      case 'shopping':
        final current = (_opts['listId'] ?? '').toString();
        return _sheetField(
          'Which list',
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final l in s.shoppingLists)
                _chip(
                  ValueKey('opt-list-${l.id}'),
                  l.name,
                  current == l.id,
                  () => setState(() => _opts['listId'] = l.id),
                ),
            ],
          ),
        );
      case 'quick_actions':
        final chosen = [
          for (final a in (_opts['actions'] as List? ?? kDefaultQuickActions))
            a.toString(),
        ];
        return _sheetField(
          'Pick four actions',
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final (id, label, _) in kHomeQuickActions)
                _chip(ValueKey('opt-qa-$id'), label, chosen.contains(id), () {
                  setState(() {
                    if (chosen.contains(id)) {
                      chosen.remove(id);
                    } else if (chosen.length < 4) {
                      chosen.add(id);
                    }
                    _opts['actions'] = chosen;
                  });
                }),
            ],
          ),
        );
      case 'family_note':
        return _sheetField(
          'Note',
          _sheetInput(_text, hint: 'e.g. Grandma arrives Friday!', maxLines: 3),
        );
      case 'divider':
        return _sheetField('Label', _sheetInput(_text, hint: 'e.g. Evenings'));
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final def = homeWidgetDef(widget.entry.widgetId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHeadWithTick(
          context,
          def?.title ?? 'Widget options',
          sub: 'Only changes your board',
          onConfirm: _save,
        ),
        Flexible(child: SingleChildScrollView(child: _body())),
      ],
    );
  }
}
