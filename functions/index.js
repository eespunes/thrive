'use strict';

// Callable Cloud Functions that let family admins give a kid profile its own
// login (admin-managed email & password, or a linked Google account) and
// manage it. See README.md. Pure rules: kid_logic.js; Firestore/Auth
// orchestration: handlers.js. This file only wires them to onCall.

const { onCall } = require('firebase-functions/v2/https');
const { createHandlers } = require('./handlers');

const REGION = 'europe-west1';
const CALL_OPTIONS = { region: REGION, enforceAppCheck: false };

let handlers;
function getHandlers() {
  if (!handlers) {
    const { initializeApp, getApps } = require('firebase-admin/app');
    const { getFirestore, FieldValue } = require('firebase-admin/firestore');
    const { getAuth } = require('firebase-admin/auth');
    if (!getApps().length) initializeApp();
    handlers = createHandlers({ db: getFirestore(), auth: getAuth(), FieldValue });
  }
  return handlers;
}

const callable = (name) => onCall(CALL_OPTIONS, (request) => getHandlers()[name](request));

exports.kidCreateEmailLogin = callable('kidCreateEmailLogin');
exports.kidLinkGoogle = callable('kidLinkGoogle');
exports.kidClaimLogin = callable('kidClaimLogin');
exports.kidResetPassword = callable('kidResetPassword');
exports.kidChangeEmail = callable('kidChangeEmail');
exports.kidSignOutEverywhere = callable('kidSignOutEverywhere');
exports.kidRemoveLogin = callable('kidRemoveLogin');
exports.kidLoginDetails = callable('kidLoginDetails');
exports.loginKind = callable('loginKind');

// ---------------------------------------------------------------------------
// Push notifications (epic #469). Pure rules: push_logic.js; orchestration:
// push_handlers.js. See README "Push notifications".

const { onDocumentWrittenWithAuthContext } = require('firebase-functions/v2/firestore');
const { onTaskDispatched } = require('firebase-functions/v2/tasks');
const { onSchedule } = require('firebase-functions/v2/scheduler');

const FLUSH_FUNCTION = 'pushFlush';

let pushHandlers;
function getPushHandlers() {
  if (!pushHandlers) {
    const { initializeApp, getApps } = require('firebase-admin/app');
    const { getFirestore } = require('firebase-admin/firestore');
    const { getMessaging } = require('firebase-admin/messaging');
    const { getFunctions } = require('firebase-admin/functions');
    const { createPushHandlers } = require('./push_handlers');
    if (!getApps().length) initializeApp();
    pushHandlers = createPushHandlers({
      db: getFirestore(),
      messaging: getMessaging(),
      enqueue: (data, opts) =>
        getFunctions().taskQueue(`locations/${REGION}/functions/${FLUSH_FUNCTION}`).enqueue(data, opts),
    });
  }
  return pushHandlers;
}

const onWrite = (document, run) =>
  onDocumentWrittenWithAuthContext({ document, region: REGION }, (event) => run(getPushHandlers(), event));

exports.pushOnCalendarEvent = onWrite('families/{fid}/calendar/main/months/{month}/events/{eventId}', (h, e) => h.onCalendarEvent(e));
exports.pushOnCalendarSeries = onWrite('families/{fid}/calendar/main/recurring/{eventId}', (h, e) => h.onCalendarEvent(e));
exports.pushOnListLine = onWrite('families/{fid}/notes/{listId}/lines/{lineId}', (h, e) => h.onListLine(e));
exports.pushOnMoneyEntry = onWrite('families/{fid}/finance/main/months/{month}/entries/{itemId}', (h, e) => h.onMoneyEntry(e, 'entries'));
exports.pushOnMoneyOccurrence = onWrite('families/{fid}/finance/main/months/{month}/recurring/{itemId}', (h, e) => h.onMoneyEntry(e, 'occurrence'));
exports.pushOnMoneySeries = onWrite('families/{fid}/finance/main/recurring/{itemId}', (h, e) => h.onMoneyEntry(e, 'series'));
exports.pushOnKitchen = onWrite('families/{fid}/settings/kitchen', (h, e) => h.onKitchen(e));
exports.pushOnFamily = onWrite('families/{fid}', (h, e) => h.onFamily(e));

exports[FLUSH_FUNCTION] = onTaskDispatched(
  {
    region: REGION,
    retryConfig: { maxAttempts: 3, minBackoffSeconds: 30 },
    rateLimits: { maxConcurrentDispatches: 20 },
  },
  (req) => getPushHandlers().flushBucket(req.data || {}),
);

exports.pushMoneyDay = onSchedule(
  { schedule: '0 * * * *', region: REGION, timeZone: 'UTC' },
  () => getPushHandlers().runMoneyDay(),
);

exports.pushQuietDigest = onSchedule(
  { schedule: '*/15 * * * *', region: REGION, timeZone: 'UTC' },
  () => getPushHandlers().runQuietDigest(),
);

exports.approveReward = onCall(
  { region: REGION, enforceAppCheck: true },
  (request) => getPushHandlers().approveReward(request),
);
