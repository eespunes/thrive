part of 'package:family_money_management_app/main.dart';

/// Lightweight in-app analytics (issue #234). The app has no external
/// analytics backend; events are recorded in-memory (inspectable in tests
/// and debugging) and echoed to the debug log. Swapping in a real backend
/// later only means changing [logAnalyticsEvent].
final List<({String name, Map<String, Object?> props})> kAnalyticsEvents = [];

void logAnalyticsEvent(String name, [Map<String, Object?> props = const {}]) {
  kAnalyticsEvents.add((name: name, props: props));
  if (kAnalyticsEvents.length > 200) kAnalyticsEvents.removeAt(0);
  foundation.debugPrint('[analytics] $name $props');
}
