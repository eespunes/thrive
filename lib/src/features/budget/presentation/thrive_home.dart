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
  void editMember(String id, String name, String email) =>
      _s.editMember(id, name, email);
  void switchFamily(String id) => _s.switchFamily(id);
  void createFamily(String name) => _s.createFamily(name);
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
}

class _ThriveHomeState extends State<ThriveHome> {
  bool ready = false;
  int year = 2026;
  int monthIdx = 5;
  String screen = 'overview'; // overview | stats — Finance tab's own sub-view
  String tab =
      'home'; // home | calendar | lists | finance | more | weekly | finsettings
  String statsMode = 'month'; // month | year

  // Active workspace (the currently-selected family's budget). Kept in sync
  // with `workspaces[familyId]` — mirrors the design holding both.
  List<Account> accounts = defaultAccounts();
  List<Category> cats = defaultCats();
  Map<int, Map<String, MonthData>> data = {};
  List<TaskList> taskLists = [];
  List<ShoppingList> shoppingLists = [];
  Map<String, DayPlan> weeklyPlan = {};
  String taskFilter = 'all'; // all | me
  String? openTaskList;
  String? openShopList;
  int weekOffset = 0; // 0 = current week, +/- N weeks navigated
  final FocusNode shopQuickAddFocus = FocusNode();
  Map<String, bool> collapsed = {};
  String? swipedId;
  String? toast;
  Timer? _toastTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _cloudSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _familySub;
  int _lastSyncedAtMillis = 0;
  bool _applyingCloudSnapshot = false;

  // True while a just-signed-in user's shared families are still being loaded
  // from the cloud. Suppresses the create/join onboarding gate so a returning
  // user goes straight to their existing family instead of flashing it (#120).
  bool _resolvingFamilies = false;

  // Auth + family state (ported from the design's v4 state).
  AppUser? user;
  List<Family> families = [];
  String familyId = 'fam_main';
  Map<String, Workspace> workspaces = {};

  @override
  void initState() {
    super.initState();
    thriveDebug._attach(this);
    _boot();
    pendingNotificationDeepLink.addListener(_handleNotificationDeepLink);
    // A tap that launched the app cold arrives before this listener attaches.
    _handleNotificationDeepLink();
  }

  @override
  void dispose() {
    thriveDebug._detach(this);
    pendingNotificationDeepLink.removeListener(_handleNotificationDeepLink);
    _cloudSub?.cancel();
    _familySub?.cancel();
    _toastTimer?.cancel();
    shopQuickAddFocus.dispose();
    super.dispose();
  }

  /// Consumes [pendingNotificationDeepLink] and jumps to the tapped task's
  /// list (#154). Deep-links only target tasks for now — event reminders
  /// follow once Calendar/#153 exists.
  void _handleNotificationDeepLink() {
    if (!ready) return; // taskLists isn't populated until boot finishes.
    final payload = pendingNotificationDeepLink.value;
    if (payload == null || !payload.startsWith('task:')) return;
    final taskId = payload.substring('task:'.length);
    for (final l in taskLists) {
      if (l.tasks.any((t) => t.id == taskId)) {
        pendingNotificationDeepLink.value = null;
        goTab('lists');
        openTaskListDetail(l.id);
        return;
      }
    }
    // Task no longer exists (deleted) — drop the stale deep link.
    pendingNotificationDeepLink.value = null;
  }

  // ---------------------------------------------------------------- boot
  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    _syncUserFromFirebaseAuth();

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
        setState(() => ready = true);
        _rescheduleTaskReminders();
        _handleNotificationDeepLink();
        return;
      }

      // Brand-new cloud user: promote any local state, else land on onboarding
      // with no families so they can create or join one.
      final rawV4 = prefs.getString(kStorageKeyV4);
      if (rawV4 != null) {
        try {
          _restoreV4(json.decode(rawV4) as Map<String, dynamic>);
          for (final f in families) {
            f.ownerUid ??= uid;
            if (!f.memberUids.contains(uid)) f.memberUids.add(uid);
            if (f.username.trim().isEmpty) f.username = familySlug(f.name);
          }
          if (!mounted) return;
          setState(() => ready = true);
          _rescheduleTaskReminders();
          _handleNotificationDeepLink();
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
      setState(() => ready = true);
      _rescheduleTaskReminders();
      _handleNotificationDeepLink();
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
        _restoreV4(json.decode(rawV4) as Map<String, dynamic>);
        if (!mounted) return;
        setState(() => ready = true);
        _rescheduleTaskReminders();
        _handleNotificationDeepLink();
        return;
      } catch (_) {
        /* fall through to migration / seed */
      }
    }

    // Migrate a pre-existing single-family v3 store into a fam_main workspace.
    final rawV3 = prefs.getString(kStorageKey);
    if (rawV3 != null) {
      try {
        _restore(json.decode(rawV3) as Map<String, dynamic>);
        _seedFamiliesAndWorkspace();
        if (!mounted) return;
        setState(() => ready = true);
        _rescheduleTaskReminders();
        _handleNotificationDeepLink();
        _persist();
        return;
      } catch (_) {
        /* fall through to fresh seed */
      }
    }

    await _seedFromAsset();
  }

  /// Re-derives every pending task reminder from `taskLists.due` on boot
  /// (#154) — reminders aren't persisted separately, so this is what makes
  /// them survive an app restart.
  void _rescheduleTaskReminders() {
    for (final l in taskLists) {
      for (final t in l.tasks) {
        if (t.done || (t.due ?? '').isEmpty) continue;
        NotificationService.instance.scheduleTaskReminder(t);
      }
    }
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

  DocumentReference<Map<String, dynamic>> _stateDocRef(String uid) {
    return FirebaseFirestore.instance.collection('user_workspaces').doc(uid);
  }

  /// Restores the v4 blob: families, per-family workspaces and the active one.
  void _restoreV4(Map<String, dynamic> saved) {
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

    familyId = (saved['familyId'] ?? 'fam_main').toString();
    if (!workspaces.containsKey(familyId)) {
      familyId = workspaces.keys.isNotEmpty
          ? workspaces.keys.first
          : 'fam_main';
    }
    final ws = workspaces[familyId] ?? Workspace.empty();
    workspaces[familyId] = ws;
    accounts = ws.accounts;
    cats = ws.cats;
    data = ws.data;
    taskLists = ws.taskLists;
    shoppingLists = ws.shoppingLists;
    weeklyPlan = ws.weeklyPlan;
  }

  /// Wraps the just-restored/seeded active workspace into `workspaces` and
  /// seeds a starter family for the signed-in user (mirrors the design's
  /// v3→v4 migration / fresh-seed path).
  void _seedFamiliesAndWorkspace() {
    familyId = 'fam_main';
    workspaces = {
      'fam_main': Workspace(
        accounts: accounts,
        cats: cats,
        data: data,
        taskLists: taskLists,
        shoppingLists: shoppingLists,
        weeklyPlan: weeklyPlan,
      ),
    };
    families = user != null ? [seedFamily('fam_main', user!)] : [];
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
  }

  /// Resolves `screen` (Finance tab's overview/stats sub-view) and `tab`
  /// (top-level nav) from a saved blob. `rawTab` is null for saves written
  /// before the 5-tab nav existed (or the v3 store, which never had a
  /// concept of tabs) — in that case a legacy `screen: 'settings'` becomes
  /// `finsettings` (More stays highlighted, matching #149), and any other
  /// legacy screen keeps the user on the Finance tab where they left off
  /// instead of dropping them onto the new Home placeholder.
  void _restoreNav(Object? rawScreen, Object? rawTab) {
    final legacyScreen = (rawScreen ?? 'overview').toString();
    if (legacyScreen == 'settings') {
      screen = 'overview';
      tab = 'finsettings';
      return;
    }
    screen = const {'overview', 'stats'}.contains(legacyScreen)
        ? legacyScreen
        : 'overview';
    if (rawTab == null) {
      tab = 'finance';
      return;
    }
    final t = rawTab.toString();
    tab = kValidTabs.contains(t) ? t : 'home';
  }

  Future<void> _seedFromAsset() async {
    // First launch with no stored state: seed the bundled sample budget so the
    // app isn't empty. Newly *created* families start blank (see issue #119).
    final ws = await buildSampleWorkspace();
    if (!mounted) return;
    setState(() {
      accounts = ws.accounts;
      cats = ws.cats;
      data = ws.data;
      taskLists = ws.taskLists;
      shoppingLists = ws.shoppingLists;
      weeklyPlan = ws.weeklyPlan;
      _seedFamiliesAndWorkspace();
      ready = true;
    });
    _persist();
  }

  /// Mirrors `syncWorkspaces()` — stores the active budget into the current
  /// family's workspace slot before serializing.
  void _syncWorkspaces() {
    workspaces[familyId] = Workspace(
      accounts: accounts,
      cats: cats,
      data: data,
      taskLists: taskLists,
      shoppingLists: shoppingLists,
      weeklyPlan: weeklyPlan,
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    _syncWorkspaces();
    if (_cloudBacked) {
      await prefs.remove(kStorageKeyV4);
      await prefs.remove(kStorageKey);
      // Never push an EMPTY family set to the cloud. An empty in-memory
      // `families` only occurs transiently — during sign-in (before cloudBoot
      // has loaded them) and during sign-out (after they're cleared) — and
      // writing `familyIds: []` then would wipe the account's membership and
      // strand it on the onboarding gate next login (issue #128). Deliberate
      // "leave/delete my last family" flows update the user doc on their own.
      if (families.isNotEmpty) await _pushCloudState();
      return;
    }
    await prefs.setString(kStorageKeyV4, json.encode(_buildStatePayload()));
  }

  Map<String, dynamic> _buildStatePayload() {
    return {
      'year': year,
      'monthIdx': monthIdx,
      'screen': screen,
      'tab': tab,
      'familyId': familyId,
      'families': families.map((f) => f.toJson()).toList(),
      'workspaces': {
        for (final e in workspaces.entries) e.key: e.value.toJson(),
      },
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
  void update(VoidCallback fn) => setState(fn);

  void mutate(VoidCallback fn, [VoidCallback? cb]) {
    setState(fn);
    _persist();
    cb?.call();
  }

  void flash(String msg) {
    setState(() => toast = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2100), () {
      if (mounted) setState(() => toast = null);
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
    setState(() => year = y);
    _persist();
  }

  void moveAccount(String key, int dir) {
    final i = accounts.indexWhere((a) => a.key == key);
    final j = i + dir;
    if (j < 0 || j >= accounts.length) return;
    setState(() {
      final t = accounts[i];
      accounts[i] = accounts[j];
      accounts[j] = t;
    });
    _persist();
  }

  void moveBlock(String key, int dir) {
    final i = cats.indexWhere((c) => c.key == key);
    final j = i + dir;
    if (j < 0 || j >= cats.length) return;
    setState(() {
      final t = cats[i];
      cats[i] = cats[j];
      cats[j] = t;
    });
    _persist();
  }

  // ---------------------------------------------------------------- nav
  void go(String s) {
    setState(() {
      screen = s;
      swipedId = null;
    });
    _persist();
  }

  void setMonth(int d) {
    setState(() {
      monthIdx = (monthIdx + d + 12) % 12;
      swipedId = null;
    });
    _persist();
  }

  void pickMonth(int i) {
    setState(() {
      monthIdx = i;
      swipedId = null;
    });
    _persist();
  }

  void toggleCollapse(String k) =>
      setState(() => collapsed[k] = !(collapsed[k] ?? false));

  // ------------------------------------------------------------ toggles
  void togglePaid(String catKey, String id) {
    if (isClosed()) return;
    mutate(() {
      final arr = data[year]![kMonthKeys[monthIdx]]!.blocks[catKey];
      final it = arr?.firstWhere((x) => x.id == id, orElse: () => arr.first);
      if (it != null && arr!.any((x) => x.id == id)) it.paid = !it.paid;
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
        final ul = c.hasUntil ? untilLabel(it.until) : null;
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
            if (toast != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 36,
                child: Center(child: _buildToast()),
              ),
            ?(shellReady ? _buildFab() : null),
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

  Widget _buildToast() {
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
          Text(
            toast ?? '',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (tab != 'finance') return _renderTab(tab);
    switch (screen) {
      case 'stats':
        return _buildStats();
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
          'stats': [
            'Statistics',
            statsMode == 'month'
                ? '${kMonthsEn[monthIdx]} $year'
                : 'Full year $year',
          ],
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
        ? (tab == 'finance' ? _buildSubHeader() : _tabSubHeader(tab))
        : null;

    return Container(
      color: B.page,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                key: const ValueKey('profile-avatar'),
                onTap: user != null ? openProfileSheet : null,
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
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: B.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (tab == 'finance') _buildSwitcher(),
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
          width: 34,
          height: 30,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .14),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: ic(
              icon,
              size: 17,
              sw: 2.1,
              color: active ? B.primary : const Color(0xff8995a6),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xffe8ecf2),
        borderRadius: BorderRadius.circular(13),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('overview', 'grid'),
          const SizedBox(width: 4),
          seg('stats', 'chart'),
        ],
      ),
    );
  }

  Widget _buildSubHeader() {
    Widget arrow(int d, String name) => GestureDetector(
      key: ValueKey('month-${d < 0 ? 'prev' : 'next'}'),
      onTap: () => setMonth(d),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: B.line),
        ),
        child: Center(child: ic(name, size: 17, sw: 2.4, color: B.soft2)),
      ),
    );

    final monthChip = GestureDetector(
      key: const ValueKey('month-chip'),
      onTap: openMonthPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: B.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ic('cal', size: 15, sw: 2.2, color: B.primary),
            const SizedBox(width: 7),
            Text(
              '${kMonthsEn[monthIdx]} $year',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: B.ink,
              ),
            ),
            const SizedBox(width: 7),
            ic('cdown', size: 14, sw: 2.4, color: B.muted),
          ],
        ),
      ),
    );

    final left = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        arrow(-1, 'cleft'),
        const SizedBox(width: 8),
        monthChip,
        const SizedBox(width: 8),
        arrow(1, 'cright'),
      ],
    );

    if (screen == 'overview') {
      final closed = isClosed();
      final lockBtn = GestureDetector(
        key: const ValueKey('lock-btn'),
        onTap: () => closed ? reopenMonth() : openCloseConfirm(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: closed ? B.ink : Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: closed ? B.ink : B.line),
          ),
          child: Center(
            child: ic(
              closed ? 'lock' : 'unlock',
              size: 16,
              sw: 2.2,
              color: closed ? Colors.white : B.soft2,
            ),
          ),
        ),
      );
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [left, lockBtn],
      );
    }

    // stats: month strip + month/year toggle
    Widget seg(String label, String val) {
      final active = statsMode == val;
      return GestureDetector(
        key: ValueKey('stats-$val'),
        onTap: () => setState(() => statsMode = val),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
      );
    }

    final toggle = Container(
      decoration: BoxDecoration(
        color: const Color(0xffe8ecf2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('Month', 'month'), seg('Year', 'year')],
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [left, toggle],
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
