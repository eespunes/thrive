part of 'package:family_money_management_app/main.dart';

/// Unsaved changes: every record write (create / edit / delete) this device
/// sent to Firestore that the server hasn't acknowledged yet.
///
/// While the app runs, the journal lives in its own on-device document
/// ([kPendingChangesKey]) so changes made without a connection survive the
/// app being closed or killed, and failed saves keep being retried.
///
/// Changes still unsaved when the app starts again are NOT written into the
/// family's data: once online they're moved, as they are, to the user's own
/// staging area in Firestore (`users/{uid}/unsavedChanges/{id}`, see
/// [kUnsavedChangesCollection]), away from the main data. Settings → Unsaved
/// changes lists them; applying one merges it onto the server's current data
/// ([applyPendingChanges]), discarding one just deletes its staging doc. A
/// set-aside change is only ever removed by that review.
const String kPendingChangesKey = 'thrive.pending.v1';

/// Whether a set-aside change can be applied.
enum StagedStatus {
  ready,

  /// The item was deleted by another member meanwhile (delete wins).
  deletedMeanwhile,

  /// The user is no longer in the change's family.
  familyGone,
}

/// The per-user Firestore collection (below `users/{uid}`) holding unsaved
/// changes set aside after a restart, until they're applied or discarded.
const String kUnsavedChangesCollection = 'unsavedChanges';

/// What applying set-aside changes did.
class StagedApplyResult {
  const StagedApplyResult({
    this.applied = 0,
    this.gone = const [],
    this.failed = false,
    this.signedOut = false,
  });

  /// Changes now in the family's data.
  final int applied;

  /// Names of the items deleted by another member meanwhile (dropped).
  final List<String> gone;

  /// The save didn't go through yet (it keeps being retried).
  final bool failed;
  final bool signedOut;
}

enum PendingOp { save, delete }

class PendingChange {
  PendingChange({
    required this.familyId,
    required this.key,
    required this.op,
    required this.at,
    this.record,
    this.serverRecord,
    this.seq = 0,
  });

  final String familyId;

  /// Record key (path below `families/{familyId}/`).
  final String key;
  PendingOp op;

  /// The record as this device wants it ([PendingOp.save] only).
  Map<String, dynamic>? record;

  /// The server's version this change was made from — null when the record
  /// is new (it didn't exist on the server).
  final Map<String, dynamic>? serverRecord;

  /// Epoch millis of the latest change.
  int at;

  /// Bumped each time the change is (re)sent, so the acknowledgement of an
  /// older send never clears a newer change. Not persisted.
  int seq;

  String get id => '$familyId|$key';

  /// Its document id in [kUnsavedChangesCollection] (one per record).
  String get docId => '${familyId}__${key.replaceAll('/', '__')}';

  /// The record as last seen by either side (for labels).
  Map<String, dynamic> get anyRecord =>
      record ?? serverRecord ?? const <String, dynamic>{};

  Map<String, dynamic> toJson() => {
    'familyId': familyId,
    'key': key,
    'op': op.name,
    'at': at,
    if (record != null) 'record': record,
    if (serverRecord != null) 'serverRecord': serverRecord,
  };

  static PendingChange? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final fid = raw['familyId'], key = raw['key'];
    if (fid is! String || key is! String) return null;
    Map<String, dynamic>? map(Object? v) =>
        v is Map ? Map<String, dynamic>.from(jsonClone(v) as Map) : null;
    return PendingChange(
      familyId: fid,
      key: key,
      op: raw['op'] == 'delete' ? PendingOp.delete : PendingOp.save,
      at: (raw['at'] as num?)?.toInt() ?? 0,
      record: map(raw['record']),
      serverRecord: map(raw['serverRecord']),
    );
  }
}

/// Deep copy of a JSON-like value.
Object? jsonClone(Object? v) => v is Map
    ? {for (final e in v.entries) '${e.key}': jsonClone(e.value)}
    : v is List
    ? [for (final x in v) jsonClone(x)]
    : v;

/// The journal of [PendingChange]s, keyed by family + record.
class PendingChanges {
  PendingChanges([Iterable<PendingChange> changes = const []]) {
    for (final c in changes) {
      _byId[c.id] = c;
    }
  }

  final Map<String, PendingChange> _byId = {};
  int _seq = 0;

  bool get isEmpty => _byId.isEmpty;
  int get length => _byId.length;

  /// Every change, oldest first.
  List<PendingChange> get all =>
      _byId.values.toList()..sort((a, b) => a.at.compareTo(b.at));

  List<PendingChange> forFamily(String fid) => [
    for (final c in all)
      if (c.familyId == fid) c,
  ];

  PendingChange? operator [](String id) => _byId[id];

  /// Records that [key] of [fid] is being saved ([record]) or deleted
  /// (`record == null`), starting from the server's [serverRecord]. A change
  /// already pending for the same record keeps its original server version
  /// (what this device last saw before ANY of its unsaved edits). Returns the
  /// send's sequence number, for [settle].
  int record(
    String fid,
    String key, {
    required Map<String, dynamic>? record,
    required Map<String, dynamic>? serverRecord,
    required int now,
  }) {
    final id = '$fid|$key';
    final prev = _byId[id];
    final seq = ++_seq;
    _byId[id] = PendingChange(
      familyId: fid,
      key: key,
      op: record == null ? PendingOp.delete : PendingOp.save,
      at: now,
      record: record == null ? null : jsonClone(record) as Map<String, dynamic>,
      serverRecord: prev != null
          ? prev.serverRecord
          : serverRecord == null
          ? null
          : jsonClone(serverRecord) as Map<String, dynamic>,
      seq: seq,
    );
    return seq;
  }

  /// The send [seq] of [key] in [fid] was acknowledged: forget the change,
  /// unless it changed again since.
  bool settle(String fid, String key, int seq) {
    final id = '$fid|$key';
    if (_byId[id]?.seq != seq) return false;
    _byId.remove(id);
    return true;
  }

  bool remove(String id) => _byId.remove(id) != null;

  /// Adds a change loaded from the staging area, as it is.
  void addStaged(PendingChange c) => _byId[c.id] = c;

  /// Drops every change of family [fid] (e.g. no longer a member).
  bool removeFamily(String fid) {
    final before = _byId.length;
    _byId.removeWhere((_, c) => c.familyId == fid);
    return _byId.length != before;
  }

  void clear() => _byId.clear();

  Map<String, dynamic> toJson(String uid) => {
    'uid': uid,
    'changes': [for (final c in all) c.toJson()],
  };

  /// The journal saved for user [uid] in [raw] (another user's is ignored).
  static PendingChanges fromJson(Object? raw, String uid) {
    if (raw is! Map || raw['uid'] != uid) return PendingChanges();
    return PendingChanges([
      for (final c in (raw['changes'] as List? ?? const []))
        ?PendingChange.fromJson(c),
    ]);
  }
}

/// Re-applies unsaved [changes] onto [local] — this device's records, freshly
/// built from the [server]'s current data (after a restart) — so the next
/// save sends them:
/// - a delete is applied if the record still exists (its key is returned in
///   `deletes`, the explicit delete intents); else it's already done;
/// - a new record is created unless the server already has it (the create
///   landed: done) or it's a line whose note was deleted meanwhile;
/// - an edit is merged field by field onto the server's current version
///   (another member's edits to other fields are kept); if the record was
///   deleted meanwhile, the deletion wins.
///
/// Returns the merged records, the delete intents, the changes still to save
/// (`pending`), those already on the server (`settled`), and those dropped
/// because the record was deleted by someone else (`lost`).
({
  Records local,
  Set<String> deletes,
  List<PendingChange> pending,
  List<PendingChange> settled,
  List<PendingChange> lost,
})
applyPendingChanges({
  required Records server,
  required Records local,
  required Iterable<PendingChange> changes,
}) {
  final out = <String, Map<String, dynamic>>{...local};
  final deletes = <String>{};
  final pending = <PendingChange>[];
  final settled = <PendingChange>[];
  final lost = <PendingChange>[];
  // Notes before their lines: a note changed again after a line was added to
  // it is journaled later, but must exist before the line is placed.
  final ordered = [
    for (final c in changes)
      if (recordKind(c.key) != RecordKind.line) c,
    for (final c in changes)
      if (recordKind(c.key) == RecordKind.line) c,
  ];
  for (final c in ordered) {
    final k = c.key;
    final s = server[k];
    if (c.op == PendingOp.delete) {
      if (s == null) {
        settled.add(c);
      } else {
        out.remove(k);
        deletes.add(k);
        pending.add(c);
      }
      continue;
    }
    final rec = c.record!;
    if (c.serverRecord == null) {
      if (s != null) {
        settled.add(c);
      } else if (recordKind(k) == RecordKind.line &&
          !server.containsKey(_noteKeyOfLine(k)) &&
          !out.containsKey(_noteKeyOfLine(k))) {
        lost.add(c);
      } else {
        out[k] = rec;
        pending.add(c);
      }
      continue;
    }
    if (s == null) {
      lost.add(c);
      continue;
    }
    final merged = rebaseValue(c.serverRecord, s, rec);
    if (jsonEquals(merged, s)) {
      settled.add(c);
    } else {
      out[k] = Map<String, dynamic>.from(merged as Map);
      pending.add(c);
    }
  }
  return (
    local: out,
    deletes: deletes,
    pending: pending,
    settled: settled,
    lost: lost,
  );
}

/// Records that are mere containers (a year / month folder, the calendar /
/// finance roots) — never shown as an unsaved change of their own.
bool isContainerRecord(String key) => switch (recordKind(key)) {
  RecordKind.finance ||
  RecordKind.calendar ||
  RecordKind.calendarMonth ||
  RecordKind.mealsYear ||
  RecordKind.mealsMonth => true,
  _ => false,
};

/// What kind of item record [key] is, for people ("Event", "Note item", …).
String recordKindLabel(String key) => switch (recordKind(key)) {
  RecordKind.kitchen => 'Kitchen settings',
  RecordKind.account => 'Account',
  RecordKind.block => 'Budget block',
  RecordKind.financeMonth => 'Budget month',
  RecordKind.entry => 'Budget entry',
  RecordKind.seriesAnchor || RecordKind.seriesCopy => 'Recurring entry',
  RecordKind.layer => 'Calendar layer',
  RecordKind.eventCategory => 'Event category',
  RecordKind.import => 'Calendar import',
  RecordKind.event || RecordKind.recurringEvent => 'Event',
  RecordKind.mealDay => 'Meal plan',
  RecordKind.note => 'Note',
  RecordKind.line => 'Note item',
  RecordKind.card => 'Card',
  _ => 'Item',
};
