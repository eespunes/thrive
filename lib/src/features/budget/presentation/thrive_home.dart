part of 'package:family_money_management_app/main.dart';

/// Root screen — a faithful Flutter port of the Thrive design `Component`.
/// Holds all app state and renders the three screens (overview, stats,
/// settings) plus the segmented header switcher.
class ThriveHome extends StatefulWidget {
  const ThriveHome({super.key});

  @override
  State<ThriveHome> createState() => _ThriveHomeState();
}

@visibleForTesting
final ThriveDebugController thriveDebug = ThriveDebugController();

@visibleForTesting
bool Function()? firebaseAppsAvailableOverride;

bool get firebaseAppsAvailable =>
    firebaseAppsAvailableOverride?.call() ?? Firebase.apps.isNotEmpty;

@visibleForTesting
class ThriveDebugController {
  _ThriveHomeState? _state;

  void _attach(_ThriveHomeState state) => _state = state;

  void _detach(_ThriveHomeState state) {
    if (_state == state) _state = null;
  }

  _ThriveHomeState get _s {
    final state = _state;
    if (state == null) {
      throw StateError('ThriveDebugController is not attached to a state');
    }
    return state;
  }

  Future<String?> signInWithGoogle() => _s.signInWithGoogle();

  Future<String?> signInWithEmail({
    required String email,
    required String password,
    required bool register,
    String? name,
  }) {
    return _s.signInWithEmail(
      email: email,
      password: password,
      register: register,
      name: name,
    );
  }

  void signInUser(AppUser user) => _s.signInUser(user);
  void signOut() => _s.signOut();
  void saveProfile(String name, String? photo, Color? color) =>
      _s.saveProfile(name, photo, color);
  bool amOwner() => _s.amOwner();
  ({Color bg, Color fg, String label}) memberPill(String role, String status) =>
      _s.memberPill(role, status);
  void renameFamily(String name) => _s.renameFamily(name);
  void inviteMember(String name, String email) => _s.inviteMember(name, email);
  void removeMember(String id) => _s.removeMember(id);
  void toggleMemberRole(String id) => _s.toggleMemberRole(id);
  void editMember(
    String id,
    String name,
    String email, {
    String? photo,
    String? emoji,
    bool photoTouched = false,
    bool emojiTouched = false,
    bool? kid,
  }) => _s.editMember(
    id,
    name,
    email,
    photo: photo,
    emoji: emoji,
    photoTouched: photoTouched,
    emojiTouched: emojiTouched,
    kid: kid,
  );
  void addMember(String name, {String? photo, String? emoji}) =>
      _s.addMember(name, photo: photo, emoji: emoji);
  void switchFamily(String id) => _s.switchFamily(id);
  Future<String?> createFamily(
    String name, {
    String? username,
    String? password,
    String? picture,
  }) => _s.createFamily(
    name,
    username: username,
    password: password,
    picture: picture,
  );
  Future<String?> fetchFamilyPassword(Family family) =>
      _s.fetchFamilyPassword(family);
  Future<String?> joinFamily({
    required String username,
    required String password,
  }) => _s.joinFamily(username: username, password: password);
  void deleteFamily(String id) => _s.deleteFamily(id);
  void leaveFamily(String id) => _s.leaveFamily(id);
  void setYear(int y) => _s.setYear(y);
  void moveAccount(String key, int dir) => _s.moveAccount(key, dir);
  void moveBlock(String key, int dir) => _s.moveBlock(key, dir);
  void go(String s) => _s.go(s);
  void goTab(String t) => _s.goTab(t);
  String get tab => _s.tab;
  void setMonth(int d) => _s.setMonth(d);
  void pickMonth(int i) => _s.pickMonth(i);
  void toggleCollapse(String k) => _s.toggleCollapse(k);
  void closeMonth() => _s.closeMonth();
  void reopenMonth() => _s.reopenMonth();
  bool isClosed([int? mIdx, int? yr]) => _s.isClosed(mIdx, yr);
  Account accByKey(String k) => _s.accByKey(k);
  Category? catByKey(String k) => _s.catByKey(k);
  List<Category> catsForMonth(int mIdx, [int? yr]) => _s.catsForMonth(mIdx, yr);
  List<Account> accountsForMonth(int mIdx, [int? yr]) =>
      _s.accountsForMonth(mIdx, yr);
  void togglePaid(String catKey, String id) => _s.togglePaid(catKey, id);
  void toggleReceived(String id) => _s.toggleReceived(id);
  String? firstIncomeId() {
    final m = _s.cur();
    if (m == null) return null;
    for (final c in _s.cats.where((c) => c.isIncome)) {
      final arr = m.blocks[c.key];
      if (arr != null && arr.isNotEmpty) return arr.first.id;
    }
    return null;
  }

  String? firstExpenseId(String catKey) =>
      _s.cur()?.blocks[catKey]?.isNotEmpty == true
      ? _s.cur()!.blocks[catKey]!.first.id
      : null;
  String? findExpenseId(
    String catKey,
    String payee,
    String label, [
    int? mIdx,
    int? yr,
  ]) {
    yr ??= _s.year;
    mIdx ??= _s.monthIdx;
    final items = _s.data[yr]?[kMonthKeys[mIdx]]?.blocks[catKey] ?? const [];
    return items
        .where((it) => it.payee == payee && it.label == label)
        .firstOrNull
        ?.id;
  }

  void deleteExpense(String catKey, String id) => _s.deleteExpense(catKey, id);

  /// Session-only sync-failure markers for imported calendars (#330) — lets
  /// tests drive the hub's amber "N failing" value without a real network.
  Set<String> get failedImportIds => _s.failedImportIds;
  void markImportFailed(String id) =>
      _s.update(() => _s.failedImportIds.add(id));
  void askDelete(
    String name,
    String message,
    VoidCallback onConfirm, {
    String confirmLabel = 'Delete',
  }) => _s.askDelete(name, message, onConfirm, confirmLabel: confirmLabel);
  void setApplyingCloudSnapshot(bool value) =>
      _s._applyingCloudSnapshot = value;
  void flash(String msg) => _s.flash(msg);
  void showError(String? msg) => _s.showError(msg);
  void dismissError() => _s.dismissError();
  String? get toast => _s.toast;
  void restoreV3(Map<String, dynamic> saved) => _s._restore(saved);
  void restoreV4(Map<String, dynamic> saved) => _s._restoreV4(saved);
  void seedFamiliesAndWorkspace() => _s._seedFamiliesAndWorkspace();
  Family? curFamily() => _s.curFamily();
  AppUser? get user => _s.user;
  List<Family> get families => _s.families;
  String get familyId => _s.familyId;
  String get myId => _s.myId;
  List<CalendarEvent> get events => _s.events;
  List<TaskList> get taskLists => _s.taskLists;
  List<ShoppingList> get shoppingLists => _s.shoppingLists;
  List<CalendarLayerDef> get calendarLayers => _s.calendarLayers;
  List<String> get layerFilter => _s.layerFilter;
  List<EventCategory> get eventCategories => _s.eventCategories;
  List<DiscountCard> get cards => _s.cards;
  void saveCard(DiscountCard c) => _s.saveCard(c);
  void logCardUse(String id) => _s.logCardUse(id);
  void payItemWithCard(String catKey, String itemId, String cardId) =>
      _s.payItemWithCard(catKey, itemId, cardId);
  void importCardFromBytes(Uint8List bytes) => _s.importCardFromBytes(bytes);
  void openWalletScreen() => _s.openWalletScreen();
  void openCardScan() => _s.openCardScan();
  void pinWalletWidget() => _s.pinWalletWidget();
  void openCardFace(String id, {String? payCat, String? payItemId}) =>
      _s.openCardFace(id, payCat: payCat, payItemId: payItemId);
  void mutateState(VoidCallback fn) => _s.mutate(fn);
  List<(Category, ExpenseItem)> unpaidItemsThisMonth() =>
      _s.unpaidItemsThisMonth();
  Map<String, dynamic> phoneWidgetPayload() => _s.phoneWidgetPayload();
  void handleWidgetLaunch(Uri uri) => _s.handleWidgetLaunch(uri);
  bool get widgetHideAmounts => _s.widgetHideAmounts;
  bool get notificationsEnabled => _s.notificationsEnabled;
  bool get deviceCalendarSyncEnabled => _s.deviceCalendarSyncEnabled;
  void toggleWidgetHideAmounts() => _s.toggleWidgetHideAmounts();
  List<BoardEntry>? get homeBoard => _s.homeBoard;
  set homeBoard(List<BoardEntry>? v) => _s.homeBoard = v;
  List<BoardEntry> effectiveHomeBoard() => _s.effectiveHomeBoard();
  bool amIKidProfile() => _s.amIKidProfile();
  List<HomeWidgetDef> offeredHomeWidgets() => _s.offeredHomeWidgets();
  void addHomeWidget(String id) => _s.addHomeWidget(id);
  void removeHomeWidget(int i) => _s.removeHomeWidget(i);
  void cycleHomeWidgetSize(int i) => _s.cycleHomeWidgetSize(i);
  void reorderHomeWidget(int from, int to) => _s.reorderHomeWidget(from, to);
  void setHomeWidgetOptions(int i, Map<String, dynamic> o) =>
      _s.setHomeWidgetOptions(i, o);
  void setHomeEditMode(bool on) => _s.setHomeEditMode(on);
  bool get homeEditMode => _s.homeEditMode;
  void openHomeWidgetPicker() => _s.openHomeWidgetPicker();
  void openHomeWidgetOptions(int i) => _s.openHomeWidgetOptions(i);
  void runHomeQuickAction(String id) => _s.runHomeQuickAction(id);
  Map<String, DayPlan> get weeklyPlan => _s.weeklyPlan;
  Map<String, int> get starsMap => _s.starsMap;
  List<ImportedCalendar> get importedCalendars => _s.importedCalendars;
  List<Account> get accounts => _s.accounts;
  List<Category> get cats => _s.cats;
  Map<int, Map<String, MonthData>> get data => _s.data;
  Map<String, bool> get picMembers => _s.picMembers;
  List<String> get kitchenLayerFilter => _s.kitchenLayerFilter;
  bool get budgetLimitWarn => _s.budgetLimitWarn;
  void saveExpense(
    String mode,
    String cat,
    String? id, {
    required String payee,
    required String label,
    required double amount,
    int? day,
    required bool paid,
    required String account,
    required bool recurring,
  }) => _s.saveExpense(
    mode,
    cat,
    id,
    payee: payee,
    label: label,
    amount: amount,
    day: day,
    paid: paid,
    account: account,
    recurring: recurring,
  );
  void addCalendarLayer({
    required String label,
    required String icon,
    String? emoji,
    String? picture,
    required Color color,
  }) => _s.addCalendarLayer(
    label: label,
    icon: icon,
    emoji: emoji,
    picture: picture,
    color: color,
  );
  void openQuickAdd() => _s.openQuickAddSheet();
  void openEvent(CalendarEvent? ev, [String? date]) => _s.openEvent(ev, date);
}

class _ThriveHomeState extends State<ThriveHome> with WidgetsBindingObserver {
  bool ready = false;
  int year = 2026;
  int monthIdx = 5;
  String screen =
      'overview'; // overview | flow | stats — Finance tab's own sub-view
  String tab =
      'home'; // home | calendar | lists | finance | more | weekly | finsettings
  String flowView = 'calendar'; // calendar | timeline — Money calendar sub-view

  // Settings hub (#272): which card is expanded (one at a time, remembered
  // for the session), plus session-local "future" toggles — visible homes
  // for not-yet-implemented preferences, never persisted.
  String? hubOpenCard;
  bool futureDark = false;

  /// Imported calendars whose last sync attempt failed this session (#330):
  /// drives the hub's amber "N failing" value. Session-only — the data model
  /// is unchanged; a successful sync clears the id again.
  final Set<String> failedImportIds = <String>{};

  // Real, persisted preferences surfaced by the hub's Account card: the
  // master reminder switch and the Android device-calendar mirror.
  bool notificationsEnabled = true;
  bool deviceCalendarSyncEnabled = true;

  /// "Warn near block limits" (#329): a toast nudge when a block's planned
  /// total crosses 90% of this month's cap. Persisted per device.
  bool budgetLimitWarn = true;
  String statsMode = 'month'; // month | year | all
  int? statsHeroSelIdx;
  String? statsHeroSelFor;

  // Active workspace: the currently-selected family's budget/calendar/lists.
  // The [Workspace] in `workspaces[familyId]` is the SINGLE owner of this
  // data; these accessors read/write through to it. They used to be plain
  // fields aliasing the workspace's lists, which meant every family
  // switch/leave/restore had to re-point 14 fields by hand — forgetting one
  // (as the leave-family flow did) silently leaked one family's data into
  // another and uploaded it to the wrong family's cloud workspace.
  Workspace get _activeWs => workspaces.putIfAbsent(familyId, Workspace.empty);
  List<Account> get accounts => _activeWs.accounts;
  set accounts(List<Account> v) => _activeWs.accounts = v;
  List<Category> get cats => _activeWs.cats;
  set cats(List<Category> v) => _activeWs.cats = v;
  Map<int, Map<String, MonthData>> get data => _activeWs.data;
  set data(Map<int, Map<String, MonthData>> v) => _activeWs.data = v;
  List<TaskList> get taskLists => _activeWs.taskLists;
  set taskLists(List<TaskList> v) => _activeWs.taskLists = v;
  List<ShoppingList> get shoppingLists => _activeWs.shoppingLists;
  set shoppingLists(List<ShoppingList> v) => _activeWs.shoppingLists = v;
  Map<String, DayPlan> get weeklyPlan => _activeWs.weeklyPlan;
  set weeklyPlan(Map<String, DayPlan> v) => _activeWs.weeklyPlan = v;
  List<CalendarEvent> get events => _activeWs.events;
  set events(List<CalendarEvent> v) => _activeWs.events = v;
  List<EventCategory> get eventCategories => _activeWs.eventCategories;
  set eventCategories(List<EventCategory> v) => _activeWs.eventCategories = v;
  List<ImportedCalendar> get importedCalendars => _activeWs.importedCalendars;
  set importedCalendars(List<ImportedCalendar> v) =>
      _activeWs.importedCalendars = v;
  List<CalendarLayerDef> get calendarLayers => _activeWs.calendarLayers;
  set calendarLayers(List<CalendarLayerDef> v) => _activeWs.calendarLayers = v;
  Map<String, int> get starsMap => _activeWs.starsMap;
  set starsMap(Map<String, int> v) => _activeWs.starsMap = v;
  bool get kitchenEnabled => _activeWs.kitchenEnabled;
  set kitchenEnabled(bool v) => _activeWs.kitchenEnabled = v;
  Map<String, bool> get picMembers => _activeWs.picMembers;
  set picMembers(Map<String, bool> v) => _activeWs.picMembers = v;
  List<String> get kitchenLayerFilter => _activeWs.kitchenLayerFilter;
  set kitchenLayerFilter(List<String> v) => _activeWs.kitchenLayerFilter = v;
  List<DiscountCard> get cards => _activeWs.cards;
  set cards(List<DiscountCard> v) => _activeWs.cards = v;

  /// This member's Home board (epic #223) — PER-USER view state, stored on
  /// the user profile, not the family. `null` means "never edited" (renders
  /// [defaultHomeBoard]); an explicit empty list is a deliberately emptied
  /// board and stays empty (issue #235).
  List<BoardEntry>? homeBoard;

  /// Whether the Home tab is currently in board-edit mode (issue #236).
  bool homeEditMode = false;

  /// Hide amounts on the Android home-screen widgets (issue #257).
  bool _widgetHideAmounts = false;

  String taskFilter = 'all'; // all | me
  String? openTaskList;
  String? openShopList;

  /// Fridge-door wall view state (#317/#318). Per-member preferences: they
  /// persist to SharedPreferences keyed by member, never to the family
  /// workspace — my sort order and folded notes are mine alone.
  String listSort = 'list'; // list | due | who
  final Set<String> foldedNotes = <String>{};
  String? _listPrefsLoadedFor;
  String calView = 'month'; // month | agenda
  String calAnchor = todayIso();
  String calSel = todayIso();
  String agendaDay = todayIso(); // day shown by Agenda view's week strip
  List<String> calFilter = []; // member id multi-filter
  List<String> calCatFilter = []; // category id multi-filter
  List<String> layerFilter = ['appt', 'task', 'content']; // enabled layers
  int weekOffset = 0; // 0 = current week, +/- N weeks navigated
  final FocusNode shopQuickAddFocus = FocusNode();
  final PageController calPageController = PageController(initialPage: 10000);
  final PageController calWeekPageController = PageController(
    initialPage: 10000,
  );
  Map<String, bool> collapsed = {};
  String? swipedId;

  /// Toast text streams through a notifier so showing/hiding it repaints only
  /// the toast overlay via its ValueListenableBuilder — a `flash()` used to
  /// trigger two full-tree setState rebuilds per toast.
  final ValueNotifier<String?> _toastNotifier = ValueNotifier<String?>(null);
  String? get toast => _toastNotifier.value;
  Timer? _toastTimer;

  /// When set, the toast pill carries an Undo button that runs this and
  /// dismisses the toast (fridge door #315: cross-off has no confirm dialog,
  /// only a 4-second Undo).
  VoidCallback? toastUndo;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _cloudSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _familySub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _wsSub;
  bool _applyingCloudSnapshot = false;

  /// The family id the Firestore family/workspace streams are currently bound
  /// to, so the user-doc listener only rebinds when the active family truly
  /// changes (its own persist echoes used to trigger a full resubscribe).
  String? _boundFamilyId;

  /// Per-family cache of the workspace subcollection's section payloads
  /// (timestamps stripped) and their digests — what we believe the server
  /// holds, so a persist only uploads sections that actually changed.
  final Map<String, Map<String, Map<String, dynamic>>> _wsSectionCache = {};
  final Map<String, Map<String, String>> _wsSectionDigests = {};

  /// Families whose legacy single-doc `workspace` blob has been dropped from
  /// the meta doc this session (it's re-dropped once per session — a cheap
  /// no-op when already gone — so migrated docs stay slim).
  final Set<String> _legacyBlobCleared = {};

  /// Trailing-debounce timer for [_persist]: serializing and uploading state
  /// on EVERY tap caused main-thread jank and a network write per keystroke.
  /// Edits are coalesced for [_persistDebounce] and flushed early when the
  /// app is backgrounded or disposed so nothing is lost on a swipe-away.
  Timer? _persistTimer;
  static const Duration _persistDebounce = Duration(seconds: 2);

  // True while a just-signed-in user's shared families are still being loaded
  // from the cloud. Suppresses the create/join onboarding gate so a returning
  // user goes straight to their existing family instead of flashing it (#120).
  bool _resolvingFamilies = false;

  // Guards the one-time sync-on-open kicked off once the shell is first
  // reachable (see `build()`); auto-sync on returning to the app is then
  // driven by `didChangeAppLifecycleState`.
  bool _didSyncImportsOnOpen = false;

  // Auth + family state (ported from the design's v4 state).
  AppUser? user;
  List<Family> families = [];
  String familyId = 'fam_main';
  Map<String, Workspace> workspaces = {};

  // In-memory-only cache of a family join password, kept only for the
  // session that just typed it (create/join). Never persisted — cloud
  // families store only a salted hash server-side, and this avoids adding a
  // new persistent field just to remember a plaintext password. Keyed by
  // family id so switching families doesn't leak the wrong one.
  final Map<String, String> _sessionFamilyPasswords = {};

  /// Bumped on every `update()`/`mutate()` call so widgets embedded in
  /// bottom sheets (e.g. the Weekly plan / Finance settings sheets, which
  /// render their content outside the main `build()` subtree) can listen
  /// and rebuild when state changes underneath them.
  final ValueNotifier<int> _rev = ValueNotifier<int>(0);

  /// App version from pubspec (e.g. "2.7.1"), without the build number
  /// suffix. Populated asynchronously in [initState]; empty until then.
  String _appVersion = '';

  /// Synchronous cache of `_localSelfUid()`, populated once at the start of
  /// [_boot] so [myId] never has to await a `SharedPreferences` read.
  String? _localSelfUidCache;

  @override
  void initState() {
    super.initState();
    thriveDebug._attach(this);
    WidgetsBinding.instance.addObserver(this);
    _boot();
    _loadAppVersion();
    pendingNotificationDeepLink.addListener(_handleNotificationDeepLink);
    // A tap that launched the app cold arrives before this listener attaches.
    _handleNotificationDeepLink();
    // Android home-screen widgets (epic #224): launch/click routing,
    // placement analytics and the background action callback.
    unawaited(bindPhoneWidgets());
    // coverage:ignore-start
    if (!foundation.kIsWeb && Platform.isAndroid) {
      unawaited(
        HomeWidget.registerInteractivityCallback(phoneWidgetBackgroundCallback),
      );
    }
    // coverage:ignore-end
  }

  @override
  void dispose() {
    thriveDebug._detach(this);
    WidgetsBinding.instance.removeObserver(this);
    pendingNotificationDeepLink.removeListener(_handleNotificationDeepLink);
    _cloudSub?.cancel();
    _familySub?.cancel();
    _wsSub?.cancel();
    _flushPersist();
    DeviceCalendarSync.instance.cancelPending();
    _toastTimer?.cancel();
    shopQuickAddFocus.dispose();
    calPageController.dispose();
    calWeekPageController.dispose();
    super.dispose();
  }

  /// Keeps subscribed (auto-sync) ICS imports — e.g. a sports team's
  /// schedule — current whenever the app comes back to the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncDueImports();
      unawaited(_refreshReminderSchedule());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Flush any debounced edit before the OS can kill the app.
      _flushPersist();
    }
  }

  /// Immediately runs a pending debounced persist, if any.
  void _flushPersist() {
    if (_persistTimer?.isActive != true) return;
    _persistTimer?.cancel();
    unawaited(_persist());
  }

  Future<void> _refreshReminderSchedule() async {
    await NotificationService.refreshTimeZone();
    await _rescheduleReminders();
  }

  /// Consumes [pendingNotificationDeepLink] and opens the task or calendar
  /// event that produced the notification.
  void _handleNotificationDeepLink() {
    if (!ready) return;
    final payload = pendingNotificationDeepLink.value;
    if (payload == null) return;
    if (payload.startsWith('task:')) {
      final taskId = payload.substring('task:'.length);
      for (final l in taskLists) {
        if (l.tasks.any((t) => t.id == taskId)) {
          pendingNotificationDeepLink.value = null;
          goTab('lists');
          openTaskListDetail(l.id);
          return;
        }
      }
    } else if (payload.startsWith('event:')) {
      // Payload shape is `event:<id>:<yyyy-mm-dd>` (see NotificationService's
      // occurrence payloads). Split on the LAST ':' with a validated date
      // instead of blind position arithmetic, so an unexpected id shape or
      // format change discards the link rather than mis-parsing it.
      final rest = payload.substring('event:'.length);
      final sep = rest.lastIndexOf(':');
      final date = sep >= 0 ? rest.substring(sep + 1) : '';
      final eventId = sep >= 0 ? rest.substring(0, sep) : '';
      final validDate = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date);
      if (validDate && eventId.isNotEmpty && eventById(eventId) != null) {
        pendingNotificationDeepLink.value = null;
        update(() {
          tab = 'calendar';
          calAnchor = date;
          calSel = date;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) openEventView(eventId, date);
        });
        return;
      }
    }
    // The source item was deleted, so discard the stale deep link.
    pendingNotificationDeepLink.value = null;
  }

  // ---------------------------------------------------------------- boot
  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = info.version);
  }

  /// Marks boot complete: shows the shell, re-derives pending reminders and
  /// consumes any notification deep link that launched the app. Every boot
  /// path must end through here — the ritual used to be copy-pasted per path
  /// and was easy to miss when adding a new one.
  void _finishBoot() {
    setState(() => ready = true);
    // Boot survived — disarm the crash-loop breaker (see kBootFailStreakKey).
    unawaited(
      SharedPreferences.getInstance()
          .then((p) => p.setInt(kBootFailStreakKey, 0))
          .catchError((Object _) => true),
    );
    unawaited(_rescheduleReminders());
    _handleNotificationDeepLink();
  }

  /// Decodes a JSON object off the main isolate when it's big. A legacy
  /// un-migrated state blob can run multi-MB; decoding that synchronously
  /// stalls the first frame. Small payloads decode inline — an isolate
  /// round-trip costs more than the decode itself.
  Future<Map<String, dynamic>> _decodeJsonMap(String raw) async {
    if (raw.length < 64 * 1024) {
      return json.decode(raw) as Map<String, dynamic>;
    }
    return foundation.compute(_jsonDecodeMap, raw);
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    _syncUserFromFirebaseAuth();
    _localSelfUidCache = await _localSelfUid();

    // Firebase boot sync is integration-only here.
    // coverage:ignore-start
    if (_cloudBacked) {
      final uid = _firebaseUid()!;
      // Load the shared families this user belongs to (migrating any legacy
      // single-blob state on first run).
      final hadCloud = await cloudBoot(uid);
      if (hadCloud) {
        await bindCloudSync(uid);
        if (!mounted) return;
        _finishBoot();
        return;
      }

      // Brand-new cloud user: promote any local state, else land on onboarding
      // with no families so they can create or join one.
      final rawV4 = prefs.getString(kStorageKeyV4);
      if (rawV4 != null) {
        try {
          _restoreV4(
            await _decodeJsonMap(rawV4),
            sectionWorkspaces: _readLocalWorkspaceSections(prefs),
          );
          for (final f in families) {
            f.ownerUid ??= uid;
            if (!f.memberUids.contains(uid)) f.memberUids.add(uid);
            if (f.username.trim().isEmpty) f.username = familySlug(f.name);
          }
          if (!mounted) return;
          _finishBoot();
          await _persist();
          await bindCloudSync(uid);
          return;
        } catch (_) {
          /* fall through to empty onboarding */
        }
      }

      // No prior data: start empty so the onboarding gate prompts create/join.
      families = [];
      workspaces = {};
      if (!mounted) return;
      _finishBoot();
      return;
    }
    // coverage:ignore-end

    // Signed-in user in local/demo mode only.
    final rawUser = prefs.getString(kUserKey);
    if (rawUser != null) {
      try {
        user = AppUser.fromJson(json.decode(rawUser) as Map<String, dynamic>);
      } catch (_) {
        /* ignore corrupt user */
      }
    }

    // v4 multi-family state.
    final rawV4 = prefs.getString(kStorageKeyV4);
    if (rawV4 != null) {
      try {
        _restoreV4(
          await _decodeJsonMap(rawV4),
          sectionWorkspaces: _readLocalWorkspaceSections(prefs),
        );
        if (!mounted) return;
        _finishBoot();
        return;
      } catch (_) {
        /* fall through to migration / seed */
      }
    }

    // Migrate a pre-existing single-family v3 store into a fam_main workspace.
    final rawV3 = prefs.getString(kStorageKey);
    if (rawV3 != null) {
      try {
        _restore(await _decodeJsonMap(rawV3));
        _seedFamiliesAndWorkspace();
        if (!mounted) return;
        _finishBoot();
        _persist();
        return;
      } catch (_) {
        /* fall through to fresh seed */
      }
    }

    await _seedFromAsset();
  }

  /// Re-derives pending reminders from persisted calendar events. With the
  /// master notifications switch off, everything scheduled is cancelled.
  Future<void> _rescheduleReminders() async {
    // Startup defers NotificationService.init past the first frame; init()
    // is memoised, so this await just orders scheduling after it.
    await NotificationService.init();
    if (!notificationsEnabled) {
      await NotificationService.instance.syncEventReminders(const []);
      return;
    }
    // Only events that can still ring: recurring series always qualify;
    // one-offs older than the longest reminder offset (2 days) can't.
    final cutoff = _isoOfDate(DateTime.now().subtract(const Duration(days: 3)));
    bool canStillRing(CalendarEvent e) =>
        e.recur != 'none' ||
        (e.endDate.isNotEmpty ? e.endDate : e.date).compareTo(cutoff) >= 0;
    final importedEvents = [
      for (final cal in importedCalendars)
        if (cal.visible && cal.reminder != 'none')
          for (final e in cal.events)
            if (e.date.compareTo(cutoff) >= 0) importedSyntheticEvent(cal, e),
    ];
    await NotificationService.instance.syncEventReminders([
      ...events.where(canStillRing),
      ...importedEvents,
    ]);
  }

  /// Mirrors events into the Android system calendar — or clears the mirror
  /// while the sync preference is off.
  void _syncDeviceCalendar() => DeviceCalendarSync.instance.syncEvents(
    deviceCalendarSyncEnabled ? events : const <CalendarEvent>[],
  );

  /// Master reminder switch (hub Account card). Turning it off cancels every
  /// scheduled reminder; turning it back on reschedules them.
  void toggleNotificationsEnabled() {
    update(() => notificationsEnabled = !notificationsEnabled);
    _schedulePersist();
    unawaited(_rescheduleReminders());
    flash(
      notificationsEnabled
          ? 'Reminders back on'
          : 'Reminders off — nothing will ring',
    );
  }

  /// Android device-calendar mirror switch (hub Account card).
  void toggleDeviceCalendarSync() {
    update(() => deviceCalendarSyncEnabled = !deviceCalendarSyncEnabled);
    _schedulePersist();
    _syncDeviceCalendar();
    flash(
      deviceCalendarSyncEnabled
          ? 'Syncing with the device calendar'
          : 'Device-calendar sync off',
    );
  }

  void _syncUserFromFirebaseAuth() {
    if (!firebaseAppsAvailable) return;
    final fb = FirebaseAuth.instance.currentUser;
    if (fb == null) return;
    final resolvedName = (fb.displayName ?? '').trim().isNotEmpty
        ? fb.displayName!.trim()
        : fb.email?.split('@').first ?? 'User';
    user = AppUser(
      name: resolvedName,
      email: fb.email ?? '',
      initials: initialsOf(resolvedName),
      provider: fb.providerData.isNotEmpty
          ? fb.providerData.first.providerId
          : 'email',
      photo: fb.photoURL,
    );
  }

  String? _firebaseUid() {
    if (!firebaseAppsAvailable) return null;
    return FirebaseAuth.instance.currentUser?.uid;
  }

  bool get _cloudBacked => _firebaseUid() != null;

  /// This device's stable, globally-unique identity: the signed-in Firebase
  /// `uid` when cloud-backed, otherwise the persisted local pseudo-uid (see
  /// `_localSelfUid`). Every `FamilyMember` row that represents "you" uses
  /// this as its `id` — there is no more `'me'` sentinel/alias, so the same
  /// member row (and anything it authors — calendar attendees, task
  /// assignees, etc.) resolves to the same real person on every device that
  /// shares the family, instead of ambiguously to "whoever's looking".
  /// Falls back to the legacy `'me'` sentinel only in the instant before
  /// `_boot()` has populated `_localSelfUidCache` (e.g. debug helpers invoked
  /// before the first frame), which normal app usage never hits.
  String get myId => _firebaseUid() ?? _localSelfUidCache ?? 'me';

  DocumentReference<Map<String, dynamic>> _stateDocRef(String uid) {
    return FirebaseFirestore.instance.collection('user_workspaces').doc(uid);
  }

  /// Restores the v4 blob: families, per-family workspaces and the active
  /// one. [sectionWorkspaces] carries workspaces read from the per-section
  /// keys; they win over any legacy `workspaces` map still embedded in the
  /// blob (newer format).
  void _restoreV4(
    Map<String, dynamic> saved, {
    Map<String, Workspace> sectionWorkspaces = const {},
  }) {
    year = (saved['year'] as num?)?.toInt() ?? 2026;
    monthIdx = ((saved['monthIdx'] as num?)?.toInt() ?? 5).clamp(
      0,
      kMonthKeys.length - 1,
    );
    _restoreNav(saved['screen'], saved['tab']);

    families = [
      for (final f in (saved['families'] as List? ?? []))
        Family.fromJson(Map<String, dynamic>.from(f as Map)),
    ];
    workspaces = {};
    (saved['workspaces'] as Map<String, dynamic>? ?? {}).forEach((id, ws) {
      workspaces[id] = Workspace.fromJson(Map<String, dynamic>.from(ws as Map));
    });
    workspaces.addAll(sectionWorkspaces);
    if (families.isNotEmpty && workspaces.isEmpty) {
      // A slim blob whose section keys are gone would silently resurrect
      // every family with an empty workspace — and the next persist would
      // cement that loss. Fail the restore loudly instead.
      throw StateError('v4 blob lists families but no workspace was found');
    }

    familyId = (saved['familyId'] ?? 'fam_main').toString();
    if (!workspaces.containsKey(familyId)) {
      familyId = workspaces.keys.isNotEmpty
          ? workspaces.keys.first
          : 'fam_main';
    }
    // The workspace in `workspaces[familyId]` IS the active state (the
    // accessors read through to it); nothing to re-point.
    _adoptActiveWorkspace();
    layerFilter = _savedLayerFilter(saved['layerFilter']);
    homeBoard = parseHomeBoard(saved['homeBoard']);
    _widgetHideAmounts = saved['widgetHideAmounts'] == true;
    budgetLimitWarn = saved['budgetLimitWarnOff'] != true;
    notificationsEnabled = saved['notificationsEnabled'] != false;
    deviceCalendarSyncEnabled = saved['deviceCalendarSync'] != false;
    _syncRecurringSeries();
  }

  /// Keeps the just-restored/seeded active workspace as `fam_main`'s and
  /// seeds a starter family for the signed-in user (mirrors the design's
  /// v3→v4 migration / fresh-seed path).
  void _seedFamiliesAndWorkspace() {
    familyId = 'fam_main';
    final ws = _activeWs;
    workspaces = {'fam_main': ws};
    families = user != null ? [seedFamily('fam_main', user!, myId)] : [];
  }

  void _restore(Map<String, dynamic> saved) {
    year = (saved['year'] as num?)?.toInt() ?? 2026;
    final rawMonth = (saved['monthIdx'] as num?)?.toInt() ?? 5;
    monthIdx = rawMonth.clamp(0, kMonthKeys.length - 1);
    _restoreNav(saved['screen'], null);
    if (saved['accounts'] is List) {
      accounts = [
        for (final a in (saved['accounts'] as List))
          Account.fromJson(Map<String, dynamic>.from(a as Map)),
      ];
    }
    // Never allow an empty account list — downstream lookups assume at least
    // one account exists.
    if (accounts.isEmpty) accounts = defaultAccounts();
    if (saved['cats'] is List) {
      cats = [
        for (final c in (saved['cats'] as List))
          Category.fromJson(Map<String, dynamic>.from(c as Map)),
      ];
    }
    if (cats.isEmpty) cats = defaultCats();
    data = {};
    (saved['data'] as Map<String, dynamic>? ?? {}).forEach((yr, months) {
      final yKey = int.tryParse(yr) ?? year;
      final map = <String, MonthData>{};
      (months as Map<String, dynamic>).forEach((mk, md) {
        map[mk] = MonthData.fromJson(Map<String, dynamic>.from(md as Map));
      });
      data[yKey] = map;
    });
    ensureIncomeCategory(cats, data);
    migrateDaylessIncome(cats, data);
    _syncRecurringSeries();
  }

  /// Resolves `screen` (Finance tab's overview/stats sub-view) and `tab`
  /// (top-level nav) from a saved blob. `rawTab` is null for saves written
  /// before the 5-tab nav existed (or the v3 store, which never had a
  /// concept of tabs) — in that case a legacy `screen: 'settings'` lands on
  /// the More hub (its finance rows now open the Settings v2 sub-screens),
  /// and any other legacy screen keeps the user on the Finance tab where
  /// they left off instead of dropping them onto the new Home placeholder.
  void _restoreNav(Object? rawScreen, Object? rawTab) {
    final legacyScreen = (rawScreen ?? 'overview').toString();
    if (legacyScreen == 'settings') {
      screen = 'overview';
      tab = 'more';
      return;
    }
    screen = const {'overview', 'stats', 'flow'}.contains(legacyScreen)
        ? legacyScreen
        : 'overview';
    if (rawTab == null) {
      tab = 'finance';
      return;
    }
    final t = rawTab.toString();
    tab = kValidTabs.contains(t) ? t : 'home';
  }

  List<String> _savedLayerFilter(Object? raw) {
    final restored = <String>[
      for (final id in (raw as List? ?? const []))
        if (id.toString().trim().isNotEmpty) id.toString(),
    ];
    return restored.isEmpty ? <String>['appt', 'task', 'content'] : restored;
  }

  Future<void> _seedFromAsset() async {
    // First launch with no stored state: seed the bundled sample budget so the
    // app isn't empty. Newly *created* families start blank (see issue #119).
    final ws = await buildSampleWorkspace();
    if (!mounted) return;
    setState(() {
      workspaces[familyId] = ws;
      _syncRecurringSeries();
      _seedFamiliesAndWorkspace();
      ready = true;
    });
    unawaited(_rescheduleReminders());
    _persist();
  }

  /// Session cache of the last-written local section digests, so unchanged
  /// sections are skipped on every save (same contract as the cloud sync's
  /// `_wsSectionDigests`).
  final Map<String, Map<String, String>> _localWsDigests = {};

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_cloudBacked) {
      await prefs.remove(kStorageKeyV4);
      await prefs.remove(kStorageKey);
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(kWsSectionPrefix)) await prefs.remove(key);
      }
      // Never push an EMPTY family set to the cloud. An empty in-memory
      // `families` only occurs transiently — during sign-in (before cloudBoot
      // has loaded them) and during sign-out (after they're cleared) — and
      // writing `familyIds: []` then would wipe the account's membership and
      // strand it on the onboarding gate next login (issue #128). Deliberate
      // "leave/delete my last family" flows update the user doc on their own.
      if (families.isNotEmpty) await _pushCloudState();
      return;
    }
    // Sections FIRST, the slim meta blob last: if the process dies between
    // the two, the previous v4 (possibly still carrying legacy embedded
    // workspaces) remains loadable. The reverse order could leave a slim
    // blob with no sections — losing every workspace. And only slim the
    // blob once every section landed: a partially-migrated section set with
    // a slimmed blob would silently drop the failed sections.
    final ok = await _persistLocalWorkspaces(prefs);
    if (ok) {
      await prefs.setString(kStorageKeyV4, json.encode(_buildStatePayload()));
    }
  }

  /// Writes each workspace as per-section keys ([kWsSectionPrefix]),
  /// skipping sections whose digest hasn't changed since the last write and
  /// sweeping keys for removed sections/families. An edit therefore
  /// re-encodes ~one section (tens of KB) instead of the whole state.
  ///
  /// Returns whether EVERY section landed. During the one-time migration
  /// the legacy blob and the sections briefly coexist, which can overflow
  /// web localStorage's quota — on a write failure the legacy blob is
  /// slimmed early to free its space and the write retried; if a section
  /// still can't be written, `false` keeps the caller from slimming a blob
  /// that is that section's only remaining copy.
  Future<bool> _persistLocalWorkspaces(SharedPreferences prefs) async {
    var slimmedForQuota = false;
    var allOk = true;
    Future<bool> write(String key, String value) async {
      try {
        await prefs.setString(key, value);
        return true;
      } catch (_) {
        if (!slimmedForQuota) {
          slimmedForQuota = true;
          try {
            await prefs.setString(
              kStorageKeyV4,
              json.encode(_buildStatePayload()),
            );
            await prefs.setString(key, value);
            return true;
          } catch (_) {
            /* fall through */
          }
        }
        return false;
      }
    }

    final live = <String>{};
    for (final entry in workspaces.entries) {
      final digests = _localWsDigests.putIfAbsent(entry.key, () => {});
      final sections = workspaceSections(entry.value);
      for (final s in sections.entries) {
        final key = '$kWsSectionPrefix${entry.key}.${s.key}';
        live.add(key);
        final digest = sectionDigest(s.value);
        if (digests[s.key] == digest && prefs.containsKey(key)) continue;
        if (await write(key, json.encode(s.value))) {
          digests[s.key] = digest;
        } else {
          allOk = false;
        }
      }
      digests.removeWhere((k, _) => !sections.containsKey(k));
    }
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(kWsSectionPrefix) && !live.contains(key)) {
        await prefs.remove(key);
      }
    }
    return allOk;
  }

  /// Rebuilds workspaces from the per-section keys, seeding the digest
  /// cache so the next save can skip everything unchanged. Families without
  /// section keys simply aren't in the result (the legacy embedded
  /// `workspaces` map covers them).
  Map<String, Workspace> _readLocalWorkspaceSections(SharedPreferences prefs) {
    final byFam = <String, Map<String, Map<String, dynamic>>>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(kWsSectionPrefix)) continue;
      final rest = key.substring(kWsSectionPrefix.length);
      final dot = rest.indexOf('.');
      if (dot <= 0) continue;
      final fid = rest.substring(0, dot);
      final section = rest.substring(dot + 1);
      try {
        final map = Map<String, dynamic>.from(
          json.decode(prefs.getString(key)!) as Map,
        );
        (byFam[fid] ??= {})[section] = map;
        (_localWsDigests[fid] ??= {})[section] = sectionDigest(map);
      } catch (_) {
        /* skip a corrupt section — the rest of the workspace still loads */
      }
    }
    final out = <String, Workspace>{};
    byFam.forEach((fid, sections) {
      final ws = workspaceFromSections(sections);
      if (ws != null) out[fid] = ws;
    });
    return out;
  }

  Map<String, dynamic> _buildStatePayload() {
    return {
      'year': year,
      'monthIdx': monthIdx,
      'screen': screen,
      'tab': tab,
      'layerFilter': layerFilter,
      if (homeBoard != null)
        'homeBoard': homeBoard!.map((e) => e.toJson()).toList(),
      if (_widgetHideAmounts) 'widgetHideAmounts': true,
      if (!budgetLimitWarn) 'budgetLimitWarnOff': true,
      if (!notificationsEnabled) 'notificationsEnabled': false,
      if (!deviceCalendarSyncEnabled) 'deviceCalendarSync': false,
      'familyId': familyId,
      'families': families.map((f) => f.toJson()).toList(),
      // Workspaces live under their own per-section keys now (see
      // [_persistLocalWorkspaces]); the blob keeps meta + families only.
    };
  }

  // requires a live Firestore backend.
  // coverage:ignore-start
  /// Pushes the active family + per-user view state to the shared collections.
  Future<void> _pushCloudState() async {
    if (_applyingCloudSnapshot) return;
    final uid = _firebaseUid();
    if (uid == null) return;
    await cloudPersist(uid);
  }
  // coverage:ignore-end

  /// Persists (or clears) the signed-in user blob.
  Future<void> _persistUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (_cloudBacked || user == null) {
      await prefs.remove(kUserKey);
    } else {
      await prefs.setString(kUserKey, json.encode(user!.toJson()));
    }
    await _persist();
  }

  // ------------------------------------------------------------- helpers
  /// setState + `_rev` bump, safe to call after any await: cloud flows
  /// routinely update state after network round-trips, and a sign-out or
  /// dispose during a slow call must not become "setState after dispose".
  void update(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
    _rev.value++;
  }

  void mutate(VoidCallback fn, [VoidCallback? cb]) {
    if (!mounted) return;
    setState(fn);
    _rev.value++;
    _schedulePersist();
    cb?.call();
  }

  /// Debounced [_persist]: coalesces a burst of edits (typing, repeated
  /// checkbox taps) into one serialize + one set of cloud writes. Flows that
  /// must be durable before continuing (create/join/leave, sign-out) call
  /// [_persist] directly and await it.
  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, () {
      unawaited(_persist());
      // Push refresh for the Android home-screen widgets (issue #252).
      unawaited(pushPhoneWidgets());
    });
  }

  void flash(String msg) {
    if (!mounted) return;
    toastUndo = null;
    _toastNotifier.value = msg;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2100), () {
      if (mounted) {
        toastUndo = null;
        _toastNotifier.value = null;
      }
    });
  }

  /// Like [flash], but the toast carries an Undo button and lingers 4 seconds
  /// so a crossed-off line can be restored in place without a confirm dialog.
  void flashUndo(String msg, VoidCallback onUndo) {
    if (!mounted) return;
    toastUndo = onUndo;
    _toastNotifier.value = msg;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 4000), () {
      if (mounted) {
        toastUndo = null;
        _toastNotifier.value = null;
      }
    });
  }

  /// Surfaces [msg] in the global, user-closable error popup. Use this for any
  /// failure the user must acknowledge; keep [flash] for transient success
  /// confirmations only.
  void showError(String? msg) => showAppError(msg);

  /// Dismisses the global error popup.
  void dismissError() => dismissAppError();

  MonthData? cur() => data[year]?[kMonthKeys[monthIdx]];

  void ensureYear(int yr) {
    if (!data.containsKey(yr)) {
      final map = <String, MonthData>{};
      for (final mk in kMonthKeys) {
        final month = MonthData();
        for (final c in cats) {
          month.blocks[c.key] = [];
        }
        map[mk] = month;
      }
      data[yr] = map;
    }
    _syncRecurringSeries();
  }

  int _monthOrd(int yr, int mIdx) => yr * 12 + mIdx;

  String? _seriesIdFor(ExpenseItem it) {
    final raw = it.seriesId?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return it.recurring ? it.id : null;
  }

  bool _monthAllowedByEnd(int yr, int mIdx, String? recurEndDate) {
    final end = normalizeRecurringEndDate(recurEndDate);
    if (end == null) return true;
    final parts = end.split('-');
    if (parts.length != 3) return true;
    final endYear = int.tryParse(parts[0]);
    final endMonth = int.tryParse(parts[1]);
    if (endYear == null || endMonth == null) return true;
    return _monthOrd(yr, mIdx) <= _monthOrd(endYear, endMonth - 1);
  }

  Iterable<
    ({int year, int monthIdx, String catKey, MonthData month, ExpenseItem item})
  >
  _seriesOccurrences(String seriesId) sync* {
    final years = data.keys.toList()..sort();
    for (final yr in years) {
      final months = data[yr];
      if (months == null) continue;
      for (int mIdx = 0; mIdx < kMonthKeys.length; mIdx++) {
        final month = months[kMonthKeys[mIdx]];
        if (month == null) continue;
        for (final entry in month.blocks.entries) {
          for (final it in entry.value) {
            if (_seriesIdFor(it) == seriesId) {
              yield (
                year: yr,
                monthIdx: mIdx,
                catKey: entry.key,
                month: month,
                item: it,
              );
            }
          }
        }
      }
    }
  }

  void _syncRecurringSeries() {
    if (data.isEmpty) return;
    final years = data.keys.toList()..sort();
    final maxOrd = _monthOrd(years.last, kMonthKeys.length - 1);
    final seriesIds = <String>{};
    for (final yr in years) {
      final months = data[yr];
      if (months == null) continue;
      for (final month in months.values) {
        seriesIds.addAll(month.seriesStops);
        for (final items in month.blocks.values) {
          for (final it in items) {
            final seriesId = _seriesIdFor(it);
            if (seriesId != null) seriesIds.add(seriesId);
          }
        }
      }
    }
    for (final seriesId in seriesIds) {
      final occurrences = _seriesOccurrences(seriesId).toList()
        ..sort(
          (a, b) => _monthOrd(
            a.year,
            a.monthIdx,
          ).compareTo(_monthOrd(b.year, b.monthIdx)),
        );
      if (occurrences.isEmpty) continue;
      // Per-month exceptions (#292) never act as anchors: their edits apply
      // to their own month only and must not rewrite the months after them.
      final explicit = occurrences
          .where((o) => !o.item.generated && !o.item.exception)
          .toList();
      final anchors = explicit.isNotEmpty ? explicit : [occurrences.first];
      final stopOrds = <int>{
        for (final yr in years)
          for (int mIdx = 0; mIdx < kMonthKeys.length; mIdx++)
            if ((data[yr]?[kMonthKeys[mIdx]]?.seriesStops ?? const <String>[])
                .contains(seriesId))
              _monthOrd(yr, mIdx),
      }.toList()..sort();
      final anchorOrds =
          anchors.map((o) => _monthOrd(o.year, o.monthIdx)).toList()..sort();
      final allowedGenerated = <int>{};

      for (final anchor in anchors) {
        final anchorOrd = _monthOrd(anchor.year, anchor.monthIdx);
        final nextAnchorOrd = anchorOrds.firstWhere(
          (ord) => ord > anchorOrd,
          orElse: () => maxOrd + 1,
        );
        final stopOrd = stopOrds.firstWhere(
          (ord) => ord >= anchorOrd,
          orElse: () => maxOrd + 1,
        );
        var endExclusive = math.min(nextAnchorOrd, stopOrd);
        if (anchor.item.recurring && anchor.item.recurEndDate != null) {
          final endIso = normalizeRecurringEndDate(anchor.item.recurEndDate);
          if (endIso != null) {
            final p = endIso.split('-');
            if (p.length == 3) {
              final endYear = int.tryParse(p[0]);
              final endMonth = int.tryParse(p[1]);
              if (endYear != null && endMonth != null) {
                endExclusive = math.min(
                  endExclusive,
                  _monthOrd(endYear, endMonth - 1) + 1,
                );
              }
            }
          }
        }
        if (!anchor.item.recurring) continue;
        // Issue #191: a custom `recurEvery` skips months in between so the
        // series only lands on multiples of the interval away from the
        // anchor (e.g. every 3 months), instead of every single month.
        final every = anchor.item.recurEvery < 1 ? 1 : anchor.item.recurEvery;
        for (var ord = anchorOrd + 1; ord < endExclusive; ord++) {
          if ((ord - anchorOrd) % every != 0) continue;
          final yr = ord ~/ 12;
          final mIdx = ord % 12;
          if (!data.containsKey(yr)) continue;
          final month = data[yr]?[kMonthKeys[mIdx]];
          if (month == null) continue;
          if (month.closed) continue;
          // #293 "Skip this month only": the occurrence was removed for just
          // this month — don't regenerate it, but keep the series going.
          if (month.seriesSkips.contains(seriesId)) continue;
          final existing = occurrences
              .where((o) => o.year == yr && o.monthIdx == mIdx)
              .firstOrNull;
          if (existing == null) {
            month.blocks.putIfAbsent(anchor.catKey, () => <ExpenseItem>[]);
            final nextItem = anchor.item.copyWithId(uid(), generated: true)
              ..paid = false
              ..until = anchor.item.recurEndDate ?? anchor.item.until;
            month.blocks[anchor.catKey]!.add(nextItem);
            occurrences.add((
              year: yr,
              monthIdx: mIdx,
              catKey: anchor.catKey,
              month: month,
              item: nextItem,
            ));
          } else if (existing.item.generated) {
            existing.item
              ..payee = anchor.item.payee
              ..label = anchor.item.label
              ..marker = anchor.item.marker
              ..amount = anchor.item.amount
              ..account = anchor.item.account
              ..recurring = anchor.item.recurring
              ..recurEvery = anchor.item.recurEvery
              ..seriesId = _seriesIdFor(anchor.item)
              ..recurEndDate = anchor.item.recurEndDate
              ..shift = anchor.item.shift
              ..day = anchor.item.day
              ..cardId = anchor.item.cardId
              ..createdBy = anchor.item.createdBy
              ..createdAt = anchor.item.createdAt
              ..until = anchor.item.recurEndDate ?? anchor.item.until;
          }
          allowedGenerated.add(ord);
        }
      }

      for (final occ in occurrences) {
        if (!occ.item.generated || occ.month.closed) continue;
        final ord = _monthOrd(occ.year, occ.monthIdx);
        final manualInMonth = occ.month.blocks.values.any(
          (items) =>
              items.any((it) => _seriesIdFor(it) == seriesId && !it.generated),
        );
        final allowed =
            allowedGenerated.contains(ord) &&
            !manualInMonth &&
            _monthAllowedByEnd(occ.year, occ.monthIdx, occ.item.recurEndDate);
        if (!allowed) {
          occ.month.blocks[occ.catKey]?.removeWhere(
            (it) => identical(it, occ.item),
          );
        }
      }
    }
  }

  Account accByKey(String k) => accounts.firstWhere(
    (a) => a.key == k,
    orElse: () => accounts.isNotEmpty ? accounts.last : defaultAccounts().first,
  );

  Category? catByKey(String k) {
    for (final c in cats) {
      if (c.key == k) return c;
    }
    return null;
  }

  List<Category> catsForMonth(int mIdx, [int? yr]) {
    yr ??= year;
    final m = data[yr]?[kMonthKeys[mIdx]];
    if (m != null && m.closed && m.catsSnapshot != null) {
      return m.catsSnapshot!;
    }
    return cats
        .where(
          (c) => !c.temporary || (c.ownerYear == yr && c.ownerMonthIdx == mIdx),
        )
        .toList();
  }

  List<Account> accountsForMonth(int mIdx, [int? yr]) {
    yr ??= year;
    final m = data[yr]?[kMonthKeys[mIdx]];
    if (m != null && m.closed && m.accountsSnapshot != null) {
      return m.accountsSnapshot!;
    }
    return accounts;
  }

  bool isClosed([int? mIdx, int? yr]) {
    yr ??= year;
    final m = data[yr]?[kMonthKeys[mIdx ?? monthIdx]];
    return m?.closed ?? false;
  }

  void closeMonth() {
    mutate(() {
      final m = data[year]![kMonthKeys[monthIdx]]!;
      m.closed = true;
      m.catsSnapshot = catsForMonth(
        monthIdx,
        year,
      ).map((c) => c.copy()).toList();
      m.accountsSnapshot = accounts.map((a) => a.copy()).toList();
    }, () => flash('Month closed'));
  }

  void reopenMonth() {
    mutate(() {
      final m = data[year]![kMonthKeys[monthIdx]]!;
      m.closed = false;
      m.catsSnapshot = null;
      m.accountsSnapshot = null;
    }, () => flash('Month reopened'));
  }

  void setYear(int y) {
    ensureYear(y);
    update(() {
      year = y;
      statsHeroSelIdx = null;
    });
    _schedulePersist();
  }

  void moveAccount(String key, int dir) {
    final i = accounts.indexWhere((a) => a.key == key);
    final j = i + dir;
    if (j < 0 || j >= accounts.length) return;
    update(() {
      final t = accounts[i];
      accounts[i] = accounts[j];
      accounts[j] = t;
    });
    _schedulePersist();
  }

  void moveBlock(String key, int dir) {
    final i = cats.indexWhere((c) => c.key == key);
    final j = i + dir;
    if (j < 0 || j >= cats.length) return;
    update(() {
      final t = cats[i];
      cats[i] = cats[j];
      cats[j] = t;
    });
    _schedulePersist();
  }

  // ---------------------------------------------------------------- nav
  void go(String s) {
    update(() {
      screen = s;
      swipedId = null;
    });
    _schedulePersist();
  }

  void setMonth(int d) {
    update(() {
      monthIdx = (monthIdx + d + 12) % 12;
      swipedId = null;
      statsHeroSelIdx = null;
    });
    _syncRecurringSeries();
    _schedulePersist();
  }

  void pickMonth(int i) {
    update(() {
      monthIdx = i;
      swipedId = null;
      statsHeroSelIdx = null;
    });
    _syncRecurringSeries();
    _schedulePersist();
  }

  void toggleCollapse(String k) =>
      setState(() => collapsed[k] = !(collapsed[k] ?? false));

  // ------------------------------------------------------------ toggles
  void togglePaid(String catKey, String id) {
    if (isClosed()) return;
    mutate(() {
      final arr = data[year]?[kMonthKeys[monthIdx]]?.blocks[catKey];
      // An empty/missing block can happen when a concurrent snapshot replaced
      // this month between render and tap — `arr.first` as an orElse would
      // itself throw on an empty list.
      if (arr == null) return;
      for (final it in arr) {
        if (it.id == id) {
          it.paid = !it.paid;
          // Paying an item that carries a discount card counts as a card
          // use (design `togglePaid`).
          if (it.paid && it.cardId != null) {
            cardById(it.cardId)?.logUse(DateTime.now().millisecondsSinceEpoch);
          }
          return;
        }
      }
    });
  }

  /// Toggles the "received" flag of an income item. Income items live in
  /// income-direction blocks now (issue #137), so this resolves the owning
  /// block and flips its `paid` flag.
  void toggleReceived(String id) {
    if (isClosed()) return;
    final m = data[year]?[kMonthKeys[monthIdx]];
    if (m == null) return;
    for (final c in cats.where((c) => c.isIncome)) {
      if ((m.blocks[c.key] ?? const <ExpenseItem>[]).any((x) => x.id == id)) {
        togglePaid(c.key, id);
        return;
      }
    }
  }

  // --------------------------------------------------------------- delete confirm
  void askDelete(
    String name,
    String message,
    VoidCallback onConfirm, {
    String confirmLabel = 'Delete',
  }) {
    setState(() => swipedId = null);
    showDialog<void>(
      context: context,
      barrierColor: const Color(0x80101828),
      builder: (ctx) => _ConfirmDialog(
        name: name,
        message: message,
        confirmLabel: confirmLabel,
        onCancel: () => Navigator.of(ctx).pop(),
        onDelete: () {
          Navigator.of(ctx).pop();
          onConfirm();
        },
      ),
    );
  }

  // -------------------------------------------------------------- compute
  _Compute compute(int mIdx) {
    final m = data[year]?[kMonthKeys[mIdx]] ?? MonthData();

    double expIncome = 0, realIncome = 0;
    double totalBudget = 0, totalPaid = 0, savings = 0;
    final blocks = <_BlockCompute>[];
    final acctTotals = <String, double>{};
    final accts = accountsForMonth(mIdx);
    for (final a in accts) {
      acctTotals[a.key] = 0;
    }
    for (final c in catsForMonth(mIdx)) {
      final items = m.blocks[c.key] ?? const <ExpenseItem>[];
      double bud = 0, paid = 0;
      final rows = <_RowCompute>[];
      for (final it in items) {
        final amt = it.amount;
        bud += amt;
        if (it.paid) {
          paid += amt;
        } else if (!c.isIncome) {
          // Income blocks never feed the "still to pay from" account totals.
          acctTotals[it.account] = (acctTotals[it.account] ?? 0) + amt;
        }
        final ul = (c.hasUntil || it.recurring || it.recurEndDate != null)
            ? untilLabel(it.recurEndDate ?? it.until)
            : null;
        rows.add(
          _RowCompute(
            item: it,
            untilLabel: ul,
            untilState: ul != null
                ? untilState(ul, mIdx, year)
                : UntilState.future,
          ),
        );
      }
      if (c.isIncome) {
        expIncome += bud;
        realIncome += paid;
      } else {
        totalBudget += bud;
        totalPaid += paid;
        if (c.isSavings) savings += bud;
      }
      final cap = m.caps[c.key];
      blocks.add(
        _BlockCompute(
          key: c.key,
          title: c.title,
          icon: c.icon,
          emoji: c.emoji,
          picture: c.picture,
          tone: c.tone,
          bg: c.bg,
          hasUntil: c.hasUntil,
          isIncome: c.isIncome,
          isSavings: c.isSavings,
          items: rows,
          total: bud,
          paid: paid,
          cap: cap,
          count: items.length,
        ),
      );
    }
    final stillToPay = math.max(0, totalBudget - totalPaid).toDouble();
    return _Compute(
      monthIdx: mIdx,
      expIncome: expIncome,
      realIncome: realIncome,
      savings: savings,
      blocks: blocks,
      totalBudget: totalBudget,
      totalPaid: totalPaid,
      stillToPay: stillToPay,
      expectedBalance: expIncome - totalBudget,
      balance: realIncome - totalBudget,
      acctTotals: acctTotals,
      accounts: accts,
      closed: isClosed(mIdx),
    );
  }

  // =============================================================== build
  @override
  Widget build(BuildContext context) {
    final authOpen = ready && user == null;
    final familyLoading =
        ready && user != null && families.isEmpty && _resolvingFamilies;
    final onboardingOpen =
        ready && user != null && families.isEmpty && !_resolvingFamilies;
    // The nav bar + FAB only make sense once the budget/family gates are
    // all clear — same condition every gate below uses.
    final shellReady = ready && !authOpen && !familyLoading && !onboardingOpen;
    if (shellReady && !_didSyncImportsOnOpen) {
      _didSyncImportsOnOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => syncDueImports());
    }
    final bottomSystemInset = shellReady ? _bottomSystemInset(context) : 0.0;
    return Scaffold(
      backgroundColor: B.page,
      // Resize above the keyboard whenever a full-screen, text-entry gate is
      // shown so its fields scroll into view instead of hiding behind the
      // keyboard (issue #129). The budget screen edits via bottom sheets, which
      // handle their own insets, so it doesn't need this.
      resizeToAvoidBottomInset: authOpen || onboardingOpen,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ready
                      ? _buildBody()
                      : const Center(
                          child: Text(
                            'Loading budget…',
                            style: TextStyle(
                              color: B.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                if (shellReady) _buildNav(),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 36 + bottomSystemInset,
              child: ValueListenableBuilder<String?>(
                valueListenable: _toastNotifier,
                builder: (context, msg, _) => msg == null
                    ? const SizedBox.shrink()
                    : Center(child: _buildToast(msg)),
              ),
            ),
            ?(shellReady
                ? _buildFab(bottomSystemInset: bottomSystemInset)
                : null),
            // Auth gate: covers the app until a user is signed in.
            if (authOpen) Positioned.fill(child: _AuthScreen(state: this)),
            // While a signed-in user's cloud families are still loading, show a
            // loader instead of the onboarding gate so we don't flash create/
            // join to someone who already has a family (#120).
            if (familyLoading)
              const Positioned.fill(child: _FamilyLoadingScreen()),
            // Onboarding gate: a signed-in user with confirmed-no family must
            // create or join one before reaching the budget.
            if (onboardingOpen)
              Positioned.fill(child: _OnboardingScreen(state: this)),
          ],
        ),
      ),
    );
  }

  Widget _buildToast(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: B.ink,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .4),
            blurRadius: 28,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ic('check', size: 14, sw: 2.8, color: const Color(0xff4ade80)),
          const SizedBox(width: 7),
          // Flexible so long toasts ("Groceries paid with Albert Heijn")
          // ellipsize instead of overflowing the pill.
          Flexible(
            child: Text(
              msg,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          if (toastUndo != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              key: const ValueKey('toast-undo'),
              onTap: () {
                final undo = toastUndo;
                toastUndo = null;
                _toastTimer?.cancel();
                _toastNotifier.value = null;
                undo?.call();
              },
              // The pill is small; pad the label up to a comfortable target.
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(
                  'Undo',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff5eead4),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (tab != 'finance') return _renderTab(tab);
    switch (screen) {
      case 'stats':
        return _buildStats();
      case 'flow':
        return _buildFlow();
      default:
        return _buildOverview();
    }
  }

  // ------------------------------------------------------------- header
  Widget _buildHeader() {
    String title = 'Thrive';
    String subtitle = 'Loading…';
    if (ready) {
      if (tab == 'finance') {
        final titles = <String, List<String>>{
          'overview': ['Overview', '${kMonthsEn[monthIdx]} $year'],
          'flow': ['Money calendar', '${kMonthsEn[monthIdx]} $year'],
          'stats': ['Statistics', _statsPeriod().label],
        };
        final t = titles[screen] ?? titles['overview']!;
        title = t[0];
        subtitle = t[1];
      } else {
        final meta = _tabMeta(tab);
        title = meta.$1;
        subtitle = meta.$2;
      }
    }
    final subHeader = ready
        ? (tab == 'finance' && screen == 'stats'
              ? _buildStatsModeSwitcher()
              : tab == 'finance' && screen == 'flow'
              ? _buildFlowSubHeader()
              : _tabSubHeader(tab))
        : null;
    final dateInHeader = tab == 'calendar' || tab == 'finance';

    return Container(
      color: B.page,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                key: const ValueKey('profile-avatar'),
                onTap: user != null ? openProfileScreen : null,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff0F8A76).withValues(alpha: .6),
                        blurRadius: 14,
                        spreadRadius: -3,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _headerAvatar(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  key: tab == 'calendar'
                      ? const ValueKey('cal-month-title')
                      : tab == 'finance'
                      ? const ValueKey('month-chip')
                      : null,
                  behavior: HitTestBehavior.opaque,
                  onTap: tab == 'calendar'
                      ? openCalPeriodPicker
                      : tab == 'finance'
                      ? openMonthPicker
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.3,
                          color: B.ink,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              subtitle,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: B.muted,
                              ),
                            ),
                          ),
                          if (dateInHeader) ...[
                            const SizedBox(width: 3),
                            ic('cdown', size: 12, sw: 2.4, color: B.muted),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (tab == 'finance') _buildFinanceHeaderActions(),
              if (tab == 'calendar') _calHeaderActions(),
            ],
          ),
          if (subHeader != null) ...[const SizedBox(height: 13), subHeader],
        ],
      ),
    );
  }

  Widget _buildSwitcher() {
    Widget seg(String k, String icon) {
      final active = screen == k;
      return GestureDetector(
        key: ValueKey('tab-$k'),
        onTap: () => go(k),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(left: 8),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active ? B.soft : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? B.primary : B.line),
          ),
          child: Center(
            child: ic(
              icon,
              size: 18,
              sw: 2.1,
              color: active ? B.deep : B.soft2,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        seg('overview', 'grid'),
        seg('flow', 'cal'),
        seg('stats', 'chart'),
      ],
    );
  }

  Widget _buildFinanceHeaderActions() {
    final closed = isClosed();
    final lockButton = GestureDetector(
      key: const ValueKey('lock-btn'),
      onTap: () => closed ? reopenMonth() : openCloseConfirm(),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: closed ? B.ink : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: closed ? B.ink : B.line),
        ),
        child: Center(
          child: ic(
            closed ? 'lock' : 'unlock',
            size: 18,
            sw: 2.1,
            color: closed ? Colors.white : B.soft2,
          ),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_buildSwitcher(), lockButton],
    );
  }

  Widget _buildStatsModeSwitcher() {
    Widget seg(String label, String val) {
      final active = statsMode == val;
      return Expanded(
        child: GestureDetector(
          key: ValueKey('stats-$val'),
          onTap: () => setState(() {
            statsMode = val;
            statsHeroSelIdx = null;
          }),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .12),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: active ? B.primary : const Color(0xff8995a6),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xffe8ecf2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          seg('Month', 'month'),
          seg('Year', 'year'),
          seg('All time', 'all'),
        ],
      ),
    );
  }
}

// ====================================================== compute records
class _Compute {
  _Compute({
    required this.monthIdx,
    required this.expIncome,
    required this.realIncome,
    required this.savings,
    required this.blocks,
    required this.totalBudget,
    required this.totalPaid,
    required this.stillToPay,
    required this.expectedBalance,
    required this.balance,
    required this.acctTotals,
    required this.accounts,
    required this.closed,
  });

  final int monthIdx;
  final double expIncome, realIncome;

  /// Planned amount across blocks flagged [Category.isSavings] (issue #136).
  final double savings;
  final List<_BlockCompute> blocks;
  final double totalBudget, totalPaid, stillToPay, expectedBalance, balance;
  final Map<String, double> acctTotals;
  final List<Account> accounts;
  final bool closed;

  /// Income-direction blocks, kept separate for the overview's income section.
  Iterable<_BlockCompute> get incomeBlocks => blocks.where((b) => b.isIncome);

  /// Withdrawing (expense) blocks — everything that is not income.
  Iterable<_BlockCompute> get expenseBlocks => blocks.where((b) => !b.isIncome);
}

class _BlockCompute {
  _BlockCompute({
    required this.key,
    required this.title,
    required this.icon,
    required this.tone,
    required this.bg,
    required this.hasUntil,
    required this.isIncome,
    required this.isSavings,
    required this.items,
    required this.total,
    required this.paid,
    required this.cap,
    required this.count,
    this.emoji,
    this.picture,
  });

  final String key, title, icon;
  final String? emoji, picture;
  final Color tone, bg;
  final bool hasUntil;
  final bool isIncome;
  final bool isSavings;
  final List<_RowCompute> items;
  final double total, paid;
  final double? cap;
  final int count;
}

class _RowCompute {
  _RowCompute({
    required this.item,
    required this.untilLabel,
    required this.untilState,
  });

  final ExpenseItem item;
  final String? untilLabel;
  final UntilState untilState;
}

// ============================================ family loading gate widget
/// Full-screen loader shown while a just-signed-in user's shared families are
/// fetched from the cloud, so the onboarding gate never flashes for someone who
/// already belongs to a family (#120).
class _FamilyLoadingScreen extends StatelessWidget {
  const _FamilyLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: B.page,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: B.primary,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Loading your family…',
              style: TextStyle(
                color: B.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================== confirm dialog widget
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.name,
    required this.message,
    required this.onCancel,
    required this.onDelete,
    this.confirmLabel = 'Delete',
  });

  final String name;
  final String message;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(26),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 312),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: B.redSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: ic('trash', size: 23, sw: 2.2, color: B.red),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              '$confirmLabel ${name.isNotEmpty ? '\u201C$name\u201D' : 'this'}?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
                color: B.ink,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: B.soft2,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 19),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: B.line),
                      ),
                      child: const Text(
                        'Cancel',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: B.text,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: B.red,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        confirmLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Top-level so [foundation.compute] can send it to a worker isolate.
Map<String, dynamic> _jsonDecodeMap(String raw) =>
    json.decode(raw) as Map<String, dynamic>;
