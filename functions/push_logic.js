'use strict';

// Pure push-notification rules (epic #469): prefs + scope filtering, §5 copy,
// FCM message shape, quiet hours, digest, buckets and the money-day
// projection. No Firestore here — orchestration lives in push_handlers.js.

const DEFAULT_TZ = 'Europe/Amsterdam';
const TYPES = ['chores', 'lists', 'cal', 'money', 'wall', 'family'];
const KID_TYPES = new Set(['chores', 'cal', 'money', 'family', 'wall']);
const CHORE_WINDOW_MS = 15 * 60 * 1000;
const LIST_DEBOUNCE_MS = 10 * 60 * 1000;
const MONEY_BUNDLE_WINDOW_MS = 10 * 60 * 1000;
const MONEY_BUNDLE_MIN = 3;
const MONEY_DAY_HOUR = 9;
const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// ------------------------------------------------------------------ prefs

function defaultPrefs({ kid = false, memberId = null } = {}) {
  return {
    chores: { on: true, scope: kid ? 'me' : 'kids', pick: [], events: { done: true, reward: true, stars: false } },
    lists: { on: true, scope: 'shop', pick: [], events: { added: true, ticked: false, finished: true } },
    cal: { on: true, scope: kid ? 'me' : 'mine', pick: [], events: { start: true, added: true, changed: true, cancelled: true } },
    money: {
      on: true,
      scope: kid ? 'pick' : 'shared',
      pick: kid && memberId ? [memberId] : [],
      events: { added: true, edited: true, paid: true, received: true },
    },
    wall: { on: false, scope: 'kids', pick: [], events: { ticked: true, stars: true } },
    family: { on: true, scope: 'all', pick: [], events: { joined: true, left: true, role: true } },
    quiet: { on: true, from: '21:30', to: '07:00', days: [true, true, true, true, true, true, true], letReminders: true },
  };
}

const isObj = (v) => !!v && typeof v === 'object' && !Array.isArray(v);

/** `raw` notifPrefs merged over the defaults; kid restrictions (#472) applied. */
function resolvePrefs(raw, { kid = false, memberId = null } = {}) {
  const def = defaultPrefs({ kid, memberId });
  const src = isObj(raw) ? raw : {};
  const out = {};
  for (const t of TYPES) {
    const r = isObj(src[t]) ? src[t] : {};
    out[t] = {
      ...def[t],
      ...r,
      pick: Array.isArray(r.pick) ? r.pick.map(String) : def[t].pick,
      events: { ...def[t].events, ...(isObj(r.events) ? r.events : {}) },
    };
  }
  const q = isObj(src.quiet) ? src.quiet : {};
  out.quiet = { ...def.quiet, ...q, days: Array.isArray(q.days) && q.days.length === 7 ? q.days.map((d) => d !== false) : def.quiet.days };
  if (kid) {
    out.lists = { ...out.lists, on: false };
    out.chores.scope = 'me';
    out.cal.scope = 'me';
    out.money.scope = 'pick';
    out.money.pick = memberId ? [memberId] : [];
  }
  return out;
}

/** Type switched on and the specific event ticked. */
function wants(prefs, type, event) {
  const p = prefs && prefs[type];
  if (!p || p.on === false) return false;
  if (!Object.values(p.events || {}).some((v) => v === true)) return false;
  return p.events[event] === true;
}

// ---------------------------------------------------------------- members

const membersOf = (family) => (Array.isArray(family && family.members) ? family.members : []);
const kidIdsOf = (family) => new Set(membersOf(family).filter((m) => m.role === 'kid').map((m) => m.id));

function memberById(family, id) {
  if (!id) return null;
  return membersOf(family).find((m) => m.id === id) || null;
}

/** Member row behind a writer id (`_by` / auth uid) — uid, member id or kidUids. */
function resolveActor(family, by) {
  if (!by) return null;
  const rows = membersOf(family);
  const kidId = family && isObj(family.kidUids) ? family.kidUids[by] : null;
  return rows.find((m) => m.uid === by) || rows.find((m) => m.id === by) || (kidId ? memberById(family, kidId) : null);
}

const nameOf = (m, fallback = 'Someone') => (m && String(m.name || '').trim()) || fallback;

function isKidMember(family, m) {
  if (!m) return false;
  if (m.role === 'kid') return true;
  return !!(m.uid && family && isObj(family.kidUids) && Object.prototype.hasOwnProperty.call(family.kidUids, m.uid));
}

function roleOf(family, m) {
  if (!m) return 'member';
  if (m.role === 'kid') return 'kid';
  if (m.role === 'owner' || (m.uid && family.ownerUid === m.uid)) return 'owner';
  if (m.uid && Array.isArray(family.adminUids) && family.adminUids.includes(m.uid)) return 'admin';
  return 'member';
}

/** Family rows that can receive pushes (signed-in, not just invited). */
function audienceMembers(family) {
  return membersOf(family).filter((m) => m.uid && m.status !== 'invited');
}

// ------------------------------------------------------------------ scope

/**
 * Does `ctx` pass recipient `me`'s scope for `type`?
 * ctx: {subjects: [memberId]} (chores, cal attendees, money, wall), or for
 * lists {listType, participants: [id|uid]}.
 */
function inScope(type, prefs, ctx, me, family) {
  const p = prefs[type];
  const scope = p.scope || 'all';
  if (scope === 'all') return true;
  const myIds = new Set([me.id, me.uid].filter(Boolean));
  const subjects = (ctx.subjects || []).map(String);
  const kids = kidIdsOf(family);
  if (type === 'lists') {
    if (scope === 'shop') return ctx.listType === 'shopping';
    if (scope === 'mine') return (ctx.participants || []).some((x) => myIds.has(x));
    return true;
  }
  if (type === 'money' && scope === 'shared') return true;
  if (scope === 'kids') return subjects.some((s) => kids.has(s));
  if (scope === 'me') return subjects.some((s) => myIds.has(s));
  if (scope === 'mine') return subjects.some((s) => myIds.has(s) || kids.has(s));
  if (scope === 'pick') return subjects.some((s) => p.pick.includes(s));
  return true;
}

/**
 * Recipients for one notification: audience rows minus `excludeUids`
 * (the actor), with kid restrictions, the type/event switch and the scope.
 * `prefsByUid` maps uid → raw notifPrefs. `includeUids` bypasses the
 * actor exclusion (role changed is also sent to the person themself).
 */
function selectRecipients(family, { type, event, ctx = {}, excludeUids = [], includeUids = [] }, prefsByUid = {}) {
  const out = [];
  const excl = new Set(excludeUids.filter(Boolean));
  const incl = new Set(includeUids.filter(Boolean));
  for (const m of audienceMembers(family)) {
    if (excl.has(m.uid) && !incl.has(m.uid)) continue;
    const kid = isKidMember(family, m);
    if (kid && !KID_TYPES.has(type)) continue;
    const prefs = resolvePrefs(prefsByUid[m.uid], { kid, memberId: m.id });
    if (!wants(prefs, type, event)) continue;
    if (!incl.has(m.uid) && !inScope(type, prefs, ctx, m, family)) continue;
    out.push({ uid: m.uid, member: m, prefs, kid });
  }
  return out;
}

// ----------------------------------------------------------------- format

function formatEuro(value) {
  let n = Number(value);
  if (!Number.isFinite(n)) n = 0;
  const neg = n < 0;
  const [whole, dec] = Math.abs(n).toFixed(2).split('.');
  return `${neg ? '\u2212' : ''}€${whole.replace(/\B(?=(\d{3})+(?!\d))/g, '.')},${dec}`;
}

function parseIso(iso) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(iso || ''));
  return m ? { y: +m[1], m: +m[2], d: +m[3] } : null;
}

/** ISO weekday index 0=Mon..6=Sun of a yyyy-mm-dd. */
function weekdayOf(iso) {
  const p = parseIso(iso);
  if (!p) return null;
  return (new Date(Date.UTC(p.y, p.m - 1, p.d)).getUTCDay() + 6) % 7;
}

/** "Tue 14 Oct" */
function formatDayDate(iso) {
  const p = parseIso(iso);
  if (!p) return String(iso || '');
  return `${DAYS[weekdayOf(iso)]} ${p.d} ${MONTHS[p.m - 1]}`;
}

function timeRange(ev) {
  if (!ev || ev.allDay || !ev.start) return 'All day';
  return ev.end ? `${ev.start}–${ev.end}` : ev.start;
}

/** "Liv", "Liv and Leo", "Liv, Leo and Mia" */
function joinNames(names) {
  const xs = [...new Set(names.filter(Boolean))];
  if (xs.length <= 1) return xs[0] || '';
  return `${xs.slice(0, -1).join(', ')} and ${xs[xs.length - 1]}`;
}

/** "Milk, eggs, bread and 1 more" */
function itemsSummary(names, max = 3) {
  const xs = names.filter(Boolean);
  if (xs.length <= max) return joinNames(xs);
  return `${xs.slice(0, max).join(', ')} and ${xs.length - max} more`;
}

const plural = (n, one, many = `${one}s`) => `${n} ${n === 1 ? one : many}`;
const parts = (...xs) => xs.filter((x) => x !== undefined && x !== null && String(x).trim() !== '').join(' · ');

// ------------------------------------------------------------------- copy
//
// Every builder returns a spec: {title, body, channel, tag, link, priority,
// group?, digest: {kind, count}}. `digest.kind` buckets held messages in the
// quiet-hours summary.

function spec({ title, body, channel, tag, link, priority = 'normal', group, kind, count = 1 }) {
  const s = { title, body, channel, tag, link, priority, digest: { kind, count } };
  if (group) s.group = group;
  return s;
}

function choreDone({ kid, chore, eventId, stars, n = 1 }) {
  return spec({
    title: `${kid} finished ${chore}`,
    body: `★ +${n} · ${stars} stars today`,
    channel: 'family_chores',
    tag: `chore:${eventId}`,
    link: `chore:${eventId}`,
    group: 'chores',
    kind: 'chore',
  });
}

/** 2+ chores in the 15-minute window. items: [{kid, chore, eventId}] */
function choresGrouped(items) {
  return spec({
    title: `${joinNames(items.map((i) => i.kid))} finished ${items.length} chores`,
    body: items.map((i) => `${i.kid} · ${i.chore}`).join('\n'),
    channel: 'family_chores',
    tag: 'chores',
    link: `chore:${items[items.length - 1].eventId}`,
    group: 'chores',
    kind: 'chore',
    count: items.length,
  });
}

function choreNotification(items) {
  if (items.length === 1) return choreDone(items[0]);
  return choresGrouped(items);
}

function rewardClaimed({ kid, memberId, familyId, reward = 'their reward', cost, left = 0, claimId }) {
  const s = spec({
    title: `${kid} wants ${reward}`,
    body: `${cost} stars · ${left} left after`,
    channel: 'family_chores',
    tag: `reward:${memberId}:${claimId}`,
    link: `reward:${memberId}`,
    priority: 'high',
    kind: 'reward',
  });
  s.approve = { familyId: String(familyId || ''), memberId: String(memberId), claimId: String(claimId) };
  return s;
}

function itemsAdded({ who, list, listId, listType, items }) {
  return spec({
    title: `${who} added ${plural(items.length, 'item')} to ${list}`,
    body: itemsSummary(items),
    channel: 'family_lists',
    tag: `list:${listId}`,
    link: `list:${listId}`,
    kind: listType === 'shopping' ? 'shopping' : 'list',
    count: items.length,
  });
}

function listFinished({ who, list, listId, listType }) {
  return spec({
    title: `${list} is done`,
    body: `${who} ticked off the last item`,
    channel: 'family_lists',
    tag: `list:${listId}`,
    link: `list:${listId}`,
    kind: listType === 'shopping' ? 'shopping' : 'list',
  });
}

const eventTitle = (ev, members) => (members ? `${ev.title} · ${members}` : ev.title);

function eventAdded({ who, ev, members }) {
  return spec({
    title: `${who} added ${eventTitle(ev, members)}`,
    body: `${formatDayDate(ev.date)} · ${timeRange(ev)}`,
    channel: 'family_calendar',
    tag: `event:${ev.id}`,
    link: `event:${ev.id}:${ev.date}`,
    kind: 'calendar',
  });
}

function eventMoved({ who, before, after, members }) {
  const dayChanged = before.date !== after.date;
  const was = dayChanged ? `${formatDayDate(before.date)} ${timeRange(before)}` : timeRange(before);
  return spec({
    title: `${who} moved ${eventTitle(after, members)}`,
    body: `${formatDayDate(after.date)} · now ${timeRange(after)} (was ${was})`,
    channel: 'family_calendar',
    tag: `event:${after.id}`,
    link: `event:${after.id}:${after.date}`,
    kind: 'calendar',
  });
}

function eventCancelled({ who, ev, date }) {
  const day = date || ev.date;
  return spec({
    title: `${ev.title} on ${formatDayDate(day)} is cancelled`,
    body: `By ${who}`,
    channel: 'family_calendar',
    tag: `event:${ev.id}`,
    link: `event:${ev.id}:${day}`,
    priority: 'high',
    kind: 'calendar',
  });
}

function moneyAdded({ who, entryId, income, amount, category, payee, account, date }) {
  return spec({
    title: income ? `${who} added income · ${formatEuro(amount)}` : `${who} added an expense · ${formatEuro(amount)}`,
    body: parts(category, payee, account),
    channel: 'family_money',
    tag: `entry:${entryId}`,
    link: `money:${date}`,
    kind: 'money',
  });
}

/** 3+ expenses by the same person within 10 minutes. */
function moneyBundle({ who, actorKey, amounts, payees, date }) {
  const total = amounts.reduce((a, b) => a + (Number(b) || 0), 0);
  return spec({
    title: `${who} added ${amounts.length} expenses · ${formatEuro(total)}`,
    body: itemsSummary(payees),
    channel: 'family_money',
    tag: `entries:${actorKey}`,
    link: `money:${date}`,
    kind: 'money',
    count: amounts.length,
  });
}

function moneyEdited({ who, entryId, payee, account, oldAmount, newAmount, date }) {
  const amounts = Number(oldAmount) === Number(newAmount)
    ? formatEuro(newAmount)
    : `${formatEuro(oldAmount)} → ${formatEuro(newAmount)}`;
  return spec({
    title: `${who} changed ${parts(payee, account)}`,
    body: parts(amounts, date ? formatDayDate(date) : 'No date'),
    channel: 'family_money',
    tag: `entry:${entryId}`,
    link: `money:${date}`,
    kind: 'money',
  });
}

function moneyRemoved({ who, entryId, payee, amount, category, account, date }) {
  return spec({
    title: `${who} removed ${parts(payee, formatEuro(amount))}`,
    body: parts(category, account),
    channel: 'family_money',
    tag: `entry:${entryId}`,
    link: `money:${date}`,
    kind: 'money',
  });
}

function paidOut({ entryId, payee, amount, account, balance, date }) {
  return spec({
    title: `${payee} paid · ${formatEuro(amount)}`,
    body: `From ${account} · ${formatEuro(balance)} left`,
    channel: 'family_money',
    tag: `entry:${entryId}`,
    link: `money:${date}`,
    group: 'money-day',
    kind: 'money',
  });
}

function received({ entryId, source, amount, account, balance, date }) {
  return spec({
    title: `${source} received · ${formatEuro(amount)}`,
    body: `Into ${account} · ${formatEuro(balance)} now`,
    channel: 'family_money',
    tag: `entry:${entryId}`,
    link: `money:${date}`,
    group: 'money-day',
    kind: 'money',
  });
}

function wallTicked({ kid, chore, eventId, stars, n = 1 }) {
  return spec({
    title: `${kid} ticked ${chore} on the wall`,
    body: `★ +${n} · ${stars} stars today`,
    channel: 'family_wall',
    tag: `wall:${eventId}`,
    link: `chore:${eventId}`,
    group: 'wall',
    kind: 'wall',
  });
}

function memberJoined({ name, family, role, who, memberId }) {
  return spec({
    title: `${name} joined the ${family} family`,
    body: who ? `Added as ${role} by ${who}` : `Added as ${role}`,
    channel: 'family_members',
    tag: `member:${memberId}`,
    link: 'members',
    kind: 'family',
  });
}

function memberLeft({ name, memberId, who }) {
  return spec({
    title: who ? `${who} removed ${name}` : `${name} left the family`,
    body: 'Chores and events stay',
    channel: 'family_members',
    tag: `member:${memberId}`,
    link: 'members',
    kind: 'family',
  });
}

const article = (w) => (/^[aeiou]/i.test(w) ? `an ${w}` : `a ${w}`);

function roleChanged({ name, role, who, memberId }) {
  return spec({
    title: `${name} is now ${article(role)}`,
    body: `Changed by ${who}`,
    channel: 'family_members',
    tag: `role:${memberId}`,
    link: 'members',
    priority: 'high',
    kind: 'family',
  });
}

const DIGEST_ORDER = ['reward', 'chore', 'shopping', 'list', 'calendar', 'money', 'family', 'wall'];
const DIGEST_LABEL = {
  reward: (n) => plural(n, 'reward claim'),
  chore: (n) => `${plural(n, 'chore')} done`,
  shopping: (n) => plural(n, 'shopping change'),
  list: (n) => plural(n, 'list change'),
  calendar: (n) => plural(n, 'calendar change'),
  money: (n) => plural(n, 'money update'),
  family: (n) => plural(n, 'family change'),
  wall: (n) => plural(n, 'wall tick'),
};
const DIGEST_MAX_PARTS = 3;

/** One quiet-hours summary from held specs (reward claims first). */
function digest(held) {
  const counts = {};
  let total = 0;
  for (const h of held) {
    const kind = DIGEST_LABEL[h?.digest?.kind] ? h.digest.kind : 'family';
    const n = Math.max(1, Number(h?.digest?.count) || 1);
    counts[kind] = (counts[kind] || 0) + n;
    total += n;
  }
  if (!total) return null;
  const all = DIGEST_ORDER.filter((k) => counts[k]).map((k) => DIGEST_LABEL[k](counts[k]));
  const shown = all.slice(0, DIGEST_MAX_PARTS);
  if (all.length > DIGEST_MAX_PARTS) shown.push('…');
  return spec({
    title: `${plural(total, 'family update')} overnight`,
    body: shown.join(' · '),
    channel: 'family_digest',
    tag: 'digest',
    link: 'digest',
    kind: 'digest',
    count: total,
  });
}

// -------------------------------------------------------------- FCM shape

const REWARD_ACTIONS = JSON.stringify([{ id: 'approve', title: 'Approve' }, { id: 'open', title: 'Open' }]);

/**
 * FCM message for spec `s`. Specs carrying `approve` (Reward claimed) are
 * data-only so the client can render the "Approve"/"Open" actions itself;
 * everything else also carries a `notification` block. `data` always has
 * title/body for the foreground handler.
 */
function fcmMessage(s, token) {
  const data = { title: s.title, body: s.body, link: String(s.link), channel: s.channel, tag: s.tag };
  if (s.group) data.group = s.group;
  const priority = s.priority === 'high' ? 'high' : 'normal';
  if (s.approve) {
    data.actions = REWARD_ACTIONS;
    data.approve = JSON.stringify(s.approve);
    return {
      token,
      android: { collapseKey: s.tag, priority: 'high' },
      apns: {
        headers: { 'apns-collapse-id': s.tag },
        payload: { aps: { alert: { title: s.title, body: s.body } } },
      },
      data,
    };
  }
  return {
    token,
    notification: { title: s.title, body: s.body },
    android: {
      collapseKey: s.tag,
      priority,
      ...(s.ttlMs ? { ttl: s.ttlMs } : {}),
      notification: { channelId: s.channel, tag: s.tag },
    },
    apns: { headers: { 'apns-collapse-id': s.tag, ...(s.ttlMs ? { 'apns-expiration': String(Math.floor(Date.now() / 1000) + Math.ceil(s.ttlMs / 1000)) } : {}) } },
    data,
  };
}

/** Device enabled and the message's channel not switched off. */
function deviceAccepts(device, channel) {
  if (!device || !device.token || device.enabled === false) return false;
  return !(isObj(device.channelState) && device.channelState[channel] === false);
}

const millisOf = (v) => {
  if (!v) return 0;
  if (typeof v === 'number') return v;
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (v instanceof Date) return v.getTime();
  return 0;
};

/** The user's timezone: the most recently updated device's. */
function userTimezone(devices) {
  const withTz = (devices || []).filter((d) => d && d.timezone);
  if (!withTz.length) return DEFAULT_TZ;
  withTz.sort((a, b) => millisOf(b.updatedAt) - millisOf(a.updatedAt));
  return withTz[0].timezone;
}

// ------------------------------------------------------------ time / quiet

const fmtCache = new Map();
function formatter(tz) {
  if (!fmtCache.has(tz)) {
    fmtCache.set(tz, new Intl.DateTimeFormat('en-GB', {
      timeZone: tz,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }));
  }
  return fmtCache.get(tz);
}

/** Wall-clock parts of `ms` in `tz`: {date: 'yyyy-mm-dd', hour, minute, weekday 0=Mon}. */
function localParts(ms, tz) {
  let f;
  try {
    f = formatter(tz || DEFAULT_TZ);
  } catch (_) {
    f = formatter('UTC');
  }
  const p = Object.fromEntries(f.formatToParts(new Date(ms)).map((x) => [x.type, x.value]));
  const date = `${p.year}-${p.month}-${p.day}`;
  return { date, hour: +p.hour % 24, minute: +p.minute, weekday: weekdayOf(date) };
}

function hhmm(s) {
  const m = /^(\d{1,2}):(\d{2})$/.exec(String(s || ''));
  return m ? +m[1] * 60 + +m[2] : null;
}

/**
 * Is `ms` inside the quiet window in `tz`? Day chips (Mon..Sun) apply to the
 * day the window STARTS, so Fri 21:30–07:00 also covers Saturday morning.
 */
function inQuietHours(quiet, ms, tz) {
  if (!quiet || quiet.on === false) return false;
  const from = hhmm(quiet.from);
  const to = hhmm(quiet.to);
  if (from === null || to === null || from === to) return false;
  const days = Array.isArray(quiet.days) && quiet.days.length === 7 ? quiet.days : [true, true, true, true, true, true, true];
  const { hour, minute, weekday } = localParts(ms, tz);
  const t = hour * 60 + minute;
  if (from < to) return days[weekday] !== false && t >= from && t < to;
  if (t >= from) return days[weekday] !== false;
  if (t < to) return days[(weekday + 6) % 7] !== false;
  return false;
}

// -------------------------------------------------------------- classify

const doneDatesOf = (ev) => (isObj(ev && ev.doneDates) ? ev.doneDates : {});
const isChore = (ev) => !!ev && ev.kitchenOrigin === true;

/** Newly completed occurrence dates of a kitchen chore (and un-completed ones). */
function choreCompletions(before, after) {
  if (!isChore(after)) return { done: [], undone: [] };
  const done = [];
  const undone = [];
  if ((after.recur || 'none') === 'none') {
    const was = !!(before && before.done);
    if (after.done === true && !was) done.push(after.date);
    if (after.done !== true && was) undone.push(after.date);
  } else {
    const b = doneDatesOf(before);
    const a = doneDatesOf(after);
    for (const [d, v] of Object.entries(a)) if (v === true && b[d] !== true) done.push(d);
    for (const [d, v] of Object.entries(b)) if (v === true && a[d] !== true) undone.push(d);
  }
  return { done, undone };
}

const timeChanged = (a, b) => ['date', 'start', 'end', 'allDay'].some((k) => (a[k] ?? null) !== (b[k] ?? null));

/** Calendar change → [{kind: 'added'|'moved'|'cancelled', date?}]; chores excluded. */
function classifyEvent(before, after) {
  if (isChore(after) || (!after && isChore(before))) return [];
  if (!before && after) return [{ kind: 'added' }];
  if (before && !after) return [{ kind: 'cancelled', date: before.date }];
  if (!before || !after) return [];
  const out = [];
  if (timeChanged(before, after)) out.push({ kind: 'moved' });
  const was = new Set((before.exceptions || []).map(String));
  for (const d of after.exceptions || []) if (!was.has(String(d))) out.push({ kind: 'cancelled', date: String(d) });
  return out;
}

const lineName = (l) => String((l && (l._kind === 'shop' ? l.name : l.title)) || (l && (l.name || l.title)) || '').trim();
const lineDone = (l) => !!(l && (l.done === true || l.checked === true));

/** List line change → {added?: name, ticked?: true}. */
function classifyLine(before, after) {
  if (!after) return {};
  if (!before) return lineDone(after) ? {} : { added: lineName(after) };
  if (lineDone(after) && !lineDone(before)) return { ticked: true };
  return {};
}

/** Kitchen starsMap diff: members whose bar went from 5+ to 0 (claimed). */
function rewardClaims(before, after) {
  const b = isObj(before && before.starsMap) ? before.starsMap : {};
  const a = isObj(after && after.starsMap) ? after.starsMap : {};
  const out = [];
  for (const [id, prev] of Object.entries(b)) {
    if (Number(prev) >= 5 && Number(a[id] || 0) === 0) out.push({ memberId: id, cost: Number(prev) });
  }
  return out;
}

const MONEY_FIELDS = ['amount', 'payee', 'label', 'day', 'account'];

/**
 * Money record change. `stored` = months/{ym}/recurring occurrence (only paid
 * flips matter — generated copies are only stored once paid/edited).
 * → {kind: 'added'|'edited'|'removed'|'paid'} or null.
 */
function classifyEntry(before, after, { stored = false } = {}) {
  const paidNow = !!(after && after.paid === true);
  const paidBefore = !!(before && before.paid === true);
  if (after && paidNow && !paidBefore) return { kind: 'paid' };
  if (stored) return null;
  if (!before && after) return { kind: 'added' };
  if (before && !after) return { kind: 'removed' };
  if (before && after && MONEY_FIELDS.some((k) => (before[k] ?? null) !== (after[k] ?? null))) return { kind: 'edited' };
  return null;
}

/** Family doc diff → [{kind: 'joined'|'left'|'role', member, role?}]. */
function classifyFamily(before, after) {
  if (!before || !after) return [];
  const prev = new Map(membersOf(before).map((m) => [m.id, m]));
  const next = new Map(membersOf(after).map((m) => [m.id, m]));
  const out = [];
  for (const [id, m] of next) {
    const p = prev.get(id);
    if (m.status === 'invited') continue;
    if (!p || p.status === 'invited') {
      out.push({ kind: 'joined', member: m, role: roleOf(after, m) });
      continue;
    }
    const was = roleOf(before, p);
    const now = roleOf(after, m);
    if (was !== now) out.push({ kind: 'role', member: m, role: now });
  }
  for (const [id, p] of prev) {
    if (!next.has(id) && p.status !== 'invited') out.push({ kind: 'left', member: p });
  }
  return out;
}

// ---------------------------------------------------------------- buckets

/**
 * Adds `item` to a debounce bucket. Chores: fixed 15-min window from the
 * first item; lists: sliding 10 min after the last change. Returns the next
 * bucket and whether a flush task must be enqueued for `dueAt`.
 */
function addToBucket(bucket, item, { now, kind }) {
  const fresh = !bucket || !Array.isArray(bucket.items);
  const items = fresh ? [] : bucket.items.slice();
  items.push(item);
  let dueAt;
  let enqueue;
  if (kind === 'chores') {
    dueAt = fresh ? now + CHORE_WINDOW_MS : bucket.dueAt;
    enqueue = fresh;
  } else {
    dueAt = now + LIST_DEBOUNCE_MS;
    enqueue = true;
  }
  return { bucket: { ...(bucket || {}), kind, items, dueAt, updatedAt: now }, enqueue, dueAt };
}

/** Flush only once the bucket is due (earlier tasks of a sliding bucket no-op). */
function bucketDue(bucket, now, graceMs = 5000) {
  return !!bucket && Array.isArray(bucket.items) && bucket.items.length > 0 && (bucket.dueAt || 0) <= now + graceMs;
}

/** Money bundle tracker: recent adds within 10 min, bundle at 3+. */
function trackMoneyAdd(state, add, now) {
  const recent = (state && Array.isArray(state.adds) ? state.adds : []).filter((a) => now - a.at < MONEY_BUNDLE_WINDOW_MS);
  recent.push({ ...add, at: now });
  return { state: { adds: recent, updatedAt: now }, bundle: recent.length >= MONEY_BUNDLE_MIN ? recent : null };
}

// ----------------------------------------------------- money-day projection

const monthOrd = (ym) => {
  const m = /^(\d{4})-(\d{2})$/.exec(String(ym || ''));
  return m ? +m[1] * 12 + (+m[2] - 1) : null;
};
const daysInMonth = (y, m) => new Date(Date.UTC(y, m, 0)).getUTCDate();

function itemDay(it) {
  if (Object.prototype.hasOwnProperty.call(it, 'day')) {
    return it.day === null || it.day === undefined ? null : Number(it.day) || null;
  }
  const m = /(\d{1,2})/.exec(String(it.marker || ''));
  return m ? +m[1] : null;
}

/** The yyyy-mm-dd item `it` posts on in month `ym` (weekend shift applied). */
function itemDate(it, ym) {
  const day = itemDay(it);
  const ord = monthOrd(ym);
  if (!day || ord === null) return null;
  const y = Math.floor(ord / 12);
  const m = (ord % 12) + 1;
  let d = Math.min(Math.max(1, day), daysInMonth(y, m));
  const wd = () => (new Date(Date.UTC(y, m - 1, d)).getUTCDay() + 6) % 7;
  if (it.shift === 'before') {
    while (wd() >= 5 && d > 1) d -= 1;
  } else if (it.shift === 'after') {
    while (wd() >= 5 && d < daysInMonth(y, m)) d += 1;
  }
  return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

const seriesIdOf = (it) => {
  const raw = String(it.seriesId || '').trim();
  if (raw) return raw;
  return it.recurring === false ? null : it.id;
};

/**
 * Every budget item of month `ym` (mirrors the app's series sync, simplified):
 * stored one-offs + stored occurrences + series occurrences regenerated from
 * their anchors. Each item: {...fields, id, _block}.
 * input: {ym, month, months: {ym: monthDoc}, entries, occurrences, anchors}
 */
function monthItems({ ym, month = {}, months = {}, entries = [], occurrences = [], anchors = [] }) {
  const ord = monthOrd(ym);
  const out = [...entries, ...occurrences];
  const storedSeries = new Set(occurrences.map(seriesIdOf).filter(Boolean));
  const [y, mIdx] = [Math.floor(ord / 12), ord % 12];
  const latest = new Map();
  for (const a of anchors) {
    const aOrd = monthOrd(a._month);
    if (aOrd === null || aOrd > ord) continue;
    const sid = seriesIdOf(a);
    if (!sid) continue;
    const cur = latest.get(sid);
    if (!cur || monthOrd(cur._month) < aOrd) latest.set(sid, a);
  }
  for (const [sid, a] of latest) {
    if (storedSeries.has(sid)) continue;
    const aOrd = monthOrd(a._month);
    if (aOrd === ord) {
      out.push(a);
      continue;
    }
    if (a.recurring === false || month.closed) continue;
    const every = Math.max(1, Number(a.recurEvery) || 1);
    if ((ord - aOrd) % every !== 0) continue;
    if ((month.seriesSkips || []).includes(sid)) continue;
    const stopped = Object.entries(months).some(([k, m]) => {
      const o = monthOrd(k);
      return o !== null && o >= aOrd && o <= ord && (m.seriesStops || []).includes(sid);
    });
    if (stopped) continue;
    const end = parseIso(a.recurEndDate || (typeof a.until === 'string' ? a.until : null));
    if (end && end.y * 12 + (end.m - 1) < ord) continue;
    out.push({ ...a, id: `g_${sid}_${y}_${mIdx}`.replace(/\//g, '_'), generated: true, paid: false });
  }
  return out;
}

/**
 * Items posting on `date` plus the family's projected balance after that day
 * (month `open` + income − expenses up to and including `date`), like the
 * Money calendar's running balance. blocks: {key: {isIncome, title}}.
 */
function moneyDay(items, { date, open = 0, blocks = {} }) {
  const ym = date.slice(0, 7);
  let balance = Number(open) || 0;
  const due = [];
  for (const it of items) {
    const d = itemDate(it, ym);
    if (!d) continue;
    const income = !!(blocks[it._block] && blocks[it._block].isIncome);
    if (d <= date) balance += (income ? 1 : -1) * (Number(it.amount) || 0);
    if (d === date) due.push({ ...it, income, date: d });
  }
  return { due, balance };
}

/** Marker doc id shared by the paid trigger and the money-day run. */
const moneyMarkerId = (ym, itemId) => `${ym}_${String(itemId).replace(/\//g, '_')}`;

/** Should the 09:00 run notify `uid` about `item` (not paid, no marker)? */
function moneyDayPending(item, marker, uid) {
  if (item.paid === true) return false;
  if (marker && marker.paidSentAt) return false;
  return !(marker && Array.isArray(marker.scheduledUids) && marker.scheduledUids.includes(uid));
}

module.exports = {
  DEFAULT_TZ,
  CHORE_WINDOW_MS,
  LIST_DEBOUNCE_MS,
  MONEY_DAY_HOUR,
  defaultPrefs,
  resolvePrefs,
  wants,
  memberById,
  resolveActor,
  nameOf,
  isKidMember,
  roleOf,
  audienceMembers,
  inScope,
  selectRecipients,
  formatEuro,
  formatDayDate,
  timeRange,
  joinNames,
  itemsSummary,
  choreDone,
  choresGrouped,
  choreNotification,
  rewardClaimed,
  itemsAdded,
  listFinished,
  eventAdded,
  eventMoved,
  eventCancelled,
  moneyAdded,
  moneyBundle,
  moneyEdited,
  moneyRemoved,
  paidOut,
  received,
  wallTicked,
  memberJoined,
  memberLeft,
  roleChanged,
  digest,
  fcmMessage,
  deviceAccepts,
  userTimezone,
  localParts,
  inQuietHours,
  choreCompletions,
  classifyEvent,
  classifyLine,
  lineName,
  lineDone,
  rewardClaims,
  classifyEntry,
  classifyFamily,
  addToBucket,
  bucketDue,
  trackMoneyAdd,
  itemDate,
  monthItems,
  moneyDay,
  moneyMarkerId,
  moneyDayPending,
};
