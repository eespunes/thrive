'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createPushHandlers } = require('../push_handlers');

// ---------------------------------------------------------------- fakes

function fakeDb(initial = {}) {
  const store = new Map(Object.entries(initial).map(([k, v]) => [k, structuredClone(v)]));
  const snap = (path) => ({
    id: path.split('/').pop(),
    exists: store.has(path),
    data: () => structuredClone(store.get(path)),
    ref: ref(path),
  });
  const set = (path, v, opts) => store.set(path, opts && opts.merge ? { ...(store.get(path) || {}), ...v } : structuredClone(v));
  function ref(path) {
    return {
      path,
      get: async () => snap(path),
      set: async (v, opts) => set(path, v, opts),
      update: async (v) => set(path, v, { merge: true }),
      delete: async () => store.delete(path),
      create: async (v) => {
        if (store.has(path)) throw Object.assign(new Error('already exists'), { code: 6 });
        set(path, v);
      },
    };
  }
  const children = (pred) => ({
    docs: [...store.keys()].filter(pred).sort().map(snap),
  });
  return {
    store,
    doc: (path) => ref(path),
    collection: (path) => ({
      get: async () => children((k) => k.startsWith(`${path}/`) && !k.slice(path.length + 1).includes('/')),
    }),
    collectionGroup: (id) => ({
      get: async () => children((k) => k.split('/').slice(-2, -1)[0] === id),
    }),
    runTransaction: async (fn) => {
      const writes = [];
      const tx = {
        get: async (r) => snap(r.path),
        set: (r, v, o) => writes.push(() => set(r.path, v, o)),
        update: (r, v) => writes.push(() => set(r.path, v, { merge: true })),
        delete: (r) => writes.push(() => store.delete(r.path)),
      };
      const out = await fn(tx);
      writes.forEach((w) => w());
      return out;
    },
  };
}

function fakeMessaging(staleTokens = []) {
  const sent = [];
  return {
    sent,
    send: async (msg) => {
      if (staleTokens.includes(msg.token)) {
        throw Object.assign(new Error('gone'), { code: 'messaging/registration-token-not-registered' });
      }
      sent.push(msg);
      return 'id';
    },
  };
}

const FID = 'f1';
const family = {
  name: 'Jansen',
  ownerUid: 'u-anna',
  adminUids: ['u-anna'],
  kidUids: { 'u-liv': 'k-liv' },
  memberUids: ['u-anna', 'u-bram', 'u-liv'],
  members: [
    { id: 'u-anna', uid: 'u-anna', name: 'Anna', role: 'owner', status: 'active' },
    { id: 'u-bram', uid: 'u-bram', name: 'Bram', role: 'member', status: 'active' },
    { id: 'k-liv', uid: 'u-liv', name: 'Liv', role: 'kid', status: 'active' },
  ],
};
const device = (uid, token, tz = 'Europe/Amsterdam', extra = {}) => ({
  [`families/${FID}/members/${uid}/devices/${token}`]: { platform: 'android', token, timezone: tz, enabled: true, updatedAt: 1, ...extra },
});
const NOON = Date.parse('2026-10-13T10:00:00Z'); // 12:00 Amsterdam, Tuesday
const NIGHT = Date.parse('2026-10-13T21:00:00Z'); // 23:00 Amsterdam

function setup({ now = NOON, extra = {}, stale = [] } = {}) {
  const db = fakeDb({
    [`families/${FID}`]: family,
    ...device('u-anna', 'tok-anna'),
    ...device('u-bram', 'tok-bram'),
    ...device('u-liv', 'tok-liv'),
    ...extra,
  });
  const messaging = fakeMessaging(stale);
  const enqueued = [];
  const clock = { t: now };
  const h = createPushHandlers({
    db,
    messaging,
    now: () => clock.t,
    enqueue: async (data, opts) => enqueued.push({ data, opts }),
    logger: { error() {} },
  });
  return { db, messaging, enqueued, clock, h };
}

const change = (before, after) => ({
  before: { exists: !!before, data: () => before },
  after: { exists: !!after, data: () => after },
});
const tokens = (m) => m.sent.map((x) => x.token).sort();

const ev = { id: 'ev1', title: 'Swimming', date: '2026-10-14', start: '14:30', end: '15:30', attendees: ['k-liv'], _by: 'u-anna' };
const calEvent = (id, before, after, authId = 'u-anna') => ({
  id,
  authType: 'app_user',
  authId,
  params: { fid: FID, month: '2026-10', eventId: 'ev1' },
  data: change(before, after),
});

// ---------------------------------------------------------------- tests

test('event added reaches attendee kid; actor never notified', async () => {
  const { h, messaging } = setup();
  const res = await h.onCalendarEvent(calEvent('evt-1', null, ev, 'u-bram'));
  assert.deepEqual(res.changes, ['added']);
  assert.deepEqual(tokens(messaging), ['tok-anna', 'tok-liv']);
  const msg = messaging.sent[0];
  assert.equal(msg.notification.title, 'Bram added Swimming · Liv');
  assert.equal(msg.data.link, 'event:ev1:2026-10-14');
  assert.equal(msg.android.notification.channelId, 'family_calendar');
});

test('no duplicates on retries (same trigger event id)', async () => {
  const { h, messaging, db } = setup();
  await h.onCalendarEvent(calEvent('evt-dup', null, ev, 'u-bram'));
  const first = messaging.sent.length;
  const again = await h.onCalendarEvent(calEvent('evt-dup', null, ev, 'u-bram'));
  assert.equal(again.duplicate, true);
  assert.equal(messaging.sent.length, first);
  assert.ok(db.store.get(`families/${FID}/pushLog/evt-dup`).expireAt instanceof Date);
});

test('stale token is deleted; other devices still get the push', async () => {
  const { h, messaging, db } = setup({
    extra: device('u-anna', 'tok-anna-old'),
    stale: ['tok-anna-old'],
  });
  await h.onCalendarEvent(calEvent('evt-2', null, ev, 'u-bram'));
  assert.ok(!db.store.has(`families/${FID}/members/u-anna/devices/tok-anna-old`));
  assert.ok(db.store.has(`families/${FID}/members/u-anna/devices/tok-anna`));
  assert.deepEqual(tokens(messaging), ['tok-anna', 'tok-liv']);
});

test('device channel switched off / device disabled are skipped', async () => {
  const { h, messaging } = setup({
    extra: {
      ...device('u-anna', 'tok-anna', 'Europe/Amsterdam', { channelState: { family_calendar: false } }),
      ...device('u-liv', 'tok-liv', 'Europe/Amsterdam', { enabled: false }),
    },
  });
  await h.onCalendarEvent(calEvent('evt-3', null, ev, 'u-bram'));
  assert.deepEqual(tokens(messaging), []);
});

test('quiet hours: held, then one digest after the window (reward first), per timezone', async () => {
  const { h, messaging, db, clock } = setup({
    now: NIGHT,
    extra: {
      ...device('u-bram', 'tok-bram', 'America/New_York'), // 17:00 in NY: not quiet
      [`families/${FID}/settings/kitchen`]: { starsMap: { 'k-liv': 0 } },
    },
  });
  await h.onCalendarEvent(calEvent('q1', null, ev, 'u-bram'));
  await h.onKitchen({
    id: 'q2', authType: 'app_user', authId: 'u-bram', params: { fid: FID },
    data: change({ starsMap: { 'k-liv': 5 } }, { starsMap: { 'k-liv': 0 } }),
  });
  assert.deepEqual(tokens(messaging), [], 'Anna and Liv are in quiet hours, Bram is the actor');
  const held = [...db.store.keys()].filter((k) => k.includes('/pushHeld/'));
  assert.deepEqual(held.map((k) => k.split('/')[1]).sort(), ['u-anna', 'u-anna', 'u-liv']);
  assert.ok(!held.some((k) => k.startsWith('users/u-liv/') && k.includes('reward')), 'Liv is not notified about her own reward claim');

  assert.deepEqual(await h.runQuietDigest(), { digests: 0 }, 'still quiet');
  clock.t = Date.parse('2026-10-14T05:15:00Z'); // 07:15 Amsterdam
  assert.deepEqual(await h.runQuietDigest(), { digests: 2 });
  const anna = messaging.sent.find((m) => m.token === 'tok-anna');
  assert.equal(anna.notification.title, '2 family updates overnight');
  assert.equal(anna.notification.body, '1 reward claim · 1 calendar change');
  assert.equal(anna.android.notification.channelId, 'family_digest');
  assert.equal(anna.data.link, 'digest');
  assert.equal([...db.store.keys()].filter((k) => k.includes('/pushHeld/')).length, 0);
  assert.deepEqual(await h.runQuietDigest(), { digests: 0 });
});

test('reward claimed: data-only push, claim record, approveReward', async () => {
  const { h, messaging, db } = setup();
  await h.onKitchen({
    id: 'k1', authType: 'app_user', authId: 'u-liv', params: { fid: FID },
    data: change({ starsMap: { 'k-liv': 5 } }, { starsMap: { 'k-liv': 0 } }),
  });
  assert.deepEqual(tokens(messaging), ['tok-anna', 'tok-bram']);
  const msg = messaging.sent[0];
  assert.equal(msg.notification, undefined);
  const args = JSON.parse(msg.data.approve);
  assert.equal(args.familyId, FID);
  const claim = db.store.get(`families/${FID}/rewardClaims/k-liv`);
  assert.equal(claim.claimId, args.claimId);

  await assert.rejects(h.approveReward({ auth: { uid: 'u-liv' }, data: args }), { code: 'permission-denied' });
  await assert.rejects(h.approveReward({ auth: null, data: args }), { code: 'unauthenticated' });
  assert.deepEqual(await h.approveReward({ auth: { uid: 'u-bram' }, data: args }), { ok: true });
  assert.equal(db.store.get(`families/${FID}/rewardClaims/k-liv`).approvedBy, 'u-bram');
  assert.deepEqual(await h.approveReward({ auth: { uid: 'u-anna' }, data: args }), { ok: true });
  assert.equal(db.store.get(`families/${FID}/rewardClaims/k-liv`).approvedBy, 'u-bram', 'idempotent');
});

test('chores: bucket + Cloud Task, grouped flush after 15 minutes', async () => {
  const { h, messaging, enqueued, clock, db } = setup({
    extra: { [`families/${FID}/settings/kitchen`]: { starsMap: { 'k-liv': 3 } } },
  });
  const chore = (id, title) => ({ id, title, kitchenOrigin: true, todo: true, date: '2026-10-13', recur: 'none', attendees: ['k-liv'], done: false });
  await h.onCalendarEvent({ ...calEvent('c1', chore('c1', 'Make bed'), { ...chore('c1', 'Make bed'), done: true }, 'u-liv'), params: { fid: FID, eventId: 'c1' } });
  clock.t += 60_000;
  await h.onCalendarEvent({ ...calEvent('c2', chore('c2', 'Dishes'), { ...chore('c2', 'Dishes'), done: true }, 'u-liv'), params: { fid: FID, eventId: 'c2' } });
  assert.equal(enqueued.length, 1);
  assert.equal(enqueued[0].opts.scheduleDelaySeconds, 900);
  assert.equal(messaging.sent.length, 0, 'debounced');

  assert.deepEqual(await h.flushBucket(enqueued[0].data), { flushed: false }, 'not due yet');
  clock.t = NOON + 15 * 60_000;
  assert.deepEqual(await h.flushBucket(enqueued[0].data), { flushed: true });
  assert.deepEqual(tokens(messaging), ['tok-anna', 'tok-bram']);
  assert.equal(messaging.sent[0].notification.title, 'Liv finished 2 chores');
  assert.equal(messaging.sent[0].data.group, 'chores');
  assert.ok(!db.store.has(`families/${FID}/pushQueue/chores`));
  assert.deepEqual(await h.flushBucket(enqueued[0].data), { flushed: false }, 'task retry no-ops');
});

test('lists: items added debounced 10 min; finished replaces', async () => {
  const listPath = `families/${FID}/notes/l1`;
  const { h, messaging, enqueued, clock, db } = setup({
    extra: {
      [listPath]: { id: 'l1', name: 'Groceries', type: 'shopping' },
      [`${listPath}/lines/a`]: { _kind: 'shop', name: 'Milk', checked: false },
    },
  });
  const line = (id, lineId, before, after, authId = 'u-bram') => ({
    id, authType: 'app_user', authId, params: { fid: FID, listId: 'l1', lineId }, data: change(before, after),
  });
  for (const [i, name] of ['Milk', 'eggs', 'bread', 'jam'].entries()) {
    await h.onListLine(line(`l-${i}`, String(i), null, { _kind: 'shop', name, checked: false }));
    clock.t += 30_000;
  }
  assert.equal(enqueued.length, 4);
  assert.deepEqual(await h.flushBucket(enqueued[0].data), { flushed: false });
  clock.t = enqueued[3].opts.scheduleDelaySeconds * 1000 + NOON + 3 * 30_000;
  assert.deepEqual(await h.flushBucket(enqueued[3].data), { flushed: true });
  assert.deepEqual(tokens(messaging), ['tok-anna'], 'kids get no lists; actor skipped');
  assert.equal(messaging.sent[0].notification.title, 'Bram added 4 items to Groceries');
  assert.equal(messaging.sent[0].notification.body, 'Milk, eggs, bread and 1 more');
  assert.equal(messaging.sent[0].android.notification.tag, 'list:l1');

  db.store.set(`${listPath}/lines/a`, { _kind: 'shop', name: 'Milk', checked: true });
  await h.onListLine(line('l-tick', 'a', { _kind: 'shop', name: 'Milk', checked: false }, { _kind: 'shop', name: 'Milk', checked: true }, 'u-anna'));
  clock.t += 10 * 60_000;
  await h.flushBucket(enqueued[enqueued.length - 1].data);
  const last = messaging.sent[messaging.sent.length - 1];
  assert.equal(last.token, 'tok-bram');
  assert.equal(last.notification.title, 'Groceries is done');
  assert.equal(last.notification.body, 'Anna ticked off the last item');
});

const finance = (extra = {}) => ({
  [`families/${FID}/finance/main/blocks/house`]: { key: 'house', title: 'Housing' },
  [`families/${FID}/finance/main/blocks/inc`]: { key: 'inc', title: 'Income', isIncome: true },
  [`families/${FID}/finance/main/accounts/j`]: { key: 'j', name: 'Joint' },
  [`families/${FID}/finance/main/months/2026-10`]: { open: 2000 },
  [`families/${FID}/finance/main/recurring/rent`]: {
    id: 'rent', _month: '2026-09', _block: 'house', recurring: true, payee: 'Rent', amount: 1250, day: 13, account: 'j', paid: false,
  },
  ...extra,
});

test('money: added, 3+ in 10 min bundle', async () => {
  const { h, messaging, clock } = setup({ extra: finance() });
  const add = (i, amount) => h.onMoneyEntry({
    id: `m-${i}`, authType: 'app_user', authId: 'u-anna',
    params: { fid: FID, month: '2026-10', itemId: `x${i}` },
    data: change(null, { id: `x${i}`, _block: 'house', payee: `P${i}`, amount, account: 'j', day: 13, paid: false, recurring: false }),
  }, 'entries');
  assert.deepEqual(await add(1, 100), { kind: 'added' });
  clock.t += 60_000;
  await add(2, 50.4);
  clock.t += 60_000;
  assert.deepEqual(await add(3, 62), { kind: 'bundle' });
  const last = messaging.sent.filter((m) => m.token === 'tok-bram').pop();
  assert.equal(last.notification.title, 'Anna added 3 expenses · €212,40');
  assert.equal(messaging.sent.find((m) => m.token === 'tok-bram').notification.title, 'Anna added an expense · €100,00');
  assert.equal(messaging.sent.find((m) => m.token === 'tok-bram').notification.body, 'Housing · P1 · Joint');
});

test('money-day: 09:00 local run, paid-in-app sends now and skips scheduled', async () => {
  const at9Ams = Date.parse('2026-10-13T07:05:00Z'); // 09:05 Amsterdam, 03:05 NY
  const { h, messaging, clock, db } = setup({
    now: at9Ams,
    extra: {
      ...finance({
        [`families/${FID}/finance/main/months/2026-10/entries/sal`]: {
          id: 'sal', _block: 'inc', payee: 'Salary', amount: 3000, day: 13, account: 'j', paid: false, recurring: false,
        },
      }),
      ...device('u-bram', 'tok-bram', 'America/New_York'),
      'users/u-bram': { notifPrefs: { quiet: { on: false } } },
    },
  });
  // Rent occurrence marked paid by Anna in the app before 09:00 Bram-time.
  const occ = { id: 'g_rent_2026_9', seriesId: 'rent', generated: true, _block: 'house', payee: 'Rent', amount: 1250, day: 13, account: 'j', paid: true };
  db.store.set(`families/${FID}/finance/main/months/2026-10/recurring/g_rent_2026_9`, occ);
  const r = await h.onMoneyEntry({
    id: 'paid-1', authType: 'app_user', authId: 'u-anna',
    params: { fid: FID, month: '2026-10', itemId: 'g_rent_2026_9' }, data: change(null, occ),
  }, 'occurrence');
  assert.deepEqual(r, { kind: 'paid' });
  const paidMsgs = messaging.sent.slice();
  assert.deepEqual(paidMsgs.map((m) => m.token), ['tok-bram'], 'actor skipped; kid Liv only sees her own money');
  assert.equal(paidMsgs[0].notification.title, 'Rent paid · €1.250,00');
  assert.equal(paidMsgs[0].notification.body, 'From Joint · €3.750,00 left');
  assert.equal(paidMsgs[0].data.group, 'money-day');
  assert.equal(paidMsgs[0].data.link, 'money:2026-10-13');

  messaging.sent.length = 0;
  await h.runMoneyDay();
  assert.deepEqual(messaging.sent.map((m) => `${m.token}:${m.notification.title}`), ['tok-anna:Salary received · €3.000,00'],
    'only Anna is at 09:00; rent already paid');
  messaging.sent.length = 0;
  await h.runMoneyDay();
  assert.equal(messaging.sent.length, 0, 'same hour rerun: no duplicate');

  clock.t = Date.parse('2026-10-13T13:05:00Z'); // 09:05 New York
  await h.runMoneyDay();
  assert.deepEqual(messaging.sent.map((m) => `${m.token}:${m.notification.title}`), ['tok-bram:Salary received · €3.000,00']);
});

test('family doc: joined, role changed (also to the person), removed', async () => {
  const { h, messaging } = setup();
  const after = {
    ...family,
    adminUids: ['u-anna', 'u-bram'],
    memberUids: [...family.memberUids, 'u-mia'],
    members: [...family.members, { id: 'u-mia', uid: 'u-mia', name: 'Mia', role: 'member', status: 'active' }],
  };
  await h.onFamily({ id: 'fam1', authType: 'app_user', authId: 'u-anna', params: { fid: FID }, data: change(family, after) });
  const titles = messaging.sent.map((m) => `${m.token}:${m.notification.title}`).sort();
  assert.deepEqual(titles, [
    'tok-bram:Bram is now an admin',
    'tok-bram:Mia joined the Jansen family',
    'tok-liv:Bram is now an admin',
    'tok-liv:Mia joined the Jansen family',
  ]);
  messaging.sent.length = 0;
  const removed = { ...family, members: family.members.filter((m) => m.id !== 'u-bram'), memberUids: ['u-anna', 'u-liv'] };
  await h.onFamily({ id: 'fam2', authType: 'app_user', authId: 'u-anna', params: { fid: FID }, data: change(family, removed) });
  assert.deepEqual(messaging.sent.map((m) => `${m.token}:${m.notification.title}`), ['tok-liv:Anna removed Bram']);
});
