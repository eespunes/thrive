part of 'package:family_money_management_app/main.dart';

/// Settings → Unsaved changes (see [PendingChanges]):
/// - changes this phone is still trying to save (retry / discard), and
/// - changes left unsaved by a previous run, set aside in the user's staging
///   area in Firestore — kept out of the family's data until applied or
///   discarded.
extension _ThrivePendingChanges on _ThriveHomeState {
  void openPendingChangesScreen() {
    pushSettingsPage<void>((_) => _PendingChangesScreen(state: this));
  }

  /// The changes still being saved worth showing (not mere year / month
  /// containers).
  List<PendingChange> get visiblePendingChanges => [
    for (final c in _pending.all.reversed)
      if (!isContainerRecord(c.key)) c,
  ];

  /// The changes set aside in the staging area, newest first.
  List<PendingChange> get visibleStagedChanges => [
    for (final c in _staged.all.reversed)
      if (!isContainerRecord(c.key)) c,
  ];

  /// Every unsaved change shown in Settings.
  int get unsavedChangeCount =>
      visiblePendingChanges.length + visibleStagedChanges.length;

  Future<void> applyStaged(List<String> ids) async {
    final msg = await applyStagedChanges(ids);
    if (mounted) flash(msg);
  }

  Future<void> discardStaged(List<String> ids) async {
    await discardStagedChanges(ids);
    if (!mounted) return;
    flash(ids.length == 1 ? 'Change discarded' : 'Changes discarded');
  }

  /// Once per session: tells the user changes were set aside and offers to
  /// review them (Settings → Unsaved changes).
  void promptUnsavedChanges() {
    final n = visibleStagedChanges.length;
    if (!mounted || _unsavedPromptShown || n == 0) return;
    _unsavedPromptShown = true;
    showDialog<bool>(
      context: context,
      barrierColor: const Color(0x80101828),
      builder: (ctx) => _UnsavedChangesDialog(
        count: n,
        onLater: () => Navigator.of(ctx).pop(false),
        onReview: () => Navigator.of(ctx).pop(true),
      ),
    ).then((review) {
      if (review == true && mounted) openPendingChangesScreen();
    });
  }

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

  Widget _section(String title, String body) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
            color: Color(0xff8a96a8),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          body,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xff5f6b7d),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ValueListenableBuilder<int>(
      valueListenable: s.pendingChangesTick,
      builder: (context, _, _) {
        final saving = s.visiblePendingChanges;
        final staged = s.visibleStagedChanges;
        final total = saving.length + staged.length;
        String familyName(String fid) =>
            s.families.where((f) => f.id == fid).firstOrNull?.name ?? '';
        final multiFamily =
            {
              for (final c in [...saving, ...staged]) c.familyId,
            }.length >
            1;
        String sub(PendingChange c) => [
          '${pendingChangeVerb(c)} ${recordKindLabel(c.key).toLowerCase()}',
          if (multiFamily) familyName(c.familyId),
          pendingChangeWhen(c.at),
        ].where((x) => x.isNotEmpty).join(' · ');
        final status = {for (final c in staged) c.id: s.stagedStatus(c)};
        final applicable = [
          for (final c in staged)
            if (status[c.id] == StagedStatus.ready) c.id,
        ];
        return SettingsSubScreen(
          sync: s.syncStatus,
          offline: s.netOffline,
          title: 'Unsaved changes',
          subtitle: total == 0
              ? 'Everything is saved'
              : '$total not saved in Thrive',
          intro:
              'Changes made on this phone that haven’t reached your '
              'family’s data in Thrive.',
          footnote:
              'Set-aside changes are kept in your own space in Thrive, apart '
              'from your family’s data — nobody else sees them — until you '
              'apply or discard them. Applying one merges it onto the latest '
              'version. A change to an item someone deleted meanwhile, or to '
              'a family you’re no longer in, can only be discarded.',
          onToast: s.flash,
          children: [
            if (total == 0)
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
              ),
            if (saving.isNotEmpty) ...[
              _section(
                'Saving',
                'Still being saved from this phone — they’re kept here (even '
                    'if you close the app) until you’re online.',
              ),
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
                        'all changes being saved',
                        'Every change in this list is undone on this phone '
                            'and never saved.',
                        s.discardAllPendingChanges,
                        confirmLabel: 'Discard',
                      ),
                    ),
                  ],
                ),
              ),
              for (final c in saving)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SettingsListRow(
                    rowKey: ValueKey('pending-${c.id}'),
                    label: pendingChangeLabel(c),
                    sub: sub(c),
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
            if (staged.isNotEmpty) ...[
              _section(
                'Set aside',
                'Not saved before the app closed, so they were set aside '
                    'instead of changing your family’s data. Apply the ones '
                    'you still want.',
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    if (applicable.isNotEmpty)
                      _button(
                        key: const ValueKey('staged-apply-all'),
                        label: '✓ Apply all',
                        onTap: () => unawaited(s.applyStaged(applicable)),
                      ),
                    const Spacer(),
                    _button(
                      key: const ValueKey('staged-discard-all'),
                      label: 'Discard all',
                      danger: true,
                      onTap: () => s.askDelete(
                        'all set-aside changes',
                        'They’re deleted and never applied. Your family’s '
                            'data stays as it is.',
                        () => unawaited(
                          s.discardStaged([for (final c in staged) c.id]),
                        ),
                        confirmLabel: 'Discard',
                      ),
                    ),
                  ],
                ),
              ),
              for (final c in staged)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SettingsListRow(
                    rowKey: ValueKey('staged-${c.id}'),
                    label: pendingChangeLabel(c),
                    sub: sub(c),
                    value: switch (status[c.id]) {
                      StagedStatus.deletedMeanwhile => 'Deleted meanwhile',
                      StagedStatus.familyGone => 'Family not available',
                      _ => null,
                    },
                    warnVal: true,
                    noChev: true,
                    actions: [
                      if (status[c.id] == StagedStatus.ready)
                        _button(
                          key: ValueKey('staged-apply-${c.id}'),
                          label: 'Apply',
                          onTap: () => unawaited(s.applyStaged([c.id])),
                        ),
                      _button(
                        key: ValueKey('staged-discard-${c.id}'),
                        label: 'Discard',
                        danger: true,
                        onTap: () => s.askDelete(
                          pendingChangeLabel(c),
                          'This change is deleted and never applied.',
                          () => unawaited(s.discardStaged([c.id])),
                          confirmLabel: 'Discard',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// "You have unsaved changes" — shown once per session when changes were set
/// aside, offering to review them.
class _UnsavedChangesDialog extends StatelessWidget {
  const _UnsavedChangesDialog({
    required this.count,
    required this.onLater,
    required this.onReview,
  });

  final int count;
  final VoidCallback onLater;
  final VoidCallback onReview;

  Widget _button(
    Key key,
    String label,
    VoidCallback onTap, {
    required bool filled,
  }) => Expanded(
    child: GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? B.primary : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: filled ? null : Border.all(color: B.line),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: filled ? Colors.white : B.text,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey('unsaved-changes-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(26),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 312),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: B.amberSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: Text(
                  '↻',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: B.amber,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              count == 1
                  ? '1 change wasn’t saved'
                  : '$count changes weren’t saved',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
                color: B.ink,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Thrive closed before they reached your family’s data, so they '
              'were set aside. Review them to apply the ones you still want '
              'or discard the rest.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: B.soft2,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 19),
            Row(
              children: [
                _button(
                  const ValueKey('unsaved-later'),
                  'Later',
                  onLater,
                  filled: false,
                ),
                const SizedBox(width: 9),
                _button(
                  const ValueKey('unsaved-review'),
                  'Review',
                  onReview,
                  filled: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
