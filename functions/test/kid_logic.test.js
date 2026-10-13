'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const L = require('../kid_logic');

const rejectsWith = (fn, code, details) => {
  assert.throws(fn, (err) => {
    assert.equal(err.code, code);
    if (details) assert.deepEqual(err.details, details);
    return true;
  });
};

function family(overrides = {}) {
  return {
    name: 'Smiths',
    ownerUid: 'owner',
    adminUids: ['admin2'],
    memberUids: ['owner', 'admin2', 'adult'],
    kidUids: {},
    members: [
      { id: 'm1', name: 'Ana Smith', email: 'ana@x.com', initials: 'AS', color: 1, uid: 'owner', role: 'owner', status: 'active' },
      { id: 'm2', name: 'Bob', email: 'Bob@X.com', initials: 'B', color: 2, uid: 'adult', role: 'member', status: 'active' },
      { id: 'k1', name: 'Kiddo Smith', email: '', initials: 'KS', color: 3, role: 'kid', status: 'active' },
      { id: 'k2', name: 'Pending', email: '', initials: 'P', color: 4, role: 'kid', status: 'active', loginMethod: 'google', loginEmail: 'pend@gmail.com', managed: false, linkedBy: 'Ana', linkedAt: 5 },
    ],
    ...overrides,
  };
}

test('normalizeEmail lowercases and trims', () => {
  assert.equal(L.normalizeEmail('  Foo@Bar.COM '), 'foo@bar.com');
  assert.equal(L.normalizeEmail(null), '');
});

test('validateEmail', () => {
  assert.equal(L.validateEmail(' A@B.co '), 'a@b.co');
  for (const bad of ['', 'a', 'a@b', 'a b@c.d', '@b.c', 42, undefined]) {
    rejectsWith(() => L.validateEmail(bad), 'invalid-argument', { reason: 'email' });
  }
});

test('validatePassword requires >= 10 chars', () => {
  assert.equal(L.validatePassword('0123456789'), '0123456789');
  for (const bad of ['012345678', '', null, 1234567890]) {
    rejectsWith(() => L.validatePassword(bad), 'invalid-argument', { reason: 'password' });
  }
});

test('requireAuth / requireString', () => {
  rejectsWith(() => L.requireAuth(null), 'unauthenticated');
  assert.equal(L.requireAuth({ uid: 'u' }), 'u');
  rejectsWith(() => L.requireString('', 'familyId'), 'invalid-argument');
});

test('admin check', () => {
  const f = family();
  assert.equal(L.isAdmin(f, 'owner'), true);
  assert.equal(L.isAdmin(f, 'admin2'), true);
  assert.equal(L.isAdmin(f, 'adult'), false);
  assert.equal(L.isAdmin(f, undefined), false);
  assert.equal(L.isAdmin({ ...f, kidUids: { admin2: 'k1' } }, 'admin2'), false);
  assert.equal(L.isAdmin({ ...f, kidUids: { owner: 'k1' } }, 'owner'), false);
  rejectsWith(() => L.assertAdmin(f, 'adult'), 'permission-denied');
  rejectsWith(() => L.assertFamily(null), 'not-found');
  rejectsWith(() => L.findMember(f, 'nope'), 'not-found');
});

test('duplicate detection by member email and loginEmail', () => {
  const f = family();
  assert.equal(L.findEmailConflict(f, 'BOB@x.com', 'k1').id, 'm2');
  assert.equal(L.findEmailConflict(f, 'pend@gmail.com', 'k1').id, 'k2');
  assert.equal(L.findEmailConflict(f, 'pend@gmail.com', 'k2'), null);
  assert.equal(L.findEmailConflict(f, 'new@x.com', 'k1'), null);
  rejectsWith(() => L.assertNoMemberConflict(f, 'ana@x.com', 'k1'), 'already-exists', {
    reason: 'member',
    memberName: 'Ana Smith',
  });
  assert.deepEqual(L.thriveConflict().details, { reason: 'thrive' });
  assert.equal(L.thriveConflict().code, 'already-exists');
});

test('link conflicts only for a different member', () => {
  assert.equal(L.linkConflicts(null, 'f', 'k1'), false);
  assert.equal(L.linkConflicts({ familyId: 'f', memberId: 'k1' }, 'f', 'k1'), false);
  assert.equal(L.linkConflicts({ familyId: 'f', memberId: 'k2' }, 'f', 'k1'), true);
  assert.equal(L.linkConflicts({ familyId: 'g', memberId: 'k1' }, 'f', 'k1'), true);
});

test('adminDisplayName / initials', () => {
  assert.equal(L.adminDisplayName(family(), 'owner'), 'Ana');
  assert.equal(L.adminDisplayName(family(), 'admin2', 'Carl Jones'), 'Carl');
  assert.equal(L.adminDisplayName(family(), 'zzz'), 'Admin');
  assert.equal(L.initialsOf('kiddo van smith'), 'KS');
  assert.equal(L.initialsOf(''), '?');
});

test('applyCreateEmailLogin', () => {
  const f = family();
  const r = L.applyCreateEmailLogin(f, 'k1', { uid: 'kidUid', email: 'Kid@X.com', by: 'Ana', at: 10 });
  const row = r.members.find((m) => m.id === 'k1');
  assert.deepEqual(row, {
    id: 'k1', name: 'Kiddo Smith', email: '', initials: 'KS', color: 3, role: 'kid', status: 'active',
    uid: 'kidUid', loginMethod: 'email', loginEmail: 'kid@x.com', managed: true, linkedBy: 'Ana', linkedAt: 10,
  });
  assert.deepEqual(r.memberUids, ['owner', 'admin2', 'adult', 'kidUid']);
  assert.deepEqual(r.kidUids, { kidUid: 'k1' });
  assert.equal(r.previousLinkEmail, null);
  // input not mutated
  assert.equal(f.members[2].uid, undefined);
  assert.deepEqual(f.kidUids, {});

  const p = L.applyCreateEmailLogin(f, 'k2', { uid: 'u2', email: 'e@x.com', by: 'Ana', at: 1 });
  assert.equal(p.previousLinkEmail, 'pend@gmail.com');
  assert.equal(p.members[3].loginMethod, 'email');

  rejectsWith(() => L.applyCreateEmailLogin(f, 'm2', { uid: 'u', email: 'e@x.com' }), 'failed-precondition', { reason: 'state' });
  const withLogin = family();
  withLogin.members[2] = { ...withLogin.members[2], uid: 'x' };
  rejectsWith(() => L.applyCreateEmailLogin(withLogin, 'k1', { uid: 'u', email: 'e@x.com' }), 'failed-precondition', { reason: 'state' });
});

test('applyLinkGoogle (new and replacing pending link)', () => {
  const f = family();
  const r = L.applyLinkGoogle(f, 'k1', { email: ' Kid@Gmail.com', by: 'Ana', at: 7 });
  const row = r.members[2];
  assert.equal(row.loginMethod, 'google');
  assert.equal(row.loginEmail, 'kid@gmail.com');
  assert.equal(row.managed, false);
  assert.equal(row.uid, undefined);
  assert.equal(row.linkedAt, 7);
  assert.equal(r.previousLinkEmail, null);

  const replaced = L.applyLinkGoogle(f, 'k2', { email: 'other@gmail.com', by: 'Ana', at: 8 });
  assert.equal(replaced.previousLinkEmail, 'pend@gmail.com');
  assert.equal(L.applyLinkGoogle(f, 'k2', { email: 'PEND@gmail.com', by: 'A', at: 9 }).previousLinkEmail, null);
  rejectsWith(() => L.applyLinkGoogle(f, 'm1', { email: 'a@b.co' }), 'failed-precondition', { reason: 'state' });
});

test('applyClaim', () => {
  const f = family();
  const r = L.applyClaim(f, 'k2', { uid: 'g1', email: 'Pend@gmail.com' });
  assert.equal(r.members[3].uid, 'g1');
  assert.equal(r.members[3].loginMethod, 'google');
  assert.ok(r.memberUids.includes('g1'));
  assert.deepEqual(r.kidUids, { g1: 'k2' });
  rejectsWith(() => L.applyClaim(f, 'k2', { uid: 'g1', email: 'other@gmail.com' }), 'failed-precondition', { reason: 'state' });
  rejectsWith(() => L.applyClaim(f, 'k1', { uid: 'g1', email: 'pend@gmail.com' }), 'failed-precondition', { reason: 'state' });
});

test('isGoogleClaimToken', () => {
  assert.equal(L.isGoogleClaimToken({ email: 'a@b.co', email_verified: true, firebase: { sign_in_provider: 'google.com' } }), true);
  assert.equal(L.isGoogleClaimToken({ email: 'a@b.co', email_verified: false, firebase: { sign_in_provider: 'google.com' } }), false);
  assert.equal(L.isGoogleClaimToken({ email: 'a@b.co', email_verified: true, firebase: { sign_in_provider: 'password' } }), false);
  assert.equal(L.isGoogleClaimToken(undefined), false);
});

test('applyRemoveLogin for pending, google and managed', () => {
  const pending = L.applyRemoveLogin(family(), 'k2');
  assert.equal(pending.kind, 'pending');
  assert.equal(pending.loginEmail, 'pend@gmail.com');
  assert.equal(pending.uid, null);
  assert.deepEqual(pending.members[3], { id: 'k2', name: 'Pending', email: '', initials: 'P', color: 4, role: 'kid', status: 'active' });

  const claimed = L.applyClaim(family(), 'k2', { uid: 'g1', email: 'pend@gmail.com' });
  const g = L.applyRemoveLogin({ ...family(), ...claimed }, 'k2');
  assert.equal(g.kind, 'google');
  assert.equal(g.uid, 'g1');
  assert.ok(!g.memberUids.includes('g1'));
  assert.deepEqual(g.kidUids, {});
  assert.equal(g.members[3].uid, undefined);

  const created = L.applyCreateEmailLogin(family(), 'k1', { uid: 'e1', email: 'k@x.com', by: 'A', at: 1 });
  const signed = L.applySignedOut({ ...family(), ...created }, 'k1', 99);
  const m = L.applyRemoveLogin({ ...family(), ...created, members: signed.members }, 'k1');
  assert.equal(m.kind, 'managed');
  assert.deepEqual(m.members[2], { id: 'k1', name: 'Kiddo Smith', email: '', initials: 'KS', color: 3, role: 'kid', status: 'active' });

  rejectsWith(() => L.applyRemoveLogin(family(), 'k1'), 'failed-precondition', { reason: 'state' });
  rejectsWith(() => L.applyRemoveLogin(family(), 'm2'), 'failed-precondition', { reason: 'state' });
});

test('applySignedOut / applyChangeEmail require the right login', () => {
  const created = { ...family(), ...L.applyCreateEmailLogin(family(), 'k1', { uid: 'e1', email: 'k@x.com', by: 'A', at: 1 }) };
  assert.equal(L.applySignedOut(created, 'k1', 5, { requireManaged: true }).members[2].signedOutAt, 5);
  assert.equal(L.applyChangeEmail(created, 'k1', 'NEW@x.com').members[2].loginEmail, 'new@x.com');

  const claimed = { ...family(), ...L.applyClaim(family(), 'k2', { uid: 'g1', email: 'pend@gmail.com' }) };
  assert.equal(L.applySignedOut(claimed, 'k2', 6).members[3].signedOutAt, 6);
  rejectsWith(() => L.applySignedOut(claimed, 'k2', 6, { requireManaged: true }), 'failed-precondition', { reason: 'state' });
  rejectsWith(() => L.applyChangeEmail(claimed, 'k2', 'a@b.co'), 'failed-precondition', { reason: 'state' });
  rejectsWith(() => L.applySignedOut(family(), 'k2', 6), 'failed-precondition', { reason: 'state' });
});

test('lastSignInMillis / isManagedKidUser', () => {
  assert.equal(L.lastSignInMillis({ metadata: { lastSignInTime: 'Thu, 01 Jan 1970 00:00:01 GMT' } }), 1000);
  assert.equal(L.lastSignInMillis({ metadata: {} }), null);
  assert.equal(L.lastSignInMillis(null), null);
  assert.equal(L.isManagedKidUser({ customClaims: { managedKid: true } }), true);
  assert.equal(L.isManagedKidUser({ customClaims: {} }), false);
  assert.equal(L.isManagedKidUser(null), false);
});
