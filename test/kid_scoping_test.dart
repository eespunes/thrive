import 'package:family_money_management_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kid accounts, sync side: the pure scoping that mirrors firestore.rules
/// (which docs a kid loads, and which writes it may plan).
void main() {
  const fid = 'fam1';
  const ev1 = 'calendar/main/months/2026-07/events/ev1';
  const ev2 = 'calendar/main/months/2026-07/events/ev2';
  String path(String key) => '$kFamiliesCollection/$fid/$key';
  Map<String, dynamic> event(String id, {String? createdBy}) => {
    'id': id,
    'title': 'Event $id',
    'date': '2026-07-10',
    'attendees': ['k1'],
    'createdBy': ?createdBy,
  };

  group('kidMemberIdFromDoc', () {
    test('maps a uid through kidUids', () {
      final doc = {
        'kidUids': {'u1': 'k1', 'u2': ''},
      };
      expect(kidMemberIdFromDoc(doc, 'u1'), 'k1');
      expect(kidMemberIdFromDoc(doc, 'u2'), isNull);
      expect(kidMemberIdFromDoc(doc, 'u3'), isNull);
      expect(kidMemberIdFromDoc(doc, null), isNull);
      expect(kidMemberIdFromDoc(null, 'u1'), isNull);
      expect(kidMemberIdFromDoc({'kidUids': 'x'}, 'u1'), isNull);
    });
  });

  group('kidQueryTags / kidOffLimits', () {
    test('per collection', () {
      for (final c in [
        kSettingsCol,
        kCalendarCol,
        kLayersCol,
        kCategoriesCol,
        kMealsCol,
        kDaysCol,
      ]) {
        expect(kidQueryTags(c), ['all'], reason: c);
        expect(kidOffLimits(c), isFalse);
      }
      expect(kidQueryTags(kEventsCol), ['attending', 'created']);
      expect(kidQueryTags(kRecurringCol), ['attending', 'created']);
      expect(kidQueryTags(kNotesCol), ['created']);
      for (final c in [kFinanceCol, kAccountsCol, kCardsCol, kImportsCol]) {
        expect(kidQueryTags(c), isEmpty, reason: c);
        expect(kidOffLimits(c), isTrue, reason: c);
      }
      // Lines load per own note, never off-limits as a whole.
      expect(kidOffLimits(kLinesCol), isFalse);
    });
  });

  group('ingestKidScoped', () {
    late Records base;
    late Map<String, int> versions;
    late Map<String, Map<String, Set<String>>> scoped;
    late Set<String> loaded;
    setUp(() {
      base = {};
      versions = {};
      scoped = {};
      loaded = {};
    });
    void ingest(
      String col,
      String tag,
      List<(String, Map<String, dynamic>?)> changes, {
      bool full = true,
      bool fromCache = false,
    }) => ingestKidScoped(
      fid: fid,
      col: col,
      tag: tag,
      changes: changes,
      full: full,
      fromCache: fromCache,
      base: base,
      versions: versions,
      scoped: scoped,
      loaded: loaded,
    );

    test('a collection is loaded once every source answered', () {
      ingest(kEventsCol, 'attending', [
        (path(ev1), {...event('ev1'), kVersionField: 3}),
      ]);
      expect(base[ev1], normalizeRecord(ev1, event('ev1')));
      expect(versions[ev1], 3);
      expect(loaded, isNot(contains(kEventsCol)));
      ingest(kEventsCol, 'created', const []);
      expect(loaded, contains(kEventsCol));
    });

    test('a doc only leaves once no source holds it', () {
      ingest(kEventsCol, 'attending', [(path(ev1), event('ev1'))]);
      ingest(kEventsCol, 'created', [
        (path(ev1), event('ev1', createdBy: 'u1')),
        (path(ev2), event('ev2', createdBy: 'u1')),
      ]);
      // The attending source no longer returns ev1: created still has it.
      ingest(kEventsCol, 'attending', const []);
      expect(base.keys, containsAll([ev1, ev2]));
      // A removal from the last holder drops it.
      ingest(kEventsCol, 'created', [(path(ev1), null)], full: false);
      expect(base.containsKey(ev1), isFalse);
      expect(base.containsKey(ev2), isTrue);
    });

    test('an empty cache answer doesn’t wipe held data', () {
      ingest(kEventsCol, 'attending', [(path(ev1), event('ev1'))]);
      ingest(kEventsCol, 'attending', const [], fromCache: true);
      expect(base.containsKey(ev1), isTrue);
      ingest(kEventsCol, 'attending', const []);
      expect(base.containsKey(ev1), isFalse);
    });

    test('other families’ paths and invalid records are skipped', () {
      ingest(kEventsCol, 'attending', [
        ('$kFamiliesCollection/other/$ev1', event('ev1')),
        (path(ev2), event('ev2')),
      ]);
      expect(base.keys, [ev2]);
      ingest(kEventsCol, 'attending', [
        (path(ev2), {...event('ev2'), 'deletion': <String, dynamic>{}}),
      ], full: false);
      expect(base.containsKey(ev2), isFalse);
    });

    test('a note leaving scope takes its lines with it', () {
      const note = 'notes/n1';
      const line = 'notes/n1/lines/l1';
      ingest(kNotesCol, 'created', [
        (path(note), {'id': 'n1', 'name': 'Homework', 'type': 'tasks'}),
      ]);
      expect(loaded, contains(kNotesCol));
      expect(kidNoteKeys(base), {note});
      // Lines aren't loaded until the note's own source answered.
      expect(loaded, isNot(contains(kLinesCol)));
      ingest(kLinesCol, 'note:$note', [
        (path(line), {'id': 'l1', 'text': 'Maths', '_kind': 'task'}),
      ]);
      expect(base.containsKey(line), isTrue);
      expect(loaded, contains(kLinesCol));

      ingest(kNotesCol, 'created', const []);
      expect(base.containsKey(note), isFalse);
      expect(base.containsKey(line), isFalse);
      expect(scoped[kLinesCol], isEmpty);
    });

    test('lines are not loaded before notes', () {
      expect(
        kidColLoaded(kLinesCol, scoped: scoped, loaded: loaded, base: base),
        isFalse,
      );
      loaded.add(kNotesCol);
      expect(
        kidColLoaded(kLinesCol, scoped: scoped, loaded: loaded, base: base),
        isTrue,
      );
    });
  });

  group('kidMayWriteRecord / scopeKidRecords', () {
    const note = 'notes/n1';
    const line = 'notes/n1/lines/l1';
    bool may(String key, Map<String, dynamic> rec, [Records view = const {}]) =>
        kidMayWriteRecord(key, rec, view, uid: 'u1', kidId: 'k1');

    test('mirrors the rules', () {
      expect(may(ev1, {'createdBy': 'u1'}), isTrue);
      expect(
        may(ev1, {
          'attendees': ['k1'],
        }),
        isTrue,
      );
      expect(
        may(ev1, {
          'attendees': ['k2'],
          'createdBy': 'u2',
        }),
        isFalse,
      );
      expect(may('calendar/main/recurring/r1', {'createdBy': 'u1'}), isTrue);
      expect(may(note, {'createdBy': 'u1'}), isTrue);
      expect(may(note, {'createdBy': 'u2'}), isFalse);
      expect(
        may(line, {}, {
          note: {'createdBy': 'u1'},
        }),
        isTrue,
      );
      expect(may(line, {}), isFalse);
      expect(may('cards/c1', {'createdBy': 'u1'}), isFalse);
    });

    test('out-of-scope writes are pinned to the server version', () {
      final base = <String, Map<String, dynamic>>{
        'cards/c1': {'name': 'AH'},
        ev2: {'createdBy': 'u2'},
      };
      final local = <String, Map<String, dynamic>>{
        'cards/c1': {'name': 'Hacked'},
        ev1: {'createdBy': 'u1'},
        ev2: {'createdBy': 'u2', 'title': 'Edited'},
        note: {'createdBy': 'u2'},
      };
      scopeKidRecords(base, local, uid: 'u1', kidId: 'k1');
      expect(local['cards/c1'], {'name': 'AH'});
      expect(local[ev1], {'createdBy': 'u1'});
      expect(local[ev2], {'createdBy': 'u2'});
      expect(local.containsKey(note), isFalse);
    });
  });
}
