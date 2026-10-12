import 'package:family_money_management_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

// Record versions (`_v`) and the versioned-save merge in the pure record
// layer (lib/src/features/account/data/cloud_records.dart).
void main() {
  group('recordVersion / normalizeRecord', () {
    test('reads the version, 0 when missing or malformed', () {
      expect(recordVersion({'_v': 4}), 4);
      expect(recordVersion({'_v': 4.0}), 4);
      expect(recordVersion({'title': 'a'}), 0);
      expect(recordVersion(null), 0);
    });

    test('version bookkeeping never reads as record content', () {
      final a = normalizeRecord('events/e1', {
        'id': 'e1',
        'title': 'Dentist',
        kVersionField: 3,
        kUpdatedByField: 'uid-a',
        'updatedAtMillis': 1,
      });
      final b = normalizeRecord('events/e1', {
        'id': 'e1',
        'title': 'Dentist',
        kVersionField: 9,
        kUpdatedByField: 'uid-b',
        'updatedAtMillis': 2,
      });
      expect(a, isNotNull);
      expect(a!.containsKey(kVersionField), isFalse);
      expect(a.containsKey(kUpdatedByField), isFalse);
      expect(jsonEquals(a, b), isTrue);
    });
  });

  group('conflictPaths', () {
    final prev = {
      'title': 'Dentist',
      'time': '09:00',
      'meta': {'a': 1, 'b': 2},
    };

    test('no conflict when only one side changed', () {
      expect(conflictPaths(prev, prev, {...prev, 'title': 'Doctor'}), isEmpty);
      expect(conflictPaths(prev, {...prev, 'title': 'Doctor'}, prev), isEmpty);
    });

    test('no conflict when both made the same change', () {
      final both = {...prev, 'title': 'Doctor'};
      expect(conflictPaths(prev, both, both), isEmpty);
    });

    test('different fields never conflict', () {
      expect(
        conflictPaths(
          prev,
          {...prev, 'time': '10:00'},
          {...prev, 'title': 'Doctor'},
        ),
        isEmpty,
      );
      expect(
        conflictPaths(
          prev,
          {
            ...prev,
            'meta': {'a': 5, 'b': 2},
          },
          {
            ...prev,
            'meta': {'a': 1, 'b': 7},
          },
        ),
        isEmpty,
      );
    });

    test('same field changed differently is a conflict (nested path)', () {
      expect(
        conflictPaths(
          prev,
          {...prev, 'title': 'Theirs'},
          {...prev, 'title': 'Mine'},
        ),
        [
          ['title'],
        ],
      );
      expect(
        conflictPaths(
          prev,
          {
            ...prev,
            'meta': {'a': 5, 'b': 2},
          },
          {
            ...prev,
            'meta': {'a': 6, 'b': 2},
          },
        ),
        [
          ['meta', 'a'],
        ],
      );
    });

    test('one side removing a field the other changed conflicts', () {
      final theirs = Map<String, dynamic>.from(prev)..remove('time');
      expect(conflictPaths(prev, theirs, {...prev, 'time': '11:00'}), [
        ['time'],
      ]);
    });
  });

  group('planVersionedSave', () {
    final prev = {'title': 'Dentist', 'time': '09:00', 'done': false};

    test('merges a concurrent edit to another field and patches only mine', () {
      final server = {...prev, 'time': '10:00'};
      final local = {...prev, 'title': 'Doctor'};
      final plan = planVersionedSave(prev: prev, server: server, local: local);
      expect(plan.merged, {'title': 'Doctor', 'time': '10:00', 'done': false});
      expect(plan.conflicts, isEmpty);
      expect(plan.patch.map((c) => c.path.join('.')), ['title']);
    });

    test('same field: mine wins in the save and the conflict is reported', () {
      final server = {...prev, 'title': 'Theirs'};
      final local = {...prev, 'title': 'Mine'};
      final plan = planVersionedSave(prev: prev, server: server, local: local);
      expect(plan.merged['title'], 'Mine');
      expect(plan.conflicts, [
        ['title'],
      ]);
    });

    test('nothing to write when the server already has my version', () {
      final local = {...prev, 'done': true};
      final plan = planVersionedSave(prev: prev, server: local, local: local);
      expect(plan.patch, isEmpty);
      expect(plan.conflicts, isEmpty);
    });
  });

  group('takeTheirs', () {
    test('replaces only the conflicting fields', () {
      final mine = {
        'title': 'Mine',
        'time': '09:30',
        'meta': {'a': 6, 'b': 2},
      };
      final theirs = {
        'title': 'Theirs',
        'time': '10:00',
        'meta': {'a': 5, 'b': 2},
      };
      final out = takeTheirs(mine, theirs, [
        ['title'],
        ['meta', 'a'],
      ]);
      expect(out, {
        'title': 'Theirs',
        'time': '09:30',
        'meta': {'a': 5, 'b': 2},
      });
      expect(mine['title'], 'Mine', reason: 'input untouched');
    });

    test('removes a field their version deleted', () {
      final out = takeTheirs(
        {'title': 'Mine', 'note': 'x'},
        {'title': 'Mine'},
        [
          ['note'],
        ],
      );
      expect(out, {'title': 'Mine'});
    });
  });

  test('recordLabel picks title / label / name', () {
    expect(recordLabel({'title': ' Dentist '}), 'Dentist');
    expect(recordLabel({'label': 'Rent'}), 'Rent');
    expect(recordLabel({'name': 'Groceries'}), 'Groceries');
    expect(recordLabel({'amount': 3}), '');
  });

  test('tabCollections maps each screen to the data it shows', () {
    expect(tabCollections('finance'), [kWorkspaceCol, kBudgetItemsCol]);
    expect(tabCollections('calendar'), [kWorkspaceCol, kEventsCol]);
    expect(tabCollections('lists'), [kWorkspaceCol, kListItemsCol]);
    expect(tabCollections('weekly'), [kWorkspaceCol, kWeeklyCol]);
    expect(tabCollections('home'), kRecordCollections);
    expect(tabCollections('more'), kRecordCollections);
  });
}
