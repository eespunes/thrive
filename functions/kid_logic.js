'use strict';

// Pure validation / decision helpers for the kid-login callables. Nothing in
// here touches Firestore or Auth, so it can be unit tested directly.

const { HttpsError } = require('firebase-functions/v2/https');

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MIN_PASSWORD_LENGTH = 10;

function normalizeEmail(email) {
  return typeof email === 'string' ? email.trim().toLowerCase() : '';
}

function isValidEmail(email) {
  return EMAIL_RE.test(normalizeEmail(email));
}

/** Returns the normalized email or throws `invalid-argument` (reason `email`). */
function validateEmail(email) {
  const e = normalizeEmail(email);
  if (!EMAIL_RE.test(e)) {
    throw new HttpsError('invalid-argument', 'Invalid email address.', { reason: 'email' });
  }
  return e;
}

function isValidPassword(password) {
  return typeof password === 'string' && password.length >= MIN_PASSWORD_LENGTH;
}

/** Throws `invalid-argument` (reason `password`) for passwords under 10 chars. */
function validatePassword(password) {
  if (!isValidPassword(password)) {
    throw new HttpsError(
      'invalid-argument',
      `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`,
      { reason: 'password' },
    );
  }
  return password;
}

function requireString(value, field) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new HttpsError('invalid-argument', `Missing ${field}.`, { reason: 'input', field });
  }
  return value.trim();
}

function requireAuth(auth) {
  if (!auth || !auth.uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }
  return auth.uid;
}

function kidUidsOf(family) {
  const k = family && family.kidUids;
  return k && typeof k === 'object' && !Array.isArray(k) ? { ...k } : {};
}

function membersOf(family) {
  return Array.isArray(family && family.members) ? family.members : [];
}

function memberUidsOf(family) {
  return Array.isArray(family && family.memberUids) ? [...family.memberUids] : [];
}

function isAdmin(family, uid) {
  if (!family || !uid) return false;
  if (Object.prototype.hasOwnProperty.call(kidUidsOf(family), uid)) return false;
  if (family.ownerUid === uid) return true;
  return Array.isArray(family.adminUids) && family.adminUids.includes(uid);
}

function assertAdmin(family, uid) {
  if (!isAdmin(family, uid)) {
    throw new HttpsError('permission-denied', 'Only family admins can do this.');
  }
}

function assertFamily(family) {
  if (!family) throw new HttpsError('not-found', 'Family not found.');
  return family;
}

/** Returns `{index, member}` or throws `not-found`. */
function findMember(family, memberId) {
  const members = membersOf(family);
  const index = members.findIndex((m) => m && m.id === memberId);
  if (index < 0) throw new HttpsError('not-found', 'Member not found.');
  return { index, member: members[index] };
}

function firstName(name) {
  const n = typeof name === 'string' ? name.trim() : '';
  return n ? n.split(/\s+/)[0] : '';
}

/** Display first name of the acting admin (their member row, else the token name). */
function adminDisplayName(family, uid, tokenName) {
  const row = membersOf(family).find((m) => m && m.uid === uid);
  return firstName(row && row.name) || firstName(tokenName) || 'Admin';
}

function initialsOf(name) {
  const parts = (typeof name === 'string' ? name.trim() : '').split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  const first = parts[0][0];
  const second = parts.length > 1 ? parts[parts.length - 1][0] : '';
  return (first + second).toUpperCase();
}

/** Another member of the family already using [email] as `email` or `loginEmail`. */
function findEmailConflict(family, email, excludeMemberId) {
  const e = normalizeEmail(email);
  if (!e) return null;
  return (
    membersOf(family).find(
      (m) =>
        m &&
        m.id !== excludeMemberId &&
        (normalizeEmail(m.email) === e || normalizeEmail(m.loginEmail) === e),
    ) || null
  );
}

function assertNoMemberConflict(family, email, excludeMemberId) {
  const m = findEmailConflict(family, email, excludeMemberId);
  if (m) {
    throw new HttpsError('already-exists', 'Email already used by a family member.', {
      reason: 'member',
      memberName: m.name || '',
    });
  }
}

function thriveConflict() {
  return new HttpsError('already-exists', 'Email already has a Thrive account.', {
    reason: 'thrive',
  });
}

function stateError(message) {
  return new HttpsError('failed-precondition', message || 'Member is not in the right state.', {
    reason: 'state',
  });
}

function isKid(m) {
  return !!m && m.role === 'kid';
}

function isPendingGoogle(m) {
  return !!m && m.loginMethod === 'google' && !m.uid;
}

function isManagedEmail(m) {
  return !!m && !!m.uid && m.loginMethod === 'email' && m.managed === true;
}

/** Kid row without a login (may be a pending Google link). */
function assertKidWithoutLogin(m) {
  if (!isKid(m) || m.uid) throw stateError('Member must be a kid without a login.');
}

function assertManagedEmail(m) {
  if (!isKid(m) || !isManagedEmail(m)) throw stateError('Member has no managed email login.');
}

function assertHasLogin(m) {
  if (!isKid(m) || !m.uid || !m.loginMethod) throw stateError('Member has no login.');
}

function replaceMember(family, index, row) {
  const members = membersOf(family).slice();
  members[index] = row;
  return members;
}

const LOGIN_FIELDS = [
  'uid',
  'loginMethod',
  'loginEmail',
  'managed',
  'linkedBy',
  'linkedAt',
  'signedOutAt',
];

function stripLogin(m) {
  const row = { ...m };
  for (const f of LOGIN_FIELDS) delete row[f];
  return row;
}

/** Member transition for `kidCreateEmailLogin`. */
function applyCreateEmailLogin(family, memberId, { uid, email, by, at }) {
  const { index, member } = findMember(family, memberId);
  assertKidWithoutLogin(member);
  const previousLinkEmail = isPendingGoogle(member) ? normalizeEmail(member.loginEmail) : null;
  const row = {
    ...stripLogin(member),
    uid,
    loginMethod: 'email',
    loginEmail: normalizeEmail(email),
    managed: true,
    linkedBy: by,
    linkedAt: at,
    status: 'active',
  };
  const memberUids = memberUidsOf(family);
  if (!memberUids.includes(uid)) memberUids.push(uid);
  const kidUids = kidUidsOf(family);
  kidUids[uid] = memberId;
  return { members: replaceMember(family, index, row), memberUids, kidUids, previousLinkEmail };
}

/** Member transition for `kidLinkGoogle` (replaces any previous pending link). */
function applyLinkGoogle(family, memberId, { email, by, at }) {
  const { index, member } = findMember(family, memberId);
  assertKidWithoutLogin(member);
  const e = normalizeEmail(email);
  const old = isPendingGoogle(member) ? normalizeEmail(member.loginEmail) : null;
  const row = {
    ...stripLogin(member),
    loginMethod: 'google',
    loginEmail: e,
    managed: false,
    linkedBy: by,
    linkedAt: at,
  };
  return {
    members: replaceMember(family, index, row),
    previousLinkEmail: old && old !== e ? old : null,
  };
}

/** Member transition for `kidClaimLogin`. */
function applyClaim(family, memberId, { uid, email }) {
  const { index, member } = findMember(family, memberId);
  if (!isKid(member) || !isPendingGoogle(member) || normalizeEmail(member.loginEmail) !== normalizeEmail(email)) {
    throw stateError('This link is no longer pending.');
  }
  const row = { ...member, uid, status: 'active' };
  const memberUids = memberUidsOf(family);
  if (!memberUids.includes(uid)) memberUids.push(uid);
  const kidUids = kidUidsOf(family);
  kidUids[uid] = memberId;
  return { members: replaceMember(family, index, row), memberUids, kidUids };
}

/** Member transition for `kidChangeEmail`. */
function applyChangeEmail(family, memberId, email) {
  const { index, member } = findMember(family, memberId);
  assertManagedEmail(member);
  return {
    members: replaceMember(family, index, { ...member, loginEmail: normalizeEmail(email) }),
    uid: member.uid,
  };
}

/** Member transition for reset password / sign out everywhere. */
function applySignedOut(family, memberId, at, { requireManaged = false } = {}) {
  const { index, member } = findMember(family, memberId);
  if (requireManaged) assertManagedEmail(member);
  else assertHasLogin(member);
  return {
    members: replaceMember(family, index, { ...member, signedOutAt: at }),
    uid: member.uid,
  };
}

/**
 * Member transition for `kidRemoveLogin`. `kind` is `pending` (Google link not
 * yet claimed), `google` (claimed Google login) or `managed` (email login).
 */
function applyRemoveLogin(family, memberId) {
  const { index, member } = findMember(family, memberId);
  let kind;
  if (isKid(member) && isPendingGoogle(member)) kind = 'pending';
  else if (isKid(member) && isManagedEmail(member)) kind = 'managed';
  else if (isKid(member) && member.uid && member.loginMethod === 'google') kind = 'google';
  else throw stateError('Member has no removable login.');

  const uid = member.uid || null;
  const memberUids = memberUidsOf(family).filter((u) => u !== uid);
  const kidUids = kidUidsOf(family);
  if (uid) delete kidUids[uid];
  return {
    kind,
    uid,
    loginEmail: normalizeEmail(member.loginEmail),
    members: replaceMember(family, index, stripLogin(member)),
    memberUids,
    kidUids,
  };
}

/** A pending `kid_links` doc that belongs to a different member blocks the email. */
function linkConflicts(link, familyId, memberId) {
  return !!link && !(link.familyId === familyId && link.memberId === memberId);
}

function isGoogleClaimToken(token) {
  return (
    !!token &&
    !!token.firebase &&
    token.firebase.sign_in_provider === 'google.com' &&
    token.email_verified === true &&
    !!normalizeEmail(token.email)
  );
}

function lastSignInMillis(userRecord) {
  const t = userRecord && userRecord.metadata && userRecord.metadata.lastSignInTime;
  if (!t) return null;
  const ms = Date.parse(t);
  return Number.isNaN(ms) ? null : ms;
}

function isManagedKidUser(userRecord) {
  return !!(userRecord && userRecord.customClaims && userRecord.customClaims.managedKid === true);
}

module.exports = {
  EMAIL_RE,
  MIN_PASSWORD_LENGTH,
  normalizeEmail,
  isValidEmail,
  validateEmail,
  isValidPassword,
  validatePassword,
  requireString,
  requireAuth,
  isAdmin,
  assertAdmin,
  assertFamily,
  findMember,
  firstName,
  adminDisplayName,
  initialsOf,
  findEmailConflict,
  assertNoMemberConflict,
  thriveConflict,
  stateError,
  isKid,
  isPendingGoogle,
  isManagedEmail,
  assertKidWithoutLogin,
  assertManagedEmail,
  assertHasLogin,
  applyCreateEmailLogin,
  applyLinkGoogle,
  applyClaim,
  applyChangeEmail,
  applySignedOut,
  applyRemoveLogin,
  linkConflicts,
  isGoogleClaimToken,
  lastSignInMillis,
  isManagedKidUser,
};
