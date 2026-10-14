'use strict';

// Firestore/FCM orchestration for push notifications (epic #469). Every
// dependency is injected so this runs against in-memory fakes; the rules,
// copy and time maths are pure in push_logic.js.

const { HttpsError } = require('firebase-functions/v2/https');
const P = require('./push_logic');
const L = require('./kid_logic');
const R = require('./reminder_logic');
const { createHash } = require('node:crypto');
const { DateTime } = require('luxon');

const DAY_MS = 24 * 60 * 60 * 1000;
const LOG_TTL_MS = 7 * DAY_MS;
const HELD_TTL_MS = 3 * DAY_MS;
const MARKER_TTL_MS = 62 * DAY_MS;
const STALE_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

const safeId = (s) => String(s).replace(/\//g, '_');
const taskId = (s) => String(s).replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 480);
const dataOf = (snap) => (snap && snap.exists ? snap.data() || {} : null);
const errCode = (err) => (err && (err.errorInfo?.code || err.code)) || '';

function createPushHandlers({ db, messaging, enqueue, now = () => Date.now(), logger = console }) {
  const famPath = (fid) => `families/${fid}`;

  /** First delivery of a trigger event wins; retries (same event id) no-op. */
  async function firstDelivery(fid, eventId) {
    if (!eventId) return true;
    try {
      await db.doc(`${famPath(fid)}/pushLog/${safeId(eventId)}`).create({
        at: now(),
        expireAt: new Date(now() + LOG_TTL_MS),
      });
      return true;
    } catch (err) {
      if (err && (err.code === 6 || err.code === 'already-exists' || /already exists/i.test(err.message || ''))) {
        return false;
      }
      throw err;
    }
  }

  /** Writer uid: the trigger's auth context, else the record's `_by`. */
  function actorUid(event, before, after) {
    if (event && event.authType === 'app_user' && event.authId) return event.authId;
    return (after && after._by) || (before && before._by) || null;
  }

  async function loadFamily(fid) {
    return dataOf(await db.doc(famPath(fid)).get());
  }

  async function devicesOf(fid, uid) {
    const snap = await db.collection(`${famPath(fid)}/members/${uid}/devices`).get();
    return snap.docs.map((d) => ({ ...d.data(), id: d.id, path: `${famPath(fid)}/members/${uid}/devices/${d.id}` }));
  }

  /** uid → {prefs (raw), devices, tz} for every member who can receive pushes. */
  async function loadAudience(fid, family) {
    const out = {};
    await Promise.all(P.audienceMembers(family).map(async (m) => {
      const [user, devices] = await Promise.all([db.doc(`users/${m.uid}`).get(), devicesOf(fid, m.uid)]);
      out[m.uid] = { rawPrefs: (dataOf(user) || {}).notifPrefs, devices, tz: P.userTimezone(devices) };
    }));
    return out;
  }

  const prefsMap = (aud) => Object.fromEntries(Object.entries(aud).map(([uid, a]) => [uid, a.rawPrefs]));

  async function sendToDevices(devices, spec) {
    let sent = 0;
    for (const d of devices) {
      if (!P.deviceAccepts(d, spec.channel)) continue;
      try {
        await messaging.send(P.fcmMessage(spec, d.token));
        sent += 1;
      } catch (err) {
        if (STALE_TOKEN_CODES.has(errCode(err))) {
          await db.doc(d.path).delete();
        } else {
          logger.error?.('push send failed', errCode(err) || err);
        }
      }
    }
    return sent;
  }

  /** Sends `spec` to one recipient, or holds it while they're in quiet hours. */
  async function deliver(fid, aud, r, spec) {
    const a = aud[r.uid];
    if (!a || !spec) return 'skipped';
    if (P.inQuietHours(r.prefs.quiet, now(), a.tz)) {
      await db.doc(`users/${r.uid}/pushHeld/${safeId(`${fid}_${spec.tag}`)}`).set({
        familyId: fid,
        spec,
        heldAt: now(),
        expireAt: new Date(now() + HELD_TTL_MS),
      });
      return 'held';
    }
    await sendToDevices(a.devices, spec);
    return 'sent';
  }

  /** Select recipients for one notification and deliver `build(recipient)`. */
  async function fanOut(fid, family, aud, select, build) {
    const recips = P.selectRecipients(family, select, prefsMap(aud));
    const delivered = [];
    for (const r of recips) {
      const spec = build(r);
      if (!spec) continue;
      await deliver(fid, aud, r, spec);
      delivered.push(r.uid);
    }
    return delivered;
  }

  async function scheduleFlush(fid, bucket, dueAt) {
    if (!enqueue) return;
    try {
      await enqueue(
        { familyId: fid, bucket },
        { scheduleDelaySeconds: Math.max(1, Math.ceil((dueAt - now()) / 1000)), id: taskId(`${fid}-${bucket}-${dueAt}`) },
      );
    } catch (err) {
      if (!/already.?exists/i.test(`${errCode(err)} ${err && err.message}`)) throw err;
    }
  }

  /** Appends to (or, with `remove`, prunes) a debounce bucket; enqueues its flush. */
  async function bucketAdd(fid, bucket, kind, items, remove) {
    const ref = db.doc(`${famPath(fid)}/pushQueue/${safeId(bucket)}`);
    const res = await db.runTransaction(async (tx) => {
      let cur = dataOf(await tx.get(ref));
      if (remove && cur && Array.isArray(cur.items)) {
        cur = { ...cur, items: cur.items.filter((i) => !remove(i)) };
      }
      let enq = null;
      for (const item of items) {
        const next = P.addToBucket(cur, item, { now: now(), kind });
        cur = next.bucket;
        if (next.enqueue) enq = next.dueAt;
      }
      if (!cur) return null;
      tx.set(ref, { ...cur, expireAt: new Date(now() + DAY_MS) });
      return enq;
    });
    if (res) await scheduleFlush(fid, bucket, res);
  }

  // Calendar reminders are queued on the server. A one-minute scheduled
  // function dispatches them; every dispatch rechecks the current source,
  // membership and preferences so stale edits and deletions cannot ring.
  async function queueSourceReminders(fid, path, source) {
    if (!source) return 0;
    const family = await loadFamily(fid);
    if (!family) return 0;
    const aud = await loadAudience(fid, family);
    const items = path.includes('/imports/')
      ? source.visible === false || source.reminder === 'none' ? []
        : (source.events || []).map((e) => ({ ...e, reminder: source.reminder || '1h', recur: 'none', imported: true }))
      : [{ reminder: '1h', ...source, id: source.id || path.split('/').pop() }];
    let queued = 0;
    for (const [uid, a] of Object.entries(aud)) {
      const zone = DateTime.now().setZone(a.tz).isValid ? a.tz : P.DEFAULT_TZ;
      const localToday = DateTime.fromMillis(now(), { zone }).toISODate();
      const from = DateTime.fromISO(localToday).minus({ days: 2 }).toISODate();
      const through = DateTime.fromISO(localToday).plus({ days: R.HORIZON_DAYS + 2 }).toISODate();
      for (const ev of items) {
        for (const occurrence of R.occurrenceDates(ev, from, through)) {
          for (const kind of ev.imported ? ['reminder'] : ['reminder', 'start']) {
            const dueAt = R.dueAt(ev, occurrence, kind, zone);
            if (dueAt === null || dueAt <= now() || dueAt > now() + R.HORIZON_DAYS * R.DAY_MS) continue;
            const key = [path, ev.id, uid, kind, occurrence, dueAt].join('|');
            const id = createHash('sha256').update(key).digest('hex');
            try {
              await db.doc(`pushReminders/${id}`).create({
                fid, uid, sourcePath: path, eventId: ev.id, occurrence, kind,
                dueAt, expireAt: new Date(dueAt + R.DAY_MS),
              });
              queued++;
            } catch (err) {
              if (!(err.code === 6 || err.code === 'already-exists' || /already exists/i.test(err.message || ''))) throw err;
            }
          }
        }
      }
    }
    return queued;
  }

  async function runDueReminders() {
    const due = await db.collection('pushReminders').where('dueAt', '<=', now()).limit(100).get();
    let sent = 0;
    for (const doc of due.docs) {
      // Scheduler invocations can overlap. Claim each due row before sending.
      const claimed = await db.runTransaction(async (tx) => {
        const current = dataOf(await tx.get(doc.ref));
        if (!current || (current.claimedAt && now() - current.claimedAt < 120_000)) return false;
        tx.update(doc.ref, { claimedAt: now() });
        return true;
      });
      if (!claimed) continue;
      const job = doc.data();
      let failed = false;
      try {
        if (now() - job.dueAt > 10 * 60_000) continue;
        const [source, family] = await Promise.all([
          db.doc(job.sourcePath).get(), db.doc(famPath(job.fid)).get(),
        ]);
        if (!source.exists || !family.exists) continue;
        const familyData = family.data();
        if (!P.audienceMembers(familyData).some((m) => m.uid === job.uid)) continue;
        const raw = source.data();
        const imported = job.sourcePath.includes('/imports/');
        const event = imported
          ? raw.visible === false ? null : (raw.events || []).find((e) => e.id === job.eventId)
          : raw;
        if (!event) continue;
        const ev = imported ? { ...event, reminder: raw.reminder || '1h', recur: 'none' } : { reminder: '1h', ...event };
        const devices = await devicesOf(job.fid, job.uid);
        const zone = P.userTimezone(devices);
        if (R.dueAt(ev, job.occurrence, job.kind, zone) !== job.dueAt) continue;
        const user = dataOf(await db.doc(`users/${job.uid}`).get()) || {};
        const member = P.audienceMembers(familyData).find((m) => m.uid === job.uid);
        const prefs = P.resolvePrefs(user.notifPrefs, {
          kid: P.isKidMember(familyData, member), memberId: member.id,
        });
        if (job.kind === 'start') {
          const recips = P.selectRecipients(familyData, {
            type: 'cal', event: 'start', ctx: { subjects: (ev.attendees || []).map(String) },
          }, { [job.uid]: user.notifPrefs }).filter((r) => r.uid === job.uid);
          if (!recips.length) continue;
        }
        if (P.inQuietHours(prefs.quiet, now(), zone) && prefs.quiet.letReminders === false) continue;
        const names = P.joinNames((ev.attendees || []).map((id) => P.memberById(familyData, id)).filter(Boolean).map(P.nameOf));
        const copy = job.kind === 'start' ? R.startCopy(ev, names)
          : { title: ev.title, body: R.reminderBody(ev) };
        const channel = job.kind === 'start' ? 'event_start' : 'event_reminders';
        const spec = {
          ...copy, channel, priority: 'high', ttlMs: 300_000, tag: `event_${job.eventId}_${job.occurrence}_${job.kind}`,
          link: `event:${imported ? `${job.sourcePath.split('/').pop()}_${job.eventId}` : job.eventId}:${job.occurrence}`,
        };
        for (const device of devices) {
          if (job.kind === 'reminder' && device.remindersEnabled === false) continue;
          sent += await sendToDevices([device], spec);
        }
      } catch (err) {
        failed = true;
        logger.error?.('reminder dispatch failed', err);
      } finally {
        if (!failed) await doc.ref.delete();
      }
    }
    return { sent, processed: due.docs.length };
  }

  // Daily backfill covers existing events on first deploy, new members and
  // the next 30 days of recurring events without keeping years of jobs.
  async function refreshReminders() {
    let queued = 0;
    for (const group of ['events', 'recurring', 'imports']) {
      const docs = await db.collectionGroup(group).get();
      for (const doc of docs.docs) {
        const match = /^families\/([^/]+)\/calendar\/main\//.exec(doc.ref.path);
        if (match) queued += await queueSourceReminders(match[1], doc.ref.path, doc.data());
      }
    }
    return { queued };
  }

  async function refreshFamilyReminders(fid) {
    let queued = 0;
    const base = `${famPath(fid)}/calendar/main`;
    for (const group of ['recurring', 'imports']) {
      const docs = await db.collection(`${base}/${group}`).get();
      for (const doc of docs.docs) queued += await queueSourceReminders(fid, doc.ref.path, doc.data());
    }
    const months = await db.collection(`${base}/months`).get();
    for (const month of months.docs) {
      const events = await db.collection(`${month.ref.path}/events`).get();
      for (const doc of events.docs) queued += await queueSourceReminders(fid, doc.ref.path, doc.data());
    }
    return { queued };
  }

  async function onDeviceWrite(event) {
    const before = dataOf(event.data && event.data.before);
    const after = dataOf(event.data && event.data.after);
    if (!after || (before && before.timezone === after.timezone)) return { queued: 0 };
    return refreshFamilyReminders(event.params.fid);
  }

  async function onCalendarImport(event) {
    const after = dataOf(event.data && event.data.after);
    return { queued: await queueSourceReminders(event.params.fid, event.data.after.ref?.path || `families/${event.params.fid}/calendar/main/imports/${event.params.importId}`, after) };
  }

  // ------------------------------------------------------------ triggers

  /** calendar/main/months/{m}/events/{id} and calendar/main/recurring/{id}. */
  async function onCalendarEvent(event) {
    const fid = event.params.fid;
    const before = dataOf(event.data && event.data.before);
    const after = dataOf(event.data && event.data.after);
    // Reminder rows use stable ids, so retries can repair a failed queue write.
    if (after) await queueSourceReminders(fid, event.data.after.ref?.path || `families/${fid}/calendar/main/${event.params.month ? `months/${event.params.month}/events` : 'recurring'}/${event.params.eventId}`, after);
    if (!(await firstDelivery(fid, event.id))) return { duplicate: true };
    const actor = actorUid(event, before, after);

    const { done, undone } = P.choreCompletions(before, after);
    if (done.length || undone.length) {
      const id = after.id || event.params.eventId;
      const gone = new Set(undone.map((d) => `${id}|${d}`));
      await bucketAdd(
        fid,
        'chores',
        'chores',
        done.map((date) => ({
          eventId: id,
          date,
          title: after.title || 'a chore',
          memberIds: (after.attendees || []).map(String),
          actorUid: actor,
          at: now(),
        })),
        (i) => gone.has(`${i.eventId}|${i.date}`),
      );
    }

    const changes = P.classifyEvent(before, after);
    if (!changes.length) return { changes: [] };
    const family = await loadFamily(fid);
    if (!family) return { changes: [] };
    const aud = await loadAudience(fid, family);
    const ev = { ...(after || before), id: (after || before).id || event.params.eventId };
    const who = P.nameOf(P.resolveActor(family, actor));
    const attendees = (ev.attendees || []).map(String);
    const members = P.joinNames(attendees.map((id) => P.memberById(family, id)).filter(Boolean).map((m) => P.nameOf(m)));
    const select = (evt) => ({ type: 'cal', event: evt, ctx: { subjects: attendees }, excludeUids: [actor] });
    for (const c of changes) {
      if (c.kind === 'added') await fanOut(fid, family, aud, select('added'), () => P.eventAdded({ who, ev, members }));
      if (c.kind === 'moved') {
        await fanOut(fid, family, aud, select('changed'), () => P.eventMoved({ who, before, after: ev, members }));
      }
      if (c.kind === 'cancelled') {
        await fanOut(fid, family, aud, select('cancelled'), () => P.eventCancelled({ who, ev, date: c.date }));
      }
    }
    return { changes: changes.map((c) => c.kind) };
  }

  /** notes/{listId}/lines/{lineId}: debounced into `list_{listId}`. */
  async function onListLine(event) {
    const { fid, listId } = event.params;
    const before = dataOf(event.data && event.data.before);
    const after = dataOf(event.data && event.data.after);
    if (!(await firstDelivery(fid, event.id))) return { duplicate: true };
    const c = P.classifyLine(before, after);
    if (!c.added && !c.ticked) return { queued: false };
    const actor = actorUid(event, before, after);
    const item = c.added
      ? { type: 'added', name: c.added, actorUid: actor, lineId: event.params.lineId }
      : { type: 'ticked', actorUid: actor, lineId: event.params.lineId };
    await bucketAdd(fid, `list_${listId}`, 'lists', [item]);
    return { queued: true };
  }

  /** Task-queue flush of a debounce bucket ({familyId, bucket}). */
  async function flushBucket(data) {
    const fid = data.familyId;
    const ref = db.doc(`${famPath(fid)}/pushQueue/${safeId(data.bucket)}`);
    const bucket = await db.runTransaction(async (tx) => {
      const cur = dataOf(await tx.get(ref));
      if (!P.bucketDue(cur, now())) return null;
      tx.delete(ref);
      return cur;
    });
    if (!bucket) return { flushed: false };
    const family = await loadFamily(fid);
    if (!family) return { flushed: false };
    const aud = await loadAudience(fid, family);
    if (bucket.kind === 'chores') await flushChores(fid, family, aud, bucket.items);
    else await flushList(fid, family, aud, String(data.bucket).replace(/^list_/, ''), bucket.items);
    return { flushed: true };
  }

  async function flushChores(fid, family, aud, items) {
    const kitchen = dataOf(await db.doc(`${famPath(fid)}/settings/kitchen`).get()) || {};
    const stars = kitchen.starsMap || {};
    const per = new Map();
    for (const item of items) {
      const recips = P.selectRecipients(
        family,
        { type: 'chores', event: 'done', ctx: { subjects: item.memberIds }, excludeUids: [item.actorUid] },
        prefsMap(aud),
      );
      const kidIds = item.memberIds.filter((id) => P.memberById(family, id));
      const view = {
        kid: P.joinNames(kidIds.map((id) => P.nameOf(P.memberById(family, id)))) || 'Someone',
        chore: item.title,
        eventId: item.eventId,
        stars: Number(stars[kidIds[0]] || 0),
      };
      for (const r of recips) {
        if (!per.has(r.uid)) per.set(r.uid, { r, items: [] });
        per.get(r.uid).items.push(view);
      }
    }
    for (const { r, items: mine } of per.values()) await deliver(fid, aud, r, P.choreNotification(mine));
  }

  async function flushList(fid, family, aud, listId, items) {
    const listPath = `${famPath(fid)}/notes/${listId}`;
    const list = dataOf(await db.doc(listPath).get());
    if (!list) return;
    const lines = (await db.collection(`${listPath}/lines`).get()).docs.map((d) => d.data());
    const participants = [list.createdBy];
    for (const l of lines) participants.push(l.addedBy, l.assignee, l.createdBy, l.completedBy);
    const ctx = { listType: list.type, participants: participants.filter(Boolean).map(String) };
    const name = list.name || 'A list';
    const base = { list: name, listId, listType: list.type };
    const who = (uids) => P.joinNames(uids.map((u) => P.nameOf(P.resolveActor(family, u))));

    const ticks = items.filter((i) => i.type === 'ticked');
    const finished = ticks.length > 0 && lines.length > 0 && lines.every(P.lineDone);
    const handled = new Set();
    if (finished) {
      const last = ticks[ticks.length - 1].actorUid;
      const done = await fanOut(fid, family, aud, { type: 'lists', event: 'finished', ctx, excludeUids: [last] }, () =>
        P.listFinished({ ...base, who: who([last]) }));
      done.forEach((u) => handled.add(u));
    }
    const adds = items.filter((i) => i.type === 'added');
    if (!adds.length) return;
    await fanOut(fid, family, aud, { type: 'lists', event: 'added', ctx }, (r) => {
      if (handled.has(r.uid)) return null;
      const mine = adds.filter((a) => a.actorUid !== r.uid);
      if (!mine.length) return null;
      return P.itemsAdded({ ...base, who: who(mine.map((a) => a.actorUid)), items: mine.map((a) => a.name) });
    });
  }

  /** Finance data for month `ym` → projected items, open balance, blocks, accounts. */
  async function loadMonth(fid, ym) {
    const fin = `${famPath(fid)}/finance/main`;
    const [monthsSnap, entries, occ, anchors, blocksSnap, accountsSnap] = await Promise.all([
      db.collection(`${fin}/months`).get(),
      db.collection(`${fin}/months/${ym}/entries`).get(),
      db.collection(`${fin}/months/${ym}/recurring`).get(),
      db.collection(`${fin}/recurring`).get(),
      db.collection(`${fin}/blocks`).get(),
      db.collection(`${fin}/accounts`).get(),
    ]);
    const months = Object.fromEntries(monthsSnap.docs.map((d) => [d.id, d.data()]));
    const withId = (snap) => snap.docs.map((d) => ({ ...d.data(), id: d.id }));
    const items = P.monthItems({
      ym,
      month: months[ym] || {},
      months,
      entries: withId(entries),
      occurrences: withId(occ),
      anchors: withId(anchors),
    });
    const blocks = Object.fromEntries(blocksSnap.docs.map((d) => [d.id, d.data()]));
    const accounts = Object.fromEntries(accountsSnap.docs.map((d) => [d.id, d.data()]));
    return { items, open: (months[ym] || {}).open || 0, blocks, accounts };
  }

  const accountName = (accounts, key) => (accounts[key] && (accounts[key].name || accounts[key].short)) || key || '';
  const moneySubjects = (it) => [it.createdBy, it.account].filter(Boolean).map(String);

  function paidSpec(it, { date, balance, accounts }) {
    const base = { entryId: it.id, amount: it.amount, account: accountName(accounts, it.account), balance, date };
    const name = it.payee || it.label || 'Entry';
    return it.income ? P.received({ ...base, source: name }) : P.paidOut({ ...base, payee: name });
  }

  /**
   * finance/main/months/{month}/entries/{id} (source 'entries'),
   * finance/main/months/{month}/recurring/{id} ('occurrence'),
   * finance/main/recurring/{id} ('series').
   */
  async function onMoneyEntry(event, source = 'entries') {
    const fid = event.params.fid;
    const before = dataOf(event.data && event.data.before);
    const after = dataOf(event.data && event.data.after);
    if (!(await firstDelivery(fid, event.id))) return { duplicate: true };
    const c = P.classifyEntry(before, after, { stored: source === 'occurrence' });
    if (!c) return { kind: null };
    const rec = after || before;
    const ym = event.params.month || rec._month;
    if (!ym) return { kind: null };
    const itemId = event.params.itemId || rec.id;
    const family = await loadFamily(fid);
    if (!family) return { kind: null };
    const actor = actorUid(event, before, after);
    const aud = await loadAudience(fid, family);
    const fin = `${famPath(fid)}/finance/main`;
    const [blockSnap, accSnap] = await Promise.all([
      db.doc(`${fin}/blocks/${safeId(rec._block || '_')}`).get(),
      db.doc(`${fin}/accounts/${safeId(rec.account || '_')}`).get(),
    ]);
    const block = dataOf(blockSnap) || {};
    const accounts = { [rec.account]: dataOf(accSnap) || {} };
    const income = block.isIncome === true;
    const date = P.itemDate(rec, ym) || `${ym}-01`;
    const who = P.nameOf(P.resolveActor(family, actor));
    const ctx = { subjects: moneySubjects(rec) };
    const payee = rec.payee || rec.label || '';

    if (c.kind === 'paid') {
      const markerRef = db.doc(`${famPath(fid)}/pushMoney/${P.moneyMarkerId(ym, itemId)}`);
      const already = await db.runTransaction(async (tx) => {
        const m = dataOf(await tx.get(markerRef));
        if (m && m.paidSentAt) return null;
        tx.set(markerRef, { ...(m || {}), paidSentAt: now(), expireAt: new Date(now() + MARKER_TTL_MS) });
        return (m && m.scheduledUids) || [];
      });
      if (!already) return { kind: 'paid', duplicate: true };
      const month = await loadMonth(fid, ym);
      const { balance } = P.moneyDay(month.items, { date, open: month.open, blocks: month.blocks });
      const it = { ...rec, id: itemId, income };
      await fanOut(
        fid, family, aud,
        { type: 'money', event: income ? 'received' : 'paid', ctx, excludeUids: [actor, ...already] },
        () => paidSpec(it, { date, balance, accounts: month.accounts }),
      );
      return { kind: 'paid' };
    }

    const select = (evt) => ({ type: 'money', event: evt, ctx, excludeUids: [actor] });
    const account = accountName(accounts, rec.account);
    const category = block.title || '';
    if (c.kind === 'added') {
      let bundle = null;
      if (!income && actor) {
        const ref = db.doc(`${famPath(fid)}/pushQueue/${safeId(`money_${actor}`)}`);
        bundle = await db.runTransaction(async (tx) => {
          const next = P.trackMoneyAdd(dataOf(await tx.get(ref)), { amount: Number(rec.amount) || 0, payee }, now());
          tx.set(ref, { ...next.state, expireAt: new Date(now() + DAY_MS) });
          return next.bundle;
        });
      }
      const s = bundle
        ? P.moneyBundle({ who, actorKey: actor, amounts: bundle.map((b) => b.amount), payees: bundle.map((b) => b.payee), date })
        : P.moneyAdded({ who, entryId: itemId, income, amount: rec.amount, category, payee, account, date });
      await fanOut(fid, family, aud, select('added'), () => s);
      return { kind: bundle ? 'bundle' : 'added' };
    }
    if (c.kind === 'edited') {
      await fanOut(fid, family, aud, select('edited'), () =>
        P.moneyEdited({ who, entryId: itemId, payee, account, oldAmount: before.amount, newAmount: after.amount, date }));
      return { kind: 'edited' };
    }
    await fanOut(fid, family, aud, select('edited'), () =>
      P.moneyRemoved({ who, entryId: itemId, payee, amount: rec.amount, category, account, date }));
    return { kind: 'removed' };
  }

  /** settings/kitchen: a kid's star bar reset from 5 to 0 = reward claimed. */
  async function onKitchen(event) {
    const fid = event.params.fid;
    const before = dataOf(event.data && event.data.before);
    const after = dataOf(event.data && event.data.after);
    if (!(await firstDelivery(fid, event.id))) return { duplicate: true };
    const claims = P.rewardClaims(before, after);
    if (!claims.length) return { claims: 0 };
    const family = await loadFamily(fid);
    if (!family) return { claims: 0 };
    const actor = actorUid(event, before, after);
    const aud = await loadAudience(fid, family);
    for (const c of claims) {
      const claimId = String(now());
      const kid = P.memberById(family, c.memberId);
      await db.doc(`${famPath(fid)}/rewardClaims/${safeId(c.memberId)}`).set({
        memberId: c.memberId,
        claimId,
        cost: c.cost,
        claimedAt: now(),
        claimedBy: actor || null,
        approvedBy: null,
        approvedAt: null,
      });
      await fanOut(
        fid, family, aud,
        { type: 'chores', event: 'reward', ctx: { subjects: [c.memberId] }, excludeUids: [actor, kid && kid.uid] },
        () => P.rewardClaimed({ kid: P.nameOf(kid), memberId: c.memberId, familyId: fid, cost: c.cost, left: 0, claimId }),
      );
    }
    return { claims: claims.length };
  }

  /** families/{fid}: members joined / left or removed / role changed. */
  async function onFamily(event) {
    const fid = event.params.fid;
    const before = dataOf(event.data && event.data.before);
    const after = dataOf(event.data && event.data.after);
    if (!(await firstDelivery(fid, event.id))) return { duplicate: true };
    const changes = P.classifyFamily(before, after);
    if (!changes.length) return { changes: [] };
    const actor = actorUid(event, before, after);
    const aud = await loadAudience(fid, after);
    const actorRow = P.resolveActor(after, actor) || P.resolveActor(before, actor);
    for (const c of changes) {
      const m = c.member;
      const self = !!actor && (actor === m.uid || (actorRow && actorRow.id === m.id));
      const actorName = !self && actorRow ? P.nameOf(actorRow) : null;
      if (c.kind === 'joined') {
        const who = actorName || m.kidSetBy || m.linkedBy || null;
        await fanOut(fid, after, aud, { type: 'family', event: 'joined', excludeUids: [actor, m.uid] }, () =>
          P.memberJoined({ name: P.nameOf(m), family: after.name || 'Thrive', role: c.role, who, memberId: m.id }));
      } else if (c.kind === 'left') {
        await fanOut(fid, after, aud, { type: 'family', event: 'left', excludeUids: [actor, m.uid] }, () =>
          P.memberLeft({ name: P.nameOf(m), memberId: m.id, who: actorName }));
      } else {
        const who = actorName || (m.accessChange && m.accessChange.by) || m.kidSetBy || 'an admin';
        await fanOut(
          fid, after, aud,
          { type: 'family', event: 'role', excludeUids: [actor], includeUids: [m.uid] },
          () => P.roleChanged({ name: P.nameOf(m), role: c.role, who, memberId: m.id }),
        );
      }
    }
    return { changes: changes.map((c) => c.kind) };
  }

  // ----------------------------------------------------------- schedules

  /** Hourly: "Paid out"/"Received" for users whose local time is 09:xx. */
  async function runMoneyDay() {
    const families = await db.collection('families').get();
    let sent = 0;
    for (const doc of families.docs) {
      const fid = doc.id;
      const family = doc.data();
      const aud = await loadAudience(fid, family);
      const byDate = new Map();
      for (const [uid, a] of Object.entries(aud)) {
        const lp = P.localParts(now(), a.tz);
        if (lp.hour !== P.MONEY_DAY_HOUR) continue;
        if (!byDate.has(lp.date)) byDate.set(lp.date, new Set());
        byDate.get(lp.date).add(uid);
      }
      for (const [date, uids] of byDate) {
        const month = await loadMonth(fid, date.slice(0, 7));
        const { due, balance } = P.moneyDay(month.items, { date, open: month.open, blocks: month.blocks });
        for (const it of due) {
          if (it.paid === true) continue;
          const markerRef = db.doc(`${famPath(fid)}/pushMoney/${P.moneyMarkerId(date.slice(0, 7), it.id)}`);
          const marker = dataOf(await markerRef.get());
          const notified = [];
          await fanOut(
            fid, family, aud,
            { type: 'money', event: it.income ? 'received' : 'paid', ctx: { subjects: moneySubjects(it) } },
            (r) => {
              if (!uids.has(r.uid) || !P.moneyDayPending(it, marker, r.uid)) return null;
              notified.push(r.uid);
              return paidSpec(it, { date, balance, accounts: month.accounts });
            },
          );
          if (!notified.length) continue;
          sent += notified.length;
          await db.runTransaction(async (tx) => {
            const m = dataOf(await tx.get(markerRef)) || {};
            const scheduledUids = [...new Set([...(m.scheduledUids || []), ...notified])];
            tx.set(markerRef, { ...m, scheduledUids, expireAt: new Date(now() + MARKER_TTL_MS) });
          });
        }
      }
    }
    return { sent };
  }

  /** Every 15 min: one family_digest per user whose quiet hours are over. */
  async function runQuietDigest() {
    const held = await db.collectionGroup('pushHeld').get();
    const byUid = new Map();
    for (const d of held.docs) {
      const uid = d.ref.path.split('/')[1];
      if (!byUid.has(uid)) byUid.set(uid, []);
      byUid.get(uid).push(d);
    }
    let digests = 0;
    for (const [uid, docs] of byUid) {
      const fids = [...new Set(docs.map((d) => d.data().familyId).filter(Boolean))];
      const devices = [];
      const seen = new Set();
      for (const fid of fids) {
        for (const dv of await devicesOf(fid, uid)) {
          if (seen.has(dv.token)) continue;
          seen.add(dv.token);
          devices.push(dv);
        }
      }
      const user = dataOf(await db.doc(`users/${uid}`).get()) || {};
      const prefs = P.resolvePrefs(user.notifPrefs);
      if (P.inQuietHours(prefs.quiet, now(), P.userTimezone(devices))) continue;
      const summary = P.digest(docs.map((d) => d.data().spec));
      if (summary) {
        await sendToDevices(devices, summary);
        digests += 1;
      }
      for (const d of docs) await d.ref.delete();
    }
    return { digests };
  }

  async function sendTestPush(request) {
    const uid = L.requireAuth(request.auth);
    const fid = L.requireString((request.data || {}).familyId, 'familyId');
    const family = await loadFamily(fid);
    if (!family || !P.audienceMembers(family).some((m) => m.uid === uid)) {
      throw new HttpsError('permission-denied', 'Family membership required.');
    }
    const throttle = db.doc(`${famPath(fid)}/pushQueue/test_${safeId(uid)}`);
    await db.runTransaction(async (tx) => {
      const previous = dataOf(await tx.get(throttle));
      if (previous && now() - previous.lastAt < 30_000) {
        throw new HttpsError('resource-exhausted', 'Wait before sending another test.');
      }
      tx.set(throttle, { lastAt: now(), expireAt: new Date(now() + DAY_MS) });
    });
    const devices = await devicesOf(fid, uid);
    const sent = await sendToDevices(devices, {
      title: 'Thrive test notification', body: 'Notifications work on this phone.',
      channel: 'family_members', tag: `test_${uid}_${now()}`, link: '',
    });
    return { sent };
  }

  // ------------------------------------------------------------ callable

  /** Approve a reward claim (#474). Any adult (non-kid) family member. */
  async function approveReward(request) {
    const uid = L.requireAuth(request.auth);
    const data = request.data || {};
    const familyId = L.requireString(data.familyId, 'familyId');
    const memberId = L.requireString(data.memberId, 'memberId');
    const claimId = data.claimId ? String(data.claimId) : null;
    const family = L.assertFamily(await loadFamily(familyId));
    const caller = P.resolveActor(family, uid);
    const isMember = (family.memberUids || []).includes(uid) || !!(caller && caller.uid === uid);
    if (!isMember || !caller || P.isKidMember(family, caller)) {
      throw new HttpsError('permission-denied', 'Only grown-ups in the family can approve rewards.');
    }
    L.findMember(family, memberId);
    const ref = db.doc(`${famPath(familyId)}/rewardClaims/${safeId(memberId)}`);
    return db.runTransaction(async (tx) => {
      const cur = dataOf(await tx.get(ref)) || {};
      if (cur.approvedAt && (!claimId || cur.claimId === claimId)) return { ok: true };
      tx.set(ref, {
        ...cur,
        memberId,
        ...(claimId ? { claimId } : {}),
        approvedBy: uid,
        approvedAt: now(),
      });
      return { ok: true };
    });
  }

  return {
    onCalendarEvent,
    onCalendarImport,
    onDeviceWrite,
    refreshFamilyReminders,
    runDueReminders,
    refreshReminders,
    onListLine,
    flushBucket,
    onMoneyEntry,
    onKitchen,
    onFamily,
    runMoneyDay,
    runQuietDigest,
    approveReward,
    sendTestPush,
    // exposed for tests
    deliver,
    loadMonth,
  };
}

module.exports = { createPushHandlers };
