part of 'package:family_money_management_app/main.dart';

/// Test seam so widget tests can supply a canned feed instead of hitting the
/// network. `null` in production.
@visibleForTesting
Future<http.Response> Function(Uri uri)? icsHttpGetOverride;

/// Fetches an ICS/webcal feed (e.g. an ecal.com, Google, Apple, or Outlook
/// published-calendar link) and returns its events as [ImportedCalendarEvent]s.
/// Throws [IcsImportException] with a user-facing message on failure.
Future<List<ImportedCalendarEvent>> fetchIcsEvents(String rawUrl) async {
  final uri = _parseIcsUri(rawUrl);
  http.Response res;
  try {
    res = icsHttpGetOverride != null
        ? await icsHttpGetOverride!(uri)
        : await http
              .get(
                uri,
                headers: const {'Accept': 'text/calendar, text/plain, */*'},
              )
              .timeout(const Duration(seconds: 20));
  } on TimeoutException {
    throw IcsImportException('Calendar link timed out');
  } catch (_) {
    throw IcsImportException('Could not reach that calendar link');
  }
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw IcsImportException('Calendar link returned ${res.statusCode}');
  }
  // Cap feed size so a hostile/misconfigured link can't exhaust memory:
  // check the advertised Content-Length and the actual bytes received.
  final contentLength = int.tryParse(res.headers['content-length'] ?? '');
  if ((contentLength != null && contentLength > _maxIcsBytes) ||
      res.bodyBytes.length > _maxIcsBytes) {
    throw IcsImportException('That calendar feed is too large (over 5 MB)');
  }
  final events = parseIcsEvents(res.body);
  if (events.isEmpty) {
    throw IcsImportException('No events found in that calendar');
  }
  return events;
}

Uri _parseIcsUri(String rawUrl) {
  final trimmed = rawUrl.trim();
  var uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) {
    throw IcsImportException('Enter a valid calendar URL');
  }
  // `webcal://` is a plain ICS feed served over http(s), same as any other
  // calendar-subscription link (ecal.com, Google, Apple all publish these).
  if (uri.scheme == 'webcal') uri = uri.replace(scheme: 'https');
  // Auto-upgrade pasted `http://` links — feeds are only fetched over https
  // so events never travel in cleartext.
  if (uri.scheme == 'http') uri = uri.replace(scheme: 'https');
  if (uri.scheme != 'https') {
    throw IcsImportException('Only https/webcal links are supported');
  }
  return uri;
}

/// Maximum accepted ICS response size (5 MB) — see the check in
/// [fetchIcsEvents].
const int _maxIcsBytes = 5 * 1024 * 1024;

class IcsImportException implements Exception {
  IcsImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Minimal RFC 5545 VEVENT parser: unfolds continuation lines, then reads
/// UID/SUMMARY/DESCRIPTION/LOCATION/DTSTART/DTEND out of each `VEVENT`.
/// Covers what real-world ICS feeds (ecal.com, fotmob, and the major
/// calendar providers) publish; recurrence rules and per-instance overrides
/// are not expanded — each VEVENT becomes a single read-only occurrence.
///
/// A `VEVENT` commonly nests its own sub-components (`VALARM` reminders,
/// most notably), which have their own `SUMMARY`/`DESCRIPTION` properties —
/// those must NOT be captured as the event's own, so this tracks nesting
/// depth and only reads properties at the top level directly inside VEVENT.
List<ImportedCalendarEvent> parseIcsEvents(String ics) {
  final out = <ImportedCalendarEvent>[];
  Map<String, String>? cur;
  var depth =
      0; // 0 = outside VEVENT; 1 = VEVENT top level; >1 = nested (e.g. VALARM)
  for (final line in _unfoldIcsLines(ics)) {
    final trimmed = line.trim();
    if (trimmed.startsWith('BEGIN:')) {
      if (depth == 0 && trimmed == 'BEGIN:VEVENT') {
        cur = {};
        depth = 1;
      } else if (depth > 0) {
        depth++;
      }
      continue;
    }
    if (trimmed.startsWith('END:')) {
      if (depth > 0) depth--;
      if (depth == 0 && trimmed == 'END:VEVENT') {
        final props = cur;
        cur = null;
        if (props != null) {
          final ev = _icsEventFromProps(props);
          if (ev != null) out.add(ev);
        }
      }
      continue;
    }
    if (cur == null || depth != 1) continue;
    final idx = trimmed.indexOf(':');
    if (idx < 0) continue;
    final key = trimmed.substring(0, idx).split(';').first.toUpperCase();
    cur[key] = trimmed.substring(idx + 1);
  }
  return out;
}

/// Joins folded lines (a leading space/tab continues the previous line).
List<String> _unfoldIcsLines(String ics) {
  final raw = ics.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final out = <String>[];
  for (final line in raw) {
    if ((line.startsWith(' ') || line.startsWith('\t')) && out.isNotEmpty) {
      out[out.length - 1] += line.substring(1);
    } else {
      out.add(line);
    }
  }
  return out;
}

ImportedCalendarEvent? _icsEventFromProps(Map<String, String> p) {
  final dtstart = p['DTSTART'];
  if (dtstart == null || dtstart.isEmpty) return null;
  final start = _parseIcsDate(dtstart);
  if (start == null) return null;
  final allDay = dtstart.length == 8;
  final dtend = p['DTEND'];
  final end = dtend != null ? _parseIcsDate(dtend) : null;
  return ImportedCalendarEvent(
    id: (p['UID'] ?? uid()).toString(),
    title: _stripEmoji(_unescapeIcsText(p['SUMMARY'] ?? 'Imported event')),
    date: _isoOfDate(start),
    allDay: allDay,
    start: allDay ? '' : _hhmmOfIcs(start),
    end: allDay || end == null ? '' : _hhmmOfIcs(end),
    location: _unescapeIcsText(p['LOCATION'] ?? ''),
    notes: _stripUrls(_unescapeIcsText(p['DESCRIPTION'] ?? '')),
  );
}

final RegExp _emojiPattern = RegExp(
  '['
  r'\u{1F000}-\u{1FFFF}'
  r'\u{2190}-\u{2BFF}'
  r'\u{2600}-\u{27BF}'
  r'\u{FE0F}'
  r'\u{200D}'
  ']',
  unicode: true,
);

/// Strips emoji (and their variation-selector/ZWJ glue) from imported event
/// titles — some feeds decorate SUMMARY with decorative emoji we don't want
/// surfaced in the app's event list.
String _stripEmoji(String v) => v
    .replaceAll(_emojiPattern, '')
    .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
    .trim();

final RegExp _urlPattern = RegExp(
  r'(https?://\S+|www\.\S+)',
  caseSensitive: false,
);

/// Removes URLs from imported event descriptions — some feeds (e.g.
/// ticketing/streaming calendars) append a link into `DESCRIPTION` that we
/// don't want surfaced as event notes.
String _stripUrls(String v) => v
    .replaceAll(_urlPattern, '')
    .replaceAll(RegExp(r'[ \t]+\n'), '\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

final RegExp _icsDatePattern = RegExp(
  r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?',
);

/// Parses a `DTSTART`/`DTEND` value into the device's local time.
///
/// - Date-only (`YYYYMMDD`, all-day events) has no time component to convert.
/// - A trailing `Z` (`YYYYMMDDTHHMMSSZ`) is UTC per RFC 5545 and is converted
///   to local time so the event lands on the correct local day/hour.
/// - Anything else (a bare local time, or a `TZID=...` time we don't have a
///   timezone database for) is treated as already being in the viewer's
///   local time — the common case for feeds like ecal.com that publish in
///   the subscriber's timezone.
DateTime? _parseIcsDate(String v) {
  final m = _icsDatePattern.firstMatch(v);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (m.group(4) == null) return DateTime.utc(y, mo, d);
  final h = int.parse(m.group(4)!);
  final mi = int.parse(m.group(5)!);
  final s = int.parse(m.group(6)!);
  if (v.trim().endsWith('Z')) {
    return DateTime.utc(y, mo, d, h, mi, s).toLocal();
  }
  return DateTime(y, mo, d, h, mi, s);
}

String _hhmmOfIcs(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _unescapeIcsText(String v) => v
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\N', '\n')
    .replaceAll(r'\,', ',')
    .replaceAll(r'\;', ';')
    .replaceAll(r'\\', r'\')
    .trim();
