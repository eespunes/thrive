part of 'package:family_money_management_app/main.dart';

/// Weekly plan & wallet sub-pages (#282, `Settings v2.dc.html`).
///
/// Weekly plan: seven weekday rows with an inline dinner field per day —
/// typing saves as you go (the fuller planner stays on the Weekly tab).
/// Wallet: card rows → the existing full-brightness scannable card face
/// (bottom sheet with barcode + Remove); add card via the scanner path.
extension _ThriveWeeklyWalletScreens on _ThriveHomeState {
  void openWeeklyPlanScreen() {
    pushSettingsPage<void>((_) => _WeeklyPlanSubScreen(state: this));
  }

  void openWalletSubScreen() {
    pushSettingsPage<void>((_) => _WalletSubScreen(state: this));
  }
}

class _WeeklyPlanSubScreen extends StatefulWidget {
  const _WeeklyPlanSubScreen({required this.state});
  final _ThriveHomeState state;

  @override
  State<_WeeklyPlanSubScreen> createState() => _WeeklyPlanSubScreenState();
}

class _WeeklyPlanSubScreenState extends State<_WeeklyPlanSubScreen> {
  static const List<String> _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  final List<TextEditingController> _ctls = [];

  _ThriveHomeState get s => widget.state;

  @override
  void initState() {
    super.initState();
    final start = s._weekStart();
    for (var i = 0; i < 7; i++) {
      final iso = s._iso(start.add(Duration(days: i)));
      _ctls.add(TextEditingController(text: s.weeklyPlan[iso]?.dinner ?? ''));
    }
  }

  @override
  void dispose() {
    for (final c in _ctls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = s._weekStart();
    final end = start.add(const Duration(days: 6));
    final range =
        '${start.day} ${kMonthsEn[start.month - 1].substring(0, 3)} – '
        '${end.day} ${kMonthsEn[end.month - 1].substring(0, 3)}';
    return SettingsSubScreen(
      title: 'Weekly plan',
      subtitle: 'Meals for the week',
      intro: 'Dinner plan · $range — type straight in, it saves as you go.',
      onToast: s.flash,
      children: [
        for (var i = 0; i < 7; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: B.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    _days[i],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: B.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: ValueKey('weekly-dinner-$i'),
                    controller: _ctls[i],
                    onChanged: (v) => s.setMeal(
                      s._iso(s._weekStart().add(Duration(days: i))),
                      'dinner',
                      v,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 11),
                      hintText: 'Dinner…',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: B.muted,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: B.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WalletSubScreen extends StatelessWidget {
  const _WalletSubScreen({required this.state});
  final _ThriveHomeState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) {
        final famName = s.curFamily()?.name ?? 'your family';
        return SettingsSubScreen(
          title: 'Discount cards',
          subtitle: 'The family wallet',
          intro:
              'Everyone in $famName can use these at the till. '
              'Tap a card to show it.',
          footnote: s.cards.isEmpty
              ? 'No cards yet — add one and the whole family can scan it.'
              : 'Brightness goes up automatically at the till.',
          onToast: s.flash,
          children: [
            for (final c in s.cards)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SettingsListRow(
                  rowKey: ValueKey('wallet-sub-row-${c.id}'),
                  leading: settingsBadgeTile(
                    color: c.color,
                    icon: 'card',
                    size: 34,
                  ),
                  label: c.name,
                  sub:
                      '${c.maskedNumber} · '
                      '${cardLastUsedLabel(c.lastUsedMillis, DateTime.now())}',
                  onTap: () => s.openCardFace(c.id),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                key: const ValueKey('wallet-sub-add'),
                behavior: HitTestBehavior.opaque,
                onTap: s.openCardScan,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: B.primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '＋ Add a card',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: B.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
