"use strict";

/**
 * Server-authoritative family credential + join logic for Thrive.
 *
 * Why this exists (security):
 * Family join passwords MUST NOT be verifiable on the client. Firestore
 * security rules cannot hash/compare a password, so if the salted hash were
 * client-readable an attacker could brute-force it offline, and if clients
 * could self-add to `memberUids` they could join any family whose id they
 * learned. These callables move both credential storage and password
 * verification behind the Admin SDK, and the rules deny all client access to
 * the `family_codes` collection.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentDeleted} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const crypto = require("crypto");

// Keep this region in sync with the Flutter client (kFunctionsRegion).
const REGION = "europe-west1";
setGlobalOptions({region: REGION, maxInstances: 10});

initializeApp();
const db = getFirestore();

const FAMILIES = "families";
const FAMILY_CODES = "family_codes";
const USERS = "users";

const USERNAME_RE = /^[a-z0-9][a-z0-9_-]{2,23}$/;

/** Normalizes a handle to the same slug rule the client uses. */
function familySlug(input) {
  return String(input || "")
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 24);
}

/** Salted SHA-256, identical scheme to the client's hashFamilyPassword. */
function hashPassword(password, salt) {
  return crypto
      .createHash("sha256")
      .update(`${salt}::${password}`)
      .digest("hex");
}

function randomSalt() {
  return crypto.randomBytes(16).toString("hex");
}

/** Constant-time string comparison to avoid hash timing leaks. */
function safeEqual(a, b) {
  const ba = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
}

function requireAuth(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to continue.");
  }
  return uid;
}

/**
 * Registers (or rotates) the username + password a family is joined with.
 * Only the family owner may call this. The plaintext password never leaves
 * this function: it is salted and hashed here, and the hash is stored in a
 * collection that is unreadable to clients.
 */
exports.createFamilyCredentials = onCall(async (request) => {
  const uid = requireAuth(request);
  const data = request.data || {};
  const familyId = String(data.familyId || "").trim();
  const slug = familySlug(data.username);
  const password = String(data.password || "");

  if (!familyId) {
    throw new HttpsError("invalid-argument", "Missing family id.");
  }
  if (!USERNAME_RE.test(slug)) {
    throw new HttpsError(
        "invalid-argument",
        "Username: 3–24 letters, numbers, - or _.",
    );
  }
  if (password.length < 4) {
    throw new HttpsError(
        "invalid-argument",
        "Password must be at least 4 characters.",
    );
  }

  const famRef = db.collection(FAMILIES).doc(familyId);
  const codeRef = db.collection(FAMILY_CODES).doc(slug);

  await db.runTransaction(async (tx) => {
    const famSnap = await tx.get(famRef);
    if (!famSnap.exists) {
      throw new HttpsError("not-found", "Family not found.");
    }
    if ((famSnap.get("ownerUid") || "") !== uid) {
      throw new HttpsError(
          "permission-denied",
          "Only the family owner can set join credentials.",
      );
    }
    const codeSnap = await tx.get(codeRef);
    if (codeSnap.exists && (codeSnap.get("familyId") || "") !== familyId) {
      throw new HttpsError(
          "already-exists",
          "That family username is taken.",
      );
    }
    const salt = randomSalt();
    tx.set(codeRef, {
      familyId: familyId,
      passwordHash: hashPassword(password, salt),
      salt: salt,
      ownerUid: uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(famRef, {username: slug}, {merge: true});
  });

  return {username: slug};
});

/**
 * Verifies a family's join password server-side and adds the caller to the
 * family's membership. This is the ONLY supported way to join: rules forbid
 * clients from editing their own membership into a family.
 */
exports.joinFamily = onCall(async (request) => {
  const uid = requireAuth(request);
  const data = request.data || {};
  const slug = familySlug(data.username);
  const password = String(data.password || "");

  if (!slug) {
    throw new HttpsError("invalid-argument", "Enter a family username.");
  }

  const codeSnap = await db.collection(FAMILY_CODES).doc(slug).get();
  if (!codeSnap.exists) {
    throw new HttpsError("not-found", "No family found with that username.");
  }
  const salt = String(codeSnap.get("salt") || "");
  const expected = String(codeSnap.get("passwordHash") || "");
  if (!expected || !safeEqual(hashPassword(password, salt), expected)) {
    throw new HttpsError("permission-denied", "Incorrect password.");
  }

  const familyId = String(codeSnap.get("familyId") || "");
  if (!familyId) {
    throw new HttpsError("not-found", "No family found with that username.");
  }

  const famRef = db.collection(FAMILIES).doc(familyId);
  const result = await db.runTransaction(async (tx) => {
    const famSnap = await tx.get(famRef);
    if (!famSnap.exists) {
      throw new HttpsError("not-found", "That family no longer exists.");
    }
    const memberUids = famSnap.get("memberUids") || [];
    if (Array.isArray(memberUids) && memberUids.includes(uid)) {
      return {familyId: familyId, alreadyMember: true};
    }

    // Build the new member from the caller's own profile (authoritative),
    // falling back to the auth token when no user doc exists yet.
    const userSnap = await tx.get(db.collection(USERS).doc(uid));
    const profile = (userSnap.exists && userSnap.get("profile")) || {};
    const token = request.auth.token || {};
    const name = String(profile.name || token.name || "");
    const email = String(profile.email || token.email || "");
    const initials = String(
        profile.initials || initialsOf(name) || "?",
    );
    const existingCount = Array.isArray(famSnap.get("members")) ?
      famSnap.get("members").length :
      0;

    const member = {
      id: uid,
      uid: uid,
      name: name,
      email: email,
      initials: initials,
      color: MEMBER_COLORS[existingCount % MEMBER_COLORS.length],
      photo: profile.photo || token.picture || null,
      role: "member",
      status: "active",
    };

    tx.update(famRef, {
      memberUids: FieldValue.arrayUnion(uid),
      members: FieldValue.arrayUnion(member),
      updatedAtMillis: Date.now(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {familyId: familyId, alreadyMember: false};
  });

  return result;
});

/**
 * When a family document is deleted, remove every credential mapping that
 * points at it so a stale username can never resolve to a missing family.
 */
exports.onFamilyDeleted = onDocumentDeleted(
    `${FAMILIES}/{familyId}`,
    async (event) => {
      const familyId = event.params.familyId;
      const matches = await db
          .collection(FAMILY_CODES)
          .where("familyId", "==", familyId)
          .get();
      if (matches.empty) return;
      const batch = db.batch();
      matches.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    },
);

// Mirrors the client's kMemberColors palette (ARGB ints) so joined members
// get a color consistent with the rest of the app.
const MEMBER_COLORS = [
  0xff0e9a8d,
  0xff1684b4,
  0xff7c3aed,
  0xffd97706,
  0xffe11d48,
  0xff54a96a,
];

function initialsOf(name) {
  const parts = String(name || "").trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
