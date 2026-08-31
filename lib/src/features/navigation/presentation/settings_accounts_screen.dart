part of 'package:family_money_management_app/main.dart';

/// Accounts sub-screen + account studio (#328, `Settings v2.dc.html`): one
/// row per account (badge, name, "Short · X"), hold-and-drag reorder,
/// add-then-open, and a full-screen editor whose delete migrates entries to
/// the FIRST remaining account (the counting confirm states it).
extension _ThriveAccountsScreen on _ThriveHomeState {
  void openAccountsScreen() {
    pushSettingsPage<void>((_) => _AccountsScreen(state: this));
  }

  void reorderAccounts(int from, int to) {
    mutate(() {
      final a = accounts.removeAt(from);
      accounts.insert(to, a);
    });
  }

  /// Counts this workspace's open-month entries paid from [key].
  int entriesOnAccount(String key) {
    var n = 0;
    for (final yr in data.keys) {
      for (final mk in kMonthKeys) {
        final m = data[yr]![mk];
        if (m == null || m.closed) continue;
        for (final arr in m.blocks.values) {
          n += arr.where((it) => it.account == key).length;
        }
      }
    }
    return n;
  }

  /// Deletes [key], moving its open-month entries to the FIRST remaining
  /// account (#328 — the legacy sheet moved them to the last).
  void deleteAccountMigrating(String key) {
    if (accounts.length <= 1) return;
    final remaining = accounts.where((a) => a.key != key).toList();
    final fallback = remaining.first.key;
    mutate(() {
      accounts = remaining;
      for (final yr in data.keys) {
        for (final mk in kMonthKeys) {
          final m = data[yr]![mk];
          if (m == null || m.closed) continue;
          for (final arr in m.blocks.values) {
            for (final it in arr) {
              if (it.account == key) it.account = fallback;
            }
          }
        }
      }
    }, () => flash('Account deleted — entries moved'));
  }
}

class _AccountsScreen extends StatelessWidget {
  const _AccountsScreen({required this.state});
  final _ThriveHomeState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) => SettingsSubScreen(
        sync: s.syncStatus,
        offline: s.netOffline,
        title: 'Accounts',
        subtitle: 'Who pays from where',
        intro:
            'Who pays from where — hold a row and drag to rearrange, '
            'tap to edit.',
        footnote:
            'Deleting an account (inside its editor) moves its entries to '
            'the first remaining one.',
        addPlaceholder: 'New account name…',
        emptyAddHint: 'Type a name first',
        onToast: s.flash,
        onAdd: (name) {
          s.saveAccount(
            'add',
            null,
            name: name,
            short: name.split(' ').first,
            color: kAccPalette[s.accounts.length % kAccPalette.length],
          );
          final a = s.accounts.lastOrNull;
          if (a == null) return;
          s.pushSettingsPage<void>(
            (_) => _AccountStudio(state: s, accountKey: a.key),
          );
        },
        children: [
          HoldDragList(
            itemCount: s.accounts.length,
            onReorder: s.reorderAccounts,
            onToast: s.flash,
            itemBuilder: (context, i) {
              final a = s.accounts[i];
              return SettingsListRow(
                rowKey: ValueKey('accounts-row-${a.key}'),
                leading: settingsBadgeTile(
                  color: a.color,
                  picture: a.picture,
                  emoji: a.emoji,
                  fallbackText: a.initials,
                ),
                label: a.name,
                sub: 'Short · ${a.short}',
                onTap: () => s.pushSettingsPage<void>(
                  (_) => _AccountStudio(state: s, accountKey: a.key),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Full-screen account editor (badge studio): name + required short label,
/// badge, colour; delete (min-1) migrates entries to the first remaining
/// account.
class _AccountStudio extends StatefulWidget {
  const _AccountStudio({required this.state, required this.accountKey});
  final _ThriveHomeState state;
  final String accountKey;

  @override
  State<_AccountStudio> createState() => _AccountStudioState();
}

class _AccountStudioState extends State<_AccountStudio> {
  late String _name;
  late final TextEditingController _short;
  String? _emoji;
  String? _picture;
  late Color _color;

  _ThriveHomeState get s => widget.state;

  Account? get _acc =>
      s.accounts.where((a) => a.key == widget.accountKey).firstOrNull;

  @override
  void initState() {
    super.initState();
    final a = _acc;
    _name = a?.name ?? '';
    _short = TextEditingController(text: a?.short ?? '');
    _emoji = a?.emoji;
    _picture = a?.picture;
    _color = a?.color ?? kAccPalette.first;
  }

  @override
  void dispose() {
    _short.dispose();
    super.dispose();
  }

  void _save() {
    s.saveAccount(
      'edit',
      widget.accountKey,
      name: _name,
      short: _short.text.trim(),
      color: _color,
      emoji: _emoji,
      picture: _picture,
    );
    Navigator.of(context).maybePop();
  }

  void _delete() {
    final a = _acc;
    if (a == null) return;
    final remaining = s.accounts.where((x) => x.key != a.key).toList();
    final n = s.entriesOnAccount(a.key);
    showCountingConfirmSheet(
      context,
      title: 'Delete ${a.name}?',
      message: n == 0
          ? 'No entries are paid from it — it just disappears.'
          : 'Its $n entr${n == 1 ? 'y' : 'ies'} move to '
                '${remaining.first.name}, the first remaining account.',
      confirmLabel: 'Delete account',
      onConfirm: () {
        s.deleteAccountMigrating(a.key);
        Navigator.of(context).maybePop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = s.accounts.length > 1;
    return BadgeStudioScaffold(
      title: 'Edit account',
      subtitle: 'Used across budgets and the money calendar.',
      accent: _color,
      saveLabel: 'Save account',
      saveEnabled: _name.trim().isNotEmpty && _short.text.trim().isNotEmpty,
      onSave: _save,
      deleteLabel: canDelete
          ? 'Delete account — entries move to the first remaining one'
          : null,
      onDelete: canDelete ? _delete : null,
      children: [
        BadgeStage(
          color: _color,
          name: _name,
          onName: (v) => setState(() => _name = v),
          emoji: _emoji,
          picture: _picture,
          fallbackGlyph: '🏦',
          namePlaceholder: "Name it… e.g. Eva's account",
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
        studioTextField(
          key: const ValueKey('acc-short'),
          controller: _short,
          hint: 'Short label — e.g. Eva',
          onChanged: (_) => setState(() {}),
        ),
        BadgeColorRow(
          colors: [if (!kAccPalette.contains(_color)) _color, ...kAccPalette],
          selected: _color,
          onPick: (c) => setState(() => _color = c),
          onToast: s.flash,
        ),
      ],
    );
  }
}
