part of 'package:family_money_management_app/main.dart';

/// Settings → Unsaved changes: what this device changed that the server
/// hasn't confirmed yet (see [PendingChanges]), with retry / discard.
extension _ThrivePendingChanges on _ThriveHomeState {
  void openPendingChangesScreen() {
    pushSettingsPage<void>((_) => _PendingChangesScreen(state: this));
  }

  /// The changes worth showing (not mere year / month containers).
  List<PendingChange> get visiblePendingChanges => [
    for (final c in _pending.all.reversed)
      if (!isContainerRecord(c.key)) c,
  ];

  /// Sends every unsaved change now.
  Future<void> retryPendingChanges() async {
    final ok = await _persist();
    if (!mounted) return;
    flash(
      ok && _pending.isEmpty
          ? 'All changes saved'
          : 'Couldn’t save yet — will keep trying',
    );
  }
}

/// "Added" / "Edited" / "Deleted".
String pendingChangeVerb(PendingChange c) => c.op == PendingOp.delete
    ? 'Deleted'
    : c.serverRecord == null
    ? 'Added'
    : 'Edited';

/// The item's name, for people.
String pendingChangeLabel(PendingChange c) {
  final rec = c.anyRecord;
  final label = recordLabel(rec);
  if (label.isNotEmpty) return label;
  final text = rec['text'];
  if (text is String && text.trim().isNotEmpty) return text.trim();
  if (recordKind(c.key) == RecordKind.mealDay) {
    return c.key.split('/').skip(1).join('-');
  }
  return recordKindLabel(c.key);
}

/// "just now" / "5 min ago" / "3 h ago" / "2 Oct, 14:05".
String pendingChangeWhen(int at, [DateTime? now]) {
  final t = DateTime.fromMillisecondsSinceEpoch(at);
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${months[t.month - 1]}, $hh:$mm';
}

class _PendingChangesScreen extends StatelessWidget {
  const _PendingChangesScreen({required this.state});
  final _ThriveHomeState state;

  Widget _button({
    required Key key,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) => GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: danger ? B.red : B.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: danger ? B.red : B.deep,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ValueListenableBuilder<int>(
      valueListenable: s.pendingChangesTick,
      builder: (context, _, _) {
        final changes = s.visiblePendingChanges;
        String familyName(String fid) =>
            s.families.where((f) => f.id == fid).firstOrNull?.name ?? '';
        final multiFamily = {for (final c in changes) c.familyId}.length > 1;
        return SettingsSubScreen(
          sync: s.syncStatus,
          offline: s.netOffline,
          title: 'Unsaved changes',
          subtitle: changes.isEmpty
              ? 'Everything is saved'
              : '${changes.length} waiting to be saved',
          intro:
              'Changes made on this phone that haven’t reached Thrive yet. '
              'They’re kept on this phone and sent as soon as you’re '
              'online — even if you close the app.',
          footnote:
              'Discarding a change puts the item back the way it is in '
              'Thrive. If someone else deletes an item you changed, the '
              'deletion wins.',
          onToast: s.flash,
          children: [
            if (changes.isEmpty)
              const Padding(
                key: ValueKey('pending-empty'),
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    '✓ All changes saved',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: B.deep,
                    ),
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    _button(
                      key: const ValueKey('pending-retry'),
                      label: '↻ Save now',
                      onTap: () => unawaited(s.retryPendingChanges()),
                    ),
                    const Spacer(),
                    _button(
                      key: const ValueKey('pending-discard-all'),
                      label: 'Discard all',
                      danger: true,
                      onTap: () => s.askDelete(
                        'all unsaved changes',
                        'Every change below is undone on this phone and '
                            'never saved.',
                        s.discardAllPendingChanges,
                        confirmLabel: 'Discard',
                      ),
                    ),
                  ],
                ),
              ),
              for (final c in changes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SettingsListRow(
                    rowKey: ValueKey('pending-${c.id}'),
                    label: pendingChangeLabel(c),
                    sub: [
                      '${pendingChangeVerb(c)} ${recordKindLabel(c.key).toLowerCase()}',
                      if (multiFamily) familyName(c.familyId),
                      pendingChangeWhen(c.at),
                    ].where((x) => x.isNotEmpty).join(' · '),
                    value: 'Discard',
                    warnVal: true,
                    noChev: true,
                    onTap: () => s.askDelete(
                      pendingChangeLabel(c),
                      'This change is undone on this phone and never saved.',
                      () => s.discardPendingChange(c.id),
                      confirmLabel: 'Discard',
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
