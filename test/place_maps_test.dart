import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> _goToCalendar(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-calendar')));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => debugLaunchUrlOverride = null);

  group('mapsSearchUri', () {
    test('builds a universal Google Maps search for a typed place', () {
      final uri = mapsSearchUri('Sports hall, Utrecht')!;
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], 'Sports hall, Utrecht');
      // Encoded, not raw — a place with spaces and commas must survive.
      expect(uri.toString(), contains('Sports+hall'));
    });

    test('a blank place has nothing to open', () {
      expect(mapsSearchUri(''), isNull);
      expect(mapsSearchUri('   '), isNull);
    });

    test('trims what the user typed', () {
      expect(mapsSearchUri('  Dentist  ')!.queryParameters['query'], 'Dentist');
    });
  });

  test('openPlaceInMaps reports failure instead of throwing', () async {
    debugLaunchUrlOverride = (_) async => throw Exception('no handler');
    expect(await openPlaceInMaps('Anywhere'), isFalse);
    expect(await openPlaceInMaps(''), isFalse);
  });

  testWidgets('tapping an event place opens it in Maps', (tester) async {
    Uri? opened;
    debugLaunchUrlOverride = (uri) async {
      opened = uri;
      return true;
    };
    await pumpApp(tester, landOnDefaultTab: true);
    thriveDebug.mutateState(() {
      thriveDebug.events.add(
        CalendarEvent(
          id: 'p1',
          title: 'Swimming',
          date: todayIso(),
          allDay: true,
          color: const Color(0xff1684B4),
          location: 'Sports hall, Utrecht',
          reminder: 'none',
        ),
      );
    });
    await tester.pumpAndSettle();
    await _goToCalendar(tester);
    // The day sheet, then the event's row — the view sheet is where a saved
    // place is read (openEvent() is the editor).
    await tester.tap(find.byKey(ValueKey('cal-day-bg-${todayIso()}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('event-p1-${todayIso()}')));
    await tester.pumpAndSettle();

    final place = find.byKey(const ValueKey('event-view-location'));
    expect(place, findsOneWidget);
    await tester.tap(place);
    await tester.pumpAndSettle();
    expect(opened, isNotNull);
    expect(opened!.queryParameters['query'], 'Sports hall, Utrecht');
  });

  testWidgets('the editor offers to find the typed place on Maps', (
    tester,
  ) async {
    Uri? opened;
    debugLaunchUrlOverride = (uri) async {
      opened = uri;
      return true;
    };
    await pumpApp(tester, landOnDefaultTab: true);
    await _goToCalendar(tester);
    await tester.tap(find.byKey(const ValueKey('quickadd-fab')));
    await tester.pumpAndSettle();

    // Nothing typed yet — nothing to find.
    expect(find.byKey(const ValueKey('event-open-in-maps')), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('event-card-place')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('event-location')),
      'Dentist, Utrecht',
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('event-open-in-maps'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(opened!.queryParameters['query'], 'Dentist, Utrecht');
  });
}
