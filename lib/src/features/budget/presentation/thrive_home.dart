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

  /// Kid accounts: the full-screen kid gate.
  ValueNotifier<KidGate?> get kidGate => _s.kidGate;

  /// Kid accounts: the once-per-login welcome check for [uid].
  Future<void> maybeKidWelcome(String uid) => _s._maybeKidWelcome(uid);

  /// Kid accounts: [fid] is dropped while this login is kid [kidMemberId].
  void noteKidFamilyDropped(String fid, String kidMemberId) {
    _s._kidMemberIdByFid[fid] = kidMemberId;
    _s._noteKidFamilyDropped(fid);
    _s._kidMemberIdByFid.remove(fid);
  }

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

  String? findIncomeId(String payee, String label, [int? mIdx, int? yr]) {
    yr ??= _s.year;
    mIdx ??= _s.monthIdx;
    final items =
        _s.data[yr]?[kMonthKeys[mIdx]]?.blocks[kIncomeBlockKey] ?? const [];
    return items
        .where((it) => it.payee == payee && it.label == label)
        .firstOrNull
        ?.id;
  }

  void openEntry(String catKey, String id) =>
      _s.openEntryTicket(cat: catKey, id: id);

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
  void flash(String msg, {ToastTone tone = ToastTone.success, String? body}) =>
      _s.flash(msg, tone: tone, body: body);
  ToastTone get toastTone => _s.toastTone;
  String? get toastBody => _s.toastBody;

  /// The unsaved-changes journal, so tests can seed entries to review.
  PendingChanges get pendingChanges => _s._pending;
  PendingChanges get stagedChanges => _s._staged;
  void promptUnsavedChanges() => _s.promptUnsavedChanges();
  void pendingChangesChanged() => _s.pendingChangesTick.value++;

  /// Sync/offline indicator plumbing (#283), so tests can read the pill
  /// state and simulate the offline queue without a real backend.
  ValueNotifier<SettingsSyncStatus?> get syncStatus => _s.syncStatus;
  ValueNotifier<bool> get netOffline => _s.netOffline;
  void syncBlip() => _s.syncBlip();
  Future<bool> syncNow() => _s.syncNow();
  void showWaitingToSyncSheet() => _s._showWaitingToSyncSheet();
  void saveMemberStudio(
    String id, {
    required String name,
    required String email,
    required Color color,
    String? photo,
    String? emoji,
    bool? kid,
  }) => _s.saveMemberStudio(
    id,
    name: name,
    email: email,
    color: color,
    photo: photo,
    emoji: emoji,
    kid: kid,
  );
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
  void deleteEvent(String id, String scope, [String? date]) =>
      _s.deleteEvent(id, scope, date);
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

  /// Runs the real recurring-series sync on [ws] (as the active workspace).
  Workspace syncRecurringSeries(Workspace ws) {
    final s = _s;
    final prev = s.workspaces[s.familyId];
    s.workspaces[s.familyId] = ws;
    try {
      s._syncRecurringSeries();
    } finally {
      if (prev == null) {
        s.workspaces.remove(s.familyId);
      } else {
        s.workspaces[s.familyId] = prev;
      }
    }
    return ws;
  }

  List<(Category, ExpenseItem)> unpaidItemsThisMonth() =>
      _s.unpaidItemsThisMonth();
  Map<String, dynamic> phoneWidgetPayload() => _s.phoneWidgetPayload();
  void handleWidgetLaunch(Uri uri) => _s.handleWidgetLaunch(uri);
  bool get widgetHideAmounts => _s.widgetHideAmounts;
  bool get notificationsEnabled => _s.notificationsEnabled;
  bool get deviceCalendarSyncEnabled => _s.deviceCalendarSyncEnabled;
  void toggleWidgetHideAmounts() => _s.toggleWidgetHideAmounts();
  List<String> get navPickedTabs => _s.navPickedTabs;
  List<String> get navMoreSections => _s.navMoreSections;
  void setNavTabs(List<String> picked) => _s.setNavTabs(picked);
  void openNavTabEditor() => _s.openNavTabEditor();
  List<BoardEntry>? get homeBoard => _s.homeBoard;
  set homeBoard(List<BoardEntry>? v) => _s.homeBoard = v;
  List<BoardEntry> effectiveHomeBoard() => _s.effectiveHomeBoard();
  bool amIKidProfile() => _s.amIKidProfile();
  bool get isChildUser => _s.isChildUser;
  List<TaskList> get visibleTaskLists => _s.visibleTaskLists;
  List<ShoppingList> get visibleShoppingLists => _s.visibleShoppingLists;
  List<CalendarOccurrence> eventOccurrences(String from, String to) =>
      _s.eventOccurrences(from, to);
  void setMeal(String dateIso, String slot, String value) =>
      _s.setMeal(dateIso, slot, value);
  void saveTaskList(String name, Color color) => _s.saveTaskList(name, color);
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
  List<SavedMeal> get savedMeals => _s.savedMeals;
  void saveDayPlan(String dateIso, DayPlan draft) =>
      _s.saveDayPlan(dateIso, draft);
  bool toggleFavouriteMeal(String name, List<String> ingredients) =>
      _s.toggleFavouriteMeal(name, ingredients);
  void toggleIngredientOnGroceries(String ingredient) =>
      _s.toggleIngredientOnGroceries(ingredient);
  int addMissingToGroceries(List<String> ingredients) =>
      _s.addMissingToGroceries(ingredients);
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
      'overview'; // overview | calendar | list | stats — Finance tab's sub-view
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
  List<SavedMeal> get savedMeals => _activeWs.savedMeals;
  set savedMeals(List<SavedMeal> v) => _activeWs.savedMeals = v;
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
  bool _headerScrolled = false;

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
  /// The sections this person picked for their bottom bar (#365). Per-user,
  /// never per-family — two members of one family have independent bars.
  /// null means "never customised", which reads as [kDefaultNavTabs].
  List<String>? navTabs;
  int weekOffset = 0; // 0 = current week, +/- N weeks navigated
  /// Day picked on the meal plan's day strip (ISO date); null = today.
  String? mealDaySel;
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

  /// Write-status pill on the Settings v2 sub-page headers (#283): every
  /// mutation blips "Saving…" → "Saved ✓" once the server acknowledged it,
  /// or "Not saved — offline" when it didn't (there is no offline queue).
  final ValueNotifier<SettingsSyncStatus?> syncStatus =
      ValueNotifier<SettingsSyncStatus?>(null);

  /// Whether the last cloud save failed (offline / timed out / rejected):
  /// flips the sync pill to "Not saved — offline" and shows the amber
  /// "Not saved" banners; cleared by the next successful save (retried with
  /// backoff). Always false in local/demo mode, where SharedPreferences
  /// writes are the durable store.
  final ValueNotifier<bool> netOffline = ValueNotifier<bool>(false);
  Timer? _syncSettleTimer;
  Timer? _syncClearTimer;

  /// Design `syncBlip()`: "Saving…" now; after 600 ms it settles to
  /// "Saved ✓" — but only once the save was actually acknowledged (a save
  /// still in flight settles when it finishes) — or "Not saved" when it
  /// failed. Clears 1800 ms after settling.
  void syncBlip() {
    if (!mounted) return;
    syncStatus.value = netOffline.value
        ? SettingsSyncStatus.queued
        : SettingsSyncStatus.saving;
    _syncSettleTimer?.cancel();
    _syncClearTimer?.cancel();
    _settleSyncWhenSaved = false;
    _syncSettleTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (_persistRun != null) {
        _settleSyncWhenSaved = true;
        return;
      }
      _settleSyncStatus();
    });
  }

  bool _settleSyncWhenSaved = false;

  /// Saves the changes waiting on this phone now, showing "Syncing N
  /// changes" until the save finishes ("Saved", or back to offline).
  Future<bool> syncNow() async {
    if (!mounted) return false;
    syncingChangeCount = visiblePendingChanges.length;
    _syncSettleTimer?.cancel();
    _syncClearTimer?.cancel();
    _settleSyncWhenSaved = false;
    syncStatus.value = SettingsSyncStatus.syncing;
    _saveRetryTimer?.cancel();
    final ok = await _persist();
    if (!mounted) return ok;
    _settleSyncStatus();
    return ok;
  }

  void _settleSyncStatus() {
    if (!mounted || syncStatus.value == null) return;
    syncStatus.value = netOffline.value
        ? SettingsSyncStatus.queued
        : SettingsSyncStatus.saved;
    _syncClearTimer?.cancel();
    _syncClearTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) syncStatus.value = null;
    });
  }

  /// When set, the toast pill carries an Undo button that runs this and
  /// dismisses the toast (fridge door #315: cross-off has no confirm dialog,
  /// only a 4-second Undo).
  VoidCallback? toastUndo;

  /// The current toast's tone (glyph + colour) and optional second line.
  ToastTone toastTone = ToastTone.success;
  String? toastBody;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _cloudSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _familySub;

  /// The active family's record listeners: one per collection, or the
  /// kid-scoped queries (plus the settings doc) for a child user.
  final List<StreamSubscription<Object?>> _recordSubs = [];

  /// Families whose access is being re-checked after a permission-denied
  /// stream error (a kid restriction rather than a removal).
  final Set<String> _accessRechecks = {};

  /// Families where the signed-in login is a kid per the family doc's
  /// `kidUids` (what the security rules enforce): family id → kid member
  /// id. Those families load through kid-scoped queries only.
  final Map<String, String> _kidMemberIdByFid = {};

  /// The full-screen kid gate (welcome, first run, errors), or null.
  final ValueNotifier<KidGate?> kidGate = ValueNotifier<KidGate?>(null);

  /// The access change whose notice this session already handled.
  int? _accessNoticeShownAt;

  /// Kid-scoped loading: family → collection → query tag → record keys that
  /// tag currently delivers. A record leaves the base only when no tag holds
  /// it.
  final Map<String, Map<String, Map<String, Set<String>>>> _scopedIds = {};

  /// A kid's per-note lines listeners (note key → subscription).
  final Map<String, StreamSubscription<Object?>> _kidLineSubs = {};
  bool _applyingCloudSnapshot = false;

  /// The family id the Firestore family/workspace streams are currently bound
  /// to, so the user-doc listener only rebinds when the active family truly
  /// changes (its own persist echoes used to trigger a full resubscribe).
  String? _boundFamilyId;

  /// Per-family normalized copy of every workspace record the server (or the
  /// local Firestore cache, which includes our own queued writes) holds —
  /// record key `<collection>/<docId>` → payload (see cloud_records.dart).
  /// It's the "last version this device knew": a persist writes only the
  /// fields where the in-memory workspace differs from it, and an incoming
  /// snapshot is rebased onto it, so a device never re-uploads data it didn't
  /// change.
  final Map<String, Records> _cloudBase = {};

  /// Per-family record collections whose contents are known (a server read,
  /// or a non-empty cache read). New docs are only created in a known
  /// collection, so an unloaded one can't be overwritten blind.
  final Map<String, Set<String>> _cloudLoaded = {};

  /// Per-family legacy single-doc `workspace` blob still on the meta doc.
  final Map<String, Map<String, dynamic>> _legacyBlob = {};

  /// Per-family normalized meta-doc fields last seen on the server.
  final Map<String, Map<String, dynamic>> _metaBase = {};

  /// Families whose legacy docs are being migrated right now.
  final Set<String> _legacyMigrating = {};

  /// Per-family guarded record keys (events, notes, lines) the user
  /// explicitly deleted and not yet deleted on the server. Only these may be
  /// removed from the server — anything else missing locally is a sync
  /// glitch and is restored (see `unintendedDeletes`).
  final Map<String, Set<String>> _deleteIntents = {};

  /// Per-family note keys deleted on the server since this device saw them:
  /// lines still filed under them are deleted too.
  final Map<String, Set<String>> _goneNotes = {};

  /// Changes not yet confirmed by the server (persisted on the device, so
  /// they survive a restart) — reviewable in Settings → Unsaved changes.
  PendingChanges _pending = PendingChanges();

  /// Unsaved changes from a previous run, set aside in the user's staging
  /// area in Firestore until they're applied or discarded.
  PendingChanges _staged = PendingChanges();

  /// Families (besides the active one) with changes to save on the next
  /// persist (staged changes just applied).
  final Set<String> _persistAlso = {};

  /// Whether this session already offered to review set-aside changes.
  bool _unsavedPromptShown = false;

  /// Bumped whenever [_pending] changes (drives the review screen).
  final ValueNotifier<int> pendingChangesTick = ValueNotifier(0);

  /// Per-family record keys this device has created on the server whose
  /// write isn't acknowledged yet. The SDK reverting such a write (e.g. a
  /// rejected batch) must not wipe the local copy.
  final Map<String, Map<String, int>> _inflightCreates = {};

  /// Per-family [kVersionField] of every record as last seen on the server
  /// (or as set by this device's own acknowledged save).
  final Map<String, Map<String, int>> _cloudVersions = {};

  /// Per-family records whose versioned save is in flight → the server
  /// version the save started from. Server changes arriving meanwhile are
  /// merged against it, so they never drop the edit being saved.
  final Map<String, Map<String, Map<String, dynamic>>> _inflightUpdates = {};

  /// When each `<familyId>/<collection>` was last reloaded from the server
  /// on opening a screen (see `reloadFromServer`).
  final Map<String, DateTime> _lastServerReload = {};

  /// A family stream died (not a permission error): re-subscribe on resume.
  bool _streamsBroken = false;

  /// A save-conflict dialog is showing (further conflicts only toast).
  bool _conflictDialogOpen = false;

  /// Signed in but the server couldn't be reached to load the families:
  /// there is no offline copy to fall back to, so a "Can't connect" screen
  /// with Retry covers the app (never the create/join onboarding).
  bool _cloudUnreachable = false;

  /// Every edit is saved IMMEDIATELY (no debounce): [_persist] runs at once,
  /// and edits made while a save is in flight are coalesced into exactly one
  /// follow-up save. [_persistRun] is the save in flight; [_persistGeneration]
  /// counts saves started (a server reload that raced one is dropped).
  Future<bool>? _persistRun;
  bool _persistAgain = false;
  Completer<bool>? _persistNext;
  int _persistGeneration = 0;

  /// Retry of a save that wasn't acknowledged (offline / rejected), with
  /// backoff; [_saveFailures] counts consecutive failures.
  Timer? _saveRetryTimer;
  int _saveFailures = 0;

  /// Debounce for refreshing the Android home-screen widgets (issue #252) —
  /// the save itself is immediate.
  Timer? _widgetPushTimer;

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
    kidGate.dispose();
    WidgetsBinding.instance.removeObserver(this);
    pendingNotificationDeepLink.removeListener(_handleNotificationDeepLink);
    _cloudSub?.cancel();
    _familySub?.cancel();
    for (final sub in _recordSubs) {
      sub.cancel();
    }
    _cancelKidLineSubs();
    _flushPersist();
    _saveRetryTimer?.cancel();
    DeviceCalendarSync.instance.cancelPending();
    _toastTimer?.cancel();
    _syncSettleTimer?.cancel();
    _syncClearTimer?.cancel();
    shopQuickAddFocus.dispose();
    calPageController.dispose();
    calWeekPageController.dispose();
    super.dispose();
  }

  /// Back in the foreground: everything is reloaded from the server (there
  /// is no offline copy — another member may have changed anything while we
  /// were away), dead streams are re-subscribed, an unsaved edit is retried,
  /// and subscribed (auto-sync) ICS imports are refreshed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncDueImports();
      unawaited(_refreshReminderSchedule());
      _reloadOnResume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _flushPersist();
    }
  }

  // coverage:ignore-start
  void _reloadOnResume() {
    final uid = _firebaseUid();
    if (uid == null || !ready || families.isEmpty) return;
    if (_streamsBroken) {
      _streamsBroken = false;
      unawaited(bindCloudSync(uid));
    }
    if (netOffline.value) unawaited(_persist());
    unawaited(reloadFromServer(force: true));
  }
  // coverage:ignore-end

  /// Saves are immediate, so nothing is ever waiting on a timer — only the
  /// home-screen widget refresh is (issue #252): run it now, before the OS
  /// can kill the app.
  void _flushPersist() {
    if (_widgetPushTimer?.isActive != true) return;
    _widgetPushTimer?.cancel();
    unawaited(pushPhoneWidgets());
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
    // Per-device settings restore on EVERY boot path — cloud boots have no
    // v4 blob to carry them, and a local v4 restore later simply re-applies
    // the same values.
    _restoreDevicePrefs(prefs);

    // Firebase boot sync is integration-only here.
    // coverage:ignore-start
    if (_cloudBacked) {
      final uid = _firebaseUid()!;
      // Load the shared families this user belongs to (migrating any legacy
      // single-blob state on first run).
      final bool hadCloud;
      try {
        hadCloud = await cloudBoot(uid);
      } on CloudUnreachable catch (e) {
        debugPrint('[cloud] boot: server unreachable: $e');
        families = [];
        workspaces = {};
        _cloudUnreachable = true;
        if (!mounted) return;
        _finishBoot();
        return;
      }
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
          if (!mounted) return;
          _finishBoot();
          // The local→cloud promotion — EVERY local family pushed (not just
          // the active one), the local pseudo-uid remapped to the Firebase
          // uid, and local copies deleted only after the writes are queued —
          // lives in [_persist]'s cloud branch, shared with the mid-session
          // sign-in path.
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
      unawaited(_kidCheckRemovedLogin(uid));
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
    navTabs = _savedNavTabs(saved['navTabs']);
    calFilter = _savedIdList(saved['calFilter']);
    calCatFilter = _savedIdList(saved['calCatFilter']);
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
    screen = switch (legacyScreen) {
      'overview' || 'stats' || 'calendar' || 'list' => legacyScreen,
      'flow' => 'calendar',
      _ => 'overview',
    };
    if (rawTab == null) {
      tab = 'finance';
      return;
    }
    final t = rawTab.toString();
    tab = kValidTabs.contains(t) ? t : 'home';
  }

  List<String> _savedLayerFilter(Object? raw) {
    final layerIds = <String>[
      for (final l
          in calendarLayers.isEmpty ? kDefaultCalendarLayers() : calendarLayers)
        l.id,
    ];
    final restored = <String>[
      for (final id in (raw as List? ?? const []))
        if (id.toString().trim().isNotEmpty) id.toString(),
    ];
    // Ids the active workspace no longer defines can't be toggled back on from
    // the filter sheet, so keeping them would silently hide the calendar.
    final known = restored.where(layerIds.contains).toList();
    return known.isEmpty ? layerIds : known;
  }

  /// A persisted picked-tab list, or null when the person never customised
  /// their bar. Sanitising happens on read ([navPickedTabs]), so a value
  /// naming a section that no longer exists degrades to the defaults rather
  /// than to a short bar.
  List<String>? _savedNavTabs(Object? raw) {
    if (raw is! List) return null;
    final restored = <String>[
      for (final id in raw)
        if (id.toString().trim().isNotEmpty) id.toString(),
    ];
    return restored.isEmpty ? null : restored;
  }

  /// A persisted id list as-is — an empty/missing value stays empty, which
  /// for [calFilter]/[calCatFilter] means "nothing switched off".
  List<String> _savedIdList(Object? raw) => <String>[
    for (final id in (raw as List? ?? const []))
      if (id.toString().trim().isNotEmpty) id.toString(),
  ];

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
  /// sections are skipped on every save.
  final Map<String, Map<String, String>> _localWsDigests = {};

  /// Saves the current state now: to Firestore when signed in (each create /
  /// edit / delete goes to the server immediately — there is no local copy),
  /// else to local storage. Saves never overlap: one requested while another
  /// is in flight runs once right after it (coalescing a burst of edits).
  /// Completes with whether everything was saved.
  Future<bool> _persist() {
    if (_persistRun != null) {
      _persistAgain = true;
      // It may wait a while (a save timing out offline): journal its changes
      // now so they survive the app being closed meanwhile.
      if (_cloudBacked) _journalWaitingChanges();
      return (_persistNext ??= Completer<bool>()).future;
    }
    final run = _runPersistLoop();
    _persistRun = run;
    return run;
  }

  Future<bool> _runPersistLoop() async {
    var ok = true;
    try {
      ok = await _persistOnce();
      while (_persistAgain) {
        _persistAgain = false;
        final waiting = _persistNext;
        _persistNext = null;
        ok = await _persistOnce();
        waiting?.complete(ok);
      }
    } finally {
      _persistRun = null;
      _persistNext?.complete(ok);
      _persistNext = null;
    }
    _afterSave(ok);
    return ok;
  }

  Future<bool> _persistOnce() async {
    _persistGeneration++;
    try {
      return await _persistNow();
    } catch (e) {
      debugPrint('[persist] save failed: $e');
      return false;
    }
  }

  /// Reflects a finished save: the sync pill / "Not saved" banner, and a
  /// retry with backoff (5 s, 10 s, … 60 s) while saves keep failing.
  void _afterSave(bool ok) {
    _saveRetryTimer?.cancel();
    if (!mounted) return;
    if (!_cloudBacked) {
      // Local/demo mode: there's no server to be "offline" from.
    } else if (ok) {
      _saveFailures = 0;
      if (netOffline.value) netOffline.value = false;
    } else {
      _saveFailures++;
      if (!netOffline.value) netOffline.value = true;
      if (_saveFailures == 1) _showWaitingToSyncSheet();
      final seconds = (5 << (_saveFailures - 1).clamp(0, 4)).clamp(5, 60);
      _saveRetryTimer = Timer(Duration(seconds: seconds), () {
        if (mounted) unawaited(_persist());
      });
    }
    if (_settleSyncWhenSaved) {
      _settleSyncWhenSaved = false;
      _settleSyncStatus();
    }
  }

  Future<bool> _persistNow() async {
    final prefs = await SharedPreferences.getInstance();
    // Per-DEVICE settings (reminders, device-calendar mirror, widget privacy,
    // active tab) live under their own small key on every persist. They never
    // ride the cloud user doc and are never deleted by the cloud-mode local
    // wipe below — before this, they only lived inside the v4 blob, which
    // cloud mode deletes, so they silently reset on every cloud boot.
    await _persistDevicePrefs(prefs);
    if (_cloudBacked) {
      // Never push an EMPTY family set to the cloud. An empty in-memory
      // `families` only occurs transiently — during sign-in (before cloudBoot
      // has loaded them) and during sign-out (after they're cleared) — and
      // writing `familyIds: []` then would wipe the account's membership and
      // strand it on the onboarding gate next login (issue #128). Deliberate
      // "leave/delete my last family" flows update the user doc on their own.
      // Nor may the local copies be deleted then: local storage may still
      // hold families the cloud has never seen.
      if (families.isEmpty) return true;
      final hasLocalState =
          prefs.containsKey(kStorageKeyV4) ||
          prefs.getKeys().any((k) => k.startsWith(kWsSectionPrefix));
      if (hasLocalState && !_applyingCloudSnapshot && _firebaseUid() != null) {
        // First cloud persist while local v4/section storage still exists:
        // this is the local→cloud promotion (fresh boot with a signed-in
        // user, or a mid-session sign-in). cloudPersist only writes the
        // ACTIVE family's docs, so pushing it and wiping local storage used
        // to lose every OTHER local family forever — their ids lingered in
        // the user doc's `familyIds` with no `families/{id}` doc behind
        // them. Promote ALL of them (after remapping this device's local
        // pseudo-uid to the Firebase uid so the pre-sign-in "you" doesn't
        // survive as a ghost member row).
        final meUid = _firebaseUid()!;
        _promoteLocalFamiliesForCloud(meUid);
        final promoted = await _persistAllFamilies(meUid);
        await _recordMembership(meUid);
        // A rejected write leaves the local copy as the only one.
        if (!promoted) return false;
      } else {
        if (!await _pushCloudState()) return false;
      }
      // Delete the local copies only NOW — after the cloud writes committed
      // (or were durably queued by the SDK's offline persistence). Deleting
      // first meant a failed/never-run cloud write destroyed the only copy.
      await prefs.remove(kStorageKeyV4);
      await prefs.remove(kStorageKey);
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(kWsSectionPrefix)) await prefs.remove(key);
      }
      return true;
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
    // Local/demo shared families: keep the registry's mirror of each
    // family current (issue: another local user who joined only ever saw
    // the workspace as it was at creation time). Best-effort: the registry
    // embeds whole workspaces and can hit the web localStorage quota — the
    // primary v4/section writes above are already safe.
    try {
      await _refreshLocalRegistry();
    } catch (e) {
      debugPrint('[persist] registry refresh failed: $e');
    }
    return ok;
  }

  /// Serializes the per-device settings (see [_persistDevicePrefs]).
  Map<String, dynamic> _devicePrefsPayload() => {
    'tab': tab,
    'widgetHideAmounts': _widgetHideAmounts,
    'notificationsEnabled': notificationsEnabled,
    'deviceCalendarSync': deviceCalendarSyncEnabled,
  };

  /// Writes the per-device settings under [kDevicePrefsKey] — a key that
  /// survives the cloud-mode wipe of v4/section storage.
  Future<void> _persistDevicePrefs(SharedPreferences prefs) async {
    try {
      await prefs.setString(
        kDevicePrefsKey,
        json.encode(_devicePrefsPayload()),
      );
    } catch (_) {
      /* best-effort: quota/serialization failures never block a persist */
    }
  }

  /// Restores the per-device settings on boot (local AND cloud paths). A v4
  /// blob restored afterwards carries the same values, so order is harmless.
  void _restoreDevicePrefs(SharedPreferences prefs) {
    final raw = prefs.getString(kDevicePrefsKey);
    if (raw == null) return;
    try {
      final m = Map<String, dynamic>.from(json.decode(raw) as Map);
      _widgetHideAmounts = m['widgetHideAmounts'] == true;
      notificationsEnabled = m['notificationsEnabled'] != false;
      deviceCalendarSyncEnabled = m['deviceCalendarSync'] != false;
      final t = (m['tab'] ?? '').toString();
      if (kValidTabs.contains(t)) tab = t;
    } catch (_) {
      /* corrupt prefs — keep the defaults */
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
      if (navTabs != null) 'navTabs': navTabs,
      // Per-user, never family-wide (#349) — which members/categories this
      // person has switched off on their own calendar.
      if (calFilter.isNotEmpty) 'calFilter': calFilter,
      if (calCatFilter.isNotEmpty) 'calCatFilter': calCatFilter,
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
  /// Pushes the active family + per-user view state to the shared
  /// collections; completes with whether it was all saved.
  Future<bool> _pushCloudState() async {
    if (_applyingCloudSnapshot) return true;
    final uid = _firebaseUid();
    if (uid == null) return true;
    return cloudPersist(uid);
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
    syncBlip();
    cb?.call();
  }

  /// Saves an edit right away ([_persist] — bursts coalesce while a save is
  /// in flight) and refreshes the Android home-screen widgets shortly after
  /// (issue #252).
  void _schedulePersist() {
    unawaited(_persist());
    _widgetPushTimer?.cancel();
    _widgetPushTimer = Timer(const Duration(seconds: 2), () {
      unawaited(pushPhoneWidgets());
    });
  }

  void flash(String msg, {ToastTone tone = ToastTone.success, String? body}) {
    if (!mounted) return;
    toastUndo = null;
    toastTone = tone;
    toastBody = body;
    // Re-notify even when the text repeats (the tone/body may differ).
    _toastNotifier.value = null;
    _toastNotifier.value = msg;
    _toastTimer?.cancel();
    _toastTimer = Timer(Duration(milliseconds: body == null ? 2100 : 4000), () {
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
    toastTone = ToastTone.success;
    toastBody = null;
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
            // Deterministic id: every family member's device generates the
            // SAME doc for this occurrence (cloud records are keyed by item
            // id), instead of each adding its own duplicate.
            final nextItem =
                anchor.item.copyWithId(
                    safeDocId('g_${seriesId}_${yr}_$mIdx'),
                    generated: true,
                  )
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
      if (s == 'calendar') flowView = 'calendar';
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

  bool _statusSheetOpen = false;

  /// Shows one error sheet at a time ([showStatusSheet]).
  void _showStatusSheetOnce({
    required StatusTone tone,
    required String title,
    required String body,
    required String primary,
    VoidCallback? onPrimary,
    String? secondary,
    VoidCallback? onSecondary,
  }) {
    if (!mounted || _statusSheetOpen) return;
    _statusSheetOpen = true;
    showStatusSheet(
      context,
      tone: tone,
      title: title,
      body: body,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
    ).whenComplete(() => _statusSheetOpen = false);
  }

  /// A save couldn't reach the server: the changes wait on this phone.
  void _showWaitingToSyncSheet() {
    final n = visiblePendingChanges.length;
    _showStatusSheetOnce(
      tone: StatusTone.amber,
      title: n <= 0
          ? 'Changes waiting to sync'
          : '$n ${n == 1 ? 'change' : 'changes'} waiting to sync',
      body:
          'You\u2019re offline. Your changes are saved on this phone and will '
          'sync as soon as you\u2019re back online.',
      primary: 'Got it',
      secondary: 'Try syncing now',
      onSecondary: () => unawaited(syncNow()),
    );
  }

  /// The floating chip over the main screens: the latest save's progress, or
  /// "Offline · saved on phone" (tap to sync now) while saves don't get
  /// through.
  Widget _buildStatusChip() => ListenableBuilder(
    listenable: Listenable.merge([syncStatus, netOffline]),
    builder: (context, _) {
      final status =
          syncStatus.value ??
          (netOffline.value ? SettingsSyncStatus.queued : null);
      return statusChipSwitcher(
        status == null
            ? null
            : StatusChip(
                key: ValueKey('status-chip-${status.name}'),
                kind: status.chipKind,
                text: statusChipText(
                  status.chipKind,
                  count: syncingChangeCount,
                ),
                dark: true,
                onTap: status == SettingsSyncStatus.queued
                    ? () => unawaited(syncNow())
                    : null,
              ),
      );
    },
  );

  // =============================================================== build
  @override
  Widget build(BuildContext context) {
    final authOpen = ready && user == null;
    // A retry from the can't-connect screen keeps it up ("Connecting…").
    final familyLoading =
        ready &&
        user != null &&
        families.isEmpty &&
        _resolvingFamilies &&
        !_cloudUnreachable;
    final cloudOffline =
        ready && user != null && families.isEmpty && _cloudUnreachable;
    final onboardingOpen =
        ready &&
        user != null &&
        families.isEmpty &&
        !_resolvingFamilies &&
        !_cloudUnreachable;
    // The nav bar + FAB only make sense once the budget/family gates are
    // all clear — same condition every gate below uses.
    final shellReady =
        ready &&
        !authOpen &&
        !familyLoading &&
        !onboardingOpen &&
        !cloudOffline;
    if (shellReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _kidShellChecks();
      });
    }
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
                ValueListenableBuilder<bool>(
                  valueListenable: netOffline,
                  builder: (context, _, _) => _buildHeader(),
                ),
                Expanded(
                  child: ready
                      ? Stack(
                          children: [
                            Positioned.fill(
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (notification.depth != 0 ||
                                      tab == 'finance') {
                                    return false;
                                  }
                                  final scrolled =
                                      notification.metrics.pixels > 0;
                                  if (_headerScrolled != scrolled) {
                                    setState(() => _headerScrolled = scrolled);
                                  }
                                  return false;
                                },
                                child: _buildBody(),
                              ),
                            ),
                            if (shellReady)
                              Positioned(
                                top: 4,
                                left: 16,
                                right: 16,
                                child: Center(child: _buildStatusChip()),
                              ),
                          ],
                        )
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
            // Signed in, but the families couldn't be loaded (no connection).
            if (cloudOffline && !familyLoading)
              Positioned.fill(
                child: CloudOfflineScreen(
                  onRetry: retryCloudConnect,
                  busy: _resolvingFamilies,
                ),
              ),
            // Onboarding gate: a signed-in user with confirmed-no family must
            // create or join one before reaching the budget.
            if (onboardingOpen)
              Positioned.fill(child: _OnboardingScreen(state: this)),
            // Kid accounts: welcome, first run and the full-screen errors.
            ValueListenableBuilder<KidGate?>(
              valueListenable: kidGate,
              builder: (context, gate, _) => gate == null
                  ? const SizedBox.shrink()
                  : Positioned.fill(
                      child: _KidGateScreen(
                        key: ValueKey(gate.kind),
                        state: this,
                        gate: gate,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The dark toast: a tone glyph, the message and an optional second line.
  Widget _buildToast(String msg) {
    final body = toastBody;
    // Transparent Material: settings pages re-host the toast outside any
    // Scaffold, where text would otherwise get the debug fallback style.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: const ValueKey('toast'),
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        decoration: BoxDecoration(
          color: B.ink,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x8c0f172a),
              blurRadius: 30,
              spreadRadius: -10,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: body == null
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: toastTone.color,
                shape: BoxShape.circle,
              ),
              child: Text(
                toastTone.glyph,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 11),
            // Flexible so long toasts ("Groceries paid with Albert Heijn")
            // ellipsize instead of overflowing the pill.
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: Color(0xfff8fafc),
                    ),
                  ),
                  if (body != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        body,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                          color: Color(0xffcbd5e1),
                        ),
                      ),
                    ),
                ],
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
      ),
    );
  }

  Widget _buildBody() {
    // A child user never renders finance, e.g. from a restored tab.
    if (isChildUser && !kChildAllowedTabs.contains(tab)) {
      return _renderTab('home');
    }
    if (tab != 'finance') return _renderTab(tab);
    return _buildFinance();
  }

  Widget _buildFinance() {
    final height = _financeHeaderHeight();
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _FinanceHeaderDelegate(
            height: height,
            builder: (visibleHeight, scrolled) =>
                _buildFinanceStickyHeader(visibleHeight, scrolled),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
            child: _buildFinanceScreenBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceScreenBody() {
    switch (screen) {
      case 'stats':
        return _buildStats();
      case 'calendar':
        return _buildFlow();
      case 'list':
        return _buildListTab();
      default:
        return _buildOverview();
    }
  }

  // ------------------------------------------------------------- header
  Widget _buildHeader() {
    if (tab == 'more') return _hubHero(scrolled: _headerScrolled);
    if (tab == 'finance') return const SizedBox.shrink();
    final meta = ready ? _tabMeta(tab) : ('Thrive', 'Loading…');
    final isCalendar = ready && tab == 'calendar';
    final calendarMonthIsPast =
        isCalendar &&
        _calMonthIsPast(calView == 'agenda' ? agendaDay : calAnchor);
    final isWeekly = ready && tab == 'weekly';
    final weekStart = isWeekly ? _weekStart() : null;
    final weekEnd = weekStart == null ? null : _addDays(weekStart, 6);
    final subtitle = isWeekly
        ? weekStart!.month == weekEnd!.month
              ? '${weekStart.day} – ${weekEnd.day} ${kMonthsEn[weekEnd.month - 1]}'
              : '${weekStart.day} ${kMonthsShort[weekStart.month - 1]} – '
                    '${weekEnd.day} ${kMonthsShort[weekEnd.month - 1]}'
        : meta.$2;
    return AppHeader(
      scrolled: _headerScrolled,
      title: meta.$1,
      subtitleKey: isCalendar
          ? const ValueKey('cal-month-title')
          : isWeekly
          ? const ValueKey('week-range')
          : null,
      subtitle: subtitle,
      subtitleOnPressed: isCalendar
          ? openCalPeriodPicker
          : isWeekly
          ? openWeekPicker
          : null,
      statusPill: calendarMonthIsPast ? 'PAST' : null,
      statusPillKey: calendarMonthIsPast
          ? const ValueKey('cal-past-pill')
          : null,
      statusChip: netOffline.value ? _offlineHeaderChip() : null,
      trailing: isCalendar ? _calHeaderActions() : null,
      actions: [
        if (tab == 'home' && !homeEditMode)
          AppHeaderAction(
            icon: 'bell',
            tooltip: 'Notifications',
            onPressed: () => flash('No new notifications'),
          ),
        if (tab == 'lists')
          AppHeaderAction(
            icon: 'search',
            tooltip: 'Search lists',
            onPressed: _openListsHeaderSearch,
          ),
      ],
      textAction: tab == 'home' && homeEditMode ? 'Done' : null,
      onTextActionPressed: tab == 'home' && homeEditMode
          ? () => setHomeEditMode(false)
          : null,
      toolbar: ready && !isCalendar ? _tabSubHeader(tab) : null,
    );
  }

  Widget _offlineHeaderChip() => GestureDetector(
    onTap: openPendingChangesScreen,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: B.amberSoft,
        border: Border.all(color: B.amberLine),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        'Not saved',
        style: TextStyle(
          color: B.amberText,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  void _openCalendarHeaderSearch() {
    showAppHeaderSearch(
      context,
      title: 'Search calendar',
      items: [
        for (final event in events)
          AppHeaderSearchItem(
            event.title,
            event.date,
            () => openEventView(event.id, event.date),
          ),
      ],
    );
  }

  void _openListsHeaderSearch() {
    showAppHeaderSearch(
      context,
      title: 'Search lists',
      items: [
        for (final list in taskLists)
          AppHeaderSearchItem(
            list.name,
            '${list.tasks.length} things to do',
            () => openTaskListDetail(list.id),
          ),
        for (final list in shoppingLists)
          AppHeaderSearchItem(
            list.name,
            '${list.items.length} items',
            () => openShopListDetail(list.id),
          ),
      ],
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

  double _financeHeaderHeight() => screen == 'overview' ? 344 : 110;

  Widget _buildFinanceStickyHeader(double height, bool scrolled) {
    final closed = isClosed();
    return Material(
      color: scrolled ? Colors.white : B.page,
      child: Stack(
        children: [
          if (!scrolled)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 22,
              child: DecoratedBox(
                key: ValueKey('finance-hero-gradient'),
                decoration: BoxDecoration(gradient: B.grad),
              ),
            ),
          Align(
            alignment: Alignment.topCenter,
            child: AppHeader(
              hero: !scrolled,
              scrolled: scrolled,
              title: 'Finance',
              titleKey: const ValueKey('finance-header-title'),
              subtitle: '${kMonthsEn[monthIdx]} $year',
              subtitleKey: const ValueKey('month-chip'),
              subtitleOnPressed: openMonthPicker,
              statusPill: closed ? 'CLOSED' : null,
              statusChip: netOffline.value ? _offlineHeaderChip() : null,
              actions: [
                AppHeaderAction(
                  icon: closed ? 'lock' : 'unlock',
                  tooltip: closed ? 'Reopen month' : 'Close month',
                  key: const ValueKey('lock-btn'),
                  filled: closed,
                  onPressed: () => closed ? reopenMonth() : openCloseConfirm(),
                ),
              ],
            ),
          ),
          if (screen == 'overview' && !scrolled)
            Positioned(
              top: 60,
              left: 18,
              right: 18,
              child: _buildFinanceHero(),
            ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 0,
            child: _buildFinanceTabs(),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceHero() {
    final c = compute(monthIdx);
    Widget tile(
      String label,
      String value, {
      VoidCallback? onTap,
      bool clickable = false,
    }) {
      final child = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4,
                      color: Color(0xe6ffffff),
                    ),
                  ),
                ),
                if (clickable)
                  ic('cright', size: 12, sw: 2.4, color: Colors.white),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
      if (onTap == null) return Expanded(child: child);
      return Expanded(
        child: GestureDetector(onTap: onTap, child: child),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SAFE TO SPEND',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
            color: Color(0xe6ffffff),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          eur(c.expectedBalance, cents: false),
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'after every planned bill this month',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xe6ffffff),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            tile(
              'Expected income',
              eur(c.expIncome, cents: false),
              onTap: openIncomeSheet,
              clickable: true,
            ),
            const SizedBox(width: 8),
            tile('Planned spend', eur(c.totalBudget, cents: false)),
            const SizedBox(width: 8),
            tile(
              'Still open',
              eur(c.stillToPay, cents: false),
              onTap: openAccountsSheet,
              clickable: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinanceTabs() {
    Widget tabBtn(String key, String label) {
      final active = screen == key;
      return Expanded(
        child: GestureDetector(
          key: ValueKey('tab-$key'),
          onTap: () => go(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? B.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : B.soft2,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('finance-tabs'),
      decoration: BoxDecoration(
        color: B.page,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .1),
            blurRadius: 24,
            spreadRadius: -18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          tabBtn('overview', 'Overview'),
          const SizedBox(width: 4),
          tabBtn('calendar', 'Calendar'),
          const SizedBox(width: 4),
          tabBtn('list', 'List'),
          const SizedBox(width: 4),
          tabBtn('stats', 'Stats'),
        ],
      ),
    );
  }
}

class _FinanceHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FinanceHeaderDelegate({required this.height, required this.builder});

  final double height;
  final Widget Function(double visibleHeight, bool scrolled) builder;

  @override
  double get minExtent => 110;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => builder(height - shrinkOffset, shrinkOffset > 20 || overlapsContent);

  @override
  bool shouldRebuild(covariant _FinanceHeaderDelegate oldDelegate) =>
      height != oldDelegate.height || builder != oldDelegate.builder;
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

  double get open => math.max(0, total - paid).toDouble();
  bool get settled => open <= 0.0001;
  bool get overCap => cap != null && total > cap!;
  double get capFraction =>
      cap == null || cap == 0 ? 0 : (total / cap!).clamp(0.0, 1.4);
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

// ============================================== save-conflict dialog widget
/// Shown when another member changed the same field(s) of an item while this
/// device was saving it: ours was saved; offer to switch to theirs.
class _SaveConflictDialog extends StatelessWidget {
  const _SaveConflictDialog({
    required this.who,
    required this.what,
    required this.onKeepMine,
    required this.onUseTheirs,
  });

  final String who;
  final String what;
  final VoidCallback onKeepMine;
  final VoidCallback onUseTheirs;

  Widget _button(String label, VoidCallback onTap, {required bool filled}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: filled ? B.primary : Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: filled ? null : Border.all(color: B.line),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: filled ? Colors.white : B.text,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey('save-conflict-dialog'),
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
                color: B.amberSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: ic('users', size: 23, sw: 2.2, color: B.amber),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              '$who also edited $what',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
                color: B.ink,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'You both changed the same thing at the same time. Your version '
              'was saved — keep it, or switch to theirs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: B.soft2,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 19),
            Row(
              children: [
                _button('Use theirs', onUseTheirs, filled: false),
                const SizedBox(width: 10),
                _button('Keep mine', onKeepMine, filled: true),
              ],
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

/// The toast's tones: a coloured glyph before the message.
enum ToastTone {
  /// Done (✓ green).
  success('✓', B.green),

  /// Removed / discarded (– slate).
  neutral('–', B.soft2),

  /// For your information (i slate).
  info('i', B.soft2),

  /// Not yet, will retry (↻ amber).
  retry('↻', B.amber),

  /// Something went wrong (! amber).
  alert('!', B.amber);

  const ToastTone(this.glyph, this.color);
  final String glyph;
  final Color color;
}
