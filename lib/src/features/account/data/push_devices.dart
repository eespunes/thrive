part of 'package:family_money_management_app/main.dart';

/// Push notifications (epic #469): the user's notification choices, this
/// phone's permission/channel state, and its FCM device registration.
extension _ThrivePush on _ThriveHomeState {
  /// The user's notification choices, or the defaults until they change one.
  NotifPrefs get notifPrefs => _notifPrefs ?? _defaultNotifPrefs();

  NotifPrefs _defaultNotifPrefs() => NotifPrefs.defaults(
    kid: isChildUser,
    selfId: notifSelfMemberId,
    kidIds: notifKidMembers.map((m) => m.id).toList(),
  );

  /// Active members of the current family.
  List<FamilyMember> get notifMembers => [
    for (final m in curFamily()?.members ?? const <FamilyMember>[])
      if (m.status == 'active') m,
  ];

  List<FamilyMember> get notifKidMembers => [
    for (final m in notifMembers)
      if (m.role == 'kid') m,
  ];

  /// The current user's member id in the active family ("Me").
  String get notifSelfMemberId {
    final mine = _homeCurrentUserMemberIds();
    for (final m in notifMembers) {
      if (mine.contains(m.id)) return m.id;
    }
    return myId;
  }

  /// Edits the choices, saves them to the account and reschedules the local
  /// event-start notifications they drive.
  void editNotifPrefs(void Function(NotifPrefs p) edit) {
    final next = notifPrefs.copy();
    edit(next);
    update(() => _notifPrefs = next);
    _schedulePersist();
    unawaited(_rescheduleReminders());
  }

  /// Adopts choices read from the account; returns whether they changed.
  bool _adoptNotifPrefs(Object? raw) {
    if (raw is! Map) return false;
    final next = NotifPrefs.fromJson(raw, _defaultNotifPrefs());
    if (_notifPrefs != null &&
        json.encode(_notifPrefs!.toJson()) == json.encode(next.toJson())) {
      return false;
    }
    _notifPrefs = next;
    return true;
  }

  /// The plan [NotificationService] schedules local notifications from.
  ReminderPlan _reminderPlan() {
    final prefs = notifPrefs;
    final selfIds = _homeCurrentUserMemberIds();
    final kidIds = notifKidMembers.map((m) => m.id).toSet();
    final quiet = prefs.quiet.on && !prefs.quiet.letReminders
        ? prefs.quiet
        : null;
    return ReminderPlan(
      reminders: notificationsEnabled,
      startFor: (e) =>
          prefs.wantsEventStart(e, selfIds: selfIds, kidIds: kidIds),
      memberNames: (e) => joinNames([
        for (final id in e.attendees)
          if (_memberById(id) case final m?) m.name,
      ]),
      quiet: quiet,
      key: json.encode({
        'r': notificationsEnabled,
        'p': prefs.toJson()['cal'],
        'q': quiet?.toJson(),
        'self': selfIds.toList()..sort(),
        'kids': kidIds.toList()..sort(),
      }),
    );
  }

  // ---------------------------------------------------- phone state (#483)

  /// Re-reads permission, channels and exact alarms (page open + resume),
  /// then refreshes this phone's device doc so the server sees it.
  Future<void> refreshNotifDevice() async {
    final state = await NotificationService.readDeviceState();
    notifDevice.value = state;
    unawaited(_registerPushDevice());
  }

  /// "Turn on notifications" / "Ask again" (2a/2c → 2b).
  Future<void> askNotifPermission() async {
    final granted = await NotificationService.askPermission();
    await refreshNotifDevice();
    if (granted) {
      flash('Notifications are on');
      unawaited(_rescheduleReminders());
    }
  }

  // ------------------------------------------------- FCM wiring (#471/#474)

  /// Subscribes to token refreshes, foreground pushes and push taps once.
  void _bindPush() {
    final m = PushService.messaging;
    if (m == null || _pushSubs.isNotEmpty) return;
    _pushSubs.addAll([
      m.onTokenRefresh.listen((_) => unawaited(_registerPushDevice())),
      m.onForeground.listen(
        (n) => unawaited(NotificationService.showRemote(n)),
      ),
      m.onOpened.listen(_openPushLink),
    ]);
    unawaited(m.initialLink().then((l) => _openPushLink(l ?? '')));
  }

  void _openPushLink(String link) {
    if (link.isEmpty) return;
    pendingNotificationDeepLink.value = link;
  }

  /// Writes `families/{fid}/members/{uid}/devices/{token}` for every family
  /// the user is in (#471).
  // Needs a live Firestore + FCM backend.
  // coverage:ignore-start
  Future<void> _registerPushDevice() async {
    final m = PushService.messaging;
    final uid = _firebaseUid();
    if (m == null || uid == null || families.isEmpty) return;
    try {
      final token = await m.token();
      if (token == null || token.isEmpty) return;
      final old = _pushToken;
      _pushToken = token;
      String tzName;
      try {
        tzName = (await FlutterTimezone.getLocalTimezone()).identifier;
      } catch (_) {
        tzName = tz.local.name;
      }
      final doc = pushDeviceDoc(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
        timezone: tzName,
        state: notifDevice.value,
      );
      for (final f in families) {
        final devices = _familiesCol()
            .doc(f.id)
            .collection('members')
            .doc(uid)
            .collection('devices');
        if (old != null && old != token) {
          unawaited(devices.doc(old).delete().catchError((_) {}));
        }
        await devices
            .doc(token)
            .set({
              ...doc,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(kCloudOpTimeout);
      }
    } catch (e) {
      debugPrint('[push] device registration failed: $e');
    }
  }

  /// Removes this phone's device doc from [fids] (sign-out, leaving a
  /// family, deleting the account); [dropToken] also invalidates the FCM
  /// token so nothing reaches a signed-out phone.
  Future<void> _unregisterPushDevice(
    Iterable<String> fids, {
    bool dropToken = false,
  }) async {
    final m = PushService.messaging;
    final uid = _firebaseUid();
    final token = _pushToken;
    if (m == null || uid == null) return;
    try {
      if (token != null) {
        await Future.wait([
          for (final fid in fids)
            _familiesCol()
                .doc(fid)
                .collection('members')
                .doc(uid)
                .collection('devices')
                .doc(token)
                .delete()
                .timeout(kCloudOpTimeout)
                .catchError((_) {}),
        ]);
      }
      if (dropToken) {
        _pushToken = null;
        await m.deleteToken();
      }
    } catch (e) {
      debugPrint('[push] device removal failed: $e');
    }
  }

  // coverage:ignore-end
}

/// "Liv", "Liv and Leo", "Liv, Leo and Eva".
String joinNames(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}
