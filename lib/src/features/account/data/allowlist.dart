part of 'package:family_money_management_app/main.dart';

/// Thrive is family-only (issue #465): `allowlist/{email}` lists the accounts
/// that may use the backend. Firestore rules are the real gate; this check
/// only turns an uninvited account away at sign-in with a clear message
/// instead of letting it hit permission errors later.
const String kAllowlistCollection = 'allowlist';

const String kNotInvitedMessage =
    'This account isn\u2019t invited to Thrive. Ask a parent to add your '
    'email, then sign in again.';

String verifyEmailMessage(String email) =>
    'We sent a link to $email. Verify your email, then sign in again.';

enum AllowlistStatus {
  allowed,
  notInvited,

  /// Email/password account whose address isn't verified yet. Only a
  /// verified email (or an entry pinning this uid) counts.
  unverified,

  /// The check couldn't run (offline, rules not deployed yet). Sign-in goes
  /// ahead and the rules decide.
  unknown,
}

/// Test seam: replaces the Auth + Firestore lookup in [checkAllowlist].
Future<AllowlistStatus> Function(User user)? allowlistCheckOverride;

Future<AllowlistStatus> checkAllowlist(User user) =>
    (allowlistCheckOverride ?? _checkAllowlistCloud)(user);

// Needs a live Firebase backend.
// coverage:ignore-start
Future<AllowlistStatus> _checkAllowlistCloud(User user) async {
  final email = (user.email ?? '').trim().toLowerCase();
  if (email.isEmpty) return AllowlistStatus.notInvited;
  var verified = user.emailVerified;
  try {
    // Pick up a verification done since this token was minted, so the rules
    // see `email_verified` too.
    await user.reload();
    final fresh = FirebaseAuth.instance.currentUser ?? user;
    verified = fresh.emailVerified;
    await fresh.getIdToken(true);
    final snap = await FirebaseFirestore.instance
        .collection(kAllowlistCollection)
        .doc(email)
        .get()
        .timeout(kCloudOpTimeout);
    if (snap.exists) return AllowlistStatus.allowed;
    return verified ? AllowlistStatus.notInvited : AllowlistStatus.unverified;
  } on FirebaseException catch (e) {
    // Rules only let an unverified email read an entry that pins its uid.
    // A verified email is always allowed to read its own entry, so a denial
    // there means the allowlist rules aren't live: let the rules decide.
    if (e.code == 'permission-denied' && !verified) {
      return AllowlistStatus.unverified;
    }
    debugPrint('[auth] allowlist check failed: ${e.code}');
    return AllowlistStatus.unknown;
  } catch (e) {
    debugPrint('[auth] allowlist check failed: $e');
    return AllowlistStatus.unknown;
  }
}
// coverage:ignore-end
