import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, limit, orderBy, documentId, updateDoc, setDoc, deleteDoc, serverTimestamp, setLogLevel } from 'firebase/firestore';
import { createContactService, sendContactNotification } from '../functions/src/contact-service.mjs';
import { tokenHash } from '../functions/src/contact-contract.mjs';
import { createContactHttpHandler } from '../functions/src/contact-http.mjs';
import { createPublicationService } from '../functions/src/publication.mjs';

const requireFunctions = createRequire(new URL('../functions/package.json', import.meta.url));
const { initializeApp, deleteApp } = requireFunctions('firebase-admin/app');
const { getFirestore, Timestamp } = requireFunctions('firebase-admin/firestore');
const { getAuth } = requireFunctions('firebase-admin/auth');
const projectId = 'demo-stackcard-test', publicId = 'a'.repeat(32), requestId = 'b'.repeat(32);
const instant = 1_800_000_000_000;
let app, database, environment;
before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Run only against the demo Firestore emulator');
  setLogLevel('silent');
  app = initializeApp({ projectId }, 'contact-service-test');
  database = getFirestore(app);
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  environment = await initializeTestEnvironment({ projectId, firestore: { host, port: Number(port), rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8') } });
});
beforeEach(async () => environment.clearFirestore());
after(async () => { await environment?.cleanup(); if (app) await deleteApp(app); });

const rejected = (code) => (error) => error.code === code;
const submit = (overrides = {}) => ({ action: 'submit', publicId, requestId, name: 'Visitor', email: 'visitor@example.com', message: 'Contact message', website: '', ...overrides });
const service = (overrides = {}) => createContactService({ database, secret: 'test-secret-'.repeat(4), now: () => instant, ...overrides });
const device = (token, action = 'registerDevice') => ({ action, token, ...(action === 'registerDevice' ? { platform: 'android' } : {}) });
async function published({ contacts = true, state = 'published' } = {}) {
  await database.doc('accounts/owner').set({ ownerUid: 'owner', lifecycleState: 'active', lifecycleGeneration: 0 });
  await database.doc('accounts/owner/publications/selected').set({ documentId: 'selected', publicId, version: 1, state, sourceMutationId: 'saved', mediaPaths: [], url: `https://stackcard.example/d/${publicId}` });
  await database.doc(`publicDocuments/${publicId}`).set({ schemaVersion: 1, publicId, version: 1, title: 'Published document', content: { blocks: contacts ? [{ kind: 'links', visible: true }] : [], links: contacts ? [{ id: 'email', kind: 'email', label: 'Email', url: 'mailto:public@example.com' }] : [] } });
}

test('submit writes exactly ten private Inbox fields after trusted owner resolution and returns no owner data', async () => {
  await published();
  assert.deepEqual(await service().execute(null, submit()), { status: 'accepted', requestId });
  const inbox = (await database.doc(`accounts/owner/contactRequests/${requestId}`).get()).data();
  assert.deepEqual(Object.keys(inbox).sort(), ['createdAt', 'documentId', 'documentTitle', 'email', 'message', 'name', 'publicId', 'readAt', 'requestId', 'schemaVersion']);
  assert.equal(inbox.documentId, 'selected'); assert.equal(inbox.documentTitle, 'Published document');
  assert.ok(inbox.createdAt instanceof Timestamp); assert.equal(inbox.readAt, null);
  assert.equal((await database.collection('contactRateLimits').get()).size, 3);
});
test('same immutable request is accepted idempotently; changed payload cannot overwrite Inbox or consume quota', async () => {
  await published(); const api = service();
  const results = await Promise.all(Array.from({ length: 4 }, () => api.execute(null, submit())));
  assert.ok(results.every((result) => result.status === 'accepted'));
  await assert.rejects(api.execute(null, submit({ message: 'Different' })), rejected('conflict'));
  assert.equal((await database.collection('accounts/owner/contactRequests').get()).size, 1);
  const rates = (await database.collection('contactRateLimits').get()).docs.map((document) => document.data());
  assert.ok(rates.every((rate) => rate.count === 1 && rate.expiresAt instanceof Timestamp));
  assert.ok(!JSON.stringify(rates).includes('visitor@example.com'));
});
test('missing, withdrawn, hidden contacts, stale public version and locked owner are unavailable without fallback', async () => {
  const api = service();
  await assert.rejects(api.execute(null, submit()), rejected('document-unavailable'));
  await published({ contacts: false });
  await assert.rejects(api.execute(null, submit()), rejected('document-unavailable'));
  await published({ state: 'unpublished' });
  await assert.rejects(api.execute(null, submit()), rejected('document-unavailable'));
  await published(); await database.doc(`publicDocuments/${publicId}`).update({ version: 2 });
  await assert.rejects(api.execute(null, submit()), rejected('document-unavailable'));
  await published(); await database.doc('accounts/owner').update({ lifecycleState: 'deleting' });
  await assert.rejects(api.execute(null, submit()), rejected('document-unavailable'));
  assert.equal((await database.collection('accounts/owner/contactRequests').get()).size, 0);
});
test('lost accepted ACK survives withdrawal without accepting a new request or changing quota', async () => {
  await published(); const api = service(); await api.execute(null, submit());
  const before = (await database.collection('contactRateLimits').get()).docs.map((document) => document.data().count);
  await database.doc('accounts/owner/publications/selected').update({ state: 'unpublished', version: 2, url: null });
  await database.doc(`publicDocuments/${publicId}`).delete();
  assert.deepEqual(await api.execute(null, submit()), { status: 'accepted', requestId });
  await assert.rejects(api.execute(null, submit({ requestId: 'c'.repeat(32) })), rejected('document-unavailable'));
  await assert.rejects(api.execute(null, submit({ message: 'Different payload' })), rejected('conflict'));
  assert.equal((await database.collection('accounts/owner/contactRequests').get()).size, 1);
  assert.deepEqual((await database.collection('contactRateLimits').get()).docs.map((document) => document.data().count), before);
});
test('transaction quotas enforce public and sender windows under concurrent submissions', async () => {
  await published(); const api = service();
  const outcomes = await Promise.allSettled(Array.from({ length: 8 }, (_, index) => api.execute(null, submit({ requestId: index.toString(16).padStart(32, '0'), email: `visitor${index}@example.com` }))));
  assert.equal(outcomes.filter((result) => result.status === 'fulfilled').length, 5);
  assert.ok(outcomes.filter((result) => result.status === 'rejected').every((result) => result.reason.code === 'rate-limited'));
  assert.equal((await database.collection('accounts/owner/contactRequests').get()).size, 5);
});
test('sender hourly quota is independent of public ten-minute quota and retry does not count', async () => {
  await published();
  for (let index = 0; index < 3; index++) await service({ now: () => instant + index * 600001 }).execute(null, submit({ requestId: index.toString(16).padStart(32, '0') }));
  await assert.rejects(service({ now: () => instant + 1800003 }).execute(null, submit({ requestId: 'f'.repeat(32) })), rejected('rate-limited'));
  await service().execute(null, submit({ requestId: '0'.repeat(32) }));
});
test('daily quota limits thirty requests across short windows and resets on the next UTC day', async () => {
  await published(); const dayStart = Math.floor(instant / 86400000) * 86400000;
  for (let index = 0; index < 30; index++) {
    const now = dayStart + 3600000 + Math.floor(index / 5) * 600000;
    await service({ now: () => now }).execute(null, submit({ requestId: index.toString(16).padStart(32, '0'), email: `visitor${index}@example.com` }));
  }
  await assert.rejects(service({ now: () => dayStart + 7200000 }).execute(null, submit()), rejected('rate-limited'));
  assert.equal((await database.collection('accounts/owner/contactRequests').get()).size, 30);
  await service({ now: () => dayStart + 86400000 }).execute(null, submit());
  assert.equal((await database.collection('accounts/owner/contactRequests').get()).size, 31);
});
test('Inbox Rules permit only active owner get/list<=50 and readAt server timestamp updates', async () => {
  await published(); await service().execute(null, submit());
  const owner = environment.authenticatedContext('owner').firestore();
  const foreign = environment.authenticatedContext('foreign').firestore();
  const anonymous = environment.unauthenticatedContext().firestore();
  const path = `accounts/owner/contactRequests/${requestId}`;
  await assertSucceeds(getDoc(doc(owner, path)));
  await assertSucceeds(getDocs(query(collection(owner, 'accounts/owner/contactRequests'), orderBy('createdAt', 'desc'), orderBy(documentId(), 'desc'), limit(50))));
  await assertFails(getDocs(collection(owner, 'accounts/owner/contactRequests')));
  await assertFails(getDocs(query(collection(owner, 'accounts/owner/contactRequests'), limit(51))));
  for (const client of [foreign, anonymous]) { await assertFails(getDoc(doc(client, path))); await assertFails(getDocs(query(collection(client, 'accounts/owner/contactRequests'), limit(50)))); }
  await assertSucceeds(updateDoc(doc(owner, path), { readAt: serverTimestamp() }));
  for (const update of [{ message: 'changed' }, { readAt: null }, { ownerUid: 'owner' }, { readAt: serverTimestamp(), name: 'changed' }]) await assertFails(updateDoc(doc(owner, path), update));
  await assertFails(setDoc(doc(owner, 'accounts/owner/contactRequests/' + 'f'.repeat(32)), { schemaVersion: 1 }));
  await assertFails(deleteDoc(doc(owner, path)));
  await database.doc('accounts/owner').update({ lifecycleState: 'deleting' });
  await assertFails(getDoc(doc(owner, path))); await assertFails(updateDoc(doc(owner, path), { readAt: serverTimestamp() }));
});
test('tokens are admin-only, rebind is atomic, stale owner revoke cannot remove the new owner token', async () => {
  const api = service(); await api.execute('owner', device('private-token'));
  const hash = tokenHash('private-token');
  for (const uid of ['owner', 'other', null]) {
    const client = (uid === null ? environment.unauthenticatedContext() : environment.authenticatedContext(uid)).firestore();
    for (const path of [`accounts/owner/pushDevices/${hash}`, `pushTokenOwners/${hash}`]) { await assertFails(getDoc(doc(client, path))); await assertFails(setDoc(doc(client, path), { token: 'attack' })); }
  }
  await api.execute('other', device('private-token'));
  await api.execute('owner', device('private-token', 'unregisterDevice'));
  assert.equal((await database.doc(`accounts/owner/pushDevices/${hash}`).get()).exists, false);
  assert.equal((await database.doc(`accounts/other/pushDevices/${hash}`).get()).exists, true);
  assert.equal((await database.doc(`pushTokenOwners/${hash}`).get()).data().ownerUid, 'other');
  await database.doc('accounts/other').set({ lifecycleState: 'deleting' });
  await assert.rejects(api.execute('other', device('new')), rejected('account-unavailable'));
});
test('parallel registrations respect the ten-device account cap and logout revoke leaves other devices intact', async () => {
  const api = service();
  const results = await Promise.allSettled(Array.from({ length: 12 }, (_, index) => api.execute('owner', device(`token-${index}`))));
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 10);
  const devices = await database.collection('accounts/owner/pushDevices').get(); assert.equal(devices.size, 10);
  await api.execute('owner', device(devices.docs[0].data().token, 'unregisterDevice'));
  assert.equal((await database.collection('accounts/owner/pushDevices').get()).size, 9);
});
test('concurrent cross-owner rebind leaves one global owner and exactly one private device', async () => {
  const api = service(), owners = ['first', 'second', 'third'], token = 'shared-device', hash = tokenHash(token);
  await Promise.all(owners.map((uid) => api.execute(uid, device(token))));
  const binding = (await database.doc(`pushTokenOwners/${hash}`).get()).data();
  assert.ok(owners.includes(binding.ownerUid));
  const registrations = await database.getAll(...owners.map((uid) => database.doc(`accounts/${uid}/pushDevices/${hash}`)));
  assert.deepEqual(registrations.filter((registration) => registration.exists).map((registration) => registration.ref.parent.parent.id), [binding.ownerUid]);
});
test('device HTTP actions verify actual Auth emulator ID tokens and never accept a caller-supplied owner', async () => {
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST, 'Run with the demo Auth emulator');
  const signup = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: `contact-${Date.now()}@example.test`, password: 'Test-password-123!', returnSecureToken: true }),
  });
  assert.equal(signup.ok, true); const { localId, idToken } = await signup.json();
  const handler = createContactHttpHandler({ database, auth: getAuth(app), origin: 'https://stackcard.example', emulator: true, projectId });
  async function http(body, authorization, origin = 'https://stackcard.example') {
    const headers = { authorization, origin }, reply = { statusCode: 200, value: null,
      set() { return this; }, status(code) { this.statusCode = code; return this; }, json(value) { this.value = value; return this; }, end() { return this; } };
    await handler({ method: 'POST', body, rawBody: Buffer.from(JSON.stringify(body)), get: (key) => headers[key.toLowerCase()], is: (type) => type === 'application/json' }, reply);
    return reply;
  }
  const token = 'auth-owned-device';
  try {
    assert.equal((await http(device(token))).statusCode, 401);
    assert.equal((await http(device(token), 'Bearer malformed')).statusCode, 401);
    assert.equal((await http(device(token), `Bearer ${idToken}`, 'https://foreign.example')).statusCode, 403);
    assert.equal((await http({ ...device(token), ownerUid: 'spoofed' }, `Bearer ${idToken}`)).statusCode, 400);
    const registered = await http(device(token), `Bearer ${idToken}`);
    assert.equal(registered.statusCode, 200); assert.deepEqual(registered.value, { status: 'completed' });
    assert.equal((await database.doc(`pushTokenOwners/${tokenHash(token)}`).get()).data().ownerUid, localId);
    await database.doc(`accounts/${localId}`).set({ lifecycleState: 'deleted' });
    assert.equal((await http(device('locked-device'), `Bearer ${idToken}`)).statusCode, 409);
    await getAuth(app).deleteUser(localId);
    assert.equal((await http(device(token, 'unregisterDevice'), `Bearer ${idToken}`)).statusCode, 401);
  } finally { await getAuth(app).deleteUser(localId).catch((error) => { if (error.code !== 'auth/user-not-found') throw error; }); }
});
test('durable notification sender is generic, deduplicates trigger attempts and skips stale bindings', async () => {
  await published(); const api = service(); await api.execute(null, submit()); await api.execute('owner', device('owner-token'));
  const sent = [], messaging = { async sendEachForMulticast(payload) { assert.equal((await database.doc(`accounts/owner/contactRequests/${requestId}`).get()).exists, true); sent.push(payload); return { responses: payload.tokens.map(() => ({ success: true })) }; } };
  await Promise.all([sendContactNotification({ database, messaging, ownerUid: 'owner', requestId }), sendContactNotification({ database, messaging, ownerUid: 'owner', requestId })]);
  assert.equal(sent.length, 1); assert.deepEqual(sent[0].data, { type: 'contactRequest', requestId, ownerUid: 'owner' });
  assert.ok(!JSON.stringify(sent).includes('visitor@example.com')); assert.ok(!JSON.stringify(sent).includes('Contact message'));
  await api.execute('other', device('owner-token'));
  const second = 'c'.repeat(32); await api.execute(null, submit({ requestId: second }));
  await sendContactNotification({ database, messaging, ownerUid: 'owner', requestId: second });
  assert.equal(sent.length, 1);
});
test('notification failures preserve Inbox and late invalid-token cleanup cannot delete a rebound token', async () => {
  await published(); const api = service(); await api.execute(null, submit()); await api.execute('owner', device('owner-token'));
  const messaging = { async sendEachForMulticast() { await api.execute('other', device('owner-token')); return { responses: [{ success: false, error: { code: 'messaging/registration-token-not-registered' } }] }; } };
  await sendContactNotification({ database, messaging, ownerUid: 'owner', requestId });
  assert.equal((await database.doc(`pushTokenOwners/${tokenHash('owner-token')}`).get()).data().ownerUid, 'other');
  assert.equal((await database.doc(`accounts/owner/contactRequests/${requestId}`).get()).exists, true);
});
test('a thrown FCM transport failure preserves the durable Inbox and suppresses a duplicate transport attempt', async () => {
  await published(); const api = service(); await api.execute(null, submit()); await api.execute('owner', device('owner-token'));
  let attempts = 0;
  const messaging = { async sendEachForMulticast() { attempts++; throw new Error('transport unavailable'); } };
  await sendContactNotification({ database, messaging, ownerUid: 'owner', requestId });
  await sendContactNotification({ database, messaging, ownerUid: 'owner', requestId });
  assert.equal(attempts, 1);
  assert.equal((await database.doc(`accounts/owner/contactRequests/${requestId}`).get()).exists, true);
});
test('sender requires an existing active account and leaves no retry receipt for a missing owner', async () => {
  await published(); const api = service(); await api.execute(null, submit()); await api.execute('owner', device('owner-token'));
  await database.doc('accounts/owner').delete();
  await sendContactNotification({ database, messaging: { sendEachForMulticast: () => assert.fail('missing owner must not receive a push') }, ownerUid: 'owner', requestId });
  assert.equal((await database.doc(`accounts/owner/contactNotificationReceipts/${requestId}`).get()).exists, false);
});
test('account deletion clears private Inbox/devices and global bindings without deleting another owner binding', async () => {
  await published(); const api = service(); await api.execute(null, submit()); await api.execute('owner', device('one')); await api.execute('other', device('two'));
  const publisher = createPublicationService({ database, bucket: { deleteFiles: async () => {} }, auth: { deleteUser: async () => {} }, origin: 'https://stackcard.example', now: () => instant });
  const result = await publisher.execute('owner', { action: 'deleteAccount', operationId: 'delete-contact-owner', expectedGeneration: 0, recoveryKey: 'e'.repeat(64) }, { auth_time: instant / 1000 });
  assert.equal(result.status, 'completed');
  assert.equal((await database.collection('accounts/owner/contactRequests').get()).size, 0);
  assert.equal((await database.collection('accounts/owner/pushDevices').get()).size, 0);
  assert.equal((await database.doc(`pushTokenOwners/${tokenHash('one')}`).get()).exists, false);
  assert.equal((await database.doc(`pushTokenOwners/${tokenHash('two')}`).get()).data().ownerUid, 'other');
});
