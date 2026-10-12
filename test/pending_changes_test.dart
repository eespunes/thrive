import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

void main() {
  CalendarEvent ev(String id, {String title = 'Swim'}) => CalendarEvent(
    id: id,
    title: title,
    date: '2026-10-07',
    color: const Color(0xff1684B4),
    notes: 'old',
  );
  Records recs(List<CalendarEvent> events) =>
      normalizedRecords(Workspace.empty()..events = events);
  final keyA = eventRecordKey(ev('a'));

  group('PendingChanges journal', () {
    test('staging doc id is a flat, per-record Firestore id', () {
      final c = PendingChange(
        familyId: 'fam_1',
        key: 'notes/n1/lines/l1',
        op: PendingOp.save,
        at: 1,
        record: {'name': 'Milk'},
      );
      expect(c.docId, 'fam_1__notes__n1__lines__l1');
      expect(c.docId.contains('/'), isFalse);
      final back = PendingChange.fromJson(c.toJson())!;
      expect(back.docId, c.docId);
      expect(back.record, {'name': 'Milk'});
      expect(back.serverRecord, isNull);
    });

    test('keeps the first server version across edits', () {
      final j = PendingChanges();
      final server = recs([ev('a')])[keyA]!;
      j.record('f', keyA, record: {'v': 1}, serverRecord: server, now: 1);
      j.record('f', keyA, record: {'v': 2}, serverRecord: {'v': 1}, now: 2);
      final c = j['f|$keyA']!;
      expect(c.record, {'v': 2});
      expect(c.serverRecord, server);
      expect(c.at, 2);
      expect(j.length, 1);
    });

    test('an old acknowledgement never clears a newer change', () {
      final j = PendingChanges();
      final s1 = j.record(
        'f',
        'k',
        record: {'v': 1},
        serverRecord: null,
        now: 1,
      );
      final s2 = j.record(
        'f',
        'k',
        record: {'v': 2},
        serverRecord: null,
        now: 2,
      );
      expect(j.settle('f', 'k', s1), isFalse);
      expect(j.isEmpty, isFalse);
      expect(j.settle('f', 'k', s2), isTrue);
      expect(j.isEmpty, isTrue);
    });

    test('round-trips JSON for its own user only', () {
      final j = PendingChanges()
        ..record('f', 'k', record: {'a': 1}, serverRecord: null, now: 3)
        ..record('f', 'd', record: null, serverRecord: {'b': 2}, now: 4);
      final raw = j.toJson('u1');
      final back = PendingChanges.fromJson(raw, 'u1');
      expect(back.length, 2);
      expect(back['f|d']!.op, PendingOp.delete);
      expect(back['f|d']!.serverRecord, {'b': 2});
      expect(back['f|k']!.op, PendingOp.save);
      expect(back['f|k']!.record, {'a': 1});
      expect(PendingChanges.fromJson(raw, 'u2').isEmpty, isTrue);
      expect(PendingChanges.fromJson('junk', 'u1').isEmpty, isTrue);
    });

    test('removeFamily drops only that family', () {
      final j = PendingChanges()
        ..record('f', 'k', record: {}, serverRecord: null, now: 1)
        ..record('g', 'k', record: {}, serverRecord: null, now: 1);
      expect(j.removeFamily('f'), isTrue);
      expect(j.all.map((c) => c.familyId), ['g']);
    });
  });

  group('applyPendingChanges', () {
    test('a new line of a new note is kept even if the note changed later', () {
      final note = {'id': 'n1', 'name': 'Shop'};
      final line = {'id': 'l1', 'name': 'Milk'};
      final r = applyPendingChanges(
        server: const {},
        local: const {},
        changes: [
          PendingChange(
            familyId: 'f',
            key: 'notes/n1/lines/l1',
            op: PendingOp.save,
            at: 1,
            record: line,
          ),
          PendingChange(
            familyId: 'f',
            key: 'notes/n1',
            op: PendingOp.save,
            at: 2,
            record: note,
          ),
        ],
      );
      expect(r.lost, isEmpty);
      expect(r.pending.length, 2);
      expect(r.local['notes/n1/lines/l1'], line);
    });

    PendingChange change(
      String key, {
      Map<String, dynamic>? record,
      Map<String, dynamic>? serverRecord,
      bool delete = false,
    }) => PendingChange(
      familyId: 'f',
      key: key,
      op: delete ? PendingOp.delete : PendingOp.save,
      at: 1,
      record: record,
      serverRecord: serverRecord,
    );

    test('an edit merges onto the current server version', () {
      final orig = recs([ev('a')])[keyA]!;
      // Another member changed the notes meanwhile; we changed the title.
      final server = recs([ev('a')..notes = 'theirs']);
      final mine = recs([ev('a', title: 'Gym')])[keyA]!;
      final r = applyPendingChanges(
        server: server,
        local: server,
        changes: [change(keyA, record: mine, serverRecord: orig)],
      );
      expect(r.pending, hasLength(1));
      expect(r.local[keyA]!['title'], 'Gym');
      expect(r.local[keyA]!['notes'], 'theirs');
    });

    test('an edit already on the server is settled', () {
      final server = recs([ev('a', title: 'Gym')]);
      final r = applyPendingChanges(
        server: server,
        local: server,
        changes: [
          change(
            keyA,
            record: server[keyA],
            serverRecord: recs([ev('a')])[keyA],
          ),
        ],
      );
      expect(r.settled, hasLength(1));
      expect(r.pending, isEmpty);
    });

    test('an edit of a record deleted meanwhile is lost (delete wins)', () {
      final orig = recs([ev('a')])[keyA]!;
      final r = applyPendingChanges(
        server: const {},
        local: const {},
        changes: [change(keyA, record: orig, serverRecord: orig)],
      );
      expect(r.lost, hasLength(1));
      expect(r.local.containsKey(keyA), isFalse);
    });

    test('a create is re-added unless it already landed', () {
      final rec = recs([ev('a')])[keyA]!;
      var r = applyPendingChanges(
        server: const {},
        local: const {},
        changes: [change(keyA, record: rec)],
      );
      expect(r.local[keyA], rec);
      expect(r.pending, hasLength(1));
      r = applyPendingChanges(
        server: {keyA: rec},
        local: {keyA: rec},
        changes: [change(keyA, record: rec)],
      );
      expect(r.settled, hasLength(1));
    });

    test('a new line under a note deleted meanwhile is lost', () {
      final line = listItemKey('L', 'x');
      final r = applyPendingChanges(
        server: const {},
        local: const {},
        changes: [
          change(line, record: {'id': 'x', 'name': 'Milk'}),
        ],
      );
      expect(r.lost, hasLength(1));
    });

    test('a delete is re-applied, or settled if already gone', () {
      final server = recs([ev('a')]);
      var r = applyPendingChanges(
        server: server,
        local: server,
        changes: [change(keyA, serverRecord: server[keyA], delete: true)],
      );
      expect(r.local.containsKey(keyA), isFalse);
      expect(r.deletes, {keyA});
      r = applyPendingChanges(
        server: const {},
        local: const {},
        changes: [change(keyA, serverRecord: server[keyA], delete: true)],
      );
      expect(r.settled, hasLength(1));
      expect(r.deletes, isEmpty);
    });
  });

  test('container records are hidden from the review list', () {
    expect(isContainerRecord('calendar/main/months/2026-10'), isTrue);
    expect(isContainerRecord(keyA), isFalse);
    expect(recordKindLabel(keyA), 'Event');
    expect(recordKindLabel(listMetaKey('L')), 'Note');
  });

  test('review labels fall back to text, the meal day, then the kind', () {
    PendingChange change(String key, Map<String, dynamic> rec) => PendingChange(
      familyId: 'f',
      key: key,
      op: PendingOp.save,
      at: 0,
      record: rec,
    );
    expect(pendingChangeLabel(change(keyA, {'text': '  Milk '})), 'Milk');
    expect(
      pendingChangeLabel(
        change('$kMealsCol/2026/$kMonthsCol/10/$kDaysCol/17', {}),
      ),
      'Saturday 17 Oct',
    );
    expect(
      pendingChangeLabel(
        change('$kMealsCol/x/$kMonthsCol/y/$kDaysCol/z', {
          '_key': '2026-10-17',
        }),
      ),
      '2026-10-17',
    );
    expect(
      pendingChangeLabel(change('$kMealsCol/x/$kMonthsCol/y/$kDaysCol/z', {})),
      'Meal plan',
    );
    expect(pendingChangeLabel(change(keyA, {})), 'Event');
  });

  test('review labels', () {
    final c = PendingChange(
      familyId: 'f',
      key: keyA,
      op: PendingOp.save,
      at: DateTime(2026, 10, 2, 14, 5).millisecondsSinceEpoch,
      record: {'title': 'Swim'},
      serverRecord: {'title': 'Old'},
    );
    expect(pendingChangeLabel(c), 'Swim');
    expect(pendingChangeVerb(c), 'Edited');
    expect(pendingChangeWhen(c.at, DateTime(2026, 10, 9)), '2 Oct, 14:05');
    expect(
      pendingChangeWhen(c.at, DateTime(2026, 10, 2, 14, 35)),
      '30 min ago',
    );
  });
}
