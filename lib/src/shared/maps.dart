part of 'package:family_money_management_app/main.dart';

/// Turns a typed place into a real one: the universal Google Maps search URL.
///
/// It is deliberately a search, not a pin — the app stores free text ("Sports
/// hall", "Dentist, Utrecht"), not coordinates, and a search is what resolves
/// that text into an actual place on the map. The universal `api=1` link
/// opens the Maps app when it's installed and the website when it isn't, on
/// every platform, so there is no per-platform scheme to maintain.
Uri? mapsSearchUri(String place) {
  final q = place.trim();
  if (q.isEmpty) return null;
  return Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': q});
}

/// Test seam: set to intercept the launch instead of leaving the app.
Future<bool> Function(Uri uri)? debugLaunchUrlOverride;

/// Opens [place] in Google Maps. Returns false when there is nothing to open
/// or no app could handle the link, so callers can say so rather than leaving
/// the user with a tap that did nothing.
Future<bool> openPlaceInMaps(String place) async {
  final uri = mapsSearchUri(place);
  if (uri == null) return false;
  final launcher = debugLaunchUrlOverride;
  try {
    if (launcher != null) return await launcher(uri);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('[maps] could not open $uri: $e');
    return false;
  }
}
