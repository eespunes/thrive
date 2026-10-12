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
const FAM = 'fam1';

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

function db(uid) {
  return (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext())
    .firestore();
}
const famRef = (d, id = FAM) => doc(d, 'families', id);

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
  it('any signed-in user can get a known handle; unauthenticated cannot', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'family_handles', 'thefam'),
        { familyId: FAM });
    });
    await assertSucceeds(getDoc(doc(db(OTHER), 'family_handles', 'thefam')));
    await assertFails(getDoc(doc(db(null), 'family_handles', 'thefam')));
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
