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

describe('workspace subcollection', () => {
  const wsRef = (d) => doc(d, 'families', FAM, 'workspace', 'budget');
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'families', FAM, 'workspace', 'budget'),
        { years: {} });
    });
  });
  it('member can read and write', async () => {
    await assertSucceeds(getDoc(wsRef(db(MEMBER))));
    await assertSucceeds(setDoc(wsRef(db(MEMBER)), { years: { 2026: {} } }));
  });
  it('non-member cannot read or write', async () => {
    await assertFails(getDoc(wsRef(db(OTHER))));
    await assertFails(setDoc(wsRef(db(OTHER)), { hacked: true }));
  });
  it('unauthenticated cannot read', async () => {
    await assertFails(getDoc(wsRef(db(null))));
  });
});

describe('events subcollection', () => {
  const evRef = (d) => doc(d, 'families', FAM, 'events', 'ev1');
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'families', FAM, 'events', 'ev1'),
        { title: 'Dentist', date: '2026-03-02' });
    });
  });
  it('member can read and write', async () => {
    await assertSucceeds(getDoc(evRef(db(MEMBER))));
    await assertSucceeds(setDoc(evRef(db(MEMBER)), { title: 'Doctor' }));
  });
  it('non-member cannot read or write', async () => {
    await assertFails(getDoc(evRef(db(OTHER))));
    await assertFails(setDoc(evRef(db(OTHER)), { hacked: true }));
  });
  it('unauthenticated cannot read', async () => {
    await assertFails(getDoc(evRef(db(null))));
  });
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
  it('any signed-in user can read; unauthenticated cannot', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'family_handles', 'thefam'),
        { familyId: FAM });
    });
    await assertSucceeds(getDoc(doc(db(OTHER), 'family_handles', 'thefam')));
    await assertFails(getDoc(doc(db(null), 'family_handles', 'thefam')));
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
