'use strict';

// Firestore/Auth orchestration for the kid-login callables. Dependencies are
// injected so this can be exercised with fakes; pure rules live in kid_logic.js.

const { HttpsError } = require('firebase-functions/v2/https');
const L = require('./kid_logic');

function isAuthError(err, code) {
  return !!err && (err.code === code || err.errorInfo?.code === code);
}

function createHandlers({ db, auth, FieldValue, now = () => Date.now() }) {
  const familyRef = (fid) => db.collection('families').doc(fid);
  const userRef = (uid) => db.collection('users').doc(uid);
  const linkRef = (email) => db.collection('kid_links').doc(email);

  async function findAuthUserByEmail(email) {
    try {
      return await auth.getUserByEmail(email);
    } catch (err) {
      if (isAuthError(err, 'auth/user-not-found')) return null;
      throw err;
    }
  }

  async function ignoreMissingUser(promise) {
    try {
      return await promise;
    } catch (err) {
      if (!isAuthError(err, 'auth/user-not-found')) throw err;
      return null;
    }
  }

  async function loadFamily(fid) {
    const snap = await familyRef(fid).get();
    return L.assertFamily(snap.exists ? snap.data() : null);
  }

  /** Reads the family inside a transaction and checks the caller is an admin. */
  async function txAdminFamily(tx, fid, callerUid) {
    const snap = await tx.get(familyRef(fid));
    const family = L.assertFamily(snap.exists ? snap.data() : null);
    L.assertAdmin(family, callerUid);
    return family;
  }

  /** Common prelude: caller signed in, ids present, caller admin, member exists. */
  async function adminContext(request) {
    const callerUid = L.requireAuth(request.auth);
    const data = request.data || {};
    const familyId = L.requireString(data.familyId, 'familyId');
    const memberId = L.requireString(data.memberId, 'memberId');
    const family = await loadFamily(familyId);
    L.assertAdmin(family, callerUid);
    const { member } = L.findMember(family, memberId);
    return { callerUid, data, familyId, memberId, family, member, token: request.auth.token || {} };
  }

  async function assertEmailFree(family, familyId, memberId, email, { allowUid } = {}) {
    L.assertNoMemberConflict(family, email, memberId);
    const existing = await findAuthUserByEmail(email);
    if (existing && existing.uid !== allowUid) throw L.thriveConflict();
    const link = await linkRef(email).get();
    if (link.exists && L.linkConflicts(link.data(), familyId, memberId)) throw L.thriveConflict();
  }

  async function kidCreateEmailLogin(request) {
    const ctx = await adminContext(request);
    const { callerUid, familyId, memberId, member, family } = ctx;
    const email = L.validateEmail(ctx.data.email);
    const password = L.validatePassword(ctx.data.password);
    L.assertKidWithoutLogin(member);
    await assertEmailFree(family, familyId, memberId, email);

    let created;
    try {
      created = await auth.createUser({
        email,
        password,
        displayName: member.name || undefined,
        emailVerified: true,
      });
    } catch (err) {
      if (isAuthError(err, 'auth/email-already-exists')) throw L.thriveConflict();
      throw err;
    }
    const uid = created.uid;

    try {
      await auth.setCustomUserClaims(uid, { managedKid: true });
      await db.runTransaction(async (tx) => {
        const fam = await txAdminFamily(tx, familyId, callerUid);
        L.assertNoMemberConflict(fam, email, memberId);
        const by = L.adminDisplayName(fam, callerUid, ctx.token.name);
        const next = L.applyCreateEmailLogin(fam, memberId, { uid, email, by, at: now() });
        const row = next.members.find((m) => m.id === memberId);
        let oldLink = null;
        if (next.previousLinkEmail) {
          const s = await tx.get(linkRef(next.previousLinkEmail));
          if (s.exists && !L.linkConflicts(s.data(), familyId, memberId)) oldLink = s.ref;
        }
        tx.update(familyRef(familyId), {
          members: next.members,
          memberUids: next.memberUids,
          kidUids: next.kidUids,
        });
        if (oldLink) tx.delete(oldLink);
        tx.set(
          userRef(uid),
          {
            familyIds: [familyId],
            activeFamilyId: familyId,
            profile: { name: row.name || '', email, initials: row.initials || L.initialsOf(row.name) },
          },
          { merge: true },
        );
      });
    } catch (err) {
      try {
        await auth.deleteUser(uid);
      } catch (_) {
        // Best-effort rollback; surface the original error.
      }
      throw err;
    }
    return { uid };
  }

  async function kidLinkGoogle(request) {
    const ctx = await adminContext(request);
    const { callerUid, familyId, memberId, member, family } = ctx;
    const email = L.validateEmail(ctx.data.email);
    L.assertKidWithoutLogin(member);
    await assertEmailFree(family, familyId, memberId, email);

    await db.runTransaction(async (tx) => {
      const fam = await txAdminFamily(tx, familyId, callerUid);
      L.assertNoMemberConflict(fam, email, memberId);
      const by = L.adminDisplayName(fam, callerUid, ctx.token.name);
      const at = now();
      const next = L.applyLinkGoogle(fam, memberId, { email, by, at });
      const newLink = await tx.get(linkRef(email));
      if (newLink.exists && L.linkConflicts(newLink.data(), familyId, memberId)) {
        throw L.thriveConflict();
      }
      let oldLink = null;
      if (next.previousLinkEmail) {
        const s = await tx.get(linkRef(next.previousLinkEmail));
        if (s.exists && !L.linkConflicts(s.data(), familyId, memberId)) oldLink = s.ref;
      }
      tx.update(familyRef(familyId), { members: next.members });
      tx.set(linkRef(email), { familyId, memberId, linkedBy: by, linkedAt: at });
      if (oldLink) tx.delete(oldLink);
    });
    return {};
  }

  async function kidClaimLogin(request) {
    const uid = L.requireAuth(request.auth);
    const token = request.auth.token || {};
    if (!L.isGoogleClaimToken(token)) {
      throw new HttpsError(
        'failed-precondition',
        'Sign in with a verified Google account.',
        { reason: 'provider' },
      );
    }
    const email = L.normalizeEmail(token.email);

    return db.runTransaction(async (tx) => {
      const linkSnap = await tx.get(linkRef(email));
      if (!linkSnap.exists) throw new HttpsError('not-found', 'No pending link.');
      const { familyId, memberId } = linkSnap.data();
      const famSnap = await tx.get(familyRef(familyId));
      const family = L.assertFamily(famSnap.exists ? famSnap.data() : null);
      if ((family.memberUids || []).includes(uid)) {
        throw L.stateError('This account is already in the family.');
      }
      const next = L.applyClaim(family, memberId, { uid, email });
      tx.update(familyRef(familyId), {
        members: next.members,
        memberUids: next.memberUids,
        kidUids: next.kidUids,
      });
      tx.delete(linkRef(email));
      tx.set(
        userRef(uid),
        { familyIds: FieldValue.arrayUnion(familyId), activeFamilyId: familyId },
        { merge: true },
      );
      return { familyId, memberId };
    });
  }

  async function kidResetPassword(request) {
    const ctx = await adminContext(request);
    const { callerUid, familyId, memberId, member } = ctx;
    L.assertManagedEmail(member);
    const password = L.validatePassword(ctx.data.password);
    await auth.updateUser(member.uid, { password });
    await auth.revokeRefreshTokens(member.uid);
    await db.runTransaction(async (tx) => {
      const fam = await txAdminFamily(tx, familyId, callerUid);
      const next = L.applySignedOut(fam, memberId, now(), { requireManaged: true });
      tx.update(familyRef(familyId), { members: next.members });
    });
    return {};
  }

  async function kidChangeEmail(request) {
    const ctx = await adminContext(request);
    const { callerUid, familyId, memberId, member, family } = ctx;
    L.assertManagedEmail(member);
    const email = L.validateEmail(ctx.data.email);
    if (L.normalizeEmail(member.loginEmail) === email) return {};
    await assertEmailFree(family, familyId, memberId, email, { allowUid: member.uid });
    try {
      await auth.updateUser(member.uid, { email });
    } catch (err) {
      if (isAuthError(err, 'auth/email-already-exists')) throw L.thriveConflict();
      throw err;
    }
    await db.runTransaction(async (tx) => {
      const fam = await txAdminFamily(tx, familyId, callerUid);
      L.assertNoMemberConflict(fam, email, memberId);
      const next = L.applyChangeEmail(fam, memberId, email);
      tx.update(familyRef(familyId), { members: next.members });
      tx.set(userRef(next.uid), { profile: { email } }, { merge: true });
    });
    return {};
  }

  async function kidSignOutEverywhere(request) {
    const ctx = await adminContext(request);
    const { callerUid, familyId, memberId, member } = ctx;
    L.assertHasLogin(member);
    await auth.revokeRefreshTokens(member.uid);
    await db.runTransaction(async (tx) => {
      const fam = await txAdminFamily(tx, familyId, callerUid);
      const next = L.applySignedOut(fam, memberId, now());
      tx.update(familyRef(familyId), { members: next.members });
    });
    return {};
  }

  async function kidRemoveLogin(request) {
    const ctx = await adminContext(request);
    const { callerUid, familyId, memberId } = ctx;

    const result = await db.runTransaction(async (tx) => {
      const fam = await txAdminFamily(tx, familyId, callerUid);
      const next = L.applyRemoveLogin(fam, memberId);
      let link = null;
      let user = null;
      if (next.kind === 'pending' && next.loginEmail) {
        link = await tx.get(linkRef(next.loginEmail));
      }
      if (next.uid) user = await tx.get(userRef(next.uid));

      tx.update(familyRef(familyId), {
        members: next.members,
        memberUids: next.memberUids,
        kidUids: next.kidUids,
      });
      if (link && link.exists && !L.linkConflicts(link.data(), familyId, memberId)) {
        tx.delete(link.ref);
      }
      if (next.kind === 'managed' && user) {
        tx.delete(userRef(next.uid));
      } else if (next.kind === 'google' && user && user.exists) {
        const data = user.data() || {};
        const remaining = (data.familyIds || []).filter((f) => f !== familyId);
        const update = {
          familyIds: FieldValue.arrayRemove(familyId),
          removedLogin: { familyId, familyName: fam.name || '', at: now() },
        };
        if (data.activeFamilyId === familyId) {
          update.activeFamilyId = remaining.length ? remaining[0] : FieldValue.delete();
        }
        tx.update(userRef(next.uid), update);
      }
      return next;
    });

    if (result.uid) {
      await ignoreMissingUser(auth.revokeRefreshTokens(result.uid));
      if (result.kind === 'managed') await ignoreMissingUser(auth.deleteUser(result.uid));
    }
    return {};
  }

  async function kidLoginDetails(request) {
    const { member } = await adminContext(request);
    if (!member.uid) return { lastSignInMillis: null };
    const user = await ignoreMissingUser(auth.getUser(member.uid));
    return { lastSignInMillis: L.lastSignInMillis(user) };
  }

  async function loginKind(request) {
    const email = L.normalizeEmail((request.data || {}).email);
    if (!L.isValidEmail(email)) return { managed: false };
    const user = await findAuthUserByEmail(email);
    return { managed: L.isManagedKidUser(user) };
  }

  return {
    kidCreateEmailLogin,
    kidLinkGoogle,
    kidClaimLogin,
    kidResetPassword,
    kidChangeEmail,
    kidSignOutEverywhere,
    kidRemoveLogin,
    kidLoginDetails,
    loginKind,
  };
}

module.exports = { createHandlers };
