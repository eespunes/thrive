part of 'package:family_money_management_app/main.dart';

/// Pure record layer behind the Firestore sync engine (`family_cloud.dart`).
///
/// Firestore is treated as the family's DATABASE: every piece of shared data
/// is a small document ("record"), the server's version is always adopted,
/// and a device only ever writes the individual fields IT changed. That makes
/// a stale device harmless — it can't push its old copy of anything it didn't
/// touch — which is what lost a member's edits under the old whole-array
/// sections (a partner's phone with an old month re-uploaded it wholesale).
///
/// Layout under `families/{fid}` — one readable tree per feature:
/// - `settings/kitchen`                         kitchen wall options, stars
/// - `finance/main`                             (container)
///   - `accounts/{key}` / `blocks/{key}`        accounts / budget categories
///   - `recurring/{itemId}`                     recurring entries (series
///     anchors; `_month` = the month they start in)
///   - `months/{2026-10}`                       month fields (caps, closed, ...)
///     - `entries/{itemId}`                     one-off entries of that month
///     - `recurring/{itemId}`                   stored occurrences of a series
///       (paid, changed, closed month). Untouched auto-generated occurrences
///       in open months are NOT stored — every device regenerates them (see
///       [isDerivedSeriesCopy])
/// - `calendar/main`                            (container)
///   - `layers/{id}` / `categories/{id}` / `imports/{id}`
///   - `recurring/{eventId}`                    repeating events
///   - `months/{2026-10}/events/{eventId}`      one-off events, by start month
/// - `meals/{2026}/months/{10}/days/{12}`       weekly-plan day
/// - `notes/{listId}` (+ `lines/{lineId}`)      task / shopping list and lines
/// - `cards/{cardId}`                           discount card (photo never synced)
/// - `savedMeals/{mealId}`                      saved-meal library (favourites)
///
/// Collection names are fixed wherever the app needs every document at once,
/// so each one loads with a single collection-group query; every document
/// carries [kFamilyIdField] for that query (and the security rules). Fields
/// starting with `_` are technical (order, block, kind).
///
/// Every record also carries a version, `_v` ([kVersionField], +1 per save,
/// enforced by firestore.rules) and who saved it last, `_by`. Edits are
/// saved in a transaction against the current version, so a concurrent edit
/// by someone else is merged (different fields) or reported (same field —
/// see [planVersionedSave]). Neither is part of the record's content.
///
/// A record key is the document path relative to `families/{fid}`; its
/// SOURCE is the collection id it lives in ([recordSource]). Everything here
/// is a plain function of its inputs (unit-tested in
/// test/cloud_records_test.dart).

const String kSettingsCol = 'settings';
const String kFinanceCol = 'finance';
const String kAccountsCol = 'accounts';
const String kBlocksCol = 'blocks';
const String kRecurringCol = 'recurring';
const String kMonthsCol = 'months';
const String kEntriesCol = 'entries';
const String kCalendarCol = 'calendar';
const String kLayersCol = 'layers';
const String kCategoriesCol = 'categories';
const String kImportsCol = 'imports';
const String kEventsCol = 'events';
const String kMealsCol = 'meals';
const String kDaysCol = 'days';
const String kNotesCol = 'notes';
const String kLinesCol = 'lines';
const String kCardsCol = 'cards';
const String kSavedMealsCol = 'savedMeals';

/// Every collection id holding workspace records. Each is loaded (and
/// listened to) as one collection-group query filtered on [kFamilyIdField];
/// a shared id (`recurring`, `months`) returns every such collection, and
/// [recordKind] tells them apart by path.
const List<String> kRecordCollections = [
  kSettingsCol,
  kFinanceCol,
  kAccountsCol,
  kBlocksCol,
  kRecurringCol,
  kMonthsCol,
  kEntriesCol,
  kCalendarCol,
  kLayersCol,
  kCategoriesCol,
  kImportsCol,
  kEventsCol,
  kMealsCol,
  kDaysCol,
  kNotesCol,
  kLinesCol,
  kCardsCol,
  kSavedMealsCol,
];

/// The record collections a top-level tab shows, reloaded from the server
/// when that tab is opened (Home and More summarize everything).
List<String> tabCollections(String tab) => switch (tab) {
  'finance' => const [
    kSettingsCol,
    kFinanceCol,
    kAccountsCol,
    kBlocksCol,
    kRecurringCol,
    kMonthsCol,
    kEntriesCol,
  ],
  'calendar' => const [
    kSettingsCol,
    kCalendarCol,
    kLayersCol,
    kCategoriesCol,
    kImportsCol,
    kRecurringCol,
    kMonthsCol,
    kEventsCol,
  ],
  'lists' => const [kSettingsCol, kNotesCol, kLinesCol],
  'weekly' => const [
    kSettingsCol,
    kMealsCol,
    kMonthsCol,
    kDaysCol,
    kSavedMealsCol,
    // The day view ticks dinner ingredients onto Groceries.
    kNotesCol,
    kLinesCol,
  ],
  _ => kRecordCollections,
};

/// Containers whose records are only written once their collection loaded
/// (a placeholder's defaults must never be created over real data).
const Set<String> kContainerCollections = {
  kSettingsCol,
  kFinanceCol,
  kAccountsCol,
  kBlocksCol,
  kMonthsCol,
  kCalendarCol,
  kLayersCol,
  kCategoriesCol,
  kImportsCol,
  kMealsCol,
  kCardsCol,
  kSavedMealsCol,
};

const String kKitchenKey = 'settings/kitchen';
const String kFinanceKey = 'finance/main';
const String kCalendarKey = 'calendar/main';

typedef Records = Map<String, Map<String, dynamic>>;

/// Per-document save counter. Every write bumps it by exactly one (enforced
/// by firestore.rules), so a device knows which version of a record it last
/// saw and whether its own save landed. Never part of the record payload.
const String kVersionField = '_v';

/// Member id (uid) of whoever saved the document last.
const String kUpdatedByField = '_by';

/// The family a record belongs to (every record doc carries it — it's what
/// the collection-group queries filter on). Never part of the payload.
const String kFamilyIdField = 'familyId';

/// The [kVersionField] of raw document [raw] (0 when it never had one).
int recordVersion(Map? raw) => _int(raw?[kVersionField]) ?? 0;

/// The collection id record [key] lives in (its last collection segment).
String recordSource(String key) {
  final parts = key.split('/');
  return parts.length < 2 ? '' : parts[parts.length - 2];
}

/// A Firestore-legal document id derived from [raw] (no `/`, not `.`/`..`).
String safeDocId(String raw) {
  final s = raw.replaceAll('/', '_');
  if (s.isEmpty || s == '.' || s == '..') return '_$s';
  return s;
}

/// What a record key points at.
enum RecordKind {
  kitchen,
  finance,
  account,
  block,
  seriesAnchor,
  financeMonth,
  entry,
  seriesCopy,
  calendar,
  layer,
  eventCategory,
  import,
  recurringEvent,
  calendarMonth,
  event,
  mealsYear,
  mealsMonth,
  mealDay,
  note,
  line,
  card,
  savedMeal,
  unknown,
}

/// The [RecordKind] of [key] (by path shape).
RecordKind recordKind(String key) {
  final p = key.split('/');
  switch (p.length) {
    case 2:
      return switch ((p[0], p[1])) {
        (kSettingsCol, 'kitchen') => RecordKind.kitchen,
        (kFinanceCol, 'main') => RecordKind.finance,
        (kCalendarCol, 'main') => RecordKind.calendar,
        (kMealsCol, _) => RecordKind.mealsYear,
        (kNotesCol, _) => RecordKind.note,
        (kCardsCol, _) => RecordKind.card,
        (kSavedMealsCol, _) => RecordKind.savedMeal,
        _ => RecordKind.unknown,
      };
    case 4:
      if (p[0] == kFinanceCol && p[1] == 'main') {
        return switch (p[2]) {
          kAccountsCol => RecordKind.account,
          kBlocksCol => RecordKind.block,
          kRecurringCol => RecordKind.seriesAnchor,
          kMonthsCol => RecordKind.financeMonth,
          _ => RecordKind.unknown,
        };
      }
      if (p[0] == kCalendarCol && p[1] == 'main') {
        return switch (p[2]) {
          kLayersCol => RecordKind.layer,
          kCategoriesCol => RecordKind.eventCategory,
          kImportsCol => RecordKind.import,
          kRecurringCol => RecordKind.recurringEvent,
          kMonthsCol => RecordKind.calendarMonth,
          _ => RecordKind.unknown,
        };
      }
      if (p[0] == kMealsCol && p[2] == kMonthsCol) return RecordKind.mealsMonth;
      if (p[0] == kNotesCol && p[2] == kLinesCol) return RecordKind.line;
      return RecordKind.unknown;
    case 6:
      if (p[0] == kFinanceCol && p[1] == 'main' && p[2] == kMonthsCol) {
        return switch (p[4]) {
          kEntriesCol => RecordKind.entry,
          kRecurringCol => RecordKind.seriesCopy,
          _ => RecordKind.unknown,
        };
      }
      if (p[0] == kCalendarCol &&
          p[1] == 'main' &&
          p[2] == kMonthsCol &&
          p[4] == kEventsCol) {
        return RecordKind.event;
      }
      if (p[0] == kMealsCol && p[2] == kMonthsCol && p[4] == kDaysCol) {
        return RecordKind.mealDay;
      }
      return RecordKind.unknown;
  }
  return RecordKind.unknown;
}

/// Whether record [key] is a calendar event (repeating or one-off).
bool isEventRecord(String key) {
  final k = recordKind(key);
  return k == RecordKind.event || k == RecordKind.recurringEvent;
}

/// `2026-10` for year [year] and month key [monthKey] (see [kMonthKeys]).
String monthDocId(int year, String monthKey) {
  final i = kMonthKeys.indexOf(monthKey);
  return '$year-${i < 0 ? safeDocId(monthKey) : '${i + 1}'.padLeft(2, '0')}';
}

/// The (year, month key) of a [monthDocId], or null when malformed.
(int, String)? parseMonthDocId(String id) {
  final sep = id.indexOf('-');
  if (sep <= 0) return null;
  final y = int.tryParse(id.substring(0, sep));
  if (y == null) return null;
  final rest = id.substring(sep + 1);
  final m = int.tryParse(rest);
  if (m != null && m >= 1 && m <= kMonthKeys.length && rest.length == 2) {
    return (y, kMonthKeys[m - 1]);
  }
  return (y, rest);
}

final RegExp _kRecordDateRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

// ------------------------------------------------------------ build records

Map<String, dynamic> _kitchenPayload(Workspace ws) => {
  if (ws.starsMap.isNotEmpty) 'starsMap': ws.starsMap,
  'kitchenEnabled': ws.kitchenEnabled,
  if (ws.picMembers.isNotEmpty) 'picMembers': ws.picMembers,
  'kitchenLayerFilter': ws.kitchenLayerFilter,
};

Map<String, dynamic> _monthPayload(MonthData m) => {
  ...m.toJson()..remove('blocks'),
  '_blocks': m.blocks.keys.toList(),
};

/// The series id of a budget item, as `_syncRecurringSeries` resolves it.
String? _seriesIdOf(ExpenseItem it) {
  final raw = it.seriesId?.trim();
  if (raw != null && raw.isNotEmpty) return raw;
  return it.recurring ? it.id : null;
}

/// For every recurring series in [ws], the blocks holding one of its
/// explicit anchors (a manual, non-exception, still-recurring occurrence) —
/// the items `_syncRecurringSeries` regenerates the series from.
Map<String, Set<String>> seriesAnchorBlocks(Workspace ws) {
  final out = <String, Set<String>>{};
  for (final months in ws.data.values) {
    for (final m in months.values) {
      for (final b in m.blocks.entries) {
        for (final it in b.value) {
          if (it.generated || it.exception || !it.recurring) continue;
          final sid = _seriesIdOf(it);
          if (sid != null) (out[sid] ??= {}).add(b.key);
        }
      }
    }
  }
  return out;
}

/// Whether [it], in block [block] of [month], is an untouched auto-generated
/// occurrence of a recurring series: an open month's copy that was never
/// paid, flagged or edited, whose series has an explicit anchor in that same
/// block ([anchors], from [seriesAnchorBlocks]). Such a copy is fully derived
/// from its anchor (same deterministic id on every device — see
/// `_syncRecurringSeries`), so it is never stored in Firestore; every device
/// regenerates it locally. Copies in closed months are frozen history (never
/// regenerated) and stay stored, as do copies of a series without an
/// explicit anchor (the sync would fall back to the copy itself as anchor).
bool isDerivedSeriesCopy(
  ExpenseItem it,
  MonthData month,
  String block,
  Map<String, Set<String>> anchors,
) {
  if (!it.generated || month.closed) return false;
  if (it.paid || it.reviewDay || it.exception) return false;
  final sid = _seriesIdOf(it);
  return sid != null && (anchors[sid]?.contains(block) ?? false);
}

/// Record key of budget item [it] stored in month [monthId]: a series
/// anchor lives in `finance/main/recurring`, an occurrence of a series in
/// the month's `recurring`, anything else in the month's `entries`.
String budgetItemKey(ExpenseItem it, String monthId) {
  final id = safeDocId(it.id);
  if (it.generated || it.exception) {
    return '$kFinanceKey/$kMonthsCol/$monthId/$kRecurringCol/$id';
  }
  if (it.recurring) return '$kFinanceKey/$kRecurringCol/$id';
  return '$kFinanceKey/$kMonthsCol/$monthId/$kEntriesCol/$id';
}

/// The month doc id (`2026-10`) a calendar event's [date] falls in.
String _eventMonthId(String date) {
  final m = _kRecordDateRe.firstMatch(date);
  return m == null ? 'undated' : '${m.group(1)}-${m.group(2)}';
}

/// Record key of calendar event [e]: repeating events live in
/// `calendar/main/recurring`, one-off ones under the month they start in.
String eventRecordKey(CalendarEvent e) {
  final id = safeDocId(e.id);
  if (e.recur != 'none') return '$kCalendarKey/$kRecurringCol/$id';
  return '$kCalendarKey/$kMonthsCol/${_eventMonthId(e.date)}/$kEventsCol/$id';
}

/// Every key in [records] holding calendar event [eventId].
List<String> eventKeysById(Records records, String eventId) => [
  for (final e in records.entries)
    if (isEventRecord(e.key) && '${e.value['id']}' == eventId) e.key,
];

/// Record key of a note (task / shopping list) [listId].
String listMetaKey(String listId) => '$kNotesCol/${safeDocId(listId)}';

/// Record key of line [itemId] of note [listId].
String listItemKey(String listId, String itemId) =>
    '${listMetaKey(listId)}/$kLinesCol/${safeDocId(itemId)}';

/// The note key a line [key] belongs to.
String _noteKeyOfLine(String key) =>
    key.substring(0, key.indexOf('/$kLinesCol/'));

/// Splits [ws] into its records (not yet normalized — see [normalizedRecords]).
/// Derived recurring copies ([isDerivedSeriesCopy]) are left out, and a
/// budget item's `_order` counts only the items that ARE stored, so adding
/// or dropping a derived copy never reorders (rewrites) the stored ones.
Records workspaceRecords(Workspace ws) {
  final out = <String, Map<String, dynamic>>{};
  // Ids are unique in practice; never let a duplicate collapse two records
  // into one doc.
  String put(String key, Map<String, dynamic> rec) {
    var k = key;
    while (out.containsKey(k)) {
      k = '$k~';
    }
    out[k] = rec;
    return k;
  }

  out[kKitchenKey] = _kitchenPayload(ws);
  out[kFinanceKey] = {};
  for (final (i, a) in ws.accounts.indexed) {
    put('$kFinanceKey/$kAccountsCol/${safeDocId(a.key)}', {
      ...a.toJson(),
      '_order': i,
    });
  }
  for (final (i, c) in ws.cats.indexed) {
    put('$kFinanceKey/$kBlocksCol/${safeDocId(c.key)}', {
      ...c.toJson(),
      '_order': i,
    });
  }
  final anchors = seriesAnchorBlocks(ws);
  for (final y in ws.data.entries) {
    for (final m in y.value.entries) {
      final monthId = monthDocId(y.key, m.key);
      out['$kFinanceKey/$kMonthsCol/$monthId'] = _monthPayload(m.value);
      for (final b in m.value.blocks.entries) {
        final stored = [
          for (final it in b.value)
            if (!isDerivedSeriesCopy(it, m.value, b.key, anchors)) it,
        ];
        for (final (i, it) in stored.indexed) {
          final key = budgetItemKey(it, monthId);
          put(key, {
            ...it.toJson(),
            if (recordKind(key) == RecordKind.seriesAnchor) '_month': monthId,
            '_block': b.key,
            '_order': i,
          });
        }
      }
    }
  }

  out[kCalendarKey] = {};
  for (final (i, l) in ws.calendarLayers.indexed) {
    put('$kCalendarKey/$kLayersCol/${safeDocId(l.id)}', {
      ...l.toJson(),
      '_order': i,
    });
  }
  for (final (i, c) in ws.eventCategories.indexed) {
    put('$kCalendarKey/$kCategoriesCol/${safeDocId(c.id)}', {
      ...c.toJson(),
      '_order': i,
    });
  }
  for (final (i, cal) in ws.importedCalendars.indexed) {
    put('$kCalendarKey/$kImportsCol/${safeDocId(cal.id)}', {
      ...cal.toJson(),
      '_order': i,
    });
  }
  for (final e in ws.events) {
    final key = eventRecordKey(e);
    if (recordKind(key) == RecordKind.event) {
      out[key.substring(0, key.indexOf('/$kEventsCol/'))] = {};
    }
    out[key] = e.toJson();
  }

  for (final e in ws.weeklyPlan.entries) {
    final m = _kRecordDateRe.firstMatch(e.key);
    final (y, mo, d) = m == null
        ? ('undated', '00', safeDocId(e.key))
        : (m.group(1)!, m.group(2)!, m.group(3)!);
    out['$kMealsCol/$y'] = {};
    out['$kMealsCol/$y/$kMonthsCol/$mo'] = {};
    put('$kMealsCol/$y/$kMonthsCol/$mo/$kDaysCol/$d', {
      ...e.value.toJson(),
      if (m == null) '_key': e.key,
    });
  }

  void note(
    int order,
    Map<String, dynamic> meta,
    String type,
    String kind,
    List<Map<String, dynamic>> lines,
  ) {
    final key = put(listMetaKey('${meta['id']}'), {
      ...meta,
      'type': type,
      '_order': order,
    });
    for (final (i, x) in lines.indexed) {
      put('$key/$kLinesCol/${safeDocId('${x['id']}')}', {
        ...x,
        '_kind': kind,
        '_order': i,
      });
    }
  }

  for (final (i, l) in ws.taskLists.indexed) {
    note(i, l.toJson()..remove('tasks'), 'tasks', 'task', [
      for (final t in l.tasks) t.toJson(),
    ]);
  }
  for (final (i, l) in ws.shoppingLists.indexed) {
    note(i, l.toJson()..remove('items'), 'shopping', 'shop', [
      for (final it in l.items) it.toJson(),
    ]);
  }
  // Card photos are local-only (issue #234) and never synced.
  for (final (i, c) in ws.cards.indexed) {
    put('$kCardsCol/${safeDocId(c.id)}', {
      ...c.toJson(includePhoto: false),
      '_order': i,
    });
  }
  for (final (i, m) in ws.savedMeals.indexed) {
    put('$kSavedMealsCol/${safeDocId(m.id)}', {...m.toJson(), '_order': i});
  }
  return out;
}

// ---------------------------------------------------------------- normalize

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

/// Canonical form of one record, as the models would re-emit it, or null when
/// [raw] isn't a current-format record (legacy/unknown docs). Both sides of
/// every comparison go through this, so serialization details (key order,
/// int-vs-double, defaults a model fills in) never read as a change.
Map<String, dynamic>? normalizeRecord(String key, Map raw) {
  // Older versions only marked deleted events / notes / lines (`deletion`)
  // instead of deleting them: those are gone.
  if (raw['deletion'] is Map && isGuardedRecord(key)) return null;
  return _normalizeRecord(key, raw);
}

Map<String, dynamic>? _normalizeRecord(String key, Map raw) {
  final kind = recordKind(key);
  final j = Map<String, dynamic>.from(raw)
    ..remove('updatedAtMillis')
    ..remove('updatedAt')
    ..remove(kVersionField)
    ..remove(kUpdatedByField)
    ..remove(kFamilyIdField);
  final order = _int(j['_order']) ?? 0;
  switch (kind) {
    case RecordKind.kitchen:
      return _kitchenPayload(Workspace.fromJson({...j, 'data': const {}}));
    case RecordKind.finance ||
        RecordKind.calendar ||
        RecordKind.calendarMonth ||
        RecordKind.mealsYear ||
        RecordKind.mealsMonth:
      return {};
    case RecordKind.account:
      return {...Account.fromJson(j).toJson(), '_order': order};
    case RecordKind.block:
      return {...Category.fromJson(j).toJson(), '_order': order};
    case RecordKind.seriesAnchor || RecordKind.entry || RecordKind.seriesCopy:
      final b = j['_block']?.toString();
      final m = j['_month']?.toString();
      if (b == null || (kind == RecordKind.seriesAnchor && m == null)) {
        return null;
      }
      return {
        ...ExpenseItem.fromJson(j).toJson(),
        if (kind == RecordKind.seriesAnchor) '_month': m,
        '_block': b,
        '_order': order,
      };
    case RecordKind.financeMonth:
      final month = MonthData.fromJson(j..remove('blocks'));
      return {
        ..._monthPayload(month),
        '_blocks': j['_blocks'] is List
            ? [for (final k in j['_blocks'] as List) k.toString()]
            : const <String>[],
      };
    case RecordKind.layer:
      return {...CalendarLayerDef.fromJson(j).toJson(), '_order': order};
    case RecordKind.eventCategory:
      return {...EventCategory.fromJson(j).toJson(), '_order': order};
    case RecordKind.import:
      return {...ImportedCalendar.fromJson(j).toJson(), '_order': order};
    case RecordKind.event || RecordKind.recurringEvent:
      return CalendarEvent.fromJson(j).toJson();
    case RecordKind.mealDay:
      return {
        ...DayPlan.fromJson(j).toJson(),
        if (j['_key'] != null) '_key': '${j['_key']}',
      };
    case RecordKind.note:
      final type = j['type'];
      if (type == 'tasks') {
        return {
          ...TaskList.fromJson({...j, 'tasks': const []}).toJson()
            ..remove('tasks'),
          'type': type,
          '_order': order,
        };
      }
      if (type == 'shopping') {
        return {
          ...ShoppingList.fromJson({...j, 'items': const []}).toJson()
            ..remove('items'),
          'type': type,
          '_order': order,
        };
      }
      return null;
    case RecordKind.line:
      final k = j['_kind'];
      if (k != 'task' && k != 'shop') return null;
      return {
        ...(k == 'task'
            ? ListTask.fromJson(j).toJson()
            : ShopItem.fromJson(j).toJson()),
        '_kind': k,
        '_order': order,
      };
    case RecordKind.card:
      return {
        ...DiscountCard.fromJson(j).toJson(includePhoto: false),
        '_order': order,
      };
    case RecordKind.savedMeal:
      return {...SavedMeal.fromJson(j).toJson(), '_order': order};
    case RecordKind.unknown:
      return null;
  }
}

/// [workspaceRecords] of [ws], every record normalized.
Records normalizedRecords(Workspace ws) => {
  for (final e in workspaceRecords(ws).entries)
    e.key: normalizeRecord(e.key, e.value) ?? e.value,
};

// ------------------------------------------------------- records → workspace

int _byOrder(Map<String, dynamic> a, Map<String, dynamic> b, String k) {
  final c = (_int(a[k]) ?? 1 << 30).compareTo(_int(b[k]) ?? 1 << 30);
  return c != 0 ? c : '${a['id']}'.compareTo('${b['id']}');
}

Map<String, dynamic> _stripInternal(Map<String, dynamic> m) => {
  for (final e in m.entries)
    if (!e.key.startsWith('_')) e.key: e.value,
};

/// Reassembles a [Workspace] from [records] (keys as in [workspaceRecords]).
/// Unknown keys are ignored; items whose month is missing still load (the
/// month is created); lines whose note is missing can't be represented —
/// see [orphanListItems].
Workspace workspaceFromRecords(Records records) {
  final j = <String, dynamic>{...?records[kKitchenKey]};
  final accounts = <Map<String, dynamic>>[];
  final cats = <Map<String, dynamic>>[];
  final layers = <Map<String, dynamic>>[];
  final eventCats = <Map<String, dynamic>>[];
  final months = <int, Map<String, Map<String, dynamic>>>{};
  final itemsByMonth = <String, List<Map<String, dynamic>>>{};
  final taskLists = <(String, Map<String, dynamic>)>[];
  final shopLists = <(String, Map<String, dynamic>)>[];
  final lines = <String, List<Map<String, dynamic>>>{};
  final cards = <Map<String, dynamic>>[];
  final savedMeals = <Map<String, dynamic>>[];
  final imports = <Map<String, dynamic>>[];
  final weekly = <String, dynamic>{};
  final events = <String, Map<String, dynamic>>{};

  void monthOf(int y, String mk) =>
      months.putIfAbsent(y, () => {}).putIfAbsent(mk, () => {});

  for (final key in records.keys.toList()..sort()) {
    final r = records[key]!;
    final p = key.split('/');
    final kind = recordKind(key);
    switch (kind) {
      case RecordKind.account:
        accounts.add(r);
      case RecordKind.block:
        cats.add(r);
      case RecordKind.layer:
        layers.add(r);
      case RecordKind.eventCategory:
        eventCats.add(r);
      case RecordKind.import:
        imports.add(r);
      case RecordKind.card:
        cards.add(r);
      case RecordKind.savedMeal:
        savedMeals.add(r);
      case RecordKind.financeMonth:
        final ym = parseMonthDocId(p[3]);
        if (ym == null) continue;
        monthOf(ym.$1, ym.$2);
        months[ym.$1]![ym.$2] = r;
      case RecordKind.seriesAnchor || RecordKind.entry || RecordKind.seriesCopy:
        final ym = parseMonthDocId(
          kind == RecordKind.seriesAnchor ? '${r['_month']}' : p[3],
        );
        if (ym == null) continue;
        (itemsByMonth['${ym.$1}|${ym.$2}'] ??= []).add(r);
        monthOf(ym.$1, ym.$2);
      case RecordKind.event || RecordKind.recurringEvent:
        // One event, one doc — a stale copy left at an old path (moved
        // meanwhile) never duplicates it.
        events.putIfAbsent('${r['id']}', () => r);
      case RecordKind.mealDay:
        weekly['${r['_key'] ?? '${p[1]}-${p[3]}-${p[5]}'}'] = _stripInternal(r);
      case RecordKind.note:
        if (r['type'] == 'tasks') taskLists.add((key, r));
        if (r['type'] == 'shopping') shopLists.add((key, r));
      case RecordKind.line:
        (lines[_noteKeyOfLine(key)] ??= []).add(r);
      default:
        break;
    }
  }

  List<Map<String, dynamic>> sorted(List<Map<String, dynamic>> xs) => [
    for (final x in xs..sort((a, b) => _byOrder(a, b, '_order')))
      _stripInternal(x),
  ];

  j['accounts'] = sorted(accounts);
  j['cats'] = sorted(cats);
  j['calendarLayers'] = sorted(layers);
  j['eventCategories'] = sorted(eventCats);

  final data = <String, dynamic>{};
  for (final y in months.keys.toList()..sort()) {
    final ym = <String, dynamic>{};
    final keys = months[y]!.keys.toList()
      ..sort((a, b) {
        final ia = kMonthKeys.indexOf(a), ib = kMonthKeys.indexOf(b);
        return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
      });
    for (final mk in keys) {
      final meta = months[y]![mk]!;
      final blocks = <String, List<Map<String, dynamic>>>{
        for (final k in (meta['_blocks'] as List? ?? const [])) '$k': [],
      };
      final items = (itemsByMonth['$y|$mk'] ?? [])
        ..sort((a, b) => _byOrder(a, b, '_order'));
      for (final it in items) {
        (blocks['${it['_block']}'] ??= []).add(_stripInternal(it));
      }
      ym[mk] = {..._stripInternal(meta), 'blocks': blocks};
    }
    data['$y'] = ym;
  }
  j['data'] = data;

  List<Map<String, dynamic>> lists(
    List<(String, Map<String, dynamic>)> metas,
    String itemsKey,
  ) {
    metas.sort((a, b) => _byOrder(a.$2, b.$2, '_order'));
    return [
      for (final (key, l) in metas)
        {
          ..._stripInternal(l)..remove('type'),
          itemsKey: sorted(lines[key] ?? []),
        },
    ];
  }

  j['taskLists'] = lists(taskLists, 'tasks');
  j['shoppingLists'] = lists(shopLists, 'items');
  j['cards'] = sorted(cards);
  j['savedMeals'] = sorted(savedMeals);
  j['importedCalendars'] = sorted(imports);
  j['weeklyPlan'] = weekly;
  // Id order: stable no matter which month/recurring doc holds an event.
  j['events'] = [for (final id in events.keys.toList()..sort()) events[id]!];
  return Workspace.fromJson(j);
}

// --------------------------------------------------------- legacy documents

/// Normalized records embedded in legacy (pre-record) workspace section docs
/// [legacyDocs] (docId → raw) and/or a legacy family-doc `workspace` [blob].
/// Settings (accounts, categories, layers, kitchen) are only taken from the
/// blob — legacy section docs never carried them.
Records legacyRecords(Map<String, Map> legacyDocs, {Map? blob}) {
  final out = <String, Map<String, dynamic>>{};
  if (blob != null) {
    out.addAll(
      normalizedRecords(Workspace.fromJson(Map<String, dynamic>.from(blob))),
    );
  }
  if (legacyDocs.isNotEmpty) {
    final ws = workspaceFromSections({
      for (final e in legacyDocs.entries)
        e.key: Map<String, dynamic>.from(e.value),
    });
    if (ws != null) {
      final recs = normalizedRecords(ws)
        ..removeWhere(
          (k, _) => const {
            RecordKind.kitchen,
            RecordKind.account,
            RecordKind.block,
            RecordKind.layer,
            RecordKind.eventCategory,
          }.contains(recordKind(k)),
        );
      out.addAll(recs);
    }
  }
  return out;
}

// ------------------------------------------------------------ deep equality

/// Structural JSON equality: map key order is irrelevant and numbers compare
/// by value (`900 == 900.0`).
bool jsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is num && b is num) return a == b;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !jsonEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

// ------------------------------------------------------------- patch/rebase

/// Marker for "field absent" in [rebaseValue].
const Object kAbsent = _Absent();

class _Absent {
  const _Absent();
}

/// One field-level write: [path] segments into the doc, and the new value, or
/// [delete] for a removed field.
class FieldChange {
  const FieldChange(this.path, this.value, {this.delete = false});
  final List<String> path;
  final Object? value;
  final bool delete;
}

/// The field-level changes turning [base] into [local]. Nested maps recurse
/// (so e.g. two members setting caps of different categories both land);
/// lists and scalars are replaced whole.
List<FieldChange> recordPatch(
  Map base,
  Map local, [
  List<String> prefix = const [],
]) {
  final out = <FieldChange>[];
  for (final k in {...base.keys, ...local.keys}) {
    final path = [...prefix, '$k'];
    final hasB = base.containsKey(k), hasL = local.containsKey(k);
    if (hasB && hasL && jsonEquals(base[k], local[k])) continue;
    if (!hasL) {
      out.add(FieldChange(path, null, delete: true));
    } else if (hasB && base[k] is Map && local[k] is Map) {
      out.addAll(recordPatch(base[k] as Map, local[k] as Map, path));
    } else {
      out.add(FieldChange(path, local[k]));
    }
  }
  return out;
}

/// Three-way merge of one value: [o] = last server version this device had,
/// [n] = the server's new version, [l] = this device's current value (any of
/// them may be [kAbsent]).
///
/// - Untouched locally (`l == o`) → the server wins, always.
/// - Server unchanged (`n == o`) → our pending local edit stays.
/// - Both changed → merged per map key where possible (different fields both
///   survive); a genuine same-field conflict keeps the local pending edit,
///   which the next persist writes (last-writer-wins on that one field).
Object? rebaseValue(Object? o, Object? n, Object? l) {
  if (jsonEquals(l, o)) return n;
  if (jsonEquals(n, o)) return l;
  if (o is Map && n is Map && l is Map) {
    final out = <String, dynamic>{};
    for (final k in {...o.keys, ...n.keys, ...l.keys}) {
      final v = rebaseValue(
        o.containsKey(k) ? o[k] : kAbsent,
        n.containsKey(k) ? n[k] : kAbsent,
        l.containsKey(k) ? l[k] : kAbsent,
      );
      if (!identical(v, kAbsent)) out['$k'] = v;
    }
    return out;
  }
  return l;
}

/// Rebases this device's [local] records onto a server change: for every key
/// in [changed], [oldBase] → [newBase] is applied unless this device has its
/// own pending edit of that record (see [rebaseValue]). Keys not in [changed]
/// keep their local value. Returns the merged record set.
Records rebaseRecords({
  required Records oldBase,
  required Records newBase,
  required Records local,
  required Iterable<String> changed,
}) {
  final out = <String, Map<String, dynamic>>{...local};
  for (final k in changed) {
    // Deleted on the server: a deletion always wins over a pending edit.
    if (oldBase.containsKey(k) && !newBase.containsKey(k)) {
      out.remove(k);
      continue;
    }
    final v = rebaseValue(
      oldBase[k] ?? kAbsent,
      newBase[k] ?? kAbsent,
      local[k] ?? kAbsent,
    );
    if (identical(v, kAbsent)) {
      out.remove(k);
    } else {
      out[k] = Map<String, dynamic>.from(v as Map);
    }
  }
  return out;
}

/// Field paths that BOTH this device and someone else changed, to different
/// values, since [o] (the version this device last saw): [n] is the server's
/// current version, [l] this device's. Mirrors [rebaseValue]'s merge — maps
/// recurse, so edits to different fields never conflict.
List<List<String>> conflictPaths(
  Object? o,
  Object? n,
  Object? l, [
  List<String> prefix = const [],
]) {
  if (jsonEquals(l, o) || jsonEquals(n, o) || jsonEquals(n, l)) return [];
  if (o is Map && n is Map && l is Map) {
    return [
      for (final k in {...o.keys, ...n.keys, ...l.keys})
        ...conflictPaths(
          o.containsKey(k) ? o[k] : kAbsent,
          n.containsKey(k) ? n[k] : kAbsent,
          l.containsKey(k) ? l[k] : kAbsent,
          [...prefix, '$k'],
        ),
    ];
  }
  return [prefix];
}

/// What a versioned save of one record must write, given [prev] (the
/// version this device last saw), [server] (what the server holds right
/// now, read inside the save's transaction) and [local] (this device's
/// copy): the three-way [merged] record, the field-level [patch] taking
/// [server] to it, and the [conflicts] — fields both sides changed, where
/// this device's value wins (the caller tells the user and offers theirs).
({
  Map<String, dynamic> merged,
  List<FieldChange> patch,
  List<List<String>> conflicts,
})
planVersionedSave({
  required Map<String, dynamic> prev,
  required Map<String, dynamic> server,
  required Map<String, dynamic> local,
}) {
  final merged = Map<String, dynamic>.from(
    rebaseValue(prev, server, local) as Map,
  );
  return (
    merged: merged,
    patch: recordPatch(server, merged),
    conflicts: conflictPaths(prev, server, local),
  );
}

/// [rec] with the value at every path in [paths] taken from [theirs] (or
/// removed where [theirs] lacks it) — "use their version" of a conflict.
Map<String, dynamic> takeTheirs(
  Map<String, dynamic> rec,
  Map<String, dynamic> theirs,
  List<List<String>> paths,
) {
  final out = json.decode(json.encode(rec)) as Map<String, dynamic>;
  for (final path in paths) {
    if (path.isEmpty) return Map<String, dynamic>.from(theirs);
    Map? dst = out;
    Object? src = theirs;
    for (final seg in path.take(path.length - 1)) {
      src = src is Map ? src[seg] : null;
      final next = dst?[seg];
      if (next is! Map) {
        dst = null;
        break;
      }
      dst = next;
    }
    if (dst == null) continue;
    final last = path.last;
    if (src is Map && src.containsKey(last)) {
      dst[last] = src[last];
    } else {
      dst.remove(last);
    }
  }
  return out;
}

/// A human label for record [rec] (event title, budget entry label, note or
/// line name), or '' when it has none.
String recordLabel(Map<String, dynamic> rec) {
  for (final k in const ['title', 'label', 'name']) {
    final v = rec[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

/// Lines in [view] whose note is in neither [view] nor [local] — e.g. the
/// lines arrived before their note doc. [workspaceFromRecords] can't place
/// them, so callers add these back to the local record set: they must never
/// look "deleted locally" (and be deleted from the server), and must reappear
/// once their note arrives.
Records orphanListItems(Records view, Records local) => {
  for (final e in view.entries)
    if (recordKind(e.key) == RecordKind.line &&
        !local.containsKey(e.key) &&
        !view.containsKey(_noteKeyOfLine(e.key)) &&
        !local.containsKey(_noteKeyOfLine(e.key)))
      e.key: e.value,
};

/// Whether [key] is a note (task / shopping list) or one of its lines.
bool isListRecord(String key) {
  final k = recordKind(key);
  return k == RecordKind.note || k == RecordKind.line;
}

/// Notes, their lines and calendar events are only ever deleted from the
/// server when the user explicitly deleted them on this device (see
/// [unintendedDeletes]); deleting a note deletes its lines with it.
bool isGuardedRecord(String key) => isListRecord(key) || isEventRecord(key);

/// The subset of [deletes] (keys in [base]) that would remove a guarded
/// record ([isGuardedRecord]) nobody deleted: one whose key — or, for a list
/// line, whose list — isn't in [intents]. A list or an event vanishing from
/// the in-memory workspace for any other reason (a stale copy, a reverted
/// write, a rebase gone wrong) must never wipe it for the whole family;
/// callers skip these deletes and restore the records locally instead.
///
/// A record [local] still holds under another key (an event whose date or
/// repetition changed, so its path did) has merely moved: its old doc may go.
Records unintendedDeletes(
  Records base,
  Iterable<String> deletes,
  Set<String> intents, {
  Records local = const {},
}) {
  String group(String key) =>
      isEventRecord(key) ? 'event' : '${recordKind(key)}';
  final moved = {
    for (final e in local.entries)
      if (isGuardedRecord(e.key)) '${group(e.key)}|${e.value['id']}',
  };
  bool intended(String key) {
    var k = key;
    while (k.endsWith('~')) {
      k = k.substring(0, k.length - 1);
    }
    if (intents.contains(key) || intents.contains(k)) return true;
    final rec = base[key];
    if (rec != null && moved.contains('${group(key)}|${rec['id']}')) {
      return true;
    }
    return recordKind(key) == RecordKind.line &&
        intents.contains(_noteKeyOfLine(key));
  }

  return {
    for (final k in deletes)
      if (isGuardedRecord(k) && base[k] != null && !intended(k)) k: base[k]!,
  };
}

/// Fields that identify where a record lives; always written on create.
const Set<String> _kIdentityKeys = {
  'id',
  'key',
  'type',
  '_month',
  '_block',
  '_kind',
  '_key',
};

/// The record this device would hold at [key] had it never seen the server's
/// doc: the model defaults for [local]'s identity (ordering fields are taken
/// from [local] — order is never treated as an edit). A record absent from
/// the base is rebased against this, so only fields this device really
/// changed can override what another member already wrote.
Map<String, dynamic> placeholderRecord(String key, Map<String, dynamic> local) {
  if (key == kKitchenKey) {
    return normalizedRecords(Workspace.empty())[kKitchenKey]!;
  }
  Map<String, dynamic> d;
  try {
    d = {
      ...?normalizeRecord(key, {
        for (final k in _kIdentityKeys)
          if (local.containsKey(k)) k: local[k],
      }),
    };
  } catch (_) {
    d = {};
  }
  for (final k in const ['_order', '_blocks']) {
    if (local.containsKey(k)) {
      d[k] = local[k];
    } else {
      d.remove(k);
    }
  }
  return d;
}

/// The doc body for CREATING [local] at [key] with `SetOptions(merge: true)`:
/// identity + ordering fields and every field that differs from
/// [placeholderRecord]. Doc ids can be shared across devices (a meal day,
/// a budget month, a generated recurring item), so a create may land on a
/// doc another member already wrote; this writes only what this device
/// actually set and leaves their other fields intact. Reading it back yields
/// [local] again (missing fields are exactly the model defaults).
Map<String, dynamic> createPayload(
  String key,
  Map<String, dynamic> local, {
  bool includeBlocks = false,
}) {
  final ph = placeholderRecord(key, local);
  return {
    for (final e in local.entries)
      if (_kIdentityKeys.contains(e.key) ||
          e.key == '_order' ||
          (e.key == '_blocks' && includeBlocks) ||
          (e.key != '_blocks' &&
              (!ph.containsKey(e.key) || !jsonEquals(ph[e.key], e.value))))
        e.key: e.value,
  };
}

/// The writes that take the server from [base] to [local]: creates (full
/// doc), field-level updates and deletes — ONLY for records this device
/// changed. A record absent from [base] is never deleted, so data that hasn't
/// loaded can't be wiped by omission.
({
  Records creates,
  Map<String, List<FieldChange>> updates,
  List<String> deletes,
})
planRecordWrites(Records base, Records local) {
  final creates = <String, Map<String, dynamic>>{};
  final updates = <String, List<FieldChange>>{};
  final deletes = <String>[];
  local.forEach((k, l) {
    final b = base[k];
    if (b == null) {
      creates[k] = l;
    } else {
      final p = recordPatch(b, l);
      if (p.isNotEmpty) updates[k] = p;
    }
  });
  for (final k in base.keys) {
    if (!local.containsKey(k)) deletes.add(k);
  }
  return (creates: creates, updates: updates, deletes: deletes);
}

/// True when [local] holds no family data at all (only the records of an
/// empty workspace, equal to its defaults) — i.e. a placeholder `Workspace.empty()`
/// for a family that hasn't loaded. Persisting that must never delete.
bool recordsAreEmptyPlaceholder(Records local) {
  final empty = normalizedRecords(Workspace.empty());
  return local.keys.every(
    (k) => empty.containsKey(k) && jsonEquals(empty[k], local[k]),
  );
}
