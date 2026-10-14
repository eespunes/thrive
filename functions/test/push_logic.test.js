'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const P = require('../push_logic');

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
    { id: 'k-leo', name: 'Leo', role: 'kid', status: 'active' },
    { id: 'u-inv', uid: 'u-inv', name: 'Invited', role: 'member', status: 'invited' },
  ],
};
const uids = (rs) => rs.map((r) => r.uid).sort();
const AMS = 'Europe/Amsterdam';
const NY = 'America/New_York';
const at = (iso) => Date.parse(iso);

// ------------------------------------------------------------------ prefs

test('defaults: adult vs kid, missing prefs, events all false = off', () => {
  const adult = P.resolvePrefs(undefined);
  assert.equal(adult.chores.scope, 'kids');
  assert.equal(adult.chores.events.stars, false);
  assert.equal(adult.lists.scope, 'shop');
  assert.equal(adult.cal.scope, 'mine');
  assert.equal(adult.money.scope, 'shared');
  assert.equal(adult.wall.on, false);
  assert.deepEqual([adult.quiet.from, adult.quiet.to, adult.quiet.letReminders], ['21:30', '07:00', true]);
  const kid = P.resolvePrefs({ chores: { scope: 'all' }, money: { scope: 'all' } }, { kid: true, memberId: 'k-liv' });
  assert.equal(kid.chores.scope, 'me');
  assert.equal(kid.cal.scope, 'me');
  assert.deepEqual([kid.money.scope, kid.money.pick], ['pick', ['k-liv']]);
  const off = P.resolvePrefs({ lists: { events: { added: false, ticked: false, finished: false } } });
  assert.equal(P.wants(off, 'lists', 'added'), false);
  assert.equal(P.wants(P.resolvePrefs({ cal: { on: false } }), 'cal', 'added'), false);
  assert.equal(P.wants(P.resolvePrefs({}), 'chores', 'stars'), false);
});

test('no self-notification, invited members and login-less kids never receive', () => {
  const rs = P.selectRecipients(family, { type: 'family', event: 'joined', excludeUids: ['u-anna'] });
  assert.deepEqual(uids(rs), ['u-bram', 'u-liv']);
});

test('kid restrictions: no lists; chores/cal only about themselves', () => {
  const lists = P.selectRecipients(family, { type: 'lists', event: 'added', ctx: { listType: 'shopping' } });
  assert.deepEqual(uids(lists), ['u-anna', 'u-bram']);
  const leoChore = P.selectRecipients(family, { type: 'chores', event: 'done', ctx: { subjects: ['k-leo'] } });
  assert.deepEqual(uids(leoChore), ['u-anna', 'u-bram']);
  const livChore = P.selectRecipients(family, { type: 'chores', event: 'done', ctx: { subjects: ['k-liv'] } });
  assert.deepEqual(uids(livChore), ['u-anna', 'u-bram', 'u-liv']);
  const cal = P.selectRecipients(family, { type: 'cal', event: 'added', ctx: { subjects: ['u-bram'] } });
  assert.deepEqual(uids(cal), ['u-bram']);
  const money = P.selectRecipients(family, { type: 'money', event: 'added', ctx: { subjects: ['k-liv'] } });
  assert.deepEqual(uids(money), ['u-anna', 'u-bram', 'u-liv']);
  const moneyOther = P.selectRecipients(family, { type: 'money', event: 'added', ctx: { subjects: ['u-anna'] } });
  assert.deepEqual(uids(moneyOther), ['u-anna', 'u-bram']);
});

test('scope filtering: kids / me / mine / shop / shared / pick', () => {
  const prefs = {
    'u-anna': { cal: { scope: 'me' }, lists: { scope: 'mine' }, chores: { scope: 'pick', pick: ['k-leo'] } },
    'u-bram': { cal: { scope: 'all' }, lists: { scope: 'all' }, money: { scope: 'kids' } },
  };
  const calKid = P.selectRecipients(family, { type: 'cal', event: 'added', ctx: { subjects: ['k-leo'] } }, prefs);
  assert.deepEqual(uids(calKid), ['u-bram']);
  const calMine = P.selectRecipients(family, { type: 'cal', event: 'added', ctx: { subjects: ['k-leo'] } }, {});
  assert.deepEqual(uids(calMine), ['u-anna', 'u-bram'], 'default "mine" includes kids');
  const task = P.selectRecipients(family, { type: 'lists', event: 'added', ctx: { listType: 'tasks', participants: ['u-anna'] } }, prefs);
  assert.deepEqual(uids(task), ['u-anna', 'u-bram']);
  const taskOther = P.selectRecipients(family, { type: 'lists', event: 'added', ctx: { listType: 'tasks', participants: ['x'] } }, prefs);
  assert.deepEqual(uids(taskOther), ['u-bram']);
  const shopDefault = P.selectRecipients(family, { type: 'lists', event: 'added', ctx: { listType: 'tasks' } }, {});
  assert.deepEqual(uids(shopDefault), [], 'default "shop" skips task lists');
  const chores = P.selectRecipients(family, { type: 'chores', event: 'done', ctx: { subjects: ['k-liv'] } }, prefs);
  assert.deepEqual(uids(chores), ['u-bram', 'u-liv']);
  const money = P.selectRecipients(family, { type: 'money', event: 'added', ctx: { subjects: ['u-anna'] } }, prefs);
  assert.deepEqual(uids(money), ['u-anna'], 'shared = all accounts, kids = kid subjects only');
});

test('role changed reaches the person themself even when they made no change', () => {
  const rs = P.selectRecipients(family, { type: 'family', event: 'role', excludeUids: ['u-anna', 'u-bram'], includeUids: ['u-bram'] });
  assert.deepEqual(uids(rs), ['u-bram', 'u-liv']);
});

test('resolveActor: uid, member id, kidUids', () => {
  assert.equal(P.resolveActor(family, 'u-bram').name, 'Bram');
  assert.equal(P.resolveActor(family, 'k-leo').name, 'Leo');
  assert.equal(P.resolveActor({ ...family, members: family.members.map((m) => (m.id === 'k-liv' ? { ...m, uid: undefined } : m)) }, 'u-liv').name, 'Liv');
  assert.equal(P.resolveActor(family, 'nobody'), null);
});

// ------------------------------------------------------------- §5 copy

const check = (s, want) => {
  for (const [k, v] of Object.entries(want)) assert.deepEqual(s[k], v, k);
};

test('§5 Chore done (single and grouped)', () => {
  check(P.choreDone({ kid: 'Liv', chore: 'Make bed', eventId: 'e1', stars: 4 }), {
    title: 'Liv finished Make bed', body: '★ +1 · 4 stars today', channel: 'family_chores',
    tag: 'chore:e1', link: 'chore:e1', group: 'chores', priority: 'normal',
  });
  const g = P.choreNotification([
    { kid: 'Liv', chore: 'Make bed', eventId: 'e1', stars: 1 },
    { kid: 'Leo', chore: 'Feed cat', eventId: 'e2', stars: 2 },
    { kid: 'Liv', chore: 'Dishes', eventId: 'e3', stars: 2 },
  ]);
  check(g, {
    title: 'Liv and Leo finished 3 chores',
    body: 'Liv · Make bed\nLeo · Feed cat\nLiv · Dishes',
    channel: 'family_chores', tag: 'chores', group: 'chores', link: 'chore:e3',
    digest: { kind: 'chore', count: 3 },
  });
});

test('§5 Reward claimed (data-only with Approve/Open actions)', () => {
  const s = P.rewardClaimed({ kid: 'Liv', memberId: 'k-liv', familyId: 'f1', cost: 5, left: 0, claimId: 'c9' });
  check(s, {
    title: 'Liv wants their reward', body: '5 stars · 0 left after', channel: 'family_chores',
    tag: 'reward:k-liv:c9', link: 'reward:k-liv', priority: 'high',
  });
  const msg = P.fcmMessage(s, 'tok');
  assert.equal(msg.notification, undefined);
  assert.equal(msg.android.priority, 'high');
  assert.deepEqual(msg.apns.payload.aps.alert, { title: s.title, body: s.body });
  assert.equal(msg.apns.headers['apns-collapse-id'], 'reward:k-liv:c9');
  assert.deepEqual(JSON.parse(msg.data.actions).map((a) => a.id), ['approve', 'open']);
  assert.deepEqual(JSON.parse(msg.data.approve), { familyId: 'f1', memberId: 'k-liv', claimId: 'c9' });
  assert.equal(msg.data.title, s.title);
  assert.ok(Object.values(msg.data).every((v) => typeof v === 'string'));
});

test('§5 Items added / List finished share the list tag', () => {
  const a = P.itemsAdded({ who: 'Bram', list: 'Groceries', listId: 'l1', listType: 'shopping', items: ['Milk', 'eggs', 'bread', 'jam'] });
  check(a, {
    title: 'Bram added 4 items to Groceries', body: 'Milk, eggs, bread and 1 more',
    channel: 'family_lists', tag: 'list:l1', link: 'list:l1', digest: { kind: 'shopping', count: 4 },
  });
  assert.equal(P.itemsAdded({ who: 'B', list: 'L', listId: 'x', items: ['Milk'] }).title, 'B added 1 item to L');
  assert.equal(P.itemsAdded({ who: 'B', list: 'L', listId: 'x', items: ['a', 'b', 'c'] }).body, 'a, b and c');
  const f = P.listFinished({ who: 'Anna', list: 'Groceries', listId: 'l1', listType: 'shopping' });
  check(f, { title: 'Groceries is done', body: 'Anna ticked off the last item', channel: 'family_lists', tag: 'list:l1' });
});

test('§5 Event added / moved / cancelled', () => {
  const ev = { id: 'ev1', title: 'Swimming', date: '2026-10-13', start: '14:30', end: '15:30' };
  check(P.eventAdded({ who: 'Anna', ev, members: 'Liv' }), {
    title: 'Anna added Swimming · Liv', body: 'Tue 13 Oct · 14:30–15:30',
    channel: 'family_calendar', tag: 'event:ev1', link: 'event:ev1:2026-10-13', priority: 'normal',
  });
  const moved = P.eventMoved({ who: 'Anna', before: ev, after: { ...ev, start: '16:00', end: '17:00' }, members: 'Liv' });
  check(moved, { title: 'Anna moved Swimming · Liv', body: 'Tue 13 Oct · now 16:00–17:00 (was 14:30–15:30)', tag: 'event:ev1' });
  const movedDay = P.eventMoved({ who: 'Anna', before: ev, after: { ...ev, date: '2026-10-14' } });
  assert.equal(movedDay.body, 'Wed 14 Oct · now 14:30–15:30 (was Tue 13 Oct 14:30–15:30)');
  assert.equal(movedDay.title, 'Anna moved Swimming');
  check(P.eventCancelled({ who: 'Bram', ev }), {
    title: 'Swimming on Tue 13 Oct is cancelled', body: 'By Bram', channel: 'family_calendar',
    tag: 'event:ev1', priority: 'high', link: 'event:ev1:2026-10-13',
  });
  assert.equal(P.eventAdded({ who: 'A', ev: { ...ev, allDay: true } }).body, 'Tue 13 Oct · All day');
});

test('§5 Money added / income / bundle / edited / removed', () => {
  check(P.moneyAdded({ who: 'Anna', entryId: 'x1', amount: 54.3, category: 'Groceries', payee: 'Albert Heijn', account: 'Joint', date: '2026-10-13' }), {
    title: 'Anna added an expense · €54,30', body: 'Groceries · Albert Heijn · Joint',
    channel: 'family_money', tag: 'entry:x1', link: 'money:2026-10-13',
  });
  assert.equal(P.moneyAdded({ who: 'Anna', entryId: 'x', income: true, amount: 3000, date: 'd' }).title, 'Anna added income · €3.000,00');
  check(P.moneyBundle({ who: 'Anna', actorKey: 'u-anna', amounts: [100, 50.4, 41, 21], payees: ['AH', 'Jumbo', 'Shell', 'Hema'], date: '2026-10-13' }), {
    title: 'Anna added 4 expenses · €212,40', body: 'AH, Jumbo, Shell and 1 more', tag: 'entries:u-anna', channel: 'family_money',
  });
  check(P.moneyEdited({ who: 'Bram', entryId: 'x1', payee: 'Eneco', account: 'Joint', oldAmount: 120, newAmount: 135.5, date: '2026-10-13' }), {
    title: 'Bram changed Eneco · Joint', body: '€120,00 → €135,50 · Tue 13 Oct', tag: 'entry:x1',
  });
  check(P.moneyRemoved({ who: 'Bram', entryId: 'x1', payee: 'Eneco', amount: 120, category: 'Energy', account: 'Joint', date: 'd' }), {
    title: 'Bram removed Eneco · €120,00', tag: 'entry:x1', channel: 'family_money',
  });
});

test('§5 Paid out / Received group "money-day"', () => {
  check(P.paidOut({ entryId: 'r1', payee: 'Rent', amount: 1250, account: 'Joint', balance: 830.15, date: '2026-10-01' }), {
    title: 'Rent paid · €1.250,00', body: 'From Joint · €830,15 left', group: 'money-day',
    channel: 'family_money', tag: 'entry:r1', link: 'money:2026-10-01',
  });
  check(P.received({ entryId: 's1', source: 'Salary', amount: 3200, account: 'Joint', balance: 4030.15, date: '2026-10-24' }), {
    title: 'Salary received · €3.200,00', body: 'Into Joint · €4.030,15 now', group: 'money-day', link: 'money:2026-10-24',
  });
});

test('§5 Echo wall, members joined/left/removed, role changed', () => {
  check(P.wallTicked({ kid: 'Liv', chore: 'Make bed', eventId: 'e1', stars: 3 }), {
    title: 'Liv ticked Make bed on the wall', body: '★ +1 · 3 stars today', channel: 'family_wall', group: 'wall',
  });
  check(P.memberJoined({ name: 'Mia', family: 'Jansen', role: 'member', who: 'Anna', memberId: 'm' }), {
    title: 'Mia joined the Jansen family', body: 'Added as member by Anna', channel: 'family_members', link: 'members',
  });
  assert.equal(P.memberLeft({ name: 'Mia', memberId: 'm' }).title, 'Mia left the family');
  assert.equal(P.memberLeft({ name: 'Mia', memberId: 'm', who: 'Anna' }).title, 'Anna removed Mia');
  check(P.roleChanged({ name: 'Bram', role: 'admin', who: 'Anna', memberId: 'u-bram' }), {
    title: 'Bram is now an admin', body: 'Changed by Anna', channel: 'family_members', priority: 'high', link: 'members',
  });
  assert.equal(P.roleChanged({ name: 'Liv', role: 'kid', who: 'A', memberId: 'k' }).title, 'Liv is now a kid');
});

test('§5 Quiet hours digest: reward claims first, " · " joined', () => {
  const held = [
    P.choreDone({ kid: 'Liv', chore: 'a', eventId: '1', stars: 1 }),
    P.choresGrouped([{ kid: 'Liv', chore: 'b', eventId: '2' }, { kid: 'Leo', chore: 'c', eventId: '3' }]),
    P.itemsAdded({ who: 'B', list: 'G', listId: 'l', listType: 'shopping', items: ['x', 'y'] }),
    P.rewardClaimed({ kid: 'Liv', memberId: 'k', cost: 5, claimId: 'c' }),
  ];
  const d = P.digest(held);
  check(d, {
    title: '6 family updates overnight', body: '1 reward claim · 3 chores done · 2 shopping changes',
    channel: 'family_digest', tag: 'digest', link: 'digest',
  });
  const more = P.digest([...held, P.eventCancelled({ who: 'A', ev: { id: 'e', title: 't', date: '2026-10-13' } })]);
  assert.equal(more.body, '1 reward claim · 3 chores done · 2 shopping changes · …');
  assert.equal(P.digest([P.memberLeft({ name: 'M', memberId: 'm' })]).title, '1 family update overnight');
  assert.equal(P.digest([]), null);
});

test('FCM message shape per contract (+ data.title/body)', () => {
  const s = P.eventAdded({ who: 'Anna', ev: { id: 'e', title: 'T', date: '2026-10-13', start: '10:00', end: '11:00' } });
  assert.deepEqual(P.fcmMessage(s, 'tok'), {
    token: 'tok',
    notification: { title: s.title, body: s.body },
    android: { collapseKey: 'event:e', priority: 'normal', notification: { channelId: 'family_calendar', tag: 'event:e' } },
    apns: { headers: { 'apns-collapse-id': 'event:e' } },
    data: { title: s.title, body: s.body, link: 'event:e:2026-10-13', channel: 'family_calendar', tag: 'event:e' },
  });
  assert.equal(P.fcmMessage(P.choreDone({ kid: 'L', chore: 'c', eventId: 'e', stars: 1 }), 't').data.group, 'chores');
  assert.equal(P.fcmMessage(P.eventCancelled({ who: 'A', ev: { id: 'e', title: 't', date: '2026-10-13' } }), 't').android.priority, 'high');
});

test('device filtering: enabled and channelState', () => {
  assert.equal(P.deviceAccepts({ token: 't', enabled: true }, 'family_money'), true);
  assert.equal(P.deviceAccepts({ token: 't', enabled: false }, 'family_money'), false);
  assert.equal(P.deviceAccepts({ token: 't', channelState: { family_money: false } }, 'family_money'), false);
  assert.equal(P.deviceAccepts({ token: 't', channelState: { family_money: false } }, 'family_lists'), true);
  assert.equal(P.userTimezone([{ timezone: AMS, updatedAt: 1 }, { timezone: NY, updatedAt: 5 }]), NY);
  assert.equal(P.userTimezone([]), P.DEFAULT_TZ);
});

// ------------------------------------------------------------ quiet hours

test('quiet hours across timezones and midnight', () => {
  const q = P.resolvePrefs({}).quiet; // 21:30–07:00 every day
  const tueEveningUtc = at('2026-10-13T20:00:00Z'); // 22:00 AMS, 16:00 NY
  assert.equal(P.inQuietHours(q, tueEveningUtc, AMS), true);
  assert.equal(P.inQuietHours(q, tueEveningUtc, NY), false);
  const wedEarlyUtc = at('2026-10-14T03:00:00Z'); // 05:00 AMS, 23:00 NY
  assert.equal(P.inQuietHours(q, wedEarlyUtc, AMS), true);
  assert.equal(P.inQuietHours(q, wedEarlyUtc, NY), true);
  assert.equal(P.inQuietHours(q, at('2026-10-14T05:00:00Z'), AMS), false); // 07:00 sharp ends
  assert.equal(P.inQuietHours({ ...q, on: false }, tueEveningUtc, AMS), false);
  const day = { on: true, from: '13:00', to: '15:00', days: q.days };
  assert.equal(P.inQuietHours(day, at('2026-10-13T12:00:00Z'), AMS), true);
  assert.equal(P.inQuietHours(day, at('2026-10-13T12:00:00Z'), NY), false);
});

test('quiet day chips apply to the day the window starts', () => {
  const tueOff = { on: true, from: '21:30', to: '07:00', days: [true, false, true, true, true, true, true] };
  assert.equal(P.inQuietHours(tueOff, at('2026-10-13T20:00:00Z'), AMS), false, 'Tue 22:00');
  assert.equal(P.inQuietHours(tueOff, at('2026-10-14T03:00:00Z'), AMS), false, 'Wed 05:00 belongs to Tue');
  assert.equal(P.inQuietHours(tueOff, at('2026-10-13T03:00:00Z'), AMS), true, 'Tue 05:00 belongs to Mon');
  assert.equal(P.inQuietHours(tueOff, at('2026-10-14T20:00:00Z'), AMS), true, 'Wed 22:00');
});

// --------------------------------------------------------------- classify

test('classify calendar changes; chores excluded', () => {
  const ev = { id: 'e', title: 'T', date: '2026-10-13', start: '10:00', end: '11:00', exceptions: [] };
  assert.deepEqual(P.classifyEvent(null, ev), [{ kind: 'added' }]);
  assert.deepEqual(P.classifyEvent(ev, null), [{ kind: 'cancelled', date: '2026-10-13' }]);
  assert.deepEqual(P.classifyEvent(ev, { ...ev, start: '10:30' }), [{ kind: 'moved' }]);
  assert.deepEqual(P.classifyEvent(ev, { ...ev, title: 'New' }), []);
  assert.deepEqual(P.classifyEvent(ev, { ...ev, exceptions: ['2026-10-20'] }), [{ kind: 'cancelled', date: '2026-10-20' }]);
  assert.deepEqual(P.classifyEvent(null, { ...ev, kitchenOrigin: true }), []);
});

test('chore completions: one-off done flag and recurring doneDates', () => {
  const c = { id: 'c', kitchenOrigin: true, todo: true, date: '2026-10-13', recur: 'none', done: false };
  assert.deepEqual(P.choreCompletions(c, { ...c, done: true }), { done: ['2026-10-13'], undone: [] });
  assert.deepEqual(P.choreCompletions({ ...c, done: true }, c), { done: [], undone: ['2026-10-13'] });
  const r = { ...c, recur: 'daily', doneDates: { '2026-10-12': true } };
  assert.deepEqual(P.choreCompletions(r, { ...r, doneDates: { '2026-10-12': true, '2026-10-13': true } }).done, ['2026-10-13']);
  assert.deepEqual(P.choreCompletions({ ...c, kitchenOrigin: false }, { ...c, kitchenOrigin: false, done: true }).done, []);
});

test('classify lines, reward claims, money entries, family', () => {
  assert.deepEqual(P.classifyLine(null, { _kind: 'shop', name: 'Milk', checked: false }), { added: 'Milk' });
  assert.deepEqual(P.classifyLine({ _kind: 'task', title: 'x', done: false }, { _kind: 'task', title: 'x', done: true }), { ticked: true });
  assert.deepEqual(P.rewardClaims({ starsMap: { a: 5, b: 3 } }, { starsMap: { a: 0, b: 0 } }), [{ memberId: 'a', cost: 5 }]);
  assert.deepEqual(P.rewardClaims({ starsMap: { a: 4 } }, { starsMap: { a: 3 } }), []);
  const e = { id: 'x', amount: 10, paid: false, account: 'j', day: 3 };
  assert.deepEqual(P.classifyEntry(null, e), { kind: 'added' });
  assert.deepEqual(P.classifyEntry(e, null), { kind: 'removed' });
  assert.deepEqual(P.classifyEntry(e, { ...e, amount: 12 }), { kind: 'edited' });
  assert.deepEqual(P.classifyEntry(e, { ...e, paid: true }), { kind: 'paid' });
  assert.deepEqual(P.classifyEntry(null, { ...e, paid: true }, { stored: true }), { kind: 'paid' });
  assert.equal(P.classifyEntry(null, e, { stored: true }), null);
  assert.equal(P.classifyEntry(e, { ...e, _order: 2 }), null);

  const after = {
    ...family,
    adminUids: ['u-anna', 'u-bram'],
    members: [...family.members.filter((m) => m.id !== 'k-leo'), { id: 'u-mia', uid: 'u-mia', name: 'Mia', role: 'member', status: 'active' }],
  };
  const kinds = P.classifyFamily(family, after).map((c) => `${c.kind}:${c.member.id}${c.role ? `:${c.role}` : ''}`).sort();
  assert.deepEqual(kinds, ['joined:u-mia:member', 'left:k-leo', 'role:u-bram:admin']);
});

// ---------------------------------------------------------------- buckets

test('buckets: chores fixed 15-min window, lists slide 10 min', () => {
  const t0 = 1_000_000;
  let r = P.addToBucket(null, { a: 1 }, { now: t0, kind: 'chores' });
  assert.equal(r.enqueue, true);
  assert.equal(r.dueAt, t0 + P.CHORE_WINDOW_MS);
  r = P.addToBucket(r.bucket, { a: 2 }, { now: t0 + 60_000, kind: 'chores' });
  assert.equal(r.enqueue, false);
  assert.equal(r.bucket.dueAt, t0 + P.CHORE_WINDOW_MS);
  assert.equal(r.bucket.items.length, 2);
  let l = P.addToBucket(null, { a: 1 }, { now: t0, kind: 'lists' });
  l = P.addToBucket(l.bucket, { a: 2 }, { now: t0 + 120_000, kind: 'lists' });
  assert.equal(l.dueAt, t0 + 120_000 + P.LIST_DEBOUNCE_MS);
  assert.equal(P.bucketDue(l.bucket, t0 + P.LIST_DEBOUNCE_MS), false, 'stale task no-ops');
  assert.equal(P.bucketDue(l.bucket, l.dueAt), true);
});

// ------------------------------------------------------- money projection

test('money-day: due items, series projection, balance, paid skip', () => {
  const anchors = [
    { id: 'rent', _month: '2026-08', _block: 'house', recurring: true, payee: 'Rent', amount: 1000, day: 1, account: 'j' },
    { id: 'gym', _month: '2026-08', _block: 'fun', recurring: true, recurEvery: 3, payee: 'Gym', amount: 90, day: 13, account: 'j' },
    { id: 'old', _month: '2026-01', _block: 'fun', recurring: true, recurEndDate: '2026-06-30', payee: 'Old', amount: 5, day: 13 },
    { id: 'sal', _month: '2026-09', _block: 'inc', recurring: true, payee: 'Salary', amount: 3000, day: 13, account: 'j' },
  ];
  const entries = [{ id: 'dent', _block: 'health', recurring: false, payee: 'Dentist', amount: 80, day: 13, paid: true }];
  const items = P.monthItems({ ym: '2026-10', month: { open: 500 }, months: { '2026-10': { open: 500 } }, entries, anchors });
  const ids = items.map((i) => i.id).sort();
  assert.ok(ids.includes('g_rent_2026_9'));
  assert.ok(!ids.some((i) => i.startsWith('g_gym')), 'gym every 3 months: Aug, Nov');
  assert.ok(!ids.some((i) => i.startsWith('g_old')), 'ended series');
  const { due, balance } = P.moneyDay(items, { date: '2026-10-13', open: 500, blocks: { inc: { isIncome: true } } });
  assert.deepEqual(due.map((d) => d.id).sort(), ['dent', 'g_sal_2026_9']);
  assert.equal(balance, 500 - 1000 - 80 + 3000);
  assert.equal(due.find((d) => d.id === 'g_sal_2026_9').income, true);

  const skipped = P.monthItems({ ym: '2026-10', month: { seriesSkips: ['rent'] }, months: {}, anchors });
  assert.ok(!skipped.some((i) => i.id === 'g_rent_2026_9'));
  const storedPaid = P.monthItems({ ym: '2026-10', occurrences: [{ id: 'g_rent_2026_9', seriesId: 'rent', paid: true, day: 1 }], anchors });
  assert.equal(storedPaid.filter((i) => i.id === 'g_rent_2026_9').length, 1);
  assert.equal(storedPaid.find((i) => i.id === 'g_rent_2026_9').paid, true);

  const rent = { id: 'g_rent_2026_9', paid: false };
  assert.equal(P.moneyDayPending(rent, null, 'u1'), true);
  assert.equal(P.moneyDayPending(rent, { paidSentAt: 1 }, 'u1'), false, 'paid immediately skips scheduled');
  assert.equal(P.moneyDayPending({ ...rent, paid: true }, null, 'u1'), false);
  assert.equal(P.moneyDayPending(rent, { scheduledUids: ['u1'] }, 'u1'), false);
  assert.equal(P.moneyMarkerId('2026-10', 'g_rent_2026_9'), '2026-10_g_rent_2026_9');
});

test('formatting helpers', () => {
  assert.equal(P.formatEuro(212.4), '€212,40');
  assert.equal(P.formatEuro(1234.5), '€1.234,50');
  assert.equal(P.formatEuro(-3), '−€3,00');
  assert.equal(P.joinNames(['Liv', 'Leo', 'Liv']), 'Liv and Leo');
  assert.equal(P.joinNames(['A', 'B', 'C']), 'A, B and C');
  assert.equal(P.localParts(at('2026-10-14T03:00:00Z'), NY).date, '2026-10-13');
});
