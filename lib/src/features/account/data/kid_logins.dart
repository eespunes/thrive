part of 'package:family_money_management_app/main.dart';

/// Kid accounts — admins and logins (`Kid Accounts.dc.html`).
///
/// Two ways a family gets a kid account:
/// - Flow A: someone joins normally, then an admin turns on Kid for them
///   ([setKidAccess]; a plain family-doc write the rules allow admins).
/// - Flow B: an admin gives a login-less kid profile a login — an
///   admin-managed email & password, or a linked Google account. That needs
///   the Admin SDK, so it goes through the callables in `functions/`
///   ([kidCall]). In local/demo mode the same calls are simulated on the
///   local family so the flows can be tried without a backend.
///
/// Admins are the owner plus `adminUids` (only the owner names them —
/// [setAdmin]); a kid is never an admin.

const String kKidFunctionsRegion = 'europe-west1';

/// A failed kid-login call: the callable's error [code] and `details.reason`.
class KidLoginError implements Exception {
  const KidLoginError(this.code, {this.reason, this.memberName});
  final String code;
  final String? reason;
  final String? memberName;

  bool get offline =>
      code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'internal';

  @override
  String toString() => 'KidLoginError($code, $reason)';
}

final RegExp _kKidEmailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Whether [email] looks like an address (`name@example.com`).
bool isValidLoginEmail(String email) => _kKidEmailRe.hasMatch(email.trim());

/// Password strength on the email-login setup screen.
enum PasswordStrength { weak, okay, good, strong }

/// Minimum length of an admin-made kid password (also enforced server-side).
const int kKidPasswordMinLength = 10;

PasswordStrength passwordStrength(String pw) {
  if (pw.length < kKidPasswordMinLength) return PasswordStrength.weak;
  var score = 0;
  if (RegExp(r'\d').hasMatch(pw)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) score++;
  if (RegExp(r'[A-Z]').hasMatch(pw) && RegExp(r'[a-z]').hasMatch(pw)) score++;
  if (pw.length >= 14) score++;
  if (score >= 3 && pw.length >= 16) return PasswordStrength.strong;
  if (score >= 2) return PasswordStrength.good;
  return PasswordStrength.okay;
}

String passwordStrengthLabel(PasswordStrength s) => switch (s) {
  PasswordStrength.weak => 'Weak',
  PasswordStrength.okay => 'Okay',
  PasswordStrength.good => 'Good',
  PasswordStrength.strong => 'Strong',
};

String passwordStrengthHint(PasswordStrength s) => switch (s) {
  PasswordStrength.weak => 'Use 10 or more characters, or tap Generate.',
  PasswordStrength.okay => 'Add another word or a number.',
  _ => 'Easy to type, hard to guess.',
};

const List<String> _kPasswordWords = [
  'otter',
  'mango',
  'river',
  'tiger',
  'maple',
  'cloud',
  'pepper',
  'comet',
  'panda',
  'lemon',
  'harbor',
  'falcon',
  'cocoa',
  'meadow',
  'pickle',
  'rocket',
  'walrus',
  'cactus',
  'banjo',
  'pebble',
  'zebra',
  'tulip',
  'kiwi',
  'nugget',
  'waffle',
  'puffin',
  'glacier',
  'acorn',
  'violet',
  'bison',
  'sunny',
  'marble',
];

/// An easy-to-type password like `otter-mango-river-27`.
String generateKidPassword([math.Random? rng]) {
  final r = rng ?? math.Random.secure();
  String w() => _kPasswordWords[r.nextInt(_kPasswordWords.length)];
  return '${w()}-${w()}-${w()}-${10 + r.nextInt(90)}';
}

/// First name of [name] ("Eva Janssen" → "Eva").
String firstNameOf(String name) {
  final t = name.trim();
  if (t.isEmpty) return '';
  return t.split(RegExp(r'\s+')).first;
}

extension _ThriveKidLogins on _ThriveHomeState {
  // ---------------------------------------------------------------- roles

  /// Whether the signed-in user may manage access and logins here.
  bool amAdmin() {
    final f = curFamily();
    if (f == null) return true;
    if (!_cloudBacked) {
      if (f.kidUids.containsKey(myId)) return false;
      return amOwner() || f.adminUids.contains(myId);
    }
    return f.isAdminUid(_firebaseUid());
  }

  /// The login id backing member [m] (uid, or the member id in demo mode).
  String? _loginIdOf(FamilyMember m) {
    if (m.hasLogin) return m.uid;
    return _cloudBacked ? null : m.id;
  }

  /// Whether [m] has admin rights in [f] (the owner always does).
  bool memberIsAdmin(Family f, FamilyMember m) {
    if (m.role == 'owner') return true;
    final id = _loginIdOf(m);
    if (id == null) return false;
    if (f.ownerUid != null && f.ownerUid == id) return true;
    return f.adminUids.contains(id) && !f.kidUids.containsKey(id);
  }

  /// Names of the family's admins ("Eva or Erik"), for "ask an admin" copy.
  String adminNames([Family? fam]) {
    final f = fam ?? curFamily();
    if (f == null) return 'an admin';
    final names = [
      for (final m in f.members)
        if (memberIsAdmin(f, m) && m.status == 'active') firstNameOf(m.name),
    ].where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return 'an admin';
    if (names.length == 1) return names.first;
    return '${names.sublist(0, names.length - 1).join(', ')} or ${names.last}';
  }

  /// First name of the signed-in user, as stamped on admin actions.
  String get _myFirstName {
    final n = firstNameOf(user?.name ?? '');
    return n.isEmpty ? 'An admin' : n;
  }

  FamilyMember? _kidRowById(String id) =>
      curFamily()?.members.where((m) => m.id == id).firstOrNull;

  // ----------------------------------------------------- Flow A: Kid on/off
  /// Turns kid access on/off for member [memberId] (applies right away, not
  /// on Save member). Returns a user-facing error, or null on success.
  Future<String?> setKidAccess(String memberId, bool kid) async {
    final f = curFamily();
    final m = _kidRowById(memberId);
    if (f == null || m == null) return 'Member not found';
    final first = firstNameOf(m.name);
    final failed =
        'Couldn’t change $first’s access. Check your connection and try again.';
    if (m.role == 'owner') return failed;
    final now = DateTime.now().millisecondsSinceEpoch;
    final change = {
      'to': kid ? 'kid' : 'full',
      'by': _myFirstName,
      'byId': myId,
      'at': now,
    };
    void apply(FamilyMember row, Family fam) {
      row
        ..role = kid ? 'kid' : 'member'
        ..kidSetBy = kid ? _myFirstName : null
        ..kidSetAt = kid ? now : null
        ..accessChange = row.hasLogin || !_cloudBacked ? change : null;
      final login = _loginIdOf(row);
      if (login != null) {
        if (kid) {
          fam.kidUids[login] = row.id;
          fam.adminUids.remove(login);
        } else {
          fam.kidUids.remove(login);
        }
      }
    }

    if (!_cloudBacked) {
      _withCurFamily((fam) => apply(m, fam));
      flash(
        kid ? '$first is now a kid account' : '$first is now a full member',
      );
      return null;
    }
    if (netOffline.value) return failed;
    final ref = _familyDocRef(f.id);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data();
        if (data == null) throw const KidLoginError('not-found');
        final rows = [
          for (final r in (data['members'] as List? ?? const []))
            if (r is Map) FamilyMember.fromJson(Map<String, dynamic>.from(r)),
        ];
        final row = rows.where((r) => r.id == memberId).firstOrNull;
        if (row == null || row.role == 'owner') {
          throw const KidLoginError('failed-precondition', reason: 'state');
        }
        final fam = Family.fromJson({...data, 'id': f.id});
        apply(row, fam);
        final upd = <Object, Object?>{
          'members': [for (final r in rows) r.toJson()],
          'updatedAtMillis': now,
        };
        final login = row.uid;
        if (login != null && login.isNotEmpty) {
          upd[FieldPath(['kidUids', login])] = kid
              ? row.id
              : FieldValue.delete();
          if (kid && (data['adminUids'] as List? ?? const []).contains(login)) {
            upd['adminUids'] = FieldValue.arrayRemove([login]);
          }
        }
        tx.update(ref, upd);
      }, timeout: kCloudOpTimeout);
    } catch (e) {
      debugPrint('[kids] setKidAccess failed: $e');
      return failed;
    }
    update(() => apply(m, f));
    flash(kid ? '$first is now a kid account' : '$first is now a full member');
    return null;
  }

  /// Gives or takes admin rights (owner only; never for a kid).
  Future<String?> setAdmin(String memberId, bool admin) async {
    final f = curFamily();
    final m = _kidRowById(memberId);
    if (f == null || m == null) return 'Member not found';
    final first = firstNameOf(m.name);
    final failed =
        'Couldn’t change $first’s admin rights. Check your connection and try '
        'again.';
    final login = _loginIdOf(m);
    if (login == null || m.role == 'kid' || !amOwner()) return failed;
    void apply(Family fam) {
      fam.adminUids.remove(login);
      if (admin) fam.adminUids.add(login);
    }

    if (!_cloudBacked) {
      _withCurFamily(apply);
    } else {
      if (netOffline.value) return failed;
      try {
        await _familyDocRef(f.id)
            .update({
              'adminUids': admin
                  ? FieldValue.arrayUnion([login])
                  : FieldValue.arrayRemove([login]),
              'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
            })
            .timeout(kCloudOpTimeout);
      } catch (e) {
        debugPrint('[kids] setAdmin failed: $e');
        return failed;
      }
      update(() => apply(f));
    }
    flash(admin ? '$first is now an admin' : '$first is no longer an admin');
    return null;
  }

  // ------------------------------------------------- Flow B: callables
  /// Calls kid-login callable [name] with [data] (`familyId` is added).
  /// Throws [KidLoginError].
  Future<Map<String, dynamic>> kidCall(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    final fid = curFamily()?.id ?? familyId;
    final payload = {'familyId': fid, ...data};
    if (!_cloudBacked) return _localKidCall(name, payload);
    if (netOffline.value) throw const KidLoginError('unavailable');
    try {
      final res = await FirebaseFunctions.instanceFor(
        region: kKidFunctionsRegion,
      ).httpsCallable(name).call<Object?>(payload).timeout(kCloudOpTimeout);
      final out = res.data;
      return out is Map ? Map<String, dynamic>.from(out) : const {};
    } on FirebaseFunctionsException catch (e) {
      final d = e.details;
      throw KidLoginError(
        e.code,
        reason: d is Map ? d['reason']?.toString() : null,
        memberName: d is Map ? d['memberName']?.toString() : null,
      );
    } on TimeoutException {
      throw const KidLoginError('deadline-exceeded');
    }
  }

  /// Demo-mode stand-in for the callables: the same checks and member-row
  /// changes, applied to the local family.
  Map<String, dynamic> _localKidCall(String name, Map<String, dynamic> d) {
    final f = curFamily();
    final m = _kidRowById((d['memberId'] ?? '').toString());
    final email = (d['email'] ?? '').toString().trim().toLowerCase();
    final pw = (d['password'] ?? '').toString();
    if (name == 'loginKind') return {'managed': false};
    if (name == 'kidClaimLogin') throw const KidLoginError('not-found');
    if (f == null || m == null) throw const KidLoginError('not-found');
    if (!amAdmin()) throw const KidLoginError('permission-denied');
    void checkEmail() {
      if (!isValidLoginEmail(email)) {
        throw const KidLoginError('invalid-argument', reason: 'email');
      }
      for (final o in f.members) {
        if (o.id == m.id) continue;
        if ((o.loginEmail ?? '') == email ||
            o.email.trim().toLowerCase() == email) {
          throw KidLoginError(
            'already-exists',
            reason: 'member',
            memberName: o.name,
          );
        }
      }
    }

    void checkPassword() {
      if (pw.length < kKidPasswordMinLength) {
        throw const KidLoginError('invalid-argument', reason: 'password');
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    switch (name) {
      case 'kidCreateEmailLogin':
        checkEmail();
        checkPassword();
        final uid = 'local-${m.id}';
        _withCurFamily((fam) {
          m
            ..uid = uid
            ..loginMethod = 'email'
            ..loginEmail = email
            ..managed = true
            ..linkedBy = _myFirstName
            ..linkedAt = now
            ..status = 'active';
          fam.kidUids[uid] = m.id;
        });
        return {'uid': uid};
      case 'kidLinkGoogle':
        checkEmail();
        _withCurFamily((_) {
          m
            ..loginMethod = 'google'
            ..loginEmail = email
            ..managed = false
            ..linkedBy = _myFirstName
            ..linkedAt = now;
        });
        return const {};
      case 'kidResetPassword':
        checkPassword();
        _withCurFamily((_) => m.signedOutAt = now);
        return const {};
      case 'kidChangeEmail':
        checkEmail();
        _withCurFamily((_) => m.loginEmail = email);
        return const {};
      case 'kidSignOutEverywhere':
        _withCurFamily((_) => m.signedOutAt = now);
        return const {};
      case 'kidRemoveLogin':
        _withCurFamily((fam) {
          if (m.uid != null) fam.kidUids.remove(m.uid);
          m
            ..uid = null
            ..loginMethod = null
            ..loginEmail = null
            ..managed = false
            ..linkedBy = null
            ..linkedAt = null
            ..signedOutAt = null;
        });
        return const {};
      case 'kidLoginDetails':
        return const {'lastSignInMillis': null};
    }
    throw const KidLoginError('not-found');
  }

  /// Whether [email] signs in to an admin-managed kid login (the
  /// wrong-password hint). False when unknown or offline.
  Future<bool> isManagedLogin(String email) async {
    if (!firebaseAppsAvailable) return false;
    try {
      final res =
          await FirebaseFunctions.instanceFor(region: kKidFunctionsRegion)
              .httpsCallable('loginKind')
              .call<Object?>({'email': email.trim().toLowerCase()})
              .timeout(const Duration(seconds: 6));
      final out = res.data;
      return out is Map && out['managed'] == true;
    } catch (e) {
      debugPrint('[kids] loginKind failed: $e');
      return false;
    }
  }

  /// After a Google sign-in that found no family: claims a pending link an
  /// admin made for this Google account. Returns the family id, or null.
  Future<String?> claimKidLink() async {
    if (!_cloudBacked) return null;
    try {
      final res =
          await FirebaseFunctions.instanceFor(region: kKidFunctionsRegion)
              .httpsCallable('kidClaimLogin')
              .call<Object?>(const <String, dynamic>{})
              .timeout(kCloudOpTimeout);
      final out = res.data;
      if (out is Map && out['familyId'] != null) {
        // A fresh ID token so the rules see the new membership right away.
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        return out['familyId'].toString();
      }
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'not-found') debugPrint('[kids] claim failed: ${e.code}');
    } catch (e) {
      debugPrint('[kids] claim failed: $e');
    }
    return null;
  }
}
