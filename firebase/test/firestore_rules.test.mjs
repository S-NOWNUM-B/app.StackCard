import assert from 'node:assert/strict';
import { after, before, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  runTransaction,
  serverTimestamp,
  setDoc,
  setLogLevel,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-stackcard-test';
let environment;

before(async () => {
  setLogLevel('silent');
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8085,
      rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment?.cleanup());

function database(uid = 'alice') {
  return (uid === null
    ? environment.unauthenticatedContext()
    : environment.authenticatedContext(uid)).firestore();
}

function content(name = 'Alice') {
  return {
    profile: {
      name,
      username: 'alice',
      headline: 'Developer',
      bio: '',
      locationText: '',
      avatarUrl: '',
    },
    skills: [],
    projects: [],
    experience: [],
    education: [],
    links: [],
    blocks: [],
    resumeText: '',
    theme: 'dark',
  };
}

function draft(uid = 'alice', overrides = {}) {
  return {
    schemaVersion: 1,
    ownerUid: uid,
    mutationId: `${uid}-mutation-1`,
    localRevision: 1,
    notes: 'Private notes never belong to the published snapshot',
    content: content(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

async function saveDraft(db, uid = 'alice', overrides = {}) {
  await setDoc(doc(db, `accounts/${uid}/drafts/current`), draft(uid, overrides));
}

function publication(uid, username, version = 1, overrides = {}) {
  return {
    schemaVersion: 1,
    ownerUid: uid,
    username,
    content: content(),
    publishedAt: serverTimestamp(),
    publicationVersion: version,
    sourceMutationId: `${uid}-mutation-1`,
    ...overrides,
  };
}

function publishBatch(db, uid = 'alice', username = 'alice', version = 1, overrides = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, `accounts/${uid}`), {
    ownerUid: uid,
    username,
    updatedAt: serverTimestamp(),
    publicationVersion: version,
  });
  batch.set(doc(db, `usernames/${username}`), { ownerUid: uid, username });
  batch.set(doc(db, `publicPortfolios/${username}`), publication(uid, username, version, overrides));
  return batch;
}

async function publish(db, uid = 'alice', username = 'alice', version = 1) {
  await saveDraft(db, uid);
  await publishBatch(db, uid, username, version).commit();
}

function unpublishBatch(db, uid = 'alice', username = 'alice', version = 2) {
  const batch = writeBatch(db);
  batch.update(doc(db, `accounts/${uid}`), {
    username: null,
    updatedAt: serverTimestamp(),
    publicationVersion: version,
  });
  batch.delete(doc(db, `usernames/${username}`));
  batch.delete(doc(db, `publicPortfolios/${username}`));
  return batch;
}

test('owner reads, writes and deletes own current draft; notes stay private', async () => {
  const alice = database();
  await assertSucceeds(saveDraft(alice));
  const stored = await assertSucceeds(getDoc(doc(alice, 'accounts/alice/drafts/current')));
  assert.match(stored.data().notes, /Private notes/);
  await assertSucceeds(deleteDoc(doc(alice, 'accounts/alice/drafts/current')));
});

test('foreign UID and anonymous clients cannot read, write or delete a private draft', async () => {
  await saveDraft(database());
  for (const uid of ['bob', null]) {
    const db = database(uid);
    const ref = doc(db, 'accounts/alice/drafts/current');
    await assertFails(getDoc(ref));
    await assertFails(setDoc(ref, draft('alice')));
    await assertFails(deleteDoc(ref));
  }
});

test('draft schema rejects spoofed owner, client timestamp, extra fields and unknown version', async () => {
  const alice = database();
  for (const overrides of [
    { ownerUid: 'bob' },
    { updatedAt: Timestamp.fromMillis(1) },
    { email: 'private@example.invalid' },
    { schemaVersion: 99 },
    { mutationId: '' },
    { localRevision: -1 },
    { notes: null },
    { content: { ...content(), notes: 'private' } },
  ]) {
    await assertFails(saveDraft(alice, 'alice', overrides));
  }
  await assertFails(setDoc(doc(alice, 'accounts/alice/drafts/other'), draft()));
});

test('notes-only draft with null content is valid', async () => {
  await assertSucceeds(saveDraft(database(), 'alice', { content: null }));
});

test('an existing unknown-schema or mismatched-owner draft cannot be overwritten', async () => {
  for (const overrides of [{ schemaVersion: 99 }, { ownerUid: 'bob' }]) {
    await environment.withSecurityRulesDisabled(async (context) => {
      await saveDraft(context.firestore(), 'alice', overrides);
    });
    await assertFails(saveDraft(database()));
  }
});

test('whole draft uses server commit order, independent of local revision and device clocks', async () => {
  const firstClient = database();
  const secondClient = database();
  await saveDraft(firstClient, 'alice', { localRevision: 20, mutationId: 'first', notes: 'Earlier commit' });
  const earlier = (await getDoc(doc(firstClient, 'accounts/alice/drafts/current'))).data();
  await assertSucceeds(saveDraft(secondClient, 'alice', {
    localRevision: 1,
    mutationId: 'second',
    notes: 'Later commit replaces the whole draft',
    content: null,
  }));
  const later = (await getDoc(doc(firstClient, 'accounts/alice/drafts/current'))).data();
  assert.equal(later.mutationId, 'second');
  assert.equal(later.content, null);
  assert.equal(later.localRevision, 1);
  assert.ok(later.updatedAt.toMillis() >= earlier.updatedAt.toMillis());
});

test('private schema 2 accepts GitHub ignore metadata and rejects a schema downgrade', async () => {
  const alice = database();
  await assertSucceeds(saveDraft(alice));
  const imported = {
    ...content('Curated project owner'),
    ignoredGitHubRepositories: [{ repositoryId: 42, fingerprint: 'ignored-source-version' }],
  };
  await assertSucceeds(saveDraft(alice, 'alice', {
    schemaVersion: 2,
    mutationId: 'metadata-v2',
    content: imported,
  }));
  const ref = doc(alice, 'accounts/alice/drafts/current');
  const before = (await getDoc(ref)).data();
  await assertFails(saveDraft(alice, 'alice', { schemaVersion: 1 }));
  const after = (await getDoc(ref)).data();
  assert.deepEqual(after, before);
  assert.deepEqual(after.content.ignoredGitHubRepositories, imported.ignoredGitHubRepositories);
});

test('legacy schema cannot write ignore metadata and schema 2 validates its list container', async () => {
  const alice = database();
  await assertFails(saveDraft(alice, 'alice', {
    schemaVersion: 1,
    content: { ...content(), ignoredGitHubRepositories: [] },
  }));
  await assertFails(saveDraft(alice, 'alice', {
    schemaVersion: 2,
    content: { ...content(), ignoredGitHubRepositories: {} },
  }));
  await assertSucceeds(saveDraft(alice, 'alice', { schemaVersion: 2, content: null }));
});

test('atomic publish exposes only public snapshot; account and private draft stay owner-only', async () => {
  const alice = database();
  await assertSucceeds(publish(alice));
  const anonymous = database(null);
  const snapshot = (await assertSucceeds(getDoc(doc(anonymous, 'publicPortfolios/alice')))).data();
  assert.equal(snapshot.content.profile.name, 'Alice');
  assert.equal(Object.hasOwn(snapshot, 'notes'), false);
  assert.equal(Object.hasOwn(snapshot, 'email'), false);
  for (const uid of ['bob', null]) {
    const db = database(uid);
    await assertFails(getDoc(doc(db, 'accounts/alice')));
    await assertFails(getDoc(doc(db, 'accounts/alice/drafts/current')));
  }
  await assertSucceeds(getDoc(doc(alice, 'accounts/alice')));
});

test('collection enumeration and unnamed paths are denied', async () => {
  await publish(database());
  for (const uid of ['alice', 'bob', null]) {
    const db = database(uid);
    for (const path of ['accounts', 'accounts/alice/drafts', 'publicPortfolios', 'usernames']) {
      await assertFails(getDocs(collection(db, path)));
    }
    await assertFails(getDoc(doc(db, 'unknown/value')));
    await assertFails(setDoc(doc(db, 'unknown/value'), { value: true }));
  }
});

test('only authenticated clients can get username claims, including missing claims', async () => {
  await publish(database());
  for (const uid of ['alice', 'bob']) {
    const db = database(uid);
    await assertSucceeds(getDoc(doc(db, 'usernames/alice')));
    await assertSucceeds(getDoc(doc(db, 'usernames/available')));
  }
  await assertFails(getDoc(doc(database(null), 'usernames/alice')));
  await assertFails(getDoc(doc(database(null), 'usernames/available')));
});

test('standalone account, reservation and snapshot creation are denied', async () => {
  const alice = database();
  await saveDraft(alice);
  await assertFails(setDoc(doc(alice, 'accounts/alice'), {
    ownerUid: 'alice', username: 'alice', updatedAt: serverTimestamp(), publicationVersion: 1,
  }));
  await assertFails(setDoc(doc(alice, 'usernames/alice'), { ownerUid: 'alice', username: 'alice' }));
  await assertFails(setDoc(doc(alice, 'publicPortfolios/alice'), publication('alice', 'alice')));
});

test('partial publish missing any one linked document is denied', async () => {
  const alice = database();
  await saveDraft(alice);
  for (const missing of ['account', 'claim', 'snapshot']) {
    const batch = writeBatch(alice);
    if (missing !== 'account') batch.set(doc(alice, 'accounts/alice'), {
      ownerUid: 'alice', username: 'alice', updatedAt: serverTimestamp(), publicationVersion: 1,
    });
    if (missing !== 'claim') batch.set(doc(alice, 'usernames/alice'), { ownerUid: 'alice', username: 'alice' });
    if (missing !== 'snapshot') batch.set(doc(alice, 'publicPortfolios/alice'), publication('alice', 'alice'));
    await assertFails(batch.commit());
  }
});

test('public snapshot rejects root and content/profile private fields', async () => {
  const alice = database();
  await saveDraft(alice);
  for (const overrides of [
    { notes: 'Private notes' },
    { email: 'private@example.invalid' },
    { content: { ...content(), notes: 'Private nested notes' } },
    { content: { ...content(), profile: { ...content().profile, email: 'private@example.invalid' } } },
    { content: { ...content(), profile: { ...content().profile, notes: 'Private notes' } } },
    { content: { ...content(), ignoredGitHubRepositories: [] } },
    { content: { ...content(), ignoredGitHubRepositories: [{ repositoryId: 42, fingerprint: 'private' }] } },
  ]) {
    await assertFails(publishBatch(alice, 'alice', 'alice', 1, overrides).commit());
  }
});

test('publish requires the current saved draft mutation identity', async () => {
  const alice = database();
  await assertFails(publishBatch(alice).commit());
  await saveDraft(alice);
  await assertFails(publishBatch(alice, 'alice', 'alice', 1, { sourceMutationId: 'stale-mutation' }).commit());
  await assertSucceeds(publishBatch(alice).commit());
});

test('combined draft and publish writes cannot claim a stale source mutation', async () => {
  const alice = database();
  await saveDraft(alice);
  const stale = publishBatch(alice);
  stale.set(doc(alice, 'accounts/alice/drafts/current'), draft('alice', { mutationId: 'newer-source' }));
  await assertFails(stale.commit());
  const current = publishBatch(alice, 'alice', 'alice', 1, { sourceMutationId: 'newer-source' });
  current.set(doc(alice, 'accounts/alice/drafts/current'), draft('alice', { mutationId: 'newer-source' }));
  await assertSucceeds(current.commit());
});

test('username follows shared lowercase 3–30 character validation', async () => {
  const alice = database();
  await saveDraft(alice);
  for (const username of ['ab', 'Alice', '-alice', 'alice-', 'alice_name', 'a'.repeat(31)]) {
    await assertFails(publishBatch(alice, 'alice', username).commit());
  }
  await assertSucceeds(publishBatch(alice, 'alice', 'alice-123').commit());
});

test('snapshot cannot change without account publicationVersion advancing', async () => {
  const alice = database();
  await publish(alice);
  await assertFails(updateDoc(doc(alice, 'publicPortfolios/alice'), {
    content: content('Changed'), publishedAt: serverTimestamp(),
  }));
  const unchangedAccount = writeBatch(alice);
  unchangedAccount.update(doc(alice, 'accounts/alice'), { updatedAt: serverTimestamp() });
  unchangedAccount.set(doc(alice, 'publicPortfolios/alice'), publication('alice', 'alice'));
  await assertFails(unchangedAccount.commit());
  await assertSucceeds(publishBatch(alice, 'alice', 'alice', 2, { content: content('Explicit republish') }).commit());
  assert.equal((await getDoc(doc(alice, 'publicPortfolios/alice'))).data().content.profile.name, 'Explicit republish');
});

test('draft sync never changes an existing published snapshot', async () => {
  const alice = database();
  await publish(alice);
  await saveDraft(alice, 'alice', { mutationId: 'unsent-to-public', content: content('Private newer draft') });
  const publicDocument = (await getDoc(doc(database(null), 'publicPortfolios/alice'))).data();
  assert.equal(publicDocument.content.profile.name, 'Alice');
  assert.equal(publicDocument.sourceMutationId, 'alice-mutation-1');
  assert.equal(publicDocument.publicationVersion, 1);
});

test('schema 2 GitHub sync preserves a published snapshot until an explicit republish', async () => {
  const alice = database();
  await publish(alice);
  const ref = doc(database(null), 'publicPortfolios/alice');
  const initialPublic = (await getDoc(ref)).data();
  await assertSucceeds(saveDraft(alice, 'alice', {
    schemaVersion: 2,
    mutationId: 'github-source-reviewed',
    content: {
      ...content('Accepted GitHub changes'),
      ignoredGitHubRepositories: [{ repositoryId: 42, fingerprint: 'private-ignore-decision' }],
    },
  }));
  assert.deepEqual((await getDoc(ref)).data(), initialPublic);
  await assertSucceeds(publishBatch(alice, 'alice', 'alice', 2, {
    content: content('Accepted GitHub changes'),
    sourceMutationId: 'github-source-reviewed',
  }).commit());
  const republished = (await getDoc(ref)).data();
  assert.equal(republished.schemaVersion, 1);
  assert.equal(republished.publicationVersion, 2);
  assert.equal(republished.content.profile.name, 'Accepted GitHub changes');
  assert.equal(Object.hasOwn(republished.content, 'ignoredGitHubRepositories'), false);
});

test('foreign UID and anonymous clients cannot take over or delete a publication', async () => {
  await publish(database());
  const bob = database('bob');
  await saveDraft(bob, 'bob');
  await assertFails(publishBatch(bob, 'bob', 'alice').commit());
  for (const uid of ['bob', null]) {
    const db = database(uid);
    await assertFails(deleteDoc(doc(db, 'accounts/alice')));
    await assertFails(deleteDoc(doc(db, 'usernames/alice')));
    await assertFails(deleteDoc(doc(db, 'publicPortfolios/alice')));
  }
});

test('username transaction race has exactly one owner', async () => {
  const alice = database();
  const bob = database('bob');
  await saveDraft(alice);
  await saveDraft(bob, 'bob');
  const reserve = (db, uid) => runTransaction(db, async (transaction) => {
    const claim = doc(db, 'usernames/shared-name');
    const current = await transaction.get(claim);
    if (current.exists()) throw new Error('username-unavailable');
    transaction.set(claim, { ownerUid: uid, username: 'shared-name' });
    transaction.set(doc(db, `accounts/${uid}`), {
      ownerUid: uid, username: 'shared-name', updatedAt: serverTimestamp(), publicationVersion: 1,
    });
    transaction.set(doc(db, 'publicPortfolios/shared-name'), publication(uid, 'shared-name'));
  });
  const results = await Promise.allSettled([reserve(alice, 'alice'), reserve(bob, 'bob')]);
  assert.equal(results.filter((item) => item.status === 'fulfilled').length, 1);
  const winner = (await getDoc(doc(alice, 'usernames/shared-name'))).data().ownerUid;
  assert.ok(['alice', 'bob'].includes(winner));
  assert.equal((await getDoc(doc(database(null), 'publicPortfolios/shared-name'))).data().ownerUid, winner);
});

test('unpublish atomically removes claim and public snapshot and clears pointer', async () => {
  const alice = database();
  await publish(alice);
  await assertSucceeds(unpublishBatch(alice).commit());
  assert.equal((await getDoc(doc(database(null), 'publicPortfolios/alice'))).exists(), false);
  assert.equal((await getDoc(doc(alice, 'usernames/alice'))).exists(), false);
  const account = (await getDoc(doc(alice, 'accounts/alice'))).data();
  assert.equal(account.username, null);
  assert.equal(account.publicationVersion, 2);
  assert.equal((await getDoc(doc(alice, 'accounts/alice/drafts/current'))).exists(), true);
});

test('partial unpublish missing account update, claim delete or snapshot delete is denied', async () => {
  const alice = database();
  await publish(alice);
  for (const missing of ['account', 'claim', 'snapshot']) {
    const batch = writeBatch(alice);
    if (missing !== 'account') batch.update(doc(alice, 'accounts/alice'), {
      username: null, updatedAt: serverTimestamp(), publicationVersion: 2,
    });
    if (missing !== 'claim') batch.delete(doc(alice, 'usernames/alice'));
    if (missing !== 'snapshot') batch.delete(doc(alice, 'publicPortfolios/alice'));
    await assertFails(batch.commit());
  }
});

test('rename requires atomic release of both old public records', async () => {
  const alice = database();
  await publish(alice);
  for (const kept of ['claim', 'snapshot', 'both']) {
    const batch = publishBatch(alice, 'alice', 'new-alice', 2);
    if (kept !== 'claim' && kept !== 'both') batch.delete(doc(alice, 'usernames/alice'));
    if (kept !== 'snapshot' && kept !== 'both') batch.delete(doc(alice, 'publicPortfolios/alice'));
    await assertFails(batch.commit());
  }
  const rename = publishBatch(alice, 'alice', 'new-alice', 2);
  rename.delete(doc(alice, 'usernames/alice'));
  rename.delete(doc(alice, 'publicPortfolios/alice'));
  await assertSucceeds(rename.commit());
  assert.equal((await getDoc(doc(database(null), 'publicPortfolios/alice'))).exists(), false);
  assert.equal((await getDoc(doc(database(null), 'publicPortfolios/new-alice'))).exists(), true);
  assert.equal((await getDoc(doc(alice, 'usernames/alice'))).exists(), false);
});

test('release after unpublish allows a new UID to claim the same username', async () => {
  const alice = database();
  await publish(alice);
  await unpublishBatch(alice).commit();
  const bob = database('bob');
  await assertSucceeds(publish(bob, 'bob', 'alice'));
  assert.equal((await getDoc(doc(bob, 'usernames/alice'))).data().ownerUid, 'bob');
});

test('account version cannot skip, decrease, change owner or delete', async () => {
  const alice = database();
  await publish(alice);
  for (const version of [0, 1, 3]) {
    await assertFails(publishBatch(alice, 'alice', 'alice', version).commit());
  }
  await assertFails(updateDoc(doc(alice, 'accounts/alice'), {
    ownerUid: 'bob', updatedAt: serverTimestamp(), publicationVersion: 2,
  }));
  await assertFails(deleteDoc(doc(alice, 'accounts/alice')));
});
