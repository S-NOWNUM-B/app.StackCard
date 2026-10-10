import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { EventEmitter } from 'node:events';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, serverTimestamp, setLogLevel } from 'firebase/firestore';
import { getBytes, ref } from 'firebase/storage';
import { createPublicationService } from '../functions/src/publication.mjs';
import { permanentPublicId } from '../functions/src/projection.mjs';

const requireFunctions = createRequire(new URL('../functions/package.json', import.meta.url));
const { initializeApp, deleteApp } = requireFunctions('firebase-admin/app');
const { getFirestore, FieldValue } = requireFunctions('firebase-admin/firestore');
const { getStorage } = requireFunctions('firebase-admin/storage');
const { getAuth } = requireFunctions('firebase-admin/auth');
const sharp = requireFunctions('sharp');
const projectId = 'demo-stackcard-test';
const fixture = JSON.parse(await readFile(new URL('../../fixtures/workspace/schema6.json', import.meta.url), 'utf8'));
const privatePath = 'accounts/owner/media/' + '0'.repeat(32) + '.jpg';
const recoveryKey = 'a'.repeat(64);
const instant = () => Date.now();
let app, database, bucket, environment, jpeg;

before(async () => {
  // Исключаем случайный live Admin access при запуске без Emulator Suite.
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  assert.ok(process.env.FIREBASE_STORAGE_EMULATOR_HOST);
  setLogLevel('silent');
  app = initializeApp({ projectId, storageBucket: `${projectId}.appspot.com` }, 'publication-service-test');
  database = getFirestore(app); bucket = getStorage(app).bucket();
  environment = await initializeTestEnvironment({
    projectId,
    firestore: { host: '127.0.0.1', port: 8085, rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8') },
    storage: { host: '127.0.0.1', port: 9199, rules: await readFile(new URL('../storage.rules', import.meta.url), 'utf8') },
  });
  jpeg = await sharp({ create: { width: 2, height: 2, channels: 3, background: '#abcdef' } }).jpeg().toBuffer();
});
beforeEach(async () => { await environment.clearFirestore(); await bucket.deleteFiles({ force: true }); });
after(async () => { await environment?.cleanup(); await deleteApp(app); });

function fakeAuth(onDelete = async () => {}) {
  let deleted = false;
  return {
    async deleteUser(uid) { await onDelete(uid); deleted = true; },
    async getUser(uid) { if (deleted) throw Object.assign(new Error(), { code: 'auth/user-not-found' }); return { uid }; },
  };
}
function service(overrides = {}) {
  return createPublicationService({ database, bucket, auth: fakeAuth(), origin: 'https://stackcard.example', now: instant, ...overrides });
}
async function saveFixture({ media = false, mutationId = fixture.mutationId, uid = 'owner', mutate } = {}) {
  const value = structuredClone(fixture);
  value.ownerUid = uid; value.mutationId = mutationId;
  if (media) {
    value.content.documents[0].content.profile.avatarPath = privatePath;
    value.content.projects[0].imagePaths = [privatePath];
    await bucket.file(privatePath).save(jpeg, { metadata: { contentType: 'image/jpeg', metadata: { firebaseStorageDownloadTokens: 'private-token' } } });
  }
  mutate?.(value);
  await database.doc(`accounts/${uid}/drafts/current`).set({ ...value, updatedAt: FieldValue.serverTimestamp() });
  return value;
}
function request(action = 'publish', overrides = {}) {
  return { action, documentId: 'first', operationId: `${action}-operation`, expectedMutationId: fixture.mutationId, expectedVersion: 0, expectedGeneration: 0, ...overrides };
}
const rejected = (code) => (error) => error.code === code;

test('without Storage text-only publication and withdrawal work, photos fail before journal writes', async () => {
  await saveFixture();
  const api = service({ bucket: null });
  const published = await api.execute('owner', request());
  assert.equal(published.status, 'completed');
  const withdrawn = await api.execute('owner', request('unpublish', { expectedVersion: 1, expectedGeneration: 1 }));
  assert.equal(withdrawn.status, 'completed');
  assert.equal((await database.doc(`publicDocuments/${published.publication.publicId}`).get()).exists, false);
  await saveFixture({ media: true });
  await assert.rejects(api.execute('owner', request('publish', { operationId: 'photo-without-storage', expectedVersion: 2, expectedGeneration: 2 })), rejected('storage-unavailable'));
  assert.equal((await database.doc('accounts/owner/publicationOperations/photo-without-storage').get()).exists, false);
  assert.equal((await database.doc('accounts/owner').get()).data().lifecycleGeneration, 2);
});

test('without Storage media withdrawal and account deletion reject before any lifecycle/data mutation', async () => {
  await saveFixture({ media: true });
  const published = await service().execute('owner', request());
  let identityDeleted = false;
  const api = service({ bucket: null, auth: fakeAuth(async () => { identityDeleted = true; }) });
  await assert.rejects(api.execute('owner', request('unpublish', { expectedVersion: 1, expectedGeneration: 1 })), rejected('storage-unavailable'));
  assert.equal((await database.doc('accounts/owner/publicationOperations/unpublish-operation').get()).exists, false);
  await assert.rejects(api.execute('owner', { action: 'deleteAccount', operationId: 'blocked-delete', expectedGeneration: 1, recoveryKey }, { auth_time: Math.floor(instant() / 1000) }), rejected('storage-unavailable'));
  const account = (await database.doc('accounts/owner').get()).data();
  assert.equal(account.lifecycleState, 'active'); assert.equal(account.lifecycleGeneration, 1);
  assert.equal(account.deletionOperationId, undefined); assert.equal(identityDeleted, false);
  assert.equal((await database.doc('accounts/owner/publicationOperations/blocked-delete').get()).exists, false);
  assert.equal((await database.doc('accounts/owner/drafts/current').get()).exists, true);
  assert.equal((await database.doc(`publicDocuments/${published.publication.publicId}`).get()).exists, true);
});

test('server uses exact saved mutation, projects only selected data and resolves lost response idempotently', async () => {
  await saveFixture();
  const api = service();
  const published = await api.execute('owner', request());
  assert.equal(published.action, 'publish'); assert.equal(published.status, 'completed');
  assert.equal(published.publication.url, `https://stackcard.example/d/${permanentPublicId('owner', 'first')}`);
  const publicReference = database.doc(`publicDocuments/${published.publication.publicId}`);
  const snapshot = (await publicReference.get()).data();
  assert.equal(snapshot.content.projects[0].title, 'Document title');
  assert.deepEqual(snapshot.content.links, []);
  assert.equal(JSON.stringify(snapshot).includes('Private notes'), false);
  await saveFixture({ mutationId: 'new-private', mutate: (value) => { value.content.documents[0].title = 'Unpublished edit'; } });
  assert.equal((await publicReference.get()).data().title, 'First');
  assert.equal((await api.execute('owner', request())).publication.version, 1);
  assert.equal((await api.execute('owner', { action: 'status', operationId: 'publish-operation' })).action, 'publish');
  assert.deepEqual(await api.execute('owner', { action: 'status', operationId: 'never-started' }), { status: 'unknown', operationId: 'never-started' });
  await assert.rejects(api.execute('owner', request('publish', { operationId: 'stale-new-op', expectedVersion: 1, expectedGeneration: 1 })), rejected('conflict'));
  await assert.rejects(api.execute('owner', request('publish', { expectedMutationId: 'new-private' })), rejected('conflict'));
});

test('withdrawal, rename and republish keep permanent ID and stale publish retry cannot resurrect', async () => {
  await saveFixture();
  const api = service();
  const published = await api.execute('owner', request());
  const unpublished = await api.execute('owner', request('unpublish', { expectedVersion: 1, expectedGeneration: 1 }));
  assert.equal(unpublished.publication.state, 'unpublished'); assert.equal(unpublished.publication.url, null);
  assert.equal((await database.doc(`publicDocuments/${published.publication.publicId}`).get()).exists, false);
  const retried = await api.execute('owner', request());
  assert.equal(retried.publication.state, 'unpublished'); assert.equal(retried.publication.url, null);
  await saveFixture({ mutate: (value) => { value.content.documents[0].title = 'Renamed'; } });
  const republished = await api.execute('owner', request('publish', { operationId: 'republish', expectedVersion: 2, expectedGeneration: 2 }));
  assert.equal(republished.publication.publicId, published.publication.publicId);
  assert.equal((await database.doc(`publicDocuments/${published.publication.publicId}`).get()).data().title, 'Renamed');
});

test('document delete withdraws atomically, clears attached resume and rejects all late aggregate saves', async () => {
  const stale = await saveFixture({ mutate: (value) => { value.content.documents[1].attachedResumeId = 'first'; } });
  const api = service();
  const published = await api.execute('owner', request());
  const deleted = await api.execute('owner', request('deleteDocument', { expectedVersion: 1, expectedGeneration: 1 }));
  assert.equal(deleted.publication.state, 'deleted');
  const draft = (await database.doc('accounts/owner/drafts/current').get()).data();
  assert.equal(draft.mutationId, 'delete-deleteDocument-operation');
  assert.equal(draft.localRevision, stale.localRevision + 1);
  assert.equal(draft.notes, stale.notes);
  assert.equal(draft.content.projects.length, 1);
  assert.equal(draft.content.documents.length, 1);
  assert.equal(draft.content.documents[0].attachedResumeId, null);
  assert.equal((await database.doc(`publicDocuments/${published.publication.publicId}`).get()).exists, false);
  const client = environment.authenticatedContext('owner').firestore();
  await assertFails(setDoc(doc(client, 'accounts/owner/drafts/current'), { ...stale, updatedAt: serverTimestamp() }));
  await assertSucceeds(setDoc(doc(client, 'accounts/owner/drafts/current'), { ...draft, updatedAt: serverTimestamp() }));
  await assert.rejects(api.execute('owner', request('publish', { operationId: 'resurrection', expectedVersion: 2, expectedGeneration: 2 })), rejected('deleted'));
  assert.equal((await api.execute('owner', request())).publication.state, 'deleted');
});

test('concurrent separate publishes use CAS, at most one operation commits', async () => {
  await saveFixture();
  const api = service();
  const results = await Promise.allSettled([
    api.execute('owner', request('publish', { operationId: 'one' })),
    api.execute('owner', request('publish', { operationId: 'two' })),
  ]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(results.find((result) => result.status === 'rejected').reason.code, 'conflict');
  assert.equal((await database.collection('publicDocuments').get()).size, 1);
});

test('public JPEG is sanitized, token-free, version-bound and revoked by real Storage Rules', async () => {
  await saveFixture({ media: true });
  const api = service();
  const result = await api.execute('owner', request());
  const snapshot = (await database.doc(`publicDocuments/${result.publication.publicId}`).get()).data();
  const path = snapshot.content.profile.avatarUrl;
  assert.equal(snapshot.content.projects[0].imageUrls[0], path);
  const [metadata] = await bucket.file(path).getMetadata();
  assert.equal(metadata.metadata?.firebaseStorageDownloadTokens, undefined);
  assert.equal(metadata.cacheControl, 'private, no-store, max-age=0');
  const anonymous = environment.unauthenticatedContext().storage(`gs://${bucket.name}`);
  await assertSucceeds(getBytes(ref(anonymous, path)));
  await assertFails(getBytes(ref(anonymous, privatePath)));
  await api.execute('owner', request('unpublish', { expectedVersion: 1, expectedGeneration: 1 }));
  await assertFails(getBytes(ref(anonymous, path)));
  assert.equal((await bucket.file(privatePath).exists())[0], true);
  assert.equal((await bucket.file(path).exists())[0], false);
});

test('same operation concurrent media failure never deletes already committed public JPEG', { timeout: 15000 }, async () => {
  await saveFixture({ media: true });
  let metadataCalls = 0, releaseBothEntered, releaseCommitted;
  const bothEntered = new Promise((resolve) => { releaseBothEntered = resolve; });
  const committed = new Promise((resolve) => { releaseCommitted = resolve; });
  const faultyBucket = {
    file(path) {
      const file = bucket.file(path);
      if (path !== privatePath) return file;
      return {
        async getMetadata() {
          metadataCalls++;
          if (metadataCalls === 1) {
            // Обе операции обязаны войти в copy ДО первого commit.
            await bothEntered; return file.getMetadata();
          }
          assert.equal(metadataCalls, 2); releaseBothEntered();
          await committed; return [{ contentType: 'text/plain', size: 1 }];
        },
        download: (...args) => file.download(...args),
      };
    },
  };
  const api = service({ bucket: faultyBucket });
  const handlers = [api.execute('owner', request()), api.execute('owner', request())];
  // Порядок Firestore transactions не привязан к порядку запуска handlers.
  const successful = await Promise.race(handlers); releaseCommitted();
  const results = await Promise.all(handlers);
  assert.equal(metadataCalls, 2);
  assert.ok(results.every((result) => result.status === 'completed'));
  const snapshot = (await database.doc(`publicDocuments/${successful.publication.publicId}`).get()).data();
  assert.equal((await bucket.file(snapshot.content.profile.avatarUrl).exists())[0], true);
  const journal = (await database.doc('accounts/owner/publicationOperations/publish-operation').get()).data();
  assert.equal(journal.status, 'completed'); assert.equal(journal.copyLeaseCount, 0);
});

test('account deletion requires recent auth, withdraws legacy and new public before Auth identity last', async () => {
  await saveFixture({ media: true });
  const api = service();
  await api.execute('owner', request());
  await database.doc('accounts/owner').set({ username: 'legacy-owner' }, { merge: true });
  await database.doc('publicPortfolios/legacy-owner').set({ ownerUid: 'owner', content: { title: 'Legacy' } });
  await database.doc('usernames/legacy-owner').set({ ownerUid: 'owner', username: 'legacy-owner' });
  const deletion = { action: 'deleteAccount', operationId: 'delete-account', expectedGeneration: 1, recoveryKey };
  await assert.rejects(api.execute('owner', deletion, { auth_time: instant() / 1000 - 301 }), rejected('reauthentication-required'));
  let authDeleted = false;
  const deleting = service({ auth: fakeAuth(async (uid) => {
    assert.equal(uid, 'owner');
    assert.equal((await database.collection('publicDocuments').get()).empty, true);
    assert.equal((await database.doc('publicPortfolios/legacy-owner').get()).exists, false);
    assert.equal((await database.doc('usernames/legacy-owner').get()).exists, false);
    assert.equal((await database.doc('accounts/owner/drafts/current').get()).exists, false);
    assert.equal((await bucket.getFiles())[0].length, 0); authDeleted = true;
  }) });
  const result = await deleting.execute('owner', deletion, { auth_time: Math.floor(instant() / 1000) });
  assert.equal(result.status, 'completed'); assert.equal(result.action, 'deleteAccount'); assert.equal(authDeleted, true);
  assert.deepEqual(await deleting.execute(null, { action: 'deletionStatus', ownerUid: 'owner', operationId: 'delete-account', recoveryKey }), result);
  const journal = (await database.doc('accounts/owner/publicationOperations/delete-account').get()).data();
  assert.equal(JSON.stringify(journal).includes(recoveryKey), false);
  const client = environment.authenticatedContext('owner').firestore();
  await assertFails(setDoc(doc(client, 'accounts/owner/drafts/current'), { ...fixture, updatedAt: serverTimestamp() }));
});

test('deletion receipt recovers cleanup failures and never reveals outcome for wrong UID, key or operation', async () => {
  await saveFixture();
  let failCleanup = true;
  const failingBucket = { deleteFiles: async (...args) => { if (failCleanup) throw new Error('temporary storage outage'); return bucket.deleteFiles(...args); } };
  const api = service({ bucket: failingBucket });
  const result = await api.execute('owner', { action: 'deleteAccount', operationId: 'recoverable-delete', expectedGeneration: 0, recoveryKey }, { auth_time: Math.floor(instant() / 1000) });
  assert.equal(result.status, 'pending');
  const receipt = { action: 'deletionStatus', ownerUid: 'owner', operationId: 'recoverable-delete', recoveryKey, retry: true };
  for (const changed of [{ ...receipt, ownerUid: 'foreign' }, { ...receipt, operationId: 'foreign' }, { ...receipt, recoveryKey: 'b'.repeat(64) }]) {
    assert.deepEqual(await api.execute(null, changed), { action: 'deleteAccount', status: 'unknown', operationId: changed.operationId });
  }
  assert.equal((await database.doc('accounts/owner/drafts/current').get()).exists, true);
  failCleanup = false;
  assert.equal((await api.execute(null, receipt)).status, 'completed');
  assert.equal((await database.doc('accounts/owner/drafts/current').get()).exists, false);
});

test('account cleanup waits for active media lease and includes first-publish orphan prefixes', async () => {
  await saveFixture();
  const publicId = permanentPublicId('owner', 'first');
  const orphan = `publicMedia/${publicId}/1/${'1'.repeat(32)}.jpg`;
  await bucket.file(orphan).save(jpeg, { metadata: { contentType: 'image/jpeg' } });
  await database.doc('accounts/owner/publicationOperations/pending-first-publish').set({ action: 'publish', status: 'pending', publicId, copyLeaseCount: 1, copyLeaseUntil: instant() + 180_000 });
  const api = service();
  const pending = await api.execute('owner', { action: 'deleteAccount', operationId: 'lease-delete', expectedGeneration: 0, recoveryKey }, { auth_time: Math.floor(instant() / 1000) });
  assert.equal(pending.status, 'pending');
  await database.doc('accounts/owner/publicationOperations/pending-first-publish').update({ copyLeaseCount: 0, copyLeaseUntil: 0 });
  const finished = await api.execute(null, { action: 'deletionStatus', ownerUid: 'owner', operationId: 'lease-delete', recoveryKey, retry: true });
  assert.equal(finished.status, 'completed');
  assert.equal((await bucket.file(orphan).exists())[0], false);
  assert.equal((await database.doc('accounts/owner/publicationOperations/pending-first-publish').get()).exists, false);
});

test('anonymous approved deletion receipt repairs a lost final journal ACK after identity deletion', async () => {
  await database.doc('accounts/owner').set({ ownerUid: 'owner', lifecycleState: 'deleted', lifecycleGeneration: 1, deletionOperationId: 'lost-final-ack' });
  const { createHash } = await import('node:crypto');
  await database.doc('accounts/owner/publicationOperations/lost-final-ack').set({ action: 'deleteAccount', status: 'pending', operationId: 'lost-final-ack', recoveryKeyHash: createHash('sha256').update(recoveryKey).digest('hex'), result: { lifecycleGeneration: 1 } });
  const api = service({ auth: { getUser: async () => { throw Object.assign(new Error(), { code: 'auth/user-not-found' }); } } });
  const receipt = await api.execute(null, { action: 'deletionStatus', ownerUid: 'owner', operationId: 'lost-final-ack', recoveryKey });
  assert.equal(receipt.status, 'completed');
  assert.equal(receipt.action, 'deleteAccount');
});

test('HTTP handler verifies actual Auth emulator ID token, refuses spoofed UID and allows scoped unauth receipt', async () => {
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
  process.env.FIREBASE_CONFIG = JSON.stringify({ projectId, storageBucket: `${projectId}.appspot.com` });
  process.env.PUBLIC_WEB_ORIGIN = 'http://localhost:3000'; process.env.FUNCTIONS_EMULATOR = 'true';
  const { documentPublication } = await import('../functions/src/index.mjs');
  const authResponse = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: `publication-${Date.now()}@example.test`, password: 'Test-password-123!', returnSecureToken: true }),
  });
  assert.equal(authResponse.ok, true);
  const { localId, idToken } = await authResponse.json();
  await saveFixture({ uid: localId });
  async function http(body, authorization, extra = {}) {
    const headers = { authorization, origin: 'http://localhost:3000', ...extra };
    const request = { method: 'POST', body, rawBody: Buffer.from(JSON.stringify(body)), get: (key) => headers[key.toLowerCase()], is: (mime) => mime === 'application/json' };
    const result = { statusCode: 200, headers: {} };
    const response = Object.assign(new EventEmitter(), {
      set(key, value) { result.headers[key] = value; return this; },
      status(code) { result.statusCode = code; return this; },
      json(value) { result.body = value; this.emit('finish'); return this; },
      end() { this.emit('finish'); return this; },
    });
    await documentPublication(request, response); return result;
  }
  assert.equal((await http({ action: 'inventory' })).statusCode, 401);
  assert.equal((await http({ action: 'inventory' }, 'Bearer malformed')).statusCode, 401);
  assert.equal((await http({ action: 'inventory' }, `Bearer ${idToken}`, { origin: 'https://foreign.example' })).statusCode, 403);
  assert.equal((await http({ action: 'inventory', ownerUid: 'owner' }, `Bearer ${idToken}`)).statusCode, 400);
  const published = await http(request('publish'), `Bearer ${idToken}`);
  assert.equal(published.statusCode, 200);
  assert.equal(published.body.publication.url, `http://localhost:3000/d/${permanentPublicId(localId, 'first')}`);
  const missingReceipt = await http({ action: 'deletionStatus', ownerUid: localId, operationId: 'unknown-receipt', recoveryKey });
  assert.equal(missingReceipt.statusCode, 200); assert.equal(missingReceipt.body.status, 'unknown');
  await getAuth(app).deleteUser(localId);
});
