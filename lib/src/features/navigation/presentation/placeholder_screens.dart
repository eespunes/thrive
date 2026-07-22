part of 'package:family_money_management_app/main.dart';

/// Shared "coming soon" empty-state helper, still used by in-progress
/// features. A faithful port of the design's `emptyState()` helper.
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
}
