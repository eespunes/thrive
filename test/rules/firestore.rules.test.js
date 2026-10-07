// Firestore security rules tests for firestore.rules.
// Run via `npm test` in test/rules/ (wraps `firebase emulators:exec`).

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { after, before, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc,
  collection, query, where, getDocs,
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
  const wsRef = (d, id = 'budget') =>
    doc(d, 'families', FAM, 'workspace', id);
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'families', FAM, 'workspace', 'budget'),
        { years: {} });
      await setDoc(
        doc(ctx.firestore(), 'families', FAM, 'workspace', 'budget_2026_Mei'),
        { caps: {}, blocks: { home: [{ id: 'a' }] } });
    });
  });
  it('member can read and write', async () => {
    await assertSucceeds(getDoc(wsRef(db(MEMBER))));
    await assertSucceeds(setDoc(wsRef(db(MEMBER)), { years: { 2026: {} } }));
  });
  it('rejects writes that embed item arrays (outdated app versions)', async () => {
    await assertFails(setDoc(wsRef(db(MEMBER), 'budget_2026_Juni'), {
      caps: {}, blocks: { home: [] },
    }));
    await assertFails(setDoc(wsRef(db(MEMBER), 'list_task_l1'), {
      name: 'Chores', tasks: [],
    }));
    await assertFails(updateDoc(wsRef(db(MEMBER), 'budget_2026_Mei'), {
      caps: { home: 100 },
    }));
  });
  it('allows the migration to strip legacy arrays', async () => {
    const { deleteField } = await import('firebase/firestore');
    await assertSucceeds(updateDoc(wsRef(db(MEMBER), 'budget_2026_Mei'), {
      blocks: deleteField(), _blocks: ['home'],
    }));
    await assertSucceeds(setDoc(wsRef(db(MEMBER), 'budget_2026_Juni'), {
      caps: {}, _blocks: ['home'],
    }));
    await assertSucceeds(deleteDoc(wsRef(db(MEMBER), 'budget')));
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

describe('per-item collections', () => {
  for (const [col, id] of [
    ['budgetItems', '2026_Mei_a'],
    ['listItems', 'task_l1_t1'],
    ['weekly', '2026-05-04'],
  ]) {
    it(`${col}: members only`, async () => {
      await assertSucceeds(setDoc(doc(db(MEMBER), 'families', FAM, col, id),
        { label: 'x' }));
      await assertSucceeds(updateDoc(doc(db(OWNER), 'families', FAM, col, id),
        { paid: true }));
      await assertSucceeds(getDoc(doc(db(MEMBER), 'families', FAM, col, id)));
      await assertFails(getDoc(doc(db(OTHER), 'families', FAM, col, id)));
      await assertFails(setDoc(doc(db(OTHER), 'families', FAM, col, id),
        { label: 'hacked' }));
      await assertSucceeds(deleteDoc(doc(db(MEMBER), 'families', FAM, col, id)));
    });
  }
});

describe('child users (kidEmails)', () => {
  const KID = 'kid-uid';
  const KID_EMAIL = 'nora@example.com';
  const KID_MEMBER = 'm-kid';
  const kidDb = () => env
    .authenticatedContext(KID, { email: 'Nora@Example.com' })
    .firestore();
  const sub = (d, col, id) => doc(d, 'families', FAM, col, id);
  const put = (col, id, data) => env.withSecurityRulesDisabled(
    (ctx) => setDoc(doc(ctx.firestore(), 'families', FAM, col, id), data));

  beforeEach(async () => {
    await seed({
      ...baseFamily,
      memberUids: [OWNER, MEMBER, KID],
      kidEmails: { [KID_EMAIL]: KID_MEMBER },
    });
    await put('workspace', 'settings', { calendarLayers: [] });
    await put('workspace', 'budget_2026_Mei', { caps: {} });
    await put('workspace', 'card_c1', { name: 'Club card' });
    await put('workspace', 'list_task_mine', { name: 'Homework', createdBy: KID });
    await put('workspace', 'list_task_other', { name: 'Chores', createdBy: MEMBER });
    await put('listItems', 'task_mine_t1', { title: 'Maths', _list: 'mine', _listOwner: KID });
    await put('listItems', 'task_other_t1', { title: 'Dishes', _list: 'other', _listOwner: MEMBER });
    await put('budgetItems', '2026_Mei_a', { label: 'Rent' });
    await put('weekly', '2026-05-04', { dinner: 'Soup' });
    await put('events', 'ev-attend', { title: 'Football', attendees: [KID_MEMBER] });
    await put('events', 'ev-own', { title: 'Party', attendees: [], createdBy: KID });
    await put('events', 'ev-other', { title: 'Parents evening', attendees: [MEMBER], createdBy: MEMBER });
  });

  it('a kid never reads budgets, cards or other people\'s data', async () => {
    const d = kidDb();
    await assertFails(getDoc(sub(d, 'budgetItems', '2026_Mei_a')));
    await assertFails(getDocs(collection(d, 'families', FAM, 'budgetItems')));
    await assertFails(getDoc(sub(d, 'workspace', 'budget_2026_Mei')));
    await assertFails(getDoc(sub(d, 'workspace', 'card_c1')));
    await assertFails(getDoc(sub(d, 'workspace', 'list_task_other')));
    await assertFails(getDoc(sub(d, 'listItems', 'task_other_t1')));
    await assertFails(getDoc(sub(d, 'events', 'ev-other')));
    await assertFails(getDocs(collection(d, 'families', FAM, 'events')));
    await assertFails(getDocs(collection(d, 'families', FAM, 'workspace')));
  });

  it('a kid reads their own world through scoped queries', async () => {
    const d = kidDb();
    const col = (c) => collection(d, 'families', FAM, c);
    await assertSucceeds(getDoc(sub(d, 'workspace', 'settings')));
    const lists = await assertSucceeds(
      getDocs(query(col('workspace'), where('createdBy', '==', KID))));
    assert.deepEqual(lists.docs.map((x) => x.id), ['list_task_mine']);
    const items = await assertSucceeds(
      getDocs(query(col('listItems'), where('_listOwner', '==', KID))));
    assert.deepEqual(items.docs.map((x) => x.id), ['task_mine_t1']);
    const attending = await assertSucceeds(getDocs(query(col('events'),
      where('attendees', 'array-contains', KID_MEMBER))));
    assert.deepEqual(attending.docs.map((x) => x.id), ['ev-attend']);
    const created = await assertSucceeds(
      getDocs(query(col('events'), where('createdBy', '==', KID))));
    assert.deepEqual(created.docs.map((x) => x.id), ['ev-own']);
    await assertSucceeds(getDocs(col('weekly')));
  });

  it('a kid writes only their own events, lists and items', async () => {
    const d = kidDb();
    await assertSucceeds(setDoc(sub(d, 'events', 'ev-new'),
      { title: 'Swim', attendees: [KID_MEMBER], createdBy: KID }));
    await assertSucceeds(updateDoc(sub(d, 'events', 'ev-attend'), { done: true }));
    await assertFails(updateDoc(sub(d, 'events', 'ev-other'), { title: 'x' }));
    await assertFails(updateDoc(sub(d, 'events', 'ev-attend'),
      { attendees: [MEMBER] }));
    await assertFails(deleteDoc(sub(d, 'events', 'ev-other')));

    await assertSucceeds(setDoc(sub(d, 'workspace', 'list_shop_new'),
      { name: 'Wishlist', createdBy: KID }));
    await assertFails(setDoc(sub(d, 'workspace', 'list_shop_x'),
      { name: 'Sneaky', createdBy: MEMBER }));
    await assertFails(updateDoc(sub(d, 'workspace', 'list_task_other'),
      { name: 'Mine now', createdBy: KID }));
    await assertFails(updateDoc(sub(d, 'workspace', 'settings'), { x: 1 }));
    await assertFails(setDoc(sub(d, 'workspace', 'card_c2'),
      { name: 'Card', createdBy: KID }));

    await assertSucceeds(setDoc(sub(d, 'listItems', 'task_mine_t2'),
      { title: 'Reading', _list: 'mine', _listOwner: KID }));
    await assertFails(setDoc(sub(d, 'listItems', 'task_other_t2'),
      { title: 'x', _list: 'other', _listOwner: MEMBER }));

    await assertFails(setDoc(sub(d, 'weekly', '2026-05-04'), { dinner: 'Cake' }));
    await assertFails(setDoc(sub(d, 'budgetItems', '2026_Mei_b'), { label: 'x' }));
  });

  it('only the owner manages kidEmails', async () => {
    await assertFails(updateDoc(famRef(kidDb()), { kidEmails: {} }));
    await assertFails(updateDoc(famRef(db(MEMBER)), { kidEmails: {} }));
    await assertSucceeds(updateDoc(famRef(db(OWNER)), { kidEmails: {} }));
  });

  it('full members are unaffected by kidEmails', async () => {
    const d = db(MEMBER);
    await assertSucceeds(getDocs(collection(d, 'families', FAM, 'budgetItems')));
    await assertSucceeds(getDocs(collection(d, 'families', FAM, 'events')));
    await assertSucceeds(getDocs(collection(d, 'families', FAM, 'workspace')));
    await assertSucceeds(setDoc(sub(d, 'weekly', '2026-05-04'), { dinner: 'x' }));
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
