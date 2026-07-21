part of 'package:family_money_management_app/main.dart';

/// "Coming soon" placeholders for modules the design specifies but that
/// aren't built yet (Calendar #152/#153, Weekly plan #157, Calendars &
/// categories #160/#161). Each is a thin wrapper around [_emptyState], a
/// faithful port of the design's `emptyState()` helper.
extension _ThrivePlaceholderScreens on _ThriveHomeState {
  Widget _emptyState({
    required String icon,
    required String title,
    required String sub,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: B.soft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(child: ic(icon, size: 28, sw: 2, color: B.primary)),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: B.ink,
              ),
            ),
            const SizedBox(height: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: B.soft2,
                  height: 1.5,
                ),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: B.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ic('plus', size: 16, sw: 2.5, color: Colors.white),
                      const SizedBox(width: 7),
                      Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarPlaceholder() {
    return _emptyState(
      icon: 'cal',
      title: 'Calendar is coming soon',
      sub:
          'A shared family calendar with month, week and agenda views is on '
          'the way (issues #152, #153).',
    );
  }

  Widget _buildWeeklyPlaceholder() {
    return _emptyState(
      icon: 'moon',
      title: 'Weekly plan is coming soon',
      sub:
          "Breakfast, lunch and dinner planning for the week is on the way "
          '(issue #157).',
    );
  }

  /// The design opens "Calendars & categories" as a bottom sheet, not a
  /// full-screen tab (`openSheet({type:'calmanage'})` in `renderMore()`).
  /// Import/category management isn't built yet (#160/#161), so this shows a
  /// placeholder sheet in the same slot.
  void _openCalendarsCategoriesPlaceholder() {
    _showSheet(
      (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHead(ctx, 'Calendars & categories'),
            _emptyState(
              icon: 'cal',
              title: 'Coming soon',
              sub:
                  'Calendar imports and event category management are on '
                  'the way (issues #160, #161).',
            ),
          ],
        ),
      ),
    );
  }
}
