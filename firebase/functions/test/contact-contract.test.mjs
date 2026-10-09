import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  normalizeContactRequest, allowsPublicContact, contactQuotaWindows,
  verifyContactAppCheck, genericContactNotification, tokenHash, sameContactPayload,
} from '../src/contact-contract.mjs';

const publicId = 'a'.repeat(32), requestId = 'b'.repeat(32);
const submit = () => ({ action: 'submit', publicId, requestId, name: ' Visitor ', email: 'Visitor@Example.com', message: ' Hello\r\nWorld ', website: '' });
const rejected = (code) => (error) => error.code === code;

test('contact payload is allowlisted, normalized and retries capture the same content', () => {
  const normalized = normalizeContactRequest(submit());
  assert.equal(normalized.name, 'Visitor');
  assert.equal(normalized.email, 'visitor@example.com');
  assert.equal(normalized.message, 'Hello\nWorld');
  assert.ok(sameContactPayload(normalized, { ...normalized }));
  assert.ok(!sameContactPayload(normalized, { ...normalized, message: 'Different' }));
  assert.ok(!sameContactPayload(normalized, { ...normalized, publicId: 'c'.repeat(32) }));
});
test('private fields, invalid IDs, contact injection, whitespace and oversized fields fail closed', () => {
  for (const body of [
    { ...submit(), ownerUid: 'private-owner' }, { ...submit(), notes: 'private' },
    { ...submit(), publicId: '../accounts/owner' }, { ...submit(), requestId: 'B'.repeat(32) },
    { ...submit(), email: 'one@example.com\r\nBcc:other@example.com' },
    { ...submit(), email: 'invalid' }, { ...submit(), name: ' ' },
    { ...submit(), name: 'Visitor\nOther' }, { ...submit(), name: 'Visitor\tOther' },
    { ...submit(), name: 'x'.repeat(101) }, { ...submit(), message: 'x'.repeat(4001) },
    { ...submit(), message: '' }, { ...submit(), website: 'https://bot.example' },
    { action: 'registerDevice', token: 'secret', platform: 'desktop' },
    { action: 'registerDevice', token: '', platform: 'android' },
    { action: 'unregisterDevice', token: 'token', ownerUid: 'other' },
  ]) assert.throws(() => normalizeContactRequest(body), rejected('invalid-data'));
});
test('selected projected typed contacts enable the form without private contact fallback', () => {
  const published = { content: { blocks: [{ kind: 'links', visible: true }], links: [{ kind: 'email', url: 'mailto:hello@example.com' }] } };
  assert.equal(allowsPublicContact(published), true);
  assert.equal(allowsPublicContact({ content: { ...published.content, blocks: [] } }), false);
  assert.equal(allowsPublicContact({ content: { ...published.content, blocks: [{ kind: 'links', visible: false }] } }), false);
  for (const links of [[{ kind: 'website', url: 'https://example.com' }], [{ kind: 'email', url: 'javascript:alert(1)' }], []])
    assert.equal(allowsPublicContact({ content: { ...published.content, links } }), false);
});
test('quota keys hide sender data, separate secrets and scopes, and have bounded TTL windows', () => {
  const at = 1_800_000_000_000;
  const secret = 'a'.repeat(64);
  const rates = contactQuotaWindows({ publicId, email: 'visitor@example.com', secret, now: at });
  assert.deepEqual(rates.map((rate) => rate.limit), [5, 30, 3]);
  assert.ok(rates.every((rate) => /^[0-9a-f]{64}$/.test(rate.id) && rate.expiresAt > at && rate.expiresAt <= at + 2 * 86400000));
  assert.equal(new Set(rates.map((rate) => rate.id)).size, 3);
  assert.notDeepEqual(rates, contactQuotaWindows({ publicId, email: 'visitor@example.com', secret: 'b'.repeat(64), now: at }));
  const other = contactQuotaWindows({ publicId, email: 'other@example.com', secret, now: at });
  assert.equal(rates[0].id, other[0].id); assert.equal(rates[1].id, other[1].id); assert.notEqual(rates[2].id, other[2].id);
  assert.ok(!JSON.stringify(rates).includes('visitor'));
});
test('production App Check consumes the limited-use token and verifies the intended app', async () => {
  const calls = [];
  const appCheck = { async verifyToken(token, options) { calls.push({ token, options }); return { appId: 'intended', alreadyConsumed: false }; } };
  await verifyContactAppCheck({ token: 'limited-use', appId: 'intended', secret: 'a'.repeat(64), appCheck, projectId: 'production-project' });
  assert.deepEqual(calls, [{ token: 'limited-use', options: { consume: true } }]);
  for (const result of [{ appId: 'foreign', alreadyConsumed: false }, { appId: 'intended', alreadyConsumed: true }])
    await assert.rejects(verifyContactAppCheck({ token: 'token', appId: 'intended', secret: 'a'.repeat(64), appCheck: { verifyToken: async () => result }, projectId: 'production-project' }), rejected('app-check-required'));
});
test('missing production protection config and client/demo flags alone never bypass App Check', async () => {
  for (const options of [
    { projectId: 'production-project', emulator: true },
    { projectId: 'demo-stackcard-test', emulator: false },
    { projectId: 'production-project', appId: 'intended' },
  ]) await assert.rejects(verifyContactAppCheck(options), rejected('configuration-required'));
  await verifyContactAppCheck({ projectId: 'demo-stackcard-test', emulator: true });
});
test('device requests have no client UID override and token hashes never expose token bytes', () => {
  assert.deepEqual(normalizeContactRequest({ action: 'registerDevice', token: 'fcm-token', platform: 'ios' }), { action: 'registerDevice', token: 'fcm-token', platform: 'ios' });
  assert.match(tokenHash('fcm-token'), /^[0-9a-f]{64}$/);
  assert.ok(!tokenHash('fcm-token').includes('fcm-token'));
});
test('notification payload contains generic text and only captured owner/request routing data', () => {
  const value = genericContactNotification('owner', requestId);
  assert.deepEqual(value.data, { type: 'contactRequest', requestId, ownerUid: 'owner' });
  assert.deepEqual(Object.keys(value).sort(), ['data', 'notification']);
  assert.ok(!JSON.stringify(value).includes('visitor@example.com'));
});
