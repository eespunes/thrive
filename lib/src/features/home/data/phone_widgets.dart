part of 'package:family_money_management_app/main.dart';

/// Android home-screen widgets (epic #224), mirroring the design's Turn-3
/// section of `Home & nav options.dc.html`: the Dart side of the bridge.
///
/// The pure pieces — payload building, the till-code PNG, the background
/// widget-action mutations and the deep-link routing — live here and are
/// unit-tested. Only the thin `home_widget` plugin calls are
/// coverage-ignored (they need the Android host).

/// Android provider class names (must match the Kotlin classes).
const List<String> kPhoneWidgetProviders = [
  'MoneyWidgetProvider',
  'TodayWidgetProvider',
  'CardWidgetProvider',
  'QuickActionsWidgetProvider',
  'ShoppingWidgetProvider',
];

/// Formats an amount for a widget, honouring the hide-amounts privacy
/// option (issue #257): hidden amounts render as bullets until the user
/// opens the app.
String widgetEur(double v, bool hide) => hide ? '€ ••••' : eur(v);

/// Renders a card's till code as a PNG for the 2×2 loyalty widget
/// (RemoteViews can only show bitmaps). Real, scannable symbology — same
/// pick as the in-app card face.
Uint8List renderCardCodePng(DiscountCard card, {int scale = 3}) {
  final isQr = card.codeType == 'qr';
  final width = (isQr ? 160 : 300) * scale ~/ 3;
  final height = (isQr ? 160 : 90) * scale ~/ 3;
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  try {
    final bc.Barcode symbology = isQr
        ? bc.Barcode.qrCode()
        : isValidEan13(card.number)
        ? bc.Barcode.ean13()
        : bc.Barcode.code128();
    for (final el in symbology.make(
      card.number,
      width: width.toDouble(),
      height: height.toDouble(),
    )) {
      if (el is bc.BarcodeBar && el.black) {
        img.fillRect(
          image,
          x1: el.left.round(),
          y1: el.top.round(),
          x2: (el.left + el.width).round() - 1,
          y2: (el.top + el.height).round() - 1,
          color: img.ColorRgb8(0, 0, 0),
        );
      }
    }
  } catch (_) {
    // Unrenderable number: the widget shows the digits only.
  }
  return img.encodePng(image);
}

/// Loads the active family's raw workspace JSON for the background isolate.
/// Workspaces moved out of the v4 blob into per-section keys
/// ([kWsSectionPrefix], see `_persistLocalWorkspaces`), so the section keys
/// are the source of truth; the legacy `workspaces` map still embedded in
/// older blobs is only a fallback. Returns null when neither exists (e.g.
/// cloud mode, where local state is wiped).
Map<String, dynamic>? phoneWidgetLoadWorkspaceJson(
  SharedPreferences prefs,
  Map<String, dynamic> v4,
) {
  final familyId = (v4['familyId'] ?? '').toString();
  final prefix = '$kWsSectionPrefix$familyId.';
  final sections = <String, Map<String, dynamic>>{};
  for (final key in prefs.getKeys()) {
    if (!key.startsWith(prefix)) continue;
    try {
      sections[key.substring(prefix.length)] = Map<String, dynamic>.from(
        json.decode(prefs.getString(key)!) as Map,
      );
    } catch (_) {
      // Skip a corrupt section — same tolerance as the app's restore.
    }
  }
  final fromSections = workspaceFromSections(sections);
  if (fromSections != null) return fromSections.toJson();
  // Legacy blob with embedded workspaces. The shallow copy shares the
  // nested lists/maps, so mutations remain visible through [v4] and a
  // legacy write-back of the whole blob persists them.
  final legacy = (v4['workspaces'] as Map?)?[familyId];
  return legacy is Map ? Map<String, dynamic>.from(legacy) : null;
}

/// Writes a mutated workspace JSON back to the SAME place it was read from,
/// so the main app's restore (which prefers section keys over the embedded
/// map) picks the change up: per-family section keys when any exist,
/// otherwise the legacy embedded `workspaces` map inside the v4 blob.
Future<void> phoneWidgetSaveWorkspaceJson(
  SharedPreferences prefs,
  Map<String, dynamic> v4,
  Map<String, dynamic> wsJson,
) async {
  final familyId = (v4['familyId'] ?? '').toString();
  final prefix = '$kWsSectionPrefix$familyId.';
  if (prefs.getKeys().any((k) => k.startsWith(prefix))) {
    final sections = workspaceSections(Workspace.fromJson(wsJson));
    for (final s in sections.entries) {
      final encoded = json.encode(s.value);
      if (prefs.getString('$prefix${s.key}') != encoded) {
        await prefs.setString('$prefix${s.key}', encoded);
      }
    }
    return;
  }
  ((v4['workspaces'] ??= <String, dynamic>{}) as Map)[familyId] = wsJson;
  await prefs.setString(kStorageKeyV4, json.encode(v4));
}

/// Background widget actions (issue #252): applied to the active family's
/// raw workspace JSON by the background isolate, so a tick or a pay works
/// without opening the app. The app reconciles + syncs on next launch.
/// Returns true when something changed.
bool applyPhoneWidgetAction(Map<String, dynamic>? ws, Uri uri) {
  if (ws == null) return false;
  switch (uri.queryParameters['do']) {
    case 'tick_task':
      final listId = uri.queryParameters['list'];
      final taskId = uri.queryParameters['task'];
      for (final l in (ws['taskLists'] as List? ?? [])) {
        if (l is Map && l['id'] == listId) {
          for (final t in (l['tasks'] as List? ?? [])) {
            if (t is Map && t['id'] == taskId) {
              t['done'] = t['done'] != true;
              return true;
            }
          }
        }
      }
      return false;
    case 'pay_bill':
      final year = uri.queryParameters['year'];
      final month = uri.queryParameters['month'];
      final cat = uri.queryParameters['cat'];
      final id = uri.queryParameters['id'];
      final monthData = ((ws['data'] as Map?)?[year] as Map?)?[month] as Map?;
      if (monthData == null || monthData['closed'] == true) return false;
      for (final it in ((monthData['blocks'] as Map?)?[cat] as List? ?? [])) {
        if (it is Map && it['id'] == id && it['paid'] != true) {
          it['paid'] = true;
          // Paying a card-tagged item logs a card use, like in the app.
          final cardId = it['cardId'];
          if (cardId != null) {
            for (final c in (ws['cards'] as List? ?? [])) {
              if (c is Map && c['id'] == cardId) {
                c['timesUsed'] = ((c['timesUsed'] as num?)?.toInt() ?? 0) + 1;
                c['lastUsed'] = DateTime.now().millisecondsSinceEpoch;
              }
            }
          }
          return true;
        }
      }
      return false;
  }
  return false;
}

/// Rebuilds the widget payload from the slim v4 meta blob plus the active
/// family's raw workspace JSON (from [phoneWidgetLoadWorkspaceJson]) — used
/// by the background isolate after [applyPhoneWidgetAction] so widgets
/// refresh without the app running.
Map<String, dynamic>? phoneWidgetPayloadFromV4(
  Map<String, dynamic> v4,
  Map<String, dynamic>? wsJson,
) {
  if (wsJson == null) return null;
  final ws = Workspace.fromJson(Map<String, dynamic>.from(wsJson));
  final year = (v4['year'] as num?)?.toInt() ?? DateTime.now().year;
  final monthIdx = ((v4['monthIdx'] as num?)?.toInt() ?? 0).clamp(0, 11);
  return buildPhoneWidgetPayload(
    ws: ws,
    year: year,
    monthIdx: monthIdx,
    kid: false,
    hideAmounts: v4['widgetHideAmounts'] == true,
  );
}

/// The payload every Android provider renders from (issue #248). Pure
/// function of the workspace so it is fully unit-tested.
Map<String, dynamic> buildPhoneWidgetPayload({
  required Workspace ws,
  required int year,
  required int monthIdx,
  required bool kid,
  required bool hideAmounts,
  DateTime? now,
}) {
  final month = ws.data[year]?[kMonthKeys[monthIdx]];
  now ??= DateTime.now();
  final today =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  // ------------------------------------------------------------- money
  double expIncome = 0, totalBudget = 0, totalPaid = 0, dueToday = 0;
  final bills = <Map<String, dynamic>>[];
  for (final c in ws.cats) {
    for (final it in month?.blocks[c.key] ?? const <ExpenseItem>[]) {
      if (c.isIncome) {
        expIncome += it.amount;
        continue;
      }
      totalBudget += it.amount;
      if (it.paid) {
        totalPaid += it.amount;
      } else {
        final day = int.tryParse(
          RegExp(r'^(\d{1,2})').firstMatch(it.marker)?.group(1) ?? '',
        );
        if (day != null && day <= now.day) dueToday += it.amount;
        bills.add({
          'id': it.id,
          'cat': c.key,
          'label': it.payee.trim().isNotEmpty ? it.payee.trim() : it.label,
          'amount': widgetEur(it.amount, hideAmounts),
          'day': day,
          'due': day == null
              ? ''
              : day <= now.day
              ? 'Today'
              : day - now.day <= 3
              ? 'In ${day - now.day}d'
              : '$day ${kMonthsEn[monthIdx].substring(0, 3)}',
          'cardId': it.cardId,
        });
      }
    }
  }
  bills.sort(
    (a, b) => ((a['day'] as int?) ?? 32).compareTo((b['day'] as int?) ?? 32),
  );

  // ---------------------------------------------------------- calendar
  final rows = <Map<String, dynamic>>[];
  for (final ev in ws.events) {
    if (ev.kitchenOrigin) continue;
    final occursToday = ev.recur == 'none'
        ? ev.date == today ||
              (ev.endDate.isNotEmpty &&
                  ev.date.compareTo(today) <= 0 &&
                  ev.endDate.compareTo(today) >= 0)
        : recurringEventDates(ev, today, today).isNotEmpty;
    if (!occursToday) continue;
    rows.add({
      'id': ev.id,
      'title': ev.title,
      'time': ev.allDay || ev.start.isEmpty ? 'all day' : ev.start,
      'color': ev.color.toARGB32(),
      'todo': ev.todo,
      'done': ev.todo && (ev.done || ev.doneDates[today] == true),
    });
  }
  rows.sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));

  // ------------------------------------------------------ loyalty card
  final card = ws.cards.isEmpty
      ? null
      : (ws.cards.toList()..sort((a, b) => b.timesUsed.compareTo(a.timesUsed)))
            .first;

  // ---------------------------------------------------------- shopping
  final list = ws.shoppingLists.firstOrNull;
  final openItems =
      list?.items.where((i) => !i.checked).toList() ?? const <ShopItem>[];

  // Tasks (for the today widget's to-do row and the tick action).
  final tasks = <Map<String, dynamic>>[
    for (final l in ws.taskLists)
      for (final t in l.tasks)
        if (!t.done) {'listId': l.id, 'id': t.id, 'title': t.title},
  ];

  return {
    'generatedAt': DateTime.now().millisecondsSinceEpoch,
    'kid': kid,
    'hideAmounts': hideAmounts,
    'money': {
      'month': kMonthsEn[monthIdx],
      'year': year,
      'monthKey': kMonthKeys[monthIdx],
      'balance': widgetEur(expIncome - totalBudget, hideAmounts),
      'stillToPay': widgetEur(totalBudget - totalPaid, hideAmounts),
      'dueToday': widgetEur(dueToday, hideAmounts),
      'progress': totalBudget > 0
          ? (totalPaid / totalBudget * 100).round().clamp(0, 100)
          : 0,
      'bills': [
        for (final (i, b) in bills.take(4).indexed) {...b, 'primary': i == 0},
      ],
      'closed': month?.closed == true,
    },
    'today': {'events': rows.take(6).toList(), 'tasks': tasks.take(3).toList()},
    'card': card == null
        ? null
        : {
            'id': card.id,
            'name': card.name,
            'color': card.color.toARGB32(),
            'tail': card.maskedNumber,
            'uses': card.timesUsed,
            'hint': 'Tap to enlarge · used ${card.timesUsed}×',
          },
    'shopping': list == null
        ? null
        : {
            'listId': list.id,
            'name': list.name,
            'left': openItems.length,
            'items': [for (final i in openItems.take(4)) i.name],
          },
    'quickActions': [
      for (final id in kDefaultQuickActions)
        {'id': id, 'label': kHomeQuickActions.firstWhere((a) => a.$1 == id).$2},
    ],
  };
}

extension _ThrivePhoneWidgets on _ThriveHomeState {
  /// Whether amounts are masked on the phone widgets (issue #257).
  bool get widgetHideAmounts => _widgetHideAmounts;
  void toggleWidgetHideAmounts() {
    update(() => _widgetHideAmounts = !_widgetHideAmounts);
    _schedulePersist();
    flash(
      _widgetHideAmounts
          ? 'Amounts hidden on your phone widgets'
          : 'Amounts shown on your phone widgets',
    );
  }

  Map<String, dynamic> phoneWidgetPayload() => buildPhoneWidgetPayload(
    ws: _activeWs,
    year: year,
    monthIdx: monthIdx,
    kid: amIKidProfile(),
    hideAmounts: _widgetHideAmounts,
  );

  /// Routes a widget deep link (issue #248): every widget lands on the
  /// right screen with the right filter.
  void handleWidgetLaunch(Uri uri) {
    logAnalyticsEvent('android_widget_opened', {
      'target': uri.queryParameters['target'] ?? uri.host,
    });
    switch (uri.queryParameters['target'] ?? '') {
      case 'finance':
        goTab('finance');
      case 'calendar':
        goTab('calendar');
      case 'card':
        final id = uri.queryParameters['id'];
        if (cardById(id) != null) {
          openCardFace(id!);
        } else {
          openWalletScreen();
        }
      case 'scan':
        openCardScan();
      case 'tasks':
        update(() => taskFilter = 'all');
        goTab('lists');
      case 'shopping':
        goTab('lists');
        final id = uri.queryParameters['id'];
        if (shoppingLists.any((l) => l.id == id)) {
          openShopListDetail(id!);
          shopQuickAddFocus.requestFocus();
        }
      case 'event':
        openEvent(null);
      case 'task':
        quickAddTask();
      case 'shop':
        quickAddShopItem();
      case 'cost':
        goTab('finance');
      default:
        goTab('home');
    }
  }

  /// Placement analytics (issue #250): the native providers record
  /// `onEnabled` into the shared widget prefs; drained + logged here.
  Future<void> drainWidgetPlacements() async {
    // coverage:ignore-start
    try {
      final raw = await HomeWidget.getWidgetData<String>('placed_events');
      if (raw == null || raw.isEmpty) return;
      await HomeWidget.saveWidgetData('placed_events', '');
      for (final id in raw.split(',').where((s) => s.isNotEmpty)) {
        logAnalyticsEvent('android_widget_placed', {'widget': id});
      }
    } catch (_) {}
    // coverage:ignore-end
  }

  /// Pushes the payload to the Android widgets. Called after every persist
  /// (push refresh, issue #252); the native side adds the 15-minute floor.
  // The home_widget plugin needs the Android host.
  // coverage:ignore-start
  Future<void> pushPhoneWidgets() async {
    if (foundation.kIsWeb || !Platform.isAndroid) return;
    try {
      final payload = phoneWidgetPayload();
      await HomeWidget.saveWidgetData('payload', json.encode(payload));
      final card = payload['card'];
      if (card is Map) {
        final c = cardById(card['id'] as String?);
        if (c != null && c.number.isNotEmpty) {
          await HomeWidget.saveWidgetData(
            'card_code_b64',
            base64Encode(renderCardCodePng(c)),
          );
        }
      }
      for (final provider in kPhoneWidgetProviders) {
        await HomeWidget.updateWidget(androidName: provider);
      }
    } catch (_) {
      // No widget host (tests, desktop) — nothing to update.
    }
  }

  /// Registers launch + click streams so widget taps land correctly.
  Future<void> bindPhoneWidgets() async {
    if (foundation.kIsWeb || !Platform.isAndroid) return;
    try {
      await HomeWidget.setAppGroupId('cat.eespunes.thrive');
      final launch = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (launch != null) handleWidgetLaunch(launch);
      HomeWidget.widgetClicked.listen((uri) {
        if (uri != null) handleWidgetLaunch(uri);
      });
      await drainWidgetPlacements();
    } catch (_) {}
  }

  // coverage:ignore-end
}

/// Background entry point for in-widget actions (issue #252): mutates the
/// active family's local workspace (per-section keys, with the legacy
/// embedded-v4 map as fallback), rebuilds the payload and refreshes the
/// widgets — all without opening the app. The app reconciles + syncs on
/// next launch. In cloud mode local state is wiped, so there is nothing to
/// mutate and the action is a no-op.
// Runs in a headless isolate with live plugins.
// coverage:ignore-start
@pragma('vm:entry-point')
Future<void> phoneWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kStorageKeyV4);
    if (raw == null) return;
    final v4 = json.decode(raw) as Map<String, dynamic>;
    final ws = phoneWidgetLoadWorkspaceJson(prefs, v4);
    if (ws == null || !applyPhoneWidgetAction(ws, uri)) return;
    await phoneWidgetSaveWorkspaceJson(prefs, v4, ws);
    final payload = phoneWidgetPayloadFromV4(v4, ws);
    if (payload != null) {
      await HomeWidget.saveWidgetData('payload', json.encode(payload));
    }
    for (final provider in kPhoneWidgetProviders) {
      await HomeWidget.updateWidget(androidName: provider);
    }
  } catch (_) {}
}

// coverage:ignore-end
