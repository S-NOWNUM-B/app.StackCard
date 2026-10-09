import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createContactHttpHandler } from '../src/contact-http.mjs';

const payload = () => ({ action: 'submit', publicId: 'a'.repeat(32), requestId: 'b'.repeat(32), name: 'Visitor', email: 'visitor@example.com', message: 'Hello', website: '' });
function request(body = payload(), headers = {}, overrides = {}) {
  return { method: 'POST', body, rawBody: Buffer.from(JSON.stringify(body)), is: (type) => type === 'application/json', get: (key) => headers[key.toLowerCase()], ...overrides };
}
function response() {
  return { statusCode: 200, headers: {}, value: null, set(name, value) { this.headers[name] = value; return this; }, status(code) { this.statusCode = code; return this; }, json(value) { this.value = value; return this; }, end() { return this; } };
}
test('contact HTTP rejects missing protection configuration without querying private data', async () => {
  const reply = response();
  await createContactHttpHandler({ projectId: 'production-project', origin: 'https://stackcard.example', database: null })(request(), reply);
  assert.equal(reply.statusCode, 503); assert.equal(reply.value.error.code, 'configuration-required');
  assert.equal(reply.headers['Cache-Control'], 'no-store');
});
test('CORS permits only the configured origin and includes the limited-use App Check header', async () => {
  const handler = createContactHttpHandler({ origin: 'https://stackcard.example', projectId: 'production-project' });
  const denied = response(); await handler(request(payload(), { origin: 'https://evil.example' }), denied);
  assert.equal(denied.statusCode, 403); assert.equal(denied.headers['Access-Control-Allow-Origin'], undefined);
  const allowed = response(); await handler(request(payload(), { origin: 'https://stackcard.example' }, { method: 'OPTIONS' }), allowed);
  assert.equal(allowed.statusCode, 204); assert.equal(allowed.headers['Access-Control-Allow-Origin'], 'https://stackcard.example');
  assert.ok(allowed.headers['Access-Control-Allow-Headers'].includes('X-Firebase-AppCheck'));
});
test('body allowlist and bounded JSON fail before verification and authenticated device actions require a Bearer token', async () => {
  const handler = createContactHttpHandler({ origin: 'https://stackcard.example', projectId: 'production-project' });
  for (const value of [request({ ...payload(), ownerUid: 'private' }), request(payload(), {}, { rawBody: Buffer.alloc(24577) }), request(payload(), {}, { is: () => false })]) {
    const reply = response(); await handler(value, reply); assert.equal(reply.statusCode, 400); assert.equal(reply.value.error.code, 'invalid-data');
  }
  const reply = response(); await handler(request({ action: 'registerDevice', token: 'token', platform: 'android' }), reply);
  assert.equal(reply.statusCode, 401); assert.equal(reply.value.error.code, 'unauthenticated');
});
