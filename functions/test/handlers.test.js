'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createHandlers } = require('../handlers');

// Minimal in-memory Firestore / Auth fakes.
const FV = {
  arrayUnion: (...v) => ({ __op: 'union', v }),
  arrayRemove: (...v) => ({ __op: 'remove', v }),
  delete: () => ({ __op: 'delete' }),
};

function applyFields(prev, fields, deepMerge = false) {
  const out = { ...(prev || {}) };
  for (const [k, val] of Object.entries(fields)) {
    if (val && val.__op === 'union') out[k] = [...new Set([...(out[k] || []), ...val.v])];
    else if (val && val.__op === 'remove') out[k] = (out[k] || []).filter((x) => !val.v.includes(x));
    else if (val && val.__op === 'delete') delete out[k];
    else if (val && typeof val === 'object' && !Array.isArray(val) && deepMerge && typeof out[k] === 'object') out[k] = { ...out[k], ...val };
    else out[k] = val;
  }
  return out;
}

function fakeDb(initial = {}) {
  const store = new Map(Object.entries(initial).map(([k, v]) => [k, structuredClone(v)]));
  const ref = (path) => ({
    path,
    get: async () => snap(path),
  });
  const snap = (path) => ({
    exists: store.has(path),
    data: () => structuredClone(store.get(path)),
    ref: ref(path),
  });
  const db = {
    store,
    failNextTx: false,
    collection: (c) => ({ doc: (d) => ref(`${c}/${d}`) }),
    runTransaction: async (fn) => {
      const writes = [];
      const tx = {
        get: async (r) => snap(r.path),
        update: (r, f) => writes.push(() => store.set(r.path, applyFields(store.get(r.path), f))),
        set: (r, f, opts) =>
          writes.push(() => store.set(r.path, opts && opts.merge ? applyFields(store.get(r.path), f, true) : applyFields(null, f))),
        delete: (r) => writes.push(() => store.delete(r.path)),
      };
      const result = await fn(tx);
      if (db.failNextTx) {
        db.failNextTx = false;
        throw new Error('tx failed');
      }
      writes.forEach((w) => w());
      return result;
    },
  };
  return db;
}

function fakeAuth(users = []) {
  const byUid = new Map(users.map((u) => [u.uid, u]));
  const notFound = () => Object.assign(new Error('nf'), { code: 'auth/user-not-found' });
  let n = 0;
  return {
    byUid,
    revoked: [],
    getUserByEmail: async (e) => {
      for (const u of byUid.values()) if (u.email === e) return u;
      throw notFound();
    },
    getUser: async (uid) => {
      if (!byUid.has(uid)) throw notFound();
      return byUid.get(uid);
    },
    createUser: async (p) => {
      const u = { uid: `new${++n}`, ...p, metadata: {} };
      byUid.set(u.uid, u);
      return u;
    },
    setCustomUserClaims: async (uid, c) => { byUid.get(uid).customClaims = c; },
    updateUser: async (uid, p) => { Object.assign(byUid.get(uid), p); },
    revokeRefreshTokens: async (uid) => {
      if (!byUid.has(uid)) throw notFound();
      byUid.get(uid).revoked = true;
    },
    deleteUser: async (uid) => { byUid.delete(uid); },
  };
}

function seed() {
  return {
    'families/f1': {
      name: 'Smiths',
      ownerUid: 'owner',
      adminUids: [],
      memberUids: ['owner', 'adult'],
      members: [
        { id: 'm1', name: 'Ana Smith', email: 'ana@x.com', uid: 'owner', role: 'owner', status: 'active', initials: 'AS', color: 1 },
        { id: 'm2', name: 'Bob', email: 'bob@x.com', uid: 'adult', role: 'member', status: 'active', initials: 'B', color: 2 },
        { id: 'k1', name: 'Kiddo', email: '', role: 'kid', status: 'active', initials: 'K', color: 3 },
      ],
    },
  };
}

const call = (uid, data, token = {}) => ({ auth: uid ? { uid, token } : null, data });
const expectCode = async (p, code, details) => {
  await assert.rejects(p, (err) => {
    assert.equal(err.code, code);
    if (details) assert.deepEqual(err.details, details);
    return true;
  });
};

function setup(users = [{ uid: 'owner', email: 'ana@x.com' }]) {
  const db = fakeDb(seed());
  const auth = fakeAuth(users);
  const h = createHandlers({ db, auth, FieldValue: FV, now: () => 1000 });
  return { db, auth, h };
}

test('kidCreateEmailLogin happy path, then manage it', async () => {
  const { db, auth, h } = setup();
  const { uid } = await h.kidCreateEmailLogin(call('owner', { familyId: 'f1', memberId: 'k1', email: ' Kid@X.com ', password: 'abcdefghij' }));
  const user = auth.byUid.get(uid);
  assert.equal(user.email, 'kid@x.com');
  assert.equal(user.emailVerified, true);
  assert.equal(user.displayName, 'Kiddo');
  assert.deepEqual(user.customClaims, { managedKid: true });
  const fam = db.store.get('families/f1');
  assert.deepEqual(fam.kidUids, { [uid]: 'k1' });
  assert.ok(fam.memberUids.includes(uid));
  assert.equal(fam.members[2].linkedBy, 'Ana');
  assert.equal(fam.members[2].managed, true);
  assert.deepEqual(db.store.get(`users/${uid}`), {
    familyIds: ['f1'], activeFamilyId: 'f1', profile: { name: 'Kiddo', email: 'kid@x.com', initials: 'K' },
  });
  assert.deepEqual(await h.loginKind(call(null, { email: 'KID@x.com' })), { managed: true });
  assert.deepEqual(await h.loginKind(call(null, { email: 'ana@x.com' })), { managed: false });

  // Kid itself is not an admin.
  await expectCode(h.kidSignOutEverywhere(call(uid, { familyId: 'f1', memberId: 'k1' })), 'permission-denied');

  await h.kidResetPassword(call('owner', { familyId: 'f1', memberId: 'k1', password: 'newpassword1' }));
  assert.equal(user.password, 'newpassword1');
  assert.equal(user.revoked, true);
  assert.equal(db.store.get('families/f1').members[2].signedOutAt, 1000);

  await expectCode(h.kidChangeEmail(call('owner', { familyId: 'f1', memberId: 'k1', email: 'bob@x.com' })), 'already-exists', { reason: 'member', memberName: 'Bob' });
  await h.kidChangeEmail(call('owner', { familyId: 'f1', memberId: 'k1', email: 'Kid2@x.com' }));
  assert.equal(user.email, 'kid2@x.com');
  assert.equal(db.store.get('families/f1').members[2].loginEmail, 'kid2@x.com');

  await h.kidRemoveLogin(call('owner', { familyId: 'f1', memberId: 'k1' }));
  assert.equal(auth.byUid.has(uid), false);
  assert.equal(db.store.has(`users/${uid}`), false);
  const after = db.store.get('families/f1');
  assert.deepEqual(after.kidUids, {});
  assert.ok(!after.memberUids.includes(uid));
  assert.deepEqual(after.members[2], seed()['families/f1'].members[2]);
});

test('kidCreateEmailLogin errors and rollback', async () => {
  const { db, auth, h } = setup([{ uid: 'owner', email: 'ana@x.com' }, { uid: 'z', email: 'taken@x.com' }]);
  const base = { familyId: 'f1', memberId: 'k1', password: 'abcdefghij' };
  await expectCode(h.kidCreateEmailLogin(call(null, { ...base, email: 'a@b.co' })), 'unauthenticated');
  await expectCode(h.kidCreateEmailLogin(call('adult', { ...base, email: 'a@b.co' })), 'permission-denied');
  await expectCode(h.kidCreateEmailLogin(call('owner', { ...base, familyId: 'nope', email: 'a@b.co' })), 'not-found');
  await expectCode(h.kidCreateEmailLogin(call('owner', { ...base, memberId: 'nope', email: 'a@b.co' })), 'not-found');
  await expectCode(h.kidCreateEmailLogin(call('owner', { ...base, email: 'bad' })), 'invalid-argument', { reason: 'email' });
  await expectCode(h.kidCreateEmailLogin(call('owner', { ...base, email: 'a@b.co', password: 'short' })), 'invalid-argument', { reason: 'password' });
  await expectCode(h.kidCreateEmailLogin(call('owner', { ...base, memberId: 'm2', email: 'a@b.co' })), 'failed-precondition', { reason: 'state' });
  await expectCode(h.kidCreateEmailLogin(call('owner', { ...base, email: 'ANA@x.com' })), 'already-exists', { reason: 'member', memberName: 'Ana Smith' });
  await expectCode(h.kidCreateEmailLogin(call('owner', { ...base, email: 'taken@x.com' })), 'already-exists', { reason: 'thrive' });

  const before = auth.byUid.size;
  db.failNextTx = true;
  await assert.rejects(h.kidCreateEmailLogin(call('owner', { ...base, email: 'roll@x.com' })), /tx failed/);
  assert.equal(auth.byUid.size, before);
  assert.equal(db.store.get('families/f1').kidUids, undefined);
});

test('Google link → claim → details → remove', async () => {
  const { db, auth, h } = setup();
  await h.kidLinkGoogle(call('owner', { familyId: 'f1', memberId: 'k1', email: 'Old@gmail.com' }));
  assert.ok(db.store.has('kid_links/old@gmail.com'));
  await h.kidLinkGoogle(call('owner', { familyId: 'f1', memberId: 'k1', email: 'kid@gmail.com' }));
  assert.equal(db.store.has('kid_links/old@gmail.com'), false);
  assert.deepEqual(db.store.get('kid_links/kid@gmail.com'), { familyId: 'f1', memberId: 'k1', linkedBy: 'Ana', linkedAt: 1000 });
  assert.equal(db.store.get('families/f1').members[2].loginMethod, 'google');

  const googleToken = { email: 'kid@gmail.com', email_verified: true, firebase: { sign_in_provider: 'google.com' } };
  await expectCode(h.kidClaimLogin(call('g1', {}, { ...googleToken, email: 'x@gmail.com' })), 'not-found');
  await expectCode(h.kidClaimLogin(call('g1', {}, { ...googleToken, firebase: { sign_in_provider: 'password' } })), 'failed-precondition');
  auth.byUid.set('g1', { uid: 'g1', email: 'kid@gmail.com', metadata: { lastSignInTime: new Date(5000).toUTCString() } });
  assert.deepEqual(await h.kidClaimLogin(call('g1', {}, googleToken)), { familyId: 'f1', memberId: 'k1' });
  assert.equal(db.store.has('kid_links/kid@gmail.com'), false);
  assert.deepEqual(db.store.get('families/f1').kidUids, { g1: 'k1' });
  assert.deepEqual(db.store.get('users/g1'), { familyIds: ['f1'], activeFamilyId: 'f1' });

  assert.deepEqual(await h.kidLoginDetails(call('owner', { familyId: 'f1', memberId: 'k1' })), { lastSignInMillis: 5000 });
  assert.deepEqual(await h.kidLoginDetails(call('owner', { familyId: 'f1', memberId: 'm2' })), { lastSignInMillis: null });

  await h.kidSignOutEverywhere(call('owner', { familyId: 'f1', memberId: 'k1' }));
  assert.equal(auth.byUid.get('g1').revoked, true);

  await h.kidRemoveLogin(call('owner', { familyId: 'f1', memberId: 'k1' }));
  assert.ok(auth.byUid.has('g1'));
  const u = db.store.get('users/g1');
  assert.deepEqual(u.familyIds, []);
  assert.equal(u.activeFamilyId, undefined);
  assert.deepEqual(u.removedLogin, { familyId: 'f1', familyName: 'Smiths', at: 1000 });
  assert.equal(db.store.get('families/f1').members[2].uid, undefined);
});

test('kidLinkGoogle rejects existing Thrive account and other pending link', async () => {
  const { db, h } = setup();
  await expectCode(h.kidLinkGoogle(call('owner', { familyId: 'f1', memberId: 'k1', email: 'ana@x.com' })), 'already-exists', { reason: 'member', memberName: 'Ana Smith' });
  db.store.set('families/f1', { ...db.store.get('families/f1'), members: [...db.store.get('families/f1').members.slice(0, 2), { ...db.store.get('families/f1').members[2], email: 'kid@school.com' }] });
  db.store.set('kid_links/other@gmail.com', { familyId: 'f2', memberId: 'kx' });
  await expectCode(h.kidLinkGoogle(call('owner', { familyId: 'f1', memberId: 'k1', email: 'other@gmail.com' })), 'already-exists', { reason: 'thrive' });
});

test('pending link removal deletes kid_links doc', async () => {
  const { db, h } = setup();
  await h.kidLinkGoogle(call('owner', { familyId: 'f1', memberId: 'k1', email: 'kid@gmail.com' }));
  await h.kidRemoveLogin(call('owner', { familyId: 'f1', memberId: 'k1' }));
  assert.equal(db.store.has('kid_links/kid@gmail.com'), false);
  assert.equal(db.store.get('families/f1').members[2].loginMethod, undefined);
  await expectCode(h.kidRemoveLogin(call('owner', { familyId: 'f1', memberId: 'k1' })), 'failed-precondition', { reason: 'state' });
});
