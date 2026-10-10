import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createPublicationHttpHandler } from '../src/publication-http.mjs';

function request(body = { action: 'inventory' }, headers = {}, overrides = {}) {
  return { method: 'POST', body, rawBody: Buffer.from(JSON.stringify(body)), is: (mime) => mime === 'application/json',
    get: (name) => headers[name.toLowerCase()], ...overrides };
}
function response() {
  return { statusCode: 200, headers: {}, value: null, set(name, value) { this.headers[name] = value; return this; },
    status(code) { this.statusCode = code; return this; }, json(value) { this.value = value; return this; }, end() { return this; } };
}

test('shared publication HTTP keeps exact CORS and bounded body checks before authorization', async () => {
  const handler = createPublicationHttpHandler({ origin: 'https://stackcard.example' });
  const denied = response();
  await handler(request(undefined, { origin: 'https://foreign.example' }), denied);
  assert.equal(denied.statusCode, 403);
  assert.equal(denied.headers['Access-Control-Allow-Origin'], undefined);
  const preflight = response();
  await handler(request(undefined, { origin: 'https://stackcard.example' }, { method: 'OPTIONS' }), preflight);
  assert.equal(preflight.statusCode, 204);
  assert.equal(preflight.headers['Access-Control-Allow-Origin'], 'https://stackcard.example');
  assert.equal(preflight.headers['Access-Control-Allow-Headers'], 'Authorization, Content-Type');
  for (const value of [request(undefined, {}, { rawBody: Buffer.alloc(8193) }), request(undefined, {}, { is: () => false })]) {
    const reply = response(); await handler(value, reply);
    assert.equal(reply.statusCode, 400); assert.equal(reply.value.error.code, 'invalid-data');
  }
  const unauthenticated = response(); await handler(request(), unauthenticated);
  assert.equal(unauthenticated.statusCode, 401);
  assert.equal(unauthenticated.headers['Cache-Control'], 'no-store');
  assert.equal(unauthenticated.headers['X-Content-Type-Options'], 'nosniff');
});

test('shared publication HTTP uses verified UID and preserves unknown scoped deletion receipt', async () => {
  const read = [];
  const database = { doc(path) { read.push(path); return {
    async get() { return { data: () => path === 'accounts/verified-owner' ? { lifecycleGeneration: 7 } : undefined }; },
    collection(name) {
      return { async get() { assert.equal(name, 'publications'); return { docs: [] }; },
        doc(id) { assert.equal(name, 'publicationOperations'); return database.doc(`${path}/${name}/${id}`); } };
    },
  }; } };
  const auth = { async verifyIdToken(token, revoked) { assert.equal(token, 'signed-token'); assert.equal(revoked, true); return { uid: 'verified-owner' }; } };
  const handler = createPublicationHttpHandler({ database, auth, bucket: null, origin: 'https://stackcard.example' });
  const inventory = response(); await handler(request(undefined, { authorization: 'Bearer signed-token' }), inventory);
  assert.deepEqual(inventory.value, { status: 'completed', lifecycleGeneration: 7, publications: [] });
  assert.deepEqual(read, ['accounts/verified-owner', 'accounts/verified-owner']);
  const receipt = response(); await handler(request({ action: 'deletionStatus', ownerUid: 'verified-owner', operationId: 'unknown', recoveryKey: 'a'.repeat(64) }), receipt);
  assert.equal(receipt.statusCode, 200); assert.equal(receipt.value.status, 'unknown');
});
