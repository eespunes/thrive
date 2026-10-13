#!/usr/bin/env node
// Manages the family allowlist (`allowlist/{email}` in Firestore, #465).
// Clients can't write it; this script uses the Admin SDK with your own
// Google login (Application Default Credentials), so no service-account key
// is ever created or stored.
//
//   gcloud auth application-default login
//   npm install
//   node allowlist.mjs list
//   node allowlist.mjs add mum@example.com [--note "Mum"]
//   node allowlist.mjs remove kid@example.com
//   node allowlist.mjs seed            # dry run: every current family member
//   node allowlist.mjs seed --apply
//
// Set FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST to run it against
// the emulators instead of production.

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const projectId = process.env.GCLOUD_PROJECT || 'thrive-b1545';
initializeApp({ projectId });
const db = getFirestore();
const auth = getAuth();
const col = db.collection('allowlist');

const [cmd, target, ...rest] = process.argv.slice(2);
const flag = (name) => {
  const i = rest.indexOf(`--${name}`);
  return i === -1 ? undefined : (rest[i + 1] ?? true);
};
const normalise = (email) => String(email ?? '').trim().toLowerCase();

// Existing email/password accounts that never verified their address still
// count when their uid is pinned on the entry (see firestore.rules).
async function entryFor(email) {
  const entry = { email, addedAt: FieldValue.serverTimestamp() };
  try {
    const user = await auth.getUserByEmail(email);
    if (!user.emailVerified) entry.uids = FieldValue.arrayUnion(user.uid);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
  }
  return entry;
}

async function list() {
  const snap = await col.get();
  if (snap.empty) console.log('(allowlist is empty)');
  for (const d of snap.docs) {
    const { note, uids } = d.data();
    console.log([d.id, note && `"${note}"`, uids?.length && `pinned: ${uids}`]
      .filter(Boolean).join('  '));
  }
}

async function add(email, note) {
  if (!email.includes('@')) throw new Error(`Not an email: ${email}`);
  const entry = await entryFor(email);
  if (typeof note === 'string') entry.note = note;
  await col.doc(email).set(entry, { merge: true });
  console.log(`added ${email}`);
}

async function remove(email) {
  await col.doc(email).delete();
  console.log(`removed ${email} (existing family membership is unchanged)`);
}

// Allowlists every member of every family, so turning on the rules locks
// nobody out. Run before deploying the allowlist rules.
async function seed(apply) {
  const uids = new Set();
  for (const f of (await db.collection('families').get()).docs) {
    for (const uid of f.get('memberUids') ?? []) uids.add(uid);
  }
  const emails = new Set();
  for (const uid of uids) {
    try {
      const user = await auth.getUser(uid);
      if (user.email) emails.add(normalise(user.email));
      else console.warn(`! ${uid} has no email; it can't be allowlisted`);
    } catch (e) {
      console.warn(`! ${uid}: ${e.code ?? e.message}`);
    }
  }
  for (const email of [...emails].sort()) {
    if (apply) await add(email);
    else console.log(`would add ${email}`);
  }
  if (!apply) console.log('Dry run. Re-run with --apply to write.');
}

const email = normalise(target);
const commands = {
  list: () => list(),
  add: () => add(email, flag('note')),
  remove: () => remove(email),
  seed: () => seed(target === '--apply'),
};
const run = commands[cmd];
if (!run || (['add', 'remove'].includes(cmd) && !email)) {
  console.error('Usage: node allowlist.mjs list | add <email> [--note <text>]'
    + ' | remove <email> | seed [--apply]');
  process.exit(2);
}
run().catch((e) => {
  console.error(e.message ?? e);
  process.exit(1);
});
