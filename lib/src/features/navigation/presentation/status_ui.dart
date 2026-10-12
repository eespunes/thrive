part of 'package:family_money_management_app/main.dart';

/// Status chips and error sheets from `Offline Screen.dc.html` (#401):
/// "Saving… / Saved / Syncing N changes" chips (light on surfaces, dark when
/// floating over content), the amber "Offline · saved on phone" chip, and one
/// bottom sheet for errors that only changes tone.

/// What a status chip shows.
enum StatusChipKind {
  saving,
  saved,
  loading,
  syncing,
  offline;

  Color get tone => switch (this) {
    saving || syncing => const Color(0xff0b9a89),
    saved => const Color(0xff16a34a),
    loading => const Color(0xff1684b4),
    offline => const Color(0xfff59e0b),
  };

  Color lightTrack() => switch (this) {
    saving || syncing => const Color(0xffb7e3db),
    loading => const Color(0xffbfdcea),
    _ => const Color(0xffe2e8f0),
  };

  bool get spins => this == saving || this == syncing || this == loading;
}

/// How many changes the current "Syncing N changes" chip counts.
int syncingChangeCount = 0;

/// The chip text for [kind]; [count] is the number of changes syncing.
String statusChipText(StatusChipKind kind, {int count = 0}) => switch (kind) {
  StatusChipKind.saving => 'Saving…',
  StatusChipKind.saved => 'Saved',
  StatusChipKind.loading => 'Loading',
  StatusChipKind.syncing =>
    count <= 0
        ? 'Syncing…'
        : 'Syncing $count ${count == 1 ? 'change' : 'changes'}',
  StatusChipKind.offline => 'Offline · saved on phone',
};

/// A pill with a status glyph and a label. [dark] is the floating variant
/// (over content); [compact] fits a page header.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.kind,
    required this.text,
    this.dark = false,
    this.compact = false,
    this.onTap,
  });

  final StatusChipKind kind;
  final String text;
  final bool dark;
  final bool compact;
  final VoidCallback? onTap;

  Widget _glyph() {
    final tone = kind.tone;
    if (kind.spins) {
      return _PendingSpinner(
        size: 14,
        tone: tone,
        track: dark ? const Color(0x40ffffff) : kind.lightTrack(),
      );
    }
    if (kind == StatusChipKind.saved) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: tone,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: tone.withValues(alpha: .22), spreadRadius: 4),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      height: compact ? 28 : (dark ? 38 : 36),
      padding: EdgeInsets.fromLTRB(compact ? 8 : 10, 0, compact ? 11 : 14, 0),
      decoration: BoxDecoration(
        color: dark ? const Color(0xff1e293b) : const Color(0xfff4f6f9),
        borderRadius: BorderRadius.circular(999),
        boxShadow: dark
            ? const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 20,
                  spreadRadius: -6,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Center(
              child: Transform.scale(scale: compact ? .85 : 1, child: _glyph()),
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11.5 : 13.5,
                fontWeight: FontWeight.w700,
                color: dark ? const Color(0xfff8fafc) : B.ink,
              ),
            ),
          ),
        ],
      ),
    );
    return Material(
      type: MaterialType.transparency,
      // A passive chip floats over headers: let touches through to them.
      child: onTap == null
          ? IgnorePointer(child: chip)
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: chip,
            ),
    );
  }
}

/// Pops a status chip in: drops 8px and scales up from 96%, fading in.
Widget statusChipSwitcher(Widget? chip) => AnimatedSwitcher(
  duration: const Duration(milliseconds: 250),
  switchInCurve: Curves.easeOut,
  transitionBuilder: (child, a) => FadeTransition(
    opacity: a,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, -.2), end: Offset.zero).animate(a),
      child: ScaleTransition(
        scale: Tween(begin: .96, end: 1.0).animate(a),
        child: child,
      ),
    ),
  ),
  child: chip ?? const SizedBox.shrink(),
);

// ================================================================= sheets

/// The error sheets' tones: the icon dot, its tile and its halo.
enum StatusTone {
  red(Color(0xffef4444), Color(0xfffee2e2)),
  amber(Color(0xfff59e0b), Color(0xfffef3c7)),
  blue(Color(0xff1684b4), Color(0xffe0f0f8)),
  slate(Color(0xff64748b), Color(0xffeef1f5));

  const StatusTone(this.tone, this.soft);
  final Color tone;
  final Color soft;

  /// Red sheets use a dark button; every other tone the brand teal.
  Color get button => this == red ? B.ink : const Color(0xff0b9a89);
}

/// The card of the error sheet: a toned dot, title, body, a primary button
/// and an optional quiet secondary one. [busyLabel] replaces the primary
/// label while [busy] (dimmed and disabled).
class StatusSheetCard extends StatelessWidget {
  const StatusSheetCard({
    super.key,
    required this.tone,
    required this.title,
    required this.body,
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.busy = false,
    this.busyLabel = 'Working…',
    this.primaryKey,
    this.secondaryKey,
  });

  final StatusTone tone;
  final String title;
  final String body;
  final String primary;
  final VoidCallback onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final bool busy;
  final String busyLabel;
  final Key? primaryKey;
  final Key? secondaryKey;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  color: tone.soft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tone.tone,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: tone.tone.withValues(alpha: .2),
                        spreadRadius: 5,
                      ),
                    ],
                  ),
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
                    height: 1.25,
                    color: B.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              height: 1.55,
              color: Color(0xff64748b),
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            key: primaryKey,
            onTap: busy ? null : onPrimary,
            child: Opacity(
              opacity: busy ? .7 : 1,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.button,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  busy ? busyLabel : primary,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          if (secondary != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              key: secondaryKey,
              behavior: HitTestBehavior.opaque,
              onTap: onSecondary,
              child: Container(
                height: 46,
                alignment: Alignment.center,
                child: Text(
                  secondary!,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff475569),
                  ),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// Shows the error sheet over a dimmed screen. The buttons close it, then run
/// their action. Completes when it's closed.
Future<void> showStatusSheet(
  BuildContext context, {
  required StatusTone tone,
  required String title,
  required String body,
  required String primary,
  VoidCallback? onPrimary,
  String? secondary,
  VoidCallback? onSecondary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x610f172a),
    elevation: 0,
    isScrollControlled: true,
    builder: (ctx) {
      void close(VoidCallback? then) {
        Navigator.of(ctx).pop();
        then?.call();
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: StatusSheetCard(
            key: const ValueKey('status-sheet'),
            tone: tone,
            title: title,
            body: body,
            primary: primary,
            onPrimary: () => close(onPrimary),
            secondary: secondary,
            onSecondary: () => close(onSecondary),
            primaryKey: const ValueKey('status-sheet-primary'),
            secondaryKey: const ValueKey('status-sheet-secondary'),
          ),
        ),
      );
    },
  );
}

// ======================================================= can't connect

/// Shown instead of the app when a signed-in user's families couldn't be
/// loaded because the server is unreachable (there's no offline copy): the
/// app's outline, greyed out and dimmed, under the "Can't connect" sheet.
class CloudOfflineScreen extends StatelessWidget {
  const CloudOfflineScreen({
    super.key,
    required this.onRetry,
    this.busy = false,
  });

  final VoidCallback onRetry;
  final bool busy;

  static const _grey = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  Widget _bar(double w, double h, Color c, {double r = 6}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(r)),
  );

  Widget _card(double h, {double r = 18, Widget? child}) => Container(
    height: h,
    padding: child == null ? null : const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r),
      boxShadow: const [BoxShadow(color: Color(0x0d0f172a), spreadRadius: 1)],
    ),
    child: child,
  );

  Widget _outline() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: B.grad,
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(70, 11, const Color(0xffcbd5e1)),
                const SizedBox(height: 5),
                _bar(110, 8, const Color(0xffe2e8f0)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        _bar(double.infinity, 38, const Color(0xffe2e8f0), r: 12),
        const SizedBox(height: 14),
        _card(
          150,
          r: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(90, 9, const Color(0xffe2e8f0)),
              const SizedBox(height: 10),
              _bar(160, 22, const Color(0xffcbd5e1), r: 8),
              const Spacer(),
              _bar(double.infinity, 10, const Color(0xffe2e8f0)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _card(96)),
            const SizedBox(width: 12),
            Expanded(child: _card(96)),
          ],
        ),
        const SizedBox(height: 14),
        _card(64),
        const SizedBox(height: 14),
        _card(64),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('cloud-offline-screen'),
      color: B.page,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: Opacity(
                  opacity: .55,
                  child: ColorFiltered(colorFilter: _grey, child: _outline()),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: const ColoredBox(color: Color(0x610f172a)),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
            child: StatusSheetCard(
              tone: StatusTone.amber,
              title: 'Can’t connect to Thrive',
              body:
                  'Your family’s data lives online. Check your connection '
                  'and try again.',
              primary: 'Try again',
              busy: busy,
              busyLabel: 'Connecting…',
              onPrimary: onRetry,
              primaryKey: const ValueKey('cloud-offline-retry'),
            ),
          ),
        ],
      ),
    );
  }
}
