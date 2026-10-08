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

function documentContent(uid = 'alice', index = 0) {
  return {
    id: `resume-${index}`,
    title: `Resume ${index}`,
    kind: 'resume',
    createdAt: '2026-10-07T00:00:00.000Z',
    updatedAt: '2026-10-07T00:00:00.000Z',
    content: {
      ...content(),
      profile: {
        ...content().profile,
        avatarPath: `accounts/${uid}/media/0123456789abcdef0123456789abcdef.jpg`,
      },
      ignoredGitHubRepositories: [],
    },
    projects: [],
    attachedResumeId: null,
  };
}

function workspaceDocuments(count = 1) {
  return {
    ...content(),
    ignoredGitHubRepositories: [],
    documents: Array.from({ length: count }, (_, index) => documentContent('alice', index)),
  };
}

function workspaceBaseReviews(count = 1) {
  const workspace = workspaceDocuments(count);
  for (const document of workspace.documents) {
    const snapshot = document.content;
    document.baseSnapshot = {
      profile: { ...snapshot.profile },
      skills: [], experience: [], education: [], links: [],
    };
    // Фото документа и захваченной базы могут независимо меняться.
    document.baseSnapshot.profile.avatarPath =
      'accounts/alice/media/abcdef0123456789abcdef0123456789.jpg';
  }
  return workspace;
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
  await seedLegacyPublication(uid, username, version);
}

async function seedLegacyPublication(uid = 'alice', username = 'alice', version = 1) {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, `accounts/${uid}`), { ownerUid: uid, username, publicationVersion: version, updatedAt: serverTimestamp() });
    batch.set(doc(db, `usernames/${username}`), { ownerUid: uid, username });
    batch.set(doc(db, `publicPortfolios/${username}`), publication(uid, username, version));
    await batch.commit();
  });
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

test('private document schema 4 accepts owner snapshots and blocks every downgrade', async () => {
  const alice = database();
  await assertSucceeds(saveDraft(alice, 'alice', {
    schemaVersion: 4, mutationId: 'documents-save', content: workspaceDocuments(),
  }));
  const stored = (await getDoc(doc(alice, 'accounts/alice/drafts/current'))).data();
  assert.equal(stored.content.documents[0].title, 'Resume 0');
  for (const schemaVersion of [1, 2, 3]) {
    await assertFails(saveDraft(alice, 'alice', { schemaVersion }));
  }
  await assertFails(getDoc(doc(database('bob'), 'accounts/alice/drafts/current')));
  await assertFails(getDoc(doc(database(null), 'accounts/alice/drafts/current')));
});

test('old private and public schemas reject documents even when the list is empty', async () => {
  const alice = database();
  for (const schemaVersion of [1, 2, 3]) {
    await assertFails(saveDraft(alice, 'alice', {
      schemaVersion, content: { ...content(), documents: [] },
    }));
  }
  await saveDraft(alice);
  await assertFails(publishBatch(alice, 'alice', 'alice', 1, {
    content: { ...content(), documents: [] },
  }).commit());
});

test('all 20 document snapshots validate their media owner, including final index', async () => {
  const alice = database();
  const emptyAvatars = workspaceDocuments(20);
  for (const document of emptyAvatars.documents) document.content.profile.avatarPath = '';
  await assertSucceeds(saveDraft(alice, 'alice', {
    schemaVersion: 4, content: emptyAvatars,
  }));
  await assertSucceeds(saveDraft(alice, 'alice', {
    schemaVersion: 4, content: workspaceDocuments(20),
  }));
  const foreign = workspaceDocuments(20);
  foreign.documents[19] = documentContent('bob', 19);
  await assertFails(saveDraft(alice, 'alice', { schemaVersion: 4, content: foreign }));
  await assertFails(saveDraft(alice, 'alice', {
    schemaVersion: 4, content: workspaceDocuments(21),
  }));
});

test('document Rules reject foreign snapshot media', async () => {
  const alice = database();
  const mutations = [
    (document) => { document.content.profile.avatarPath = 'accounts/bob/media/0123456789abcdef0123456789abcdef.jpg'; },
    (document) => { document.content.profile.avatarPath = 42; },
    (document) => { delete document.content.profile.avatarPath; },
  ];
  for (const mutate of mutations) {
    const workspace = workspaceDocuments();
    mutate(workspace.documents[0]);
    await assertFails(saveDraft(alice, 'alice', { schemaVersion: 4, content: workspace }));
  }
  await assertSucceeds(saveDraft(alice, 'alice', {
    schemaVersion: 4, content: workspaceDocuments(),
  }));
});

test('schema 5 accepts all 20 captured bases and blocks downgrades and foreign clients', async () => {
  const alice = database();
  await assertSucceeds(saveDraft(alice, 'alice', {
    schemaVersion: 5, content: workspaceBaseReviews(20),
  }));
  const stored = (await getDoc(doc(alice, 'accounts/alice/drafts/current'))).data();
  assert.equal(stored.content.documents[19].baseSnapshot.profile.name, 'Alice');
  for (const schemaVersion of [1, 2, 3, 4]) {
    await assertFails(saveDraft(alice, 'alice', { schemaVersion }));
  }
  const foreign = workspaceBaseReviews(20);
  foreign.documents[19].baseSnapshot.profile.avatarPath =
    'accounts/bob/media/0123456789abcdef0123456789abcdef.jpg';
  await assertFails(saveDraft(alice, 'alice', { schemaVersion: 5, content: foreign }));
  await assertFails(saveDraft(alice, 'alice', { schemaVersion: 5, content: workspaceBaseReviews(21) }));
  for (const uid of ['bob', null]) {
    await assertFails(getDoc(doc(database(uid), 'accounts/alice/drafts/current')));
    await assertFails(saveDraft(database(uid), 'alice', {
      schemaVersion: 5, content: workspaceBaseReviews(),
    }));
  }
});

test('schema 5 preserves legacy documents without a baseline key and rejects explicit null writes', async () => {
  const alice = database();
  await assertSucceeds(saveDraft(alice, 'alice', { schemaVersion: 4, content: workspaceDocuments() }));
  await assertSucceeds(saveDraft(alice, 'alice', { schemaVersion: 5, content: workspaceDocuments() }));
  const workspace = workspaceDocuments();
  workspace.documents[0].baseSnapshot = null;
  await assertFails(saveDraft(alice, 'alice', { schemaVersion: 5, content: workspace }));
});

test('captured base media rejects malformed, missing and non-string paths', async () => {
  const alice = database();
  const mutations = [
    (snapshot) => { snapshot.profile = []; },
    (snapshot) => { delete snapshot.profile.avatarPath; },
    (snapshot) => { snapshot.profile.avatarPath = 42; },
    (snapshot) => { snapshot.profile.avatarPath = 'https://example.invalid/private'; },
    (snapshot) => { snapshot.profile.avatarPath = 'accounts/alice/media/not-an-image.jpg'; },
    (snapshot) => { snapshot.profile.avatarPath = 'accounts/bob/media/0123456789abcdef0123456789abcdef.jpg'; },
  ];
  for (const mutate of mutations) {
    const workspace = workspaceBaseReviews();
    mutate(workspace.documents[0].baseSnapshot);
    await assertFails(saveDraft(alice, 'alice', { schemaVersion: 5, content: workspace }));
  }
  const emptyAvatars = workspaceBaseReviews(20);
  for (const document of emptyAvatars.documents) document.baseSnapshot.profile.avatarPath = '';
  await assertSucceeds(saveDraft(alice, 'alice', { schemaVersion: 5, content: emptyAvatars }));
});

test('literal UID quoting prevents regex injection, including embedded quote terminators and path separators', async () => {
  for (const uid of ['a.b*+?^$()[]{}|', 'literal\\E.*', 'literal;uid', 'literal\\Quid\\E', 'a\\E\\E|b', 'алматы']) {
    const db = database(uid);
    const workspace = workspaceBaseReviews(20);
    for (const [index, document] of workspace.documents.entries()) {
      document.content.profile.avatarPath =
        `accounts/${uid}/media/${index.toString(16).padStart(32, '0')}.jpg`;
      document.baseSnapshot.profile.avatarPath =
        `accounts/${uid}/media/${(index + 100).toString(16).padStart(32, '0')}.jpg`;
    }
    await assertSucceeds(saveDraft(db, uid, { schemaVersion: 5, content: workspace }));
    workspace.documents[19].baseSnapshot.profile.avatarPath =
      'accounts/bob/media/0123456789abcdef0123456789abcdef.jpg';
    await assertFails(saveDraft(db, uid, { schemaVersion: 5, content: workspace }));
  }
  const uid = 'a.b';
  const workspace = workspaceBaseReviews();
  workspace.documents[0].content.profile.avatarPath =
    'accounts/a.b/media/0123456789abcdef0123456789abcdef.jpg';
  workspace.documents[0].baseSnapshot.profile.avatarPath =
    'accounts/axb/media/0123456789abcdef0123456789abcdef.jpg';
  await assertFails(saveDraft(database(uid), uid, { schemaVersion: 5, content: workspace }));
});

test('typed field access still rejects every missing mandatory draft, profile and content field', async () => {
  const alice = database();
  for (const key of ['schemaVersion', 'ownerUid', 'mutationId', 'localRevision', 'notes', 'content', 'updatedAt']) {
    const value = draft('alice', { schemaVersion: 5, content: workspaceBaseReviews() });
    delete value[key];
    await assertFails(setDoc(doc(alice, 'accounts/alice/drafts/current'), value));
  }
  for (const key of ['profile', 'skills', 'projects', 'experience', 'education', 'links', 'blocks', 'resumeText', 'theme']) {
    const value = content();
    delete value[key];
    await assertFails(saveDraft(alice, 'alice', { schemaVersion: 5, content: value }));
  }
  for (const key of ['name', 'username', 'headline', 'bio', 'locationText', 'avatarUrl']) {
    const value = content();
    delete value.profile[key];
    await assertFails(saveDraft(alice, 'alice', { schemaVersion: 5, content: value }));
  }
  for (const value of [[], 42, 'Not an object']) {
    await assertFails(saveDraft(alice, 'alice', { schemaVersion: 5, content: value }));
    await assertFails(saveDraft(alice, 'alice', { schemaVersion: 5, content: { ...content(), profile: value } }));
  }
});

test('public schema remains 1 and rejects captured bases and documents', async () => {
  const alice = database();
  await assertSucceeds(saveDraft(alice, 'alice', { schemaVersion: 5, content: workspaceBaseReviews() }));
  for (const extra of [
    { documents: workspaceBaseReviews().documents },
    { baseSnapshot: workspaceBaseReviews().documents[0].baseSnapshot },
  ]) {
    await assertFails(publishBatch(alice, 'alice', 'alice', 1, {
      content: { ...content(), ...extra },
    }).commit());
  }
  await assertFails(publishBatch(alice).commit());
  await seedLegacyPublication();
  const publicData = (await getDoc(doc(database(null), 'publicPortfolios/alice'))).data();
  assert.equal(publicData.schemaVersion, 1);
  assert.equal(Object.hasOwn(publicData.content, 'documents'), false);
  assert.equal(Object.hasOwn(publicData.content, 'baseSnapshot'), false);
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

test('private schema 3 accepts owner media paths after legacy migration and forbids downgrades', async () => {
  const alice = database();
  await assertSucceeds(saveDraft(alice));
  await assertSucceeds(saveDraft(alice, 'alice', { schemaVersion: 2 }));
  const mediaPath = 'accounts/alice/media/0123456789abcdef0123456789abcdef.jpg';
  const mediaContent = {
    ...content(),
    profile: { ...content().profile, avatarPath: mediaPath },
    projects: [{ id: 'project-1', imagePaths: [mediaPath] }],
    ignoredGitHubRepositories: [],
  };
  await assertSucceeds(saveDraft(alice, 'alice', {
    schemaVersion: 3, mutationId: 'media-v3', content: mediaContent,
  }));
  const ref = doc(alice, 'accounts/alice/drafts/current');
  const before = (await getDoc(ref)).data();
  assert.equal(before.content.profile.avatarPath, mediaPath);
  for (const schemaVersion of [1, 2]) {
    await assertFails(saveDraft(alice, 'alice', { schemaVersion }));
  }
  assert.deepEqual((await getDoc(ref)).data(), before);
});

test('schema 3 allows absent or empty avatar path and notes-only content', async () => {
  const alice = database();
  await assertSucceeds(saveDraft(alice, 'alice', { schemaVersion: 3 }));
  await assertSucceeds(saveDraft(alice, 'alice', {
    schemaVersion: 3,
    content: { ...content(), profile: { ...content().profile, avatarPath: '' } },
  }));
  await assertSucceeds(saveDraft(alice, 'alice', { schemaVersion: 3, content: null }));
});

test('legacy schemas reject the media profile field even when it is empty', async () => {
  for (const schemaVersion of [1, 2]) {
    await assertFails(saveDraft(database(), 'alice', {
      schemaVersion,
      content: { ...content(), profile: { ...content().profile, avatarPath: '' } },
    }));
    await assertSucceeds(saveDraft(database(), 'alice', { schemaVersion }));
  }
});

test('schema 3 rejects malformed, foreign and non-string avatar paths', async () => {
  for (const avatarPath of [
    null, 1, [], {},
    'accounts/bob/media/0123456789abcdef0123456789abcdef.jpg',
    'accounts/alice/media/0123456789abcdef0123456789abcdef.png',
    'accounts/alice/media/0123456789ABCDEF0123456789ABCDEF.jpg',
    'accounts/alice/media/short.jpg',
    'accounts/alice/media/0123456789abcdef0123456789abcdef.jpg/other',
    'publicPortfolios/alice/media/0123456789abcdef0123456789abcdef.jpg',
    'https://example.invalid/avatar.jpg',
  ]) {
    await assertFails(saveDraft(database(), 'alice', {
      schemaVersion: 3,
      content: { ...content(), profile: { ...content().profile, avatarPath } },
    }));
  }
});

test('schema 3 sync preserves publication and the public profile refuses private media paths', async () => {
  const alice = database();
  await publish(alice);
  const publicRef = doc(database(null), 'publicPortfolios/alice');
  const initialPublic = (await getDoc(publicRef)).data();
  const privateContent = {
    ...content('Private media owner'),
    profile: {
      ...content('Private media owner').profile,
      avatarPath: 'accounts/alice/media/0123456789abcdef0123456789abcdef.jpg',
    },
  };
  await assertSucceeds(saveDraft(alice, 'alice', {
    schemaVersion: 3, mutationId: 'media-v3', content: privateContent,
  }));
  assert.deepEqual((await getDoc(publicRef)).data(), initialPublic);
  await assertFails(publishBatch(alice, 'alice', 'alice', 2, {
    content: privateContent, sourceMutationId: 'media-v3',
  }).commit());
  await assertFails(publishBatch(alice, 'alice', 'alice', 2, {
    content: content('Explicit legacy public projection'), sourceMutationId: 'media-v3',
  }).commit());
  assert.equal(Object.hasOwn((await getDoc(publicRef)).data().content.profile, 'avatarPath'), false);
});

test('historical legacy snapshot is read-only; all direct publishing transitions are denied', async () => {
  const alice = database();
  await publish(alice);
  const snapshot = await assertSucceeds(getDoc(doc(database(null), 'publicPortfolios/alice')));
  assert.equal(snapshot.data().content.profile.name, 'Alice');
  for (const uid of ['alice', 'bob', null]) {
    const db = database(uid);
    await assertFails(setDoc(doc(db, 'publicPortfolios/alice'), publication('alice', 'alice')));
    await assertFails(deleteDoc(doc(db, 'publicPortfolios/alice')));
    await assertFails(setDoc(doc(db, 'usernames/alice'), { ownerUid: 'alice', username: 'alice' }));
    await assertFails(deleteDoc(doc(db, 'usernames/alice')));
    await assertFails(getDocs(collection(db, 'publicPortfolios')));
    await assertFails(getDocs(collection(db, 'usernames')));
  }
  await assertFails(publishBatch(alice, 'alice', 'alice', 2).commit());
  await assertFails(unpublishBatch(alice).commit());
  await assertFails(publishBatch(database('bob'), 'bob', 'new-bob').commit());
  for (const uid of ['bob', null]) {
    await assertFails(getDoc(doc(database(uid), 'accounts/alice')));
    await assertFails(getDoc(doc(database(uid), 'accounts/alice/drafts/current')));
  }
  await assertSucceeds(getDoc(doc(alice, 'accounts/alice')));
});

test('private Save preserves historical public payload without implicit publication', async () => {
  await publish(database());
  const publicRef = doc(database(null), 'publicPortfolios/alice');
  const original = (await getDoc(publicRef)).data();
  await saveDraft(database(), 'alice', { mutationId: 'new-private', content: content('Private edit') });
  assert.deepEqual((await getDoc(publicRef)).data(), original);
});

test('new public documents allow exact get only and deny every client write', async () => {
  const publicId = 'a'.repeat(32);
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `publicDocuments/${publicId}`), { schemaVersion: 1, publicId, version: 1, title: 'Published', content: content() });
  });
  for (const uid of ['alice', 'bob', null]) {
    const db = database(uid);
    await assertSucceeds(getDoc(doc(db, `publicDocuments/${publicId}`)));
    await assertFails(getDocs(collection(db, 'publicDocuments')));
    await assertFails(setDoc(doc(db, `publicDocuments/${publicId}`), { notes: 'malicious' }));
    await assertFails(deleteDoc(doc(db, `publicDocuments/${publicId}`)));
    await assertFails(getDoc(doc(db, 'publicDocuments/not-an-opaque-id')));
  }
});

test('owner publication metadata is private and cannot forge operation results or lifecycle fields', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'accounts/alice'), { ownerUid: 'alice', lifecycleGeneration: 1, lifecycleState: 'active', deletedDocumentIds: [] });
    await setDoc(doc(db, 'accounts/alice/publications/first'), { documentId: 'first', state: 'published' });
    await setDoc(doc(db, 'accounts/alice/publicationOperations/op'), { status: 'completed' });
  });
  await assertSucceeds(getDoc(doc(database(), 'accounts/alice/publications/first')));
  await assertSucceeds(getDocs(collection(database(), 'accounts/alice/publications')));
  await assertSucceeds(getDoc(doc(database(), 'accounts/alice/publicationOperations/op')));
  await assertFails(getDocs(collection(database(), 'accounts/alice/publicationOperations')));
  for (const uid of ['alice', 'bob', null]) {
    const db = database(uid);
    for (const path of ['accounts/alice', 'accounts/alice/publications/first', 'accounts/alice/publicationOperations/op']) {
      await assertFails(setDoc(doc(db, path), { lifecycleGeneration: 0, deletedDocumentIds: [], status: 'completed' }));
      await assertFails(deleteDoc(doc(db, path)));
      if (uid !== 'alice') await assertFails(getDoc(doc(db, path)));
    }
  }
});

test('schema6 fixture accepts full 20 documents, privacy, overrides and refuses downgrade', async () => {
  const value = JSON.parse(await readFile(new URL('../../fixtures/workspace/schema6.json', import.meta.url), 'utf8'));
  const uid = value.ownerUid;
  const db = database(uid);
  const documents = Array.from({ length: 20 }, (_, index) => ({ ...structuredClone(value.content.documents[0]), id: `doc-${index}` }));
  value.content.documents = documents;
  value.updatedAt = serverTimestamp();
  await assertSucceeds(setDoc(doc(db, `accounts/${uid}/drafts/current`), value));
  value.content.documents[19].baseSnapshot.profile.avatarPath = 'accounts/foreign/media/' + '0'.repeat(32) + '.jpg';
  await assertFails(setDoc(doc(db, `accounts/${uid}/drafts/current`), value));
  await assertFails(saveDraft(db, uid, { schemaVersion: 5 }));
});

test('protected tombstones reject stale whole-workspace writes including last of 20 documents', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'accounts/alice'), { ownerUid: 'alice', lifecycleGeneration: 2, lifecycleState: 'active', deletedDocumentIds: ['resume-19'] });
  });
  const all = workspaceBaseReviews(20);
  await assertFails(saveDraft(database(), 'alice', { schemaVersion: 6, content: all }));
  all.documents = all.documents.filter((document) => document.id !== 'resume-19');
  await assertSucceeds(saveDraft(database(), 'alice', { schemaVersion: 6, content: all }));
  await assertFails(deleteDoc(doc(database(), 'accounts/alice/drafts/current')));
  for (const fakeState of [0, 100]) {
    await assertFails(setDoc(doc(database(), 'accounts/alice'), { ownerUid: 'alice', lifecycleGeneration: fakeState, lifecycleState: 'active', deletedDocumentIds: [] }));
  }
});

test('account deletion lock denies new, old and pending private writes', async () => {
  for (const lifecycleState of ['deleting', 'deleted']) {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'accounts/alice'), { ownerUid: 'alice', lifecycleState, lifecycleGeneration: 3 });
    });
    for (const schemaVersion of [1, 3, 5, 6]) {
      await assertFails(saveDraft(database(), 'alice', { schemaVersion }));
    }
    await assertFails(deleteDoc(doc(database(), 'accounts/alice/drafts/current')));
  }
});
