import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createRequire } from 'node:module';
import { test } from 'node:test';

const requireFunctions = createRequire(new URL('../functions/package.json', import.meta.url));
const { initializeApp, deleteApp } = requireFunctions('firebase-admin/app');
const { getAuth } = requireFunctions('firebase-admin/auth');

test('Auth emulator password reset redeems the owner code once and replaces the old password', async (t) => {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  assert.match(host ?? '', /^(?:127\.0\.0\.1|localhost):[0-9]+$/, 'Use the loopback demo Auth emulator only');
  const base = `http://${host}`, projectId = 'demo-stackcard-test';
  const app = initializeApp({ projectId }, 'auth-recovery-test');
  t.after(() => deleteApp(app));
  const email = `reset-${randomUUID()}@example.test`;
  const oldPassword = 'Previous-password-123!', newPassword = 'Changed-password-456!';
  async function auth(action, body) {
    const response = await fetch(`${base}/identitytoolkit.googleapis.com/v1/accounts:${action}?key=demo-key`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    return { status: response.status, value: await response.json() };
  }
  const created = await auth('signUp', { email, password: oldPassword, returnSecureToken: true });
  assert.equal(created.status, 200);
  try {
    assert.equal((await auth('sendOobCode', { requestType: 'PASSWORD_RESET', email })).status, 200);
    const response = await fetch(`${base}/emulator/v1/projects/${projectId}/oobCodes`);
    assert.equal(response.status, 200);
    const codes = (await response.json()).oobCodes.filter((entry) => entry.email === email && entry.requestType === 'PASSWORD_RESET');
    assert.equal(codes.length, 1);
    const oobCode = codes[0].oobCode;
    assert.equal((await auth('resetPassword', { oobCode: 'invalid-code', newPassword })).status, 400);
    assert.equal((await auth('resetPassword', { oobCode, newPassword })).status, 200);
    assert.equal((await auth('signInWithPassword', { email, password: oldPassword, returnSecureToken: true })).status, 400);
    const signedIn = await auth('signInWithPassword', { email, password: newPassword, returnSecureToken: true });
    assert.equal(signedIn.status, 200);
    assert.equal(signedIn.value.localId, created.value.localId);
    assert.equal((await auth('resetPassword', { oobCode, newPassword: oldPassword })).status, 400);
    assert.equal((await auth('delete', { idToken: signedIn.value.idToken })).status, 200);
  } finally {
    // Удаляем только synthetic identity, не очищая весь Auth emulator.
    await getAuth(app).deleteUser(created.value.localId).catch((error) => { if (error.code !== 'auth/user-not-found') throw error; });
  }
});
