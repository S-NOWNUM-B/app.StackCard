import assert from 'node:assert/strict';
import test from 'node:test';
import { createServer } from 'node:http';
import { safeApiEndpoint } from '../src/lib/api-endpoint';
import { publicationEndpoint, recoverAccountDeletion } from '../src/lib/publication';
import { contactEndpoint, submitContact } from '../src/lib/contact-repository';

test('trusted API URLs reject credentials, query, fragment, implicit authority and non-demo HTTP', () => {
  assert.equal(
    safeApiEndpoint('https://api.example.test/documentPublication'),
    'https://api.example.test/documentPublication',
  );
  assert.equal(
    safeApiEndpoint('http://127.0.0.1:3810/documentPublication', true),
    'http://127.0.0.1:3810/documentPublication',
  );
  for (const value of [
    '',
    'https:api.example.test',
    'https:///api.example.test/path',
    '//api.example.test',
    'https://user:password@api.example.test/path',
    'https://api.example.test/path?token=secret',
    'https://api.example.test/path#other',
    'https://api.example.test/path?',
    'https://api.example.test/path#',
    'https://api.example.test/\npath',
    'https://api.example.test\\other',
    'http://127.0.0.1:3810/path',
    'http://api.example.test/path',
  ])
    assert.equal(safeApiEndpoint(value), null, value);
  assert.equal(safeApiEndpoint('http://api.example.test/path', true), null);
});

test('publication and Contact require a demo project before accepting emulator HTTP', (t) => {
  const keys = [
    'NEXT_PUBLIC_USE_EMULATORS',
    'NEXT_PUBLIC_FIREBASE_PROJECT_ID',
    'NEXT_PUBLIC_PUBLICATION_API_URL',
    'NEXT_PUBLIC_CONTACT_INBOX_API_URL',
  ];
  const previous = keys.map((key) => process.env[key]);
  t.after(() =>
    keys.forEach((key, index) => {
      if (previous[index] === undefined) delete process.env[key];
      else process.env[key] = previous[index];
    }),
  );
  process.env.NEXT_PUBLIC_USE_EMULATORS = 'true';
  process.env.NEXT_PUBLIC_PUBLICATION_API_URL = 'http://127.0.0.1:3810/documentPublication';
  process.env.NEXT_PUBLIC_CONTACT_INBOX_API_URL = 'http://127.0.0.1:3810/contactInbox';
  for (const project of ['', 'stackcard-dev-snownumb']) {
    process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID = project;
    assert.throws(publicationEndpoint);
    assert.throws(contactEndpoint);
  }
  process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID = 'demo-stackcard-test';
  assert.match(publicationEndpoint(), /^http:\/\/127\.0\.0\.1:/);
  assert.match(contactEndpoint(), /^http:\/\/127\.0\.0\.1:/);
});

test('Contact and deletion recovery refuse actual HTTP redirects without forwarding payloads', async (t) => {
  const keys = [
    'NEXT_PUBLIC_USE_EMULATORS',
    'NEXT_PUBLIC_FIREBASE_PROJECT_ID',
    'NEXT_PUBLIC_PUBLICATION_API_URL',
    'NEXT_PUBLIC_CONTACT_INBOX_API_URL',
  ];
  const previous = keys.map((key) => process.env[key]);
  t.after(() =>
    keys.forEach((key, index) => {
      if (previous[index] === undefined) delete process.env[key];
      else process.env[key] = previous[index];
    }),
  );
  let redirectedRequests = 0;
  const server = createServer((request, response) => {
    if (request.url === '/unexpected') {
      redirectedRequests++;
      response.end('{}');
    } else {
      response.writeHead(307, { location: '/unexpected' });
      response.end();
    }
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(
    () =>
      new Promise<void>((resolve, reject) =>
        server.close((error) => (error ? reject(error) : resolve())),
      ),
  );
  const address = server.address();
  assert.ok(address && typeof address !== 'string');
  const endpoint = `http://127.0.0.1:${address.port}/redirect`;
  Object.assign(process.env, {
    NEXT_PUBLIC_USE_EMULATORS: 'true',
    NEXT_PUBLIC_FIREBASE_PROJECT_ID: 'demo-stackcard-test',
    NEXT_PUBLIC_PUBLICATION_API_URL: endpoint,
    NEXT_PUBLIC_CONTACT_INBOX_API_URL: endpoint,
  });
  await assert.rejects(
    () =>
      recoverAccountDeletion({
        ownerUid: 'owner',
        operationId: 'operation',
        recoveryKey: 'a'.repeat(64),
      }),
    TypeError,
  );
  await assert.rejects(
    () =>
      submitContact({
        publicId: 'a'.repeat(32),
        requestId: 'b'.repeat(32),
        name: 'Reader',
        email: 'reader@example.test',
        message: 'Private message',
        website: '',
      }),
    TypeError,
  );
  assert.equal(redirectedRequests, 0);
});
