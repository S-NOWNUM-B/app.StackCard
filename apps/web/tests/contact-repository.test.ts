import assert from 'node:assert/strict';
import test from 'node:test';
import { deleteApp, getApps } from 'firebase/app';
import { submitContact } from '../src/lib/contact-repository';

test('Enterprise contact retry requests a fresh limited-use token and preserves captured payload', async (t) => {
  const env = {
    NEXT_PUBLIC_FIREBASE_API_KEY: 'test-api-key',
    NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN: 'test-project.firebaseapp.com',
    NEXT_PUBLIC_FIREBASE_PROJECT_ID: 'test-project',
    NEXT_PUBLIC_FIREBASE_APP_ID: 'test-web-app',
    NEXT_PUBLIC_APP_CHECK_SITE_KEY: 'test-enterprise-site-key',
    NEXT_PUBLIC_CONTACT_INBOX_API_URL: 'https://api.stackcard.example/contactInbox',
    NEXT_PUBLIC_USE_EMULATORS: 'false',
  };
  const previousEnv = Object.fromEntries(Object.keys(env).map((key) => [key, process.env[key]]));
  Object.assign(process.env, env);
  t.after(() => {
    for (const [key, value] of Object.entries(previousEnv)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
  function installGlobal(name: string, value: unknown) {
    const previous = Object.getOwnPropertyDescriptor(globalThis, name);
    Object.defineProperty(globalThis, name, { value, writable: true, configurable: true });
    t.after(() => {
      if (previous) Object.defineProperty(globalThis, name, previous);
      else Reflect.deleteProperty(globalThis, name);
    });
  }
  const document = {
    createElement(tag: string) {
      assert.equal(tag, 'div');
      return { style: {}, id: '' };
    },
    body: { appendChild() {} },
  };
  let attestations = 0;
  const enterprise = {
    ready(callback: () => void) {
      callback();
    },
    render(_container: string, options: { sitekey: string; callback: () => void }) {
      assert.equal(options.sitekey, env.NEXT_PUBLIC_APP_CHECK_SITE_KEY);
      options.callback();
      return 1;
    },
    async execute(widget: number, options: { action: string }) {
      assert.equal(widget, 1);
      assert.equal(options.action, 'fire_app_check');
      return `recaptcha-proof-${++attestations}`;
    },
  };
  installGlobal('window', { document });
  installGlobal('document', document);
  installGlobal('self', {
    grecaptcha: {
      enterprise,
      ready() {
        assert.fail('v3 provider must not be used');
      },
    },
  });
  const exchanges: unknown[] = [],
    submissions: RequestInit[] = [];
  t.mock.method(globalThis, 'fetch', async (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    if (new URL(url).hostname === 'content-firebaseappcheck.googleapis.com') {
      assert.ok(
        url.includes('/projects/test-project/apps/test-web-app:exchangeRecaptchaEnterpriseToken'),
      );
      exchanges.push(JSON.parse(String(init?.body)));
      return new Response(
        JSON.stringify({ token: `limited-token-${exchanges.length}`, ttl: '3600s' }),
        { status: 200 },
      );
    }
    assert.equal(url, env.NEXT_PUBLIC_CONTACT_INBOX_API_URL);
    assert.ok(init);
    submissions.push(init);
    return new Response(JSON.stringify({ status: 'accepted', requestId: submission.requestId }), {
      status: 200,
    });
  });
  t.after(async () => {
    const app = getApps().find((candidate) => candidate.name === 'stackcard-web');
    if (app) await deleteApp(app);
  });
  const submission = {
    publicId: 'a'.repeat(32),
    requestId: 'b'.repeat(32),
    name: 'Reader',
    email: 'reader@example.com',
    message: 'Captured message',
    website: '',
  };
  await submitContact(submission);
  await submitContact(submission);
  assert.deepEqual(exchanges, [
    { recaptcha_enterprise_token: 'recaptcha-proof-1', limited_use: true },
    { recaptcha_enterprise_token: 'recaptcha-proof-2', limited_use: true },
  ]);
  assert.equal(submissions.length, 2);
  for (const [index, init] of submissions.entries()) {
    assert.equal(
      new Headers(init.headers).get('X-Firebase-AppCheck'),
      `limited-token-${index + 1}`,
    );
    assert.deepEqual(JSON.parse(String(init.body)), { action: 'submit', ...submission });
    assert.equal(init.cache, 'no-store');
  }
});
