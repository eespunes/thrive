part of 'package:family_money_management_app/main.dart';

/// Settings → Unsaved changes (see [PendingChanges]):
/// - changes this phone is still trying to save (retry / discard), and
/// - changes left unsaved by a previous run, set aside in the user's staging
///   area in Firestore - kept out of the family's data until applied or
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
    final r = await applyStagedChanges(ids);
    if (!mounted) return;
    if (r.signedOut) {
      flash('Sign in to apply changes', tone: ToastTone.alert);
      return;
    }
    if (r.failed) {
      flash('Couldn’t save yet - will keep trying', tone: ToastTone.retry);
      return;
    }
    final gone = r.gone;
    final goneText = gone.length == 1
        ? '“${gone.first}” was deleted by another member'
        : '${gone.length} items were deleted by another member';
    if (r.applied == 0) {
      flash(
        gone.isEmpty ? 'Nothing could be applied' : goneText,
        tone: ToastTone.info,
      );
      return;
    }
    flash(
      r.applied == 1 ? 'Change applied' : '${r.applied} changes applied',
      body: gone.isEmpty
          ? null
          : '$goneText, so ${gone.length == 1 ? 'it was' : 'they were'} '
                'skipped.',
    );
  }

  Future<void> discardStaged(List<String> ids) async {
    await discardStagedChanges(ids);
    if (mounted) _flashDiscarded(ids.length);
  }

  void discardPending(List<String> ids) {
    if (ids.length == 1) {
      discardPendingChange(ids.first);
    } else {
      discardAllPendingChanges();
    }
    _flashDiscarded(ids.length);
  }

  void _flashDiscarded(int n) => flash(
    n == 1 ? 'Change discarded' : '$n changes discarded',
    tone: ToastTone.neutral,
  );

  /// "Jansen family" for changes of one family, else "your families".
  String unsavedFamilyLabel(Iterable<PendingChange> changes) {
    final ids = {for (final c in changes) c.familyId};
    if (ids.length == 1) {
      final name =
          families.where((f) => f.id == ids.first).firstOrNull?.name ?? '';
      return name.trim().isEmpty ? 'your family' : name.trim();
    }
    return 'your families';
  }

  /// Bottom-sheet confirmation before discarding one or more [changes].
  void confirmDiscard({
    required List<PendingChange> changes,
    required bool saving,
    required VoidCallback onConfirm,
  }) {
    final fam = unsavedFamilyLabel(changes);
    final famData = '${possessive(fam)} data';
    final n = changes.length;
    final one = n == 1;
    final changesText = one ? '1 change' : '$n changes';
    final String title, body, primary, secondary;
    if (one) {
      title = 'Discard this change?';
      body = saving
          ? 'It stops trying to save, and it won’t reach $fam. This can’t be '
                'undone.'
          : 'It’s removed from your set-aside space. '
                '${capitalize(famData)} stays as it is. This can’t be undone.';
      primary = 'Discard change';
      secondary = 'Keep it';
    } else if (saving) {
      title = 'Discard $changesText still saving?';
      body = 'They stop retrying and won’t reach $fam. This can’t be undone.';
      primary = 'Discard $changesText';
      secondary = 'Keep saving';
    } else {
      title = 'Discard $n set-aside changes?';
      body =
          '${capitalize(famData)} stays exactly as it is. These changes are '
          'removed from your space. This can’t be undone.';
      primary = 'Discard $changesText';
      secondary = 'Keep them';
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x610f172a),
      isScrollControlled: true,
      builder: (ctx) => _DiscardSheet(
        title: title,
        body: body,
        item: one ? changes.first : null,
        summary: one ? null : changes,
        primary: primary,
        secondary: secondary,
        onConfirm: () {
          Navigator.of(ctx).pop();
          onConfirm();
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
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
    final ok = await syncNow();
    if (!mounted) return;
    if (ok && _pending.isEmpty) {
      flash('All changes saved');
    } else {
      flash('Couldn’t save yet - will keep trying', tone: ToastTone.retry);
    }
  }
}

/// "Jansen family’s" / "your families’".
String possessive(String name) => name.endsWith('s') ? '$name’' : '$name’s';

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
    // meals/{yyyy}/months/{mm}/days/{dd} → "Saturday 17 Oct".
    final p = c.key.split('/');
    final d = DateTime.tryParse('${p[1]}-${p[3]}-${p[5]}');
    if (d != null) {
      return '${_kWeekdays[d.weekday - 1]} ${d.day} '
          '${_kShortMonths[d.month - 1]}';
    }
    final key = rec['_key'];
    if (key is String && key.isNotEmpty) return key;
  }
  return recordKindLabel(c.key);
}

const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _kWeekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', //
  'Friday', 'Saturday', 'Sunday',
];

/// "just now" / "5 min ago" / "3 h ago" / "2 Oct, 14:05".
String pendingChangeWhen(int at, [DateTime? now]) {
  final t = DateTime.fromMillisecondsSinceEpoch(at);
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${_kShortMonths[t.month - 1]}, $hh:$mm';
}

/// The four kinds of item the review screen distinguishes (icon + colour).
enum _ChangeType {
  note('note item', 'Notes', Color(0xff475569), Color(0xffeef1f5)),
  event('event', 'Events', Color(0xff1684B4), Color(0xffe0f0f8)),
  budget('budget entry', 'Budget', B.deep, B.soft),
  meal('meal plan', 'Meal plans', B.orangeText, B.orangeSoft);

  const _ChangeType(this.single, this.group, this.ink, this.bg);
  final String single;
  final String group;
  final Color ink;
  final Color bg;

  static _ChangeType of(PendingChange c) => switch (recordKind(c.key)) {
    RecordKind.note || RecordKind.line => note,
    RecordKind.calendar ||
    RecordKind.layer ||
    RecordKind.eventCategory ||
    RecordKind.import ||
    RecordKind.recurringEvent ||
    RecordKind.calendarMonth ||
    RecordKind.event => event,
    RecordKind.kitchen ||
    RecordKind.mealsYear ||
    RecordKind.mealsMonth ||
    RecordKind.mealDay => meal,
    RecordKind.unknown => note,
    _ => budget,
  };
}

/// "Added" green, "Edited" blue, "Deleted" red.
Color _verbInk(String verb) => switch (verb) {
  'Added' => B.greenText,
  'Deleted' => B.red,
  _ => const Color(0xff1684B4),
};

Color _verbTone(String verb) => switch (verb) {
  'Added' => B.green,
  'Deleted' => B.red,
  _ => const Color(0xff1684B4),
};

/// A design icon (16-unit viewBox) from its SVG [shapes].
Widget _svg16(
  String shapes, {
  double size = 16,
  required Color color,
  double sw = 2,
}) {
  final hex =
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  return SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="none" '
    'stroke="$hex" stroke-width="$sw" stroke-linecap="round" '
    'stroke-linejoin="round">$shapes</svg>',
    width: size,
    height: size,
  );
}

/// The "upload" glyph of the Unsaved changes row.
Widget unsavedChangesGlyph(Color color) => _svg16(
  '<path d="M8 10V2.5M5 5.5l3-3 3 3M2.5 10v3h11v-3"/>',
  size: 18,
  color: color,
  sw: 1.8,
);

/// The item tile: the type's icon with an added / edited / deleted badge.
Widget _changeTile(PendingChange c, {double size = 36}) {
  final t = _ChangeType.of(c);
  final verb = pendingChangeVerb(c);
  final icon = switch (t) {
    _ChangeType.note => _svg16(
      '<path d="M3.5 4.5h9M3.5 8h9M3.5 11.5h5.5"/>',
      color: t.ink,
    ),
    _ChangeType.event => _svg16(
      '<rect x="2.5" y="3.5" width="11" height="10" rx="2.5"/>'
      '<path d="M2.5 7h11M5.5 2v2.5M10.5 2v2.5"/>',
      color: t.ink,
      sw: 1.9,
    ),
    _ChangeType.budget => Text(
      '€',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.ink),
    ),
    _ChangeType.meal => _svg16(
      '<circle cx="8" cy="8" r="5.5"/><circle cx="8" cy="8" r="2.4"/>',
      color: t.ink,
      sw: 1.9,
    ),
  };
  final badge = switch (verb) {
    'Added' => '<path d="M5 1.5v7M1.5 5h7"/>',
    'Deleted' => '<path d="M1.5 5h7"/>',
    _ => '<path d="M1.5 8.5l.6-2.4L6.6 1.6l1.8 1.8-4.5 4.5z"/>',
  };
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(11),
          ),
          child: icon,
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: 17,
            height: 17,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _verbTone(verb),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: SvgPicture.string(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" '
              'fill="none" stroke="#ffffff" stroke-width="2" '
              'stroke-linecap="round" stroke-linejoin="round">$badge</svg>',
              width: 9,
              height: 9,
            ),
          ),
        ),
      ],
    ),
  );
}

/// "**Added** note item" - the verb in its colour.
Widget _verbLine(PendingChange c, {String? tail, double fontSize = 12.5}) {
  final verb = pendingChangeVerb(c);
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: verb,
          style: TextStyle(color: _verbInk(verb), fontWeight: FontWeight.w800),
        ),
        TextSpan(
          text:
              ' ${recordKindLabel(c.key).toLowerCase()}'
              '${tail == null ? '' : ' · $tail'}',
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: B.soft2,
    ),
  );
}

/// A small spinning ring; still under tests and with reduced motion.
class _PendingSpinner extends StatefulWidget {
  const _PendingSpinner({
    this.size = 14,
    this.track = const Color(0xffdbe3ea),
    this.tone = B.primary,
  });
  final double size;
  final Color track;
  final Color tone;

  @override
  State<_PendingSpinner> createState() => _PendingSpinnerState();
}

class _PendingSpinnerState extends State<_PendingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  static final bool _underTest =
      !foundation.kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = _underTest || MediaQuery.of(context).disableAnimations;
    if (still) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _spin,
    child: SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(painter: _RingPainter(widget.track, widget.tone)),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.track, [this.tone = B.primary]);
  final Color track;
  final Color tone;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rect = r.deflate(1);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(rect, p..color = track);
    canvas.drawArc(rect, -math.pi * .75, math.pi / 2, false, p..color = tone);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.track != track || old.tone != tone;
}

/// The set-aside tray's 1.5px dashed amber outline.
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.75),
          const Radius.circular(20),
        ),
      );
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xfff2c96b);
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => false;
}

/// Settings → Unsaved changes: "Saving" (retried automatically) and "Set
/// aside" (needs the user: Apply / Discard each).
class _PendingChangesScreen extends StatefulWidget {
  const _PendingChangesScreen({required this.state});
  final _ThriveHomeState state;

  @override
  State<_PendingChangesScreen> createState() => _PendingChangesScreenState();
}

class _PendingChangesScreenState extends State<_PendingChangesScreen> {
  /// Above this many set-aside changes, they get verb filters and are
  /// grouped by type.
  static const int _longList = 8;
  String _filter = 'All';

  _ThriveHomeState get s => widget.state;

  Widget _textButton(Key key, String label, VoidCallback onTap) =>
      GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: B.soft2,
            ),
          ),
        ),
      );

  Widget _countBadge(int n, Color ink, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      '$n',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ink),
    ),
  );

  Widget _sectionLabel(String text, Color ink) => Text(
    text,
    style: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
      color: ink,
    ),
  );

  Widget _header(int total, String? famSuffix) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
    child: Row(
      children: [
        GestureDetector(
          key: const ValueKey('pending-back'),
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14101828),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: _svg16(
              '<path d="M10 3.5L5.5 8 10 12.5"/>',
              color: B.ink,
              sw: 2.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unsaved changes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                  color: B.ink,
                ),
              ),
              Text(
                total == 0
                    ? 'Everything is saved'
                    : '$total not saved in Thrive'
                          '${famSuffix == null ? '' : ' · $famSuffix'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: total == 0 ? B.greenText : B.amberText,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _offlineBanner() => Container(
    margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: B.amberSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: B.amberLine),
    ),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: B.amber,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x2ed97706), spreadRadius: 4)],
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'You’re offline - changes are kept on this phone',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: B.amberText,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _empty() => Padding(
    key: const ValueKey('pending-empty'),
    padding: const EdgeInsets.fromLTRB(24, 90, 24, 0),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: B.greenSoft,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: B.green,
              shape: BoxShape.circle,
            ),
            child: _svg16(
              '<path d="M4 8.3l2.6 2.6L12 5.4"/>',
              size: 16,
              color: Colors.white,
              sw: 2.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'All changes saved',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -.3,
            color: B.ink,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Everything you changed has reached Thrive. If something can’t be '
          'saved, it shows up here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: B.soft2,
          ),
        ),
      ],
    ),
  );

  Widget _savingSection(
    List<PendingChange> saving,
    String? Function(PendingChange) famOf,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 2),
            const _PendingSpinner(size: 12, track: Color(0xffb7e3db)),
            const SizedBox(width: 8),
            _sectionLabel('SAVING', B.deep),
            const SizedBox(width: 8),
            _countBadge(saving.length, B.deep, B.soft),
            const Spacer(),
            GestureDetector(
              key: const ValueKey('pending-retry'),
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(s.retryPendingChanges()),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: B.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _svg16(
                      '<path d="M13 8a5 5 0 1 1-1.5-3.6M13 2.5v2.8h-2.8"/>',
                      size: 13,
                      color: B.deep,
                      sw: 2.2,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Save now',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: B.deep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            _textButton(
              const ValueKey('pending-discard-all'),
              'Discard all',
              () => s.confirmDiscard(
                changes: saving,
                saving: true,
                onConfirm: () =>
                    s.discardPending([for (final c in saving) c.id]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            'Retrying automatically - nothing to do. Tap a change to '
            'discard it.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: B.soft2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0a101828),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: Color(0x47101828),
                blurRadius: 26,
                spreadRadius: -20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              for (final (i, c) in saving.indexed)
                GestureDetector(
                  key: ValueKey('pending-${c.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => s.confirmDiscard(
                    changes: [c],
                    saving: true,
                    onConfirm: () => s.discardPending([c.id]),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : const Border(top: BorderSide(color: B.faint)),
                    ),
                    child: Row(
                      children: [
                        _changeTile(c),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _name(c),
                              const SizedBox(height: 2),
                              _verbLine(
                                c,
                                tail: [
                                  ?famOf(c),
                                  pendingChangeWhen(c.at),
                                ].join(' · '),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const _PendingSpinner(),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _name(PendingChange c) => Text(
    pendingChangeLabel(c),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w800,
      color: B.ink,
    ),
  );

  Widget _asideRow(PendingChange c, String? fam) {
    final status = s.stagedStatus(c);
    final canApply = status != StagedStatus.familyGone;
    return Container(
      key: ValueKey('staged-${c.id}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0d101828),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          _changeTile(c),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _name(c),
                const SizedBox(height: 2),
                _verbLine(c, tail: fam, fontSize: 12),
                const SizedBox(height: 2),
                Text(
                  canApply
                      ? pendingChangeWhen(c.at)
                      : '${pendingChangeWhen(c.at)} · Family not available',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: canApply ? B.muted : B.amberText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Discard',
            button: true,
            child: GestureDetector(
              key: ValueKey('staged-discard-${c.id}'),
              onTap: () => s.confirmDiscard(
                changes: [c],
                saving: false,
                onConfirm: () => unawaited(s.discardStaged([c.id])),
              ),
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: B.faint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SvgPicture.string(
                  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 12" '
                  'fill="none" stroke="#64748b" stroke-width="2.2" '
                  'stroke-linecap="round"><path d="M2.5 2.5l7 7M9.5 2.5l-7 7"/>'
                  '</svg>',
                  width: 12,
                  height: 12,
                ),
              ),
            ),
          ),
          if (canApply) ...[
            const SizedBox(width: 6),
            GestureDetector(
              key: ValueKey('staged-apply-${c.id}'),
              onTap: () => unawaited(s.applyStaged([c.id])),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: B.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: B.deep,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, int count) {
    final on = label == _filter;
    return GestureDetector(
      key: ValueKey('staged-filter-$label'),
      onTap: () => setState(() => _filter = label),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: on ? B.ink : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? B.ink : const Color(0xfff2dfae)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : B.text,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: (on ? Colors.white : B.text).withValues(alpha: .7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _asideSection(
    List<PendingChange> staged,
    String? Function(PendingChange) famOf,
  ) {
    final applicable = [
      for (final c in staged)
        if (s.stagedStatus(c) != StagedStatus.familyGone) c.id,
    ];
    final long = staged.length > _longList;
    final filter = long ? _filter : 'All';
    final visible = [
      for (final c in staged)
        if (filter == 'All' || pendingChangeVerb(c) == filter) c,
    ];
    final fam = s.unsavedFamilyLabel(staged);
    Widget rows(List<PendingChange> list) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in list)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _asideRow(c, famOf(c)),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 3),
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: B.amber,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0x2ed97706), spreadRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 9),
            _sectionLabel('SET ASIDE', B.amberText),
            const SizedBox(width: 8),
            _countBadge(staged.length, B.amberText, const Color(0xfffef3c7)),
            const Spacer(),
            _textButton(
              const ValueKey('staged-discard-all'),
              'Discard all',
              () => s.confirmDiscard(
                changes: staged,
                saving: false,
                onConfirm: () =>
                    unawaited(s.discardStaged([for (final c in staged) c.id])),
              ),
            ),
            if (applicable.isNotEmpty) ...[
              const SizedBox(width: 8),
              GestureDetector(
                key: const ValueKey('staged-apply-all'),
                onTap: () => unawaited(s.applyStaged(applicable)),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: B.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Apply all',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        CustomPaint(
          foregroundPainter: const _DashedRRectPainter(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            decoration: BoxDecoration(
              color: B.amberSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: _svg16(
                          '<rect x="3" y="7" width="10" height="7" rx="2"/>'
                          '<path d="M5.5 7V5a2.5 2.5 0 0 1 5 0v2"/>',
                          size: 15,
                          color: B.amberText,
                          sw: 1.9,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Not in ${possessive(fam)} data yet. Only you can '
                          'see these - Apply to add them on top of the latest '
                          'version.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                            color: Color(0xff92400e),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (long) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final k in const [
                        'All',
                        'Added',
                        'Edited',
                        'Deleted',
                      ])
                        _chip(
                          k,
                          k == 'All'
                              ? staged.length
                              : staged
                                    .where((c) => pendingChangeVerb(c) == k)
                                    .length,
                        ),
                    ],
                  ),
                  for (final t in _ChangeType.values)
                    if (visible.any((c) => _ChangeType.of(c) == t)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: t.ink,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              t.group.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .6,
                                color: B.text,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${visible.where((c) => _ChangeType.of(c) == t).length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: B.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      rows([
                        for (final c in visible)
                          if (_ChangeType.of(c) == t) c,
                      ]),
                    ],
                ] else
                  rows(visible),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _footnote() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoDot(),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Set-aside changes live in your own space, apart from the '
            'family’s data. If someone deleted the item in the meantime, the '
            'deletion wins.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: B.soft2,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: B.page,
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: s.pendingChangesTick,
          builder: (context, _, _) {
            final saving = s.visiblePendingChanges;
            final staged = s.visibleStagedChanges;
            final total = saving.length + staged.length;
            final all = [...saving, ...staged];
            final familyIds = {for (final c in all) c.familyId};
            // Several families' changes: name each row's family; one family
            // (while the user has several): name it in the subtitle.
            final perRowFamily = familyIds.length > 1;
            String? famOf(PendingChange c) =>
                perRowFamily ? s.unsavedFamilyLabel([c]) : null;
            final famSuffix =
                !perRowFamily && familyIds.isNotEmpty && s.families.length > 1
                ? s.unsavedFamilyLabel(all)
                : null;
            return Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: s.netOffline,
                  builder: (context, off, _) =>
                      off ? _offlineBanner() : const SizedBox.shrink(),
                ),
                _header(total, famSuffix),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
                    children: [
                      if (total == 0) _empty(),
                      if (saving.isNotEmpty) ...[
                        _savingSection(saving, famOf),
                        const SizedBox(height: 22),
                      ],
                      if (staged.isNotEmpty) ...[
                        _asideSection(staged, famOf),
                        const SizedBox(height: 22),
                      ],
                      if (total > 0) _footnote(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoDot extends StatelessWidget {
  const _InfoDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    margin: const EdgeInsets.only(top: 1),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xff94a3b8), width: 1.6),
    ),
    child: const Text(
      'i',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        height: 1,
        color: B.muted,
      ),
    ),
  );
}

/// The red "Discard …?" bottom sheet: one change's preview, or a summary of
/// how many of each kind.
class _DiscardSheet extends StatelessWidget {
  const _DiscardSheet({
    required this.title,
    required this.body,
    required this.primary,
    required this.secondary,
    required this.onConfirm,
    required this.onCancel,
    this.item,
    this.summary,
  });

  final String title;
  final String body;
  final String primary;
  final String secondary;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final PendingChange? item;
  final List<PendingChange>? summary;

  @override
  Widget build(BuildContext context) {
    final it = item;
    final counts = <_ChangeType, int>{};
    for (final c in summary ?? const <PendingChange>[]) {
      counts.update(_ChangeType.of(c), (n) => n + 1, ifAbsent: () => 1);
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          key: const ValueKey('discard-sheet'),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x800f172a),
                blurRadius: 60,
                spreadRadius: -20,
                offset: Offset(0, 30),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: B.redSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: _svg16(
                      '<path d="M2.5 4.5h11M6 4.5V3h4v1.5M4 4.5l.7 8.5h6.6l.7-8.5"/>',
                      size: 18,
                      color: B.red,
                      sw: 1.9,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.3,
                        color: B.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.55,
                  color: B.soft2,
                ),
              ),
              const SizedBox(height: 16),
              if (it != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: B.page,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _changeTile(it, size: 34),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pendingChangeLabel(it),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: B.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _verbLine(it, tail: pendingChangeWhen(it.at)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (counts.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final MapEntry(key: t, value: n) in counts.entries)
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: B.page,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: t.ink,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$n ${n == 1 ? t.single : t.group.toLowerCase()}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: B.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              GestureDetector(
                key: const ValueKey('discard-confirm'),
                onTap: onConfirm,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: B.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    primary,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                key: const ValueKey('discard-cancel'),
                behavior: HitTestBehavior.opaque,
                onTap: onCancel,
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  child: Text(
                    secondary,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: B.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "You have unsaved changes" - shown once per session when changes were set
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
