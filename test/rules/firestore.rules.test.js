// Firestore security rules tests for firestore.rules.
// Run via `npm test` in test/rules/ (wraps `firebase emulators:exec`).

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc,
  collection, getDocs, query, where,
} from 'firebase/firestore';

const __dir = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(join(__dir, '../../firestore.rules'), 'utf8');

const OWNER = 'owner-uid';
const MEMBER = 'member-uid';
const OTHER = 'other-uid';
const JOINER = 'joiner-uid';
// Signed in, but never added to the allowlist.
const STRANGER = 'stranger-uid';
const FAM = 'fam1';
const ALLOWLISTED = [OWNER, MEMBER, OTHER, JOINER];
const emailOf = (uid) => `${uid}@Example.com`;

const baseFamily = {
  ownerUid: OWNER,
  memberUids: [OWNER, MEMBER],
  members: [
    { uid: OWNER, name: 'Owner' },
    { uid: MEMBER, name: 'Member' },
  ],
  name: 'The Family',
  picture: 'pic.png',
  username: 'thefam',
  joinHash: 'hash-abc',
  joinSalt: 'salt',
  workspace: { lists: [] },
};

let env;

// Every signed-in context carries a verified email (`<uid>@Example.com`,
// mixed case to prove the rules lower-case it) unless [token] overrides it.
function db(uid, token = {}) {
  return (uid
    ? env.authenticatedContext(uid,
      { email: emailOf(uid), email_verified: true, ...token })
    : env.unauthenticatedContext()
  ).firestore();
}
const famRef = (d, id = FAM) => doc(d, 'families', id);

async function allow(email, data = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'allowlist', email.toLowerCase()), data);
  });
}

async function seed(data = baseFamily, id = FAM) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'families', id), data);
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-thrive',
    firestore: { rules },
  });
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await seed();
  for (const uid of ALLOWLISTED) await allow(emailOf(uid));
});

describe('family doc reads', () => {
  it('member can read', async () => {
    await assertSucceeds(getDoc(famRef(db(MEMBER))));
  });
  it('owner can read', async () => {
    await assertSucceeds(getDoc(famRef(db(OWNER))));
  });
  it('non-member cannot read', async () => {
    await assertFails(getDoc(famRef(db(OTHER))));
  });
  it('unauthenticated cannot read', async () => {
    await assertFails(getDoc(famRef(db(null))));
  });
});

describe('non-owner member restrictions', () => {
  it('cannot change joinHash', async () => {
    await assertFails(updateDoc(famRef(db(MEMBER)), { joinHash: 'evil' }));
  });
  it('cannot remove another uid from memberUids', async () => {
    await assertFails(updateDoc(famRef(db(MEMBER)), { memberUids: [MEMBER] }));
  });
  it('cannot change ownerUid', async () => {
    await assertFails(updateDoc(famRef(db(MEMBER)), { ownerUid: MEMBER }));
  });
  it('cannot delete the family', async () => {
    await assertFails(deleteDoc(famRef(db(MEMBER))));
  });
});

describe('non-owner member allowed writes', () => {
  it('can update name, picture, members, workspace', async () => {
    await assertSucceeds(updateDoc(famRef(db(MEMBER)), {
      name: 'New Name',
      picture: 'new.png',
      members: [...baseFamily.members, { uid: MEMBER, name: 'Renamed' }],
      workspace: { lists: [1] },
    }));
  });
  it('can remove exactly themselves from memberUids', async () => {
    await assertSucceeds(updateDoc(famRef(db(MEMBER)), {
      memberUids: [OWNER],
      members: [{ uid: OWNER, name: 'Owner' }],
    }));
  });
  it('self-removal branch cannot smuggle a joinHash change', async () => {
    await assertFails(updateDoc(famRef(db(MEMBER)), {
      memberUids: [OWNER],
      joinHash: 'evil',
    }));
  });
});

describe('owner powers', () => {
  it('can rotate joinHash', async () => {
    await assertSucceeds(updateDoc(famRef(db(OWNER)), { joinHash: 'new-hash' }));
  });
  it('can remove members', async () => {
    await assertSucceeds(updateDoc(famRef(db(OWNER)), {
      memberUids: [OWNER],
      members: [{ uid: OWNER, name: 'Owner' }],
    }));
  });
  it('cannot change username on the family doc', async () => {
    await assertFails(updateDoc(famRef(db(OWNER)), { username: 'newname' }));
  });
  it('can delete the family', async () => {
    await assertSucceeds(deleteDoc(famRef(db(OWNER))));
  });
});

describe('owner handoff', () => {
  it('owner can hand off to an existing member while leaving', async () => {
    await assertSucceeds(updateDoc(famRef(db(OWNER)), {
      ownerUid: MEMBER,
      memberUids: [MEMBER],
      members: [{ uid: MEMBER, name: 'Member' }],
    }));
  });
  it('handoff fails if owner stays in memberUids', async () => {
    await assertFails(updateDoc(famRef(db(OWNER)), {
      ownerUid: MEMBER,
      memberUids: [OWNER, MEMBER],
    }));
  });
  it('handoff fails to a non-member target', async () => {
    await assertFails(updateDoc(famRef(db(OWNER)), {
      ownerUid: OTHER,
      memberUids: [MEMBER, OTHER],
    }));
  });
  it('non-owner cannot perform a handoff', async () => {
    await assertFails(updateDoc(famRef(db(MEMBER)), {
      ownerUid: MEMBER,
      memberUids: [MEMBER],
    }));
  });
});

describe('password-verified self-join', () => {
  it('succeeds with correct joinProof appending only own uid', async () => {
    await assertSucceeds(updateDoc(famRef(db(JOINER)), {
      joinProof: 'hash-abc',
      memberUids: [OWNER, MEMBER, JOINER],
    }));
  });
  it('legacy client may also append exactly one members row', async () => {
    await assertSucceeds(updateDoc(famRef(db(JOINER)), {
      joinProof: 'hash-abc',
      memberUids: [OWNER, MEMBER, JOINER],
      members: [...baseFamily.members, { uid: JOINER, name: 'Joiner' }],
    }));
  });
  it('fails with wrong proof', async () => {
    await assertFails(updateDoc(famRef(db(JOINER)), {
      joinProof: 'wrong',
      memberUids: [OWNER, MEMBER, JOINER],
    }));
  });
  it('fails if it also changes joinHash', async () => {
    await assertFails(updateDoc(famRef(db(JOINER)), {
      joinProof: 'hash-abc',
      joinHash: 'evil',
      memberUids: [OWNER, MEMBER, JOINER],
    }));
  });
  it('fails if it appends someone else\'s uid too', async () => {
    await assertFails(updateDoc(famRef(db(JOINER)), {
      joinProof: 'hash-abc',
      memberUids: [OWNER, MEMBER, JOINER, OTHER],
    }));
  });
  it('fails if it appends only someone else\'s uid', async () => {
    await assertFails(updateDoc(famRef(db(JOINER)), {
      joinProof: 'hash-abc',
      memberUids: [OWNER, MEMBER, OTHER],
    }));
  });
  it('fails if it drops an existing member while joining', async () => {
    await assertFails(updateDoc(famRef(db(JOINER)), {
      joinProof: 'hash-abc',
      memberUids: [OWNER, JOINER],
    }));
  });
  it('fails if members grows by more than one', async () => {
    await assertFails(updateDoc(famRef(db(JOINER)), {
      joinProof: 'hash-abc',
      memberUids: [OWNER, MEMBER, JOINER],
      members: [
        ...baseFamily.members,
        { uid: JOINER, name: 'Joiner' },
        { uid: OTHER, name: 'Sneaky' },
      ],
    }));
  });
  it('fails if it touches ownerUid or username', async () => {
    await assertFails(updateDoc(famRef(db(JOINER)), {
      joinProof: 'hash-abc',
      memberUids: [OWNER, MEMBER, JOINER],
      ownerUid: JOINER,
    }));
    await assertFails(updateDoc(famRef(db(JOINER)), {
      joinProof: 'hash-abc',
      memberUids: [OWNER, MEMBER, JOINER],
      username: 'stolen',
    }));
  });
});

describe('family creation', () => {
  it('creator must be owner and member of the new family', async () => {
    await assertSucceeds(setDoc(doc(db(OTHER), 'families', 'fam2'), {
      ...baseFamily, ownerUid: OTHER, memberUids: [OTHER], username: 'fam2',
    }));
  });
  it('cannot create a family owned by someone else', async () => {
    await assertFails(setDoc(doc(db(OTHER), 'families', 'fam3'), {
      ...baseFamily, ownerUid: OWNER, memberUids: [OTHER], username: 'fam3',
    }));
  });
});

// Record docs below the family doc, one per layout shape.
const RECORD_PATHS = [
  'settings/kitchen',
  'finance/main',
  'finance/main/accounts/shared',
  'finance/main/blocks/home',
  'finance/main/recurring/rent',
  'finance/main/months/2026-05',
  'finance/main/months/2026-05/entries/a',
  'finance/main/months/2026-05/recurring/rent',
  'calendar/main',
  'calendar/main/layers/l1',
  'calendar/main/categories/c1',
  'calendar/main/imports/i1',
  'calendar/main/recurring/ev1',
  'calendar/main/months/2026-05',
  'calendar/main/months/2026-05/events/ev2',
  'meals/2026',
  'meals/2026/months/05',
  'meals/2026/months/05/days/04',
  'notes/l1',
  'notes/l1/lines/t1',
  'cards/k1',
];
const recRef = (d, path, fam = FAM) =>
  doc(d, 'families', fam, ...path.split('/'));

describe('family records', () => {
  for (const path of RECORD_PATHS) {
    it(`${path}: members only, stamped with familyId`, async () => {
      await assertSucceeds(setDoc(recRef(db(MEMBER), path),
        { familyId: FAM, label: 'x' }));
      await assertSucceeds(updateDoc(recRef(db(OWNER), path), { paid: true }));
      await assertSucceeds(getDoc(recRef(db(MEMBER), path)));
      await assertFails(getDoc(recRef(db(OTHER), path)));
      await assertFails(getDoc(recRef(db(null), path)));
      await assertFails(setDoc(recRef(db(OTHER), path),
        { familyId: FAM, label: 'hacked' }));
      await assertSucceeds(deleteDoc(recRef(db(MEMBER), path)));
    });
  }
  it('rejects writes without (or with another) familyId', async () => {
    await assertFails(setDoc(recRef(db(MEMBER), 'cards/k2'), { label: 'x' }));
    await assertFails(setDoc(recRef(db(MEMBER), 'cards/k2'),
      { familyId: 'fam2', label: 'x' }));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(recRef(ctx.firestore(), 'cards/k3'), { familyId: FAM });
    });
    await assertFails(updateDoc(recRef(db(MEMBER), 'cards/k3'),
      { familyId: 'fam2' }));
  });
  it('outdated app versions cannot write the old flat layout', async () => {
    await assertFails(setDoc(recRef(db(MEMBER), 'workspace/settings'),
      { accounts: [] }));
    await assertFails(setDoc(recRef(db(MEMBER), 'budgetItems/2026_Mei_a'),
      { label: 'x' }));
  });
  it('members may delete leftover legacy docs', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(recRef(ctx.firestore(), 'workspace/settings'), { a: 1 });
    });
    await assertSucceeds(deleteDoc(recRef(db(MEMBER), 'workspace/settings')));
  });
});

describe('collection-group record queries', () => {
  beforeEach(async () => {
    await seed({ ...baseFamily, memberUids: [OTHER], ownerUid: OTHER }, 'fam2');
    await env.withSecurityRulesDisabled(async (ctx) => {
      const f = ctx.firestore();
      await setDoc(recRef(f, 'finance/main/recurring/rent'), { familyId: FAM });
      await setDoc(recRef(f, 'calendar/main/recurring/ev1'), { familyId: FAM });
      await setDoc(recRef(f, 'meals/2026/months/05/days/04'), { familyId: FAM });
      await setDoc(recRef(f, 'cards/x', 'fam2'), { familyId: 'fam2' });
    });
  });
  const q = async (d, col, fam) => {
    const { collectionGroup, query, where, getDocs } =
      await import('firebase/firestore');
    return getDocs(query(collectionGroup(d, col), where('familyId', '==', fam)));
  };
  it('a member can load a collection id across the hierarchy', async () => {
    const snap = await assertSucceeds(q(db(MEMBER), 'recurring', FAM));
    if (snap.size !== 2) throw new Error(`expected 2, got ${snap.size}`);
    await assertSucceeds(q(db(OWNER), 'days', FAM));
  });
  it('cannot query another family', async () => {
    await assertFails(q(db(MEMBER), 'cards', 'fam2'));
    await assertFails(q(db(OTHER), 'recurring', FAM));
    await assertFails(q(db(null), 'recurring', FAM));
  });
  it('an unfiltered collection-group query is rejected', async () => {
    const { collectionGroup, getDocs } = await import('firebase/firestore');
    await assertFails(getDocs(collectionGroup(db(MEMBER), 'cards')));
  });
});

describe('record version (_v)', () => {
  for (const path of ['calendar/main/recurring/ev_v',
    'finance/main/months/2026-05/entries/v', 'notes/l1/lines/v',
    'meals/2026/months/05/days/11', 'settings/kitchen']) {
    it(`${path}: creates at 1 (or no version)`, async () => {
      const { increment } = await import('firebase/firestore');
      const r = (suffix) => recRef(db(MEMBER), path + suffix);
      await assertSucceeds(setDoc(r(''),
        { familyId: FAM, title: 'a', _v: increment(1) }, { merge: true }));
      await assertSucceeds(setDoc(r('_legacy'), { familyId: FAM, title: 'a' }));
      await assertFails(setDoc(r('_skip'), { familyId: FAM, title: 'a', _v: 5 }));
      await assertFails(setDoc(r('_str'), { familyId: FAM, title: 'a', _v: '1' }));
    });
    it(`${path}: each save bumps by exactly 1 or keeps it`, async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(recRef(ctx.firestore(), path),
          { familyId: FAM, title: 'a', _v: 3 });
      });
      const r = recRef(db(MEMBER), path);
      await assertSucceeds(updateDoc(r, { title: 'b', _v: 4 }));
      // An app version that doesn't track versions leaves it unchanged.
      await assertSucceeds(updateDoc(r, { title: 'c' }));
      await assertFails(updateDoc(r, { title: 'd', _v: 3 }));
      await assertFails(updateDoc(r, { title: 'd', _v: 6 }));
      await assertSucceeds(deleteDoc(r));
    });
  }
});

describe('family_handles', () => {
  it('owner can create a handle matching the family username', async () => {
    await assertSucceeds(setDoc(doc(db(OWNER), 'family_handles', 'thefam'), {
      familyId: FAM, joinSalt: 'salt',
    }));
  });
  it('create fails when handle id mismatches the family username', async () => {
    await assertFails(setDoc(doc(db(OWNER), 'family_handles', 'othername'), {
      familyId: FAM,
    }));
  });
  it('non-owner cannot create the handle', async () => {
    await assertFails(setDoc(doc(db(MEMBER), 'family_handles', 'thefam'), {
      familyId: FAM,
    }));
  });
  it('an allowlisted user can get a known handle; others cannot', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'family_handles', 'thefam'),
        { familyId: FAM });
    });
    await assertSucceeds(getDoc(doc(db(OTHER), 'family_handles', 'thefam')));
    await assertFails(getDoc(doc(db(STRANGER), 'family_handles', 'thefam')));
    await assertFails(getDoc(doc(db(null), 'family_handles', 'thefam')));
  });
  it('create only carries familyId, ownerUid and joinSalt', async () => {
    await assertFails(setDoc(doc(db(OWNER), 'family_handles', 'thefam'), {
      familyId: FAM, joinSalt: 'salt', joinHash: 'leak',
    }));
  });
  it('owner may keep the handle on their family; nobody can retarget it', async () => {
    await seed({ ...baseFamily, ownerUid: OTHER, memberUids: [OTHER],
      username: 'thefam' }, 'fam2');
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'family_handles', 'thefam'),
        { familyId: FAM });
    });
    const h = (d) => doc(d, 'family_handles', 'thefam');
    await assertSucceeds(updateDoc(h(db(OWNER)), { joinSalt: 'new' }));
    // Pointing the handle at someone else's family is a phishing vector.
    await assertFails(updateDoc(h(db(OWNER)), { familyId: 'fam2' }));
    await assertFails(updateDoc(h(db(MEMBER)), { joinSalt: 'evil' }));
    await assertFails(updateDoc(h(db(OTHER)), { familyId: 'fam2' }));
  });
  it('nobody can list (enumerate) the handles collection', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'family_handles', 'thefam'),
        { familyId: FAM, joinSalt: 'salt' });
    });
    await assertFails(getDocs(collection(db(OTHER), 'family_handles')));
    await assertFails(getDocs(collection(db(OWNER), 'family_handles')));
    await assertFails(getDocs(query(collection(db(OTHER), 'family_handles'),
      where('familyId', '==', FAM))));
    await assertFails(getDocs(collection(db(null), 'family_handles')));
  });
  it('owner can delete their handle; non-owner cannot', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'family_handles', 'thefam'),
        { familyId: FAM });
    });
    await assertFails(deleteDoc(doc(db(MEMBER), 'family_handles', 'thefam')));
    await assertSucceeds(deleteDoc(doc(db(OWNER), 'family_handles', 'thefam')));
  });
});

describe('allowlist collection', () => {
  it('a user can get only their own entry', async () => {
    await assertSucceeds(getDoc(doc(db(MEMBER), 'allowlist',
      emailOf(MEMBER).toLowerCase())));
    await assertFails(getDoc(doc(db(MEMBER), 'allowlist',
      emailOf(OWNER).toLowerCase())));
    await assertFails(getDoc(doc(db(null), 'allowlist',
      emailOf(MEMBER).toLowerCase())));
  });
  it('a stranger can look up (the absence of) their own entry', async () => {
    const snap = await assertSucceeds(getDoc(doc(db(STRANGER), 'allowlist',
      emailOf(STRANGER).toLowerCase())));
    if (snap.exists()) throw new Error('stranger should not be allowlisted');
  });
  it('an unverified email cannot read the entry it claims', async () => {
    await assertFails(getDoc(doc(db(MEMBER, { email_verified: false }),
      'allowlist', emailOf(MEMBER).toLowerCase())));
  });
  it('nobody can list it or write it', async () => {
    await assertFails(getDocs(collection(db(OWNER), 'allowlist')));
    for (const uid of [OWNER, MEMBER, STRANGER]) {
      const ref = doc(db(uid), 'allowlist', emailOf(uid).toLowerCase());
      await assertFails(setDoc(ref, { uids: [uid] }));
      await assertFails(deleteDoc(ref));
    }
    await assertFails(setDoc(doc(db(STRANGER), 'allowlist', 'x@example.com'),
      {}));
  });
});

describe('allowlist gates (#465)', () => {
  const newFamily = (uid, id, d = db(uid)) => setDoc(doc(d, 'families', id), {
    ...baseFamily, ownerUid: uid, memberUids: [uid], username: id,
  });
  const join = (d) => updateDoc(famRef(d), {
    joinProof: 'hash-abc',
    memberUids: [OWNER, MEMBER, STRANGER],
  });

  it('a non-allowlisted account cannot sign up (write its user doc)', async () => {
    await assertFails(setDoc(doc(db(STRANGER), 'users', STRANGER),
      { familyIds: [] }));
    await assertFails(setDoc(doc(db(STRANGER), 'users', STRANGER,
      'unsavedChanges', 'c1'), { a: 1 }));
  });
  it('a non-allowlisted account cannot create a family', async () => {
    await assertFails(newFamily(STRANGER, 'famx'));
  });
  it('a non-allowlisted account cannot join, even with the password', async () => {
    await assertFails(join(db(STRANGER)));
    await allow(emailOf(STRANGER));
    await assertSucceeds(join(db(STRANGER)));
  });
  it('an unverified email does not count, unless its uid is pinned', async () => {
    const unverified = db(STRANGER, { email_verified: false });
    await allow(emailOf(STRANGER));
    await assertFails(newFamily(STRANGER, 'famx', unverified));
    await assertFails(setDoc(doc(unverified, 'users', STRANGER), { a: 1 }));
    // Pinning the uid only helps that uid (an existing member's account).
    await allow(emailOf(STRANGER), { uids: [STRANGER] });
    await assertSucceeds(setDoc(doc(unverified, 'users', STRANGER), { a: 1 }));
    await assertSucceeds(newFamily(STRANGER, 'famx', unverified));
    const impostor = env.authenticatedContext('impostor-uid', {
      email: emailOf(STRANGER), email_verified: false,
    }).firestore();
    await assertFails(setDoc(doc(impostor, 'users', 'impostor-uid'),
      { a: 1 }));
  });
  it('a token without an email is never allowlisted', async () => {
    const noEmail = env.authenticatedContext(STRANGER, {}).firestore();
    await assertFails(setDoc(doc(noEmail, 'users', STRANGER), { a: 1 }));
    await assertFails(getDoc(doc(noEmail, 'family_handles', 'thefam')));
  });
  it('existing members keep family access after leaving the allowlist', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(doc(ctx.firestore(), 'allowlist',
        emailOf(MEMBER).toLowerCase()));
    });
    await assertSucceeds(getDoc(famRef(db(MEMBER))));
    await assertSucceeds(updateDoc(famRef(db(MEMBER)), { name: 'Still here' }));
    await assertSucceeds(setDoc(recRef(db(MEMBER), 'cards/k1'),
      { familyId: FAM }));
    // ...and can still read or delete their own user doc.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', MEMBER), { familyIds: [FAM] });
    });
    await assertSucceeds(getDoc(doc(db(MEMBER), 'users', MEMBER)));
    await assertSucceeds(deleteDoc(doc(db(MEMBER), 'users', MEMBER)));
  });
});

describe('users/{uid}', () => {
  const user = (d, uid = MEMBER) => doc(d, 'users', uid);
  it('owner-only read and write', async () => {
    await assertSucceeds(setDoc(user(db(MEMBER)), { familyIds: [FAM] }));
    await assertSucceeds(updateDoc(user(db(MEMBER)), { familyIds: [] }));
    await assertSucceeds(getDoc(user(db(MEMBER))));
    await assertFails(getDoc(user(db(OWNER))));
    await assertFails(setDoc(user(db(OWNER)), { familyIds: ['evil'] }));
    await assertFails(getDoc(user(db(null))));
    await assertFails(getDocs(collection(db(MEMBER), 'users')));
    await assertFails(deleteDoc(user(db(OWNER))));
    await assertSucceeds(deleteDoc(user(db(MEMBER))));
  });
  it('unsavedChanges are owner-only', async () => {
    const c = (d, uid = MEMBER) =>
      doc(d, 'users', uid, 'unsavedChanges', 'c1');
    await assertSucceeds(setDoc(c(db(MEMBER)), { op: 'x' }));
    await assertSucceeds(getDoc(c(db(MEMBER))));
    await assertSucceeds(getDocs(collection(db(MEMBER), 'users', MEMBER,
      'unsavedChanges')));
    await assertFails(getDoc(c(db(OWNER))));
    await assertFails(setDoc(c(db(OWNER)), { op: 'evil' }));
    await assertFails(deleteDoc(c(db(OWNER))));
    await assertSucceeds(deleteDoc(c(db(MEMBER))));
  });
  it('other subcollections of a user doc are closed', async () => {
    await assertFails(setDoc(doc(db(MEMBER), 'users', MEMBER, 'other', 'x'),
      { a: 1 }));
  });
});

describe('user_workspaces (legacy, read/delete-only)', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'user_workspaces', MEMBER),
        { state: {} });
    });
  });
  it('owner can read and delete it, but not write new data', async () => {
    const ref = (d) => doc(d, 'user_workspaces', MEMBER);
    await assertSucceeds(getDoc(ref(db(MEMBER))));
    await assertFails(setDoc(ref(db(MEMBER)), { state: { big: 1 } }));
    await assertFails(setDoc(doc(db(OWNER), 'user_workspaces', OWNER),
      { state: {} }));
    await assertFails(getDoc(ref(db(OWNER))));
    await assertFails(deleteDoc(ref(db(OWNER))));
    await assertSucceeds(deleteDoc(ref(db(MEMBER))));
  });
});

describe('least privilege on family records', () => {
  it('members cannot invent new top-level sections', async () => {
    await assertFails(setDoc(recRef(db(MEMBER), 'dump/a'), { familyId: FAM }));
    await assertFails(setDoc(recRef(db(MEMBER), 'fcmTokens/t1'),
      { familyId: FAM }));
    await assertFails(setDoc(recRef(db(MEMBER), 'alexa/link'),
      { familyId: FAM }));
  });
  it('family create checks the shape', async () => {
    await assertFails(setDoc(doc(db(OTHER), 'families', 'famy'), {
      ownerUid: OTHER, memberUids: [OTHER],
    }));
    await assertFails(setDoc(doc(db(OTHER), 'families', 'famy'), {
      ...baseFamily, ownerUid: OTHER, memberUids: [OTHER], username: 'famy',
      joinHash: 42,
    }));
  });
});

describe('default deny', () => {
  it('unknown top-level collections are closed to everyone', async () => {
    for (const path of ['config/app', 'fcmTokens/t1', 'alexaLinks/l1',
      'pairingCodes/123456', 'anything/else']) {
      const [c, id] = path.split('/');
      await assertFails(setDoc(doc(db(OWNER), c, id), { a: 1 }));
      await assertFails(getDoc(doc(db(OWNER), c, id)));
      await assertFails(getDoc(doc(db(null), c, id)));
    }
  });
});

describe('kid accounts and admins', () => {
  const KID = 'kid-uid';
  const KID_ID = 'kid-member';
  const ADMIN = 'admin-uid';
  const kidFamily = {
    ...baseFamily,
    memberUids: [OWNER, MEMBER, ADMIN, KID],
    adminUids: [ADMIN],
    kidUids: { [KID]: KID_ID },
  };
  beforeEach(async () => {
    await seed(kidFamily);
    await env.withSecurityRulesDisabled(async (ctx) => {
      const f = ctx.firestore();
      await setDoc(recRef(f, 'settings/kitchen'), { familyId: FAM });
      await setDoc(recRef(f, 'calendar/main'), { familyId: FAM });
      await setDoc(recRef(f, 'calendar/main/layers/l1'), { familyId: FAM });
      await setDoc(recRef(f, 'calendar/main/months/2026-05/events/mine'),
        { familyId: FAM, attendees: [KID_ID], createdBy: OWNER });
      await setDoc(recRef(f, 'calendar/main/months/2026-05/events/made'),
        { familyId: FAM, attendees: [], createdBy: KID });
      await setDoc(recRef(f, 'calendar/main/months/2026-05/events/other'),
        { familyId: FAM, attendees: ['m2'], createdBy: OWNER });
      await setDoc(recRef(f, 'calendar/main/recurring/rep'),
        { familyId: FAM, attendees: [KID_ID] });
      await setDoc(recRef(f, 'finance/main/recurring/rent'), { familyId: FAM });
      await setDoc(recRef(f, 'finance/main/accounts/a'), { familyId: FAM });
      await setDoc(recRef(f, 'cards/c'), { familyId: FAM });
      await setDoc(recRef(f, 'meals/2026/months/05/days/04'), { familyId: FAM });
      await setDoc(recRef(f, 'notes/kn'), { familyId: FAM, createdBy: KID });
      await setDoc(recRef(f, 'notes/kn/lines/l'), { familyId: FAM });
      await setDoc(recRef(f, 'notes/on'), { familyId: FAM, createdBy: OWNER });
      await setDoc(recRef(f, 'notes/on/lines/l'), { familyId: FAM });
    });
  });
  const cg = async (d, col, ...filters) => {
    const { collectionGroup } = await import('firebase/firestore');
    return getDocs(query(collectionGroup(d, col),
      where('familyId', '==', FAM), ...filters));
  };

  it('a kid reads the kid-safe docs and only their own events and lists', async () => {
    const k = db(KID);
    for (const p of ['settings/kitchen', 'calendar/main',
      'calendar/main/layers/l1', 'calendar/main/months/2026-05/events/mine',
      'calendar/main/months/2026-05/events/made', 'calendar/main/recurring/rep',
      'meals/2026/months/05/days/04', 'notes/kn', 'notes/kn/lines/l']) {
      await assertSucceeds(getDoc(recRef(k, p)));
    }
    for (const p of ['calendar/main/months/2026-05/events/other',
      'finance/main/recurring/rent', 'finance/main/accounts/a', 'cards/c',
      'notes/on', 'notes/on/lines/l']) {
      await assertFails(getDoc(recRef(k, p)));
    }
  });

  it('a kid can run the scoped collection-group queries only', async () => {
    const k = db(KID);
    for (const col of ['settings', 'calendar', 'layers', 'meals', 'days']) {
      await assertSucceeds(cg(k, col));
    }
    const att = await assertSucceeds(
      cg(k, 'events', where('attendees', 'array-contains', KID_ID)));
    if (att.size !== 1) throw new Error(`expected 1, got ${att.size}`);
    await assertSucceeds(cg(k, 'events', where('createdBy', '==', KID)));
    await assertSucceeds(
      cg(k, 'recurring', where('attendees', 'array-contains', KID_ID)));
    await assertSucceeds(cg(k, 'notes', where('createdBy', '==', KID)));
    await assertSucceeds(getDocs(collection(k, 'families', FAM, 'notes/kn/lines')));
    for (const col of ['events', 'recurring', 'notes', 'accounts', 'cards',
      'months', 'entries', 'lines']) {
      await assertFails(cg(k, col));
    }
    await assertFails(getDocs(collection(k, 'families', FAM, 'notes/on/lines')));
  });

  it('a kid writes only their own events and lists', async () => {
    const k = db(KID);
    await assertSucceeds(setDoc(
      recRef(k, 'calendar/main/months/2026-06/events/new'),
      { familyId: FAM, createdBy: KID, attendees: [] }));
    await assertSucceeds(updateDoc(
      recRef(k, 'calendar/main/months/2026-05/events/mine'), { title: 'x' }));
    await assertFails(updateDoc(
      recRef(k, 'calendar/main/months/2026-05/events/other'), { title: 'x' }));
    // Taking themselves off an event they don't own is not allowed.
    await assertFails(updateDoc(
      recRef(k, 'calendar/main/months/2026-05/events/mine'), { attendees: [] }));
    await assertSucceeds(setDoc(recRef(k, 'notes/new'),
      { familyId: FAM, createdBy: KID }));
    await assertSucceeds(setDoc(recRef(k, 'notes/kn/lines/l2'),
      { familyId: FAM }));
    await assertFails(setDoc(recRef(k, 'notes/on/lines/l2'), { familyId: FAM }));
    await assertFails(setDoc(recRef(k, 'notes/spoof'),
      { familyId: FAM, createdBy: OWNER }));
    await assertFails(updateDoc(recRef(k, 'settings/kitchen'), { a: 1 }));
    await assertFails(setDoc(recRef(k, 'meals/2026/months/05/days/05'),
      { familyId: FAM }));
    await assertFails(setDoc(recRef(k, 'finance/main/accounts/b'),
      { familyId: FAM }));
  });

  it('a kid cannot lift their own restriction or change family settings', async () => {
    const k = famRef(db(KID));
    await assertFails(updateDoc(k, { kidUids: {} }));
    await assertFails(updateDoc(k, { adminUids: [ADMIN, KID] }));
    await assertFails(updateDoc(k, { name: 'Renamed' }));
    await assertSucceeds(updateDoc(k, { members: [] }));
  });

  it('full members still read everything; kids are not admins', async () => {
    await assertSucceeds(getDoc(recRef(db(MEMBER), 'cards/c')));
    await assertSucceeds(cg(db(MEMBER), 'events'));
  });

  it('admins turn kid access on and off; plain members cannot', async () => {
    await assertSucceeds(updateDoc(famRef(db(ADMIN)),
      { kidUids: { [KID]: KID_ID, [MEMBER]: 'm' } }));
    await assertSucceeds(updateDoc(famRef(db(OWNER)), { kidUids: {} }));
    await assertFails(updateDoc(famRef(db(MEMBER)),
      { kidUids: { [KID]: KID_ID } }));
  });

  it('only the owner names admins', async () => {
    await assertSucceeds(updateDoc(famRef(db(OWNER)),
      { adminUids: [ADMIN, MEMBER] }));
    await assertFails(updateDoc(famRef(db(ADMIN)), { adminUids: [] }));
  });

  it('the owner is never a kid and a kid is never an admin', async () => {
    await assertFails(updateDoc(famRef(db(ADMIN)),
      { kidUids: { [KID]: KID_ID, [OWNER]: 'o' } }));
    await assertFails(updateDoc(famRef(db(OWNER)),
      { adminUids: [ADMIN, KID] }));
    await assertFails(updateDoc(famRef(db(ADMIN)),
      { kidUids: { [KID]: KID_ID, [ADMIN]: 'a' } }));
  });

  it('a kid can still leave the family', async () => {
    const { arrayRemove } = await import('firebase/firestore');
    await assertSucceeds(updateDoc(famRef(db(KID)),
      { memberUids: arrayRemove(KID) }));
  });

  it('nobody reads or writes kid_links from the client', async () => {
    await assertFails(getDoc(doc(db(OWNER), 'kid_links', 'a@b.c')));
    await assertFails(setDoc(doc(db(OWNER), 'kid_links', 'a@b.c'), { x: 1 }));
  });
});
