import assert from 'node:assert/strict';
import test from 'node:test';
import { deleteApp } from 'firebase/app';
import type { User } from 'firebase/auth';
import { firebaseServices } from '../src/lib/firebase';
import { publicationRequest } from '../src/lib/publication';

test('publication does not dispatch a captured token after an account switch or accept a stale response', async (t) => {
  const env = {
    NEXT_PUBLIC_FIREBASE_API_KEY: 'test-api-key',
    NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN: 'demo-stackcard-test.firebaseapp.com',
    NEXT_PUBLIC_FIREBASE_PROJECT_ID: 'demo-stackcard-test',
    NEXT_PUBLIC_FIREBASE_APP_ID: 'test-publication-owner',
    NEXT_PUBLIC_PUBLICATION_API_URL: 'https://api.example.test/documentPublication',
    NEXT_PUBLIC_USE_EMULATORS: 'false',
  };
  const previousEnv = Object.fromEntries(Object.keys(env).map((key) => [key, process.env[key]]));
  const previousWindow = Object.getOwnPropertyDescriptor(globalThis, 'window');
  Object.assign(process.env, env);
  Object.defineProperty(globalThis, 'window', { value: {}, configurable: true });
  t.after(() => {
    for (const [key, value] of Object.entries(previousEnv)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    if (previousWindow) Object.defineProperty(globalThis, 'window', previousWindow);
    else Reflect.deleteProperty(globalThis, 'window');
  });
  const { app, auth } = firebaseServices();
  await auth.authStateReady();
  t.after(() => {
    Object.defineProperty(auth, 'currentUser', { value: null });
    return deleteApp(app);
  });
  let releaseToken!: (token: string) => void;
  const captured = {
    uid: 'first-owner',
    getIdToken: () =>
      new Promise<string>((resolve) => {
        releaseToken = resolve;
      }),
  } as User;
  Object.defineProperty(auth, 'currentUser', {
    configurable: true,
    writable: true,
    value: captured,
  });
  let requests = 0;
  t.mock.method(globalThis, 'fetch', async () => {
    requests++;
    throw new Error('Must not dispatch');
  });
  const pending = publicationRequest(captured, { action: 'inventory' });
  Object.defineProperty(auth, 'currentUser', { value: { uid: 'other-owner' } });
  releaseToken('synthetic-token');
  await assert.rejects(pending, /Аккаунт изменился/);
  assert.equal(requests, 0);

  const active = { uid: 'first-owner', getIdToken: async () => 'synthetic-token' } as User;
  Object.defineProperty(auth, 'currentUser', { value: active });
  t.mock.method(globalThis, 'fetch', async (_url: unknown, options?: RequestInit) => {
    assert.equal(options?.redirect, 'error');
    assert.equal(options?.credentials, 'omit');
    Object.defineProperty(auth, 'currentUser', { value: { uid: 'other-owner' } });
    return new Response(
      JSON.stringify({ status: 'completed', publications: [], lifecycleGeneration: 0 }),
    );
  });
  await assert.rejects(
    () => publicationRequest(active, { action: 'inventory' }),
    /Аккаунт изменился/,
  );
});
