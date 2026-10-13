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
