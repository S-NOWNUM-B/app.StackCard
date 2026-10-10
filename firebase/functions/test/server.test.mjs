import assert from 'node:assert/strict';
import { request as httpRequest } from 'node:http';
import { after, before, test } from 'node:test';
import { createBackendServer, readServerConfiguration } from '../src/server.mjs';
import { createContactHttpHandler } from '../src/contact-http.mjs';
import { createPublicationHttpHandler } from '../src/publication-http.mjs';

const configuration = () => ({ GCLOUD_PROJECT: 'production-project', BACKEND_PORT: '5001',
  PUBLIC_WEB_ORIGIN: 'https://stackcard.example', CONTACT_APP_CHECK_APP_ID: 'intended-app', CONTACT_RATE_HMAC_KEY: 's'.repeat(32) });
const demoConfiguration = () => ({ GCLOUD_PROJECT: 'demo-stackcard-test', BACKEND_PORT: '5001',
  PUBLIC_WEB_ORIGIN: 'http://localhost:3000', FUNCTIONS_EMULATOR: 'true',
  FIRESTORE_EMULATOR_HOST: '127.0.0.1:8085', FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099' });

test('Node server requires explicit live protection and never enables remote Storage or emulator bypass', () => {
  const live = readServerConfiguration(configuration());
  assert.equal(live.emulator, false); assert.equal(live.storageBucket, null);
  const invalid = [
    { CONTACT_RATE_HMAC_KEY: '' }, { CONTACT_APP_CHECK_APP_ID: '' }, { PUBLIC_WEB_ORIGIN: 'http://localhost:3000' },
    { PUBLIC_STORAGE_BUCKET: 'production-project.appspot.com' }, { GCLOUD_PROJECT: 'demo-stackcard-test' },
    { FUNCTIONS_EMULATOR: 'true' }, { BACKEND_PORT: '0' }, { BACKEND_PORT: '65536' }, { BACKEND_PORT: '' },
    { FIRESTORE_EMULATOR_HOST: '127.0.0.1:8085' }, { FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099' },
  ];
  for (const override of invalid) assert.throws(() => readServerConfiguration({ ...configuration(), ...override }));
});

test('demo bypass requires both actual loopback Auth/Firestore hosts, optional Storage also stays loopback', () => {
  assert.equal(readServerConfiguration(demoConfiguration()).emulator, true);
  assert.equal(readServerConfiguration({ ...demoConfiguration(), PUBLIC_STORAGE_BUCKET: 'demo-stackcard-test.appspot.com', FIREBASE_STORAGE_EMULATOR_HOST: '[::1]:9199' }).storageBucket, 'demo-stackcard-test.appspot.com');
  for (const override of [
    { FIRESTORE_EMULATOR_HOST: '' }, { FIREBASE_AUTH_EMULATOR_HOST: '' }, { FIRESTORE_EMULATOR_HOST: 'firestore.googleapis.com:443' },
    { FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099/path' }, { FIRESTORE_EMULATOR_HOST: 'user@localhost:8085' },
    { FIREBASE_STORAGE_EMULATOR_HOST: 'remote.example:9199' }, { PUBLIC_STORAGE_BUCKET: 'demo-stackcard-test.appspot.com' },
  ]) assert.throws(() => readServerConfiguration({ ...demoConfiguration(), ...override }));
});

let server, origin;
before(async () => {
  server = createBackendServer({
    contactHandler: createContactHttpHandler({ origin: 'https://stackcard.example', projectId: 'production-project' }),
    publicationHandler: createPublicationHttpHandler({ origin: 'https://stackcard.example', bucket: null }),
  });
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
  origin = `http://127.0.0.1:${server.address().port}`;
});
after(async () => {
  if (!server?.listening) return;
  server.closeAllConnections(); await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
});

test('real Node HTTP adapter provides minimal health and preserves CORS/auth checks for both endpoints', async () => {
  const health = await fetch(`${origin}/health`);
  assert.deepEqual(await health.json(), { status: 'ok' });
  assert.equal(health.headers.get('cache-control'), 'no-store');
  assert.equal((await fetch(`${origin}/health`, { method: 'HEAD' })).status, 200);
  assert.equal((await fetch(`${origin}/missing`)).status, 404);
  for (const path of ['/contactInbox', '/documentPublication']) {
    const denied = await fetch(`${origin}${path}`, { method: 'OPTIONS', headers: { Origin: 'https://foreign.example' } });
    assert.equal(denied.status, 403); assert.equal(denied.headers.get('access-control-allow-origin'), null);
    const allowed = await fetch(`${origin}${path}`, { method: 'OPTIONS', headers: { Origin: 'https://stackcard.example' } });
    assert.equal(allowed.status, 204); assert.equal(allowed.headers.get('access-control-allow-origin'), 'https://stackcard.example');
    assert.equal((await fetch(`${origin}${path}`)).status, 405);
    const body = path === '/contactInbox' ? { action: 'registerDevice', token: 'token', platform: 'android' } : { action: 'inventory' };
    const result = await fetch(`${origin}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body) });
    assert.equal(result.status, 401); assert.equal((await result.json()).error.code, 'unauthenticated');
  }
});

test('HTTP parser rejects malformed/wrong-type/oversized JSON for both route limits without accessing Firebase', async () => {
  for (const [path, limit] of [['/contactInbox', 24576], ['/documentPublication', 8192]]) {
    for (const [body, contentType] of [['{broken', 'application/json'], ['{}', 'text/plain'], [' '.repeat(limit + 1), 'application/json']]) {
      const result = await fetch(`${origin}${path}`, { method: 'POST', headers: { 'Content-Type': contentType }, body });
      assert.equal(result.status, 400); assert.equal((await result.json()).error.code, 'invalid-data');
    }
    // Отдельно проверяем stream без Content-Length: лимит не зависит от declared size.
    const result = await new Promise((resolve, reject) => {
      const request = httpRequest(`${origin}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json' } }, (response) => {
        let body = ''; response.on('data', (chunk) => { body += chunk; });
        response.on('end', () => resolve({ status: response.statusCode, body: JSON.parse(body) }));
      });
      request.on('error', reject); request.write(' '.repeat(limit)); request.end(' ');
    });
    assert.equal(result.status, 400); assert.equal(result.body.error.code, 'invalid-data');
  }
});
